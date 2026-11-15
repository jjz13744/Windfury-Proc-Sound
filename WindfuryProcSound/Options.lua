local ADDON, ns = ...
local window, soundPanel, playbackPanel, summary, detail, targetLabel
local enable, weapon, totem, master, sfx, volume, volumeValue, gap, gapValue, random, preview
local soundTab, playbackTab
local choices, targetButtons = {}, {}
local target = "both"
local refreshing = false

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
        if field == "enabled" or field == "weapon" or field == "totem" then ns.detector.events = {} end
        if field == "enabled" and not ns.db.enabled then ns.StopPlayback() end
        ns.RefreshOptions()
    end)
    return b
end

local function slider(parent, name, low, high, step, x, y, action)
    local s = CreateFrame("Slider", name, parent, "BackdropTemplate")
    s:SetSize(400, 18); s:SetPoint("TOPLEFT", x, y)
    s:SetOrientation("HORIZONTAL"); s:SetMinMaxValues(low, high)
    s:SetValueStep(step); s:SetObeyStepOnDrag(true)
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetBackdrop({bgFile="Interface\\Buttons\\UI-SliderBar-Background", edgeFile="Interface\\Buttons\\UI-SliderBar-Border", tile=true, tileSize=8, edgeSize=8, insets={left=3,right=3,top=6,bottom=6}})
    s:SetScript("OnValueChanged", function(_, value)
        if not refreshing then action(value) end
    end)
    return s
end

local function showTab(which)
    if which == "playback" then soundPanel:Hide(); playbackPanel:Show()
    else playbackPanel:Hide(); soundPanel:Show() end
    soundTab:SetEnabled(which == "playback")
    playbackTab:SetEnabled(which ~= "playback")
    ns.RefreshOptions()
end

function ns.RefreshOptions()
    if not window or not ns.db or not volume then return end
    refreshing = true
    enable:SetChecked(ns.db.enabled); weapon:SetChecked(ns.db.weapon); totem:SetChecked(ns.db.totem)
    random:SetChecked(ns.db.randomSound); preview:SetChecked(ns.db.previewOnSelect)
    master:SetEnabled(ns.db.channel ~= "Master"); sfx:SetEnabled(ns.db.channel ~= "SFX")
    volume:SetValue(ns.db.volume); volumeValue:SetText(ns.db.volume .. "%")
    gap:SetValue(ns.db.minGap); gapValue:SetText(string.format("%.1f s", ns.db.minGap))
    local selected = target == "weapon" and ns.db.weaponSound or target == "totem" and ns.db.totemSound
    if target == "both" and ns.db.weaponSound == ns.db.totemSound then selected = ns.db.weaponSound end
    for id, b in pairs(choices) do b:SetText((selected == id and "|cff70ff90> |r" or "") .. ns.GetSound(id).name) end
    for name, b in pairs(targetButtons) do b:SetEnabled(name ~= target) end
    targetLabel:SetText(target == "both" and "Choose a sound for both proc types:" or ("Choose a sound for " .. (target == "weapon" and "Weapon:" or "Totem:")))
    summary:SetText("Weapon: " .. ns.GetSound(ns.db.weaponSound).name .. "  |  Totem: " .. ns.GetSound(ns.db.totemSound).name)
    detail:SetText(ns.db.volume .. "% addon volume  |  " .. ns.db.channel .. "  |  " .. (ns.db.randomSound and "Random cues on" or "Selected cues") .. "  |  Gap " .. string.format("%.1f", ns.db.minGap) .. "s")
    refreshing = false
end

