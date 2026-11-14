local ns = {}
local tests = 0
local function check(value, message)
    assert(value, message); tests = tests + 1
end
local secret = {}
issecretvalue = function(v) return rawequal(v, secret) end
assert(loadfile("WindfurySaber/Core.lua"))("WindfurySaber", ns)
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
    function f:SetChecked(v) self.checked = v end
    function f:GetChecked() return self.checked end
    function f:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:Hide() self.shown=false end
    local noOp = function() end
    for _, n in ipairs({"SetSize", "SetPoint", "SetFrameStrata", "SetClampedToScreen", "EnableMouse", "SetMovable", "RegisterForDrag", "SetBackdrop", "SetEnabled", "StartMoving", "StopMovingOrSizing"}) do f[n] = noOp end
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
assert(loadfile("WindfurySaber/Sounds.lua"))("WindfurySaber", ns)
check(#ns.sounds == 20, "20 sounds")
local unique = {}
for _, s in ipairs(ns.sounds) do
    check(not unique[s.id], "unique sound " .. s.id); unique[s.id] = true
    local audio = assert(io.open("WindfurySaber/sounds/" .. s.file, "rb"))
    check(audio:read(4)=="OggS", "valid OGG header " .. s.id); audio:close()
end
assert(loadfile("WindfurySaber/Addon.lua"))("WindfurySaber", ns)
assert(loadfile("WindfurySaber/Options.lua"))("WindfurySaber", ns)
local event=ns.frame.scripts.OnEvent
event(ns.frame, "ADDON_LOADED", "WindfurySaber")
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
SlashCmdList.WINDFURYSABER("sound 2")
check(ns.db.sound==ns.sounds[2].id and #played==2, "select sound by number")
SlashCmdList.WINDFURYSABER("off")
clock=110; event(ns.frame, "UNIT_SPELLCAST_SUCCEEDED", "player", "off", 8233)
check(#played==2, "disabled handler silent")
SlashCmdList.WINDFURYSABER("test")
check(#played==3, "manual preview works when disabled")
SlashCmdList.WINDFURYSABER("options")
check(WindfurySaberOptions.shown, "options opens")
SlashCmdList.WINDFURYSABER("reset")
check(ns.db.enabled and ns.db.sound=="lightsaber", "reset command")
SlashCmdList.WINDFURYSABER("status")
check(#messages > 0, "status prints")
PlaySoundFile=function() return false end
check(not ns.Play(nil,true) and ns.soundFailures==1, "playback failure reported")
SlashCmdList.WINDFURYSABER("reset")
check(ns.soundFailures == 0, "reset playback failure counter")
print("PASS: " .. tests .. " assertions (Lua logic and mocked WoW APIs). No live game test.")
