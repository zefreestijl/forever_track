-- ==========================================
-- 1. Create the Main Frame
-- ==========================================
local f = CreateFrame("Frame", "t1_TrackMap", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(916, 640)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

f:SetResizable(true)
if f.SetResizeBounds then
    f:SetResizeBounds(376, 280, 1216, 840)
else
    f:SetMinResize(376, 280)
    f:SetMaxResize(1216, 840)
end

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f, "TOP", 0, -6)
f.title:SetText("t1_TrackMap")

f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

-- ==========================================
-- 2. Map Canvas & Content
-- ==========================================
f.mapCanvas = CreateFrame("Frame", "$parentMapCanvas", f)
f.mapCanvas:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -28)
f.mapCanvas:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
f.mapCanvas:SetClipsChildren(true)

f.mapContent = CreateFrame("Frame", nil, f.mapCanvas)
f.mapContent:SetPoint("TOPLEFT", f.mapCanvas, "TOPLEFT", 0, 0)
f.mapContent:SetSize(900, 600)

-- ==========================================
-- 3. Buttons & Grips
-- ==========================================
local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
collapseBtn:SetText("_")

local isCollapsed = false
collapseBtn:SetScript("OnClick", function()
    if isCollapsed then
        f:SetHeight(f.expandedHeight or 640)
        if f.Bg then f.Bg:Show() end
        if f.InsetBg then f.InsetBg:Show() end
        if f.mapCanvas then f.mapCanvas:Show() end
        collapseBtn:SetText("_")
        isCollapsed = false
    else
        f.expandedHeight = f:GetHeight()
        f:SetHeight(32)
        if f.Bg then f.Bg:Hide() end
        if f.InsetBg then f.InsetBg:Hide() end
        if f.mapCanvas then f.mapCanvas:Hide() end
        collapseBtn:SetText("+")
        isCollapsed = true
    end
end)

-- ==========================================
-- Map Toggle & Return Button (Top Left)
-- ==========================================
f.isDetailedMap = false
f.MapToggleButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.MapToggleButton:SetSize(130, 20)
-- Anchor it slightly to the right so it doesn't overlap the UI portrait/title
f.MapToggleButton:SetPoint("TOPLEFT", f, "TOPLEFT", 5, 0)
f.MapToggleButton:SetText("Show Detailed Map")

