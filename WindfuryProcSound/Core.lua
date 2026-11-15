local _, ns = ...
local Core = {}
ns.Core = Core

-- Proc spells, NOT the casts that apply the weapon imbue or place the totem.
-- Verified against GaleCount's published Forever source; see SOURCES.md.
Core.procIDs = {
    [8233] = "weapon", [8236] = "weapon", [10484] = "weapon", [16361] = "weapon",
    [8516] = "totem", [10608] = "totem", [10610] = "totem",
}
Core.defaults = { enabled = true, weapon = true, totem = true, sound = "lightsaber", channel = "Master" }
Core.window = 0.25

function Core.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
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
    return out
end

function Core.NewDetector(emit)
    local self = { events = {}, count = 0, restricted = 0, readable = 0 }
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
        local records = self.events[spellID] or {}
        self.events[spellID] = records
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
        emit(spellID, kind)
        return true
    end
    function self:Reset()
        self.events = {}; self.count = 0; self.restricted = 0; self.readable = 0
    end
    return self
end
