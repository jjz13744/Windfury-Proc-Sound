# Compatibility research

## Other extra hits investigation (2026-11-16, version 0.6.0)

The existing Windfury cooldown detector is independently visible in the upstream
addon, matching spell 439440, category 0 and recovery category 0:
https://github.com/GuppitusMaximus/windfury/blob/main/Windfury/Windfury.lua

Blizzard's Warrior deep dive says Sword Specialization was folded into
Weaponmaster in Forever. This is still a sword extra-attack effect, rather than
the old Classic talent's public spell ID:
https://worldofwarcraft.blizzard.com/en-us/news/24301514/world-of-warcraft-forever-class-deep-dives-priest-and-warrior

Queried the client DB2 exports for build **1.60.1.70938**, filtering exact numeric
IDs after downloading (Wago's filter can return substring matches). These are
client-data facts, not proof of runtime event delivery:

| Source | Client-data chain | Accepted triggered spell |
| --- | --- | --- |
| Weaponmaster (Sword) | Spell 12281, SpellEffect 688843 triggers 1257049 | 1257049 |
| Hand of Justice | Item 11815 → ItemEffect 99238 → passive spell 15600 → triggered spell 15601 | 15601 |
| Flurry Axe | Item 871 → ItemEffect 97087 → spell 18797 | 18797 |
| Thrash Blade | Item 17705 → ItemEffect 100397 → spell 21919 | 21919 |

Each accepted spell has effect **19 (Add Extra Attacks)** with base value **1**.
Hand of Justice 15600 and Weaponmaster 12281/1290261 are passive/application
effects and must not count as an extra attack. Classic's 16459 is not used.

Reproducible source exports (replace the numeric filter to inspect other rows):

- https://wago.tools/db2/SpellName/csv?build=1.60.1.70938&filter[ID]=1257049
- https://wago.tools/db2/SpellEffect/csv?build=1.60.1.70938&filter[SpellID]=12281
- https://wago.tools/db2/SpellEffect/csv?build=1.60.1.70938&filter[SpellID]=1257049
- https://wago.tools/db2/SpellEffect/csv?build=1.60.1.70938&filter[SpellID]=15600
- https://wago.tools/db2/SpellEffect/csv?build=1.60.1.70938&filter[SpellID]=15601
- https://wago.tools/db2/SpellEffect/csv?build=1.60.1.70938&filter[SpellID]=18797
- https://wago.tools/db2/SpellEffect/csv?build=1.60.1.70938&filter[SpellID]=21919
- https://wago.tools/db2/ItemXItemEffect/csv?build=1.60.1.70938&filter[ItemID]=11815
- https://wago.tools/db2/ItemEffect/csv?build=1.60.1.70938&filter[ID]=99238

No SpellCategories or SpellCooldowns rows were returned for these four triggered
spells. That absence **does not establish their runtime cooldown event payload**:
even Windfury Totem 8516's client category is 0 while the observed event category
was 2619. The new feature therefore stays **off by default**, labelled
experimental. It tries public cooldown candidates `(procID, nil, 0, 0, nil)` and
readable player casts/added auras of those exact IDs. The zero-category shape is
an explicit hypothesis. No live item/Sword event trace was found or supplied;
neither completeness nor other-player isolation is established. A working
preview verifies sound playback only. Existing tracing captures unknown
signatures too, so future observations can refine the filter without guessing
from attack timing. Weaponmaster is warrior-gated; item procs can affect any
player class. Different item/talent IDs never deduplicate one another.

The duration cap uses C_Timer.NewTimer and StopSound on only the addon's handle;
the deadline uses no fade-out padding. Game scheduling is frame-based:
https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua

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

## Isolated trace follow-up (version 0.2.2)

The user then ran separate tests and reported two observed procs in each:

- Weapon imbue only: 439440, nil, 0, 0, nil occurred twice. One unrelated 16257 event had nil category fields.
- Totem only: 8516, nil, 2619, 0, nil occurred twice. Two unrelated 16257 events had nil category fields.

Neither trace showed a matching player cast or added aura. Both trace screenshots had zero omitted rows. These are direct user-supplied live observations; the implementation now matches these two exact payloads, with separate counters and settings. Summon/application IDs are not used. The Totem rank mapping 10608/10610 is retained from GaleCount's proc family, but those ranks are not yet live-tested. Tests replay the observations through the real addon handlers with mocked playback.

This establishes the observed signatures, not universal event delivery or audible playback of this new version. Other-player isolation still needs a negative test. The addon reads only public local-client cooldown fields, never reconstructs target hit timing, and does not bypass secret restrictions.

## Addon-only volume and native wolf (version 0.3.0)

The Forever generated Sound API defines C_Sound.PlaySound with six parameters: soundKitID, uiSoundSubType, forceNoDuplicates, runFinishCallback, overridePriority, volumeOverride. This is used only for the native Warcraft wolf. It does not accept custom file paths, and there is no documented handle-volume setter. Custom cues instead use pre-rendered attenuated files; no global audio CVar is changed.
https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua
https://ffmpeg.org/ffmpeg-filters.html#volume

The native slider methods (including SetValueStep and SetObeyStepOnDrag) are documented for this client:
https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleSliderAPIDocumentation.lua

Warcraft's wolf howl assets are WolfStandVar4 / WolfStandVar4b, FileDataIDs564211/564217. The known classic WolfFidget2 kit1018 is tried first; modern wolf-howl kit53875 is an unavailable-kit fallback. These exact kits are not yet runtime-tested in the user's Forever client. No game asset is extracted or bundled.
https://github.com/wowdev/wow-listfile

## Categorized dropdown implementation (0.4.0)

The Forever Blizzard UI source retains UIDropDownMenuTemplate and the Initialize, CreateInfo, AddButton, SetWidth and SetText helpers. Category rows preserve the open menu on click; each submenu is limited to ten choices. This is source/API validation, not live UI rendering.

- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenu.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenuTemplates.xml
