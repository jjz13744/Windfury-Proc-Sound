# Verification report

2026-11-15, version 0.2.2

Passed locally:
- 192 assertions using Lua 5.4 and mocked WoW APIs.
- Exact replay of isolated Weapon trace: two 439440/nil/0/0/nil events produce two cues; unrelated 16257 refresh is ignored.
- Exact replay of isolated Totem trace: two 8516/nil/2619/0/nil events produce two cues; unrelated 16257 refreshes are ignored.
- Separate Weapon/Totem counts, independent options and global disabled state.
- Weapon signature shaman-only; Totem signature available to a recipient of any class.
- All five event fields checked for secret values before comparisons; nil and zero distinguished.
- Imbue-application, totem-summon, passive-buff, general-refresh, GCD, item and wrong-category payloads rejected.
- Legacy cast/aura events deduplicate against the matching proc type's cooldown event; distinct rapid same-source notifications are retained.
- Trace stop/show/timeout no longer remove the automatic cooldown listener.
- Original 21 sound options, selected audio/channel, previews, UI, saved-option migration and restriction-handling regressions.
- ZIP integrity, both Interface 16001 manifests and exact one-folder install layout.

Live evidence:
- The user reported two Weapon-only procs and supplied a trace containing the exact Weapon signature twice, with no omitted rows.
- A separate Totem-only two-proc test contained the exact Totem signature twice, with no omitted rows.
- Both isolated tests lacked Windfury cast/aura notifications, explaining the original filter failure.

Remaining validation:
- The new version's audible playback has not yet been confirmed in game.
- Other-player negative tests, higher Totem ranks10608/10610 and other client builds remain unverified.
- Mock secret markers are not Blizzard's actual restricted-value engine.
- No hosted CI workflow exists or ran.
