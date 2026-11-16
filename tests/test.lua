local ns = {}
local tests = 0
local function check(value, message)
    assert(value, message); tests = tests + 1
end
local secret = {}
issecretvalue = function(v) return rawequal(v, secret) end
assert(loadfile("WindfuryProcSound/Core.lua"))("WindfuryProcSound", ns)
local C = ns.Core
local catalog = {{id="lightsabercrit_proc"}, {id="lightsaber"}, {id="wolf"}}
local db = C.Settings(nil, catalog)
check(db.enabled and db.weapon and db.totem and db.sound == "lightsabercrit_proc", "0.4.1 default cue preserved")
local corrupt = C.Settings({enabled="yes", channel="Bad", sound="missing"}, catalog)
check(corrupt.enabled and corrupt.channel == "Master" and corrupt.sound == "lightsabercrit_proc", "repair settings preserves 0.4.1 default")
local count = 0
local d = C.NewDetector(function() count = count + 1 end)
check(d:Observe(8233, "cast", "a", 1, db), "weapon proc")
check(not d:Observe(8233, "aura", 7, 1.05, db), "cross source dedupe")
check(not d:Observe(8233, "cast", "a", 1.06, db), "duplicate cast token")
check(d:Observe(8233, "cast", "b", 1.1, db), "rapid distinct cast")
check(not d:Observe(8233, "aura", 8, 1.15, db), "second cross source dedupe")
check(count == 2, "exact count after rapid pair")
check(d:Observe(8233, "aura", 9, 2, db), "aura first")
check(not d:Observe(8233, "cast", "c", 2.05, db), "aura before cast dedupe")
check(not d:Observe(8232, "cast", "imbue", 3, db), "imbue is not proc")
check(not d:Observe(8512, "cast", "totem", 3, db), "totem cast is not proc")
check(not d:Observe(secret, "cast", "s", 4, db), "secret spell ignored")
check(d.restricted == 1, "secret diagnostic")
check(d:Observe(8516, "cast", secret, 4, db), "secret token ignored safely")
db.totem = false
check(not d:Observe(10608, "cast", "t", 5, db), "totem disabled")
db.enabled = false
check(not d:Observe(8236, "cast", "e", 5, db), "disabled")
db.enabled = true; db.totem = true
db.extra = true
for id in pairs(C.procIDs) do check(d:Observe(id, "cast", "rank" .. id, 10, db), "rank " .. id) end
db.extra = false
d:Reset(); check(d.count == 0 and d.restricted == 0, "reset")

-- Lightweight WoW API mocks: execute the actual addon event handlers and options.
local frames, played, messages = {}, {}, {}
local clock = 100
local function widget()
    local f = { scripts = {}, registered = {} }
    function f:SetScript(k, v) self.scripts[k] = v end
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:UnregisterEvent(e) self.registered[e] = nil end
    function f:RegisterUnitEvent(e, u) self.registered[e] = u end
    function f:CreateFontString() return widget() end
    function f:SetText(v) self.textValue = v end
    function f:GetText() return self.textValue end
    function f:SetPoint(...) self.point = {...} end
    function f:SetSize(w,h) self.width=w; self.height=h end
    function f:SetScale(v) self.scale=v end
    function f:SetChecked(v) self.checked = v end
    function f:SetValue(v) self.value=v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
    function f:GetValue() return self.value end
    function f:SetMinMaxValues(low,high) self.low=low;self.high=high end
    function f:SetValueStep(v) self.step=v end
    function f:GetChecked() return self.checked end
    function f:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    local noOp = function() end
    for _, n in ipairs({"SetOrientation", "SetObeyStepOnDrag", "SetThumbTexture", "SetFrameStrata", "SetClampedToScreen", "EnableMouse", "SetMovable", "RegisterForDrag", "SetBackdrop", "SetEnabled", "StartMoving", "StopMovingOrSizing", "SetAutoFocus", "SetMaxLetters", "ClearFocus"}) do f[n] = noOp end
    return f
