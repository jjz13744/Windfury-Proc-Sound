# Verification report

2026-11-14, version 0.2.0

Passed locally:
- 118 assertions in Lua 5.4, using WoW-compatible Lua syntax and mocked WoW APIs.
- All seven known proc IDs; no cue for applying Windfury Weapon or placing its totem.
- Only player events; independent weapon/totem settings; disabled state.
- Cast/aura duplicate suppression in either arrival order, token duplicates, and rapid distinct casts.
- Secret-marker values skipped in spell IDs, unit tokens, cast tokens and aura arrays; full aura snapshots ignored.
- All 21 unique catalog entries and audio files, saved-option normalization, selection, preview, reset and status.
- Mocked options-window open and registration, sound failure reporting and counter reset.
- The 21st option has its own non-overlapping button; window grows for 11 rows.
- Product/folder/TOC/commands renamed; legacy settings import when available; new settings take precedence; automatic cues pause while legacy addon runs to avoid duplicates.
- LightsaberCrit proc selected by number and ID and plays the exact expected filename.
- All 21 OGGs decode with ffmpeg; source manifests verify their hashes.
- ZIP integrity, both TOCs, all referenced Lua files and exact one-folder install layout.
- Independent static review of detection, secret guards and UI. Its reset-counter finding was fixed and regression tested.

Not tested:
- No live WoW Forever client was available. Actual proc notifications, secret-value semantics and native UI layout/templates remain unverified.
- No end-to-end Windows installation was performed; the user's desktop was not changed.
- No hosted CI workflow was added or run.

The original Wago page was unreadable during research. Its exact audio and trigger are not verified. Version 0.2.0 includes the separate LightsaberCrit OGG at owner request; audio-specific license coverage remains unverified. See README and sound credits for the replacement audio's provenance.
