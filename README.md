# Windfury Proc Sound

A small WoW **Forever** addon with **21 selectable sound cues** for the player's Windfury Weapon and Windfury Totem procs. Includes wolf howl, chicken, and an original sci-fi blade cue.

**Status: experimental, not yet tested inside the live game.** Automated Lua tests cover the event logic, settings, sound selection, and mocked UI. The current Forever API can restrict combat-event data. The addon skips restricted values and cannot promise a cue for every proc in every client build.

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

Only one cue plays at a time. A new cue stops the preceding one to prevent audio stacking. Short sound previews can still be loud depending on your game volume.

## Proc detection

The detector uses `UNIT_SPELLCAST_SUCCEEDED` registered for the player, plus newly added player `UNIT_AURA` entries as a fallback. Known proc IDs come from a current Forever-specific addon, GaleCount. Applying the weapon imbue or dropping the totem does **not** trigger a sound. Another unit's cast is ignored. The addon does not read the combat log or damage numbers.

A 0.25-second matching window suppresses duplicate cast/aura notifications of the same proc. Distinct same-source notifications remain distinct. Since the game does not supply a common public identifier across both sources, extremely closely spaced incomplete event sequences can be ambiguous. Restricted values are discarded before comparison or table indexing. Full aura snapshots are not treated as new procs.

No WeakAuras, GaleCount, or other addon is required. No hidden combat data is extracted or bypassed. No networking or telemetry is included.

## In-game check still needed

1. `/wfps test`: confirms installation and audio playback.
2. On a character using Windfury Weapon, attack a target and compare observed procs with `/wfps status`.
3. Check that applying Windfury and other players' procs do not play the cue.
4. Repeat with Windfury Totem if desired.
5. If previews work but no actual procs are detected, the current client may not expose the required public notifications. A successful preview does not validate proc detection.

`/wfps status` reports counters only, not character information. It does not log private combat payloads. Report client version and these counters when diagnosing compatibility.

## Sound rights and provenance

The bundled sci-fi blade is an **original synthesized sound**, not the exact audio from the linked Wago aura or a Star Wars recording. Wolf and chicken are real recordings. Other effects come from the creator's CC0 sound pack. The separately requested LightsaberCrit proc file is not part of that CC0/original set and is louder than the normalized cues. See `WindfuryProcSound/SOUND_CREDITS.md` for the complete asset list, source URLs, licenses, and processing notes.

## Development

- `lua tests/test.lua` with Lua 5.1+ (WoW-compatible Lua syntax), or `python3 tools/run_lua.py` with system liblua 5.3/5.4.
- `python3 tools/package.py` verifies the manifest and creates `dist/WindfuryProcSound-0.2.0.zip`.
- Tests use mocked WoW APIs. They do not emulate Blizzard's secret-value engine or verify real game delivery.
- `ffmpeg`/`ffprobe` can verify that all bundled OGG files decode successfully.

## License

Original addon code is MIT. The original 20 sounds have separate original/CC0/public-domain provenance. The additional LightsaberCrit file has unverified audio-rights coverage. See the credits. World of Warcraft and Star Wars are trademarks of their respective owners. This project is unofficial and unaffiliated.
