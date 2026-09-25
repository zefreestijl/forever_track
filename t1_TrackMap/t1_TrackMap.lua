-- ==========================================
-- 1. Create the Main Frame
-- ==========================================
local f = CreateFrame("Frame", "t1_TrackMap", UIParent)
f:SetSize(916, 640) -- Changed to fit a perfect 3:2 inner canvas
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)


-- Resizing Bounds (Mathematically synced to 1.5 inner ratio)
f:SetResizable(true)
if f.SetResizeBounds then
    f:SetResizeBounds(376, 280, 1216, 840)
else
    f:SetMinResize(376, 280)
    f:SetMaxResize(1216, 840)
end


-- Backgrounds
f.Bg = f:CreateTexture(nil, "BACKGROUND")
f.Bg:SetAllPoints()
f.Bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

f.Header = f:CreateTexture(nil, "ARTWORK")
f.Header:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
f.Header:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
f.Header:SetHeight(24)
f.Header:SetColorTexture(0.2, 0.2, 0.2, 1)

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f, "TOP", 0, -6)
f.title:SetText("t1_TrackMap")

-- Enable moving/dragging
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

-- ==========================================
-- 2. Map Canvas & Content
-- ==========================================
-- Outer boundary that clips overflowing map graphics
f.mapCanvas = CreateFrame("Frame", "$parentMapCanvas", f)
f.mapCanvas:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -32)
f.mapCanvas:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
f.mapCanvas:SetClipsChildren(true)

-- Inner container that gets zoomed and panned
f.mapContent = CreateFrame("Frame", nil, f.mapCanvas)
f.mapContent:SetPoint("TOPLEFT", f.mapCanvas, "TOPLEFT", 0, 0)
f.mapContent:SetSize(900, 600) -- Initial size (916 - 16 width, 640 - 40 height)


-- ==========================================
-- 3. Buttons & Grips
-- ==========================================
f.CloseButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
f.CloseButton:SetSize(24, 24)
f.CloseButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
f.CloseButton:SetScript("OnClick", function() f:Hide() end)

local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", 0, 0)
collapseBtn:SetText("_")
local isCollapsed = false
collapseBtn:SetScript("OnClick", function()
    if isCollapsed then
        f:SetHeight(300)
        if f.Bg then f.Bg:Show() end
        if f.mapCanvas then f.mapCanvas:Show() end
        collapseBtn:SetText("_")
        isCollapsed = false
    else
        f:SetHeight(24)
        if f.Bg then f.Bg:Hide() end
        if f.mapCanvas then f.mapCanvas:Hide() end
        collapseBtn:SetText("+")
        isCollapsed = true
    end
end)

-- ==========================================
-- Zoom Slider (Top Right)
-- ==========================================
f.zoomSlider = CreateFrame("Slider", "T1_TrackMapZoomSlider", f, "OptionsSliderTemplate")
f.zoomSlider:SetSize(80, 16)
f.zoomSlider:SetPoint("RIGHT", collapseBtn, "LEFT", -3, 0)

f.zoomSlider:SetMinMaxValues(1, 10)
f.zoomSlider:SetValueStep(0.01)
f.zoomSlider:SetObeyStepOnDrag(true)

_G[f.zoomSlider:GetName() .. "Low"]:Hide()
_G[f.zoomSlider:GetName() .. "High"]:Hide()

f.zoomSlider.isUpdating = false

f.zoomSlider:SetScript("OnValueChanged", function(self, value)
    if self.isUpdating then return end

    local oldZoom = f.zoomLevel
    local newZoom = value
    if newZoom == oldZoom then return end

    local canvasW, canvasH = f.mapCanvas:GetSize()
    local contentW, contentH = f.mapContent:GetSize()

    if canvasW and canvasH and contentW and contentH then
        -- IF ARROW EXISTS: Always center the map exactly on the player!
        if f.playerArrow and f.playerArrow:IsShown() and f.playerArrow.pX and f.playerArrow.pY then
            local exactPixelX = f.playerArrow.pX * contentW
            local exactPixelY = -f.playerArrow.pY * contentH

            local visualOffsetX = (canvasW / 2) - (exactPixelX * newZoom)
            local visualOffsetY = -(canvasH / 2) - (exactPixelY * newZoom)

            f.mapOffsetX = visualOffsetX / newZoom
            f.mapOffsetY = visualOffsetY / newZoom

            -- FALLBACK: If in an unmapped zone, use the dead-center of the window as a pivot
        else
            local pivotX = canvasW / 2
            local pivotY = -canvasH / 2

            f.mapOffsetX = f.mapOffsetX + pivotX * ((1 / newZoom) - (1 / oldZoom))
            f.mapOffsetY = f.mapOffsetY + pivotY * ((1 / newZoom) - (1 / oldZoom))
        end
    end

    f.zoomLevel = newZoom
    if f.UpdateMapTransform then f:UpdateMapTransform() end
end)


