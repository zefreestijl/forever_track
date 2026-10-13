-- Initialize the global registry if it doesn't exist yet
_G.ForeverTrack = _G.ForeverTrack or { Modules = {} }

-- 1. Create the Main Frame attached to the root window (nil)
local f = CreateFrame("Frame", "t0_Entry", nil, "BasicFrameTemplateWithInset")

-- Save the frame to the global module registry for Input.lua to access
_G.ForeverTrack.Modules.T0 = f

-- FIX: Prevent FLT_OVERFLOW crash by ensuring scale is never 0 during load
local uiScale = UIParent:GetEffectiveScale()
if not uiScale or uiScale <= 0.1 then
    uiScale = 1 -- Fallback to standard 100% scale if the game hasn't loaded UIParent yet
end
f:SetScale(uiScale)


--
f:SetSize(200, 300)
f:SetPoint("LEFT", nil, "LEFT", 50, 0)



-- Enable moving/dragging around the screen
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

-- 2. Add a Title Text
f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f, "TOP", 0, -6)
f.title:SetText("t0_Entry")


-- ==========================================
-- UPDATED: Bottom Utility Buttons
-- ==========================================
-- 1. Reload Button (Shrunk to 42px)
local reloadBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
reloadBtn:SetSize(60, 22)
reloadBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
reloadBtn:SetText("Reload")
reloadBtn:SetFrameLevel(f:GetFrameLevel() + 5)
reloadBtn:SetScript("OnClick", function() ReloadUI() end)

-- 2. Reset Button (Shrunk to 42px)
local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
resetBtn:SetSize(55, 22)
resetBtn:SetPoint("LEFT", reloadBtn, "RIGHT", 2, 0)
resetBtn:SetText("Reset")
resetBtn:SetFrameLevel(f:GetFrameLevel() + 5)
resetBtn:SetScript("OnClick", function()
    -- 1. Reset t0_Entry itself
    f:ClearAllPoints()
    f:SetPoint("LEFT", nil, "LEFT", 5, 0)
    f:SetSize(200, 300)

    -- 2. Reset all sub-modules
    local mods = { "t1_TrackMap", "t2_TrackNPC", "t3_TrackQst", "t4_TrackRes", "t5_TrackDgn" }
    for _, modID in ipairs(mods) do
        local targetFrame = _G[modID]
        if targetFrame then
            -- If the module has defined a reset rule, trigger it
            if targetFrame.ResetLayout then
                targetFrame:ResetLayout()
            else
                -- Generic fallback if you haven't added the rule to a module yet
                targetFrame:ClearAllPoints()
                targetFrame:SetPoint("CENTER", nil, "CENTER", 0, 0)
            end
        end
    end
    -- print("|cFFFFD100Forever Track:|r All UI positions and sizes reset.")
end)


-- 3. Toggle All Button (Shrunk to 45px, Text shortened)
local toggleAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
toggleAllBtn:SetSize(35, 22)
toggleAllBtn:SetPoint("LEFT", resetBtn, "RIGHT", 2, 0)
toggleAllBtn:SetText("All")
toggleAllBtn:SetFrameLevel(f:GetFrameLevel() + 5)
toggleAllBtn:SetScript("OnClick", function()
    local mods = { "t1_TrackMap", "t2_TrackNPC", "t3_TrackQst", "t4_TrackRes", "t5_TrackDgn" }

    -- Step 1: Check if any enabled windows are currently hidden
    local anyHidden = false
    for _, modID in ipairs(mods) do
        if ForeverTrack_DB[modID] then
            local targetFrame = _G[modID]
            if targetFrame and not targetFrame:IsShown() then
                anyHidden = true
                break
            end
        end
    end

    -- Step 2: Apply the new state to all enabled windows
    for _, modID in ipairs(mods) do
        if ForeverTrack_DB[modID] then
            local targetFrame = _G[modID]
            if targetFrame then
                if anyHidden then
                    targetFrame:Show()
                else
                    targetFrame:Hide()
                end
            end

            -- Step 3: Update the individual On/Off button text visuals in the t0 list
            local btn = _G["t0_Btn_" .. modID]
            if btn then
                if anyHidden then
                    btn:SetText("|cFFFFD100On|r")
                else
                    btn:SetText("|cFF808080Off|r")
                end
            end
        end
    end
end)


-- 4. NEW: Debug Toggle Button
local debugBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
debugBtn:SetSize(20, 22)
debugBtn:SetPoint("LEFT", toggleAllBtn, "RIGHT", 7, 0)
debugBtn:SetText("->")
debugBtn:SetFrameLevel(f:GetFrameLevel() + 5)

