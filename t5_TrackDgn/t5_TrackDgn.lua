-- 1. Create the Main Frame
local f = CreateFrame("Frame", "t5_TrackDgn", nil,"BasicFrameTemplateWithInset")



local uiScale = UIParent:GetEffectiveScale()
if not uiScale or uiScale <= 0.1 then 
    uiScale = 1 -- Fallback to standard 100% scale if the game hasn't loaded UIParent yet
end
f:SetScale(uiScale)


f:SetSize(250, 250) 
f:SetPoint("TOPRIGHT", nil,"TOPRIGHT", -5, -33)


f.ResetLayout = function(self)
    self:ClearAllPoints()
    self:SetPoint("TOPRIGHT", nil, "TOPRIGHT", -5, -33) -- T1's specific default position
    self:SetSize(250, 250)                           -- T1's specific default size
end




--
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

-- Enable Resizing and set limits for a square
f:SetResizable(true)
if f.SetResizeBounds then
    f:SetResizeBounds(250, 250, 800, 800)
else
    f:SetMinResize(250, 250)
    f:SetMaxResize(800, 800)
end

-- 2. Add a Title Text
f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f, "TOP", 0, -6)
f.title:SetText("t5_TrackDgn")

-- 3. Create Custom Buttons (Collapse and Resize)
local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
collapseBtn:SetText("_")

local isCollapsed = false
collapseBtn:SetScript("OnClick", function()
    if isCollapsed then
        f:SetHeight(f:GetWidth()) 
        if f.Bg then f.Bg:Show() end
        if f.InsetBg then f.InsetBg:Show() end
        Minimap:Show()
        collapseBtn:SetText("_")
        isCollapsed = false
    else
        f:SetHeight(32)
        if f.Bg then f.Bg:Hide() end
        if f.InsetBg then f.InsetBg:Hide() end
        Minimap:Hide()
        collapseBtn:SetText("+")
        isCollapsed = true
        if f.coordText then f.coordText:SetText("") end
        if f.convertedText then f.convertedText:SetText("") end
        if f.playerText then f.playerText:SetText("") end
    end
end)

-- Resize Grip (Bottom Left)
local resizeBtn = CreateFrame("Button", nil, f)
resizeBtn:SetPoint("BOTTOMLEFT", 4, 4)
resizeBtn:SetSize(16, 16)
resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeBtn:GetNormalTexture():SetTexCoord(1, 0, 0, 1)
resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeBtn:GetHighlightTexture():SetTexCoord(1, 0, 0, 1)
resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeBtn:GetPushedTexture():SetTexCoord(1, 0, 0, 1)

resizeBtn:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and not isCollapsed then
        f:StartSizing("BOTTOMLEFT")
    end
end)
resizeBtn:SetScript("OnMouseUp", function(self, button)
    f:StopMovingOrSizing()
end)

tinsert(UISpecialFrames, f:GetName())
f:Hide()

-- 4. Create a Transparent Overlay for Tooltips, Scroll Zooming, and Custom Coordinates
local hoverOverlay = CreateFrame("Frame", nil, f)
hoverOverlay:SetFrameLevel(f:GetFrameLevel() + 10)
hoverOverlay:EnableMouse(true)
hoverOverlay:EnableMouseWheel(true)
hoverOverlay:Hide()

-- NEW TEXT: White Player Coordinates (Most Bottom)
f.playerText = hoverOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.playerText:SetPoint("BOTTOM", f, "BOTTOM", 0, 6)
f.playerText:SetTextColor(1, 1, 1, 1) 
f.playerText:SetText("")

-- BASE TEXT: Grey Raw Grid Coordinates (Middle)
f.coordText = hoverOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.coordText:SetPoint("BOTTOM", f.playerText, "TOP", 0, 2)
f.coordText:SetTextColor(0.6, 0.6, 0.6, 1) 
f.coordText:SetText("")

-- CONVERTED TEXT: Pure Yellow Converted Coordinates (Top)
f.convertedText = hoverOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.convertedText:SetPoint("BOTTOM", f.coordText, "TOP", 0, 2)
f.convertedText:SetTextColor(1, 1, 0, 1)
f.convertedText:SetText("")

local hoverMarker = hoverOverlay:CreateTexture(nil, "OVERLAY")
hoverMarker:SetColorTexture(1, 0, 0, 1) 
hoverMarker:SetSize(6, 6)
hoverMarker:Hide()