f.MapToggleButton:SetScript("OnClick", function()
    local MY_CUSTOM_WORLD_MAP_ID = 947

    if f.currentMapID ~= MY_CUSTOM_WORLD_MAP_ID then
        -- 1. If we are in a city, "Return" to the world map and reset the zoom
        f.zoomLevel = 1
        f.mapOffsetX = 0
        f.mapOffsetY = 0
        f:LoadMap(MY_CUSTOM_WORLD_MAP_ID)
    else
        -- 2. If we are on the world map, toggle the texture
        f.isDetailedMap = not f.isDetailedMap
        f:LoadMap(MY_CUSTOM_WORLD_MAP_ID)
    end

    if f.UpdateMapTransform then f:UpdateMapTransform() end
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
        if f.playerArrow and f.playerArrow:IsShown() and f.playerArrow.pX and f.playerArrow.pY then
            local exactPixelX = f.playerArrow.pX * contentW
            local exactPixelY = -f.playerArrow.pY * contentH
            local visualOffsetX = (canvasW / 2) - (exactPixelX * newZoom)
            local visualOffsetY = -(canvasH / 2) - (exactPixelY * newZoom)
            f.mapOffsetX = visualOffsetX / newZoom
            f.mapOffsetY = visualOffsetY / newZoom
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
-- Live Zoom Scale Display & Mist Toggle
-- ==========================================
f.zoomUI = CreateFrame("Frame", nil, f)
f.zoomUI:SetAllPoints(f.mapCanvas)
f.zoomUI:SetFrameStrata("HIGH")

f.zoomText = f.zoomUI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
f.zoomText:SetPoint("TOPLEFT", f.zoomUI, "TOPLEFT", 5, -5)
f.zoomText:SetJustifyH("LEFT")
f.zoomText:SetText("Scale: 1.00x")

f.showFogOfWar = true
f.mistToggle = CreateFrame("CheckButton", nil, f.zoomUI, "UICheckButtonTemplate")
f.mistToggle:SetSize(24, 24)
f.mistToggle:SetPoint("TOPRIGHT", f.zoomUI, "TOPRIGHT", -75, -5)
f.mistToggle:SetChecked(f.showFogOfWar)
f.mistToggle:SetAlpha(0.5) -- Grey out the toggle so it looks inactive

f.mistToggle.text = f.mistToggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
f.mistToggle.text:SetPoint("LEFT", f.mistToggle, "RIGHT", 4, 0)
f.mistToggle.text:SetText("Mist Maps")
f.mistToggle.text:SetTextColor(0.6, 0.6, 0.6) -- Dim the text

-- Expand the button's invisible clickable area to the right so it covers the text
local textWidth = f.mistToggle.text:GetStringWidth() or 60
f.mistToggle:SetHitRectInsets(0, -(textWidth + 10), 0, 0)

f.mistToggle:SetScript("OnClick", function(self)
    f.showFogOfWar = self:GetChecked()
    if f.RefreshFogOfWar then f:RefreshFogOfWar() end
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
    if f.currentMapID then f:LoadMap(f.currentMapID) end
    if f.UpdateMapTransform then f:UpdateMapTransform() end
end)

local MAP_ASPECT_RATIO = 1.5

f.ResizeGrip:SetScript("OnUpdate", function(self)
    if self.isResizing then
        local cX, _ = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local dx = (cX - self.startX) / scale
        local newWidth = self.startW + dx

        if newWidth < 376 then newWidth = 376 end
        if newWidth > 1216 then newWidth = 1216 end

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
-- Map Panning & Click Detection
-- ==========================================
f.mapCanvas:EnableMouse(true)
f.mapCanvas:SetScript("OnMouseDown", function(self, button)
    self.startX, self.startY = GetCursorPosition()
    self.startOffsetX = f.mapOffsetX or 0
    self.startOffsetY = f.mapOffsetY or 0
    if button == "LeftButton" then self.isDragging = true end
end)

f.mapCanvas:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then self.isDragging = false end
    if not self.startX or not self.startY then return end

    local cX, cY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local dragDistance = (math.abs(cX - self.startX) + math.abs(cY - self.startY)) / scale
    local MY_CUSTOM_WORLD_MAP_ID = 947

    if dragDistance < 25 then
        if button == "RightButton" then
            local targetMapID = (f.currentMapID == MY_CUSTOM_WORLD_MAP_ID) and self.hoveredMapID or f.currentMapID
            if _G.func_ToggleT2Window then
                _G.func_ToggleT2Window(targetMapID)
            else
                print("|cffff2020T1_TrackMap:|r T2_TrackNPC addon is not loaded.")
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
        elseif button == "LeftButton" and f.currentMapID == MY_CUSTOM_WORLD_MAP_ID then
            local rawX, rawY = GetCursorPosition()
            local mapScale = f.mapContent:GetEffectiveScale()
            local left = f.mapContent:GetLeft()
            local top = f.mapContent:GetTop()

            if left and top then
                local pctX = ((rawX / mapScale) - left) / f.mapContent:GetWidth()
                local pctY = (top - (rawY / mapScale)) / f.mapContent:GetHeight()
                local CLICK_RADIUS_SQ = 0.0005 / (f.zoomLevel * f.zoomLevel)

                for _, data in pairs(cityDataByZone) do
                    if data.x and data.y then
                        local dx = data.x - pctX
                        local dy = data.y - pctY
                        if (dx * dx) + (dy * dy) <= CLICK_RADIUS_SQ then
                            f.zoomLevel = 1
                            f.mapOffsetX = 0
                            f.mapOffsetY = 0
                            f:LoadMap(data.id)
                            if f.UpdateMapTransform then f:UpdateMapTransform() end
                            break
                        end
                    end
                end
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
    if self.isDragging then
        local cX, cY = GetCursorPosition()
        local uiScale = UIParent:GetEffectiveScale()
        local dx = (cX - self.startX) / uiScale
        local dy = (cY - self.startY) / uiScale
        f.mapOffsetX = self.startOffsetX + (dx / f.zoomLevel)
        f.mapOffsetY = self.startOffsetY + (dy / f.zoomLevel)
        f:UpdateMapTransform()
    end

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
                local closestZone, closestComment, closestID = "Unknown Area", "", "0"
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
                    closestZone, closestComment, closestID = "Great Sea", "", "???"
                    hoverLocalX, hoverLocalY = 0, 0
                end

                self.hoveredZone = closestZone
                self.hoveredMapID = (closestID ~= "???") and tonumber(closestID) or nil

                local colorCode = "|cffffffff"
                local isCity = false

                if cityDataByZone[closestZone] then
                    isCity = true
                    if cityDataByZone[closestZone].status == "Alliance" then
                        colorCode = "|cff0044cc"
                    elseif cityDataByZone[closestZone].status == "Horde" then
                        colorCode = "|cffff2020"
                    end
                end

                if not self.isDragging then ResetCursor() end

                local headerText = (closestID == "???") and "|cffaaaaaa#???|r" or
                    string.format("|cffaaaaaa#%s (%.0f, %.0f)|r", closestID, hoverLocalX * 100, hoverLocalY * 100)

                if closestComment ~= "" then
                    f.cursorTooltip.text:SetFormattedText("%s\n%s%s\n%s\n%.3f, %.3f|r", headerText, colorCode,
                        closestZone:upper(), closestComment, pctX, pctY)
                else
                    f.cursorTooltip.text:SetFormattedText("%s\n%s%s\n%.3f, %.3f|r", headerText, colorCode,
                        closestZone:upper(), pctX, pctY)
                end

                -- NEW: Dynamically swap the font size based on whether it is a city!
                if isCity then
                    f.cursorTooltip.text:SetFontObject("GameFontHighlight") -- ~1.1x bigger for readability
                else
                    f.cursorTooltip.text:SetFontObject("SystemFont_Tiny")   -- Compact for regular zones/sea
                end

                -- Wrap the invisible frame tightly to the newly sized text
                f.cursorTooltip:SetSize(f.cursorTooltip.text:GetStringWidth(), f.cursorTooltip.text:GetStringHeight())

                local uiScale = f.cursorTooltip:GetEffectiveScale()
                local cursorX = rawX / uiScale
                local cursorY = rawY / uiScale

                local anchorPoint = ""
                local offsetX = 0
                local offsetY = 0

                -- 1. Vertical Check (pctY: 0 is top, 1 is bottom)
                if pctY > 0.5 then
                    anchorPoint = "BOTTOM"
                    offsetY = 15
                else
                    anchorPoint = "TOP"
                    offsetY = -15
                end

                -- 2. Horizontal Check (pctX: 0 is left, 1 is right)
                if pctX > 0.5 then
                    anchorPoint = anchorPoint .. "RIGHT"
                    offsetX = -15
                    f.cursorTooltip.text:SetJustifyH("RIGHT")
                else
                    anchorPoint = anchorPoint .. "LEFT"
                    offsetX = 15
                    f.cursorTooltip.text:SetJustifyH("LEFT")
                end

                f.cursorTooltip:ClearAllPoints()
                f.cursorTooltip:SetPoint(anchorPoint, UIParent, "BOTTOMLEFT", cursorX + offsetX, cursorY + offsetY)
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
-- Map Loading & Fog of War Rendering
-- ==========================================

f.mapTiles = {}
function f:LoadMap(mapID)
    f.currentMapID = mapID
    for _, tile in ipairs(f.mapTiles) do tile:Hide() end
    wipe(f.mapTiles)

    -- SMART BUTTON TEXT: Update the button label based on where we are
    if f.MapToggleButton then
        if mapID == 947 then
            if f.isDetailedMap then
                f.MapToggleButton:SetText("Show Blank Map")
            else
                f.MapToggleButton:SetText("Show Detailed Map")
            end
        else
            f.MapToggleButton:SetText("Return")
        end
    end

    if mapID == 947 then
        local customTile = f.mapContent:CreateTexture(nil, "BACKGROUND")
        customTile:SetAllPoints(f.mapContent)
        
        -- Swap between your two custom backgrounds
        if f.isDetailedMap then
            customTile:SetTexture("Interface\\AddOns\\t1_TrackMap\\map_texture\\world map-detailed.tga")
        else
            customTile:SetTexture("Interface\\AddOns\\t1_TrackMap\\map_texture\\world map-blank.tga")
        end
        
        table.insert(f.mapTiles, customTile)
    else
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

    if f.RefreshFogOfWar then f:RefreshFogOfWar() end
end


if not f.exploredTexturePool then
    f.exploredTexturePool = CreateTexturePool(f.mapContent, "ARTWORK")
end

function f:DrawExploredZone(zoneID)
    if not T1_ZoneDB or not T1_ZoneDB[zoneID] then return end
    local zData = T1_ZoneDB[zoneID]
    if not zData.x or not zData.y or not zData.w or not zData.h then return end

    local artID = C_Map.GetMapArtID(zoneID)
    if not artID then return end
    local layers = C_Map.GetMapArtLayers(artID)
    if not layers or not layers[1] then return end

    local exploredTextures = C_MapExplorationInfo.GetExploredMapTextures(zoneID)
    if not exploredTextures then return end

    local zonePixelX = zData.x * f.mapContent:GetWidth()
    local zonePixelY = -zData.y * f.mapContent:GetHeight()
    local zonePixelW = zData.w * f.mapContent:GetWidth()
    local zonePixelH = zData.h * f.mapContent:GetHeight()

    for _, expInfo in ipairs(exploredTextures) do
        if expInfo.fileDataIDs and expInfo.fileDataIDs[1] then
            local tex = f.exploredTexturePool:Acquire()
            tex:SetTexture(expInfo.fileDataIDs[1])
            local pctX = expInfo.offsetX / layers[1].layerWidth
            local pctY = expInfo.offsetY / layers[1].layerHeight
            local pctW = expInfo.textureWidth / layers[1].layerWidth
            local pctH = expInfo.textureHeight / layers[1].layerHeight

            tex:SetSize(pctW * zonePixelW, pctH * zonePixelH)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", f.mapContent, "TOPLEFT", zonePixelX + (pctX * zonePixelW),
                zonePixelY - (pctY * zonePixelH))
            tex:Show()
        end
    end
end

function f:RefreshFogOfWar()
    if f.exploredTexturePool then f.exploredTexturePool:ReleaseAll() end
    if not f.showFogOfWar then return end

    if f.currentMapID == 947 then
        if T1_ZoneDB then
            for zoneID, _ in pairs(T1_ZoneDB) do f:DrawExploredZone(zoneID) end
        end
    else
        f:DrawExploredZone(f.currentMapID)
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

    local canvasW, canvasH = self.mapCanvas:GetSize()
    local contentW, contentH = self.mapContent:GetSize()
    if not canvasW or canvasW <= 0 or not contentW or contentW <= 0 then return end

    local minZoomW = canvasW / contentW
    local minZoomH = canvasH / contentH
    local absoluteMinZoom = math.max(minZoomW, minZoomH)

    if self.zoomLevel < absoluteMinZoom then self.zoomLevel = absoluteMinZoom end
    if self.zoomLevel > 10 then self.zoomLevel = 10 end
    self.mapContent:SetScale(self.zoomLevel)

    local effW = contentW * self.zoomLevel
    local effH = contentH * self.zoomLevel

    local visualMaxX = 0
    local visualMinX = canvasW - effW
    local visualMinY = 0
    local visualMaxY = effH - canvasH

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
    if f.zoomSlider then
        f.zoomSlider.isUpdating = true
        f.zoomSlider:SetValue(self.zoomLevel)
        f.zoomSlider.isUpdating = false
    end

    local MY_CUSTOM_WORLD_MAP_ID = 947
    if f.currentMapID == MY_CUSTOM_WORLD_MAP_ID then
        if not f.cityFlags then
            f.cityFlags = {}
            for key, data in pairs(cityDataByZone) do
                local flagFrame = CreateFrame("Frame", nil, self.mapContent)
                flagFrame:SetFrameLevel(self.mapContent:GetFrameLevel() + 50)
                local tex = flagFrame:CreateTexture(nil, "BACKGROUND")
                tex:SetAllPoints()
                tex:SetTexture(data.status == "Alliance" and "Interface\\TargetingFrame\\UI-PVP-Alliance" or
                    "Interface\\TargetingFrame\\UI-PVP-Horde")
                tex:SetTexCoord(10 / 64, 54 / 64, 10 / 64, 54 / 64)
                f.cityFlags[key] = {
                    frame = flagFrame,
                    tex = tex,
                    x = data.x or 0,
                    y = data.y or 0,
                    status = data
                        .status
                }
            end
        end

        local playerMap = C_Map.GetBestMapForUnit("player")
        local playerInCityID = nil
        for key, data in pairs(cityDataByZone) do
            if data.id == playerMap then
                playerInCityID = playerMap; break
            end
        end

        -- 3. Render and Counter-Scale
        for key, flagObj in pairs(f.cityFlags) do
            flagObj.frame:Show()

            if playerInCityID and cityDataByZone[key].id ~= playerInCityID then
                flagObj.baseOpacity = 0.3
            else
                flagObj.baseOpacity = 1.0
            end

            flagObj.tex:SetDesaturated(false)
            flagObj.tex:SetVertexColor(1, 1, 1, flagObj.baseOpacity)

            -- NEW: Stretch Alliance flags to 1.2x width!
            local baseWidth = 24
            local baseHeight = 24
            if cityDataByZone[key] and cityDataByZone[key].status == "Alliance" then
                baseWidth = baseWidth * 1.2
            end

            flagObj.frame:SetSize(baseWidth / self.zoomLevel, baseHeight / self.zoomLevel)
            flagObj.frame:ClearAllPoints()
            flagObj.frame:SetPoint("CENTER", self.mapContent, "TOPLEFT", flagObj.x * contentW, -flagObj.y * contentH)
        end
    else
        if f.cityFlags then
            for key, flagObj in pairs(f.cityFlags) do flagObj.frame:Hide() end
        end
    end

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
            local showPin, drawX, drawY = false, 0, 0
            if f.currentMapID == pinData.mapID then
                drawX, drawY, showPin = pinData.x, pinData.y, true
            elseif f.currentMapID == MY_CUSTOM_WORLD_MAP_ID then
                if T1_ZoneDB and T1_ZoneDB[pinData.mapID] then
                    local zData = T1_ZoneDB[pinData.mapID]
                    if zData.x and zData.w and zData.y and zData.h then
                        drawX, drawY, showPin = zData.x + ((pinData.x - 0.5) * zData.w),
                            zData.y + ((pinData.y - 0.5) * zData.h), true
                    end
                end
            end
            if showPin then
                frame:Show()
                frame:SetSize(24 / self.zoomLevel, 24 / self.zoomLevel)
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
    local mouseX = (cX / uiScale) - self:GetLeft()
    local mouseY = (cY / uiScale) - self:GetTop()

    f.mapOffsetX = f.mapOffsetX + mouseX * ((1 / newZoom) - (1 / oldZoom))
    f.mapOffsetY = f.mapOffsetY + mouseY * ((1 / newZoom) - (1 / oldZoom))
    f.zoomLevel = newZoom
    f:UpdateMapTransform()
end)

