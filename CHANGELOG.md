# Windfury/Extra Hit Proc Sound

## 0.6.1 — based on the supplied 0.4.1 release

- Rebased the requested extra-hit and duration features onto the user's
  `WindfuryProcSound-0.4.1.zip` (SHA256
  `ae632b24186763ad1f499c13c599ca1ae2ffbc57fbdfb3d46bb283a79a946d34`).
- Restored the full 0.4.1 sound library, category dropdowns, speaker previews,
  arrow-relative menu anchors, LightsaberCrit default, and saved legacy choices.
- Preserved all 64 original catalog positions. Bonk and Fruit machine payout
  are appended as 65 and 66: 49 active choices and 17 retired legacy choices.
- Retained Other extra hit sounds, the 0.1-second duration limit, separate
  counts and selections, and the new display title. Item/Sword detection stays
  experimental and off by default. No combo feature is included.
- Kept Use Weapon cue for both limited to Weapon/Totem, preserving the independent
  Other extra hit selection. Random mode excludes retired cues.
- Applied the conservative silence check to all 65 custom originals and
  validated the resulting 585 quieter variants. Original credits/licenses and
  the speaker asset are included.
- Preserved two transient effects byte-identical when trimming would exceed
  the waveform-quality guard; per-file reasons are recorded.
- Passed 645 Lua assertions, five audio-boundary tests, baseline compatibility
  checks and all 585 volume-variant validations.

The 0.6.0 notes below describe the earlier build before this baseline correction.
Its smaller catalog counts are historical, not the contents of 0.6.1.

## 0.6.0 — 2026-11-16

- Renamed the displayed addon to **Windfury/Extra Hit Proc Sound**. The folder,
  saved-variable name, and `/wfps` command stay compatible with existing settings.
- Added **Other extra hit sounds**, a separate sound choice, toggle, preview,
  and session counter for Hand of Justice, Flurry Axe, Thrash Blade, and the
  sword extra attack from Forever's Weaponmaster talent.
- Matched those triggered spell IDs against Forever client data. Public event
  delivery and other-player isolation remain unverified; the feature is labelled
  experimental and starts off by default. Windfury keeps its existing filters.
- Added **Bonk** and **Fruit machine payout**, bringing the catalog to 23 cues.
- Removed leading/trailing near-silence from six clips, preserving audible
  attacks, decay, and internal pauses. Sixteen originals remain byte-identical.
- Added **Max sound duration**: 0.1-second steps, including 1.1, 1.2, and 2.5
  seconds. Zero means unlimited. Applies to previews and automatic sounds;
  changing the limit updates the current cue. Only the owned sound is stopped.
- Cancelled duration timers on replacement, stop, mute, disable, and reset;
  stale timers cannot cut off a later cue.
- Kept Windfury Weapon, Windfury Totem, and other extra attacks independent.
  Simultaneous different item/talent proc IDs do not suppress one another.
- Updated sound options, diagnostics, commands, source evidence, audio credits,
  and packaging checks. Rebuilt/validated the required quieter variants.
- This build does not include the separate combo feature.

Validation: 364 mocked Lua assertions, five audio-boundary tests, 22 custom
originals and 198 volume variants checked. Native-game rendering, audible
playback, and experimental event delivery still require in-game checks.
