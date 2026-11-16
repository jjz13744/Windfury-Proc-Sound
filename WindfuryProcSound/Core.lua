local _, ns = ...
local Core = {}
ns.Core = Core

-- Proc spells, NOT the casts that apply the weapon imbue or place the totem.
-- Sourced from GaleCount; actual Forever event delivery is unverified. See SOURCES.md.
Core.procIDs = {
    [439440] = "weapon", [8233] = "weapon", [8236] = "weapon", [10484] = "weapon", [16361] = "weapon",
    [8516] = "totem", [10608] = "totem", [10610] = "totem",
}
-- Triggered Add Extra Attacks spells from Forever DB2 build 1.60.1.70938.
-- Passive/application spells (e.g. Hand of Justice 15600) are excluded.
-- The spell identities are data-backed; public event delivery is unverified.
Core.extraProcIDs = {
    [1257049] = "Weaponmaster (Sword)",
    [15601] = "Hand of Justice",
    [18797] = "Flurry Axe",
    [21919] = "Thrash Blade",
}
for id in pairs(Core.extraProcIDs) do Core.procIDs[id] = "extra" end
Core.defaults = {
    enabled = true, weapon = true, totem = true, extra = false, sound = "lightsabercrit_proc", channel = "Master",
    volume = 100, minGap = 0, randomSound = false, previewOnSelect = false,
    maxDuration = 0,
}
Core.window = 0.25

function Core.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

function Core.Snap(value, low, high, step, fallback)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return math.max(low, math.min(high, math.floor(value / step + 0.5) * step))
end

function Core.SoundPath(addon, file, volume)
    volume = Core.Snap(volume, 0, 100, 10, 100)
    if volume == 0 then return nil end
    local folder = volume < 100 and ("volume_" .. volume .. "\\") or ""
    return "Interface\\AddOns\\" .. addon .. "\\sounds\\" .. folder .. file
end

function Core.Settings(saved, catalog)
    local out = {}
    saved = type(saved) == "table" and saved or {}
    for k, value in pairs(Core.defaults) do
        if type(saved[k]) == type(value) then out[k] = saved[k] else out[k] = value end
    end
    if out.channel ~= "Master" and out.channel ~= "SFX" then out.channel = "Master" end
    local valid = false
    for _, sound in ipairs(catalog) do if sound.id == out.sound then valid = true end end
    if not valid then out.sound = Core.defaults.sound end
    for _, kind in ipairs({"weapon", "totem", "extra"}) do
        local key = kind .. "Sound"
        out[key] = out.sound
        for _, sound in ipairs(catalog) do if sound.id == saved[key] then out[key] = sound.id end end
    end
    out.volume = Core.Snap(out.volume, 0, 100, 10, Core.defaults.volume)
    out.minGap = Core.Snap(out.minGap, 0, 2, 0.1, Core.defaults.minGap)
    out.maxDuration = Core.Snap(out.maxDuration, 0, 30, 0.1, Core.defaults.maxDuration)
    return out
end

-- Exact public event signature observed during a confirmed own proc. Do not
-- treat general refreshes, GCD/item updates, or a nearby spell ID as a proc.
function Core.MatchCooldown(spellID, baseSpellID, category, recovery, itemID)
    if Core.IsSecret(spellID) or Core.IsSecret(baseSpellID) or Core.IsSecret(category)
        or Core.IsSecret(recovery) or Core.IsSecret(itemID) then return false, true end
    if baseSpellID ~= nil or recovery ~= 0 or itemID ~= nil then return nil, false end
    if spellID == 439440 and category == 0 then return "weapon", false end
    -- Rank 1 was observed independently; higher ranks share the proc family.
    if (spellID == 8516 or spellID == 10608 or spellID == 10610) and category == 2619 then return "totem", false end
    -- Candidate only: the zero-category event shape is inferred, not observed.
    -- Other extra hits are opt-in; only Weaponmaster is warrior-gated.
    if type(spellID) == "number" and Core.extraProcIDs[spellID] and category == 0 then return "extra", false end
    return nil, false
end