hoverOverlay:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(GetMinimapZoneText() or GetZoneText(), 1, 1, 1)
    GameTooltip:AddLine("Custom UI Coordinate Grid Active", 0.2, 1, 0.2, true)
    GameTooltip:Show()
    hoverMarker:Show()
end)

hoverOverlay:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
    f.coordText:SetText("")
    f.convertedText:SetText("")
    hoverMarker:Hide()
end)

-- The defined local origin point
local ORIGIN_X = 50.0
local ORIGIN_Y = 50.4

hoverOverlay:SetScript("OnUpdate", function(self)
    local debugMsg = ""
    local posFound = false

    -- 1. Try MapUtil as a fallback if GetBestMapForUnit fails
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID and MapUtil then
        mapID = MapUtil.GetDisplayableMapForPlayer()
    end

    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            local x, y = pos:GetXY()
            local playerConvX = (x * 100) - ORIGIN_X
            local playerConvY = (y * 100) - ORIGIN_Y
            f.playerText:SetFormattedText("Player: %.1f, %.1f", playerConvX, playerConvY)
            posFound = true
        else
            debugMsg = debugMsg .. "[MapPos: blocked] "
        end
    else
        debugMsg = debugMsg .. "[MapID: nil] "
    end

    -- 2. Fallback to UnitPosition if Map API fails
    if not posFound then
        local posY, posX, posZ, instanceID = UnitPosition("player")
        if posX and posY then
            f.playerText:SetFormattedText("World (Yds): %.1f, %.1f", posX, posY)
            posFound = true
        else
            debugMsg = debugMsg .. "[UnitPos: blocked]"
        end
    end

    -- 3. Print the exact failure points if neither worked
    if not posFound then
        f.playerText:SetText(debugMsg)
    end

    -- Update Mouse Coordinates if hovering
    if self:IsMouseOver() then
        local cursorX, cursorY = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        
        local localX = (cursorX / scale) - self:GetLeft()
        local localY = (cursorY / scale) - self:GetBottom()
        
        hoverMarker:ClearAllPoints()
        hoverMarker:SetPoint("CENTER", self, "BOTTOMLEFT", localX, localY)
        
        local pctX = (localX / self:GetWidth()) * 100
        local pctY = (localY / self:GetHeight()) * 100
        
        pctX = math.max(0, math.min(100, pctX))
        pctY = math.max(0, math.min(100, pctY))
        pctY = 100 - pctY 
        
        f.coordText:SetFormattedText("Grid: %.1f, %.1f", pctX, pctY)
        
        local convX = pctX - ORIGIN_X
        local convY = pctY - ORIGIN_Y
        f.convertedText:SetFormattedText("Hover: %.1f, %.1f", convX, convY)
    end
end)





hoverOverlay:SetScript("OnMouseWheel", function(self, delta)
    -- Intentionally left blank to disable zooming
end)

-- 5. Minimap Hijack and Restore Logic
local origMinimapParent
local origMinimapPoints = {}
local origWidth, origHeight
local origZoom
local isCaptured = false

local function CaptureMinimap()
    if isCaptured then return end
    isCaptured = true

    origMinimapParent = Minimap:GetParent()
    origWidth, origHeight = Minimap:GetSize()
    origZoom = Minimap:GetZoom()
    
    wipe(origMinimapPoints)
    for i = 1, Minimap:GetNumPoints() do
        local point, relativeTo, relativePoint, xOfs, yOfs = Minimap:GetPoint(i)
        origMinimapPoints[i] = {point, relativeTo, relativePoint, xOfs, yOfs}
    end

    Minimap:SetParent(f)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", f, "CENTER", 0, -10) 
    
    local mapSize = f:GetWidth() - 32
    Minimap:SetSize(mapSize, mapSize) 
    Minimap:SetMaskTexture("Interface/BUTTONS/WHITE8X8")
    
    Minimap:SetZoom(0)
    
    hoverOverlay:SetAllPoints(Minimap)
    hoverOverlay:Show()
    
    if MinimapBorder then MinimapBorder:Hide() end
    if MinimapBorderTop then MinimapBorderTop:Hide() end
    if MinimapCompassTexture then MinimapCompassTexture:Hide() end
    if MiniMapWorldMapButton then MiniMapWorldMapButton:Hide() end
    if MinimapZoneTextButton then MinimapZoneTextButton:Hide() end
    
    if MinimapZoomIn then 
        MinimapZoomIn:Hide()
        MinimapZoomIn.OrigShow = MinimapZoomIn.Show
        MinimapZoomIn.OrigSetAlpha = MinimapZoomIn.SetAlpha
        MinimapZoomIn.Show = function() end
        MinimapZoomIn.SetAlpha = function() end
    end
    if MinimapZoomOut then 
        MinimapZoomOut:Hide()
        MinimapZoomOut.OrigShow = MinimapZoomOut.Show
        MinimapZoomOut.OrigSetAlpha = MinimapZoomOut.SetAlpha
        MinimapZoomOut.Show = function() end
        MinimapZoomOut.SetAlpha = function() end
    end
