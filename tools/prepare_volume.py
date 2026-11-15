#!/usr/bin/env python3
"""Build and validate attenuation-only OGG variants for the addon's volume slider.

Requires Python 3, FFmpeg with libvorbis, and ffprobe. Run from any directory:
    python tools/prepare_volume.py
    python tools/prepare_volume.py --verify-only

Original sounds/*.ogg are read only. 100% uses those originals; 0% means no
playback. The nine derived banks use linear PCM gains 0.1 through 0.9, with no
normalization, compression, limiting, amplification, fades, or resampling.
Original asset rights and attribution remain unchanged. Bitexact flags remove
random OGG serials and metadata variation. Identical tools/inputs produce
identical files; encoder versions can produce different encoded bytes.
Source timing is rebuilt from PCM sample positions while retaining its initial
timestamp, avoiding broken/nonmonotonic Vorbis timestamps on transcoding. No
silence is added, and no audio samples are deliberately trimmed.
"""

import argparse
import array
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "WindfuryProcSound"
SOUNDS = ADDON / "sounds"
MANIFEST = ADDON / "volume_manifest.json"
REPORT = ROOT / "references" / "volume_validation.json"
LEVELS = tuple(range(10, 100, 10))
EXPECTED_ORIGINALS = 20
QUALITY = "6"
TOLERANCES = {
    "container_duration_samples": 1,
    # Timestamp rounding can move an endpoint by one sample (0.023 ms).
    "decoded_frame_difference": 1,
    "rms_gain_error_db": 0.5,
    "peak_gain_error_db": 1.0,
    "maximum_absolute_sample_exclusive": 1.0,
}


def run(*args):
    try:
        return subprocess.check_output(args, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as error:
        raise RuntimeError(f"{' '.join(args)}\n{error.stderr.decode(errors='replace')}") from error


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path):
    return path.relative_to(ADDON).as_posix()


def db(value):
    return 20 * math.log10(value) if value > 0 else None


def inspect(path):
    streams = json.loads(run(
        "ffprobe", "-v", "error", "-select_streams", "a", "-show_streams",
        "-of", "json", str(path),
    ))["streams"]
    if len(streams) != 1 or streams[0]["codec_name"] != "vorbis":
        raise ValueError(f"Expected exactly one Vorbis stream: {path}")
    stream = streams[0]
    channels, sample_rate = int(stream["channels"]), int(stream["sample_rate"])
    decoded = array.array("f", run(
        "ffmpeg", "-v", "error", "-xerror", "-threads", "1", "-i", str(path),
        "-map", "0:a:0", "-threads", "1", "-filter_threads", "1",
        "-f", "f32le", "-c:a", "pcm_f32le", "pipe:1",
    ))
    if sys.byteorder != "little":
        decoded.byteswap()
    if not decoded or len(decoded) % channels:
        raise ValueError(f"Invalid decoded frame count: {path}")
    if not all(math.isfinite(value) for value in decoded):
        raise ValueError(f"Non-finite audio sample: {path}")
    peak = max(map(abs, decoded))
    rms = math.sqrt(math.fsum(value * value for value in decoded) / len(decoded))
    return {
        "path": relative(path),
        "sha256": sha256(path),
        "bytes": path.stat().st_size,
        "codec": "vorbis",
        "sample_rate": sample_rate,
        "channels": channels,
        "duration_seconds": float(stream["duration"]),
        "duration_ts": int(stream["duration_ts"]),
        "time_base": stream["time_base"],
        "decoded_frames": len(decoded) // channels,
        "decoded_duration_seconds": len(decoded) / channels / sample_rate,
        "rms": rms,
        "peak": peak,
        "rms_dbfs": db(rms),
        "peak_dbfs": db(peak),
    }


def encode(source, level):
    target = SOUNDS / f"volume_{level}" / source.name
    target.parent.mkdir(parents=True, exist_ok=True)
    run(
        "ffmpeg", "-v", "error", "-xerror", "-y", "-bitexact", "-threads", "1",
        "-i", str(source), "-map", "0:a:0", "-map_metadata", "-1",
        "-threads", "1", "-filter_threads", "1",
        "-af", f"volume={level / 100:.1f}:precision=double,asetpts=N/SR/TB+STARTPTS",
        "-c:a", "libvorbis", "-q:a", QUALITY, "-fflags", "+bitexact",
        str(target),
    )
    return target


