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
                -- Always use the standard zone ID we just saved in OnUpdate!
                targetMapID = self.hoveredMapID
            else
                -- If we are already zoomed into a specific city map, use its ID directly
                targetMapID = f.currentMapID
            end

            -- DEBUG PRINT: Let's see exactly what T1 is sending!
            print(string.format("|cff00ff00T1_TrackMap DEBUG:|r Right-Clicked! Target MapID: %s | Hovered Zone: %s",
                tostring(targetMapID), tostring(self.hoveredZone)))

            -- Pass the targetMapID to your T2 API
            if _G.func_ToggleT2Window then
                _G.func_ToggleT2Window(targetMapID)
            else
                print("|cffff2020T1_TrackMap:|r T2_TrackNPC addon is not loaded.")
            end
            local targetMapID = nil

            if f.currentMapID == MY_CUSTOM_WORLD_MAP_ID then
                -- Always use the standard zone ID we just saved in OnUpdate!
                targetMapID = self.hoveredMapID
            else
                -- If we are already zoomed into a specific city map, use its ID directly
                targetMapID = f.currentMapID
            end

            -- Pass the targetMapID to your T2 API
            if _G.func_ToggleT2Window then
                _G.func_ToggleT2Window(targetMapID)
            else
                print("|cffff2020T1_TrackMap:|r T2_TrackNPC addon is not loaded.")
            end
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
-- Zoom & Pan Logic (and Flags / Pins)
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

    -- ==========================================
    -- RENDER CUSTOM MAP PINS (Global & Regional)
    -- ==========================================
    if not f.pinFrames then f.pinFrames = {} end
    if not f.customPins then f.customPins = {} end

    local maxIndex = math.max(#f.customPins, #f.pinFrames)

    for i = 1, maxIndex do
        local pinData = f.customPins[i]
        local frame = f.pinFrames[i]

        if pinData and not frame then
            frame = CreateFrame("Frame", nil, self.mapContent)
            frame:SetFrameLevel(self.mapContent:GetFrameLevel() + 60)

            local tex = frame:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints()
            tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")

            frame.tex = tex
            f.pinFrames[i] = frame
        end

        if pinData and frame then
            frame.tex:SetVertexColor(pinData.r, pinData.g, pinData.b, 1)

            local showPin = false
            local drawX, drawY = 0, 0

            if f.currentMapID == pinData.mapID then
                drawX = pinData.x
                drawY = pinData.y
                showPin = true
            elseif f.currentMapID == MY_CUSTOM_WORLD_MAP_ID then
                if T1_ZoneDB and T1_ZoneDB[pinData.mapID] then
                    local zData = T1_ZoneDB[pinData.mapID]
                    if zData.x and zData.w and zData.y and zData.h then
                        drawX = zData.x + ((pinData.x - 0.5) * zData.w)
                        drawY = zData.y + ((pinData.y - 0.5) * zData.h)
                        showPin = true
                    end
                end
            end

            if showPin then
                frame:Show()
                local baseSize = 24
                frame:SetSize(baseSize / self.zoomLevel, baseSize / self.zoomLevel)
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", self.mapContent, "TOPLEFT", drawX * contentW, -drawY * contentH)
            else
                frame:Hide()
            end
        elseif frame then
            frame:Hide()
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
-- Auto-Frame: Zoom Fit Player and Pin
-- ==========================================
function f:ZoomFitPlayerAndPin()-- =========================================================================
-- 1. Main Frame Setup
-- =========================================================================
local f = CreateFrame("Frame", "t3_TrackQst", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(320, 500)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f, "TOP", 0, -6)
f.title:SetText("t3_TrackQst - Rewards & Choices")

local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
collapseBtn:SetText("_")
local isCollapsed = false

-- =========================================================================
-- 2. Bottom Action Buttons (Expand/Collapse/Untrack All)
-- =========================================================================
local btnExpandAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
btnExpandAll:SetSize(90, 22)
btnExpandAll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 8)
btnExpandAll:SetText("Expand All")

local btnCollapseAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
btnCollapseAll:SetSize(90, 22)
btnCollapseAll:SetPoint("LEFT", btnExpandAll, "RIGHT", 10, 0)
btnCollapseAll:SetText("Collapse All")

local btnUntrackAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
btnUntrackAll:SetSize(90, 22)
btnUntrackAll:SetPoint("LEFT", btnCollapseAll, "RIGHT", 10, 0)
btnUntrackAll:SetText("Untrack All")

-- Style Untrack All to look like an inactive tab (dimmed) to prevent accidental clicks
local untrackText = btnUntrackAll:GetFontString()
if untrackText then untrackText:SetTextColor(0.5, 0.5, 0.5) end
for _, region in ipairs({btnUntrackAll:GetRegions()}) do
    if region.IsObjectType and region:IsObjectType("Texture") then
        region:SetVertexColor(0.4, 0.4, 0.4)
    end