-- ==========================================
-- Auto-Frame Logic
-- ==========================================
function f:ZoomToPoint(pctX, pctY, targetZoom)
    if not pctX or not pctY then return end
    targetZoom = targetZoom or 5
    if targetZoom < 1 then targetZoom = 1 end
    if targetZoom > 10 then targetZoom = 10 end

    local canvasW, canvasH = self.mapCanvas:GetSize()
    local contentW, contentH = self.mapContent:GetSize()
    if canvasW and canvasH and contentW and contentH then
        local exactPixelX = pctX * contentW
        local exactPixelY = -pctY * contentH
        self.zoomLevel = targetZoom
        self.mapOffsetX = ((canvasW / 2) - (exactPixelX * targetZoom)) / targetZoom
        self.mapOffsetY = (-(canvasH / 2) - (exactPixelY * targetZoom)) / targetZoom
        if self.UpdateMapTransform then self:UpdateMapTransform() end
    end
end

function f:ZoomToZone(zoneID)
    if f.currentMapID ~= 947 or not zoneID then return end
    if T1_ZoneDB and T1_ZoneDB[zoneID] then
        local zData = T1_ZoneDB[zoneID]
        if zData.x and zData.y and zData.w and zData.h then
            local boxW = math.max(zData.w * 1.3, 0.10)
            local boxH = math.max(zData.h * 1.3, 0.10)
            f:ZoomToPoint(zData.x, zData.y, math.min(1 / boxW, 1 / boxH))
        end
    end
