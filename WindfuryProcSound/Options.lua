local ADDON, ns = ...
local window, soundPanel, playbackPanel, diagnosticsPanel, weaponSummary, totemSummary, detail, targetLabel, diagnosticsText
local enable, weapon, totem, master, sfx, volume, volumeValue, gap, gapValue, random, preview
local soundTab, playbackTab, diagnosticsTab
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
    s:SetSize(420, 18); s:SetPoint("TOPLEFT", x, y)
    s:SetOrientation("HORIZONTAL"); s:SetMinMaxValues(low, high)
    s:SetValueStep(step); s:SetObeyStepOnDrag(true)
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetBackdrop({bgFile="Interface\\Buttons\\UI-SliderBar-Background", edgeFile="Interface\\Buttons\\UI-SliderBar-Border", tile=true, tileSize=8, edgeSize=8, insets={left=3,right=3,top=6,bottom=6}})
    s:SetScript("OnValueChanged", function(_, value)
        if not refreshing then action(value) end
    end)
    return s
end

local function fitWindow()
    if not window or not UIParent or type(UIParent.GetWidth) ~= "function" or type(UIParent.GetHeight) ~= "function" then return end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if ns.Core.IsSecret(width) or ns.Core.IsSecret(height) or type(width) ~= "number" or type(height) ~= "number" then return end
    if width > 0 and height > 0 then window:SetScale(math.max(0.1, math.min(1, (width - 32) / 640, (height - 32) / 600))) end
end

local function showTab(which)
    soundPanel:Hide(); playbackPanel:Hide(); diagnosticsPanel:Hide()
    if which == "playback" then playbackPanel:Show()
    elseif which == "diagnostics" then diagnosticsPanel:Show()
    else soundPanel:Show() end
    soundTab:SetEnabled(which ~= "sounds")
    playbackTab:SetEnabled(which ~= "playback")
    diagnosticsTab:SetEnabled(which ~= "diagnostics")
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
    weaponSummary:SetText(ns.GetSound(ns.db.weaponSound).name)
    totemSummary:SetText(ns.GetSound(ns.db.totemSound).name)
    local d = ns.detector
    diagnosticsText:SetText("Weapon procs: " .. d.weapon .. "    Totem procs: " .. d.totem .. "\n\nPlayback failures: " .. ns.soundFailures .. "    Muted / rate-limited: " .. ns.suppressed .. "\n\nReadable candidates: " .. d.readable .. "    Restricted payloads skipped: " .. d.restricted)
    detail:SetText(ns.db.volume .. "% addon volume  |  " .. ns.db.channel .. "  |  " .. (ns.db.randomSound and "Random cues on" or "Selected cues") .. "  |  Gap " .. string.format("%.1f", ns.db.minGap) .. "s")
    refreshing = false
end