end

-- =========================================================================
-- 3. ScrollFrame Setup & Custom Scrolling
-- =========================================================================
local scrollFrame = CreateFrame("ScrollFrame", "T3_QuestScrollFrame", f, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -50)
scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 35)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(scrollFrame:GetWidth(), 1)
scrollFrame:SetScrollChild(content)

-- Custom 3-Item Mouse Wheel Scrolling Override
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local scrollBar = _G[self:GetName() .. "ScrollBar"]
    if scrollBar then
        local scrollStep = 90 
        local minVal, maxVal = scrollBar:GetMinMaxValues()
        local newVal = scrollBar:GetValue() - (delta * scrollStep)
        
        if newVal < minVal then newVal = minVal end
        if newVal > maxVal then newVal = maxVal end
        
        scrollBar:SetValue(newVal)
    end
end)

local tabButtons = {}

collapseBtn:SetScript("OnClick", function()
    if isCollapsed then
        f:SetHeight(500)
        if f.Bg then f.Bg:Show() end
        if f.InsetBg then f.InsetBg:Show() end
        scrollFrame:Show()
        btnExpandAll:Show()
        btnCollapseAll:Show()
        btnUntrackAll:Show()
        collapseBtn:SetText("_")
        isCollapsed = false
        if _G.UpdateQuestList then _G.UpdateQuestList() end
    else
        f:SetHeight(32)
        if f.Bg then f.Bg:Hide() end
        if f.InsetBg then f.InsetBg:Hide() end
        scrollFrame:Hide()
        btnExpandAll:Hide()
        btnCollapseAll:Hide()
        btnUntrackAll:Hide()
        for _, tab in ipairs(tabButtons) do tab:Hide() end
        collapseBtn:SetText("+")
        isCollapsed = true
    end
end)

-- =========================================================================
-- 4. Dynamic Tabs Logic
-- =========================================================================
local activeFilter = "All"

local function GetOrCreateTab(index)
    local tab = tabButtons[index]
    if not tab then
        tab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        tab:SetHeight(22)
        tab.text = tab:GetFontString()
        table.insert(tabButtons, tab)
    end
    return tab
end

-- =========================================================================
-- 5. Accordion Logic & Data Population
-- =========================================================================
local questLines = {}
local expandedQuests = {} 

btnExpandAll:SetScript("OnClick", function()
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local q = C_QuestLog.GetInfo(i)
        if q and not q.isHidden and not q.isHeader then
            expandedQuests[q.questID] = true
        end
    end
    if _G.UpdateQuestList then _G.UpdateQuestList() end
end)

btnCollapseAll:SetScript("OnClick", function()
    wipe(expandedQuests)
    if _G.UpdateQuestList then _G.UpdateQuestList() end
end)

btnUntrackAll:SetScript("OnClick", function()
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local questInfo = C_QuestLog.GetInfo(i)
        if questInfo and not questInfo.isHidden and not questInfo.isHeader then
            local isCurrentlyTracked = false
            if type(C_QuestLog.GetQuestWatchType) == "function" then
                isCurrentlyTracked = (C_QuestLog.GetQuestWatchType(questInfo.questID) ~= nil)
            elseif type(IsQuestWatched) == "function" then
                isCurrentlyTracked = IsQuestWatched(i)
            end
            
            if isCurrentlyTracked then
                if type(C_QuestLog.RemoveQuestWatch) == "function" then
                    C_QuestLog.RemoveQuestWatch(questInfo.questID)
                elseif type(RemoveQuestWatch) == "function" then
                    RemoveQuestWatch(i)
                end
            end
        end
    end
    if _G.UpdateQuestList then _G.UpdateQuestList() end
end)

local function GetOrCreateLine(index)
    local btn = questLines[index]
    if not btn then
        btn = CreateFrame("Button", nil, content)
        btn.text = btn:CreateFontString(nil, "OVERLAY")
        btn.text:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        btn.text:SetJustifyH("LEFT")
        btn.text:SetWordWrap(true)
        
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.5, 0.5, 0.5, 0.25)
        btn.bg:Hide()
        
        table.insert(questLines, btn)
    end
    
    btn.bg:Hide()
    btn.bg:SetColorTexture(0.5, 0.5, 0.5, 0.25)
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    btn:SetScript("OnClick", nil)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    return btn
end

local function GetItemLinkSafe(typeStr, index, questID)
    if type(GetQuestLogItemLink) == "function" then
        local s, l = pcall(GetQuestLogItemLink, typeStr, index, questID)
        if s and l then return l end
        s, l = pcall(GetQuestLogItemLink, typeStr, index)
        if s and l then return l end
    end
    return nil