end


function f:ZoomFitPlayerAndPin()
    if f.currentMapID ~= 947 then return end
    
    local pX = f.playerArrow and f.playerArrow.pX
    local pY = f.playerArrow and f.playerArrow.pY
    local pinX, pinY = nil, nil

    if f.customPins and #f.customPins > 0 then
        local pinData = f.customPins[#f.customPins]
        
        -- FIX 1: Support pins that are placed directly on the world map!
        if pinData.mapID == 947 then
            pinX = pinData.x
            pinY = pinData.y
        elseif T1_ZoneDB and T1_ZoneDB[pinData.mapID] then
            local zData = T1_ZoneDB[pinData.mapID]
            if zData.x and zData.w and zData.y and zData.h then
                pinX = zData.x + ((pinData.x - 0.5) * zData.w)
                pinY = zData.y + ((pinData.y - 0.5) * zData.h)
            end
        end
    end

    local minX, maxX, minY, maxY
    if pX and pY and pinX and pinY then
        minX, maxX = math.min(pX, pinX), math.max(pX, pinX)
        minY, maxY = math.min(pY, pinY), math.max(pY, pinY)
    elseif pinX and pinY then
        minX, maxX, minY, maxY = pinX, pinX, pinY, pinY
    elseif pX and pY then
        minX, maxX, minY, maxY = pX, pX, pY, pY
    else
        return
    end

    -- FIX 2: Dynamic padding instead of a massive flat buffer
    local distW = maxX - minX
    local distH = maxY - minY
    
    -- Multiply distance by 1.5 to leave clean screen margins around the icons.
    -- Enforce a 0.10 minimum so the camera doesn't attempt to zoom to infinity if distance is 0.
    local boxW = math.max(distW * 1.5, 0.10)
    local boxH = math.max(distH * 1.5, 0.10)
    
    local targetZoom = math.min(1 / boxW, 1 / boxH)
    
    f:ZoomToPoint((minX + maxX) / 2, (minY + maxY) / 2, targetZoom)
end

-- ==========================================
-- Exposed Map APIs
-- ==========================================
f.customPins = {}
_G.func_T1_SetPin = function(mapID, localX, localY, r, g, b)
    _G.func_T1_ClearPins()
    _G.func_T1_AddPin(mapID, localX, localY, r, g, b)
end

_G.func_T1_AddPin = function(mapID, localX, localY, r, g, b)
    if localX and localX > 1 then localX = localX / 100 end
    if localY and localY > 1 then localY = localY / 100 end

    local capitalCities = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
    if capitalCities[mapID] then
        print(string.format("|cff00ff00T1_TrackMap DEBUG:|r City Pin - MapID: %s | Local: (%.1f, %.1f)", mapID,
            localX * 100, localY * 100))
    end
    
    -- 1. Add to your custom global map
    table.insert(f.customPins, { mapID = mapID, x = localX, y = localY, r = r or 0, g = g or 1, b = b or 1 })
    
    if f:IsShown() and f.UpdateMapTransform then f:UpdateMapTransform() end
    if f:IsShown() and f.ZoomFitPlayerAndPin then f:ZoomFitPlayerAndPin() end

    -- 2. NEW: Push the exact same coordinates to the built-in Blizzard Minimap!
    if C_Map.CanSetUserWaypointOnMap(mapID) then
        local uiMapPoint = UiMapPoint.CreateFromCoordinates(mapID, localX, localY)
        C_Map.SetUserWaypoint(uiMapPoint)
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
end

_G.func_T1_ClearPins = function()
    -- 1. Clear custom map pins
    wipe(f.customPins)
    if f:IsShown() and f.UpdateMapTransform then f:UpdateMapTransform() end
    
    -- 2. NEW: Clear the built-in Blizzard Minimap waypoint
    if C_Map.HasUserWaypoint() then
        C_Map.ClearUserWaypoint()
    end
end


-- ==========================================
-- Live Trackers
-- ==========================================
f.playerArrow = f.mapContent:CreateTexture(nil, "OVERLAY")
f.playerArrow:SetTexture("Interface\\Minimap\\MinimapArrow")
f.playerArrow:SetDrawLayer("OVERLAY", 7)
f.playerArrowTracker = CreateFrame("Frame", nil, f.mapCanvas)
f.playerArrowTracker:SetScript("OnUpdate", function()
    local hasValidData, pX, pY = false, 0, 0
    local currentZoneID = C_Map.GetBestMapForUnit("player")
    if currentZoneID then
        local pos = C_Map.GetPlayerMapPosition(currentZoneID, "player")
        if pos and pos.x and pos.y then
            if f.currentMapID == 947 then
                if T1_ZoneDB and T1_ZoneDB[currentZoneID] then
                    local zoneData = T1_ZoneDB[currentZoneID]
                    if zoneData.x and zoneData.y and zoneData.w and zoneData.h then
                        pX, pY, hasValidData = zoneData.x + ((pos.x - 0.5) * zoneData.w),
                            zoneData.y + ((pos.y - 0.5) * zoneData.h), true
                    end
                end
            elseif f.currentMapID == currentZoneID then
                pX, pY, hasValidData = pos.x, pos.y, true
            end
        end
    end
    if hasValidData then
        f.playerArrow:Show()
        f.playerArrow:SetSize(32 / f.zoomLevel, 32 / f.zoomLevel)
        local facing = GetPlayerFacing()
        if facing then f.playerArrow:SetRotation(facing) end
        f.playerArrow.pX, f.playerArrow.pY = pX, pY
        f.playerArrow:SetPoint("CENTER", f.mapContent, "TOPLEFT", pX * f.mapContent:GetWidth(),
            -pY * f.mapContent:GetHeight())
    else
        f.playerArrow:Hide()
        f.playerArrow.pX, f.playerArrow.pY = nil, nil
    end
end)

if not f.partyFrames then
    f.partyFrames = {}
    for i = 1, 4 do
        local pf = CreateFrame("Frame", nil, f.mapContent)
        pf:SetFrameLevel(f.mapContent:GetFrameLevel() + 5)
        pf:EnableMouse(true)
        pf:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" and self.pX and self.pY then f:ZoomToPoint(self.pX, self.pY, 6) end
        end)
        pf.tex = pf:CreateTexture(nil, "OVERLAY")
        pf.tex:SetAllPoints()
        pf.tex:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        f.partyFrames[i] = pf
    end
