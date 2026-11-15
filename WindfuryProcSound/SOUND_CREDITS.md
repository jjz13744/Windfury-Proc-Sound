Bundled Audio Credits and Provenance
====================================
Updated 2026-11-15. Nineteen custom cues are mono Vorbis at 44,100 Hz.
One stereo source file comes from LightsaberCrit. Version 0.3.0
uses native game audio for the Warcraft wolf and bundles quieter variants
of the remaining 20 custom cues.
The original audio set has public-domain / CC0 / original provenance.
The added LightsaberCrit file has unverified underlying audio rights;
it is not covered by this addon's code license and is not cleared here
for public redistribution. No match to a Wago sound is claimed.

1. Warcraft Wolf Howl (native game audio; no file bundled)
   Blizzard Entertainment's WolfStandVar4 / WolfStandVar4b assets.
   Native FileDataIDs: 564211 and 564217.
   Verified asset paths: sound/creature/wolf/wolfstandvar4.ogg and
   sound/creature/wolf/wolfstandvar4b.ogg.
   Asset-path reference: https://github.com/wowdev/wow-listfile
   Playback uses classic wolf-howl sound kit 1018 (WolfFidget2), with
   modern wolf-howl kit 53875 as an unavailable-kit fallback.
   Forever sound-kit availability still needs in-game preview validation.
   This addon does not copy, extract, bundle or license Blizzard's audio.
   The former public-domain animal recording is no longer included.

2. Chicken (chicken.ogg)
   Original: "Chicken Single Alarm Call" by Rudmer_Rotteveel.
   https://freesound.org/people/Rudmer_Rotteveel/sounds/316920/
   CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/
   Derived from the author's public high-quality preview of an original
   recording of one of the author's chickens. Modified: mono conversion,
   near-silence trimming, level adjustment, fades and encoding.

3. Sci-fi blade (lightsaber.ogg)
   Original procedural waveform created for this addon from oscillators and
   filtered noise. No third-party recording or sample was used. The waveform
   and its generation script may be used, modified and redistributed without
   restriction. It is a generic buzzing energy-blade effect, not the sound
   from a film, game, commercial sound library or Wago aura.
   Reproducible source: tools/prepare_audio.py.

4. Seventeen Kenney effects
   Kenney Vleugels (Kenney.nl), "63 Digital sound effects (lasers, phasers,
   space etc.)", originally made with a KORG microKORG synthesizer.
   https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc
   Archive: https://opengameart.org/sites/default/files/Digital_SFX_Set.zip
   CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/
   Modified: mono conversion, near-silence trimming, level adjustment,
   edge fades and Vorbis encoding. Original filenames are mapped below.

   laser_pulse.ogg <- laser1.mp3
   laser_burst.ogg <- laser4.mp3
   laser_zing.ogg <- laser9.mp3
   phaser_drop.ogg <- phaserDown1.mp3
   phaser_rise.ogg <- phaserUp3.mp3
   power_up.ogg <- powerUp4.mp3
   arcade_bonus.ogg <- powerUp8.mp3
   victory_ping.ogg <- powerUp12.mp3
   high_swoop.ogg <- highUp.mp3
   bass_drop.ogg <- lowDown.mp3
   triple_boop.ogg <- lowThreeTone.mp3
   happy_blip.ogg <- pepSound3.mp3
   phase_jump.ogg <- phaseJump4.mp3
   space_crackle.ogg <- spaceTrash1.mp3
   three_tone.ogg <- threeTone1.mp3
   electric_zap.ogg <- zap1.mp3
   double_zap.ogg <- zapTwoTone.mp3

See sound-catalog.json for per-file source links, modifications, durations, hashes
and technical measurements. Attribution is included voluntarily for CC0.
No creator endorsement is implied. The 19 normalized custom cues peak below -4 dBFS.
The trimmed LightsaberCrit clip peaks around -2.9 dBFS and is louder
(mean approximately -10.0 dBFS after removing silent time). The selected sounds have been decoded and checked for valid
format, non-silent signal, duration and clipping; they have not been tested
inside the World of Warcraft client.

5. LightsaberCrit proc (lightsabercrit_proc.ogg), added at owner request
   Upstream project: 4rgs / LightsaberCrit.
   https://github.com/4rgs/LightsaberCrit/blob/main/sounds/lightsaber_proc.ogg
   Original filename: sounds/lightsaber_proc.ogg. Version 0.3.1 trims its leading near-silence.
   Git blob SHA: c3b03bc95c112d20ba39064f1b8a2ae77ad79f7d
   Upstream SHA256: 659c6e8715612ce38ad44323a53755bff5d059def2fa2d99d9befb9aa260e71c
   Trimmed SHA256: f3621d16aac3429d0ea62c5291ea81bb2cfebadb1ee62a4e23debafc3d647b55
   Removed 459.819 ms from the beginning, preserving a short pre-roll and tail.
   Current file: 49,708 bytes; 1.016644 seconds; stereo Vorbis; 44,100 Hz.
   Project license listing: https://www.curseforge.com/wow/addons/lightsabercrit/license
   CurseForge labels the project MIT and displays a generic license template.
   No LICENSE file was returned by GitHub's license endpoint, and the sounds
   directory has no separate attribution or license file. No original audio
   creator or file-specific rights statement was located. These observations
   do not establish whether the project author owns the recording or whether
   its underlying audio is licensed for redistribution.
   Do not assume the project's MIT label clears the audio. Confirm permission
   from its rights holder, or remove this file before public distribution.

Volume variants (version 0.3.0)
   Each custom cue has nine derived variants under sounds/volume_10 through
   sounds/volume_90. PCM amplitude is scaled directly from the original by
   0.1 through 0.9, without normalization or amplification, then re-encoded.
   The 100% files are the full-level custom sources. The variants retain the original
   asset's rights status. See volume_manifest.json and tools/prepare_volume.py.
   Native Warcraft Wolf Howl instead uses the game's SoundKit volume override.

Leading-silence cleanup (version 0.3.1)
   Fourteen custom cues had measurable near-silent lead-ins removed. Six
   already-prompt cues remain byte-identical. A -60 dBFS peak threshold across
   channels and at least 5 ms of pre-roll preserve the natural attack; no tail
   is trimmed. No normalization, gain adjustment, fade or resampling is added.
   Changed originals are re-encoded at Vorbis quality 10; quieter variants are
   rebuilt. See sound-catalog.json for per-file trim amounts and source hashes.
   The native Warcraft wolf sound cannot be edited by this addon.
