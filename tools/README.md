# Audio reproduction (optional)

The addon ships ready-to-play OGGs. Python is not required to use it.

`prepare_audio.py` preserves the full synthesis recipe for the original sci-fi blade and processing recipe for the other cues. It requires Python 3, numpy, scipy and ffmpeg. Before running, obtain the documented originals from their primary creators and arrange them under repository `sources/`:

- Historical wolf recipe only: `wolf-fws.ogg` from https://commons.wikimedia.org/wiki/File:Wolf_howls.ogg. This recording is no longer used by the addon.
- `chicken.mp3`: the author's public HQ preview linked in `WindfuryProcSound/sound-catalog.json`.
- `kenney_digital/`: extract the original MP3 files from the Digital_SFX_Set.zip archive linked in the catalog.

Run `python3 tools/prepare_audio.py`. It writes a separate top-level `sounds/` output and manifest for review. It does not replace installed addon files. Vorbis bitstreams may differ across encoder versions even with identical source waveforms.

The shipped audio metadata and original-source licenses are in `WindfuryProcSound/SOUND_CREDITS.md`. Do not replace those credits if substituting new audio.

## Addon-only volume

`python3 tools/prepare_volume.py` renders nine gain banks from the 20 custom originals already in the addon. `--verify-only` checks the packaged banks against `volume_manifest.json`. Each 10â€“90% level is rendered directly from the original with linear sample-amplitude gain, never normalized. 100% originals are unchanged; 0% is handled by skipping playback. Native Warcraft Wolf Howl has no bundled file and uses the game's SoundKit volume override.

## Leading-silence cleanup

Run `python3 tools/trim_leading_silence.py`, then regenerate volume banks with `python3 tools/prepare_volume.py`. The trim tool needs numpy as well as FFmpeg. It creates a local immutable archive under `audio-assets/before-leading-trim`, preserves at least 5 ms pre-roll, removes only leading samples below âˆ’60 dBFS, and does not touch tails or native game sounds. Re-running never progressively trims an already-processed file. `--verify-only` checks against that local archive/report. Reproducing the first cleanup requires the pre-trim 0.3.0 assets from commit 668da5ee01671c42bd02dd99dff8343acfc67c34; current release files are already processed.


## Requested clips and two-ended silence trimming (0.6.0)

Use yt-dlp --write-info-json -f bestaudio with output template
`audio-assets/requested/%(id)s.%(ext)s` for the two URLs in SOUND_CREDITS.md.
Then run `python tools/import_requested_sounds.py`,
`python tools/trim_silence.py`, and `python tools/prepare_volume.py`.
The import needs numpy and FFmpeg/ffprobe, and keeps source metadata outside
the addon. The trim tool archives every input under audio-assets/before-edge-trim
and refuses unknown changed outputs. `--verify-only` remeasures the completed
report without encoding. It removes padding from BOTH ends, retaining at least
5 ms around samples above -60 dBFS across any channel. No interior silence,
audible tail, gain, channel layout or sample rate is changed by trimming.
The older trim_leading_silence.py is a historical 20-source recipe; use the
new trim_silence.py for this expanded catalog. The volume tool derives its
source set from the catalog, reuses previously validated variants only when
both hashes match, and validates all outputs even when reused.


## 0.4.1 baseline correction (0.6.1)

The current catalog preserves all 64 entries from the supplied 0.4.1 release,
including 17 retired cues; the two new sounds append as 65/66. The current trim
tool uses `audio-assets/before-edge-trim-041` and records
`references/silence_trim_validation_041.json`, independently of the earlier
22-source pass. All 65 originals and 585 volume variants are validated. A trim
candidate that exceeds the waveform-quality guard is explicitly recorded as
quality-limited and its original bytes are preserved. The guard is never relaxed.
See the per-file catalog fields for processing history; original release credits
and manifests remain as provenance, while current sound-catalog/volume hashes
describe the current audio.