end

f.partyTracker = CreateFrame("Frame", nil, f.mapCanvas)
f.partyTracker:SetScript("OnUpdate", function()
    local contentW, contentH = f.mapContent:GetWidth(), f.mapContent:GetHeight()
    for i = 1, 4 do
        local unit, pf, showPartyMember, drawX, drawY = "party" .. i, f.partyFrames[i], false, 0, 0
        if UnitExists(unit) and UnitIsConnected(unit) then
            local unitMapID = C_Map.GetBestMapForUnit(unit)
            if unitMapID then
                local pos = C_Map.GetPlayerMapPosition(unitMapID, unit)
                if pos and pos.x and pos.y then
                    if f.currentMapID == 947 then
                        if T1_ZoneDB and T1_ZoneDB[unitMapID] then
                            local zData = T1_ZoneDB[unitMapID]
                            if zData.x and zData.w and zData.y and zData.h then
                                drawX, drawY, showPartyMember = zData.x + ((pos.x - 0.5) * zData.w),
                                    zData.y + ((pos.y - 0.5) * zData.h), true
                            end
                        end
                    elseif f.currentMapID == unitMapID then
                        drawX, drawY, showPartyMember = pos.x, pos.y, true
                    end
                end
            end
        end
        if showPartyMember then
            local _, classFilename = UnitClass(unit)
            if classFilename and RAID_CLASS_COLORS[classFilename] then
                local c = RAID_CLASS_COLORS[classFilename]
                pf.tex:SetVertexColor(c.r, c.g, c.b, 1)
            else
                pf.tex:SetVertexColor(0.5, 0.5, 1, 1)
            end
            pf.pX, pf.pY = drawX, drawY
            pf:Show()
            pf:SetSize(16 / f.zoomLevel, 16 / f.zoomLevel)
            pf:ClearAllPoints()
            pf:SetPoint("CENTER", f.mapContent, "TOPLEFT", drawX * contentW, -drawY * contentH)
        else
            pf:Hide()
            pf.pX, pf.pY = nil, nil
        end
    end
end)