-- ==========================================
-- City Map Data
-- ==========================================
local cityDataByZone = {
    ["elwynn-forest"] = { name = "Stormwind", id = 1453, status = "Alliance", x = 0.718, y = 0.638 },
    ["durotar"] = { name = "Orgrimmar", id = 1454, status = "Horde", x = 0.317, y = 0.449 },
    ["dun-morogh"] = { name = "Ironforge", id = 1455, status = "Alliance", x = 0.759, y = 0.489 },
    ["mulgore"] = { name = "Thunder Bluff", id = 1456, status = "Horde", x = 0.193, y = 0.554 },
    ["teldrassil"] = { name = "Darnassus", id = 1457, status = "Alliance", x = 0.118, y = 0.114 },
    ["tirisfal-glades"] = { name = "Undercity", id = 1458, status = "Horde", x = 0.729, y = 0.226 },
}


-- ==========================================
-- Aspect Ratio Lock
-- ==========================================
f.ResizeGrip = CreateFrame("Button", nil, f)
f.ResizeGrip:SetSize(16, 16)
f.ResizeGrip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
f.ResizeGrip:SetFrameLevel(99)

f.ResizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
f.ResizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
f.ResizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

local ASPECT_RATIO = 800 / 600

f.ResizeGrip:EnableMouse(true)
f.ResizeGrip:RegisterForDrag("LeftButton")
f.ResizeGrip:SetScript("OnDragStart", function(self)
    self.isResizing = true
    local cX, _ = GetCursorPosition()
    self.startX = cX
    self.startW = f:GetWidth()
end)

f.ResizeGrip:SetScript("OnDragStop", function(self)
    self.isResizing = false
    if f.currentMapID then
        f:LoadMap(f.currentMapID)
        if f.RefreshPOIs then f:RefreshPOIs() end
    end
    if f.UpdateMapTransform then f:UpdateMapTransform() end
end)

local MAP_ASPECT_RATIO = 1.5 -- WoW's native 1002x668 map ratio (3:2)

f.ResizeGrip:SetScript("OnUpdate", function(self)
    if self.isResizing then
        local cX, _ = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local dx = (cX - self.startX) / scale
        local newWidth = self.startW + dx

        -- CRITICAL: Updated to match the new 376 / 1216 limits
        if newWidth < 376 then newWidth = 376 end
        if newWidth > 1216 then newWidth = 1216 end

        -- Calculate the exact height needed to keep the INNER canvas at 1.5 ratio
        local canvasW = newWidth - 16
        local newHeight = (canvasW / MAP_ASPECT_RATIO) + 40

        f:SetSize(newWidth, newHeight)
    end
end)


f:SetScript("OnSizeChanged", function(self)
    if self.mapContent and self.mapCanvas then
        local w, h = self.mapCanvas:GetSize()
        if w and h and w > 1 and h > 1 then
            self.mapContent:SetSize(w, h)
        end
    end
end)

-- ==========================================
-- Live Zoom Scale Display (Top Left)
-- ==========================================
f.zoomUI = CreateFrame("Frame", nil, f)
f.zoomUI:SetAllPoints(f.mapCanvas)
f.zoomUI:SetFrameStrata("HIGH")

f.zoomText = f.zoomUI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
f.zoomText:SetPoint("TOPLEFT", f.zoomUI, "TOPLEFT", 5, -5)
f.zoomText:SetJustifyH("LEFT")
f.zoomText:SetText("Scale: 1.00x")


