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
print("PASS: " .. tests .. " assertions (Lua logic and mocked WoW APIs). No live game test.")
