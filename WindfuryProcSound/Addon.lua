local ADDON, ns = ...
local Core = ns.Core
local frame = CreateFrame("Frame")
local soundHandle
local lastAutomaticPlay
local lastRandomIndex
local unavailableWarned = false
local ready = false
ns.frame = frame
ns.registered = {}
ns.soundFailures = 0
ns.suppressed = 0

function ns.Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff70caffWindfury Proc Sound:|r " .. message)
end

function ns.GetSound(id)
    for _, sound in ipairs(ns.sounds) do if sound.id == id then return sound end end
    return ns.sounds[1]
end

function ns.StopPlayback()
    if soundHandle and type(StopSound) == "function" then pcall(StopSound, soundHandle, 50) end
    soundHandle = nil
end

function ns.SelectSound(id, kind)
    local selected = ns.GetSound(id)
    if kind == "weapon" or kind == "totem" then
        ns.db[kind .. "Sound"] = selected.id
    else
        ns.db.sound = selected.id
        ns.db.weaponSound = selected.id
        ns.db.totemSound = selected.id
    end
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.SetVolume(value)
    ns.db.volume = Core.Snap(value, 0, 100, 10, 100)
    -- Muting stops only this addon's current cue. Other levels apply next play.
    if ns.db.volume == 0 then ns.StopPlayback() end
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.Play(id, preview, kind)
    local now = GetTime()
    if not preview and lastAutomaticPlay and now - lastAutomaticPlay < ns.db.minGap then
        ns.suppressed = ns.suppressed + 1; return true
    end
    kind = kind == "totem" and "totem" or "weapon"
    local selected = ns.GetSound(id or ns.db[kind .. "Sound"] or ns.db.sound)
    if not preview and ns.db.randomSound then
        local n = #ns.sounds
        local index = math.random(lastRandomIndex and n > 1 and n - 1 or n)
        if lastRandomIndex and n > 1 and index >= lastRandomIndex then index = index + 1 end
        lastRandomIndex = index
        selected = ns.sounds[index]
    end
    if ns.db.volume == 0 then
        ns.StopPlayback()
        if preview then ns.Print("Muted at 0%. Increase the addon volume to preview.")
        else ns.suppressed = ns.suppressed + 1 end
        return true
    end
    -- Custom cues use encoded gain; the native Warcraft howl uses SoundKit's
    -- documented volume override. Neither changes global CVars or audio timers.
    ns.StopPlayback()
    local ok, willPlay, handle
    if selected.soundKit then
        local play = C_Sound and C_Sound.PlaySound or PlaySound
        if type(play) == "function" then
            ok, willPlay, handle = pcall(play, selected.soundKit, ns.db.channel, false, false, nil, ns.db.volume / 100)
            if (not ok or not willPlay) and selected.fallbackSoundKit then
                ok, willPlay, handle = pcall(play, selected.fallbackSoundKit, ns.db.channel, false, false, nil, ns.db.volume / 100)
            end
        end
    else
        local path = Core.SoundPath(ADDON, selected.file, ns.db.volume)
        ok, willPlay, handle = pcall(PlaySoundFile, path, ns.db.channel)
    end
    if ok and willPlay then
        soundHandle = handle
        if preview then ns.Print("Preview: " .. selected.name .. " (" .. ns.db.volume .. "%)")
        else lastAutomaticPlay = now end
        return true
    end
    ns.soundFailures = ns.soundFailures + 1
    if preview or not unavailableWarned then
        ns.Print("Sound could not play. Check the sound files or native sound kit and restart after updating. No fallback to a louder or different cue is used.")
        unavailableWarned = true
    end
    return false
end

ns.detector = Core.NewDetector(function(_, kind) ns.Play(nil, false, kind) end)

function ns.ResetCounters()
    ns.detector:Reset()
    ns.soundFailures = 0; ns.suppressed = 0; unavailableWarned = false
    lastAutomaticPlay = nil
end

function ns.ResetOptions()
    ns.StopPlayback(); ns.StopTrace(false); ns.trace = nil
    ns.db = Core.Settings({}, ns.sounds); WindfuryProcSoundDB = ns.db
    ns.ResetCounters(); lastRandomIndex = nil
    if ns.RefreshOptions then ns.RefreshOptions() end
    ns.Print("Options and session counters reset.")
end

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
    ns.Print("Version 0.3.2; separate Weapon and Totem cooldown signatures.")
    ns.Print((ns.db.enabled and "On" or "Off") .. "; " .. ns.db.volume .. "% addon volume; " .. ns.db.channel .. "; minimum gap " .. string.format("%.1f", ns.db.minGap) .. "s.")
    ns.Print("Weapon: " .. ns.GetSound(ns.db.weaponSound).name .. "; Totem: " .. ns.GetSound(ns.db.totemSound).name .. "; random=" .. tostring(ns.db.randomSound) .. ".")
    ns.Print("This session: " .. d.count .. " detected procs (Weapon " .. d.weapon .. ", Totem " .. d.totem .. "), " .. d.readable .. " readable candidates, " .. d.restricted .. " restricted payloads skipped; " .. ns.soundFailures .. " playback failures; " .. ns.suppressed .. " cues muted or rate-limited.")
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
    if cmd == "test" then ns.Play(nil, true, arg:lower())
    elseif cmd == "stop" then ns.StopPlayback()
    elseif cmd == "clearcounts" then ns.ResetCounters(); ns.Print("Session counters reset; options kept.")
    elseif cmd == "volume" then
        local value = tonumber(arg)
        if value then ns.SetVolume(value); ns.Print("Addon volume: " .. ns.db.volume .. "%. Applies to subsequent cues; game channel/master settings still apply.")
        else ns.Print("/wfps volume 0-100 (10% steps)") end
    elseif cmd == "status" then ns.Status()
    elseif cmd == "trace" then
        arg = arg:lower()
        if arg == "on" or arg == "start" then ns.StartTrace()
        elseif arg == "off" or arg == "stop" then ns.StopTrace(true)
        elseif arg == "clear" then ns.StopTrace(false); ns.trace = nil; ns.db.lastTrace = nil; ns.Print("Trace cleared.")
        elseif arg == "" or arg == "show" then ns.ShowTrace()
        else ns.Print("/wfps trace on, show, stop, clear") end
    elseif cmd == "on" or cmd == "off" then
        ns.db.enabled = cmd == "on"; ns.detector.events = {}; if not ns.db.enabled then ns.StopPlayback() end; ns.Status()
        if ns.RefreshOptions then ns.RefreshOptions() end
    elseif cmd == "sound" then
        local target, choice = arg:match("^(weapon)%s+(.+)$")
        if not target then target, choice = arg:match("^(totem)%s+(.+)$") end
        choice = choice or arg
        local found
        for i, sound in ipairs(ns.sounds) do
            if choice == sound.id or tonumber(choice) == i then found = sound end
        end
        if found then ns.SelectSound(found.id, target); ns.Play(found.id, true, target)
        else ns.Print("/wfps sound NUMBER sets both; /wfps sound weapon NUMBER or /wfps sound totem NUMBER sets one. Use 1-" .. #ns.sounds .. ".") end
    elseif cmd == "reset" then ns.ResetOptions()
    elseif cmd == "" or cmd == "options" then ns.ShowOptions()
    else ns.Print("/wfps options, test, sound 1-" .. #ns.sounds .. ", test totem, volume 0-100, stop, clearcounts, status, trace on|show|stop|clear, on, off, reset") end
end