debugBtn:SetScript("OnClick", function(self)
    local testPanel = _G["GamepadLayout"]

    if testPanel then
        -- Set up a one-time hook to ensure the text always matches the window state
        if not testPanel.debugBtnHooked then
            testPanel:HookScript("OnShow", function() self:SetText("<-") end)
            testPanel:HookScript("OnHide", function() self:SetText("->") end)
            testPanel.debugBtnHooked = true
        end

        if testPanel:IsShown() then
            testPanel:Hide()
        else
            -- Snap the layout test window to the right edge of t0_Entry
            testPanel:ClearAllPoints()
            testPanel:SetPoint("TOPLEFT", f, "TOPRIGHT", 5, 0)
            testPanel:Show()
        end
    end
end)

-- ==========================================




-- 3. Create a Custom Collapse (Minimize) Button next to the close button
local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
collapseBtn:SetText("_")


-- Elevate both the default X button and the custom minimize button
f.CloseButton:SetFrameLevel(f:GetFrameLevel() + 5)
collapseBtn:SetFrameLevel(f:GetFrameLevel() + 5)

-- ==========================================
-- NEW: Override Close Button to behave like Ctrl+Numpad0
-- ==========================================
f.CloseButton:SetScript("OnClick", function()
    -- Ensure the function from Input.lua is loaded
    if _G.func_ToggleT0Window then
        _G.func_ToggleT0Window()
    else
        f:Hide() -- Safety fallback
    end
end)
-- ==========================================



-- Track collapsed state
local isCollapsed = false

collapseBtn:SetScript("OnClick", function()
    if isCollapsed then
        local mods = { "t1_TrackMap", "t2_TrackNPC", "t3_TrackQst", "t4_TrackRes", "t5_TrackDgn" }
        for _, modID in ipairs(mods) do
            if _G["t0_CB_" .. modID] then _G["t0_CB_" .. modID]:Show() end
            if _G["t0_Btn_" .. modID] then _G["t0_Btn_" .. modID]:Show() end
            if _G["t0_Info_" .. modID] then _G["t0_Info_" .. modID]:Show() end
        end

        -- Restore full size and show background elements
        f:SetHeight(300)
        if f.Bg then f.Bg:Show() end
        if f.InsetBg then f.InsetBg:Show() end

        -- Show the bottom utility buttons
        reloadBtn:Show()
        resetBtn:Show()
        toggleAllBtn:Show()
        debugBtn:Show() -- Add this line

        -- Show all generated module checkboxes and buttons
        local mods = { "t1_TrackMap", "t2_TrackNPC", "t3_TrackQst", "t4_TrackRes", "t5_TrackDgn" }
        for _, modID in ipairs(mods) do
            if _G["t0_CB_" .. modID] then _G["t0_CB_" .. modID]:Show() end
            if _G["t0_Btn_" .. modID] then _G["t0_Btn_" .. modID]:Show() end
        end

        collapseBtn:SetText("_")
        isCollapsed = false
    else
        local mods = { "t1_TrackMap", "t2_TrackNPC", "t3_TrackQst", "t4_TrackRes", "t5_TrackDgn" }
        for _, modID in ipairs(mods) do
            if _G["t0_CB_" .. modID] then _G["t0_CB_" .. modID]:Hide() end
            if _G["t0_Btn_" .. modID] then _G["t0_Btn_" .. modID]:Hide() end
            if _G["t0_Info_" .. modID] then _G["t0_Info_" .. modID]:Hide() end
        end

        -- Collapse down to just the header bar and hide backgrounds
        f:SetHeight(32)
        if f.Bg then f.Bg:Hide() end
        if f.InsetBg then f.InsetBg:Hide() end

        -- Hide the bottom utility buttons
        reloadBtn:Hide()
        resetBtn:Hide()
        toggleAllBtn:Hide()
        debugBtn:Hide() -- Add this line

        -- Hide all generated module checkboxes and buttons
        local mods = { "t1_TrackMap", "t2_TrackNPC", "t3_TrackQst", "t4_TrackRes", "t5_TrackDgn" }
        for _, modID in ipairs(mods) do
            if _G["t0_CB_" .. modID] then _G["t0_CB_" .. modID]:Hide() end
            if _G["t0_Btn_" .. modID] then _G["t0_Btn_" .. modID]:Hide() end
        end

        collapseBtn:SetText("+")
        isCollapsed = true
    end
end)


