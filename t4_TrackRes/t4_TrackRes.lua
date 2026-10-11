-- ==========================================================
-- t4_TrackRes.lua: Gamepad Visualizer & Debug Panel
-- ==========================================================
local f = CreateFrame("Frame", "t4_TrackRes", UIParent, "BasicFrameTemplateWithInset")

local uiScale = UIParent:GetEffectiveScale()
if not uiScale or uiScale <= 0.1 then 
    uiScale = 1
end
f:SetScale(uiScale)
f:SetSize(420, 260)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

-- Register into ForeverTrack registry
_G.ForeverTrack = _G.ForeverTrack or { Modules = {} }
_G.ForeverTrack.Modules.T4 = f

f.ResetLayout = function(self)
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self:SetSize(420, 260)
end

f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

-- Title
f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f, "TOP", 0, -6)
f.title:SetText("Gamepad Controller HUD (T4)")

-- Helper: Create visual gamepad buttons
f.Buttons = {}

local function CreatePadButton(keyID, parent, label, x, y, w, h, isCircle)
    local btn = CreateFrame("Frame", nil, parent)
    btn:SetSize(w or 32, h or 32)
    btn:SetPoint("CENTER", parent, "CENTER", x, y)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.18, 0.18, 0.22, 0.9)

    btn.border = btn:CreateLine(nil, "BORDER") -- simple edge highlight
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.text:SetText(label)
    btn.text:SetTextColor(0.8, 0.8, 0.8)

    btn.SetPressed = function(self, pressed)
        if pressed then
            self.bg:SetColorTexture(0.1, 0.85, 0.25, 0.95) -- Bright active green
            self.text:SetTextColor(0, 0, 0)
        else
            self.bg:SetColorTexture(0.18, 0.18, 0.22, 0.9)  -- Inactive gray
            self.text:SetTextColor(0.8, 0.8, 0.8)
        end
    end

    f.Buttons[keyID] = btn
    return btn
end

-- Layout: Left side (D-Pad) -> DOUBLE-D API NAMES
local dpadAnchor = CreateFrame("Frame", nil, f)
dpadAnchor:SetSize(90, 90)
dpadAnchor:SetPoint("LEFT", f, "LEFT", 30, -15)

CreatePadButton("PADDUP",    dpadAnchor, "▲",  0,  28, 26, 26)
CreatePadButton("PADDDOWN",  dpadAnchor, "▼",  0, -28, 26, 26)
CreatePadButton("PADDLEFT",  dpadAnchor, "◄", -28,  0, 26, 26)
CreatePadButton("PADDRIGHT", dpadAnchor, "►",  28,  0, 26, 26)


-- Layout: Right side (XYAB / Face Buttons)
local faceAnchor = CreateFrame("Frame", nil, f)
faceAnchor:SetSize(90, 90)
faceAnchor:SetPoint("RIGHT", f, "RIGHT", -30, -15)

CreatePadButton("PAD4", faceAnchor, "Y",  0,  28, 26, 26) -- Top
CreatePadButton("PAD1", faceAnchor, "A",  0, -28, 26, 26) -- Bottom
CreatePadButton("PAD3", faceAnchor, "X", -28,  0, 26, 26) -- Left
CreatePadButton("PAD2", faceAnchor, "B",  28,  0, 26, 26) -- Right

-- Layout: Center (Back/Select, Start/Forward) & Shoulder Badges
CreatePadButton("PADBACK",    f, "BACK",  -40, 5,  46, 20)
CreatePadButton("PADFORWARD", f, "START",  40, 5,  46, 20)


CreatePadButton("PADLSHOULDER", f, "LB", -120, 65, 42, 20)
CreatePadButton("PADRSHOULDER", f, "RB",  120, 65, 42, 20)
CreatePadButton("PADLTRIGGER",  f, "LT", -120, 90, 42, 20)
CreatePadButton("PADRTRIGGER",  f, "RT",  120, 90, 42, 20)

-- 3. UPDATE SetButtonState to route L3 and R3 directly to the stick graphics:
f.SetButtonState = function(self, keyName, isPressed)
    if keyName == "PADLSTICK" then
        self.LStick:SetPressed(isPressed)
    elseif keyName == "PADRSTICK" then
        self.RStick:SetPressed(isPressed)
    elseif self.Buttons[keyName] then
        self.Buttons[keyName]:SetPressed(isPressed)
    end
end


-- ==========================================
-- New: Joystick Trackers
-- ==========================================
-- 2. UPDATE your CreateStickBadge function:
local function CreateStickBadge(parent, label, x, y)
    local stick = CreateFrame("Frame", nil, parent)
    stick:SetSize(46, 46) 
    stick:SetPoint("CENTER", parent, "CENTER", x, y)
    
    stick.bg = stick:CreateTexture(nil, "BACKGROUND")
    stick.bg:SetSize(40, 40)
    stick.bg:SetPoint("CENTER")
    stick.bg:SetColorTexture(0.15, 0.15, 0.18, 0.8)
    
    stick.thumb = stick:CreateTexture(nil, "ARTWORK")
    stick.thumb:SetSize(16, 16)
    stick.thumb:SetPoint("CENTER", stick, "CENTER", 0, 0)
    stick.thumb:SetColorTexture(0.8, 0.2, 0.2, 0.9) 
    
    stick.text = stick:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stick.text:SetPoint("TOP", stick, "BOTTOM", 0, -2)
    stick.text:SetText(label)
    
    -- NEW: Handle pressed state to turn the background green
    stick.SetPressed = function(self, pressed)
        if pressed then
            self.bg:SetColorTexture(0.1, 0.85, 0.25, 0.95)
            self.text:SetTextColor(0, 0, 0)
        else
            self.bg:SetColorTexture(0.15, 0.15, 0.18, 0.8)
            self.text:SetTextColor(1, 0.82, 0)
        end
    end

    return stick
end

f.LStick = CreateStickBadge(f, "L-Stick", -70, -20)
f.RStick = CreateStickBadge(f, "R-Stick", 70, -20)



-- API method for Input.lua to update stick positions
f.UpdateSticks = function(self, lx, ly, rx, ry)
    -- WoW joystick raw values are floats between -1 and 1
    -- Multiply by ~14 to constrain the thumb square inside the 40px background well
    self.LStick.thumb:SetPoint("CENTER", self.LStick, "CENTER", lx * 14, ly * 14)
    self.RStick.thumb:SetPoint("CENTER", self.RStick, "CENTER", rx * 14, ry * 14)
end



-- Collapse Button
local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
collapseBtn:SetText("_")
local isCollapsed = false

collapseBtn:SetScript("OnClick", function()
    if isCollapsed then
        f:SetHeight(260)
        collapseBtn:SetText("_")
        isCollapsed = false
    else
        f:SetHeight(32)
        collapseBtn:SetText("+")
        isCollapsed = true
    end
end)

tinsert(UISpecialFrames, f:GetName())
f:Hide()

