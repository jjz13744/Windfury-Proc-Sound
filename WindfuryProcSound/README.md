# Windfury/Extra Hit Proc Sound

WoW **Forever** sound cues for Windfury Weapon, Windfury Totem, and experimental
item/Sword extra attacks. **Version 0.6.1** adds Bonk, Fruit machine payout,
silence cleanup, and a maximum sound duration in **0.1-second steps**. There are
49 selectable cues, plus 17 preserved legacy choices. This build is based on
the supplied **0.4.1 ZIP**, including its category dropdowns, speaker previews,
expanded sound library, and LightsaberCrit default. Existing sound IDs and
numbers are unchanged. The separate combo feature is not included.

## Install / update

1. Exit WoW completely. New audio files need a full game restart.
2. Replace the `WindfuryProcSound` folder in
   `World of Warcraft\_forever_\Interface\AddOns\` with the release's folder.
3. Check for `AddOns\WindfuryProcSound\WindfuryProcSound.toc`, without an extra
   nested folder. Enable **Windfury/Extra Hit Proc Sound** in the AddOns menu.
4. Open `/wfps`. Existing saved sound/volume settings are retained.

When building from source, copy only the `WindfuryProcSound` subdirectory.
The old `WindfurySaber` addon's settings can be imported on first login if that
addon is still enabled. New automatic cues pause while it is loaded; disable
the old addon and reload after importing. `/wfs` remains an alias.

## Options

The top toggles separately control **Windfury Weapon**, **Windfury Totem**, and
**Other extra hit sounds (experimental)**. The extra-hit option starts **off**.

On **Sounds**, use the separate Weapon, Totem, and Other extra hits dropdowns.
Choose a category, then a cue; submenus contain at most ten sounds. The speaker
beside each dropdown previews its selection. Each group saves independently.
**Use Weapon cue for both** copies Weapon to Totem and leaves Other extra hits
unchanged. **Use Weapon cue for all** copies it to both other groups.
Bonk is option **65**; Fruit machine payout is **66**. Selection
previews are off by default.

The 0.4.1 library is retained: 49 active choices after adding the two new cues,
and 17 retired effects whose saved selections and original command numbers
still work. Retired choices stay out of random mode and normal browsing. A
currently selected retired cue appears under **Saved legacy cue**. New users
and Restore defaults use **LightsaberCrit proc**, as in 0.4.1.

On **Playback**:

- **Addon volume:** 0–100% in 10% steps. Zero mutes and stops the current cue.
  Custom clips use pre-rendered quieter files; native Warcraft wolf audio uses
  SoundKit's volume override. Missing quiet files never fall back to full level.
- **Audio channel:** Master or SFX. Existing game mute/volume settings apply;
  the addon never changes global volume CVars.
- **Max duration (s):** type `1.1`, `1.2`, `2.5`, etc., then Enter or click away.
  Values snap to 0.1-second steps, from 0 through 30 seconds. **0 = unlimited**.
  Applies to automatic cues and previews, including the native wolf. Changing
  it adjusts the current cue's deadline relative to when that cue started.
  Stops use zero fade padding; the game executes timers on frame boundaries.
  Shorter files finish naturally. New cues cancel old deadlines.
- **Minimum gap:** 0–2 seconds in 0.1-second steps. Limits audio, not proc counts.
  Default 0 plays every detected proc; previews bypass this gap.
- **Random cue each proc:** avoids immediately repeating the last random cue.
- **Restore defaults:** resets selections and playback settings, including the
  duration cap and the experimental extra-hit toggle.

Only one addon cue plays at a time. Closing the options saves changes
automatically. Escape closes the window (or cancels an unfinished duration edit).

**Diagnostics** shows session counts by group, playback failures, suppressed
cues, and restricted/readable event totals. It also offers a short public-event
trace. Reset counters keeps options.

## Proc detection

Windfury keeps its existing exact `SPELL_UPDATE_COOLDOWN` filters:

| Type | Spell ID | Category | Class |
| --- | --- | --- | --- |
| Windfury Weapon | 439440 | 0 | Shaman |
| Windfury Totem | 8516, 10608, 10610 | 2619 | Any player class |

Both require base spell nil, recovery category 0, and item nil. Rank-1 Totem
and Weapon signatures were observed in prior isolated live traces; higher
Totem ranks are mapped from the known proc family. Generic refreshes, GCD and
item updates, imbue casts, totem summons, and passive buff IDs are excluded.

**Other extra hit sounds** groups these triggered spells under one sound choice:

| Source | Extra-attack spell |
| --- | --- |
| Weaponmaster's Sword Specialization effect (warrior only) | 1257049 |
| Hand of Justice (any player class) | 15601 |
| Flurry Axe (any player class) | 18797 |
| Thrash Blade (any player class) | 21919 |

These identities are verified against Forever build **1.60.1.70938** client
tables: each grants one extra attack. Hand of Justice's equipped passive
15600 is deliberately excluded. Forever's Sword effect is part of Weaponmaster;
the old Classic talent/application IDs are not treated as attacks.

**Event delivery is unverified for these four extra-hit spells.** With the
experiment enabled, the addon tries exact cooldown candidates
`(procID, nil, 0, 0, nil)` and readable player casts/newly added player auras.
The zero-category event shape is an inference, not a recorded Sword/item
payload. Client spell data cannot prove that a public addon event is emitted.
No warrior/item live test or other-player isolation test is claimed. See
`SOURCES.md` for the source chain and the distinction between data and traces.

Across all groups, a 0.25-second window matches duplicate notifications from
different sources. Distinct same-source notifications stay distinct. Different
item/Sword IDs cannot suppress one another; Windfury groups remain separate.
There is no public shared event identifier, so incomplete closely spaced event
sequences can still be ambiguous. Full aura snapshots and restricted values
are ignored. No combat log, target-hit inference, networking or telemetry is used.

## Commands / quick checks

| Command | Action |
| --- | --- |
| `/wfps` | Open options |
| `/wfps test` / `test totem` / `test extra` | Preview a group's selection |
| `/wfps sound 65` | Set all three groups to Bonk and preview |
| `/wfps sound extra 66` | Set only Other extra hits to Fruit machine payout |
| `/wfps duration 1.2` | Cap cues at 1.2 seconds |
| `/wfps duration 0` | Remove the duration cap |
| `/wfps extra on` / `extra off` | Enable / disable experimental other extra hits |
| `/wfps volume 50` | Set addon-only volume |
| `/wfps stop` | Stop the owned cue and cancel its deadline |
| `/wfps status` | Show selections, duration, counters and experiment state |
| `/wfps clearcounts` | Clear counters, keep options |
| `/wfps on` / `off` | Enable / disable automatic cues |
| `/wfps reset` | Restore defaults and clear counters |
| `/wfps trace on` / `trace show` | Start / stop and show a diagnostic trace |
| `/wfps trace stop` / `trace clear` | Stop / remove the trace |

For a smell test, preview the two new cues, then set a fractional duration and
preview Fruit machine payout again. A working preview validates playback only.
For experimental detection, enable Other extra hit sounds and capture a short
trace while using one of the listed items or Weaponmaster with a sword. Compare
an isolated test with another player proccing while you are idle.

Traces stop after 30 seconds and retain the latest 120 public numeric IDs and
relative times. `/reload` or normal logout saves them. They contain no names,
GUIDs, damage amounts or restricted payload values, and are never transmitted.

## Sound processing and provenance

The complete 0.4.1 library is retained, with the two requested uploads appended.
All 65 custom originals were checked. Seventeen baseline clips had 1,671.791 ms
of trailing padding removed in total; 46 baseline originals remain byte-identical.
Explosion blast and Whip crack retain about 40 ms of tail padding each because
a lossy re-encode exceeded the waveform-quality guard. The two new cues retain
their previously reviewed trims (Bonk about 0.402 s; Fruit machine about 3.702 s).
Trimming checks padding at both ends using a -60 dBFS
threshold across every channel, retaining at least 5 ms around the first/last
audible sample. Interior pauses and audible decay remain. A separate immutable
archive is used for this 0.4.1-based pass. The native wolf remains game-owned
and has no bundled file to edit. See the current validation report and each
catalog entry for exact trim amounts and output hashes.

All original 0.4.1 source credits, asset licenses, category labels and retired
IDs are preserved. See `EXPANSION_CREDITS.md`, `LEGACY_AUDIO_PROVENANCE.md`,
`SOUND_CREDITS.md`, and `sound-catalog.json`. The two user-requested YouTube
uploads have unverified redistribution rights and are not covered by the code's
MIT license. This build contains 65 custom originals and 585 quieter variants.

## Development

- `lua tests/test.lua` (Lua 5.1+) runs 645 assertions using the real modules
  with mocked WoW APIs.
  `python tools/run_lua.py` also supports system liblua 5.3/5.4.
- `python tests/test_audio.py` tests conservative edge trimming (numpy required).
- `python tools/trim_silence.py --verify-only` checks the immutable trim archive.
- `python tools/prepare_volume.py --verify-only` checks all volume banks.
- `python tools/package.py` validates catalog/hashes/TOCs and builds
  `dist/WindfuryProcSound-0.6.1.zip`.

Mocked tests do not emulate the client's secret-value engine or establish real
event delivery, native audio availability or UI rendering. Original code is MIT;
see the audio credits for asset-specific terms. This project is unofficial.