local function makeWindow()
    window = CreateFrame("Frame", "WindfuryProcSoundOptions", UIParent, "BackdropTemplate")
    window:SetSize(600, 650); window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true); window:EnableMouse(true); window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    window:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=8,right=8,top=8,bottom=8} })
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4); close:SetScript("OnClick", function() window:Hide() end)
    label(window, "Windfury Proc Sound", 22, -22, "GameFontNormalLarge")
    label(window, "Changes save automatically. Preview buttons always use your addon volume.", 22, -48, "GameFontHighlightSmall")
    enable = check(window, "Enable", 18, -67, "enabled")
    weapon = check(window, "Windfury Weapon", 150, -67, "weapon")
    totem = check(window, "Windfury Totem", 360, -67, "totem")
    soundTab = button(window, "Sounds", 115, 22, -108, function() showTab("sounds") end)
    playbackTab = button(window, "Playback", 115, 145, -108, function() showTab("playback") end)
    soundPanel = CreateFrame("Frame", "WindfuryProcSoundSoundPanel", window)
    soundPanel:SetPoint("TOPLEFT", 22, -150); soundPanel:SetSize(556, 390)
    playbackPanel = CreateFrame("Frame", "WindfuryProcSoundPlaybackPanel", window)
    playbackPanel:SetPoint("TOPLEFT", 22, -150); playbackPanel:SetSize(556, 390)
    targetLabel = label(soundPanel, "", 0, -5, "GameFontHighlightSmall")
    targetButtons.both = button(soundPanel, "Both", 75, 302, 0, function() target="both"; ns.RefreshOptions() end)
    targetButtons.weapon = button(soundPanel, "Weapon", 82, 382, 0, function() target="weapon"; ns.RefreshOptions() end)
    targetButtons.totem = button(soundPanel, "Totem", 82, 469, 0, function() target="totem"; ns.RefreshOptions() end)
    local rows = math.ceil(#ns.sounds / 2)
    for i, sound in ipairs(ns.sounds) do
        local choice = sound
        local col, row = math.floor((i - 1) / rows), (i - 1) % rows
        local x, y = col * 284, -42 - row * 31
        choices[choice.id] = button(soundPanel, choice.name, 197, x, y, function()
            ns.SelectSound(choice.id, target)
            if ns.db.previewOnSelect then ns.Play(choice.id, true) end
        end)
        button(soundPanel, "Play", 62, x + 202, y, function() ns.Play(choice.id, true) end)
    end
    label(playbackPanel, "Addon volume (10% steps)", 2, -6)
    volume = slider(playbackPanel, "WindfuryProcSoundVolumeSlider", 0, 100, 10, 18, -36, ns.SetVolume)
    volumeValue = label(playbackPanel, "", 444, -37)
    label(playbackPanel, "0% / muted", 18, -61, "GameFontHighlightSmall")
    label(playbackPanel, "100% / full", 328, -61, "GameFontHighlightSmall")
    label(playbackPanel, "Audio channel:", 2, -103)
    master = button(playbackPanel, "Master", 82, 145, -96, function() ns.db.channel="Master"; ns.RefreshOptions() end)
    sfx = button(playbackPanel, "SFX", 82, 232, -96, function() ns.db.channel="SFX"; ns.RefreshOptions() end)
    label(playbackPanel, "Minimum gap between automatic cues", 2, -151)
    gap = slider(playbackPanel, "WindfuryProcSoundGapSlider", 0, 2, 0.1, 18, -182, function(value)
        ns.db.minGap=ns.Core.Snap(value,0,2,0.1,0); ns.RefreshOptions()
    end)
    gapValue = label(playbackPanel, "", 444, -183)
    label(playbackPanel, "0s / every detected proc", 18, -207, "GameFontHighlightSmall")
    label(playbackPanel, "2 seconds", 354, -207, "GameFontHighlightSmall")
    random = check(playbackPanel, "Random sound each proc (no immediate repeats)", -4, -243, "randomSound")
    preview = check(playbackPanel, "Preview when selecting a sound", -4, -278, "previewOnSelect")
    button(playbackPanel, "Stop current sound", 165, 0, -325, ns.StopPlayback)
    button(playbackPanel, "Reset counters", 145, 180, -325, function() ns.ResetCounters(); ns.Print("Session counters reset; options kept.") end)
    button(playbackPanel, "Restore defaults", 145, 340, -325, ns.ResetOptions)
    label(playbackPanel, "Addon-only volume. Changes apply next cue; game audio settings still apply.", 2, -364, "GameFontHighlightSmall")
    summary = label(window, "", 24, -555, "GameFontHighlightSmall")
    detail = label(window, "", 24, -576, "GameFontHighlightSmall")
    button(window, "Preview Weapon", 145, 24, -611, function() ns.Play(nil, true, "weapon") end)
    button(window, "Preview Totem", 145, 178, -611, function() ns.Play(nil, true, "totem") end)
    button(window, "Diagnostics", 115, 332, -611, ns.Status)
    button(window, "Close", 90, 480, -611, function() window:Hide() end)
    UISpecialFrames[#UISpecialFrames + 1] = "WindfuryProcSoundOptions"
    window:SetScript("OnShow", ns.RefreshOptions)
    showTab("sounds"); window:Hide()
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
    label(panel, tostring(#ns.sounds) .. " sound cues, separate proc choices and addon-only volume.", 18, -50, "GameFontHighlight")
    button(panel, "Open sound options", 180, 18, -82, ns.ShowOptions)
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Windfury Proc Sound")
    if ok and category then pcall(Settings.RegisterAddOnCategory, category) end
end