-- ==========================================
-- Map Panning & Click Detection
-- ==========================================
f.mapCanvas:EnableMouse(true)
f.mapCanvas:SetScript("OnMouseDown", function(self, button)
    self.startX, self.startY = GetCursorPosition()
    self.startOffsetX = f.mapOffsetX or 0
    self.startOffsetY = f.mapOffsetY or 0

    if button == "LeftButton" then
        self.isDragging = true
    end
end)


f.mapCanvas:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then self.isDragging = false end

    if not self.startX or not self.startY then return end

    local cX, cY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local dragDistance = (math.abs(cX - self.startX) + math.abs(cY - self.startY)) / scale

    if dragDistance < 25 then
        local MY_CUSTOM_WORLD_MAP_ID = 947

        -- ==========================================
        -- RIGHT CLICK: Open T2 Window with MapID
        -- ==========================================
        if button == "RightButton" then
            local targetMapID = nil

            if f.currentMapID == MY_CUSTOM_WORLD_MAP_ID then
                -- If we are hovering a zone that has a capital city, prefer the city's ID
                if self.hoveredZone and cityDataByZone[self.hoveredZone] then
                    targetMapID = cityDataByZone[self.hoveredZone].id
                else
                    -- Otherwise, use the standard zone ID we just saved in OnUpdate
                    targetMapID = self.hoveredMapID
                end
            else
                -- If we are already looking at a specific city map, use its ID directly
                targetMapID = f.currentMapID
            end

            -- Pass the targetMapID to your T2 API
            if _G.func_ToggleT2Window then
                _G.func_ToggleT2Window(targetMapID)
            else
                print("|cffff2020T1_TrackMap:|r T2_TrackNPC addon is not loaded.")
            end

            -- ==========================================
            -- WORLD MAP SPECIFIC CLICKS (Left / Middle)
            -- ==========================================
        elseif f.currentMapID == MY_CUSTOM_WORLD_MAP_ID then
            if button == "LeftButton" then
                if self.hoveredZone and cityDataByZone[self.hoveredZone] then
                    local cityID = cityDataByZone[self.hoveredZone].id
                    f.zoomLevel = 1
                    f.mapOffsetX = 0
                    f.mapOffsetY = 0
                    f:LoadMap(cityID)
                    if f.UpdateMapTransform then f:UpdateMapTransform() end
                    if f.RefreshPOIs then f:RefreshPOIs() end
                end
            elseif button == "MiddleButton" then
                local canvasW, canvasH = self:GetSize()
                local contentW, contentH = f.mapContent:GetSize()

                if canvasW and canvasH and contentW and contentH then
                    local fitScale = math.min(canvasW / contentW, canvasH / contentH)

                    if fitScale < 1 then fitScale = 1 end
                    if fitScale > 10 then fitScale = 10 end

                    f.zoomLevel = fitScale

                    local visualOffsetX = (canvasW - (contentW * f.zoomLevel)) / 2
                    local visualOffsetY = -(canvasH - (contentH * f.zoomLevel)) / 2

                    f.mapOffsetX = visualOffsetX / f.zoomLevel
                    f.mapOffsetY = visualOffsetY / f.zoomLevel
                end
                if f.UpdateMapTransform then f:UpdateMapTransform() end
            end
        end
    end
    self.startX = nil
    self.startY = nil
end)


-- ==========================================
-- Live Cursor Coordinate Tooltip
-- ==========================================
f.cursorTooltip = CreateFrame("Frame", nil, f.mapCanvas)
f.cursorTooltip:SetSize(120, 65)
f.cursorTooltip:SetFrameLevel(f.mapCanvas:GetFrameLevel() + 20)
f.cursorTooltip:Hide()

f.cursorTooltip.text = f.cursorTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
f.cursorTooltip.text:SetPoint("CENTER", f.cursorTooltip, "CENTER", 0, 0)

