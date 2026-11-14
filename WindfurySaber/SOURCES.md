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
