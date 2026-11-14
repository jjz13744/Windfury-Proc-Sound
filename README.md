# Windfury Saber

A small WoW **Forever** addon with **20 selectable sound cues** for the player's Windfury Weapon and Windfury Totem procs. Includes wolf howl, chicken, and an original sci-fi blade cue.

**Status: experimental, not yet tested inside the live game.** Automated Lua tests cover the event logic, settings, sound selection, and mocked UI. The current Forever API can restrict combat-event data. The addon skips restricted values and cannot promise a cue for every proc in every client build.

## Install on Windows

1. Exit World of Warcraft completely.
2. Extract the release ZIP. Copy its **WindfurySaber** folder into:
   `World of Warcraft\_forever_\Interface\AddOns\`
3. Check that the final path is `...\AddOns\WindfurySaber\WindfurySaber.toc`, not a second nested folder.
4. Start Forever. Enable **Windfury Saber** in the character-selection AddOns menu.
5. Type **/wfs**, select a sound, and click **Play** to preview it. The choice saves automatically.

If building from this repository, copy the `WindfurySaber` subdirectory, not the whole repository.

## Options

- **20 sound buttons**, each with a separate Play preview.
- Enable/disable all proc cues.
- Toggle Windfury Weapon and Windfury Totem separately.
- Choose **Master** (default) or **SFX** audio channel. The addon never changes game volume, CVars, or default sounds.
- Type `/wfs` or open **Settings → AddOns → Windfury Saber → Open sound options** when that Settings API is available.

Commands:

| Command | Action |
| --- | --- |
| `/wfs` | Open options |
| `/wfs test` | Preview selected sound, even if automatic cues are disabled |
| `/wfs sound 1` | Select and preview sound 1; numbers 1–20 are supported |
| `/wfs status` | Show event registration, readable/restricted candidate counts, proc count and playback failures |
| `/wfs on` / `/wfs off` | Enable or disable automatic cues |
| `/wfs reset` | Restore default options and clear session counters |

Only one cue plays at a time. A new cue stops the preceding one to prevent audio stacking. Short sound previews can still be loud depending on your game volume.

## Proc detection

The detector uses `UNIT_SPELLCAST_SUCCEEDED` registered for the player, plus newly added player `UNIT_AURA` entries as a fallback. Known proc IDs come from a current Forever-specific addon, GaleCount. Applying the weapon imbue or dropping the totem does **not** trigger a sound. Another unit's cast is ignored. The addon does not read the combat log or damage numbers.

A 0.25-second matching window suppresses duplicate cast/aura notifications of the same proc. Distinct same-source notifications remain distinct. Since the game does not supply a common public identifier across both sources, extremely closely spaced incomplete event sequences can be ambiguous. Restricted values are discarded before comparison or table indexing. Full aura snapshots are not treated as new procs.

No WeakAuras, GaleCount, or other addon is required. No hidden combat data is extracted or bypassed. No networking or telemetry is included.

## In-game check still needed

1. `/wfs test`: confirms installation and audio playback.
2. On a character using Windfury Weapon, attack a target and compare observed procs with `/wfs status`.
3. Check that applying Windfury and other players' procs do not play the cue.
4. Repeat with Windfury Totem if desired.
5. If previews work but no actual procs are detected, the current client may not expose the required public notifications. A successful preview does not validate proc detection.

`/wfs status` reports counters only, not character information. It does not log private combat payloads. Report client version and these counters when diagnosing compatibility.

## Sound rights and provenance

The bundled sci-fi blade is an **original synthesized sound**, not the exact audio from the linked Wago aura or a Star Wars recording. Wolf and chicken are real recordings. Other effects come from the creator's CC0 sound pack. See `WindfurySaber/SOUND_CREDITS.md` for the complete asset list, source URLs, licenses, and processing notes.

The original request referenced <https://wago.io/wqR5gKz0o>. That page could not be read during development, so its code or exact audio is not included. A LightsaberCrit audio file was inspected during research but is **not distributed**, because its underlying audio provenance was unclear even though the addon project lists MIT.

## Development

- `lua tests/test.lua` with Lua 5.1+ (WoW-compatible Lua syntax), or `python3 tools/run_lua.py` with system liblua 5.3/5.4.
- `python3 tools/package.py` verifies the manifest and creates `dist/WindfurySaber-0.1.0.zip`.
- Tests use mocked WoW APIs. They do not emulate Blizzard's secret-value engine or verify real game delivery.
- `ffmpeg`/`ffprobe` can verify that all bundled OGG files decode successfully.

## License

Original addon code is MIT. Audio has separate CC0/public-domain provenance documented in the credits. World of Warcraft and Star Wars are trademarks of their respective owners. This project is unofficial and unaffiliated.