f.corpseFrame = CreateFrame("Frame", nil, f.mapContent)
f.corpseFrame:SetFrameLevel(f.mapContent:GetFrameLevel() + 55)
f.corpseTex = f.corpseFrame:CreateTexture(nil, "OVERLAY")
f.corpseTex:SetAllPoints()
f.corpseTex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")

f.gyFrame = CreateFrame("Frame", nil, f.mapContent)
f.gyFrame:SetFrameLevel(f.mapContent:GetFrameLevel() + 54)
f.gyTex = f.gyFrame:CreateTexture(nil, "OVERLAY")
f.gyTex:SetAllPoints()
f.gyTex:SetTexture("Interface\\Icons\\Spell_Holy_Resurrection")
f.gyTex:SetTexCoord(0.1, 0.9, 0.1, 0.9)

f.deathTracker = CreateFrame("Frame", nil, f.mapCanvas)
f.deathTracker:SetScript("OnUpdate", function()
    local hasCorpse, hasGY, cX, cY, gX, gY = false, false, 0, 0, 0, 0
    if UnitIsDeadOrGhost("player") then
        local currentZoneID = C_Map.GetBestMapForUnit("player")
        if currentZoneID and C_DeathInfo then
            local corpsePos = C_DeathInfo.GetCorpseMapPosition and C_DeathInfo.GetCorpseMapPosition(currentZoneID)
            local gyPos = C_DeathInfo.GetDeathReleasePosition and C_DeathInfo.GetDeathReleasePosition(currentZoneID)

            if corpsePos and corpsePos.x and corpsePos.y then
                if f.currentMapID == 947 then
                    if T1_ZoneDB and T1_ZoneDB[currentZoneID] then
                        local zData = T1_ZoneDB[currentZoneID]
                        if zData.x and zData.w and zData.y and zData.h then
                            cX, cY, hasCorpse = zData.x + ((corpsePos.x - 0.5) * zData.w),
                                zData.y + ((corpsePos.y - 0.5) * zData.h), true
                        end
                    end
                elseif f.currentMapID == currentZoneID then
                    cX, cY, hasCorpse = corpsePos.x, corpsePos.y, true
                end
            end

            if gyPos and gyPos.x and gyPos.y then
                if f.currentMapID == 947 then
                    if T1_ZoneDB and T1_ZoneDB[currentZoneID] then
                        local zData = T1_ZoneDB[currentZoneID]
                        if zData.x and zData.w and zData.y and zData.h then
                            gX, gY, hasGY = zData.x + ((gyPos.x - 0.5) * zData.w), zData.y + ((gyPos.y - 0.5) * zData.h),
                                true
                        end
                    end
                elseif f.currentMapID == currentZoneID then
                    gX, gY, hasGY = gyPos.x, gyPos.y, true
                end
            end
        end
    end

    local contentW, contentH = f.mapContent:GetWidth(), f.mapContent:GetHeight()
    if hasCorpse then
        f.corpseFrame:Show()
        f.corpseFrame:SetSize(12 / f.zoomLevel, 12 / f.zoomLevel)
        f.corpseFrame:ClearAllPoints()
        f.corpseFrame:SetPoint("CENTER", f.mapContent, "TOPLEFT", cX * contentW, -cY * contentH)
    else
        f.corpseFrame:Hide()
    end

    if hasGY then
        f.gyFrame:Show()
        f.gyFrame:SetSize(12 / f.zoomLevel, 12 / f.zoomLevel)
        f.gyFrame:ClearAllPoints()
        f.gyFrame:SetPoint("CENTER", f.mapContent, "TOPLEFT", gX * contentW, -gY * contentH)
    else
        f.gyFrame:Hide()
    end
end)