f.mapCanvas:SetScript("OnUpdate", function(self)
    -- Panning / Dragging Logic
    if self.isDragging then
        local cX, cY = GetCursorPosition()
        local uiScale = UIParent:GetEffectiveScale()

        local dx = (cX - self.startX) / uiScale
        local dy = (cY - self.startY) / uiScale

        f.mapOffsetX = self.startOffsetX + (dx / f.zoomLevel)
        f.mapOffsetY = self.startOffsetY + (dy / f.zoomLevel)
        f:UpdateMapTransform()
    end


    -- Coordinate Tracking
    local MY_CUSTOM_WORLD_MAP_ID = 947
    if f.currentMapID == MY_CUSTOM_WORLD_MAP_ID and self:IsMouseOver() then
        local rawX, rawY = GetCursorPosition()
        local mapScale = f.mapContent:GetEffectiveScale()
        local mapX = rawX / mapScale
        local mapY = rawY / mapScale

        local left = f.mapContent:GetLeft()
        local top = f.mapContent:GetTop()

        if left and top then
            local pctX = (mapX - left) / f.mapContent:GetWidth()
            local pctY = (top - mapY) / f.mapContent:GetHeight()

            if pctX >= 0 and pctX <= 1 and pctY >= 0 and pctY <= 1 then
                local closestZone = "Unknown Area"
                local closestComment = ""
                local closestID = "0"
                local hoverLocalX, hoverLocalY = 0, 0
                local minDist = 999

                if T1_ZoneDB then
                    for id, data in pairs(T1_ZoneDB) do
                        if data.x and data.y then
                            local dx = data.x - pctX
                            local dy = data.y - pctY
                            local distSq = (dx * dx) + (dy * dy)

                            if distSq < minDist then
                                minDist = distSq
                                closestZone = data.name
                                closestComment = data.comment or ""
                                closestID = id

                                local zoneW = data.w or 0.05
                                local zoneH = data.h or 0.05
                                hoverLocalX = ((pctX - data.x) / zoneW) + 0.5
                                hoverLocalY = ((pctY - data.y) / zoneH) + 0.5
                            end
                        end
                    end
                end

                if minDist > 0.015 then
                    closestZone = "Great Sea"
                    closestComment = ""
                    closestID = "???"
                    hoverLocalX, hoverLocalY = 0, 0
                end

                self.hoveredZone = closestZone

                -- ==========================================
                -- NEW: Save the actual MapID of the hovered zone!
                -- ==========================================
                self.hoveredMapID = (closestID ~= "???") and tonumber(closestID) or nil


                local colorCode = "|cffffffff"
                if cityDataByZone[closestZone] then
                    if cityDataByZone[closestZone].status == "Alliance" then
                        colorCode = "|cff0078ff"
                    elseif cityDataByZone[closestZone].status == "Horde" then
                        colorCode = "|cffff2020"
                    end
                end

                if not self.isDragging then ResetCursor() end

                local headerText = ""
                if closestID == "???" then
                    headerText = "|cffaaaaaa#???|r"
                else
                    headerText = string.format("|cffaaaaaa#%s (%.0f, %.0f)|r", closestID, hoverLocalX * 100,
                        hoverLocalY * 100)
                end

                if closestComment ~= "" then
                    f.cursorTooltip.text:SetFormattedText("%s\n%s%s\n%s\n%.3f, %.3f|r", headerText, colorCode,
                        closestZone:upper(), closestComment, pctX, pctY)
                else
                    f.cursorTooltip.text:SetFormattedText("%s\n%s%s\n%.3f, %.3f|r", headerText, colorCode,
                        closestZone:upper(), pctX, pctY)
                end

                local uiScale = f.cursorTooltip:GetEffectiveScale()
                f.cursorTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (rawX / uiScale) + 15,
                    (rawY / uiScale) - 25)
                f.cursorTooltip:Show()
            else
                f.cursorTooltip:Hide()
                if not self.isDragging then ResetCursor() end
            end
        end
    else
        f.cursorTooltip:Hide()
        if not self.isDragging then ResetCursor() end
    end
end)


-- ==========================================
-- Map Menus & URL Credit Box
-- ==========================================
local MY_CUSTOM_WORLD_MAP_ID = 947
f.isDetailedMap = false

