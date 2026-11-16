# Verification report

## 2026-11-16 — version 0.6.1, rebased on the supplied 0.4.1 ZIP

Source archive SHA256:
`ae632b24186763ad1f499c13c599ca1ae2ffbc57fbdfb3d46bb283a79a946d34`.
This corrects the earlier 0.6.0 baseline. The old reports below are historical.

- 645 Lua 5.1 assertions passed using the real runtime and UI callbacks. They
  cover all prior detection/duration behavior plus the preserved 0.4.1 defaults,
  all 64 stable catalog positions, retired saved choices, active-only random mode,
  category pagination, dropdown arrow anchoring, and independent Extra controls.
- Complete library retained: 66 catalog entries, 49 active, 17 retired, 65 custom
  originals. Bonk/Fruit append as positions 65/66. No combo or Audit module.
- Separate baseline proof checks exact input ZIP integrity/hash, all original IDs,
  files, categories, retired flags and rights fields, the TOC load list and default,
  and byte-identical baseline media, licenses and original provenance documents.
  Its receipt is shipped as BASELINE.json.
- Five audio-boundary tests passed. All 65 originals checked at -60 dBFS with
  >=5 ms padding around the audible signal. Seventeen baseline clips lost
  1,671.791 ms of trailing padding; 46 baseline originals remain byte-identical.
  The two appended clips preserve their earlier reviewed trims.
- Explosion blast and Whip crack retain 39.637/40.839 ms of candidate trailing
  padding: re-encoding produced SNR 33.10/34.51 dB, below the unchanged 35 dB
  quality guard. Originals remain byte-identical; no threshold was relaxed.
- Trim verify-only encoded zero files. All 585 attenuation variants passed hash,
  decoding, gain, layout and duration checks, with no clipping and at most one
  decoded sample difference. 414 unchanged-source variants were reused.
- Package validates both TOCs, complete file layout, all catalog/audio hashes and
  ZIP integrity. New files require a full game restart after installation.

Native-game layout/audio and experimental item/Sword event delivery still need
live testing. Client-data identities do not prove that the inferred cooldown
payloads are emitted or isolated from other players.


## 2026-11-16 — version 0.6.0

Windfury/Extra Hit Proc Sound, built from the repository source. The separately
installed 0.5.1 combo/audit expansion was intentionally not merged at the user's
request. Folder and saved-variable names remain compatible.

Passed locally:

- 364 assertions using the actual addon modules and Lua 5.1 (Lupa), with mocked
  game APIs/UI. Existing Windfury trace replays remain covered.
- New extra-hit category defaults off; independent settings, previews, counters,
  and enable/disable behavior. Hand of Justice's passive 15600, talent/application
  IDs and Classic-only 16459 are rejected. Item proc IDs work on non-warriors;
  Weaponmaster 1257049 is warrior-gated on all candidate routes.
- All four candidate IDs checked through actual cooldown handlers. Secret fields,
  nonmatching payloads, other-unit casts and full aura snapshots are rejected.
  These are synthetic candidate tests, NOT live item/Sword trace replays.
- Cross-source duplicates of one item proc are suppressed; distinct item/talent
  IDs in the same interval remain separate. Windfury counters remain independent.
- Duration cap accepts tenths (1.1, 1.2, 2.5), clamps/sanitizes settings, and stops
  only the owned sound with zero fade padding. Previews, automatic cues and native
  SoundKits are covered. Replacement, mute, disable, reset and unlimited cancel
  deadlines. Stale callbacks cannot stop a replacement cue. Changing the limit
  accounts for elapsed playback. Real text-input callbacks are exercised.
- Five synthetic audio-boundary tests cover both ends, multichannel attacks,
  retained interior gaps, short padding, and all-silent rejection.
- All 22 custom originals decoded and measured. Six trimmed, sixteen unchanged;
  854.898 ms leading and 580.862 ms trailing near-silence removed in total.
  At least 5 ms around samples above -60 dBFS retained. Changed outputs have exact
  planned frame counts, waveform correlation >=0.9999, SNR >=37.38 dB, gain error
  <0.085 dB, and no clipping. A verification run encoded zero files.
