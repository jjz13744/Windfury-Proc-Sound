local ns = {}
local tests = 0
local function check(value, message)
    assert(value, message); tests = tests + 1
end
local secret = {}
issecretvalue = function(v) return rawequal(v, secret) end
assert(loadfile("WindfuryProcSound/Core.lua"))("WindfuryProcSound", ns)
local C = ns.Core
local catalog = {{id="lightsaber"}, {id="wolf"}}
local db = C.Settings(nil, catalog)
check(db.enabled and db.weapon and db.totem and db.sound == "lightsaber", "defaults")
local corrupt = C.Settings({enabled="yes", channel="Bad", sound="missing"}, catalog)
check(corrupt.enabled and corrupt.channel == "Master" and corrupt.sound == "lightsaber", "repair settings")
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
for id in pairs(C.procIDs) do check(d:Observe(id, "cast", "rank" .. id, 10, db), "rank " .. id) end
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
    function f:SetPoint(...) self.point = {...} end
    function f:SetSize(w,h) self.width=w; self.height=h end
    function f:SetChecked(v) self.checked = v end
    function f:GetChecked() return self.checked end
    function f:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:Hide() self.shown=false end
    local noOp = function() end
    for _, n in ipairs({"SetFrameStrata", "SetClampedToScreen", "EnableMouse", "SetMovable", "RegisterForDrag", "SetBackdrop", "SetEnabled", "StartMoving", "StopMovingOrSizing"}) do f[n] = noOp end
    return f
end
CreateFrame = function(_, name)
    local f=widget(); f.text=widget(); frames[#frames+1]=f
    if name then _G[name]=f end
    return f
end
DEFAULT_CHAT_FRAME = {AddMessage=function(_, m) messages[#messages+1]=m end}
PlaySoundFile=function(path, channel) played[#played+1]={path,channel}; return true,#played end
StopSound=function() end
GetTime=function() return clock end
SlashCmdList={}; UISpecialFrames={}; UIParent={}
Settings={ RegisterCanvasLayoutCategory=function() return {} end, RegisterAddOnCategory=function() end }
assert(loadfile("WindfuryProcSound/Sounds.lua"))("WindfuryProcSound", ns)
check(#ns.sounds == 21, "21 sounds")
local unique = {}
for _, s in ipairs(ns.sounds) do
    check(not unique[s.id], "unique sound " .. s.id); unique[s.id] = true
    local audio = assert(io.open("WindfuryProcSound/sounds/" .. s.file, "rb"))
    check(audio:read(4)=="OggS", "valid OGG header " .. s.id); audio:close()
end
assert(loadfile("WindfuryProcSound/Addon.lua"))("WindfuryProcSound", ns)
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
check(WindfuryProcSoundOptions.height == 601, "21-sound window grows for extra row")
local positions, selectable = {}, 0
for _, f in ipairs(frames) do
    if f.width == 197 and f.point then
        local key = tostring(f.point[2]) .. ":" .. tostring(f.point[3])
        check(not positions[key], "sound buttons do not overlap")
        positions[key] = true; selectable = selectable + 1
    end
end
check(selectable == 21, "all 21 sounds have option buttons")
SlashCmdList.WINDFURYPROCSOUND("sound 21")
check(ns.db.sound == "lightsabercrit_proc", "select new LightsaberCrit option")
check(played[#played][1]:find("lightsabercrit_proc.ogg",1,true) ~= nil, "new sound plays correct file")
SlashCmdList.WINDFURYPROCSOUND("sound lightsabercrit_proc")
check(ns.db.sound == "lightsabercrit_proc", "select new sound by ID")
SlashCmdList.WINDFURYPROCSOUND("reset")
check(ns.db.enabled and ns.db.sound=="lightsaber", "reset command")
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
print("PASS: " .. tests .. " assertions. Isolated live traces replayed with mocked APIs; live audio playback is still unverified.")