f.MapToggleButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.MapToggleButton:SetSize(130, 22)
f.MapToggleButton:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -1)
f.MapToggleButton:SetText("Show Detailed Map")
f.MapToggleButton:SetScript("OnClick", function()
    f.isDetailedMap = not f.isDetailedMap
    if f.isDetailedMap then
        f.MapToggleButton:SetText("Show Blank Map")
    else
        f.MapToggleButton:SetText("Show Detailed Map")
    end
    f:LoadMap(MY_CUSTOM_WORLD_MAP_ID)
    if f.UpdateMapTransform then f:UpdateMapTransform() end
    if f.RefreshPOIs then f:RefreshPOIs() end
end)

f.creditBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
f.creditBox:SetSize(270, 20)
f.creditBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 65, 12)
f.creditBox:SetAutoFocus(false)
f.creditBox:SetFontObject("ChatFontNormal")
f.creditBox:SetFrameLevel(f.mapCanvas:GetFrameLevel() + 10)

f.creditLabel = f.creditBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
f.creditLabel:SetPoint("RIGHT", f.creditBox, "LEFT", -10, 0)
f.creditLabel:SetText("Source:")

f.creditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
f.creditBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
f.creditBox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
f.creditBox:SetScript("OnChar", function(self)
    self:SetText(self.currentURL)
    self:HighlightText()
end)

-- Live Coordinate Display (Bottom Right)
f.coordText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
f.coordText:SetPoint("BOTTOMRIGHT", f.ResizeGrip, "BOTTOMLEFT", -10, 2)
f.coordText:SetJustifyH("RIGHT")
f.coordText:SetText("")

-- ==========================================
-- Map Generation Logic
-- ==========================================
f.mapTiles = {}
f.mapPins = {}

function f:LoadMap(mapID)
    f.currentMapID = mapID
    for _, tile in ipairs(f.mapTiles) do tile:Hide() end
    wipe(f.mapTiles)

    if mapID == MY_CUSTOM_WORLD_MAP_ID then
        f.creditLabel:Show()
        f.creditBox:Show()

        local customTile = f.mapContent:CreateTexture(nil, "BACKGROUND")
        customTile:SetAllPoints(f.mapContent)

        if f.isDetailedMap then
            customTile:SetTexture("Interface\\AddOns\\t1_TrackMap\\map_texture\\world map-detailed.tga")
            f.creditBox.currentURL = "http://redd.it/bid2ue"
        else
            customTile:SetTexture("Interface\\AddOns\\t1_TrackMap\\map_texture\\world map-blank.tga")
            f.creditBox.currentURL = "https://warcraft-games.3dn.ru/Wow/fullmap.jpg"
        end

        f.creditBox:SetText(f.creditBox.currentURL)
        table.insert(f.mapTiles, customTile)
    else
        f.creditLabel:Hide()
        f.creditBox:Hide()

        local layers = C_Map.GetMapArtLayers(mapID)
        if not layers or #layers == 0 then return end

        local layerInfo = layers[1]
        local textures = C_Map.GetMapArtLayerTextures(mapID, 1)
        if not textures then return end

        local numCols = math.ceil(layerInfo.layerWidth / layerInfo.tileWidth)
        local numRows = math.ceil(layerInfo.layerHeight / layerInfo.tileHeight)

        local scaleX = f.mapContent:GetWidth() / layerInfo.layerWidth
        local scaleY = f.mapContent:GetHeight() / layerInfo.layerHeight

        local textureIndex = 1
        for row = 1, numRows do
            for col = 1, numCols do
                if textureIndex > #textures then break end

                local tile = f.mapContent:CreateTexture(nil, "BACKGROUND")
                local tileWidth = layerInfo.tileWidth * scaleX
                local tileHeight = layerInfo.tileHeight * scaleY

                tile:SetSize(tileWidth, tileHeight)
                tile:SetPoint("TOPLEFT", f.mapContent, "TOPLEFT", (col - 1) * tileWidth, -(row - 1) * tileHeight)
                tile:SetTexture(textures[textureIndex])

                table.insert(f.mapTiles, tile)
                textureIndex = textureIndex + 1
            end
        end
    end
end

-- ==========================================
-- Zoom & Pan Logic (and Flags)
-- ==========================================
f.zoomLevel = 1
f.mapOffsetX = 0
f.mapOffsetY = 0