end
CreateFrame = function(_, name, parent, template)
    local f=widget(); f.text=widget(); frames[#frames+1]=f
    f.parent=parent
    if template=="UIDropDownMenuTemplate" then f.Button=widget() end
    if name then _G[name]=f end
    return f
end
DEFAULT_CHAT_FRAME = {AddMessage=function(_, m) messages[#messages+1]=m end}
PlaySoundFile=function(path, channel) played[#played+1]={path,channel}; return true,#played end
StopSound=function() end
C_Sound={PlaySound=function(kit,channel,duplicates,callback,priority,volume)
    played[#played+1]={"soundkit:"..kit,channel,kit=kit,volume=volume}
    return true,#played
end}
GetTime=function() return clock end
SlashCmdList={}; UISpecialFrames={}; UIParent={}
Settings={ RegisterCanvasLayoutCategory=function() return {} end, RegisterAddOnCategory=function() end }
local dropdown, menuClosed = nil, 0
UIDropDownMenu_SetWidth=function(menu,width) menu.width=width end
UIDropDownMenu_SetAnchor=function(menu,...) menu.anchor={...} end
UIDropDownMenu_Initialize=function(menu,initialize) menu.initialize=initialize end
UIDropDownMenu_CreateInfo=function() return {} end
UIDropDownMenu_AddButton=function(info,level)
    assert(dropdown,"dropdown must be open before adding buttons")
    dropdown.buttons[#dropdown.buttons+1]=info
end
UIDropDownMenu_SetText=function(menu,text) menu.textValue=text end
CloseDropDownMenus=function() menuClosed=menuClosed+1 end
local function openMenu(menu,level,group)
    dropdown=menu;menu.buttons={}
    menu.initialize(menu,level or 1,group)
    dropdown=nil
    return menu.buttons
end
local function menuChoice(menu,id)
    local groups=openMenu(menu)
    for _,group in ipairs(groups) do
        for _,choice in ipairs(openMenu(menu,2,group.menuList)) do
            if choice.value==id then return choice end
        end
    end
    error("Missing menu choice "..id)
end
assert(loadfile("WindfuryProcSound/Sounds.lua"))("WindfuryProcSound", ns)
check(#ns.sounds == 66, "0.4.1 catalog plus two new sounds")
local baselineIDs={
 "lightsaber","wolf_howl","chicken","laser_pulse","laser_burst","laser_zing","phaser_drop","phaser_rise",
 "power_up","arcade_bonus","victory_ping","high_swoop","bass_drop","triple_boop","happy_blip","phase_jump",
 "space_crackle","three_tone","electric_zap","double_zap","lightsabercrit_proc","cat","cow","duck","goat",
 "lion","pig","blast","boxing_bell","heavy_punch","shotgun","temple_bell","thunder","whip_crack","air_horn",
 "applause","cartoon_voice","spring_boing","squeaky_toy","cash_register","coin_drop","drum_roll","heartbeat",
 "triangle","water_drop","cannon","metal_parry","firework","frying_pan","slot_machine","critsound_critical_damage",
 "critsound_dominating","critsound_unstoppable","critsound_wicked_sick","critsound_godlike","critsound_fight",
 "wfgw_whoosh","wfgw_whoosh_two","wfgw_stay_positive","wfgw_what_was_that","wfgw_purr","wfgw_boing",
 "wfgw_boing_two","shaman_warning_windfury",
}
for i,id in ipairs(baselineIDs) do check(ns.sounds[i].id==id,"0.4.1 numeric sound position preserved "..i) end
check(ns.sounds[65].id=="bonk" and ns.sounds[66].id=="fruit_machine","new sounds append after all 0.4.1 positions")
local unique = {}
for _, s in ipairs(ns.sounds) do
    check(not unique[s.id], "unique sound " .. s.id); unique[s.id] = true
    if s.file then
        local audio = assert(io.open("WindfuryProcSound/sounds/" .. s.file, "rb"))
        check(audio:read(4)=="OggS", "valid OGG header " .. s.id); audio:close()
    else check(s.soundKit==1018 and s.fallbackSoundKit==53875, "Warcraft wolf uses native howl kits") end
end
assert(loadfile("WindfuryProcSound/Addon.lua"))("WindfuryProcSound", ns)
check(#ns.activeSounds==49,"49 active sounds retain 17 retired legacy positions")
assert(loadfile("WindfuryProcSound/Options.lua"))("WindfuryProcSound", ns)
local event=ns.frame.scripts.OnEvent
event(ns.frame, "ADDON_LOADED", "WindfuryProcSound")
check(ns.frame.registered.UNIT_SPELLCAST_SUCCEEDED == "player", "player cast registration")
check(ns.frame.registered.UNIT_AURA == "player", "player aura registration")
event(ns.frame, "UNIT_SPELLCAST_SUCCEEDED", "target", "bad", 8233)
check(#played==0, "other unit ignored")
event(ns.frame, "UNIT_SPELLCAST_SUCCEEDED", "player", "good", 8233)
check(#played==1 and played[1][2]=="Master", "proc audio played")
event(ns.frame, "UNIT_AURA", "player", {addedAuras={{spellId=8233,auraInstanceID=1}}})
check(#played==1, "real handlers dedupe")
event(ns.frame, "UNIT_SPELLCAST_SUCCEEDED", secret, "bad", 8233)
event(ns.frame, "UNIT_SPELLCAST_SUCCEEDED", "player", "bad", secret)
check(#played==1, "restricted handlers fail closed")
event(ns.frame, "UNIT_AURA", "player", {isFullUpdate=true, addedAuras={{spellId=8516,auraInstanceID=3}}})
check(#played==1, "full aura snapshots ignored")
event(ns.frame, "UNIT_AURA", "player", {addedAuras=secret})
check(#played==1, "secret aura array ignored")
SlashCmdList.WINDFURYPROCSOUND("sound 2")
check(ns.db.sound==ns.sounds[2].id and #played==2, "select sound by number")
SlashCmdList.WINDFURYPROCSOUND("off")
clock=110; event(ns.frame, "UNIT_SPELLCAST_SUCCEEDED", "player", "off", 8233)
check(#played==2, "disabled handler silent")
SlashCmdList.WINDFURYPROCSOUND("test")
check(#played==3, "manual preview works when disabled")
SlashCmdList.WINDFURYPROCSOUND("options")
check(WindfuryProcSoundOptions.shown, "options opens")
check(WindfuryProcSoundOptions.height == 680, "tabbed options window fits all controls")
for _,menu in ipairs({WindfuryProcSoundWeaponMenu,WindfuryProcSoundTotemMenu,WindfuryProcSoundExtraMenu}) do
    check(menu.anchor[3]=="TOPLEFT" and menu.anchor[4]==menu.Button and menu.anchor[5]=="BOTTOMLEFT","dropdown stays anchored below its own arrow")
end
SlashCmdList.WINDFURYPROCSOUND("sound 21")
check(ns.db.sound == "lightsabercrit_proc", "select new LightsaberCrit option")
check(played[#played][1]:find("lightsabercrit_proc.ogg",1,true) ~= nil, "new sound plays correct file")
SlashCmdList.WINDFURYPROCSOUND("sound lightsabercrit_proc")
check(ns.db.sound == "lightsabercrit_proc", "select new sound by ID")
SlashCmdList.WINDFURYPROCSOUND("reset")
check(ns.db.enabled and ns.db.sound=="lightsabercrit_proc", "reset command preserves 0.4.1 default cue")
SlashCmdList.WINDFURYPROCSOUND("status")
check(#messages > 0, "status prints")
PlaySoundFile=function() return false end
check(not ns.Play(nil,true) and ns.soundFailures==1, "playback failure reported")
SlashCmdList.WINDFURYPROCSOUND("reset")
check(ns.soundFailures == 0, "reset playback failure counter")
-- Diagnostics: bounded public IDs only; cooldown candidates never trigger audio.
local tr = C.NewTrace(200)
C.TraceRecord(tr, "cooldown", secret, 200.25, nil, secret, 0, secret)
check(tr.rows[1].spellID == "restricted" and tr.rows[1].category == "restricted", "trace discards secret values")
check(tr.rows[1].baseSpellID == "nil" and tr.rows[1].startRecoveryCategory == 0, "trace preserves nil vs zero")
check(tr.rows[1].itemID == "restricted" and tr.rows[1].t == 0.25, "trace stores only markers and relative timing")
for i=1,130 do C.TraceRecord(tr,"cast",i,201+i/10) end
check(#tr.rows == 120 and tr.dropped == 11 and tr.total == 131, "trace bounded to latest 120 rows")
check(tr.rows[1].spellID == 11 and tr.rows[120].spellID == 130, "trace retains latest entries")
local restored=C.CopyTrace(tr)
check(restored and not restored.active and #restored.rows == 120, "saved trace restored inactive")
check(C.CopyTrace({rows="bad"}) == nil, "invalid saved trace rejected")
clock=300
SlashCmdList.WINDFURYPROCSOUND("trace on")
check(ns.trace.active and ns.frame.registered.SPELL_UPDATE_COOLDOWN, "trace subscribes cooldown event")
local procBefore, failuresBefore = ns.detector.count, ns.soundFailures
event(ns.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
check(ns.trace.rows[1].spellID == 439440 and ns.trace.rows[1].category == 0, "observed cooldown signature recorded")
check(ns.detector.count == procBefore and ns.soundFailures == failuresBefore, "cooldown candidate cannot trigger sound")
event(ns.frame,"UNIT_SPELLCAST_SUCCEEDED","player","never-stored-guid",12345)
check(ns.trace.rows[2].source == "cast" and ns.trace.rows[2].spellID == 12345, "readable player cast recorded without GUID")
C_UnitAuras={GetAuraDataByAuraInstanceID=function(unit,id) return {spellId=439441} end}
event(ns.frame,"UNIT_AURA","player",{updatedAuraInstanceIDs={17}})
check(ns.trace.rows[3].source == "aura-update" and ns.trace.rows[3].spellID == 439441, "updated aura traced without counting as proc")
check(ns.detector.count == procBefore, "aura refresh trace does not become proc")
SlashCmdList.WINDFURYPROCSOUND("trace show")
check(not ns.trace.active and ns.frame.registered.SPELL_UPDATE_COOLDOWN, "show stops trace but preserves automatic cooldown listener")
check(ns.db.lastTrace == ns.trace, "trace retained in existing saved settings")
SlashCmdList.WINDFURYPROCSOUND("trace on")
clock=331
ns.frame.scripts.OnUpdate()
check(not ns.trace.active and ns.frame.scripts.OnUpdate == nil, "trace automatically ends after 30 seconds")
SlashCmdList.WINDFURYPROCSOUND("trace clear")
check(ns.trace == nil and ns.db.lastTrace == nil, "clear removes diagnostic record")
-- Optional trace-field restrictions must not abort readable added-aura handling.
local guarded=setmetatable({addedAuras={{spellId=8233,auraInstanceID=200}}}, {
    __index=function(_,key) if key=="updatedAuraInstanceIDs" then error("restricted diagnostic field") end end
})
clock=400
local addedBefore=ns.detector.count
event(ns.frame,"UNIT_AURA","player",guarded)
check(ns.detector.count==addedBefore+1, "trace-off never reads optional updated-aura field")
SlashCmdList.WINDFURYPROCSOUND("trace on")
clock=401; guarded.addedAuras[1].auraInstanceID=201
event(ns.frame,"UNIT_AURA","player",guarded)
check(ns.detector.count==addedBefore+2, "trace restriction cannot abort readable added-aura detection")
SlashCmdList.WINDFURYPROCSOUND("trace clear")
C_UnitAuras=nil

-- Rename migration: import only when no new-format settings exist, avoid double audio.
local renamed = {}
assert(loadfile("WindfuryProcSound/Core.lua"))("WindfuryProcSound", renamed)
assert(loadfile("WindfuryProcSound/Sounds.lua"))("WindfuryProcSound", renamed)
WindfuryProcSoundDB = nil
WindfurySaberDB = { enabled=true, weapon=true, totem=false, sound="chicken", channel="SFX" }
C_AddOns = { IsAddOnLoaded=function(name) return name == "WindfurySaber" end }
assert(loadfile("WindfuryProcSound/Addon.lua"))("WindfuryProcSound", renamed)
local renamedEvent = renamed.frame.scripts.OnEvent
renamedEvent(renamed.frame, "ADDON_LOADED", "WindfuryProcSound")
check(renamed.db.sound == "chicken" and renamed.db.channel == "SFX" and not renamed.db.totem, "legacy settings imported")
check(WindfuryProcSoundDB == renamed.db, "new saved-variable name")
check(renamed.legacyActive, "legacy addon detected")
local before = #played
renamedEvent(renamed.frame, "UNIT_SPELLCAST_SUCCEEDED", "player", "legacy-active", 8233)
check(#played == before and renamed.detector.count == 0, "avoid double cues during migration")
check(SLASH_WINDFURYPROCSOUND1 == "/wfps" and SLASH_WINDFURYPROCSOUND2 == "/windfuryprocsound", "new command aliases")
check(SLASH_WINDFURYPROCSOUND3 == "/wfs", "old short alias retained")
local subsequent = {}
assert(loadfile("WindfuryProcSound/Core.lua"))("WindfuryProcSound", subsequent)
assert(loadfile("WindfuryProcSound/Sounds.lua"))("WindfuryProcSound", subsequent)
WindfuryProcSoundDB.sound = "lightsabercrit_proc"
C_AddOns.IsAddOnLoaded=function() return false end
assert(loadfile("WindfuryProcSound/Addon.lua"))("WindfuryProcSound", subsequent)
subsequent.frame.scripts.OnEvent(subsequent.frame, "ADDON_LOADED", "WindfuryProcSound")
check(subsequent.db.sound == "lightsabercrit_proc", "new settings take precedence over legacy")
check(not subsequent.legacyActive, "automatic cues resume without legacy addon")


-- Replay the isolated live weapon trace against actual runtime handlers.
local runtime = {}
WindfuryProcSoundDB={enabled=true,weapon=true,totem=true,sound="lightsabercrit_proc",channel="Master"}
UnitClass=function() return "Shaman","SHAMAN" end
PlaySoundFile=function(path, channel) played[#played+1]={path,channel}; return true,#played end
assert(loadfile("WindfuryProcSound/Core.lua"))("WindfuryProcSound", runtime)
assert(loadfile("WindfuryProcSound/Sounds.lua"))("WindfuryProcSound", runtime)
assert(loadfile("WindfuryProcSound/Addon.lua"))("WindfuryProcSound", runtime)
local re=runtime.frame.scripts.OnEvent
re(runtime.frame,"ADDON_LOADED","WindfuryProcSound")
check(runtime.isShaman and runtime.frame.registered.SPELL_UPDATE_COOLDOWN, "weapon cooldown listener active on shaman")
local startPlayed=#played
clock=1000
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
clock=1002
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",16257,nil,nil,nil,nil)
check(#played==startPlayed+2 and runtime.detector.count==2, "isolated two-proc weapon trace plays exactly twice")
check(played[#played][1]:find("lightsabercrit_proc.ogg",1,true) and played[#played][2]=="Master", "cooldown uses saved selected sound and channel")
local unpackArgs=table.unpack or unpack
local rejected={
 {}, {439440}, {439440,nil,nil,0}, {439440,nil,0,nil},
 {439440,nil,0,133}, {439440,nil,2619,0}, {439440,439440,0,0},
 {439440,nil,0,0,1}, {439441,nil,0,0}, {8516,nil,0,0},
 {8512,nil,0,0}, {8232,nil,0,0}, {439440,nil,"0",0},
}
for i,args in ipairs(rejected) do
 local prior=runtime.detector.count
 re(runtime.frame,"SPELL_UPDATE_COOLDOWN",unpackArgs(args,1,5))
 check(runtime.detector.count==prior,"reject nonmatching cooldown payload "..i)
end
for i=1,5 do
 local args={439440,nil,0,0,nil};args[i]=secret
 local prior=runtime.detector.count
 re(runtime.frame,"SPELL_UPDATE_COOLDOWN",unpackArgs(args,1,5))
 check(runtime.detector.count==prior,"secret cooldown field fails closed "..i)
end
runtime.db.weapon=false
local prior=runtime.detector.count
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
check(runtime.detector.count==prior,"weapon option disables cooldown cue")
runtime.db.weapon=true;runtime.db.enabled=false
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
check(runtime.detector.count==prior,"global disable suppresses cooldown cue")
runtime.db.enabled=true
clock=1100
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
re(runtime.frame,"UNIT_SPELLCAST_SUCCEEDED","player","legacy-same-proc",8233)
check(runtime.detector.count==prior+1,"cooldown and legacy weapon ID deduplicate across sources")
clock=1200
re(runtime.frame,"UNIT_SPELLCAST_SUCCEEDED","player","cast-first",8236)
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
check(runtime.detector.count==prior+2,"legacy cast before cooldown also deduplicates")
SlashCmdList.WINDFURYPROCSOUND("trace on")
SlashCmdList.WINDFURYPROCSOUND("trace stop")
check(runtime.frame.registered.SPELL_UPDATE_COOLDOWN,"stopping trace preserves automatic weapon listener")
UnitClass=function() return "Warrior","WARRIOR" end
re(runtime.frame,"PLAYER_ENTERING_WORLD")
prior=runtime.detector.count
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
check(not runtime.isShaman and runtime.detector.count==prior,"weapon signature disabled on non-shaman")
UnitClass=function() return "Secret",secret end
re(runtime.frame,"PLAYER_ENTERING_WORLD")
check(not runtime.isShaman,"restricted player class fails closed")

-- Replay the isolated live Totem trace independently of Weapon and class.
UnitClass=function() return "Shaman","SHAMAN" end
re(runtime.frame,"PLAYER_ENTERING_WORLD")
clock=1300;startPlayed=#played
local oldWeapon,oldTotem=runtime.detector.weapon,runtime.detector.totem
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",8516,nil,2619,0,nil)
clock=1302
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",8516,nil,2619,0,nil)
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",16257,nil,nil,nil,nil)
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",16257,nil,nil,nil,nil)
check(#played==startPlayed+2 and runtime.detector.totem==oldTotem+2,"isolated two-proc Totem trace plays exactly twice")
check(runtime.detector.weapon==oldWeapon,"Totem signature is counted separately from Weapon")
local totemRejected={
 {8516,nil,0,0}, {8516,nil,2619,nil}, {8516,nil,2619,133}, {8516,nil,2619,0,1},
 {8516,8516,2619,0}, {8512,nil,2619,0}, {10613,nil,2619,0}, {10614,nil,2619,0},
 {8515,nil,2619,0}, {10609,nil,2619,0}, {10612,nil,2619,0},
}
for i,args in ipairs(totemRejected) do
 prior=runtime.detector.count
 re(runtime.frame,"SPELL_UPDATE_COOLDOWN",unpackArgs(args,1,5))
 check(runtime.detector.count==prior,"reject non-proc Totem payload "..i)
end
for i=1,5 do
 local args={8516,nil,2619,0,nil};args[i]=secret;prior=runtime.detector.count
 re(runtime.frame,"SPELL_UPDATE_COOLDOWN",unpackArgs(args,1,5))
 check(runtime.detector.count==prior,"Totem secret field fails closed "..i)
end
runtime.db.totem=false;prior=runtime.detector.count
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",8516,nil,2619,0,nil)
check(runtime.detector.count==prior,"Totem option disables only Totem signature")
clock=1400;re(runtime.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
check(runtime.detector.count==prior+1,"Weapon stays enabled when Totem disabled")
runtime.db.totem=true;runtime.db.weapon=false;prior=runtime.detector.count
clock=1500;re(runtime.frame,"SPELL_UPDATE_COOLDOWN",8516,nil,2619,0,nil)
check(runtime.detector.count==prior+1,"Totem stays enabled when Weapon disabled")
re(runtime.frame,"UNIT_AURA","player",{addedAuras={{spellId=8516,auraInstanceID=909}}})
check(runtime.detector.count==prior+1,"Totem cooldown and legacy aura deduplicate")
UnitClass=function() return "Warrior","WARRIOR" end
re(runtime.frame,"PLAYER_ENTERING_WORLD");prior=runtime.detector.count
clock=1600;re(runtime.frame,"SPELL_UPDATE_COOLDOWN",8516,nil,2619,0,nil)
check(runtime.detector.count==prior+1,"Totem own-client signature available to non-shaman recipient")
for i,id in ipairs({10608,10610}) do
 clock=1700+i;prior=runtime.detector.count
 re(runtime.frame,"SPELL_UPDATE_COOLDOWN",id,nil,2619,0,nil)
 check(runtime.detector.count==prior+1,"higher Totem rank mapping "..id)
end
runtime.db.enabled=false;prior=runtime.detector.count
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",8516,nil,2619,0,nil)
check(runtime.detector.count==prior,"global disable suppresses Totem")


-- Volume and convenience settings preserve old selections and never touch CVars.
local migrated=C.Settings({sound="wolf",volume=54,minGap=0.26,weaponSound="missing"},catalog)
check(migrated.weaponSound=="wolf" and migrated.totemSound=="wolf","old sound migrated to both proc types")
check(migrated.volume==50 and math.abs(migrated.minGap-0.3)<0.001,"volume and minimum gap snap to honest steps")
local invalid=C.Settings({volume=0/0,minGap=math.huge},catalog)
check(invalid.volume==100 and invalid.minGap==0,"invalid numeric settings reset safely")
check(C.Snap(-30,0,100,10,100)==0 and C.Snap(999,0,100,10,100)==100,"volume bounds")
check(C.SoundPath("WindfuryProcSound","x.ogg",0)==nil,"zero volume has no playback path")
check(C.SoundPath("WindfuryProcSound","x.ogg",50)=="Interface\\AddOns\\WindfuryProcSound\\sounds\\volume_50\\x.ogg","quiet volume uses pre-rendered path")
check(C.SoundPath("WindfuryProcSound","x.ogg",100)=="Interface\\AddOns\\WindfuryProcSound\\sounds\\x.ogg","100 percent uses untouched original")
SetCVar=function() error("global audio setting must never be changed") end
C_CVar={SetCVar=SetCVar}
local stopped=0
StopSound=function() stopped=stopped+1 end
local ui={}
WindfuryProcSoundDB={enabled=true,weapon=true,totem=true,sound="lightsabercrit_proc",channel="Master"}
UnitClass=function() return "Shaman","SHAMAN" end
assert(loadfile("WindfuryProcSound/Core.lua"))("WindfuryProcSound",ui)
assert(loadfile("WindfuryProcSound/Sounds.lua"))("WindfuryProcSound",ui)
assert(loadfile("WindfuryProcSound/Addon.lua"))("WindfuryProcSound",ui)
assert(loadfile("WindfuryProcSound/Options.lua"))("WindfuryProcSound",ui)
local ue=ui.frame.scripts.OnEvent
ue(ui.frame,"ADDON_LOADED","WindfuryProcSound")
check(ui.db.weaponSound=="lightsabercrit_proc" and ui.db.totemSound=="lightsabercrit_proc","existing actual selection preserved for both")
ui.ShowOptions()
check(WindfuryProcSoundSoundPanel.shown and not WindfuryProcSoundPlaybackPanel.shown,"Sounds tab selected initially")
check(WindfuryProcSoundVolumeSlider.low==0 and WindfuryProcSoundVolumeSlider.high==100 and WindfuryProcSoundVolumeSlider.step==10,"volume slider range and step")
WindfuryProcSoundVolumeSlider:SetValue(43)
check(ui.db.volume==40 and WindfuryProcSoundVolumeSlider:GetValue()==40,"slider snaps and refreshes without recursion")
local n=#played
ui.Play(nil,true)
check(#played==n+1 and played[#played][1]:find("volume_40\\lightsabercrit_proc.ogg",1,true),"preview respects own volume")
ui.SetVolume(0);n=#played;local failures=ui.soundFailures
check(stopped>0,"mute stops owned sound handle")
ui.Play(nil,true)
check(#played==n and ui.soundFailures==failures,"muted preview is silent without playback failure")
ui.SetVolume(50)
ui.SelectSound("chicken","weapon");ui.SelectSound("laser_pulse","totem")
ui.Play(nil,true,"weapon");local weaponPath=played[#played][1]
ui.Play(nil,true,"totem")
check(weaponPath:find("volume_50\\chicken.ogg",1,true) and played[#played][1]:find("volume_50\\laser_pulse.ogg",1,true),"independent Weapon and Totem previews")
SlashCmdList.WINDFURYPROCSOUND("sound weapon 21")
check(ui.db.weaponSound=="lightsabercrit_proc" and ui.db.totemSound=="laser_pulse","weapon slash selection preserves totem")
SlashCmdList.WINDFURYPROCSOUND("sound totem 3")
check(ui.db.weaponSound=="lightsabercrit_proc" and ui.db.totemSound=="chicken","totem slash selection preserves weapon")
SlashCmdList.WINDFURYPROCSOUND("sound 2")
check(ui.db.weaponSound==ui.sounds[2].id and ui.db.totemSound==ui.sounds[2].id,"legacy sound command updates both")
SlashCmdList.WINDFURYPROCSOUND("volume 76")
check(ui.db.volume==80,"volume slash rounds to available variant")
ui.db.volume=100;ui.db.minGap=1;ui.db.randomSound=false;ui.ResetCounters()
n=#played;clock=2000
ue(ui.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
clock=2000.5;ue(ui.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
ui.Play(nil,true,"totem")
clock=2001;ue(ui.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
check(ui.detector.weapon==3 and ui.suppressed==1 and #played==n+3,"gap limits audio only; preview bypasses without changing automatic interval")
ui.db.minGap=0;ui.db.randomSound=true;ui.ResetCounters()
local previous,retiredPaths = nil,{}
for _,sound in ipairs(ui.sounds) do
 if sound.retired then retiredPaths[C.SoundPath("WindfuryProcSound",sound.file,100)]=true end
end
local actualRandom=math.random
math.random=function(maximum) return math.min(4,maximum) end
for i=1,40 do
 clock=2100+i;ui.Play(nil,false,"weapon")
 local path=played[#played][1]
 check(path~=previous,"random cues avoid immediate repeat "..i);previous=path
 check(not retiredPaths[path],"random selection excludes retired legacy cues "..i)
end
math.random=actualRandom
n=#played;ui.Play("chicken",true)
check(#played==n+1 and played[#played][1]:find("chicken.ogg",1,true),"explicit preview ignores random mode")
local beforeSettings=ui.db.weaponSound
SlashCmdList.WINDFURYPROCSOUND("clearcounts")
check(ui.detector.count==0 and ui.suppressed==0 and ui.db.weaponSound==beforeSettings,"counter reset preserves options")
local beforeStop=stopped
SlashCmdList.WINDFURYPROCSOUND("stop")
check(stopped==beforeStop+1,"stop command only stops owned handle")
ui.Play(nil,true);beforeStop=stopped
SlashCmdList.WINDFURYPROCSOUND("off")
check(stopped==beforeStop+1 and not ui.db.enabled,"disable stops current addon cue")
-- Find the most recently created control by text to exercise actual callbacks.
local function clickText(text)
 for i=#frames,1,-1 do local f=frames[i];if f.textValue==text and f.scripts.OnClick then f.scripts.OnClick(f);return f end end
 error("Missing UI button "..text)
end
clickText("Playback")
check(WindfuryProcSoundPlaybackPanel.shown and not WindfuryProcSoundSoundPanel.shown,"Playback tab switches visibility")
WindfuryProcSoundGapSlider:SetValue(0.26)
check(math.abs(ui.db.minGap-0.3)<0.001,"gap slider snaps to 0.1 second")
clickText("Sounds")
ui.db.previewOnSelect=false;n=#played
menuChoice(WindfuryProcSoundWeaponMenu,"chicken").func()
check(ui.db.weaponSound=="chicken" and #played==n,"sound selection is quiet by default")
ui.db.previewOnSelect=true
local closedBefore=menuClosed
menuChoice(WindfuryProcSoundWeaponMenu,"bonk").func()
check(ui.db.weaponSound=="bonk" and #played==n+1,"optional menu selection preview plays once")
check(menuClosed==closedBefore+1,"choosing a sound closes native menus")
ui.db.previewOnSelect=false
ui.SelectSound("laser_pulse","weapon")
check(WindfuryProcSoundWeaponMenu.textValue=="Laser Pulse","saved retired cue remains displayed")
local legacyMenu=menuChoice(WindfuryProcSoundWeaponMenu,"laser_pulse")
check(legacyMenu.checked and legacyMenu.text=="Laser Pulse","selected retired cue is accessible in saved legacy menu")
ui.Play(nil,true,"weapon")
check(played[#played][1]:find("laser_pulse.ogg",1,true),"saved retired cue remains playable")
menuChoice(WindfuryProcSoundWeaponMenu,"chicken").func()
local visible,seen=0,{}
for _,group in ipairs(openMenu(WindfuryProcSoundWeaponMenu)) do
 check(group.hasArrow and group.notCheckable and group.menuList==group.text,"first-level category opens submenu "..group.text)
 local entries=openMenu(WindfuryProcSoundWeaponMenu,2,group.menuList)
 check(#entries>0 and #entries<=10,"category submenu remains bounded "..group.text)
 for _,choice in ipairs(entries) do
  check(not seen[choice.value] and not ui.GetSound(choice.value).retired,"active cue appears once in categories "..choice.value)
  seen[choice.value]=true;visible=visible+1
 end
end
check(visible==49,"all active cues are browsable without duplicates")
for _,group in ipairs(openMenu(WindfuryProcSoundWeaponMenu)) do check(group.text~="Saved legacy cue","retired group disappears after selecting active cue") end
local actualActive=ui.activeSounds
ui.activeSounds={}
for i=1,21 do
 local sound={}
 for key,value in pairs(actualActive[i]) do sound[key]=value end
 sound.category="Paging test";ui.activeSounds[i]=sound
end
local pages=openMenu(WindfuryProcSoundWeaponMenu)
check(#pages==3,"one large category splits into three native submenus")
local paged,pagedIDs=0,{}
for _,page in ipairs(pages) do
 local entries=openMenu(WindfuryProcSoundWeaponMenu,2,page.menuList)
 check(#entries<=10,"large category page never exceeds ten entries")
 for _,choice in ipairs(entries) do
  check(not pagedIDs[choice.value],"paginated cue appears once "..choice.value)
  pagedIDs[choice.value]=true;paged=paged+1
 end
end
check(paged==21,"category pagination retains every cue")
ui.activeSounds=actualActive;ui.RefreshOptions()
clickText("Close");ui.ShowOptions()
check(WindfuryProcSoundOptions.shown,"options reopen after Close")
ui.ResetOptions()
check(ui.db.volume==100 and ui.db.minGap==0 and not ui.db.randomSound and not ui.db.previewOnSelect,"reset restores convenience defaults")
check(ui.db.weaponSound=="lightsabercrit_proc" and ui.db.totemSound=="lightsabercrit_proc","reset restores 0.4.1 default on both sounds")

-- Native Warcraft howl: exact volume override, known same-wolf fallback, no redistribution.
ui.SetVolume(40);ui.Play("wolf_howl",true)
check(played[#played].kit==1018 and played[#played].volume==0.4,"native Warcraft howl uses own volume override")
local normalKitPlay=C_Sound.PlaySound
local attempts={}
C_Sound.PlaySound=function(kit,channel,duplicates,callback,priority,volume)
 attempts[#attempts+1]={kit,volume}
 if kit==1018 then return false end
 return normalKitPlay(kit,channel,duplicates,callback,priority,volume)
end
check(ui.Play("wolf_howl",true) and #attempts==2 and attempts[2][1]==53875 and attempts[2][2]==0.4,"unavailable classic howl falls back only to same Warcraft wolf kit")
C_Sound.PlaySound=function() return false end
failures=ui.soundFailures;n=#played
check(not ui.Play("wolf_howl",true) and #played==n and ui.soundFailures==failures+1,"unavailable native kits report failure rather than substitute unrelated wolf")
C_Sound.PlaySound=normalKitPlay
local normalFilePlay=PlaySoundFile
local attemptedPaths={}
PlaySoundFile=function(path) attemptedPaths[#attemptedPaths+1]=path;return false end
check(not ui.Play("chicken",true) and #attemptedPaths==1 and attemptedPaths[1]:find("volume_40\\chicken.ogg",1,true),"missing quiet file never falls back to original loudness")
PlaySoundFile=normalFilePlay
ui.SetVolume(0);n=#played
check(ui.Play("wolf_howl",true) and #played==n,"zero volume also mutes native howl")
ui.SetVolume(100)


-- Compact three-tab layout and smaller-screen scaling.
clickText("Diagnostics")
check(WindfuryProcSoundDiagnosticsPanel.shown and not WindfuryProcSoundSoundPanel.shown and not WindfuryProcSoundPlaybackPanel.shown,"diagnostics has its own uncluttered tab")
clickText("Playback");clickText("Sounds")
check(WindfuryProcSoundSoundPanel.shown and not WindfuryProcSoundDiagnosticsPanel.shown,"returning to Sounds hides other content")
UIParent.GetWidth=function() return 520 end
UIParent.GetHeight=function() return 500 end
WindfuryProcSoundOptions:Hide();ui.ShowOptions()
check(WindfuryProcSoundOptions.scale<1 and WindfuryProcSoundOptions.width*WindfuryProcSoundOptions.scale<=488 and WindfuryProcSoundOptions.height*WindfuryProcSoundOptions.scale<=468,"options scale to smaller available UI area")
UIParent.GetWidth=function() return 1920 end
UIParent.GetHeight=function() return 1080 end
WindfuryProcSoundOptions:Hide();ui.ShowOptions()
check(WindfuryProcSoundOptions.scale==1,"normal screens preserve readable native scale")
-- Experimental extra hits use a separate selection/toggle and never merge
-- different item/talent spells just because they occur at the same time.
check(not C.Settings({},ns.sounds).extra, "other extra hits default off")
check(C.Settings({sound="chicken"},ns.sounds).extraSound=="chicken", "shared selection migrates to extra cue")
UnitClass=function() return "Warrior","WARRIOR" end
re(runtime.frame,"PLAYER_ENTERING_WORLD")
runtime.ResetCounters()
runtime.db.enabled=true;runtime.db.weapon=true;runtime.db.totem=true;runtime.db.extra=false
local extraIDs={1257049,15601,18797,21919}
clock=3000
for _,id in ipairs(extraIDs) do re(runtime.frame,"SPELL_UPDATE_COOLDOWN",id,nil,0,0,nil) end
check(runtime.detector.count==0,"all experimental extra-hit candidates disabled initially")
runtime.db.extra=true
runtime.SelectSound("bonk","extra")
runtime.SelectSound("chicken","totem")
for _,id in ipairs(extraIDs) do
 clock=clock+1;n=#played
 re(runtime.frame,"SPELL_UPDATE_COOLDOWN",id,nil,0,0,nil)
 check(#played==n+1 and played[#played][1]:find("bonk.ogg",1,true),"extra candidate uses own cue "..id)
 re(runtime.frame,"UNIT_SPELLCAST_SUCCEEDED","player","extra"..id,id)
 re(runtime.frame,"UNIT_AURA","player",{addedAuras={{spellId=id,auraInstanceID=id}}})
 check(#played==n+1,"same extra proc deduplicates across sources "..id)
end
check(runtime.detector.extra==4 and runtime.detector.weapon==0 and runtime.detector.totem==0,"other extra hits counted separately")
clock=3010;n=runtime.detector.extra
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",15601,nil,0,0,nil)
re(runtime.frame,"UNIT_SPELLCAST_SUCCEEDED","player","distinct-flurry",18797)
check(runtime.detector.extra==n+2,"simultaneous different item procs are not deduplicated together")
clock=3011;n=runtime.detector.extra
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",15601,nil,0,0,nil)
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",15601,nil,0,0,nil)
check(runtime.detector.extra==n+2,"rapid distinct same-source extra procs remain separate")
for _,id in ipairs({15600,12281,1290261,16459,11815,871,17705}) do
 n=runtime.detector.count
 re(runtime.frame,"SPELL_UPDATE_COOLDOWN",id,nil,0,0,nil)
 re(runtime.frame,"UNIT_SPELLCAST_SUCCEEDED","player","passive"..id,id)
 re(runtime.frame,"UNIT_AURA","player",{addedAuras={{spellId=id,auraInstanceID=id}}})
 check(runtime.detector.count==n,"passive, Classic-only and item IDs excluded "..id)
end
for _,id in ipairs(extraIDs) do
 for field=1,5 do
  local args={id,nil,0,0,nil};args[field]=secret;n=runtime.detector.count
  re(runtime.frame,"SPELL_UPDATE_COOLDOWN",unpackArgs(args,1,5))
  check(runtime.detector.count==n,"restricted extra cooldown field ignored "..id..":"..field)
 end
 n=runtime.detector.count
 re(runtime.frame,"SPELL_UPDATE_COOLDOWN",id,nil,2619,0,nil)
 re(runtime.frame,"SPELL_UPDATE_COOLDOWN",id,nil,0,133,nil)
 re(runtime.frame,"SPELL_UPDATE_COOLDOWN",id,id,0,0,nil)
 re(runtime.frame,"SPELL_UPDATE_COOLDOWN",id,nil,0,0,11815)
 re(runtime.frame,"UNIT_SPELLCAST_SUCCEEDED","target","other-player",id)
 re(runtime.frame,"UNIT_AURA","player",{isFullUpdate=true,addedAuras={{spellId=id,auraInstanceID=id}}})
 check(runtime.detector.count==n,"nonmatching or non-player extra candidates ignored "..id)
end
UnitClass=function() return "Shaman","SHAMAN" end
re(runtime.frame,"PLAYER_ENTERING_WORLD")
clock=3020;n=runtime.detector.count
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",1257049,nil,0,0,nil)
re(runtime.frame,"UNIT_SPELLCAST_SUCCEEDED","player","not-warrior",1257049)
re(runtime.frame,"UNIT_AURA","player",{addedAuras={{spellId=1257049,auraInstanceID=1}}})
check(runtime.detector.count==n,"Weaponmaster extra attack is warrior-only on all sources")
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",15601,nil,0,0,nil)
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",18797,nil,0,0,nil)
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",21919,nil,0,0,nil)
check(runtime.detector.count==n+3,"item extra attacks can be detected on a shaman")
runtime.db.extra=false;n=runtime.detector.extra
clock=3030
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",439440,nil,0,0,nil)
re(runtime.frame,"SPELL_UPDATE_COOLDOWN",8516,nil,2619,0,nil)
check(runtime.detector.weapon==1 and runtime.detector.totem==1 and runtime.detector.extra==n,"Windfury remains independent of extra-hit toggle")
SlashCmdList.WINDFURYPROCSOUND("extra on")
check(ui.db.extra,"slash command enables extra-hit experiment")
SlashCmdList.WINDFURYPROCSOUND("sound extra 65")
check(ui.db.extraSound=="bonk" and ui.db.weaponSound=="lightsabercrit_proc","extra slash selection preserves Windfury cue")
SlashCmdList.WINDFURYPROCSOUND("test extra")
check(played[#played][1]:find("bonk.ogg",1,true),"extra preview uses its selection")
SlashCmdList.WINDFURYPROCSOUND("extra off")
check(not ui.db.extra,"slash command disables extra-hit experiment")
clickText("Sounds")
menuChoice(WindfuryProcSoundExtraMenu,"fruit_machine").func()
check(ui.db.extraSound=="fruit_machine" and ui.db.weaponSound=="lightsabercrit_proc" and WindfuryProcSoundExtraMenu.textValue=="Fruit machine payout","extra dropdown selection preserves Windfury cue")
clickText("Preview Other")
check(played[#played][1]:find("fruit_machine.ogg",1,true),"extra UI preview uses its selection")
WindfuryProcSoundExtraSpeaker.scripts.OnClick()
check(played[#played][1]:find("fruit_machine.ogg",1,true),"extra speaker previews its own selection")
menuChoice(WindfuryProcSoundWeaponMenu,"bonk").func()
clickText("Use Weapon cue for both")
check(ui.db.weaponSound=="bonk" and ui.db.totemSound=="bonk" and ui.db.extraSound=="fruit_machine","base Both button preserves independent other extra cue")
ui.SelectSound("chicken","totem")
clickText("Use Weapon cue for all")
check(ui.db.weaponSound=="bonk" and ui.db.totemSound=="bonk" and ui.db.extraSound=="bonk","All updates all three selections")
ui.SelectSound("fruit_machine","extra");ui.SelectSound("chicken","both")
check(ui.db.weaponSound=="chicken" and ui.db.totemSound=="chicken" and ui.db.extraSound=="fruit_machine","base both API preserves independent other extra cue")
ui.ResetOptions()
check(not ui.db.extra and ui.db.extraSound=="lightsabercrit_proc","restore defaults turns experiment off and resets extra selection")
runtime.ResetCounters()
check(runtime.detector.extra==0,"counter reset clears extra hits")

-- Fractional duration limits stop only the owned handle, without fade padding.
local timers, timedStops = {}, {}
C_Timer={NewTimer=function(seconds,callback)
 local timer={seconds=seconds,at=clock+seconds,callback=callback}
 function timer:Cancel() self.cancelled=true end
 timers[#timers+1]=timer
 return timer
end}
StopSound=function(handle,fade) timedStops[#timedStops+1]={handle=handle,fade=fade,at=clock} end
local function advance(to)
 clock=to
 for _,timer in ipairs(timers) do
  if not timer.cancelled and not timer.fired and timer.at<=clock then timer.fired=true;timer.callback() end
 end
end
ui.StopPlayback();ui.ResetOptions()
check(ui.db.maxDuration==0,"default maximum duration is unlimited")
check(math.abs(C.Settings({maxDuration=1.24},ns.sounds).maxDuration-1.2)<0.00001,"saved duration snaps to tenths")
check(C.Settings({maxDuration=math.huge},ns.sounds).maxDuration==0,"nonfinite saved duration repaired")
ui.SetMaxDuration(1.1);clock=4000;ui.Play("fruit_machine",true)
local timer=timers[#timers];local handle=#played
check(math.abs(timer.seconds-1.1)<0.00001,"preview schedules exact 1.1 second limit")
n=#timedStops;advance(4001.099)
check(#timedStops==n,"duration does not stop before deadline")
advance(timer.at)
check(#timedStops==n+1 and timedStops[#timedStops].handle==handle and timedStops[#timedStops].fade==0,"duration stops owned cue at deadline with zero fade")
ui.SetMaxDuration(1.2);clock=4010;ui.Play("fruit_machine",false,"extra")
check(math.abs(timers[#timers].seconds-1.2)<0.00001,"automatic extra cue uses 1.2 second limit")
local oldTimer=timers[#timers]
clock=4010.5;ui.Play("chicken",true);n=#timedStops
check(oldTimer.cancelled,"new cue cancels previous duration timer")
oldTimer.callback()
check(#timedStops==n,"stale timer cannot stop replacement cue")
ui.SetMaxDuration(2.5)
check(math.abs(timers[#timers].seconds-2.5)<0.00001,"2.5 second setting uses exact fractional value")
clock=4011.5;ui.SetMaxDuration(2)
check(math.abs(timers[#timers].seconds-1)<0.00001,"changing limit uses elapsed cue time")
n=#timedStops;ui.SetMaxDuration(0.5)
check(#timedStops==n+1 and timedStops[#timedStops].fade==0,"shortening below elapsed time stops cue immediately")
ui.SetMaxDuration(2.5);clock=4020;ui.Play("wolf_howl",true)
timer=timers[#timers]
check(math.abs(timer.seconds-2.5)<0.00001,"native SoundKit also uses duration cap")
ui.SetMaxDuration(0)
check(timer.cancelled,"unlimited cancels active deadline")
n=#timedStops;timer.callback()
check(#timedStops==n,"cancelled unlimited deadline cannot stop current cue")
clock=4030;ui.SetMaxDuration(1.1);ui.Play("fruit_machine",true);timer=timers[#timers]
ui.SetVolume(0)
check(timer.cancelled,"mute cancels duration timer")
ui.SetVolume(100);ui.Play("fruit_machine",true);timer=timers[#timers]
SlashCmdList.WINDFURYPROCSOUND("off")
check(timer.cancelled,"disable cancels duration timer")
ui.ResetOptions();clock=4040
SlashCmdList.WINDFURYPROCSOUND("duration 2.5")
check(ui.db.maxDuration==2.5,"duration slash accepts decimal seconds")
local input=WindfuryProcSoundDurationInput
input:SetText("1.1");input.scripts.OnEnterPressed(input)
check(math.abs(ui.db.maxDuration-1.1)<0.00001 and input:GetText()=="1.1","duration input preserves one decimal place")
input:SetText("1.26");input.scripts.OnEditFocusLost(input)
check(math.abs(ui.db.maxDuration-1.3)<0.00001 and input:GetText()=="1.3","duration input rounds to tenths on focus loss")
input:SetText("bad");input.scripts.OnEnterPressed(input)
check(math.abs(ui.db.maxDuration-1.3)<0.00001 and input:GetText()=="1.3","invalid duration input keeps current value")
input:SetText("9.9");input.scripts.OnEscapePressed(input)
check(math.abs(ui.db.maxDuration-1.3)<0.00001 and input:GetText()=="1.3","Escape restores saved duration")
ui.SetMaxDuration(99)
check(ui.db.maxDuration==30,"duration clamps to documented maximum")
ui.SetMaxDuration(-1)
check(ui.db.maxDuration==0,"negative duration clamps to unlimited")
ui.ResetOptions()
check(ui.db.maxDuration==0,"restore defaults clears duration cap")
print("PASS: " .. tests .. " assertions. Mocked API/UI tests; native game audio and layout require live checks.")
