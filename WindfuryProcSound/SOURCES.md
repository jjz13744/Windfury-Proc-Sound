# Compatibility research

Checked 2026-11-14. Links identify the evidence used, not live-game validation.

- GaleCount, an addon specifically targeting WoW Forever, implements player spellcast and added-aura proc detection using IDs 8233, 8236, 10484, 16361 (weapon) and 8516, 10608, 10610 (totem). Its code cites DB2 build 1.60.1.70862. We independently implemented a narrower sound-only addon using those factual IDs; no source code was copied.
  https://github.com/masterred92/GaleCount
  https://raw.githubusercontent.com/masterred92/GaleCount/main/GaleCount.lua
- Blizzard-generated client API documentation, mirrored on the Forever branch, defines UNIT_SPELLCAST_SUCCEEDED as unitTarget, castGUID, spellID, optional castBarID, and marks it SecretWhenUnitSpellCastRestricted. This is why every candidate is guarded and why availability cannot be guaranteed.
  https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua
- Forever interface 16001 is used by the current Forever-targeted GaleCount manifest and by LightsaberCrit's Camelot support. Both a normal and Camelot TOC are included for this client, each loading the same files once.
  https://github.com/masterred92/GaleCount/blob/main/GaleCount.toc
  https://github.com/4rgs/LightsaberCrit/blob/main/LightsaberCrit.toc
- User's reference aura: https://wago.io/wqR5gKz0o
  Its contents were unavailable during research. No claim of matching its exact sound or implementation is made.

Limitations: no live Forever client test; client updates may change public event availability or proc IDs; mocked tests cannot implement the real secret-value mechanism. The addon deliberately does not reconstruct restricted combat information.

## Missing-proc investigation (2026-11-15)

A user reported an actual proc without a sound. Their status showed registered cast/aura handlers, 22 readable candidates, zero detected procs, and zero playback failures. This demonstrates that loading/registration succeeded, not that the expected proc event was delivered.

- GuppitusMaximus documents two observed Windfury episodes on client 1.60.1.70938 producing SPELL_UPDATE_COOLDOWN(439440, nil, 0, 0, nil), while explicitly leaving completeness and other-player attribution unverified. Version 0.2.1 records this event only during an opt-in trace; it does not play a cue from it.
  https://github.com/GuppitusMaximus/windfury/blob/main/Windfury/Windfury.lua#L863-L890
- The Forever client-generated schema defines the five optional payload fields as spellID, baseSpellID, category, startRecoveryCategory, and itemID. A nil general refresh is distinguished from numeric zero. Every field is checked for secret values before it is stored or displayed.
  https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua#L925-L936
- Another Forever addon author states that Windfury is not reported as an addon-visible spell cast and uses hit timing, with possible attribution to other players. This conflicts with treating a player-cast filter as established detection. This addon does not use hit-timing estimates.
  https://www.curseforge.com/wow/addons/zakleciojebacz-forever

The native aura-sound API exists, but no evidence yet establishes that a Windfury proc produces a matching native aura notification. No API restriction is bypassed by this diagnostic build.
