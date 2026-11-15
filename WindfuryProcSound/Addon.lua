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
    Core.TraceRecord(ns.trace, source, spellID, GetTime())
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
    -- Trace-only reads must not interfere with the existing added-aura route.
    if ns.trace and ns.trace.active then
        pcall(function()
            local updated = updateInfo.updatedAuraInstanceIDs
            if not Core.IsSecret(updated) and type(updated) == "table"
                and C_UnitAuras and type(C_UnitAuras.GetAuraDataByAuraInstanceID) == "function" then
                for _, id in ipairs(updated) do
                    if not Core.IsSecret(id) and type(id) == "number" then
                        local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", id)
                        if ok and not Core.IsSecret(aura) and type(aura) == "table" then
                            Core.TraceRecord(ns.trace, "aura-update", aura.spellId, GetTime())
                        end
                    end
                end
            end
        end)
    end
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

local function syncCooldownEvent()
    -- Totem procs can affect any player class; only Weapon's signature is
    -- shaman-gated. These are the local client's public cooldown events.
    local ok, result = pcall(frame.RegisterEvent, frame, "SPELL_UPDATE_COOLDOWN")
    ns.registered.SPELL_UPDATE_COOLDOWN = ok and result ~= false
end

local function refreshPlayerClass()
    ns.isShaman = false
    if type(UnitClass) == "function" then
        local ok, _, class = pcall(UnitClass, "player")
        if ok and not Core.IsSecret(class) and type(class) == "string" then ns.isShaman = class == "SHAMAN" end
    end
    syncCooldownEvent()
end

function ns.StopTrace(announce)
    if ns.trace then ns.trace.active = false end
    frame:SetScript("OnUpdate", nil)
    syncCooldownEvent()
    if announce then ns.Print("Trace stopped. Use /wfps trace show to view it, then /reload when convenient to save it.") end
end

function ns.StartTrace()
    ns.StopTrace(false)
    ns.trace = Core.NewTrace(GetTime())
    ns.db.lastTrace = ns.trace
    syncCooldownEvent()
    ns.trace.cooldownRegistered = ns.registered.SPELL_UPDATE_COOLDOWN
    frame:SetScript("OnUpdate", function()
        if ns.trace and ns.trace.active and GetTime() >= ns.trace.expires then ns.StopTrace(true) end
    end)
    ns.Print("30-second diagnostic trace started. Trigger one Windfury proc, then /wfps trace show. Normal sound triggers remain enabled.")
    if not ns.trace.cooldownRegistered then ns.Print("Cooldown event unavailable; tracing readable player casts and auras only.") end
end

