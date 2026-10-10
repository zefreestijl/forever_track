-- Initialize the global registry if it doesn't exist yet
_G.ForeverTrack = _G.ForeverTrack or { Modules = {} }


-- 1. Create the Main Frame using Blizzard's built-in template
local f = CreateFrame("Frame", "t0_Entry", nil, "BasicFrameTemplateWithInset")
_G.ForeverTrack.Modules.T0 = f

f:SetScale(UIParent:GetEffectiveScale()) -- Sync scale with the user's UI settings
f:SetSize(200, 300) -- Width and Height
f:SetPoint("LEFT", nil, "LEFT", 50, 0) -- Position in the middle of the screen


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




-- 3. Create a Custom Collapse (Minimize) Button next to the close button
local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
collapseBtn:SetText("_")

-- Elevate both the default X button and the custom minimize button
f.CloseButton:SetFrameLevel(f:GetFrameLevel() + 5)
collapseBtn:SetFrameLevel(f:GetFrameLevel() + 5)


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
    infoText:SetWidth(100) 
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