if not f.flagHoverTracker then f.flagHoverTracker = CreateFrame("Frame", nil, f.mapCanvas) end
f.flagHoverTracker:SetScript("OnUpdate", function()
    if f.currentMapID ~= 947 or not f.cityFlags then return end
    local rawX, rawY = GetCursorPosition()
    local mapScale = f.mapContent:GetEffectiveScale()
    local left, top = f.mapContent:GetLeft(), f.mapContent:GetTop()
    if not left or not top then return end

    local pctX = ((rawX / mapScale) - left) / f.mapContent:GetWidth()
    local pctY = (top - (rawY / mapScale)) / f.mapContent:GetHeight()
    local CLICK_RADIUS_SQ = 0.0005 / (f.zoomLevel * f.zoomLevel)

    for key, flagObj in pairs(f.cityFlags) do
        if cityDataByZone[key] then
            local dx = (cityDataByZone[key].x or 0) - pctX
            local dy = (cityDataByZone[key].y or 0) - pctY
            if (dx * dx) + (dy * dy) <= CLICK_RADIUS_SQ then
                flagObj.tex:SetVertexColor(1, 1, 1, 0.7)
            else
                flagObj.tex:SetVertexColor(1, 1, 1, flagObj.baseOpacity or 1)
            end
        end
    end
end)