-- 4. Make the window close when pressing the ESC key
tinsert(UISpecialFrames, f:GetName())

-- 5. Hide it by default on load, provide the /t0 slash command
f:Hide()



-- Initialize the SavedVariables database
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "forever_track" then
        ForeverTrack_DB = ForeverTrack_DB or {
            t1_TrackMap = true,
            t2_TrackNPC = true,
            t3_TrackQst = true,
            t4_TrackRes = true,
            t5_TrackDgn = true
        }
    end
end)

-- 7. Generate Checkboxes and Window Toggles
local modules = {
    { id = "t1_TrackMap", info = "Track World Map" },
    { id = "t2_TrackNPC", info = "Track NPC in Zone" },
    { id = "t3_TrackQst", info = "Track Accepted Quest" },
    { id = "t4_TrackRes", info = "Track Resources" },
    { id = "t5_TrackDgn", info = "Track Dungeon Map" }
}


local yOffset = -30
for i, mod in ipairs(modules) do
    -- Add background highlight for gamepad focus
    local rowBg = f:CreateTexture(nil, "BACKGROUND")
    rowBg:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    rowBg:Hide()
    mod.bg = rowBg

    -- 1. Enable/Disable Checkbox
    local cb = CreateFrame("CheckButton", "t0_CB_" .. mod.id, f, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", f, "TOPLEFT", 5, yOffset)
    mod.cb = cb -- Store reference for the gamepad

    -- Main Title (ID)
    local cbText = getglobal(cb:GetName() .. 'Text')
    cbText:SetText(mod.id)
    cbText:SetFontObject("GameFontNormal")
    cbText:SetWidth(90)
    cbText:SetJustifyH("LEFT")
    cbText:SetWordWrap(false)

    -- Subtitle (Info)
    local infoText = f:CreateFontString("t0_Info_" .. mod.id, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", cbText, "BOTTOMLEFT", 0, -2)
    infoText:SetWidth(120)
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(false)
    infoText:SetText(mod.info)

    -- Visual Helper: Grey out text if disabled
    local function UpdateTextVisuals(isEnabled)
        if isEnabled then
            cbText:SetTextColor(1, 0.82, 0)      -- Default UI Gold
            infoText:SetTextColor(0.7, 0.7, 0.7) -- Default Light Grey
        else
            cbText:SetTextColor(0.4, 0.4, 0.4)   -- Dark Grey
            infoText:SetTextColor(0.3, 0.3, 0.3) -- Darker Grey
        end
    end

    -- Load saved enable/disable state
    cb:SetScript("OnShow", function(self)
        local isEnabled = ForeverTrack_DB[mod.id]
        self:SetChecked(isEnabled)
        UpdateTextVisuals(isEnabled)
    end)

    -- 2. Open/Close Window Button
    local toggleBtn = CreateFrame("Button", "t0_Btn_" .. mod.id, f, "UIPanelButtonTemplate")
    toggleBtn:SetSize(45, 22)
    toggleBtn:SetPoint("LEFT", cb, "RIGHT", 115, 0)
    toggleBtn:SetFrameLevel(cb:GetFrameLevel() + 2)
    mod.toggleBtn = toggleBtn -- Store reference for the gamepad

    -- Anchor the highlight background to cover the whole row securely
    rowBg:SetPoint("TOPLEFT", cb, "TOPLEFT", -2, 2)
    rowBg:SetPoint("BOTTOMRIGHT", toggleBtn, "BOTTOMRIGHT", 2, -2)


    -- Visual Helper: Update button text color based on state
    local function UpdateBtnText()
        local targetFrame = _G[mod.id]

        if targetFrame and targetFrame:IsShown() then
            toggleBtn:SetText("|cFFFFD100On|r")
        else
            toggleBtn:SetText("|cFF808080Off|r")
        end
    end

    -- Save enable/disable state
    cb:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        ForeverTrack_DB[mod.id] = isChecked
        UpdateTextVisuals(isChecked)

        -- Force close the window if disabled
        if not isChecked and _G[mod.id] then
            _G[mod.id]:Hide()
        end
        UpdateBtnText()
    end)

    toggleBtn:SetScript("OnShow", function(self) UpdateBtnText() end)

    toggleBtn:SetScript("OnClick", function(self)
        if not ForeverTrack_DB[mod.id] then return end

        local targetFrame = _G[mod.id]
        if targetFrame then
            if targetFrame:IsShown() then
                targetFrame:Hide()
            else
                targetFrame:Show()
            end
            UpdateBtnText()
        end
    end)

    yOffset = yOffset - 30
end

-- ==========================================
-- Custom Window Focus Visuals & Gamepad Blocker
-- ==========================================
f.moduleRows = modules
f.focusBorder = CreateFrame("Frame", nil, f, "BackdropTemplate")
f.focusBorder:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
f.focusBorder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
f.focusBorder:SetFrameLevel(f:GetFrameLevel() + 20)
f.focusBorder:EnableMouse(false)

f.focusBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 3 })
f.focusBorder.glowAnim = f.focusBorder:CreateAnimationGroup()
f.focusBorder.glowAnim:SetLooping("BOUNCE")