def compare(source, result, level):
    gain = level / 100
    errors = []
    for key in ("sample_rate", "channels", "time_base"):
        if result[key] != source[key]:
            errors.append(f"{key} changed")
    duration_difference = result["duration_ts"] - source["duration_ts"]
    frame_difference = result["decoded_frames"] - source["decoded_frames"]
    rms_ratio = result["rms"] / source["rms"]
    peak_ratio = result["peak"] / source["peak"]
    rms_error_db, peak_error_db = db(rms_ratio / gain), db(peak_ratio / gain)
    if abs(duration_difference) > TOLERANCES["container_duration_samples"]:
        errors.append("container duration changed")
    if abs(frame_difference) > TOLERANCES["decoded_frame_difference"]:
        errors.append("decoded duration changed beyond codec-padding tolerance")
    if abs(rms_error_db) > TOLERANCES["rms_gain_error_db"]:
        errors.append("RMS gain outside lossy-codec tolerance")
    if abs(peak_error_db) > TOLERANCES["peak_gain_error_db"]:
        errors.append("peak gain outside lossy-codec tolerance")
    if result["peak"] >= TOLERANCES["maximum_absolute_sample_exclusive"]:
        errors.append("decoded waveform clips at or above full scale")
    return {
        **result,
        "source_path": source["path"],
        "source_sha256": source["sha256"],
        "volume_percent": level,
        "intended_linear_gain": gain,
        "intended_gain_db": db(gain),
        "measured_rms_gain": rms_ratio,
        "measured_peak_gain": peak_ratio,
        "rms_gain_error_db": rms_error_db,
        "peak_gain_error_db": peak_error_db,
        "duration_difference_samples": duration_difference,
        "decoded_frame_difference": frame_difference,
        "validation_passed": not errors,
        "validation_errors": errors,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", action="store_true",
                        help="Validate existing variants against saved hashes; do not encode.")
    parser.add_argument("--jobs", type=int, default=4,
                        help="Concurrent FFmpeg jobs (default: 4).")
    parser.add_argument("--exclude", action="append", default=None, metavar="FILENAME.ogg",
                        help="Omit a retired original and its variants without deleting them. "
                             "Repeat for each source. --verify-only reuses manifest exclusions.")
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    prior = json.loads(MANIFEST.read_text()) if args.verify_only else None
    excluded = set(args.exclude if args.exclude is not None else
                   (prior or {}).get("excluded_source_files", []))
    if any(Path(name).name != name or not name.endswith(".ogg") for name in excluded):
        parser.error("--exclude accepts only an OGG filename, not a path")
    sources = sorted(path for path in SOUNDS.glob("*.ogg") if path.name not in excluded)
    expected_count = EXPECTED_ORIGINALS - len(excluded)
    if not sources or len(sources) != expected_count:
        raise ValueError(f"Expected {expected_count} included originals; found {len(sources)}")
    original_hashes = {relative(path): sha256(path) for path in sources}
    if prior:
        expected = {item["path"]: item["sha256"] for item in prior["originals"]}
        if expected != original_hashes:
            raise ValueError("Original hashes differ from the recorded manifest")
    with ThreadPoolExecutor(max_workers=args.jobs) as executor:
        originals = list(executor.map(inspect, sources))
        source_info = {item["path"]: item for item in originals}
        jobs = [(source, level) for level in LEVELS for source in sources]
        if not args.verify_only:
            list(executor.map(lambda job: encode(*job), jobs))
        print(f"{'Checking' if args.verify_only else 'Encoded'} {len(jobs)} volume variants.",
              flush=True)
        targets = [SOUNDS / f"volume_{level}" / source.name for source, level in jobs]
        decoded = list(executor.map(inspect, targets))
    variants = [compare(source_info[relative(source)], result, level)
                for (source, level), result in zip(jobs, decoded)]
    originals_unchanged = original_hashes == {
        relative(path): sha256(path) for path in sources
    }
    bank_file_counts = {
        str(level): len([path for path in (SOUNDS / f"volume_{level}").glob("*.ogg")
                        if path.name not in excluded])
        for level in LEVELS
    }
    errors = [f"{item['path']}: {', '.join(item['validation_errors'])}"
              for item in variants if item["validation_errors"]]
    if not originals_unchanged:
        errors.append("Original file hashes changed during the run")
    if any(count != expected_count for count in bank_file_counts.values()):
        errors.append("A volume bank has an unexpected OGG file count")
    if prior:
        expected = {item["path"]: item["sha256"] for item in prior["variants"]}
        if expected != {item["path"]: item["sha256"] for item in variants}:
            errors.append("Derived file hashes differ from the recorded manifest")
    summary = {
        "passed": not errors,
        "original_count": len(originals),
        "excluded_source_files": sorted(excluded),
        "variant_count": len(variants),
        "decoded_successfully": len(variants),
        "originals_unchanged": originals_unchanged,
        "original_bytes": sum(item["bytes"] for item in originals),
        "variant_bytes": sum(item["bytes"] for item in variants),
        "bank_file_counts": bank_file_counts,
        "maximum_absolute_rms_gain_error_db": max(abs(item["rms_gain_error_db"]) for item in variants),
        "maximum_absolute_peak_gain_error_db": max(abs(item["peak_gain_error_db"]) for item in variants),
        "maximum_absolute_duration_difference_samples": max(abs(item["duration_difference_samples"]) for item in variants),
        "maximum_absolute_decoded_frame_difference": max(abs(item["decoded_frame_difference"]) for item in variants),
        "maximum_variant_peak": max(item["peak"] for item in variants),
        "clipped_variants": sum(item["peak"] >= 1 for item in variants),
        "errors": errors,
    }
    manifest = {
        "schema_version": 1,
        "excluded_source_files": sorted(excluded),
        "generator": "tools/prepare_volume.py",
        "ffmpeg_version": run("ffmpeg", "-version").decode().splitlines()[0],
        "encoding": {"codec": "libvorbis", "quality": int(QUALITY), "bitexact": True,
                     "gain_type": "linear PCM amplitude", "normalization": False,
                     "amplification": False, "levels_percent": list(LEVELS),
                     "timing": "Rebuild timestamps from PCM sample positions, retaining the source initial timestamp. No silence added or audio samples deliberately trimmed."},
        "playback": {"0_percent": "Do not play a sound", "100_percent": "Use unchanged original sounds/*.ogg"},
        "rights": "Each variant retains the source asset's existing rights and attribution; no new audio was sourced.",
        "measurement": "Decode with FFmpeg to float32 PCM; RMS and absolute peak across all channels. Compare decoded amplitude to its decoded original. Container timing and decoded sample counts are checked separately for Vorbis padding.",
        "tolerances": TOLERANCES,
        "summary": summary,
        "originals": originals,
        "variants": variants,
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps({"verification_mode": "existing_files" if args.verify_only else "new_render",
                                  "manifest": relative(MANIFEST), "tolerances": TOLERANCES,
                                  **summary}, indent=2) + "\n")
    if errors:
        print(json.dumps(summary, indent=2))
        raise SystemExit("Volume validation failed; see references/volume_validation.json")
    if not args.verify_only:
        MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
