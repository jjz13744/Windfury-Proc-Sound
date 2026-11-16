local ADDON, ns = ...
local window, soundPanel, playbackPanel, diagnosticsPanel, weaponSummary, totemSummary, extraSummary, detail, diagnosticsText
local enable, weapon, totem, extra, master, sfx, volume, volumeValue, gap, gapValue, random, preview, duration
local soundTab, playbackTab, diagnosticsTab
local weaponMenu, totemMenu, extraMenu
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
        if field == "enabled" or field == "weapon" or field == "totem" or field == "extra" then ns.detector.events = {} end
        if field == "enabled" and not ns.db.enabled then ns.StopPlayback() end
        ns.RefreshOptions()
    end)
    return b
end

-- Native two-level menus keep large libraries usable without a tall list.
local function soundMenu(parent, name, kind, x, y)
    local menu = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    menu:SetPoint("TOPLEFT", x, y)
    UIDropDownMenu_SetWidth(menu, 360)
    -- Open beside the arrow that was clicked, not the far-left edge of the field.
    -- Keep a frame-relative anchor so moving/scaling the options cannot leave it behind.
    local arrow = menu.Button or _G[name .. "Button"] or menu
    UIDropDownMenu_SetAnchor(menu, 0, 0, "TOPLEFT", arrow, "BOTTOMLEFT")
    UIDropDownMenu_Initialize(menu, function(_, level, group)
        level = level or 1
        if level == 1 then
            for _, category in ipairs(ns.SoundGroups(kind)) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = category; info.notCheckable = true
                info.hasArrow = true; info.menuList = category; info.keepShownOnClick = true
                UIDropDownMenu_AddButton(info, level)
            end
        elseif level == 2 then
            for _, sound in ipairs(ns.MenuSounds(kind, group)) do
                local id = sound.id
                local info = UIDropDownMenu_CreateInfo()
                info.text = sound.name; info.value = id
                info.checked = ns.db[kind .. "Sound"] == id
                info.func = function()
                    ns.SelectSound(id, kind)
                    if ns.db.previewOnSelect then ns.Play(id, true) end
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end)
    return menu
end

local function speaker(parent, name, kind, x, y)
    local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    b:SetSize(34, 28); b:SetPoint("TOPLEFT", x, y)
    b:SetText("|TInterface\\AddOns\\" .. ADDON .. "\\media\\speaker.tga:18:18|t")
    b:SetScript("OnClick", function() ns.Play(nil, true, kind) end)
    b:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Preview " .. (kind == "weapon" and "Weapon" or kind == "extra" and "Other extra hits" or "Totem") .. " cue")
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
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
    if width > 0 and height > 0 then window:SetScale(math.max(0.1, math.min(1, (width - 32) / 640, (height - 32) / 680))) end
end

local function showTab(which)
    CloseDropDownMenus()
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
    extra:SetChecked(ns.db.extra)
    random:SetChecked(ns.db.randomSound); preview:SetChecked(ns.db.previewOnSelect)
    master:SetEnabled(ns.db.channel ~= "Master"); sfx:SetEnabled(ns.db.channel ~= "SFX")
    volume:SetValue(ns.db.volume); volumeValue:SetText(ns.db.volume .. "%")
    gap:SetValue(ns.db.minGap); gapValue:SetText(string.format("%.1f s", ns.db.minGap))
    duration:SetText(string.format("%.1f", ns.db.maxDuration))
    UIDropDownMenu_SetText(weaponMenu, ns.GetSound(ns.db.weaponSound).name)
    UIDropDownMenu_SetText(totemMenu, ns.GetSound(ns.db.totemSound).name)
    UIDropDownMenu_SetText(extraMenu, ns.GetSound(ns.db.extraSound).name)
    weaponSummary:SetText(ns.GetSound(ns.db.weaponSound).name)
    totemSummary:SetText(ns.GetSound(ns.db.totemSound).name)
    extraSummary:SetText(ns.GetSound(ns.db.extraSound).name)
    local d = ns.detector
    diagnosticsText:SetText("Weapon procs: " .. d.weapon .. "    Totem procs: " .. d.totem .. "    Other extra hits: " .. d.extra .. "\n\nPlayback failures: " .. ns.soundFailures .. "    Muted / rate-limited: " .. ns.suppressed .. "\n\nReadable candidates: " .. d.readable .. "    Restricted payloads skipped: " .. d.restricted .. "\n\nOther extra hit detection is experimental and unverified in-game.")
    detail:SetText(ns.db.volume .. "% addon volume  |  " .. ns.db.channel .. "  |  Gap " .. string.format("%.1f", ns.db.minGap) .. "s  |  Max " .. (ns.db.maxDuration == 0 and "unlimited" or string.format("%.1fs", ns.db.maxDuration)))
    refreshing = false