local function makeWindow()
    window = CreateFrame("Frame", "WindfuryProcSoundOptions", UIParent, "BackdropTemplate")
    window:SetSize(640, 600); window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true); window:EnableMouse(true); window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    window:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=8,right=8,top=8,bottom=8} })
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4); close:SetScript("OnClick", function() window:Hide() end)
    label(window, "Windfury Proc Sound", 24, -22, "GameFontNormalLarge")
    label(window, "Your Windfury cues, your way. Changes save automatically.", 24, -48, "GameFontHighlightSmall")
    enable = check(window, "Enable alerts", 20, -72, "enabled")
    weapon = check(window, "Windfury Weapon", 200, -72, "weapon")
    totem = check(window, "Windfury Totem", 400, -72, "totem")
    soundTab = button(window, "Sounds", 115, 24, -112, function() showTab("sounds") end)
    playbackTab = button(window, "Playback", 115, 147, -112, function() showTab("playback") end)
    diagnosticsTab = button(window, "Diagnostics", 115, 270, -112, function() showTab("diagnostics") end)
    soundPanel = CreateFrame("Frame", "WindfuryProcSoundSoundPanel", window)
    soundPanel:SetPoint("TOPLEFT", 24, -158); soundPanel:SetSize(592, 290)
    playbackPanel = CreateFrame("Frame", "WindfuryProcSoundPlaybackPanel", window)
    playbackPanel:SetPoint("TOPLEFT", 24, -158); playbackPanel:SetSize(592, 290)
    diagnosticsPanel = CreateFrame("Frame", "WindfuryProcSoundDiagnosticsPanel", window)
    diagnosticsPanel:SetPoint("TOPLEFT", 24, -158); diagnosticsPanel:SetSize(592, 290)
    targetLabel = label(soundPanel, "", 0, -6, "GameFontHighlightSmall")
    targetButtons.both = button(soundPanel, "Both", 75, 310, 0, function() target="both"; ns.RefreshOptions() end)
    targetButtons.weapon = button(soundPanel, "Weapon", 90, 392, 0, function() target="weapon"; ns.RefreshOptions() end)
    targetButtons.totem = button(soundPanel, "Totem", 90, 489, 0, function() target="totem"; ns.RefreshOptions() end)
    local rows = math.ceil(#ns.sounds / 3)
    for i, sound in ipairs(ns.sounds) do
        local choice = sound
        local col, row = math.floor((i - 1) / rows), (i - 1) % rows
        local x, y = col * 200, -46 - row * 34
        choices[choice.id] = button(soundPanel, choice.name, 146, x, y, function()
            ns.SelectSound(choice.id, target)
            if ns.db.previewOnSelect then ns.Play(choice.id, true) end
        end)
        button(soundPanel, "Play", 42, x + 150, y, function() ns.Play(choice.id, true) end)
    end
    label(playbackPanel, "Addon volume", 2, -4)
    volume = slider(playbackPanel, "WindfuryProcSoundVolumeSlider", 0, 100, 10, 18, -32, ns.SetVolume)
    volumeValue = label(playbackPanel, "", 466, -33)
    label(playbackPanel, "0% mutes  /  100% full. Game audio settings still apply.", 18, -58, "GameFontHighlightSmall")
    label(playbackPanel, "Audio channel", 2, -98)
    master = button(playbackPanel, "Master", 82, 145, -91, function() ns.db.channel="Master"; ns.RefreshOptions() end)
    sfx = button(playbackPanel, "SFX", 82, 232, -91, function() ns.db.channel="SFX"; ns.RefreshOptions() end)
    label(playbackPanel, "Minimum gap between cues", 2, -137)
    gap = slider(playbackPanel, "WindfuryProcSoundGapSlider", 0, 2, 0.1, 18, -164, function(value)
        ns.db.minGap=ns.Core.Snap(value,0,2,0.1,0); ns.RefreshOptions()
    end)
    gapValue = label(playbackPanel, "", 466, -165)
    label(playbackPanel, "0s plays every detected proc. Previews ignore this gap.", 18, -190, "GameFontHighlightSmall")
    random = check(playbackPanel, "Random cue each proc", -4, -216, "randomSound")
    preview = check(playbackPanel, "Preview on selection", 296, -216, "previewOnSelect")
    button(playbackPanel, "Restore defaults", 145, 0, -263, ns.ResetOptions)
    label(playbackPanel, "Resets sounds, volume and playback options.", 160, -269, "GameFontHighlightSmall")
    label(diagnosticsPanel, "Session snapshot", 2, -5)
    diagnosticsText = label(diagnosticsPanel, "", 2, -40, "GameFontHighlight")
    button(diagnosticsPanel, "Refresh", 100, 0, -154, ns.RefreshOptions)
    button(diagnosticsPanel, "Reset counters", 140, 110, -154, function() ns.ResetCounters(); ns.RefreshOptions() end)
    button(diagnosticsPanel, "Print status", 120, 260, -154, ns.Status)
    label(diagnosticsPanel, "Troubleshooting trace (30 seconds, public IDs only)", 2, -205, "GameFontHighlightSmall")
    button(diagnosticsPanel, "Start trace", 120, 0, -234, ns.StartTrace)
    button(diagnosticsPanel, "Show / stop", 120, 130, -234, ns.ShowTrace)
    button(diagnosticsPanel, "Clear trace", 120, 260, -234, function()
        ns.StopTrace(false); ns.trace=nil; ns.db.lastTrace=nil; ns.Print("Trace cleared.")
    end)
    label(window, "WEAPON CUE", 24, -471, "GameFontNormalSmall")
    label(window, "TOTEM CUE", 338, -471, "GameFontNormalSmall")
    weaponSummary = label(window, "", 24, -490, "GameFontHighlight")
    totemSummary = label(window, "", 338, -490, "GameFontHighlight")
    detail = label(window, "", 24, -519, "GameFontHighlightSmall")
    button(window, "Stop sound", 96, 24, -555, ns.StopPlayback)
    button(window, "Preview Weapon", 145, 130, -555, function() ns.Play(nil, true, "weapon") end)
    button(window, "Preview Totem", 145, 285, -555, function() ns.Play(nil, true, "totem") end)
    button(window, "Close", 84, 532, -555, function() window:Hide() end)
    UISpecialFrames[#UISpecialFrames + 1] = "WindfuryProcSoundOptions"
    window:SetScript("OnShow", function() fitWindow(); ns.RefreshOptions() end)
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
