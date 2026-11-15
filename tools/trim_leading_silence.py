#!/usr/bin/env python3
"""Conservatively remove only the custom cues' near-silent leading padding.

Requires Python 3, numpy, FFmpeg/libvorbis and ffprobe. Run:
    python tools/trim_leading_silence.py
    python tools/prepare_volume.py
    python tools/trim_leading_silence.py --verify-only
    python tools/prepare_volume.py --verify-only

The first run archives all 20 inputs, their catalog and volume manifest outside
the addon. Later runs always derive their plan from that immutable archive,
validate known output hashes, and do not encode already-processed/no-op files.
Unknown changed inputs cause an error, rather than another destructive trim.

At -60 dBFS peak (0.001 full scale), keep at least 5 ms before the first sample
above the threshold in ANY channel. Select the quietest sample in the preceding
1 ms to avoid a hard boundary. Do nothing when less than 5 ms can be removed.
Never trim the tail, resample, remix, normalize, amplify, fade or denoise. This
is a conservative signal threshold, not a claim of universal inaudibility.
Changed files need one lossy re-encode at Vorbis quality 10. PCM comparison
checks attack, retained waveform, gain and exact frame count. The native wolf
has no bundled file and is explicitly excluded, including its catalog entry.
"""

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import tempfile

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "WindfuryProcSound"
SOUNDS = ADDON / "sounds"
CATALOG = ADDON / "sound-catalog.json"
BACKUP = ROOT / "audio-assets" / "before-leading-trim"
REPORT = ROOT / "references" / "leading_silence_validation.json"
METHOD = {
    "threshold_dbfs": -60,
    "threshold_linear_peak": 0.001,
    "preroll_ms_minimum": 5,
    "boundary_search_ms": 1,
    "minimum_trim_ms": 5,
    "vorbis_quality": 10,
    "tail_trim": False,
    "normalization": False,
    "gain_change": False,
    "fades": False,
    "sample_rate_or_channel_changes": False,
}
TOLERANCES = {
    "retained_frame_difference": 0,
    "retained_waveform_snr_db_minimum": 35,
    "attack_snr_db_minimum": 34,
    "attack_correlation_minimum": 0.999,
    "fitted_gain_error_db_maximum": 0.15,
    "peak_error_db_maximum": 0.3,
    "processed_leading_near_silence_ms_maximum": 6.5,
    "first_sample_peak_dbfs_maximum": -60,
}


def run(*args, pcm=None):
    result = subprocess.run(args, input=pcm, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, check=False)
    if result.returncode:
        raise RuntimeError(f"{' '.join(map(str, args))}\n{result.stderr.decode()}")
    return result.stdout


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    data = json.dumps(value, indent=2, allow_nan=False) + "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_text() != data:
        path.write_text(data)


def db(value):
    return 20 * math.log10(value) if value > 0 else None


def decode(path):
    streams = json.loads(run("ffprobe", "-v", "error", "-select_streams", "a",
                             "-show_streams", "-of", "json", str(path)))["streams"]
    if len(streams) != 1 or streams[0]["codec_name"] != "vorbis":
        raise ValueError(f"Expected one Vorbis stream: {path}")
    stream = streams[0]
    sr, ch = int(stream["sample_rate"]), int(stream["channels"])
    pcm = np.frombuffer(run("ffmpeg", "-v", "error", "-xerror", "-i", str(path),
                            "-map", "0:a:0", "-f", "f32le", "-c:a", "pcm_f32le",
                            "pipe:1"), dtype="<f4").reshape(-1, ch).astype(np.float64)
    if not len(pcm) or not np.isfinite(pcm).all():
        raise ValueError(f"Empty/non-finite decoded audio: {path}")
    peak = float(np.max(np.abs(pcm)))
    rms = float(np.sqrt(np.mean(pcm * pcm)))
    above = np.flatnonzero(np.max(np.abs(pcm), axis=1) > METHOD["threshold_linear_peak"])
    if not len(above):
        raise ValueError(f"No signal above the conservative threshold: {path}")
    info = {
        "sha256": sha256(path), "bytes": path.stat().st_size,
        "sample_rate": sr, "channels": ch, "codec": "Vorbis",
        "decoded_frames": len(pcm), "duration_seconds": len(pcm) / sr,
        "container_duration_ts": int(stream["duration_ts"]),
        "container_duration_seconds": float(stream["duration"]),
        "peak": peak, "peak_dbfs": db(peak), "rms_dbfs": db(rms),
        "leading_near_silence_frames": int(above[0]),
        "leading_near_silence_ms": int(above[0]) * 1000 / sr,
        "first_sample_peak_dbfs": db(float(np.max(np.abs(pcm[0])))),
    }
    return pcm, info