end

local function makeWindow()
    window = CreateFrame("Frame", "WindfuryProcSoundOptions", UIParent, "BackdropTemplate")
    window:SetSize(640, 680); window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true); window:EnableMouse(true); window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    window:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=8,right=8,top=8,bottom=8} })
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4); close:SetScript("OnClick", function() window:Hide() end)
    label(window, "Windfury/Extra Hit Proc Sound", 24, -22, "GameFontNormalLarge")
    label(window, "Your Windfury cues, your way. Changes save automatically.", 24, -48, "GameFontHighlightSmall")
    enable = check(window, "Enable alerts", 20, -72, "enabled")
    weapon = check(window, "Windfury Weapon", 200, -72, "weapon")
    totem = check(window, "Windfury Totem", 400, -72, "totem")
    extra = check(window, "Other extra hit sounds (experimental)", 20, -102, "extra")
    label(window, "Items + Sword spec / Weaponmaster", 340, -110, "GameFontHighlightSmall")
    soundTab = button(window, "Sounds", 115, 24, -142, function() showTab("sounds") end)
    playbackTab = button(window, "Playback", 115, 147, -142, function() showTab("playback") end)
    diagnosticsTab = button(window, "Diagnostics", 115, 270, -142, function() showTab("diagnostics") end)
    soundPanel = CreateFrame("Frame", "WindfuryProcSoundSoundPanel", window)
    soundPanel:SetPoint("TOPLEFT", 24, -188); soundPanel:SetSize(592, 320)
    playbackPanel = CreateFrame("Frame", "WindfuryProcSoundPlaybackPanel", window)
    playbackPanel:SetPoint("TOPLEFT", 24, -188); playbackPanel:SetSize(592, 320)
    diagnosticsPanel = CreateFrame("Frame", "WindfuryProcSoundDiagnosticsPanel", window)
    diagnosticsPanel:SetPoint("TOPLEFT", 24, -188); diagnosticsPanel:SetSize(592, 320)
    label(soundPanel, "Windfury Weapon", 2, -4)
    weaponMenu = soundMenu(soundPanel, "WindfuryProcSoundWeaponMenu", "weapon", -14, -29)
    speaker(soundPanel, "WindfuryProcSoundWeaponSpeaker", "weapon", 400, -29)
    label(soundPanel, "Windfury Totem", 2, -82)
    totemMenu = soundMenu(soundPanel, "WindfuryProcSoundTotemMenu", "totem", -14, -107)
    speaker(soundPanel, "WindfuryProcSoundTotemSpeaker", "totem", 400, -107)
    label(soundPanel, "Other extra hits", 2, -160)
    extraMenu = soundMenu(soundPanel, "WindfuryProcSoundExtraMenu", "extra", -14, -185)
    speaker(soundPanel, "WindfuryProcSoundExtraSpeaker", "extra", 400, -185)
    button(soundPanel, "Use Weapon cue for both", 220, 0, -232, function()
        ns.SelectSound(ns.db.weaponSound, "totem")
    end)
    button(soundPanel, "Use Weapon cue for all", 220, 240, -232, function()
        ns.SelectSound(ns.db.weaponSound, "totem")
        ns.SelectSound(ns.db.weaponSound, "extra")
    end)
    label(soundPanel, "Choose a category, then a sound. Click the speaker to hear it.", 2, -278, "GameFontHighlightSmall")
    label(soundPanel, "Saved legacy cues keep working; old similar effects are hidden.", 2, -301, "GameFontHighlightSmall")
    label(playbackPanel, "Addon volume", 2, -4)
    volume = slider(playbackPanel, "WindfuryProcSoundVolumeSlider", 0, 100, 10, 18, -32, ns.SetVolume)
    volumeValue = label(playbackPanel, "", 466, -33)
    label(playbackPanel, "0% mutes  /  100% full. Game audio settings still apply.", 18, -58, "GameFontHighlightSmall")
    label(playbackPanel, "Audio channel", 2, -98)
    master = button(playbackPanel, "Master", 82, 145, -91, function() ns.db.channel="Master"; ns.RefreshOptions() end)
    sfx = button(playbackPanel, "SFX", 82, 232, -91, function() ns.db.channel="SFX"; ns.RefreshOptions() end)
    label(playbackPanel, "Max duration (s)", 338, -98)
    duration = CreateFrame("EditBox", "WindfuryProcSoundDurationInput", playbackPanel, "InputBoxTemplate")
    duration:SetSize(75, 25); duration:SetPoint("TOPLEFT", 490, -91)
    duration:SetAutoFocus(false); duration:SetMaxLetters(5)
    local function saveDuration(self)
        ns.SetMaxDuration(tonumber(self:GetText()))
    end
    duration:SetScript("OnEnterPressed", function(self) saveDuration(self); self:ClearFocus() end)
    duration:SetScript("OnEditFocusLost", saveDuration)
    duration:SetScript("OnEscapePressed", function(self) ns.RefreshOptions(); self:ClearFocus() end)
    label(playbackPanel, "0 = unlimited; 0.1 s steps (max 30)", 338, -120, "GameFontHighlightSmall")
    label(playbackPanel, "Minimum gap between cues", 2, -137)
    gap = slider(playbackPanel, "WindfuryProcSoundGapSlider", 0, 2, 0.1, 18, -164, function(value)
        ns.db.minGap=ns.Core.Snap(value,0,2,0.1,0); ns.RefreshOptions()
    end)
    gapValue = label(playbackPanel, "", 466, -165)
    label(playbackPanel, "0s plays every detected proc. Previews ignore this gap.", 18, -190, "GameFontHighlightSmall")
    random = check(playbackPanel, "Random cue each proc", -4, -216, "randomSound")
    preview = check(playbackPanel, "Preview on selection", 296, -216, "previewOnSelect")
    button(playbackPanel, "Restore defaults", 145, 0, -263, ns.ResetOptions)
    label(playbackPanel, "Resets sounds, volume, duration and playback options.", 160, -269, "GameFontHighlightSmall")
    label(diagnosticsPanel, "Session snapshot", 2, -5)
    diagnosticsText = label(diagnosticsPanel, "", 2, -40, "GameFontHighlight")
    button(diagnosticsPanel, "Refresh", 100, 0, -184, ns.RefreshOptions)
    button(diagnosticsPanel, "Reset counters", 140, 110, -184, function() ns.ResetCounters(); ns.RefreshOptions() end)
    button(diagnosticsPanel, "Print status", 120, 260, -184, ns.Status)
    label(diagnosticsPanel, "Troubleshooting trace (30 seconds, public IDs only)", 2, -235, "GameFontHighlightSmall")
    button(diagnosticsPanel, "Start trace", 120, 0, -264, ns.StartTrace)
    button(diagnosticsPanel, "Show / stop", 120, 130, -264, ns.ShowTrace)
    button(diagnosticsPanel, "Clear trace", 120, 260, -264, function()
        ns.StopTrace(false); ns.trace=nil; ns.db.lastTrace=nil; ns.Print("Trace cleared.")
    end)
    label(window, "WEAPON CUE", 24, -530, "GameFontNormalSmall")
    label(window, "TOTEM CUE", 224, -530, "GameFontNormalSmall")
    label(window, "OTHER EXTRA HITS", 424, -530, "GameFontNormalSmall")
    weaponSummary = label(window, "", 24, -549, "GameFontHighlight")
    totemSummary = label(window, "", 224, -549, "GameFontHighlight")
    extraSummary = label(window, "", 424, -549, "GameFontHighlight")
    detail = label(window, "", 24, -577, "GameFontHighlightSmall")
    button(window, "Stop sound", 96, 24, -613, ns.StopPlayback)
    button(window, "Preview Weapon", 145, 130, -613, function() ns.Play(nil, true, "weapon") end)
    button(window, "Preview Totem", 145, 285, -613, function() ns.Play(nil, true, "totem") end)
    button(window, "Preview Other", 145, 440, -613, function() ns.Play(nil, true, "extra") end)
    button(window, "Close", 84, 532, -645, function() window:Hide() end)
    UISpecialFrames[#UISpecialFrames + 1] = "WindfuryProcSoundOptions"
    window:SetScript("OnShow", function() fitWindow(); ns.RefreshOptions() end)
    window:SetScript("OnHide", function() CloseDropDownMenus(); if GameTooltip then GameTooltip:Hide() end end)
    showTab("sounds"); window:Hide()
end

function ns.ShowOptions()
    if not window then makeWindow() end
    window:Show(); ns.RefreshOptions()
end

function ns.RegisterSettings()
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return end
    local panel = CreateFrame("Frame")
    panel.name = "Windfury/Extra Hit Proc Sound"
    label(panel, "Windfury/Extra Hit Proc Sound", 18, -20, "GameFontNormalLarge")
    label(panel, tostring(#ns.activeSounds) .. " sound cues, separate proc choices and experimental extra hit support.", 18, -50, "GameFontHighlight")
    button(panel, "Open sound options", 180, 18, -82, ns.ShowOptions)
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Windfury/Extra Hit Proc Sound")
    if ok and category then pcall(Settings.RegisterAddOnCategory, category) end
end
