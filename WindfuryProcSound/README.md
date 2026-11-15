# Windfury Proc Sound

A small WoW **Forever** addon with **21 selectable sound cues** for the player's Windfury Weapon and Windfury Totem procs. Includes wolf howl, chicken, and an original sci-fi blade cue.

**Status: 0.2.2 event-detection fix.** Separate live traces showed two Weapon procs with two matching cooldown events, then two Totem procs with two different matching events. This version uses those distinct signatures. Automated replays pass; audible playback with this version and isolation from other players still need live verification.

## Install on Windows

1. Exit World of Warcraft completely.
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

- **21 sound buttons**, each with a separate Play preview.
- Enable/disable all proc cues.
- Toggle Windfury Weapon and Windfury Totem separately.
- Choose **Master** (default) or **SFX** audio channel. The addon never changes game volume, CVars, or default sounds.
- Type `/wfps` or open **Settings → AddOns → Windfury Proc Sound → Open sound options** when that Settings API is available.

Commands:

| Command | Action |
| --- | --- |
| `/wfps` | Open options |
| `/wfps test` | Preview selected sound, even if automatic cues are disabled |
| `/wfps sound 1` | Select and preview sound 1; numbers 1–21 are supported |
| `/wfps status` | Show event registration, readable/restricted candidate counts, proc count and playback failures |
| `/wfps on` / `/wfps off` | Enable or disable automatic cues |
| `/wfps reset` | Restore default options and clear session counters |
| `/wfps trace on` | Capture up to 30 seconds of public diagnostic events |
| `/wfps trace show` | Stop and show the latest trace summary |
| `/wfps trace stop` / `/wfps trace clear` | Stop capture / remove the captured trace |

Only one cue plays at a time. A new cue stops the preceding one to prevent audio stacking. Short sound previews can still be loud depending on your game volume.

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

The trace keeps the latest 120 public numeric spell/category IDs and relative times. Older rows are omitted if the limit is reached. It stores no character names, GUIDs, damage amounts, or restricted payload values, and sends nothing anywhere. Tracing does not change normal sound triggers. Version 0.2.2 uses the two isolated cooldown signatures above. Party isolation, additional client builds and higher Totem ranks remain unverified. See `SOURCES.md`.

## Sound rights and provenance

The bundled sci-fi blade is an **original synthesized sound**, not the exact audio from the linked Wago aura or a Star Wars recording. Wolf and chicken are real recordings. Other effects come from the creator's CC0 sound pack. The separately requested LightsaberCrit proc file is not part of that CC0/original set and is louder than the normalized cues. See `WindfuryProcSound/SOUND_CREDITS.md` for the complete asset list, source URLs, licenses, and processing notes.

## Development

- `lua tests/test.lua` with Lua 5.1+ (WoW-compatible Lua syntax), or `python3 tools/run_lua.py` with system liblua 5.3/5.4.
- `python3 tools/package.py` verifies the manifest and creates `dist/WindfuryProcSound-0.2.2.zip`.
- Tests use mocked WoW APIs. They do not emulate Blizzard's secret-value engine or verify real game delivery.
- `ffmpeg`/`ffprobe` can verify that all bundled OGG files decode successfully.

## License

Original addon code is MIT. The original 20 sounds have separate original/CC0/public-domain provenance. The additional LightsaberCrit file has unverified audio-rights coverage. See the credits. World of Warcraft and Star Wars are trademarks of their respective owners. This project is unofficial and unaffiliated.
