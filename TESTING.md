# Verification report

2026-11-15, version 0.3.1

Passed locally:
- 268 Lua assertions using the real addon modules with mocked WoW APIs.
- Existing exact Weapon/Totem trace replays, all event filtering, secret guards, independent toggles and duplicate suppression remain covered.
- Old shared sound selections migrate to both new per-proc choices. Separate UI and slash selections preserve the other choice.
- Volume snaps to 10% steps;0% skips playback and stops only the owned handle;100% uses unchanged custom originals; lower levels use the matching variant path.
- Native Warcraft howl uses the documented sixth SoundKit volume override argument. Classic-kit failure tries the known modern equivalent; failure of both reports unavailable, without substituting unrelated audio.
- Missing quiet files never fall back to a full-volume original.
- Random cues avoid immediate repeats. Preview ignores random mode, respects volume and bypasses the automatic cue interval.
- Minimum-gap setting limits audio, not proc counts; reset counters keeps settings; disable/stop stops the owned sound.
- Real UI callbacks exercised for tabs, sliders, selection previews, Close/reopen and reset. Refresh guards prevent slider recursion. Static review confirmed control bounds within600x650.
- Independent code review found no new defects; native game UI rendering still requires validation.
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