end

local function GetMoneyStringPlain(money)
    if not money or money <= 0 then return "" end
    local g = math.floor(money / 10000)
    local s = math.floor((money % 10000) / 100)
    local c = money % 100
    local str = ""
    if g > 0 then str = str .. g .. "g " end
    if s > 0 then str = str .. s .. "s " end
    if c > 0 then str = str .. c .. "c" end
    return str
end

local function GetDifficultyColorHex(questLevel)
    if not questLevel or questLevel <= 0 then return "|cFFFFFF00" end
    
    local playerLevel = UnitLevel("player") or 1
    local diff = questLevel - playerLevel
    
    if diff >= 5 then 
        return "|cFFFF1A1A" -- Red
    elseif diff >= 3 then 
        return "|cFFFF8040" -- Orange
    elseif diff >= -2 then 
        return "|cFFFFFF00" -- Yellow
    else
        local grayLevel = 0
        if playerLevel <= 5 then 
            grayLevel = 0
        elseif playerLevel <= 39 then 
            grayLevel = playerLevel - 5 - math.floor(playerLevel / 10)
        elseif playerLevel <= 59 then 
            grayLevel = playerLevel - 1 - math.floor(playerLevel / 5)
        else 
            grayLevel = playerLevel - 9 
        end
        
        if questLevel <= grayLevel then
            return "|cFF808080" -- Gray
        else
            return "|cFF40C040" -- Green
        end
    end
end

