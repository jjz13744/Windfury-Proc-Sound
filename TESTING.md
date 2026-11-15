# Verification report

2026-11-15, version 0.2.1 diagnostic build

Passed locally:
- 137 assertions using Lua 5.4 and mocked WoW APIs.
- Original settings, all 21 sound files, selection, preview, disabled state, options layout, rename migration and cast/aura filtering regressions.
- Opt-in 30-second trace; last 120 rows retained; old rows counted as omitted.
- Secret values replaced with markers before comparison, serialization or display; nil and zero kept distinct.
- Cooldown signature 439440, nil, 0, 0, nil recorded with all five fields but never counted as a proc or used for playback.
- Readable updated-aura spell IDs are diagnostic only; neither updates nor diagnostic read failures change normal added-aura processing.
- Trace stops/unregisters its cooldown event on show, stop and timeout; clear/reset remove it.
- Saved trace normalization restores inactive; names, cast GUIDs and damage are not stored.
- Independent review found an optional trace field could interrupt added-aura processing. It was isolated and covered by two regression tests.
- ZIP integrity, both Interface 16001 manifests, exact single-folder layout and all referenced Lua/audio files.

Live evidence and remaining limits:
- The installed 0.2.0 files were verified against the release ZIP on Windows. The user's screenshot showed 0 detected procs, 22 readable candidates and no playback failures after a reported proc.
- Version 0.2.1 adds diagnostics, not a confirmed detection fix. The cooldown candidate requires own-proc comparison and an other-player negative test. No in-game trace from this build has been reviewed yet.
- Mock secret markers are not Blizzard's actual restricted-value engine. Event delivery and native UI remain outside the local test environment.
- No hosted CI workflow exists or ran.
