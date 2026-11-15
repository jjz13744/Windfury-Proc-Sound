local ADDON, ns = ...
local window, summary, enable, weapon, totem, master, sfx
local choices = {}

local function label(parent, text, x, y, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y); fs:SetText(text)
    return fs
end

local function button(parent, text, width, x, y, action)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 25); b:SetPoint("TOPLEFT", x, y); b:SetText(text); b:SetScript("OnClick", action)
    return b
end

local function check(parent, text, x, y, field)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetPoint("TOPLEFT", x, y); b.text:SetText(text)
    b:SetScript("OnClick", function(self)
        ns.db[field] = self:GetChecked() and true or false
        ns.detector.events = {}
        ns.RefreshOptions()
    end)
    return b
end

function ns.RefreshOptions()
    if not window or not ns.db then return end
    enable:SetChecked(ns.db.enabled); weapon:SetChecked(ns.db.weapon); totem:SetChecked(ns.db.totem)
    master:SetEnabled(ns.db.channel ~= "Master"); sfx:SetEnabled(ns.db.channel ~= "SFX")
    for id, b in pairs(choices) do
        b:SetText((ns.db.sound == id and "|cff70ff90> |r" or "") .. ns.GetSound(id).name)
    end
    summary:SetText("Selected: " .. ns.GetSound(ns.db.sound).name .. "  |  Channel: " .. ns.db.channel)
end

local function makeWindow()
    window = CreateFrame("Frame", "WindfuryProcSoundOptions", UIParent, "BackdropTemplate")
    local rows = math.ceil(#ns.sounds / 2)
    local extraHeight = math.max(0, rows - 10) * 31
    window:SetSize(600, 570 + extraHeight); window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true); window:EnableMouse(true); window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    window:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() window:Hide() end)
    label(window, "Windfury Proc Sound", 22, -22, "GameFontNormalLarge")
    label(window, "Choose a cue, then Preview. Changes save automatically.", 22, -48, "GameFontHighlightSmall")
    enable = check(window, "Enable", 18, -67, "enabled")
    weapon = check(window, "Windfury Weapon", 150, -67, "weapon")
    totem = check(window, "Windfury Totem", 360, -67, "totem")
    label(window, "Audio channel:", 24, -112)
    master = button(window, "Master", 82, 145, -105, function() ns.db.channel = "Master"; ns.RefreshOptions() end)
    sfx = button(window, "SFX", 82, 232, -105, function() ns.db.channel = "SFX"; ns.RefreshOptions() end)
    button(window, "Preview selected", 150, 420, -105, function() ns.Play(nil, true) end)
    for i, sound in ipairs(ns.sounds) do
        local choice = sound
        local col = math.floor((i - 1) / rows)
        local row = (i - 1) % rows
        local x, y = 22 + col * 284, -148 - row * 31
        choices[choice.id] = button(window, choice.name, 197, x, y, function()
            ns.db.sound = choice.id; ns.RefreshOptions()
        end)
        button(window, "Play", 62, x + 202, y, function() ns.Play(choice.id, true) end)
    end
    summary = label(window, "", 24, -468 - extraHeight, "GameFontHighlight")
    label(window, "Separate Weapon / Totem cooldown signatures. Restricted values are skipped.", 24, -493 - extraHeight, "GameFontHighlightSmall")
    label(window, "Use /wfps status for counts. Live playback and party isolation need verification.", 24, -510 - extraHeight, "GameFontHighlightSmall")
    button(window, "Diagnostics", 115, 24, -532 - extraHeight, ns.Status)
    button(window, "Close", 90, 480, -532 - extraHeight, function() window:Hide() end)
    UISpecialFrames[#UISpecialFrames + 1] = "WindfuryProcSoundOptions"
    window:SetScript("OnShow", ns.RefreshOptions)
    window:Hide()
end

function ns.ShowOptions()
    if not window then makeWindow() end
    window:Show(); ns.RefreshOptions()
end

function ns.RegisterSettings()
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return end
    local panel = CreateFrame("Frame")
    panel.name = "Windfury Proc Sound"
    label(panel, "Windfury Proc Sound", 18, -20, "GameFontNormalLarge")
    label(panel, tostring(#ns.sounds) .. " selectable sound cues for player Windfury procs.", 18, -50, "GameFontHighlight")
    button(panel, "Open sound options", 180, 18, -82, ns.ShowOptions)
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Windfury Proc Sound")
    if ok and category then pcall(Settings.RegisterAddOnCategory, category) end
end