function _G.UpdateQuestList()
    if not f:IsShown() or isCollapsed then return end

    for _, line in ipairs(questLines) do line:Hide() end
    for _, tab in ipairs(tabButtons) do tab:Hide() end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    local filters = { ["All"] = true, ["Tracked"] = true, ["Untracked"] = true }
    
    for i = 1, numEntries do
        local q = C_QuestLog.GetInfo(i)
        if q and not q.isHidden and q.isHeader then filters[q.title] = true end
    end

    local sortedFilters = {}
    for k in pairs(filters) do table.insert(sortedFilters, k) end
    table.sort(sortedFilters, function(a, b)
        local order = { ["All"] = 1, ["Tracked"] = 2, ["Untracked"] = 3 }
        if order[a] and order[b] then return order[a] < order[b] end
        if order[a] then return true end
        if order[b] then return false end
        return a < b
    end)

    local tabX, tabY = 10, -28
    for i, filterName in ipairs(sortedFilters) do
        local tab = GetOrCreateTab(i)
        tab:SetText(filterName)
        local tabWidth = tab.text:GetStringWidth() + 20
        tab:SetWidth(tabWidth)
        
        if tabX + tabWidth > f:GetWidth() - 20 then
            tabX = 10
            tabY = tabY - 24
        end
        
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", tabX, tabY)
        tabX = tabX + tabWidth + 4
        
        local isSelected = (activeFilter == filterName)
        if isSelected then 
            tab:LockHighlight() 
            tab.text:SetTextColor(1, 0.82, 0)
        else 
            tab:UnlockHighlight() 
            tab.text:SetTextColor(0.5, 0.5, 0.5)
        end
        
        for _, region in ipairs({tab:GetRegions()}) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                if isSelected then
                    region:SetVertexColor(1, 1, 1)
                else
                    region:SetVertexColor(0.4, 0.4, 0.4)
                end
            end
        end
        
        tab:SetScript("OnClick", function() activeFilter = filterName; _G.UpdateQuestList() end)
        tab:Show()
    end
    
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, tabY - 26)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 35)

    local yOffset = -5
    local lineIndex = 1

    local function FlushText(textStr, indent)
        if textStr == "" then return end
        local dBtn = GetOrCreateLine(lineIndex)
        dBtn:ClearAllPoints()
        dBtn:SetPoint("TOPLEFT", content, "TOPLEFT", indent or 35, yOffset)
        dBtn.text:SetWidth(scrollFrame:GetWidth() - (indent or 35) - 5)
        dBtn.text:SetFontObject("GameFontHighlightSmall")
        dBtn.text:SetText(textStr)
        local h = dBtn.text:GetStringHeight()
        dBtn:SetSize(scrollFrame:GetWidth() - (indent or 35) - 5, h + 4)
        dBtn:Show()
        yOffset = yOffset - (h + 8)
        lineIndex = lineIndex + 1
    end

    local function RenderSingleQuest(questInfo, logIndex)
        local qBtn = GetOrCreateLine(lineIndex)
        qBtn:ClearAllPoints()
        qBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
        qBtn.text:SetWidth(scrollFrame:GetWidth() - 25)
        qBtn.text:SetFontObject("GameFontHighlight")
        
        local hexDiff = GetDifficultyColorHex(questInfo.level)

        local expandSymbol = expandedQuests[questInfo.questID] and "[-] " or "[+] "
        local levelText = questInfo.level > 0 and ("[" .. questInfo.level .. "] ") or ""
        local status = questInfo.isComplete and " |cFF00FF00(Ready)|r" or ""
        
        qBtn.text:SetText(hexDiff .. expandSymbol .. levelText .. questInfo.title .. "|r" .. status)
        
        qBtn:SetScript("OnEnter", function(self) self.text:SetAlpha(0.7) end)
        qBtn:SetScript("OnLeave", function(self) self.text:SetAlpha(1.0) end)
        qBtn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                local isCurrentlyTracked = false
                if type(C_QuestLog.GetQuestWatchType) == "function" then
                    isCurrentlyTracked = (C_QuestLog.GetQuestWatchType(questInfo.questID) ~= nil)
                elseif type(IsQuestWatched) == "function" then
                    isCurrentlyTracked = IsQuestWatched(logIndex)
                end
                
                if isCurrentlyTracked then
                    if type(C_QuestLog.RemoveQuestWatch) == "function" then
                        C_QuestLog.RemoveQuestWatch(questInfo.questID)
                    elseif type(RemoveQuestWatch) == "function" then
                        RemoveQuestWatch(logIndex)
                    end
                else
                    if type(C_QuestLog.AddQuestWatch) == "function" then
                        C_QuestLog.AddQuestWatch(questInfo.questID)
                    elseif type(AddQuestWatch) == "function" then
                        AddQuestWatch(logIndex)
                    end
                end
            else
                expandedQuests[questInfo.questID] = not expandedQuests[questInfo.questID]
            end
            _G.UpdateQuestList()
        end)

        local qHeight = qBtn.text:GetStringHeight()
        qBtn:SetSize(scrollFrame:GetWidth() - 25, qHeight + 4)
        qBtn:Show()
        yOffset = yOffset - (qHeight + 6)
        lineIndex = lineIndex + 1

        if expandedQuests[questInfo.questID] then
            C_QuestLog.SetSelectedQuest(questInfo.questID)
            
            -- 1. Story & Money Block
            local textBlock1 = ""
            local description, objectiveText = GetQuestLogQuestText()
            if objectiveText and objectiveText ~= "" then textBlock1 = textBlock1 .. "|cFFFFFF00Preface:|r\n" .. objectiveText .. "\n\n" end
            if description and description ~= "" then textBlock1 = textBlock1 .. "|cFFFFFF00Story:|r\n" .. description .. "\n\n" end
            
            local xp = 0
            if type(GetQuestLogRewardXP) == "function" then
                local s, v = pcall(GetQuestLogRewardXP, questInfo.questID)
                if s and v then xp = v end
            end
            local money = 0
            if type(GetQuestLogRewardMoney) == "function" then
                local s, v = pcall(GetQuestLogRewardMoney, questInfo.questID)
                if s and v then money = v end
            end
            if xp > 0 or money > 0 then
                textBlock1 = textBlock1 .. "|cFFFFFF00Rewards:|r\n"
                if xp > 0 then textBlock1 = textBlock1 .. xp .. " XP\n" end
                if money > 0 then textBlock1 = textBlock1 .. GetMoneyStringPlain(money) .. "\n" end
            end
            FlushText(textBlock1, 35)

            -- 2. Mandatory Item Rewards
            local numRewards = 0
            if type(GetNumQuestLogRewards) == "function" then
                local s, v = pcall(GetNumQuestLogRewards, questInfo.questID)
                if s and v then numRewards = v end
            end
            
            if numRewards > 0 then
                FlushText("|cFFFFFF00Item Rewards:|r", 35)
                for r = 1, numRewards do
                    local s, itemName, _, count = pcall(GetQuestLogRewardInfo, r, questInfo.questID)
                    if not s or not itemName then s, itemName, _, count = pcall(GetQuestLogRewardInfo, r) end
                    if itemName then
                        local link = GetItemLinkSafe("reward", r, questInfo.questID)
                        count = (count and count > 1) and (count.."x ") or ""
                        
                        local iBtn = GetOrCreateLine(lineIndex)
                        iBtn:ClearAllPoints()
                        iBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 45, yOffset)
                        iBtn.text:SetWidth(scrollFrame:GetWidth() - 55)
                        iBtn.text:SetFontObject("GameFontHighlightSmall")
                        iBtn.text:SetText("- " .. count .. (link or itemName))
                        
                        iBtn.bg:Show()
                        iBtn:SetScript("OnEnter", function(self)
                            self.bg:SetColorTexture(0.7, 0.7, 0.7, 0.4)
                            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                            if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetQuestLogItem("reward", r) end
                            GameTooltip:Show()
                        end)
                        iBtn:SetScript("OnLeave", function(self)
                            self.bg:SetColorTexture(0.5, 0.5, 0.5, 0.25)
                            GameTooltip:Hide() 
                        end)
                        
                        local h = iBtn.text:GetStringHeight()
                        iBtn:SetSize(scrollFrame:GetWidth() - 55, h + 4)
                        iBtn:Show()
                        yOffset = yOffset - (h + 6)
                        lineIndex = lineIndex + 1
                    end
                end
                yOffset = yOffset - 4
            end
            
            -- 3. Choice Item Rewards
            local numChoices = 0
            if type(GetNumQuestLogChoices) == "function" then
                local s, v = pcall(GetNumQuestLogChoices, questInfo.questID)
                if s and v then numChoices = v end
            end
            
            if numChoices > 0 then
                FlushText("|cFFFFFF00Choose One:|r", 35)
                for c = 1, numChoices do
                    local s, itemName, _, count = pcall(GetQuestLogChoiceInfo, c, questInfo.questID)
                    if not s or not itemName then s, itemName, _, count = pcall(GetQuestLogChoiceInfo, c) end
                    if itemName then
                        local link = GetItemLinkSafe("choice", c, questInfo.questID)
                        count = (count and count > 1) and (count.."x ") or ""
                        
                        local cBtn = GetOrCreateLine(lineIndex)
                        cBtn:ClearAllPoints()
                        cBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 45, yOffset)
                        cBtn.text:SetWidth(scrollFrame:GetWidth() - 55)
                        cBtn.text:SetFontObject("GameFontHighlightSmall")
                        cBtn.text:SetText("- " .. count .. (link or itemName))
                        
                        cBtn.bg:Show()
                        cBtn:SetScript("OnEnter", function(self)
                            self.bg:SetColorTexture(0.7, 0.7, 0.7, 0.4)
                            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                            if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetQuestLogItem("choice", c) end
                            GameTooltip:Show()
                        end)
                        cBtn:SetScript("OnLeave", function(self)
                            self.bg:SetColorTexture(0.5, 0.5, 0.5, 0.25)
                            GameTooltip:Hide() 
                        end)
                        
                        local h = cBtn.text:GetStringHeight()
                        cBtn:SetSize(scrollFrame:GetWidth() - 55, h + 4)
                        cBtn:Show()
                        yOffset = yOffset - (h + 6)
                        lineIndex = lineIndex + 1
                    end
                end
                yOffset = yOffset - 4
            end

            -- 4. Live Progress Block
            local objectives = C_QuestLog.GetQuestObjectives(questInfo.questID)
            if objectives and #objectives > 0 then
                local objText = "|cFFFFFF00Live Progress:|r\n"
                for _, obj in ipairs(objectives) do
                    local objColor = obj.finished and "|cFF808080" or "|cFFFFFFFF"
                    objText = objText .. objColor .. "• " .. (obj.text or "") .. "|r\n"
                end
                FlushText(objText, 35)
            end

            -- 5. Location Block (Map ID & Coords)
            local questMapID = type(QuestUtils_GetQuestMapID) == "function" and QuestUtils_GetQuestMapID(questInfo.questID) or nil
            
            local mapText = questMapID and tostring(questMapID) or "|cFF808080Unknown|r"
            local locText = "|cFFFFFF00Location:|r\nMap ID: " .. mapText
            local foundCoords = false
            
            if type(C_QuestLog.GetNextWaypoint) == "function" then
                local wp = C_QuestLog.GetNextWaypoint(questInfo.questID)
                if wp and wp.x and wp.y then
                    locText = locText .. string.format("\nWaypoint: %.1f, %.1f", wp.x * 100, wp.y * 100)
                    foundCoords = true
                end
            end
            
            if not foundCoords and type(C_QuestLog.GetQuestPOIs) == "function" and questMapID then
                local pois = C_QuestLog.GetQuestPOIs(questInfo.questID)
                if pois and #pois > 0 then
                    locText = locText .. "\nPOIs:"
                    for _, poi in ipairs(pois) do
                        if type(poi.GetXY) == "function" then
                            local x, y = poi:GetXY()
                            if x and y then
                                locText = locText .. string.format(" [%.1f, %.1f]", x * 100, y * 100)
                                foundCoords = true
                            end
                        end
                    end
                end
            end

            if not foundCoords then
                locText = locText .. "\nCoords: |cFF808080None found in client API.|r"
            end
            
            FlushText(locText .. "\n", 35)
        end
        yOffset = yOffset - 4
    end

    local focusedQuestID = nil
    if C_SuperTrack and type(C_SuperTrack.GetSuperTrackedQuestID) == "function" then
        focusedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
    elseif type(GetSuperTrackedQuestID) == "function" then
        focusedQuestID = GetSuperTrackedQuestID()
    end

    if focusedQuestID then
        local focusedQuestInfo = nil
        local focusedLogIndex = nil
        for i = 1, numEntries do
            local qInfo = C_QuestLog.GetInfo(i)
            if qInfo and not qInfo.isHidden and not qInfo.isHeader and qInfo.questID == focusedQuestID then
                focusedQuestInfo = qInfo
                focusedLogIndex = i
                break
            end
        end
        
        if focusedQuestInfo then
            local hBtn = GetOrCreateLine(lineIndex)
            hBtn:ClearAllPoints()
            hBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 5, yOffset)
            hBtn.text:SetWidth(scrollFrame:GetWidth() - 25)
            hBtn.text:SetFontObject("GameFontNormalLarge")
            hBtn.text:SetText("|cFFFFFFFF★ Focused Quest|r")
            local h = hBtn.text:GetStringHeight()
            hBtn:SetSize(scrollFrame:GetWidth() - 25, h + 4)
            hBtn:Show()
            yOffset = yOffset - (h + 8)
            lineIndex = lineIndex + 1

            RenderSingleQuest(focusedQuestInfo, focusedLogIndex)
        end
    end

    local currentHeaderTitle = nil
    local headerDrawn = false

    for i = 1, numEntries do
        local questInfo = C_QuestLog.GetInfo(i)
        
        if questInfo and not questInfo.isHidden then
            if questInfo.isHeader then
                currentHeaderTitle = questInfo.title
                headerDrawn = false
            else
                if questInfo.questID ~= focusedQuestID then
                    local isTracked = false
                    if type(C_QuestLog.GetQuestWatchType) == "function" then
                        isTracked = (C_QuestLog.GetQuestWatchType(questInfo.questID) ~= nil)
                    elseif type(IsQuestWatched) == "function" then
                        isTracked = IsQuestWatched(i)
                    end
                    
                    local isUntracked = not isTracked

                    if activeFilter == "All" or 
                       (activeFilter == "Tracked" and isTracked) or 
                       (activeFilter == "Untracked" and isUntracked) or 
                       (activeFilter == currentHeaderTitle) then
                        
                        if currentHeaderTitle and not headerDrawn then
                            local hBtn = GetOrCreateLine(lineIndex)
                            hBtn:ClearAllPoints()
                            hBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 5, yOffset)
                            hBtn.text:SetWidth(scrollFrame:GetWidth() - 25)
                            hBtn.text:SetFontObject("GameFontNormalLarge")
                            hBtn.text:SetText("|cFFFFFFFF" .. currentHeaderTitle .. "|r")
                            local h = hBtn.text:GetStringHeight()
                            hBtn:SetSize(scrollFrame:GetWidth() - 25, h + 4)
                            hBtn:Show()
                            
                            yOffset = yOffset - (h + 8)
                            lineIndex = lineIndex + 1
                            headerDrawn = true
                        end

                        RenderSingleQuest(questInfo, i)
                    end
                end
            end
        end
    end

    content:SetHeight(math.abs(yOffset) + 10)
