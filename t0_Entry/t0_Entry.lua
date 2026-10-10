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
-- NEW: Create a Reload UI Button on the top left
-- ==========================================
local reloadBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
reloadBtn:SetSize(55, 22)
reloadBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
reloadBtn:SetText("Reload")

-- Elevate the button so it sits above the title bar background
reloadBtn:SetFrameLevel(f:GetFrameLevel() + 5)

-- Execute the /reload command when clicked
reloadBtn:SetScript("OnClick", function()
    ReloadUI()
end)
-- ==========================================

-- ==========================================
-- NEW: Create a Reset UI Button next to Reload
-- ==========================================
local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
resetBtn:SetSize(50, 22)
resetBtn:SetPoint("LEFT", reloadBtn, "RIGHT", 2, 0) -- Placed right next to the Reload button
resetBtn:SetText("Reset")
resetBtn:SetFrameLevel(f:GetFrameLevel() + 5)

resetBtn:SetScript("OnClick", function()
    -- 1. Reset t0_Entry itself
    f:ClearAllPoints()
    f:SetPoint("LEFT", nil, "LEFT", 5, 0)
    f:SetSize(200, 300)
    
    -- 2. Reset all sub-modules
    local mods = {"t1_TrackMap", "t2_TrackNPC", "t3_TrackQst", "t4_TrackRes", "t5_TrackDgn"}
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
-- ==========================================


-- ==========================================
-- NEW: Create a Toggle All Button next to Reset
-- ==========================================
local toggleAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
toggleAllBtn:SetSize(70, 22)
toggleAllBtn:SetPoint("LEFT", resetBtn, "RIGHT", 2, 0) -- Place right next to the Reset button
toggleAllBtn:SetText("Toggle All")
toggleAllBtn:SetFrameLevel(f:GetFrameLevel() + 5)

toggleAllBtn:SetScript("OnClick", function()
    local mods = {"t1_TrackMap", "t2_TrackNPC", "t3_TrackQst", "t4_TrackRes", "t5_TrackDgn"}
    
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
        -- Restore full size and show background elements
        f:SetHeight(300)
        if f.Bg then f.Bg:Show() end
        if f.InsetBg then f.InsetBg:Show() end
        collapseBtn:SetText("_")
        isCollapsed = false
    else
        -- Collapse down to just the header bar and hide backgrounds
        f:SetHeight(32)
        if f.Bg then f.Bg:Hide() end
        if f.InsetBg then f.InsetBg:Hide() end
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
    -- 1. Enable/Disable Checkbox
    local cb = CreateFrame("CheckButton", "t0_CB_" .. mod.id, f, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", f, "TOPLEFT", 5, yOffset)
    
    -- Main Title (ID)
    local cbText = getglobal(cb:GetName() .. 'Text')
    cbText:SetText(mod.id)
    cbText:SetFontObject("GameFontNormal")
    cbText:SetWidth(90)
    cbText:SetJustifyH("LEFT")
    cbText:SetWordWrap(false)

    -- Subtitle (Info)
    local infoText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", cbText, "BOTTOMLEFT", 0, -2)
    infoText:SetWidth(120) 
    infoText:SetJustifyH("LEFT") 
    infoText:SetWordWrap(false) 
    infoText:SetText(mod.info)

    -- Visual Helper: Grey out text if disabled
    local function UpdateTextVisuals(isEnabled)
        if isEnabled then
            cbText:SetTextColor(1, 0.82, 0) -- Default UI Gold
            infoText:SetTextColor(0.7, 0.7, 0.7) -- Default Light Grey
        else
            cbText:SetTextColor(0.4, 0.4, 0.4) -- Dark Grey
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

    
    -- Visual Helper: Update button text color based on state
    local function UpdateBtnText()
        local targetFrame = _G[mod.id]
        
        if targetFrame and targetFrame:IsShown() then
            -- |cFFFFD100 is the standard WoW UI Gold color
            toggleBtn:SetText("|cFFFFD100On|r")
        else
            -- |cFF808080 is a dark grey color
            toggleBtn:SetText("|cFF808080Off|r")
        end
    end



    -- Save enable/disable state (needs to be below UpdateBtnText so it can call it)
    cb:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        ForeverTrack_DB[mod.id] = isChecked
        UpdateTextVisuals(isChecked)
        
        -- Force close the window if disabled
        if not isChecked and _G[mod.id] then
            _G[mod.id]:Hide()
        end
        -- Refresh the button visuals in case we just forced it closed
        UpdateBtnText()
    end)

    toggleBtn:SetScript("OnShow", function(self)
        UpdateBtnText()
    end)
    
    toggleBtn:SetScript("OnClick", function(self)
        if not ForeverTrack_DB[mod.id] then
            -- print(mod.id .. " is disabled. Enable it first.")
            return
        end
        
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

--print("|cFF00FF00t1_BlankPanel loaded! Type /t0 or press Ctrl+Numpad 0 to toggle.|r")