local alphaPulse = f.focusBorder.glowAnim:CreateAnimation("Alpha")
alphaPulse:SetFromAlpha(0.3)
alphaPulse:SetToAlpha(1.0)
alphaPulse:SetDuration(1.0)
alphaPulse:SetSmoothing("IN_OUT")

f.focusBorder:Hide()
f.focusBorder:SetBackdropBorderColor(0, 0, 0, 0)

f.padBlocker = CreateFrame("Button", "T0_PadBlocker", UIParent)
f.padBlocker:SetScript("OnClick", function() end)

local padKeysToBlock = {
    "PAD1", "PAD2", "PAD3", "PAD4",
    "PADFORWARD",
    "PADLSHOULDER", "PADRSHOULDER",
    "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
    "PADLSTICK", "PADRSTICK"
}

f.bottomButtons = { reloadBtn, resetBtn, toggleAllBtn, debugBtn }
f.selectedIndex = 1
f.bottomSelectedIndex = 1
f.isBottomRowFocused = false

-- Restore the missing MoveSelection function
function f:MoveSelection(delta)
    f.isBottomRowFocused = false -- Moving D-Pad snaps focus back to the vertical list
    f.selectedIndex = math.max(1, math.min(#f.moduleRows, (f.selectedIndex or 1) + delta))
    if f.UpdateSelectionVisuals then f:UpdateSelectionVisuals() end
end

f.UpdateSelectionVisuals = function(self)
    -- 1. Update the vertical addon list
    for i, row in ipairs(self.moduleRows) do
        if not self.isBottomRowFocused and i == self.selectedIndex then
            if row.bg then
                row.bg:SetDrawLayer("ARTWORK")
                row.bg:SetColorTexture(0.5, 0.5, 0.5, 0.5)
                row.bg:Show()
            end
        else
            if row.bg then row.bg:Hide() end
        end
    end

    -- 2. Update the bottom utility buttons
    for i, btn in ipairs(self.bottomButtons) do
        if self.isBottomRowFocused and i == self.bottomSelectedIndex then
            btn:LockHighlight()                            -- Native WoW glow effect
            local text = btn:GetFontString()
            if text then text:SetTextColor(1, 0.82, 0) end -- Gold text
        else
            btn:UnlockHighlight()
            local text = btn:GetFontString()
            if text then text:SetTextColor(1, 1, 1) end -- White text
        end
    end
end


-- Hidden Actions for the D-Pad
f.padUpBtn = CreateFrame("Button", "T0_ListUp", f)
f.padUpBtn:SetScript("OnClick", function() f:MoveSelection(-1) end)

f.padDownBtn = CreateFrame("Button", "T0_ListDown", f)
f.padDownBtn:SetScript("OnClick", function() f:MoveSelection(1) end)

-- Hidden Actions for D-Pad Left / Right Bottom Tabs
f.padLeftBtn = CreateFrame("Button", "T0_TabLeft", f)
f.padLeftBtn:SetScript("OnClick", function()
    f.isBottomRowFocused = true
    f.bottomSelectedIndex = (f.bottomSelectedIndex or 1) - 1
    if f.bottomSelectedIndex < 1 then f.bottomSelectedIndex = #f.bottomButtons end
    f:UpdateSelectionVisuals()
end)

f.padRightBtn = CreateFrame("Button", "T0_TabRight", f)
f.padRightBtn:SetScript("OnClick", function()
    f.isBottomRowFocused = true
    f.bottomSelectedIndex = (f.bottomSelectedIndex or 1) + 1
    if f.bottomSelectedIndex > #f.bottomButtons then f.bottomSelectedIndex = 1 end
    f:UpdateSelectionVisuals()
end)


-- Hidden Action for A (Select / Confirm)
f.padSelectBtn = CreateFrame("Button", "T0_PadSelect", f)
f.padSelectBtn:SetScript("OnClick", function()
    if f.isBottomRowFocused then
        -- Click the focused bottom button
        local btn = f.bottomButtons[f.bottomSelectedIndex]
        if btn then
            local onClick = btn:GetScript("OnClick")
            if onClick then onClick(btn) end
        end
    else
        -- Click the focused addon row's toggle button
        local row = f.moduleRows[f.selectedIndex]
        if row and row.toggleBtn then
            local onClick = row.toggleBtn:GetScript("OnClick")
            if onClick then onClick(row.toggleBtn) end
        end
    end
end)

-- ==========================================
-- ADD THIS MISSING BLOCK BACK:
-- Hidden Action for X (PAD3) - Toggle Checkbox
f.padXBtn = CreateFrame("Button", "T0_PadX", f)
f.padXBtn:SetScript("OnClick", function()
    -- Only toggle if we are focused on the vertical addon list
    if not f.isBottomRowFocused then
        local row = f.moduleRows[f.selectedIndex]
        if row and row.cb then
            -- Flip the visual checkmark state
            row.cb:SetChecked(not row.cb:GetChecked())

            -- Execute the save/update script
            local onClick = row.cb:GetScript("OnClick")
            if onClick then onClick(row.cb) end
        end
    end
end)
-- ==========================================

f.isFocused = false


function f:SetFocus(focused)
    f.isFocused = focused
    if focused then
        f.focusBorder:Show()
        f.focusBorder:SetBackdropBorderColor(1, 0.82, 0, 1)
        f.focusBorder.glowAnim:Play()
        if f.title then f.title:SetTextColor(1, 0.82, 0) end

        if not InCombatLockdown() then
            if SetGamePadCursorControl then SetGamePadCursorControl(false) end


            for _, key in ipairs(padKeysToBlock) do
                if key == "PADDUP" then
                    SetOverrideBindingClick(f.padBlocker, true, key, "T0_ListUp")
                elseif key == "PADDDOWN" then
                    SetOverrideBindingClick(f.padBlocker, true, key, "T0_ListDown")
                elseif key == "PADDLEFT" then  -- D-Pad Left Button
                    SetOverrideBindingClick(f.padBlocker, true, key, "T0_TabLeft")
                elseif key == "PADDRIGHT" then -- D-Pad Right Button
                    SetOverrideBindingClick(f.padBlocker, true, key, "T0_TabRight")
                elseif key == "PAD1" then      -- A Button (Confirm)
                    SetOverrideBindingClick(f.padBlocker, true, key, "T0_PadSelect")
                elseif key == "PAD3" then      -- X Button (Enable/Disable Checkbox)
                    SetOverrideBindingClick(f.padBlocker, true, key, "T0_PadX")
                else
                    -- L1 (PADLSHOULDER) and R1 (PADRSHOULDER) will now fall through to here and be safely blocked
                    SetOverrideBindingClick(f.padBlocker, true, key, f.padBlocker:GetName())
                end
                SetOverrideBindingClick(f.padBlocker, true, "PADLTRIGGER-" .. key, f.padBlocker:GetName())
            end
        end

        f.selectedIndex = 1
        f:UpdateSelectionVisuals()
    else
        f.focusBorder:Hide()
        f.focusBorder.glowAnim:Stop()
        if f.title then f.title:SetTextColor(1, 1, 1) end

        if not InCombatLockdown() then
            ClearOverrideBindings(f.padBlocker)
        end

        for _, row in ipairs(f.moduleRows) do
            if row.bg then row.bg:Hide() end
        end

        f.isBottomRowFocused = false
        if f.UpdateSelectionVisuals then f:UpdateSelectionVisuals() end
    end
end

f:HookScript("OnShow", function()
    -- Left empty so Input.lua can successfully auto-focus the window
end)

f:HookScript("OnMouseDown", function() f:SetFocus(true) end)

f:HookScript("OnHide", function()
    f:SetFocus(false)
    -- Fail-safe: Always restore the native HUD if this window is closed via ESC or other means
    if not UIParent:IsShown() then
        UIParent:Show()
    end
end)

local focusWatcher = CreateFrame("Frame")
focusWatcher:RegisterEvent("GLOBAL_MOUSE_DOWN")
focusWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
focusWatcher:SetScript("OnEvent", function(self, event)
    if event == "GLOBAL_MOUSE_DOWN" then
        if f:IsShown() and not f:IsMouseOver() then
            f:SetFocus(false)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if f.isFocused then f:SetFocus(false) end
    end
end)
