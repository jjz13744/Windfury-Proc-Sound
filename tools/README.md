# Audio reproduction (optional)

The addon ships ready-to-play OGGs. Python is not required to use it.

`prepare_audio.py` preserves the full synthesis recipe for the original sci-fi blade and processing recipe for the other cues. It requires Python 3, numpy, scipy and ffmpeg. Before running, obtain the documented originals from their primary creators and arrange them under repository `sources/`:

- `wolf-fws.ogg`: https://commons.wikimedia.org/wiki/File:Wolf_howls.ogg
- `chicken.mp3`: the author's public HQ preview linked in `WindfuryProcSound/sound-catalog.json`.
- `kenney_digital/`: extract the original MP3 files from the Digital_SFX_Set.zip archive linked in the catalog.

Run `python3 tools/prepare_audio.py`. It writes a separate top-level `sounds/` output and manifest for review. It does not replace installed addon files. Vorbis bitstreams may differ across encoder versions even with identical source waveforms.

The shipped audio metadata and original-source licenses are in `WindfuryProcSound/SOUND_CREDITS.md`. Do not replace those credits if substituting new audio.