- 198 attenuation variants verified against hashes, decoding, levels, channels,
  sample rates and durations. No clipping. Maximum decoded frame difference:
  one sample. The 144 banks for unchanged old sources retain their original bytes.
- Package validates both TOCs, catalog order, 23 cues, 22 originals, 198 variants,
  every audio hash, one-folder install layout, and ZIP integrity.

Research validates spell identities, not public event delivery. The inferred
zero-category cooldown payloads for item/Sword procs are unverified. Native UI,
real timer/frame behavior, sound-kit availability, audible output and negative
other-player tests still require the user's game client. Existing Windfury live
evidence and limitations below remain applicable.

2026-11-15, version 0.3.2

Passed locally:
- 272 Lua assertions using the real addon modules with mocked WoW APIs.
- Existing exact Weapon/Totem trace replays, all event filtering, secret guards, independent toggles and duplicate suppression remain covered.
- Old shared sound selections migrate to both new per-proc choices. Separate UI and slash selections preserve the other choice.
- Volume snaps to 10% steps;0% skips playback and stops only the owned handle;100% uses unchanged custom originals; lower levels use the matching variant path.
- Native Warcraft howl uses the documented sixth SoundKit volume override argument. Classic-kit failure tries the known modern equivalent; failure of both reports unavailable, without substituting unrelated audio.
- Missing quiet files never fall back to a full-volume original.
- Random cues avoid immediate repeats. Preview ignores random mode, respects volume and bypasses the automatic cue interval.
- Minimum-gap setting limits audio, not proc counts; reset counters keeps settings; disable/stop stops the owned sound.
- Real UI callbacks exercised for tabs, sliders, selection previews, Close/reopen and reset. Refresh guards prevent slider recursion. Static review confirmed control bounds within 640×600. Smaller-screen scaling and three-tab visibility are covered.
- Independent UI review found no functional blockers. Its 28 additional checks cover diagnostics callbacks, tab-state retention, repeated navigation, and settings preservation (300 total assertions including the repository suite).
- Internal layout approximations were inspected for all three tabs; these are not native-game screenshots. Native font metrics and rendering still require in-game validation.
- All 200 bundled audio files are byte-identical to the 0.3.1 release. Only UI code, UI tests, version labels, and documentation changed.
- Package verifies both TOCs, one-folder install layout,21catalog choices,20custom originals,180volume variants, exact SHA256hashes and ZIP integrity.

Audio measurements:
-14 custom sources have validated leading-silence trims;6 remain byte-identical. All original inputs are preserved outside the addon.
- All180derived files decode; channels and sample rates match originals.
- No clipping. Every trimmed original retains the exact expected decoded frame count. All but one volume variant agree within one sample; the10% LightsaberCrit variant has128samples(2.90ms) of codec tail-padding difference, below−105dBFS after gain.
- Repeated renders produce identical output hashes with the same tools.
- See volume_manifest.json for per-file amplitude, timing and hash checks.

Live evidence and limits:
- Prior isolated live traces contained exactly two Weapon events for two reported Weapon procs, and two Totem events for two reported Totem procs. These filters are unchanged.
- New volume levels, native howl availability, and native UI layout have not been verified inside the running Forever client.
- Known classic and modern wolf-howl kits are used; the Forever SoundKit table could not be independently inspected. Preview validation is required.
- Other-player isolation, higher Totem ranks10608/10610 and other client builds remain unverified.
- No hosted CI workflow exists or ran.

Leading-silence validation:
-20 custom files checked;14 trimmed,6 unchanged. Native wolf untouched.
-LightsaberCrit:459.819ms removed;13 other trims:6.100–18.254ms.
-No removed sample exceeded−60dBFS. At least5ms pre-roll and all original tail frames retained.
-Attack correlation is at least0.999; waveform/gain/peak checks pass without normalization or added fades.
-A second trim run encoded zero files and changed no hashes.
-All180 volume variants were rebuilt and independently validated.
