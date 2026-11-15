local ADDON, ns = ...
local Core = ns.Core
local frame = CreateFrame("Frame")
local soundHandle
local unavailableWarned = false
local ready = false
ns.frame = frame
ns.registered = {}
ns.soundFailures = 0

function ns.Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff70caffWindfury Proc Sound:|r " .. message)
end

function ns.GetSound(id)
    for _, sound in ipairs(ns.sounds) do if sound.id == id then return sound end end
    return ns.sounds[1]
end

function ns.Play(id, preview)
    local selected = ns.GetSound(id or ns.db.sound)
    local path = "Interface\\AddOns\\" .. ADDON .. "\\sounds\\" .. selected.file
    -- Keep only one cue playing. No CVars, game sound muting, or volume changes.
    if soundHandle and type(StopSound) == "function" then pcall(StopSound, soundHandle, 50) end
    soundHandle = nil
    local ok, willPlay, handle = pcall(PlaySoundFile, path, ns.db.channel)
    if ok and willPlay then
        soundHandle = handle
        if preview then ns.Print("Preview: " .. selected.name) end
        return true
    end
    ns.soundFailures = ns.soundFailures + 1
    if preview or not unavailableWarned then
        ns.Print("Sound could not play. Check the sounds folder and game audio settings; use /wfps test.")
        unavailableWarned = true
    end
    return false
end

ns.detector = Core.NewDetector(function() ns.Play() end)

local function observe(spellID, source, token)
    if ns.legacyActive then return end
    ns.detector:Observe(spellID, source, token, GetTime(), ns.db)
end

local function playerUnit(unit)
    if Core.IsSecret(unit) then ns.detector.restricted = ns.detector.restricted + 1; return false end
    return unit == "player"
end

local function onAura(unit, updateInfo)
    if not playerUnit(unit) then return end
    if Core.IsSecret(updateInfo) then ns.detector.restricted = ns.detector.restricted + 1; return end
    if type(updateInfo) ~= "table" then return end
    -- Full snapshots can contain old proc auras: do not treat them as new procs.
    local full = updateInfo.isFullUpdate
    if Core.IsSecret(full) or full then return end
    local added = updateInfo.addedAuras
    if Core.IsSecret(added) then ns.detector.restricted = ns.detector.restricted + 1; return end
    if type(added) ~= "table" then return end
    for _, aura in ipairs(added) do
        if not Core.IsSecret(aura) and type(aura) == "table" then
            observe(aura.spellId, "aura", aura.auraInstanceID)
        end
    end
end

local function registerUnit(event)
    local ok, result = pcall(frame.RegisterUnitEvent, frame, event, "player")
    ns.registered[event] = ok and result ~= false
end

local function legacyLoaded()
    local check = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if type(check) ~= "function" then return false end
    local ok, loaded = pcall(check, "WindfurySaber")
    return ok and loaded == true
end

function ns.Status()
    local d = ns.detector
    if ns.legacyActive then ns.Print("Automatic cues paused while the legacy addon is loaded. Disable the old addon, then reload.") end
    ns.Print((ns.db.enabled and "On" or "Off") .. "; " .. ns.GetSound(ns.db.sound).name .. "; " .. ns.db.channel .. " channel.")
    ns.Print("This session: " .. d.count .. " detected procs, " .. d.readable .. " readable candidates, " .. d.restricted .. " restricted payloads skipped; " .. ns.soundFailures .. " playback failures.")
    ns.Print("Events: cast=" .. tostring(ns.registered.UNIT_SPELLCAST_SUCCEEDED) .. ", aura=" .. tostring(ns.registered.UNIT_AURA) .. ". Live Forever validation is still needed.")
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON then return end
        local migrating = type(WindfuryProcSoundDB) ~= "table" and type(WindfurySaberDB) == "table"
        ns.db = Core.Settings(migrating and WindfurySaberDB or WindfuryProcSoundDB, ns.sounds)
        WindfuryProcSoundDB = ns.db
        ns.legacyActive = legacyLoaded()
        if migrating then ns.Print("Previous options imported into Windfury Proc Sound.") end
        if ns.legacyActive then ns.Print("Disable the old addon in the AddOns menu, then reload. New automatic cues are paused to avoid doubles.") end
        ready = true
        registerUnit("UNIT_SPELLCAST_SUCCEEDED")
        registerUnit("UNIT_AURA")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        if ns.RegisterSettings then ns.RegisterSettings() end
        frame:UnregisterEvent("ADDON_LOADED")
    elseif ready and event == "PLAYER_ENTERING_WORLD" then
        ns.detector.events = {}
    elseif ready and event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if playerUnit(unit) then observe(spellID, "cast", castGUID) end
    elseif ready and event == "UNIT_AURA" then
        -- A restriction can prohibit a table-field read even when the container
        -- itself is not secret. Fail closed; do not attempt to reveal the data.
        local ok = pcall(onAura, ...)
        if not ok then ns.detector.restricted = ns.detector.restricted + 1 end
    end
end)
frame:RegisterEvent("ADDON_LOADED")

SLASH_WINDFURYPROCSOUND1 = "/wfps"
SLASH_WINDFURYPROCSOUND2 = "/windfuryprocsound"
SLASH_WINDFURYPROCSOUND3 = "/wfs"
SLASH_WINDFURYPROCSOUND4 = "/windfurysaber" -- Legacy command alias.
SlashCmdList.WINDFURYPROCSOUND = function(text)
    if not ready then return end
    local cmd, arg = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "test" then ns.Play(nil, true)
    elseif cmd == "status" then ns.Status()
    elseif cmd == "on" or cmd == "off" then
        ns.db.enabled = cmd == "on"; ns.detector.events = {}; ns.Status()
        if ns.RefreshOptions then ns.RefreshOptions() end
    elseif cmd == "sound" then
        local found
        for i, sound in ipairs(ns.sounds) do
            if arg == sound.id or tonumber(arg) == i then found = sound end
        end
        if found then ns.db.sound = found.id; ns.Play(nil, true); if ns.RefreshOptions then ns.RefreshOptions() end
        else ns.Print("Use /wfps to choose one of the " .. #ns.sounds .. " sounds, or /wfps sound NUMBER (1-" .. #ns.sounds .. ").") end
    elseif cmd == "reset" then
        ns.db = Core.Settings({}, ns.sounds); WindfuryProcSoundDB = ns.db; ns.detector:Reset()
        ns.soundFailures = 0; unavailableWarned = false
        if ns.RefreshOptions then ns.RefreshOptions() end
        ns.Print("Options and session counters reset.")
    elseif cmd == "" or cmd == "options" then ns.ShowOptions()
    else ns.Print("/wfps options, test, sound 1-" .. #ns.sounds .. ", status, on, off, reset") end
end
