"""Trim near-silent padding from both ends of every catalogued custom cue.

Requires numpy, FFmpeg/libvorbis and ffprobe. Keeps at least 5 ms outside the
first/last sample above -60 dBFS across ANY channel. Interior silence and natural
decay above the threshold remain intact. Never amplifies, fades or normalizes.
Sources are archived once outside the addon. Reruns verify known output hashes
and never progressively trim/re-encode a processed file. Native SoundKits have
no editable file. Run prepare_volume.py after processing.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import tempfile

import numpy as np

from trim_leading_silence import comparison, decode, encode

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "WindfuryProcSound"
BACKUP = ROOT / "audio-assets" / "before-edge-trim-041"
REPORT = ROOT / "references" / "silence_trim_validation_041.json"
THRESHOLD = 0.001


def trim_bounds(pcm, sample_rate):
    peaks = np.max(np.abs(pcm), axis=1)
    active = np.flatnonzero(peaks > THRESHOLD)
    if not len(active):
        raise ValueError("No audible signal above -60 dBFS")
    padding = math.ceil(sample_rate * 0.005)
    search = math.ceil(sample_rate * 0.001)
    first_limit = max(0, int(active[0]) - padding)
    start = max(0, first_limit - search)
    start += int(np.argmin(peaks[start:first_limit + 1]))
    if start < padding:
        start = 0
    last_limit = min(len(pcm), int(active[-1]) + 1 + padding)
    end_limit = min(len(pcm), last_limit + search)
    # Choose a quiet final retained sample, leaving the whole attack and decay.
    end = last_limit
    if last_limit < end_limit:
        end += int(np.argmin(peaks[last_limit - 1:end_limit]))
    if len(pcm) - end < padding:
        end = len(pcm)
    return start, end


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    catalog_path = ADDON / "sound-catalog.json"
    catalog = json.loads(catalog_path.read_text())
    entries = [item for item in catalog if item.get("file")]
    archive_path = BACKUP / "manifest.json"
    if not archive_path.exists():
        if args.verify_only:
            raise ValueError("No archived inputs or completed trim report")
        if BACKUP.exists():
            raise ValueError("Incomplete archive exists; inspect before proceeding")
        BACKUP.mkdir(parents=True)
        archived = {}
        for item in entries:
            source = ADDON / "sounds" / item["file"]
            shutil.copy2(source, BACKUP / source.name)
            archived[source.name] = sha256(source)
        shutil.copy2(catalog_path, BACKUP / "sound-catalog.json")
        archive_path.write_text(json.dumps(archived, indent=2) + "\n")
    archived = json.loads(archive_path.read_text())
    if set(archived) != {item["file"] for item in entries}:
        raise ValueError("Catalog differs from the archived source set")
    previous = json.loads(REPORT.read_text()) if REPORT.exists() else {}
    known = {item["file"]: item for item in previous.get("files", [])}
    records, replacements = [], []
    with tempfile.TemporaryDirectory(prefix=".edge-trim-", dir=ROOT) as temporary:
        for item in entries:
            name = item["file"]
            original = BACKUP / name
            if sha256(original) != archived[name]:
                raise ValueError(f"Archived source changed: {name}")
            pcm, before = decode(original)
            start, end = trim_bounds(pcm, before["sample_rate"])
            current = ADDON / "sounds" / name
            prior = known.get(name)
            quality_limited = prior.get("quality_limited") if prior else None
            if quality_limited:
                if (quality_limited["planned_start_frame"] != start or
                        quality_limited["planned_end_frame"] != end):
                    raise ValueError(f"Quality-limited trim plan changed: {name}")
                start, end = 0, len(pcm)
            if prior and (prior["source_sha256"] != archived[name] or
                          prior["start_frame"] != start or prior["end_frame"] != end):
                raise ValueError(f"Recorded trim plan changed: {name}")
            done = prior and sha256(current) == prior["sha256"]
            if not done and sha256(current) != archived[name]:
                raise ValueError(f"Unknown output; refusing a progressive trim: {name}")
            if args.verify_only and not done:
                raise ValueError(f"Output differs from the saved report: {name}")
            target = current
            changed = start > 0 or end < len(pcm)
            if changed and not done:
                target = Path(temporary) / name
                encode(pcm[start:end], before["sample_rate"], before["channels"], target)
                replacements.append((target, current))
            actual, after = decode(target)
            expected = pcm[start:end]
            if actual.shape != expected.shape:
                raise ValueError(f"Retained frame/channel count changed: {name}")
            metrics = comparison(expected, actual)
            if after["peak"] >= 1:
                raise ValueError(f"Decoded output clips: {name}")
            if changed and (
                    metrics["snr_db"] is None or metrics["snr_db"] < 35 or
                    abs(metrics["fitted_gain_error_db"]) > 0.15 or
                    metrics["correlation"] < 0.999):
                if args.verify_only or done:
                    raise ValueError(f"Recorded waveform/gain validation failed: {name}: {metrics}")
                # A high-quality lossy re-encode still has a quality budget.
                # Keep the source bytes when a padding-only edit exceeds it;
                # never relax the threshold merely to force a successful trim.
                quality_limited = {
                    "reason": "Original bytes preserved: Vorbis quality-10 re-encode exceeded waveform quality limits.",
                    "planned_start_frame": start, "planned_end_frame": end,
                    "untrimmed_leading_ms": round(start * 1000 / before["sample_rate"], 6),
                    "untrimmed_trailing_ms": round((len(pcm) - end) * 1000 / before["sample_rate"], 6),
                    "candidate_waveform": metrics,
                }
                replacements.pop()
                target = current
                actual, after = decode(target)
                start, end = 0, len(pcm)
                metrics = comparison(pcm, actual)
                if after["sha256"] != before["sha256"]:
                    raise ValueError(f"Quality-limited original changed: {name}")
            if (start and np.max(np.abs(pcm[:start])) > THRESHOLD) or (
                    end < len(pcm) and np.max(np.abs(pcm[end:])) > THRESHOLD):
                raise ValueError(f"Removed signal exceeded -60 dBFS: {name}")
            record = {
                "file": name, "source_sha256": archived[name], "sha256": after["sha256"],
                "start_frame": start, "end_frame": end,
                "leading_trim_ms": round(start * 1000 / before["sample_rate"], 6),
                "trailing_trim_ms": round((len(pcm) - end) * 1000 / before["sample_rate"], 6),
                "before_duration_seconds": before["duration_seconds"],
                "after_duration_seconds": after["duration_seconds"],
                "retained_frames": len(actual), "waveform": metrics, "passed": True,
            }
            if quality_limited:
                record["quality_limited"] = quality_limited
            records.append(record)
            for key in ("sha256", "bytes", "sample_rate", "channels", "codec"):
                item[key] = after[key]
            item["duration"] = round(after["duration_seconds"], 6)
            if "duration_seconds" in item:
                item["duration_seconds"] = round(after["duration_seconds"], 6)
            if "leading_silence_ms" in item:
                item["leading_silence_ms"] = round(after["leading_near_silence_ms"], 6)
            item["peak_dbfs"] = round(after["peak_dbfs"], 2)
            item["rms_dbfs"] = round(after["rms_dbfs"], 2)
            item["silence_processing"] = {
                "generator": "tools/trim_silence.py", "threshold_dbfs": -60,
                "padding_ms_minimum": 5, **record,
            }
        summary = {
            "passed": True, "custom_files_checked": len(records),
            "trimmed_files": sum(bool(row["leading_trim_ms"] or row["trailing_trim_ms"]) for row in records),
            "quality_limited_files": sum(bool(row.get("quality_limited")) for row in records),
            "leading_trim_ms": sum(row["leading_trim_ms"] for row in records),
            "trailing_trim_ms": sum(row["trailing_trim_ms"] for row in records),
            "clipped_files": 0, "native_sound_kit": "Unchanged; no bundled file",
        }
        report = {"method": {"threshold_dbfs": -60, "padding_ms_minimum": 5,
                             "gain_change": False, "interior_silence_removed": False},
                  "summary": summary, "files": records}
        if args.verify_only:
            if report != previous or catalog != json.loads(catalog_path.read_text()):
                raise ValueError("Measured audio/catalog differs from the completed report")
        else:
            for staged, destination in replacements:
                staged.replace(destination)
            catalog_path.write_text(json.dumps(catalog, indent=2, allow_nan=False) + "\n")
            REPORT.parent.mkdir(exist_ok=True)
            REPORT.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
        print(json.dumps({**summary, "encoded_this_run": len(replacements)}, indent=2))


if __name__ == "__main__":
    main()