end

local function ReleaseMinimap()
    if not isCaptured then return end
    isCaptured = false
    
    hoverOverlay:Hide()
    f.coordText:SetText("")
    f.convertedText:SetText("")
    f.playerText:SetText("")
    
    Minimap:SetParent(origMinimapParent)
    Minimap:ClearAllPoints()
    for _, pt in ipairs(origMinimapPoints) do
        Minimap:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5])
    end
    Minimap:SetSize(origWidth, origHeight) 
    
    if origZoom then Minimap:SetZoom(origZoom) end
    Minimap:SetMaskTexture("Interface/CharacterFrame/TempPortraitAlphaMask")
    
    if MinimapBorder then MinimapBorder:Show() end
    if MinimapBorderTop then MinimapBorderTop:Show() end
    if MinimapCompassTexture then MinimapCompassTexture:Show() end
    if MiniMapWorldMapButton then MiniMapWorldMapButton:Show() end
    if MinimapZoneTextButton then MinimapZoneTextButton:Show() end
    
    if MinimapZoomIn and MinimapZoomIn.OrigShow then 
        MinimapZoomIn.Show = MinimapZoomIn.OrigShow
        MinimapZoomIn.SetAlpha = MinimapZoomIn.OrigSetAlpha
        MinimapZoomIn.OrigShow = nil
        MinimapZoomIn.OrigSetAlpha = nil
        MinimapZoomIn:SetAlpha(1)
        MinimapZoomIn:Show()
    end
    if MinimapZoomOut and MinimapZoomOut.OrigShow then 
        MinimapZoomOut.Show = MinimapZoomOut.OrigShow
        MinimapZoomOut.SetAlpha = MinimapZoomOut.OrigSetAlpha
        MinimapZoomOut.OrigShow = nil
        MinimapZoomOut.OrigSetAlpha = nil
        MinimapZoomOut:SetAlpha(1)
        MinimapZoomOut:Show()
    end

    Minimap:Show()
end

f:SetScript("OnShow", CaptureMinimap)
f:SetScript("OnHide", ReleaseMinimap)

-- Force 1:1 Aspect Ratio during resizing
local isUpdatingSize = false
f:SetScript("OnSizeChanged", function(self, width, height)
    if isUpdatingSize then return end
    isUpdatingSize = true
    
    self:SetSize(width, width)
    
    if isCaptured and not isCollapsed then
        local mapSize = width - 32
        Minimap:SetSize(mapSize, mapSize)
    end
    
    isUpdatingSize = false
end)

-- 6. Global Toggle Function, Slash Command, and Keybinding Logic
_G.func_ToggleT5Window = function(optionalID)
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

SLASH_T5_CMD1 = "/t5"
SlashCmdList["T5_CMD"] = function(msg)
    msg = msg and strtrim(msg) or ""
    if msg ~= "" then
        local param = tonumber(msg)
        if param then
            _G.func_ToggleT5Window(param)
        else
            print("|cFFFF3333[T5]|r Invalid input. Usage: /t5")
        end
    else
        _G.func_ToggleT5Window()
    end
end

local toggleBtn = CreateFrame("Button", "T5_UniqueKeybindButton", UIParent)
toggleBtn:SetScript("OnClick", function() _G.func_ToggleT5Window() end)

local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    SetBindingClick("CTRL-NUMPAD5", "T5_UniqueKeybindButton")
    SaveBindings(GetCurrentBindingSet())
end)

--print("|cFF00FF00t5_TrackDgn loaded! Type /t5 or press Ctrl+Numpad 5 to toggle.|r")