function ns.ShowTrace()
    ns.StopTrace(false)
    local trace = ns.trace
    if not trace then ns.Print("No trace yet. Use /wfps trace on."); return end
    ns.Print("Trace: " .. #trace.rows .. " rows, " .. trace.total .. " events, " .. trace.dropped .. " rows omitted. This is a public-event trace.")
    local grouped, order = {}, {}
    for _, row in ipairs(trace.rows) do
        local key = row.source .. " id=" .. tostring(row.spellID)
        if row.source == "cooldown" then
            key = key .. " base=" .. tostring(row.baseSpellID) .. " category=" .. tostring(row.category)
                .. " recovery=" .. tostring(row.startRecoveryCategory) .. " item=" .. tostring(row.itemID)
        end
        if not grouped[key] then grouped[key] = 0; order[#order + 1] = key end
        grouped[key] = grouped[key] + 1
    end
    table.sort(order, function(a,b)
        local ac, bc = a:find("id=439440", 1, true) ~= nil, b:find("id=439440", 1, true) ~= nil
        if ac ~= bc then return ac end
        return a < b
    end)
    for i = 1, math.min(15, #order) do local key = order[i]; ns.Print(key .. " x" .. grouped[key]) end
    if #order > 15 then ns.Print("More groups are saved in the trace. /reload when convenient saves all captured rows.") end
end

function ns.Status()
    local d = ns.detector
    if ns.legacyActive then ns.Print("Automatic cues paused while the legacy addon is loaded. Disable the old addon, then reload.") end
    ns.Print("Version 0.2.2; separate Weapon and Totem cooldown signatures.")
    ns.Print((ns.db.enabled and "On" or "Off") .. "; " .. ns.GetSound(ns.db.sound).name .. "; " .. ns.db.channel .. " channel.")
    ns.Print("This session: " .. d.count .. " detected procs (Weapon " .. d.weapon .. ", Totem " .. d.totem .. "), " .. d.readable .. " readable candidates, " .. d.restricted .. " restricted payloads skipped; " .. ns.soundFailures .. " playback failures.")
    ns.Print("Events: cast=" .. tostring(ns.registered.UNIT_SPELLCAST_SUCCEEDED) .. ", aura=" .. tostring(ns.registered.UNIT_AURA) .. ", cooldown=" .. tostring(ns.registered.SPELL_UPDATE_COOLDOWN) .. ", shaman=" .. tostring(ns.isShaman) .. ".")
    ns.Print("Both own-proc signals observed; playback and other-player isolation still need live verification.")
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON then return end
        local migrating = type(WindfuryProcSoundDB) ~= "table" and type(WindfurySaberDB) == "table"
        local previous = migrating and WindfurySaberDB or WindfuryProcSoundDB
        ns.db = Core.Settings(previous, ns.sounds)
        ns.trace = Core.CopyTrace(type(previous) == "table" and previous.lastTrace or nil)
        ns.db.lastTrace = ns.trace
        WindfuryProcSoundDB = ns.db
        ns.legacyActive = legacyLoaded()
        if migrating then ns.Print("Previous options imported into Windfury Proc Sound.") end
        if ns.legacyActive then ns.Print("Disable the old addon in the AddOns menu, then reload. New automatic cues are paused to avoid doubles.") end
        ready = true
        registerUnit("UNIT_SPELLCAST_SUCCEEDED")
        registerUnit("UNIT_AURA")
        refreshPlayerClass()
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        if ns.RegisterSettings then ns.RegisterSettings() end
        frame:UnregisterEvent("ADDON_LOADED")
    elseif ready and event == "PLAYER_ENTERING_WORLD" then
        ns.detector.events = {}
        refreshPlayerClass()
    elseif ready and event == "SPELL_UPDATE_COOLDOWN" then
        local spellID, baseSpellID, category, startRecoveryCategory, itemID = ...
        Core.TraceRecord(ns.trace, "cooldown", spellID, GetTime(), baseSpellID, category, startRecoveryCategory, itemID)
        if not ns.legacyActive then
            local kind, restricted = Core.MatchCooldown(spellID, baseSpellID, category, startRecoveryCategory, itemID)
            if restricted then ns.detector.restricted = ns.detector.restricted + 1 end
            if kind == "totem" or (kind == "weapon" and ns.isShaman) then
                ns.detector:Observe(spellID, "cooldown", nil, GetTime(), ns.db)
            end
        end
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
    elseif cmd == "trace" then
        arg = arg:lower()
        if arg == "on" or arg == "start" then ns.StartTrace()
        elseif arg == "off" or arg == "stop" then ns.StopTrace(true)
        elseif arg == "clear" then ns.StopTrace(false); ns.trace = nil; ns.db.lastTrace = nil; ns.Print("Trace cleared.")
        elseif arg == "" or arg == "show" then ns.ShowTrace()
        else ns.Print("/wfps trace on, show, stop, clear") end
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
        ns.StopTrace(false); ns.trace = nil
        ns.db = Core.Settings({}, ns.sounds); WindfuryProcSoundDB = ns.db; ns.detector:Reset()
        ns.soundFailures = 0; unavailableWarned = false
        if ns.RefreshOptions then ns.RefreshOptions() end
        ns.Print("Options and session counters reset.")
    elseif cmd == "" or cmd == "options" then ns.ShowOptions()
    else ns.Print("/wfps options, test, sound 1-" .. #ns.sounds .. ", status, trace on|show|stop|clear, on, off, reset") end
end