def trim_point(pcm, info):
    sr = info["sample_rate"]
    limit = max(0, info["leading_near_silence_frames"] - math.ceil(sr * 0.005))
    start = max(0, limit - math.ceil(sr * 0.001))
    boundary = start + int(np.argmin(np.max(np.abs(pcm[start:limit + 1]), axis=1)))
    return boundary if boundary >= math.ceil(sr * 0.005) else 0


def encode(pcm, sr, ch, path):
    """Correct FFmpeg's Vorbis initial timestamp without adding PCM silence.

    Depending on first block size, Vorbis decoding begins at PTS 0 or 128.
    Preserve the exact supplied frame count by shifting ONLY encoder timestamps
    by that initial PTS. Without this, FFmpeg may omit or append tail samples.
    The output still decodes starting at PCM frame zero, checked below.
    """
    def render(offset):
        run("ffmpeg", "-v", "error", "-xerror", "-y", "-bitexact",
            "-threads", "1", "-f", "f32le", "-ar", str(sr), "-ac", str(ch),
            "-i", "pipe:0", "-map_metadata", "-1", "-threads", "1",
            "-filter_threads", "1", "-af", f"asetpts=N/SR/TB+{offset}/SR/TB",
            "-c:a", "libvorbis", "-q:a", str(METHOD["vorbis_quality"]),
            "-fflags", "+bitexact", str(path), pcm=pcm.astype("<f4").tobytes())
    render(0)
    frames = json.loads(run("ffprobe", "-v", "error", "-select_streams", "a",
                            "-show_frames", "-of", "json", str(path)))["frames"]
    offset = int(frames[0]["pts"])
    if offset not in (0, 128):
        raise ValueError(f"Unexpected encoder priming timestamp {offset}: {path}")
    if offset:
        render(offset)
    return offset


def comparison(expected, actual):
    residual = actual - expected
    error = float(np.sqrt(np.mean(residual * residual)))
    rms = float(np.sqrt(np.mean(expected * expected)))
    gain = float(np.sum(expected * actual) / np.sum(expected * expected))
    correlation = float(np.sum(expected * actual) /
                        np.sqrt(np.sum(expected * expected) * np.sum(actual * actual)))
    return {"snr_db": db(rms / error) if error else None,
            "fitted_gain_error_db": db(gain), "correlation": correlation}