end

-- =========================================================================
-- 6. Events & Keybinds
-- =========================================================================
f:SetScript("OnShow", _G.UpdateQuestList)
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("SUPER_TRACKING_CHANGED")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:SetScript("OnEvent", function(self, event) _G.UpdateQuestList() end)

tinsert(UISpecialFrames, f:GetName())
f:Hide()

local function ToggleT3Window()
    if f:IsShown() then f:Hide() else f:Show() end
end

SLASH_T3_CMD1 = "/t3"
SlashCmdList["T3_CMD"] = ToggleT3Window

local toggleBtn = CreateFrame("Button", "T3_KeybindButton", UIParent, "SecureActionButtonTemplate")
toggleBtn:SetAttribute("type", "macro")
toggleBtn:SetAttribute("macrotext", "/t3")
toggleBtn:SetScript("OnClick", ToggleT3Window)

local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    SetBindingClick("CTRL-NUMPAD3", "T3_KeybindButton")
    SaveBindings(GetCurrentBindingSet())
end)
    -- NEW: Skip auto-zooming completely if we are on a city map!
    local MY_CUSTOM_WORLD_MAP_ID = 947
    if f.currentMapID ~= MY_CUSTOM_WORLD_MAP_ID then
        return
    end

    -- 1. Grab Player coordinates (computed by your playerArrowTracker)
    local pX = f.playerArrow and f.playerArrow.pX
    local pY = f.playerArrow and f.playerArrow.pY

    -- 2. Grab the latest Pin coordinates
    local pinX, pinY = nil, nil
    if f.customPins and #f.customPins > 0 then
        local pinData = f.customPins[#f.customPins] -- Get the most recently added pin

        local MY_CUSTOM_WORLD_MAP_ID = 947
        if f.currentMapID == MY_CUSTOM_WORLD_MAP_ID then
            if T1_ZoneDB and T1_ZoneDB[pinData.mapID] then
                local zData = T1_ZoneDB[pinData.mapID]
                if zData.x and zData.w and zData.y and zData.h then
                    pinX = zData.x + ((pinData.x - 0.5) * zData.w)
                    pinY = zData.y + ((pinData.y - 0.5) * zData.h)
                end
            end
        elseif f.currentMapID == pinData.mapID then
            -- Fallback if looking at a local regional map instead of the global map
            pinX = pinData.x
            pinY = pinData.y
        end
    end

    -- 3. Determine the Bounding Box
    local minX, maxX, minY, maxY
    if pX and pY and pinX and pinY then
        minX = math.min(pX, pinX)
        maxX = math.max(pX, pinX)
        minY = math.min(pY, pinY)
        maxY = math.max(pY, pinY)
    elseif pinX and pinY then
        -- Only pin exists (player is off-map or hidden)
        minX, maxX = pinX, pinX
        minY, maxY = pinY, pinY
    elseif pX and pY then
        -- Only player exists (no pins)
        minX, maxX = pX, pX
        minY, maxY = pY, pY
    else
        return -- Nothing to frame!
    end

    -- 4. Calculate Distance and Required Zoom
    local boxW = maxX - minX
    local boxH = maxY - minY

    -- Add 20% padding around the edges so the icons aren't touching the window border
    local PADDING = 0.20
    boxW = math.max(boxW + (PADDING * 2), 0.15) -- Enforce a minimum zoom limit
    boxH = math.max(boxH + (PADDING * 2), 0.15)

    -- Calculate the highest zoom level that fits both width and height
    local zoomW = 1 / boxW
    local zoomH = 1 / boxH
    local targetZoom = math.min(zoomW, zoomH)

    if targetZoom < 1 then targetZoom = 1 end
    if targetZoom > 10 then targetZoom = 10 end

    -- 5. Calculate Center Point to Pan To
    local centerX = (minX + maxX) / 2
    local centerY = (minY + maxY) / 2

    local canvasW, canvasH = self.mapCanvas:GetSize()
    local contentW, contentH = self.mapContent:GetSize()

    if canvasW and canvasH and contentW and contentH then
        local exactPixelX = centerX * contentW
        local exactPixelY = -centerY * contentH

        -- Apply the visual offsets using the new zoom level
        local visualOffsetX = (canvasW / 2) - (exactPixelX * targetZoom)
        local visualOffsetY = -(canvasH / 2) - (exactPixelY * targetZoom)

        self.zoomLevel = targetZoom
        self.mapOffsetX = visualOffsetX / targetZoom
        self.mapOffsetY = visualOffsetY / targetZoom

        if self.UpdateMapTransform then self:UpdateMapTransform() end
    end
end

-- ==========================================
-- RENDER CUSTOM MAP PINS (Global & Regional)
-- ==========================================
local MY_CUSTOM_WORLD_MAP_ID = 947
if not f.pinFrames then f.pinFrames = {} end
if not f.customPins then f.customPins = {} end

-- Loop through whichever is larger: the number of active pins, or frames created
local maxIndex = math.max(#f.customPins, #f.pinFrames)

for i = 1, maxIndex do
    local pinData = f.customPins[i]
    local frame = f.pinFrames[i]

    -- 1. Create frames safely without rotation math
    if pinData and not frame then
        frame = CreateFrame("Frame", nil, self.mapContent)
        frame:SetFrameLevel(self.mapContent:GetFrameLevel() + 60)

        local tex = frame:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        -- Bulletproof fallback: A built-in Star Icon instead of a rotated color block!
        tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")

        frame.tex = tex
        f.pinFrames[i] = frame
    end

    -- 2. Position and Scale Active Pins
    if pinData and frame then
        -- Tint the Star with the colors passed from T2
        frame.tex:SetVertexColor(pinData.r, pinData.g, pinData.b, 1)

        local showPin = false
        local drawX, drawY = 0, 0

        -- RULE 1: Are we looking at the SMALL REGIONAL MAP?
        if f.currentMapID == pinData.mapID then
            drawX = pinData.x
            drawY = pinData.y
            showPin = true

            -- RULE 2: Are we looking at the GLOBAL WORLD MAP?
        elseif f.currentMapID == MY_CUSTOM_WORLD_MAP_ID then
            if T1_ZoneDB and T1_ZoneDB[pinData.mapID] then
                local zData = T1_ZoneDB[pinData.mapID]
                if zData.x and zData.w and zData.y and zData.h then
                    -- Translate local to global math
                    drawX = zData.x + ((pinData.x - 0.5) * zData.w)
                    drawY = zData.y + ((pinData.y - 0.5) * zData.h)
                    showPin = true
                end
            end
        end

        -- Display the pin safely
        if showPin then
            frame:Show()
            local baseSize = 24 -- Made it 24x24 so it is impossible to miss!
            frame:SetSize(baseSize / self.zoomLevel, baseSize / self.zoomLevel)

            frame:ClearAllPoints()
            frame:SetPoint("CENTER", self.mapContent, "TOPLEFT", drawX * contentW, -drawY * contentH)
        else
            frame:Hide()
        end

        -- 3. Hide leftover frames if wiped
    elseif frame then
        frame:Hide()
    end
end

-- ==========================================
-- GLOBAL EXPOSED API: MAP PINS
-- ==========================================
f.customPins = {}

-- Usage 1: Clears all existing pins and sets exactly ONE new pin (Best for T2 row clicks)
_G.func_T1_SetPin = function(mapID, localX, localY, r, g, b)
    _G.func_T1_ClearPins()
    _G.func_T1_AddPin(mapID, localX, localY, r, g, b)
end

-- Usage 2: Adds a pin to the map WITHOUT clearing old ones
_G.func_T1_AddPin = function(mapID, localX, localY, r, g, b)
    -- SMART NORMALIZE: Convert 0-100 coordinates into 0.0-1.0 math coordinates!
    if localX and localX > 1 then localX = localX / 100 end
    if localY and localY > 1 then localY = localY / 100 end

    -- ==========================================
    -- DEBUG LOGGING: Test the Global Math!
    -- ==========================================
    if T1_ZoneDB and T1_ZoneDB[mapID] then
        local zData = T1_ZoneDB[mapID]
        if zData.x and zData.w and zData.y and zData.h then
            local globalX = zData.x + ((localX - 0.5) * zData.w)
            local globalY = zData.y + ((localY - 0.5) * zData.h)

            -- CHANGED: Multiply localX and localY by 100 just for the print readout!
            print(string.format("|cff00ff00T1_TrackMap DEBUG:|r MapID: %s | Local: (%.1f, %.1f) -> Global: (%.4f, %.4f)",
                tostring(mapID), localX * 100, localY * 100, globalX, globalY))
       
        end
    else
        print(string.format(
            "|cFFFF0000T1_TrackMap ERROR:|r MapID %s is NOT in T1_ZoneDB! The map cannot translate this pin.",
            tostring(mapID)))
    end
    -- ==========================================

    -- Default to a bright cyan rhombus if no RGB color is provided
    table.insert(f.customPins, {
        mapID = mapID,
        x = localX,
        y = localY,
        r = r or 0,
        g = g or 1,
        b = b or 1
    })

    -- NEW: Instead of just updating the transform, trigger the auto-zoom framing!
    if f:IsShown() and f.ZoomFitPlayerAndPin then
        f:ZoomFitPlayerAndPin()
    end
end



-- Usage 3: Wipes all pins off the map
_G.func_T1_ClearPins = function()
    wipe(f.customPins)
    if f:IsShown() and f.UpdateMapTransform then
        f:UpdateMapTransform()
    end
end


-- ==========================================
-- Visibility, Keybindings & Initialization
-- ==========================================
tinsert(UISpecialFrames, f:GetName())
f:Hide()

-- ==========================================
-- GLOBAL EXPOSED TOGGLE API
-- ==========================================
_G.func_ToggleT1Window = function(mapID)
    -- If a specific mapID is passed from another addon, load it!
    if mapID and type(mapID) == "number" then
        f:LoadMap(mapID)
        if f.UpdateMapTransform then f:UpdateMapTransform() end
        if f.RefreshPOIs then f:RefreshPOIs() end
        f:Show()
    else
        -- Otherwise, just act as a standard toggle
        if f:IsShown() then
            f:Hide()
        else
            f:Show()
        end
    end
end

-- Slash Commands
SLASH_T1_CMD1 = "/t1"
SlashCmdList["T1_CMD"] = function() _G.func_ToggleT1Window() end

-- Keybindings
local toggleBtn = CreateFrame("Button", "T1_KeybindButton", UIParent, "SecureActionButtonTemplate")
toggleBtn:SetAttribute("type", "macro")
toggleBtn:SetAttribute("macrotext", "/t1")
toggleBtn:SetScript("OnClick", function() _G.func_ToggleT1Window() end)

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
        local MY_CUSTOM_WORLD_MAP_ID = 947
        self:LoadMap(MY_CUSTOM_WORLD_MAP_ID)
        self.currentMapLoaded = true
    end
    if self.UpdateMapTransform then self:UpdateMapTransform() end
end)

print("|cFF00FF00t1_TrackMap UI Built! Type /t1 or Ctrl+Numpad 1|r")




print("|cFF00FF00t1_TrackMap UI Built! Type /t1 or Ctrl+Numpad 1|r")
