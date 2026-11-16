"""Import the two requested YouTube sound effects from local WebM downloads.

Obtain sources with yt-dlp --write-info-json -f bestaudio, using the output
template audio-assets/requested/%(id)s.%(ext)s. This tool does not download.
Requires numpy, FFmpeg/libvorbis and ffprobe. Then run trim_silence.py and
prepare_volume.py. Source downloads and metadata stay outside the addon.
"""

import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np

from trim_leading_silence import decode, encode

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "WindfuryProcSound"
REQUESTS = (
    ("6TP0abZdRXg", "bonk", "Bonk"),
    ("NDqVyfjcckI", "fruit_machine", "Fruit machine payout"),
)


def main():
    catalog_path = ADDON / "sound-catalog.json"
    catalog = json.loads(catalog_path.read_text())
    for video, sound_id, name in REQUESTS:
        source = ROOT / "audio-assets" / "requested" / f"{video}.webm"
        metadata_path = source.with_suffix(".info.json")
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        if metadata["id"] != video:
            raise ValueError(f"Wrong source metadata: {metadata_path}")
        source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        target = ADDON / "sounds" / f"{sound_id}.ogg"
        existing = next((item for item in catalog if item["id"] == sound_id), None)
        if existing:
            if (existing.get("source_sha256") != source_hash or
                    hashlib.sha256(target.read_bytes()).hexdigest() != existing["sha256"]):
                raise ValueError(f"Existing source/output changed: {sound_id}")
            print(f"Already imported: {name}")
            continue
        pcm = np.frombuffer(subprocess.check_output([
            "ffmpeg", "-v", "error", "-xerror", "-i", str(source),
            "-map", "0:a:0", "-ac", "1", "-ar", "44100", "-f", "f32le", "pipe:1",
        ]), dtype="<f4").reshape(-1, 1).astype(np.float64)
        if not len(pcm) or not np.isfinite(pcm).all():
            raise ValueError(f"Invalid source audio: {source}")
        # Attenuate loud uploads to the existing pack's ceiling; never amplify.
        gain = min(1.0, 10 ** (-4.5 / 20) / float(np.max(np.abs(pcm))))
        encode(pcm * gain, 44100, 1, target)
        _, measured = decode(target)
        catalog.append({
            "id": sound_id, "name": name, "filename": target.name, "file": target.name,
            "duration": round(measured["duration_seconds"], 6), "sample_rate": 44100,
            "channels": 1, "codec": "Vorbis", "bytes": measured["bytes"],
            "sha256": measured["sha256"], "peak_dbfs": round(measured["peak_dbfs"], 2),
            "rms_dbfs": round(measured["rms_dbfs"], 2), "author": metadata["uploader"],
            "original_title": metadata["title"], "source_url": metadata["webpage_url"],
            "source_filename": source.name, "source_sha256": source_hash,
            "license": "YouTube upload; redistribution rights unverified; not covered by the code license",
            "license_url": None, "source_description": metadata.get("description", ""),
            "changes": f"Decoded upload, converted to mono 44.1 kHz; attenuation {20 * np.log10(gain):.3f} dB (never amplified); Vorbis quality 10. Silence trimming recorded separately.",
        })
        print(f"Imported {name}: {measured['duration_seconds']:.3f}s")
    catalog_path.write_text(json.dumps(catalog, indent=2, allow_nan=False) + "\n")


if __name__ == "__main__":
    main()