-- ==========================================
-- Init & Slash Commands
-- ==========================================
tinsert(UISpecialFrames, f:GetName())
f:Hide()

_G.func_ToggleT1Window = function(mapID)
    if mapID and type(mapID) == "number" then
        f:LoadMap(mapID)
        if f.UpdateMapTransform then f:UpdateMapTransform() end
        f:Show()
    else
        if f:IsShown() then
            f:Hide()
        else
            local playerMap = C_Map.GetBestMapForUnit("player")
            local capitalCities = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
            local defaultMap = (playerMap and capitalCities[playerMap]) and playerMap or 947
            f:LoadMap(defaultMap)
            if defaultMap == 947 and playerMap then
                f:ZoomToZone(playerMap)
            elseif f.UpdateMapTransform then
                f:UpdateMapTransform()
            end
            f:Show()
        end
    end
end

SLASH_T1_CMD1 = "/t1"
SlashCmdList["T1_CMD"] = function() _G.func_ToggleT1Window() end

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
    if not self.currentMapID then
        local playerMap = C_Map.GetBestMapForUnit("player")
        local capitalCities = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
        local defaultMap = (playerMap and capitalCities[playerMap]) and playerMap or 947
        self:LoadMap(defaultMap)
        if defaultMap == 947 and playerMap then self:ZoomToZone(playerMap) end
    end
    if self.UpdateMapTransform then self:UpdateMapTransform() end
end)

print("|cFF00FF00t1_TrackMap UI Built! Type /t1 or Ctrl+Numpad 1|r")
