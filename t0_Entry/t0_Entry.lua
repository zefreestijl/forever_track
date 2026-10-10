-- 1. Create the Main Frame using Blizzard's built-in template
local f = CreateFrame("Frame", "t0_Entry", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(400, 300) -- Width and Height
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) -- Position in the middle of the screen

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

local function ToggleT0Window()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

SLASH_T0_CMD1 = "/t0"
SlashCmdList["T0_CMD"] = function()
    ToggleT0Window()
end

-- 6. Setup Ctrl + Numpad 1 keybinding via secure button
local toggleBtn = CreateFrame("Button", "T0_KeybindButton", UIParent, "SecureActionButtonTemplate")
toggleBtn:SetAttribute("type", "macro")
toggleBtn:SetAttribute("macrotext", "/t0")

toggleBtn:SetScript("OnClick", function()
    ToggleT0Window()
end)

local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    -- Bind CTRL-NUMPAD1 to click our hidden button automatically
    SetBindingClick("CTRL-NUMPAD0", "T0_KeybindButton")
    SaveBindings(GetCurrentBindingSet())
end)

--print("|cFF00FF00t1_BlankPanel loaded! Type /t0 or press Ctrl+Numpad 0 to toggle.|r")