function f:UpdateMapTransform()
    if not self.mapContent or not self.mapCanvas then return end

    if self.zoomLevel < 1 then self.zoomLevel = 1 end
    if self.zoomLevel > 10 then self.zoomLevel = 10 end

    self.mapContent:SetScale(self.zoomLevel)

    local canvasW, canvasH = self.mapCanvas:GetSize()
    local contentW, contentH = self.mapContent:GetSize()
    if not canvasW or canvasW <= 0 or not contentW or contentW <= 0 then return end

    local effW = contentW * self.zoomLevel
    local effH = contentH * self.zoomLevel

    local BLEED_RATIO = 0.75
    local bleedX = canvasW * BLEED_RATIO
    local bleedY = canvasH * BLEED_RATIO

    local visualMinX = (canvasW - effW) - bleedX
    local visualMaxX = bleedX
    local visualMinY = -bleedY
    local visualMaxY = (effH - canvasH) + bleedY

    local currentVisualX = self.mapOffsetX * self.zoomLevel
    local currentVisualY = self.mapOffsetY * self.zoomLevel

    if currentVisualX > visualMaxX then currentVisualX = visualMaxX end
    if currentVisualX < visualMinX then currentVisualX = visualMinX end
    if currentVisualY < visualMinY then currentVisualY = visualMinY end
    if currentVisualY > visualMaxY then currentVisualY = visualMaxY end

    self.mapOffsetX = currentVisualX / self.zoomLevel
    self.mapOffsetY = currentVisualY / self.zoomLevel

    self.mapContent:ClearAllPoints()
    self.mapContent:SetPoint("TOPLEFT", self.mapCanvas, "TOPLEFT", self.mapOffsetX, self.mapOffsetY)

    if f.zoomText then f.zoomText:SetFormattedText("Scale: %.2fx", self.zoomLevel) end

    -- Sync slider
    if f.zoomSlider then
        f.zoomSlider.isUpdating = true
        f.zoomSlider:SetValue(self.zoomLevel)
        f.zoomSlider.isUpdating = false
    end

    -- ==========================================
    -- BULLETPROOF FRAME-BASED CITY FLAGS
    -- ==========================================
    local MY_CUSTOM_WORLD_MAP_ID = 947

    if f.currentMapID == MY_CUSTOM_WORLD_MAP_ID then
        -- 1. Create the frames exactly once
        if not f.cityFlags then
            f.cityFlags = {}
            for key, data in pairs(cityDataByZone) do
                local flagFrame = CreateFrame("Frame", nil, self.mapContent)
                flagFrame:SetFrameLevel(self.mapContent:GetFrameLevel() + 50)

                local tex = flagFrame:CreateTexture(nil, "BACKGROUND")
                tex:SetAllPoints()
                if data.status == "Alliance" then
                    tex:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
                else
                    tex:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
                end
                tex:SetTexCoord(10 / 64, 54 / 64, 10 / 64, 54 / 64)

                f.cityFlags[key] = { frame = flagFrame, x = data.x or 0, y = data.y or 0 }
            end
        end

        -- 2. Render and Counter-Scale
        for key, flagObj in pairs(f.cityFlags) do
            flagObj.frame:Show()

            local baseSize = 24
            flagObj.frame:SetSize(baseSize / self.zoomLevel, baseSize / self.zoomLevel)

            flagObj.frame:ClearAllPoints()
            flagObj.frame:SetPoint("CENTER", self.mapContent, "TOPLEFT", flagObj.x * contentW, -flagObj.y * contentH)
        end
    else
        if f.cityFlags then
            for key, flagObj in pairs(f.cityFlags) do
                flagObj.frame:Hide()
            end
        end
    end
end

