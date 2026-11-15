# Windfury Proc Sound

A small WoW **Forever** addon with **21 selectable sound cues** for the player's Windfury Weapon and Windfury Totem procs. Includes the native Warcraft wolf howl, chicken, and an original sci-fi blade cue.

**Version 0.3.2:** a cleaner three-tab options window, compact sound grid, separate cue previews, and automatic sizing for smaller screens. All 0.3.1 sound timing, audio files, proc filters, and saved settings are preserved. Native UI rendering still needs in-game verification.

## Install on Windows

1. Exit World of Warcraft completely. A full restart ensures all audio files are available. Updating only from 0.3.1 to 0.3.2 changes no audio files, so `/reload` is sufficient when safe.
2. Extract the release ZIP. Copy its **WindfuryProcSound** folder into:
   `World of Warcraft\_forever_\Interface\AddOns\`
3. Check that the final path is `...\AddOns\WindfuryProcSound\WindfuryProcSound.toc`, not a second nested folder.
4. Start Forever. Enable **Windfury Proc Sound** in the character-selection AddOns menu.
5. Type **/wfps**, select a sound, and click **Play** to preview it. The choice saves automatically.

If building from this repository, copy the `WindfuryProcSound` subdirectory, not the whole repository.

## Upgrade from the previous name

The addon folder is now **WindfuryProcSound**. To import prior options automatically, leave the old addon installed and enabled for the first login after installing this folder. The new addon imports its settings and pauses its own automatic cues while the old addon is loaded. Then disable the old addon in the AddOns menu and reload the UI. The new settings are saved independently. Do not leave both versions enabled.

If you already removed the old addon, the new version uses defaults. Your old saved-variable file is not deleted. The old `/wfs` shortcut still works when only the new addon is enabled.

## Options

Open `/wfps`, or **Settings → AddOns → Windfury Proc Sound → Open sound options** when supported.

**Sounds tab**
- All 21 choices appear in a compact three-column grid. The window scales down if needed to fit your screen.
- Choose **Both**, **Weapon**, or **Totem**, then one of the 21 sound buttons. Each has a Play preview.
- Weapon and Totem may use different cues. Existing selections automatically migrate to both.
- **Warcraft Wolf Howl** now uses native game sound kits, replacing the non-Warcraft animal recording. No Blizzard audio is bundled. The known classic howl kit is tried first, with its modern equivalent as fallback; preview it to verify your client supports it.

**Playback tab**
- **Addon volume:** 0–100% in 10% steps. 0% mutes and stops the current addon cue. Other changes apply to subsequent cues.
- **Master / SFX channel:** keeps your current choice. Game channel/master volume and mute settings still apply.
- **Minimum gap:** 0–2 seconds in 0.1-second steps. Default 0 plays every detected proc; longer gaps limit audio without changing proc counts. Manual previews bypass this gap.
- **Random cue each proc:** off by default; avoids immediately repeating the last random cue.
- **Preview on selection:** off by default.
- **Restore defaults** resets sounds and playback settings.

**Diagnostics tab**
- Session proc counts, playback failures, muted/rate-limited cues, and readable/restricted event totals.
- **Refresh**, **Reset counters** (keeps options), and **Print status**.
- **Start trace**, **Show / stop**, and **Clear trace** for short troubleshooting captures.

Enable alerts and the Weapon/Totem toggles remain visible at the top. The selected cues, **Stop sound**, and separate **Preview Weapon / Preview Totem** buttons stay visible below every tab. Changes save automatically; Escape or **Close** dismisses the window.

The addon never changes global volume CVars. Custom sounds use pre-rendered quieter files, with the full-level custom files at 100%; native Warcraft audio uses its per-sound SoundKit volume override. Missing quiet files never fall back to full volume. Only one addon cue plays at a time.

Commands:

| Command | Action |
| --- | --- |
| `/wfps` | Open options |
| `/wfps test` / `/wfps test totem` | Preview the selected Weapon / Totem sound |
| `/wfps sound 1` | Set both proc sounds to option 1; supports numbers 1–21 or IDs |
| `/wfps sound weapon 21` / `/wfps sound totem 3` | Change one proc's sound |
| `/wfps volume 50` | Set addon volume, snapped to 10% steps |
| `/wfps stop` | Stop the current addon sound |
| `/wfps clearcounts` | Reset counters without changing options |
| `/wfps status` | Show selections, volume, counts, muted/rate-limited cues and failures |
| `/wfps on` / `/wfps off` | Enable / disable automatic cues |
| `/wfps reset` | Restore defaults and clear counters |
| `/wfps trace on` / `/wfps trace show` | Start / stop and show a short diagnostic trace |
| `/wfps trace stop` / `/wfps trace clear` | Stop / remove the trace |

## Quicker sound starts

Version 0.3.1 removes 459.8 ms of near-silence from LightsaberCrit proc and 6.1–18.3 ms from 13 other custom clips. Six clips already started promptly and were left byte-identical. At least 5 ms before the audible attack is retained to avoid abrupt starts; tails and levels are preserved. All quieter volume copies are rebuilt from these sources. The native Warcraft wolf plays from game data and cannot be trimmed by the addon.

## Proc detection

The main detector uses exact `SPELL_UPDATE_COOLDOWN` payloads:

- **Windfury Weapon:** spell `439440`, base spell nil, category `0`, recovery category `0`, item nil. Enabled only on a shaman.
- **Windfury Totem:** spell `8516`, `10608`, or `10610`, base spell nil, category `2619`, recovery category `0`, item nil. Totem recipients may be any player class. The rank-1 signature (`8516`) was observed live; higher ranks are mapped from the known proc family and are not yet live-tested.

Weapon and Totem have independent toggles and counts. The summon IDs `8512`, `10613`, `10614`, passive totem-buff IDs, and weapon-imbue application casts are excluded. Generic cooldown refreshes, GCD events, item events, unknown signatures and restricted values are ignored. No damage timing, target-hit inference, combat log, or other-player unit feed is used.

Readable player casts and newly added player auras remain a legacy fallback. The failed original implementation relied on those events alone; the isolated traces showed only cooldown notifications for the observed procs.
A 0.25-second matching window suppresses duplicate cooldown/cast/aura notifications of the same proc type. Distinct same-source notifications remain distinct. Since the game does not supply a common public identifier across the sources, extremely closely spaced incomplete event sequences can be ambiguous. Restricted values are discarded before comparison or table indexing. Full aura snapshots are not treated as new procs.

No WeakAuras, GaleCount, or other addon is required. No hidden combat data is extracted or bypassed. No networking or telemetry is included.

## Investigating missing proc sounds

1. `/wfps test`: confirms installation and audio playback.
2. On a character using Windfury Weapon, attack a target and compare observed procs with `/wfps status`.
3. Check that applying Windfury and other players' procs do not play the cue.
4. Repeat with Windfury Totem if desired.
5. If previews work but no actual procs are detected, the current client may not expose the required public notifications. A successful preview does not validate proc detection.

For a short diagnostic capture:

1. Run `/wfps trace on`, then attack until you see a Windfury proc.
2. Run `/wfps trace show` promptly. Capture stops automatically after 30 seconds.
3. Share the summary and whether you observed your own proc. Separately test with another player proccing while you do not attack.
4. `/reload` or normal logout saves the trace with addon settings. Do this when convenient, outside combat. `/wfps trace clear` removes it.

The trace keeps the latest 120 public numeric spell/category IDs and relative times. Older rows are omitted if the limit is reached. It stores no character names, GUIDs, damage amounts, or restricted payload values, and sends nothing anywhere. Tracing does not change normal sound triggers. The addon retains the two isolated cooldown signatures above. Party isolation, additional client builds and higher Totem ranks remain unverified. See `SOURCES.md`.

## Sound rights and provenance

The bundled sci-fi blade is an **original synthesized sound**, not the exact audio from the linked Wago aura or a Star Wars recording. Chicken is a real recording; the Warcraft wolf plays from the installed game. Other effects come from the creator's CC0 sound pack. The separately requested LightsaberCrit proc file is not part of that CC0/original set and is louder than the normalized cues. See `WindfuryProcSound/SOUND_CREDITS.md` for the complete asset list, source URLs, licenses, and processing notes.

## Development

- `lua tests/test.lua` with Lua 5.1+ (WoW-compatible Lua syntax), or `python3 tools/run_lua.py` with system liblua 5.3/5.4.
- `python3 tools/package.py` verifies the manifest and creates `dist/WindfuryProcSound-0.3.2.zip`.
- Tests use mocked WoW APIs. They do not emulate Blizzard's secret-value engine or verify real game delivery.
- `python3 tools/prepare_volume.py --verify-only` verifies all 180 quieter custom-file variants and their hashes, amplitude, duration and decoding.

## License

Original addon code is MIT. Nineteen custom cues have original/CC0 provenance. Native Warcraft audio is not redistributed. The additional LightsaberCrit file has unverified audio-rights coverage. See the credits. World of Warcraft and Star Wars are trademarks of their respective owners. This project is unofficial and unaffiliated.
