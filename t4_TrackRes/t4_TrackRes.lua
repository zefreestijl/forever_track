-- 1. Create the Main Frame using Blizzard's built-in template
local f = CreateFrame("Frame", "t4_TrackRes", nil, "BasicFrameTemplateWithInset")


if _G.ForeverTrack then
    _G.ForeverTrack.Modules.T4 = f
end


local uiScale = UIParent:GetEffectiveScale()
if not uiScale or uiScale <= 0.1 then 
    uiScale = 1 -- Fallback to standard 100% scale if the game hasn't loaded UIParent yet
end
f:SetScale(uiScale)


f:SetSize(400, 300) -- Width and Height
f:SetPoint("TOPRIGHT", nil, "TOPRIGHT", -260, -5) -- Position in the middle of the screen



f.ResetLayout = function(self)
    self:ClearAllPoints()
    self:SetPoint("TOPRIGHT", nil, "TOPRIGHT", -260, -5) -- T1's specific default position
    self:SetSize(400, 300)                           -- T1's specific default size
end




-- Enable moving/dragging around the screen
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

-- 2. Add a Title Text
f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f, "TOP", 0, -6)
f.title:SetText("t4_TrackRes")

-- 3. Create a Custom Collapse (Minimize) Button next to the close button
local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
collapseBtn:SetText("_")

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

-- 5. Hide it by default on load, provide the /t4 slash command
f:Hide()



-- ==========================================
-- Custom Window Focus Visuals
-- ==========================================
f.focusBorder = CreateFrame("Frame", nil, f, "BackdropTemplate")
f.focusBorder:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
f.focusBorder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
f.focusBorder:SetFrameLevel(f:GetFrameLevel() + 20)
f.focusBorder:EnableMouse(false)

f.focusBorder:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 3,
})

f.focusBorder.glowAnim = f.focusBorder:CreateAnimationGroup()
f.focusBorder.glowAnim:SetLooping("BOUNCE")

local alphaPulse = f.focusBorder.glowAnim:CreateAnimation("Alpha")
alphaPulse:SetFromAlpha(0.3)
alphaPulse:SetToAlpha(1.0)
alphaPulse:SetDuration(1.0)
alphaPulse:SetSmoothing("IN_OUT")

f.focusBorder:Hide()
f.focusBorder:SetBackdropBorderColor(0, 0, 0, 0)

f.isFocused = false
function f:SetFocus(focused)
    f.isFocused = focused
    if focused then
        f.focusBorder:Show() 
        f.focusBorder:SetBackdropBorderColor(1, 0.82, 0, 1) 
        f.focusBorder.glowAnim:Play() 
        if f.title then f.title:SetTextColor(1, 0.82, 0) end
    else
        f.focusBorder:Hide() 
        f.focusBorder.glowAnim:Stop() 
        if f.title then f.title:SetTextColor(1, 1, 1) end
    end
end

-- Clear focus if clicking the background of the window
f:HookScript("OnMouseDown", function() 
    if not f.isFocused and f.SetFocus then f:SetFocus(true) end 
end)