f.mapCanvas:EnableMouseWheel(true)
f.mapCanvas:SetScript("OnMouseWheel", function(self, delta)
    local oldZoom = f.zoomLevel
    local newZoom = oldZoom + (delta * 0.25)

    if newZoom < 1 then newZoom = 1 end
    if newZoom > 10 then newZoom = 10 end
    if newZoom == oldZoom then return end

    local cX, cY = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale()
    cX = cX / uiScale
    cY = cY / uiScale

    local left = self:GetLeft()
    local top = self:GetTop()
    local mouseX = cX - left
    local mouseY = cY - top

    f.mapOffsetX = f.mapOffsetX + mouseX * ((1 / newZoom) - (1 / oldZoom))
    f.mapOffsetY = f.mapOffsetY + mouseY * ((1 / newZoom) - (1 / oldZoom))

    f.zoomLevel = newZoom
    f:UpdateMapTransform()
end)

-- ==========================================
-- Live Player Tracker Arrow
-- ==========================================
f.playerArrow = f.mapContent:CreateTexture(nil, "OVERLAY")
f.playerArrow:SetTexture("Interface\\Minimap\\MinimapArrow")
f.playerArrow:SetDrawLayer("OVERLAY", 7)

f.playerArrowTracker = CreateFrame("Frame", nil, f.mapCanvas)
f.playerArrowTracker:SetScript("OnUpdate", function()
    local MY_CUSTOM_WORLD_MAP_ID = 947

    if f.currentMapID == MY_CUSTOM_WORLD_MAP_ID then
        local hasValidData = false
        local pX, pY = 0, 0

        local currentZoneID = C_Map.GetBestMapForUnit("player")
        if currentZoneID then
            local pos = C_Map.GetPlayerMapPosition(currentZoneID, "player")
            if pos and pos.x and pos.y and T1_ZoneDB and T1_ZoneDB[currentZoneID] then
                local localX, localY = pos.x, pos.y
                local zoneData = T1_ZoneDB[currentZoneID]

                if zoneData.x and zoneData.y and zoneData.w and zoneData.h then
                    pX = zoneData.x + ((localX - 0.5) * zoneData.w)
                    pY = zoneData.y + ((localY - 0.5) * zoneData.h)
                    hasValidData = true
                end
            end
        end

        if hasValidData then
            f.playerArrow:Show()
            local baseSize = 32
            f.playerArrow:SetSize(baseSize / f.zoomLevel, baseSize / f.zoomLevel)

            local facing = GetPlayerFacing()
            if facing then f.playerArrow:SetRotation(facing) end

            f.playerArrow.pX = pX
            f.playerArrow.pY = pY

            local pixelX = pX * f.mapContent:GetWidth()
            local pixelY = -pY * f.mapContent:GetHeight()
            f.playerArrow:SetPoint("CENTER", f.mapContent, "TOPLEFT", pixelX, pixelY)
        else
            f.playerArrow:Hide()
            f.playerArrow.pX = nil
            f.playerArrow.pY = nil
        end
    else
        f.playerArrow:Hide()
    end
end)

-- ==========================================
-- Visibility, Keybindings & Initialization
-- ==========================================
tinsert(UISpecialFrames, f:GetName())
f:Hide()

local function ToggleT1Window()
    if f:IsShown() then f:Hide() else f:Show() end
end

SLASH_T1_CMD1 = "/t1"
SlashCmdList["T1_CMD"] = function() ToggleT1Window() end

local toggleBtn = CreateFrame("Button", "T1_KeybindButton", UIParent, "SecureActionButtonTemplate")
toggleBtn:SetAttribute("type", "macro")
toggleBtn:SetAttribute("macrotext", "/t1")
toggleBtn:SetScript("OnClick", function() ToggleT1Window() end)

local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    SetBindingClick("CTRL-NUMPAD1", "T1_KeybindButton")

    local bindSet = GetCurrentBindingSet() or 1
    if bindSet ~= 1 and bindSet ~= 2 then bindSet = 1 end
    SaveBindings(bindSet)
end)

f:SetScript("OnShow", function(self)
    if not self.currentMapLoaded then
        self:LoadMap(MY_CUSTOM_WORLD_MAP_ID)
        self.currentMapLoaded = true
    end
    -- CRITICAL FIX: Force the map to draw the flags instantly when opening the window!
    if self.UpdateMapTransform then self:UpdateMapTransform() end
end)

print("|cFF00FF00t1_TrackMap UI Built! Type /t1 or Ctrl+Numpad 1|r")