def validate(source_pcm, before, result_pcm, after, cut):
    errors = []
    expected = source_pcm[cut:]
    delta = len(result_pcm) - len(expected)
    if delta or before["sample_rate"] != after["sample_rate"] or before["channels"] != after["channels"]:
        raise ValueError(f"Changed PCM layout or tail length: frame difference={delta}")
    full = comparison(expected, result_pcm)
    onset = before["leading_near_silence_frames"] - cut
    end = min(len(expected), onset + round(before["sample_rate"] * 0.1))
    attack = comparison(expected[onset:end], result_pcm[onset:end])
    peak_error = db(after["peak"] / before["peak"])
    removed_peak = float(np.max(np.abs(source_pcm[:cut]))) if cut else None
    if cut:
        checks = {
            "removed signal exceeded threshold": removed_peak > METHOD["threshold_linear_peak"],
            "less than 5 ms pre-roll": onset < math.ceil(before["sample_rate"] * 0.005),
            "remaining lead-in too long": after["leading_near_silence_ms"] > 6.5,
            "lead-in did not improve": after["leading_near_silence_ms"] >= before["leading_near_silence_ms"],
            "start discontinuity too large": (after["first_sample_peak_dbfs"] or -999) > -60,
            "retained waveform error too large": full["snr_db"] is None or full["snr_db"] < 35,
            "attack waveform error too large": attack["snr_db"] is None or attack["snr_db"] < 34,
            "attack correlation too low": attack["correlation"] < 0.999,
            "gain error too large": abs(full["fitted_gain_error_db"]) > 0.15,
            "attack gain error too large": abs(attack["fitted_gain_error_db"]) > 0.15,
            "peak error too large": abs(peak_error) > 0.3,
        }
        errors.extend(key for key, failed in checks.items() if failed)
    elif before["sha256"] != after["sha256"]:
        errors.append("no-op source changed bytes")
    if after["peak"] >= 1:
        errors.append("decoded output clips")
    return {"passed": not errors, "errors": errors,
            "retained_frame_difference": delta,
            "removed_peak_dbfs": db(removed_peak) if removed_peak is not None else None,
            "preroll_frames": onset, "preroll_ms": onset * 1000 / before["sample_rate"],
            "peak_error_db": peak_error, "retained_waveform": full, "first_100ms_attack": attack,
            "tail_frames_removed": 0}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    sources = sorted(SOUNDS.glob("*.ogg"))
    if len(sources) != 20:
        raise ValueError(f"Expected 20 custom sources, found {len(sources)}")
    archive_manifest = BACKUP / "input_manifest.json"
    if not archive_manifest.exists():
        if args.verify_only:
            raise ValueError("No original archive exists; run processing first")
        if BACKUP.exists():
            raise ValueError("Incomplete archive exists; inspect it before proceeding")
        BACKUP.mkdir(parents=True)
        for source in sources:
            shutil.copy2(source, BACKUP / source.name)
        shutil.copy2(CATALOG, BACKUP / "sound-catalog.json")
        shutil.copy2(ADDON / "volume_manifest.json", BACKUP / "volume_manifest.json")
        write_json(archive_manifest, {"schema_version": 1,
                   "files": {p.name: sha256(BACKUP / p.name) for p in sources},
                   "catalog_sha256": sha256(BACKUP / "sound-catalog.json"),
                   "volume_manifest_sha256": sha256(BACKUP / "volume_manifest.json")})
    archive = json.loads(archive_manifest.read_text())
    if set(archive["files"]) != {p.name for p in sources}:
        raise ValueError("Source set differs from the immutable archive")
    for name, expected in archive["files"].items():
        if sha256(BACKUP / name) != expected:
            raise ValueError(f"Archived input changed: {name}")
    for name, key in [("sound-catalog.json", "catalog_sha256"),
                      ("volume_manifest.json", "volume_manifest_sha256")]:
        if sha256(BACKUP / name) != archive[key]:
            raise ValueError(f"Archived metadata changed: {name}")
    prior = json.loads(REPORT.read_text()) if REPORT.exists() else None
    if prior and prior["method"] != METHOD:
        raise ValueError("Processing method changed; review a new archive/plan explicitly")
    known = {item["filename"]: item for item in prior["files"]} if prior else {}
    if args.verify_only and len(known) != 20:
        raise ValueError("No complete prior processing report")
    catalog = json.loads(CATALOG.read_text())
    original_catalog = json.loads((BACKUP / "sound-catalog.json").read_text())
    native = [x for x in original_catalog if x.get("kind") == "native_sound_kit"]
    if [x for x in catalog if x.get("kind") == "native_sound_kit"] != native:
        raise ValueError("Native sound catalog entry changed; it is outside this tool's scope")
    updated_catalog = copy.deepcopy(catalog)
    previous_entries = {item["filename"]: item for item in original_catalog if "filename" in item}
    entries = {item["filename"]: item for item in updated_catalog if "filename" in item}
    report_files, replacements = [], []
    with tempfile.TemporaryDirectory(prefix=".leading-trim-", dir=ROOT) as temporary:
        for source in sources:
            archived = BACKUP / source.name
            source_pcm, before = decode(archived)
            cut = trim_point(source_pcm, before)
            current_hash = sha256(source)
            previous = known.get(source.name)
            if previous and (previous["before"]["sha256"] != before["sha256"] or
                             previous["trim_frames"] != cut):
                raise ValueError(f"Recorded source/trim plan mismatch: {source.name}")
            already_done = previous and current_hash == previous["after"]["sha256"]
            if current_hash != before["sha256"] and not already_done:
                raise ValueError(f"Unknown current audio; refusing to trim again: {source.name}")
            if args.verify_only and not already_done:
                raise ValueError(f"Output hash mismatch: {source.name}")
            target = source
            offset = previous["encoder_timestamp_offset_frames"] if already_done else None
            if cut and not already_done:
                target = Path(temporary) / source.name
                offset = encode(source_pcm[cut:], before["sample_rate"], before["channels"], target)
                replacements.append((target, source))
            result_pcm, after = decode(target)
            checks = validate(source_pcm, before, result_pcm, after, cut)
            if not checks["passed"]:
                raise ValueError(f"Audio validation failed for {source.name}: {checks['errors']}")
            trim_ms = cut * 1000 / before["sample_rate"]
            record = {"filename": source.name, "status": "trimmed" if cut else "unchanged",
                      "trim_frames": cut, "trim_ms": trim_ms,
                      "encoder_timestamp_offset_frames": offset,
                      "reason": "Near-silent leading padding removed; full attack and tail retained."
                                if cut else "No removable lead-in of at least 5 ms with 5 ms pre-roll; bytes unchanged.",
                      "before": before, "after": after, "validation": checks}
            report_files.append(record)
            entry = entries[source.name]
            for key in ("sha256", "bytes", "sample_rate", "channels", "codec"):
                entry[key] = after[key]
            entry["duration"] = round(after["duration_seconds"], 6)
            entry["peak_dbfs"] = round(after["peak_dbfs"], 2)
            entry["rms_dbfs"] = round(after["rms_dbfs"], 2)
            entry["leading_silence_processing"] = {
                "generator": "tools/trim_leading_silence.py", "status": record["status"],
                "source_sha256": before["sha256"], "trim_frames": cut,
                "trim_ms": round(trim_ms, 6), "threshold_dbfs": -60,
                "preroll_ms_minimum": 5, "tail_frames_removed": 0,
                "gain_change": False, "normalization": False,
                "before_leading_near_silence_ms": round(before["leading_near_silence_ms"], 6),
                "after_leading_near_silence_ms": round(after["leading_near_silence_ms"], 6),
            }
            original_changes = previous_entries[source.name]["changes"]
            if cut:
                entry["changes_before_leading_trim"] = original_changes
                entry["changes"] = (
                    f"Removed {trim_ms:.3f} ms of leading near-silence at a conservative -60 dBFS "
                    "peak threshold, preserving at least 5 ms pre-roll and the complete tail. "
                    "No normalization, gain adjustment, fade, resampling or channel change. "
                    "Re-encoded Vorbis quality 10; no longer byte-identical to the prior file. "
                    "Earlier processing and unchanged rights notes are recorded in changes_before_leading_trim.")
            else:
                entry["changes"] = original_changes
        report = {
            "schema_version": 1, "generator": "tools/trim_leading_silence.py",
            "archive": BACKUP.relative_to(ROOT).as_posix(),
            "ffmpeg_version": run("ffmpeg", "-version").decode().splitlines()[0],
            "method": METHOD, "tolerances": TOLERANCES,
            "measurement": "FFmpeg float32 decoded PCM. Threshold uses maximum absolute sample across channels. SNR and fitted gain compare output to the exact retained archived waveform; attack comparison covers 100 ms from threshold onset. No listening test or in-game playback claim.",
            "native_sound_kit": "Unchanged; game-owned Warcraft Wolf Howl has no editable bundled file.",
            "summary": {"passed": True, "custom_files_checked": 20,
                        "trimmed_files": sum(bool(r["trim_frames"]) for r in report_files),
                        "unchanged_files": sum(not r["trim_frames"] for r in report_files),
                        "total_trim_ms": sum(r["trim_ms"] for r in report_files),
                        "clipped_files": 0, "tail_frames_removed": 0,
                        "maximum_retained_frame_difference": 0,
                        "native_catalog_entry_unchanged": True},
            "files": report_files,
        }
        if args.verify_only:
            if report != prior or updated_catalog != catalog:
                raise ValueError("Measured output/catalog differs from recorded processing report")
        else:
            for staged, destination in replacements:
                staged.replace(destination)
            write_json(CATALOG, updated_catalog)
            write_json(REPORT, report)
        print(json.dumps({**report["summary"], "encoded_this_run": len(replacements),
                          "verification_only": args.verify_only}, indent=2))
        if replacements:
            print("Next: python tools/prepare_volume.py (regenerate all volume variants)")


if __name__ == "__main__":
    main()