function Core.NewDetector(emit)
    local self = { events = {}, count = 0, weapon = 0, totem = 0, extra = 0, restricted = 0, readable = 0 }
    function self:Observe(spellID, source, token, now, settings)
        if Core.IsSecret(spellID) then self.restricted = self.restricted + 1; return false end
        if type(spellID) ~= "number" then return false end
        self.readable = self.readable + 1
        local kind = Core.procIDs[spellID]
        if not kind then return false end
        if not settings.enabled or not settings[kind] then return false end
        -- Never inspect or stringify a secret cast GUID / aura instance ID.
        if Core.IsSecret(token) then token = nil end
        if type(token) ~= "string" and type(token) ~= "number" then token = nil end
        -- A current cooldown signal and legacy cast/aura ID can describe the
        -- same weapon proc. Match across sources by kind, not spell rank.
        -- Different item/talent extra attacks can occur together. They share
        -- a sound choice, but must never deduplicate one another.
        local eventKey = kind == "extra" and spellID or kind
        local records = self.events[eventKey] or {}
        self.events[eventKey] = records
        -- Only match the same proc across two event sources. Distinct rapid casts
        -- from the same source remain distinct, unlike a blanket audio throttle.
        for i = #records, 1, -1 do
            if now - records[i].time > Core.window then table.remove(records, i) end
        end
        if token ~= nil then
            for _, record in ipairs(records) do
                if record.tokens[source] == token then return false end
            end
        end
        for _, record in ipairs(records) do
            if not record.sources[source] then
                record.sources[source] = true
                record.tokens[source] = token
                return false
            end
        end
        records[#records + 1] = { time = now, sources = { [source] = true }, tokens = { [source] = token } }
        self.count = self.count + 1
        self[kind] = self[kind] + 1
        emit(spellID, kind)
        return true
    end
    function self:Reset()
        self.events = {}; self.count = 0; self.weapon = 0; self.totem = 0; self.extra = 0; self.restricted = 0; self.readable = 0
    end
    return self
end

-- Opt-in diagnostics contain only public numeric spell/category IDs and timing.
-- No character names, GUIDs, damage values, or secret payload values are stored.
Core.traceLimit = 120
function Core.TraceValue(value)
    if Core.IsSecret(value) then return "restricted" end
    if value == nil then return "nil" end
    if type(value) == "number" and value == value and value > -math.huge and value < math.huge then return value end
    return "other"
end

function Core.NewTrace(now)
    return { active = true, started = now, expires = now + 30, rows = {}, total = 0, dropped = 0 }
end

function Core.TraceRecord(trace, source, spellID, now, baseSpellID, category, startRecoveryCategory, itemID)
    if not trace or not trace.active then return end
    trace.total = trace.total + 1
    if #trace.rows >= Core.traceLimit then table.remove(trace.rows, 1); trace.dropped = trace.dropped + 1 end
    local row = { source = source, t = math.floor((now - trace.started) * 1000 + 0.5) / 1000, spellID = Core.TraceValue(spellID) }
    if source == "cooldown" then
        row.baseSpellID = Core.TraceValue(baseSpellID)
        row.category = Core.TraceValue(category)
        row.startRecoveryCategory = Core.TraceValue(startRecoveryCategory)
        row.itemID = Core.TraceValue(itemID)
    end
    trace.rows[#trace.rows + 1] = row
end

function Core.CopyTrace(saved)
    if type(saved) ~= "table" or type(saved.rows) ~= "table" then return nil end
    local copy = { active = false, rows = {}, total = tonumber(saved.total) or 0, dropped = tonumber(saved.dropped) or 0 }
    local sources = { cast = true, aura = true, ["aura-update"] = true, cooldown = true }
    local function field(v)
        if type(v) == "number" and v == v and v > -math.huge and v < math.huge then return v end
        if v == "nil" or v == "restricted" or v == "other" then return v end
        return "other"
    end
    for i = 1, math.min(#saved.rows, Core.traceLimit) do
        local row = saved.rows[i]
        if type(row) == "table" and type(row.source) == "string" and sources[row.source] then
            local out = { source = row.source, t = type(row.t) == "number" and row.t or 0, spellID = field(row.spellID) }
            if row.source == "cooldown" then
                for _, k in ipairs({ "baseSpellID", "category", "startRecoveryCategory", "itemID" }) do out[k] = field(row[k]) end
            end
            copy.rows[#copy.rows + 1] = out
        end
    end
    return copy
end
