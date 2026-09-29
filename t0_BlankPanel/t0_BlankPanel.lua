-- ==========================================
-- 0. Force Load Blizzard's Map Modules
-- ==========================================
local LoadAddOnFunc = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
LoadAddOnFunc("Blizzard_MapCanvas")
LoadAddOnFunc("Blizzard_SharedMapDataProviders")

-- ==========================================
-- 1. Create the Main Custom Window
-- ==========================================
local f = CreateFrame("Frame", "t0_BlankPanel", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(420, 320) 
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f, "TOP", 0, -6)
f.title:SetText("t0_BlankPanel - Native Blizzard Map")

-- ==========================================
-- 2. Build the Native Map Canvas
-- ==========================================
-- We create a child frame to hold the actual map canvas
f.Map = CreateFrame("Frame", nil, f)
f.Map:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -25)
f.Map:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
f.Map:SetClipsChildren(true)

-- Step A: Provide the exact Scroll Container Blizzard expects
local tocVersion = select(4, GetBuildInfo())
local scrollType = (tocVersion >= 100000) and "Frame" or "ScrollFrame"
f.Map.ScrollContainer = CreateFrame(scrollType, nil, f.Map, "MapCanvasFrameScrollContainerTemplate")
f.Map.ScrollContainer:SetAllPoints()

-- Step B: Mock the UI layout elements that the Canvas expects to exist
f.Map.BorderFrame = CreateFrame("Frame", nil, f.Map)
f.Map.BorderFrame.MaximizeMinimizeFrame = CreateFrame("Frame", nil, f.Map.BorderFrame)

-- Step C: Inject the core Blizzard Map logic
Mixin(f.Map, MapCanvasMixin)

-- Step D: THE CRITICAL FIX (Stubbing)
-- We intercept and neutralize the specific Blizzard UI functions that caused 
-- the previous nil crashes because our frame isn't the fullscreen World Map.
f.Map.UpdateGamepadCursor = function() end
f.Map.EvaluateLockReasons = function() end
f.Map.IsMaximized = function() return false end
f.Map.SetMaximized = function() end

-- Step E: Wire up the required interactive scripts
f.Map:SetScript("OnUpdate", f.Map.OnUpdate)
f.Map:SetScript("OnEvent", f.Map.OnEvent)
f.Map:SetScript("OnShow", f.Map.OnShow)
f.Map:SetScript("OnHide", f.Map.OnHide)
f.Map:SetScript("OnMouseWheel", f.Map.OnMouseWheel)

-- Step F: Safely trigger the internal Blizzard setup
f.Map:OnLoad()


-- ==========================================
-- 3. Add Native Features (Fog of War & Text)
-- ==========================================
if MapExplorationDataProviderMixin then
    f.Map:AddDataProvider(CreateFromMixins(MapExplorationDataProviderMixin))
end
if MapLabelsDataProviderMixin then
    f.Map:AddDataProvider(CreateFromMixins(MapLabelsDataProviderMixin))
end

-- Note: GroupMembersDataProviderMixin has been removed to prevent 
-- UnitPositionFrame initialization crashes on custom map canvases.

-- Render the Zone natively!
f.Map:SetMapID(1429)


-- ==========================================
-- 4. Collapse Button & Close Handlers
-- ==========================================
local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
collapseBtn:SetText("_")
local isCollapsed = false

collapseBtn:SetScript("OnClick", function()
    if isCollapsed then
        f:SetHeight(320)
        if f.Bg then f.Bg:Show() end
        if f.InsetBg then f.InsetBg:Show() end
        f.Map:Show()
        collapseBtn:SetText("_")
        isCollapsed = false
    else
        f:SetHeight(32)
        if f.Bg then f.Bg:Hide() end
        if f.InsetBg then f.InsetBg:Hide() end
        f.Map:Hide()
        collapseBtn:SetText("+")
        isCollapsed = true
    end
end)

tinsert(UISpecialFrames, f:GetName())
f:Hide()

-- ==========================================
-- 5. Slash Commands & Keybindings
-- ==========================================
SLASH_T0_CMD1 = "/t0"
SlashCmdList["T0_CMD"] = function()
    if f:IsShown() then f:Hide() else f:Show() end
end

local toggleBtn = CreateFrame("Button", "T0_KeybindButton", UIParent, "SecureActionButtonTemplate")
toggleBtn:SetAttribute("type", "macro")
toggleBtn:SetAttribute("macrotext", "/t0")
toggleBtn:SetScript("OnClick", function() if f:IsShown() then f:Hide() else f:Show() end end)

local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    SetBindingClick("CTRL-NUMPAD0", "T0_KeybindButton")
    SaveBindings(GetCurrentBindingSet())
end)

print("|cFF00FF00t0_BlankPanel Native Map loaded! Type /t0 to test.|r")