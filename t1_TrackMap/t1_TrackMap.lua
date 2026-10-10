local addonName, T1 = ...

-- Create your main frame
T1.MapFrame = CreateFrame("Frame", "t1_TrackMap", nil, "BasicFrameTemplateWithInset")
local f = T1.MapFrame


local uiScale = UIParent:GetEffectiveScale()
if not uiScale or uiScale <= 0.1 then 
    uiScale = 1 -- Fallback to standard 100% scale if the game hasn't loaded UIParent yet
end
f:SetScale(uiScale)


-- FIX: Hide the map by default on login, and allow the ESC key to close it
f:Hide()
tinsert(UISpecialFrames, f:GetName())

-- Register this frame to the shared Core Addon
if _G.ForeverTrack then
    _G.ForeverTrack.Modules.T1 = f
end

--
f:SetSize(304, 227)
f:SetPoint("TOPLEFT", nil, "TOPLEFT", 5, -5)
f:SetFrameLevel(100)
f:SetResizable(true)


f.ResetLayout = function(self)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", nil, "TOPLEFT", 5, -5) -- T1's specific default position
    self:SetSize(304, 227)                            -- T1's specific default size
end



--
if f.SetResizeBounds then
    f:SetResizeBounds(304, 227, 1216, 840)
else
    f:SetMinResize(304, 227)
    f:SetMaxResize(1216, 840)
end

function f:GetDynamicMaxZoom()
    local w = self:GetWidth() or 916
    local maxZoom = 20 - ((w - 304) / (1216 - 304)) * 10
    return math.max(10, math.min(20, maxZoom))
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
-- Logical <-> UI Percent Converters
-- ==========================================
local function LogicalToUIPercent(logicalX, logicalY)
    local pctX = (logicalX / 1.5) + 0.5
    local pctY = 0.5 - logicalY
    return pctX, pctY
end

local function UIPercentToLogical(pctX, pctY)
    local logicalX = (pctX - 0.5) * 1.5
    local logicalY = (0.5 - pctY) * 1.0
    return logicalX, logicalY
end

local function IsPointInPolygon(px, py, loops)
    local inside = false
    for _, loop in ipairs(loops) do
        local j = #loop
        for i = 1, #loop do
            local xi, yi = loop[i].x, loop[i].y
            local xj, yj = loop[j].x, loop[j].y
            local intersect = ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi)
            if intersect then inside = not inside end
            j = i
        end
    end
    return inside
end

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
-- City Map Data
-- ==========================================
local cityDataByZone = {
    ["elwynn-forest"]     = { name = "Stormwind", id = 1453, zoneID = 1429, status = "Alliance", x = 0.324, y = -0.131, zoneX = 0.24, zoneY = 0.36 },
    ["durotar"]           = { name = "Orgrimmar", id = 1454, zoneID = 1411, status = "Horde", x = -0.305, y = 0.065, zoneX = 0.46, zoneY = 0.16 },
    ["dun-morogh"]        = { name = "Ironforge", id = 1455, zoneID = 1426, status = "Alliance", x = 0.382, y = 0.012, zoneX = 0.59, zoneY = 0.24 },
    ["mulgore"]           = { name = "Thunder Bluff", id = 1456, zoneID = 1412, status = "Horde", x = -0.450, y = -0.029, zoneX = 0.41, zoneY = 0.33 },
    ["teldrassil"]        = { name = "Darnassus", id = 1457, zoneID = 1438, status = "Alliance", x = -0.540, y = 0.340, zoneX = 0.26, zoneY = 0.55 },
    ["tirisfal-glades"]   = { name = "Undercity", id = 1458, zoneID = 1420, status = "Horde", x = 0.342, y = 0.226, zoneX = 0.62, zoneY = 0.75 },
    ["alterac-mountains"] = { name = "Dalaran", id = -1416, zoneID = 1416, status = "Neutral", x = 0.3395, y = 0.1746, w = 0.0283, zoneX = 0.17, zoneY = 0.68, cityScaleX = 7.5, cityScaleY = 7.5 },
}

local function GetCityDataForZone(zoneMapID)
    if not zoneMapID or zoneMapID == 947 or zoneMapID <= 0 then return nil, nil end
    for key, data in pairs(cityDataByZone) do
        if data.zoneID == zoneMapID then return key, data end
    end
    return nil, nil
end

local function GetCityLocalCoords(data, zoneMapID)
    if data and data.zoneX and data.zoneY then return data.zoneX, data.zoneY end
    return nil, nil
end

function T1.IsCustomCityMap(mapID)
    if not mapID or mapID <= 0 then return false end
    for _, data in pairs(cityDataByZone) do
        if data.id == mapID then return true end
    end
    return false
end

-- ==========================================
-- Map Toggle & Zoom UI
-- ==========================================
f.showFogOfWar = true
f.MapToggleButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.MapToggleButton:SetSize(110, 20)
f.MapToggleButton:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
f.MapToggleButton:SetText("Hide Mist")
f.MapToggleButton:SetNormalFontObject("GameFontNormalSmall")
f.MapToggleButton:SetHighlightFontObject("GameFontHighlightSmall")

f.MapToggleButton:SetScript("OnClick", function()
    if f.currentMapID ~= 947 then
        f:LoadMap(947)
    else
        f.showFogOfWar = not f.showFogOfWar
        if f.RefreshFogOfWar then f:RefreshFogOfWar() end
        f.MapToggleButton:SetText(f.showFogOfWar and "Hide Mist" or "Show Mist")
    end
    if f.UpdateMapTransform then f:UpdateMapTransform() end
end)

f.zoomSlider = CreateFrame("Slider", "T1_TrackMapZoomSlider", f, "OptionsSliderTemplate")
f.zoomSlider:SetSize(60, 16)
f.zoomSlider:SetPoint("RIGHT", collapseBtn, "LEFT", -3, 0)
f.zoomSlider:SetMinMaxValues(1, 10)
f.zoomSlider:SetValueStep(0.01)
f.zoomSlider:SetObeyStepOnDrag(true)
_G[f.zoomSlider:GetName() .. "Low"]:Hide()
_G[f.zoomSlider:GetName() .. "High"]:Hide()
f.zoomSlider.isUpdating = false

f.zoomSlider:SetScript("OnValueChanged", function(self, value)
    if self.isUpdating then return end
    if f.targetZoom == value then return end
    f.targetZoom = value

    if value <= 1.01 then
        f.targetOffsetX = 0
        f.targetOffsetY = 0
        self.isUpdating = true
        if f.currentMapID then
            f.savedWorldZoom = nil
            if f.RefreshFogOfWar then f:RefreshFogOfWar() end
            if f.UpdateMapTransform then f:UpdateMapTransform() end
        end
        self.isUpdating = false
    end

    local canvasW, canvasH = f.mapCanvas:GetSize()
    local contentW, contentH = f.mapContent:GetSize()
    if canvasW and canvasH and contentW and contentH then
        if f.playerArrow and f.playerArrow:IsShown() and f.playerArrow.pX and f.playerArrow.pY then
            local uiPctX, uiPctY = LogicalToUIPercent(f.playerArrow.pX, f.playerArrow.pY)
            if f.currentMapID ~= 947 then
                uiPctX, uiPctY = f.playerArrow.pX, f.playerArrow.pY
            end
            f.zoomPivotX = (f.mapOffsetX + (uiPctX * contentW)) * f.zoomLevel
            f.zoomPivotY = (f.mapOffsetY - (uiPctY * contentH)) * f.zoomLevel
        else
            f.zoomPivotX = canvasW / 2
            f.zoomPivotY = -canvasH / 2
        end
    end
    if f.zoomSmoother then f.zoomSmoother:Show() end
end)

f.zoomUI = CreateFrame("Frame", nil, f)
f.zoomUI:SetAllPoints(f.mapCanvas)
f.zoomUI:SetFrameLevel(f:GetFrameLevel() + 5)

f.zoomText = f.zoomUI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
f.zoomText:SetPoint("TOPLEFT", f.zoomUI, "TOPLEFT", 5, -5)
f.zoomText:SetJustifyH("LEFT")
f.zoomText:SetText("Scale: 1.00x")

-- ==========================================
-- Dynamic POI Menu Builder (For Components)
-- ==========================================
f.poiMainToggle = CreateFrame("CheckButton", nil, f.zoomUI, "UICheckButtonTemplate")
f.poiMainToggle:SetSize(24, 24)
f.poiMainToggle:SetPoint("TOPLEFT", f.zoomText, "BOTTOMLEFT", -4, -5)
f.poiMainToggle:SetChecked(false)

f.poiMainText = f.poiMainToggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
f.poiMainText:SetPoint("LEFT", f.poiMainToggle, "RIGHT", 0, 1)
f.poiMainText:SetText("Toggle PoI")
f.poiMainToggle:SetHitRectInsets(0, -f.poiMainText:GetStringWidth() - 5, 0, 0)

f.poiSubMenu = CreateFrame("Frame", nil, f.zoomUI)
f.poiSubMenu:SetSize(100, 100)
f.poiSubMenu:SetPoint("TOPLEFT", f.poiMainToggle, "BOTTOMLEFT", 12, 0)
f.poiSubMenu:Hide()

f.poiMainToggle:SetScript("OnClick", function(self)
    if self:GetChecked() then f.poiSubMenu:Show() else f.poiSubMenu:Hide() end
end)

f.poiCheckboxes = {}
function T1.CreatePoICheckbox(name, label, defaultState, onClickFunc)
    local anchorFrame = #f.poiCheckboxes == 0 and f.poiSubMenu or f.poiCheckboxes[#f.poiCheckboxes]
    local yOffset = #f.poiCheckboxes == 0 and 0 or -2

    local cb = CreateFrame("CheckButton", name, f.poiSubMenu, "UICheckButtonTemplate")
    cb:SetSize(20, 20)

    if #f.poiCheckboxes == 0 then
        cb:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 0, 0)
    else
        cb:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, yOffset)
    end
    cb:SetChecked(defaultState)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    text:SetText(label)
    cb:SetHitRectInsets(0, -text:GetStringWidth() - 5, 0, 0)

    cb:SetScript("OnClick", function(self)
        if onClickFunc then onClickFunc(self:GetChecked()) end
    end)

    table.insert(f.poiCheckboxes, cb)
    return cb
end

-- ==========================================
-- Map Window Resizing
-- ==========================================
f.ResizeGrip = CreateFrame("Button", nil, f)
f.ResizeGrip:SetSize(16, 16)
f.ResizeGrip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
f.ResizeGrip:SetFrameLevel(f:GetFrameLevel() + 10)
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
    if f.RefreshFogOfWar then f:RefreshFogOfWar() end
    if f.UpdateMapTransform then f:UpdateMapTransform() end
end)

f.ResizeGrip:SetScript("OnUpdate", function(self)
    if self.isResizing then
        local cX, _ = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local dx = (cX - self.startX) / scale
        local newWidth = self.startW + dx
        if newWidth < 304 then newWidth = 304 end
        if newWidth > 1216 then newWidth = 1216 end

        local canvasW = newWidth - 16
        local newHeight = (canvasW / 1.5) + 36
        f:SetSize(newWidth, newHeight)
    end
end)

f:SetScript("OnSizeChanged", function(self)
    if self.mapContent and self.mapCanvas then
        local w, h = self.mapCanvas:GetSize()
        if w and h and w > 1 and h > 1 then
            local targetRatio = 1.5
            local currentRatio = w / h
            if currentRatio > targetRatio then
                self.mapContent:SetSize(h * targetRatio, h)
            else
                self.mapContent:SetSize(w, w / targetRatio)
            end
        end
    end
    if self.zoomSlider then
        local currentMin, _ = self.zoomSlider:GetMinMaxValues()
        self.zoomSlider:SetMinMaxValues(currentMin, self.GetDynamicMaxZoom and self:GetDynamicMaxZoom() or 20)
    end
    if self.currentMapID == 947 and self.worldMapTiles then
        local numCols, numRows = 3, 3
        local tileW = self.mapContent:GetWidth() / numCols
        local tileH = self.mapContent:GetHeight() / numRows
        local tileIndex = 1
        for r = 0, numRows - 1 do
            for c = 0, numCols - 1 do
                local tile = self.worldMapTiles[tileIndex]
                if tile then
                    tile:SetSize(tileW, tileH)
                    tile:ClearAllPoints()
                    tile:SetPoint("TOPLEFT", self.mapContent, "TOPLEFT", c * tileW, -(r * tileH))
                end
                tileIndex = tileIndex + 1
            end
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
    f.targetOffsetX = nil
    f.targetOffsetY = nil
    f.velocityX = 0
    f.velocityY = 0
    if f.zoomSmoother then f.zoomSmoother:Hide() end
    if button == "LeftButton" then self.isDragging = true end
end)

f.mapCanvas:SetScript("OnMouseUp", function(self, button)
    if not self.startX or not self.startY then return end

    local cX, cY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local dragDistance = (math.abs(cX - self.startX) + math.abs(cY - self.startY)) / scale
    local MY_CUSTOM_WORLD_MAP_ID = 947

    if button == "LeftButton" then
        self.isDragging = false
        if dragDistance >= 25 then
            if f.velocityX and f.velocityY and (math.abs(f.velocityX) > 50 or math.abs(f.velocityY) > 50) then
                if f.zoomSmoother then f.zoomSmoother:Show() end
            end
        else
            f.velocityX = 0
            f.velocityY = 0
        end
    end

    if dragDistance < 25 then
        if button == "RightButton" then
            local targetMapID = (f.currentMapID == MY_CUSTOM_WORLD_MAP_ID) and self.hoveredMapID or f.currentMapID
            if T1.OpenT2Window then T1:OpenT2Window(targetMapID) end
        elseif button == "MiddleButton" then
            local currentTime = GetTime()
            if self.lastMiddleClickTime and (currentTime - self.lastMiddleClickTime < 0.3) then
                self.lastMiddleClickTime = 0
                f.savedWorldZoom = nil
                if f.currentMapID ~= 947 then f:LoadMap(947) end

                local canvasW, canvasH = self:GetSize()
                local contentW, contentH = f.mapContent:GetSize()
                if canvasW and canvasH and contentW and contentH then
                    local fitScale = math.max(canvasW / contentW, canvasH / contentH)
                    f.targetZoom = fitScale
                    f.targetOffsetX = ((canvasW - (contentW * fitScale)) / 2) / fitScale
                    f.targetOffsetY = (-(canvasH - (contentH * fitScale)) / 2) / fitScale
                    if f.zoomSmoother then f.zoomSmoother:Show() end
                end
            else
                self.lastMiddleClickTime = currentTime
                local currentZoneID = C_Map.GetBestMapForUnit("player")
                if currentZoneID and currentZoneID > 0 then
                    f.savedWorldZoom = nil
                    if f.currentMapID ~= 947 then f:LoadMap(947) end

                    local wX, wY = nil, nil
                    local pos = C_Map.GetPlayerMapPosition(currentZoneID, "player")

                    if pos and pos.x and pos.y and T1_ZoneDB and T1_ZoneDB[currentZoneID] then
                        local zData = T1_ZoneDB[currentZoneID]
                        local zW = (zData.w and zData.w > 0) and zData.w or 0.05
                        if zData.x and zData.y then
                            wX = zData.x + ((pos.x - 0.5) * zW)
                            wY = zData.y + ((0.5 - pos.y) * (zW / 1.5))
                        end
                    end

                    if wX and wY then
                        local uiX, uiY = LogicalToUIPercent(wX, wY)
                        f:ZoomToPoint(uiX, uiY, 8)
                    else
                        f:ZoomToZone(currentZoneID)
                    end
                end
            end
            if f.UpdateMapTransform then f:UpdateMapTransform() end
        elseif button == "LeftButton" then
            if f.currentMapID == MY_CUSTOM_WORLD_MAP_ID then
                if self.hoveredMapID and self.hoveredMapID ~= 0 then
                    f:LoadMap(self.hoveredMapID)
                    if f.UpdateMapTransform then f:UpdateMapTransform() end
                end
            elseif self.hoveredCityID then
                f:LoadMap(self.hoveredCityID)
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
f.cursorTooltip:SetFrameStrata("TOOLTIP")
f.cursorTooltip:SetFrameLevel(f:GetFrameLevel() + 20)
f.cursorTooltip:Hide()

f.cursorTooltip.text = f.cursorTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
f.cursorTooltip.text:SetPoint("CENTER", f.cursorTooltip, "CENTER", 0, 0)

f.mapCanvas:SetScript("OnUpdate", function(self, elapsed)
    elapsed = elapsed or (1 / 60)

    if self.isDragging then
        local cX, cY = GetCursorPosition()
        local uiScale = UIParent:GetEffectiveScale()
        local dx = (cX - self.startX) / uiScale
        local dy = (cY - self.startY) / uiScale

        local newOffsetX = self.startOffsetX + (dx / f.zoomLevel)
        local newOffsetY = self.startOffsetY + (dy / f.zoomLevel)

        f.velocityX = (newOffsetX - (f.mapOffsetX or 0)) / elapsed
        f.velocityY = (newOffsetY - (f.mapOffsetY or 0)) / elapsed

        f.mapOffsetX = newOffsetX
        f.mapOffsetY = newOffsetY
        f:UpdateMapTransform()
    end

    if self:IsMouseOver() then
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
                if f.currentMapID == 947 then
                    local logicalX, logicalY = UIPercentToLogical(pctX, pctY)
                    local closestZone, closestComment, closestID = "Great Sea", "", "???"
                    local hoverLocalX, hoverLocalY = nil, nil
                    local foundPolygonZone = false
                    local isHoveringCity = false
                    local hoverCityStatus = nil

                    local CLICK_RADIUS_SQ = 0.0006 / (f.zoomLevel * f.zoomLevel)

                    for _, data in pairs(cityDataByZone) do
                        if data.x and data.y then
                            local dx = data.x - logicalX
                            local dy = data.y - logicalY
                            if (dx * dx) + (dy * dy) <= CLICK_RADIUS_SQ then
                                closestID = data.id
                                closestZone = data.name
                                hoverCityStatus = data.status
                                isHoveringCity = true
                                break
                            end
                        end
                    end

                    if not isHoveringCity then
                        if T1_OutlineDB then
                            for id, outlineData in pairs(T1_OutlineDB) do
                                if tonumber(id) and tonumber(id) > 0 and outlineData.loops and outlineData.bounds then
                                    if logicalX >= outlineData.bounds.minX and logicalX <= outlineData.bounds.maxX and
                                        logicalY >= outlineData.bounds.minY and logicalY <= outlineData.bounds.maxY then
                                        if IsPointInPolygon(logicalX, logicalY, outlineData.loops) then
                                            closestID = id
                                            foundPolygonZone = true

                                            if T1_ZoneDB and T1_ZoneDB[id] then
                                                local zData = T1_ZoneDB[id]
                                                closestZone = zData.zone or ("Zone_" .. id)
                                                closestComment = zData.comment or ""
                                                if zData.x and zData.y then
                                                    local zoneW = (zData.w and zData.w > 0) and zData.w or 0.05
                                                    hoverLocalX = ((logicalX - zData.x) / zoneW) + 0.5
                                                    hoverLocalY = ((zData.y - logicalY) / (zoneW / 1.5)) + 0.5
                                                end
                                            else
                                                closestZone = "???"
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end

                        if not foundPolygonZone and T1_ZoneDB then
                            local minDist = 999
                            for id, zData in pairs(T1_ZoneDB) do
                                if tonumber(id) and tonumber(id) > 0 then
                                    local hasOutline = T1_OutlineDB and T1_OutlineDB[id] and T1_OutlineDB[id].loops
                                    if not hasOutline and zData.x and zData.y then
                                        local dx = zData.x - logicalX
                                        local dy = zData.y - logicalY
                                        local distSq = (dx * dx) + (dy * dy)
                                        if distSq < minDist then
                                            minDist = distSq
                                            closestZone = zData.zone or ("Zone_" .. id)
                                            closestComment = zData.comment or ""
                                            closestID = id
                                            local zoneW = (zData.w and zData.w > 0) and zData.w or 0.05
                                            hoverLocalX = ((logicalX - zData.x) / zoneW) + 0.5
                                            hoverLocalY = ((zData.y - logicalY) / (zoneW / 1.5)) + 0.5
                                        end
                                    end
                                end
                            end
                            if minDist > 0.015 then
                                closestZone, closestComment, closestID = "Great Sea", "", "???"
                                hoverLocalX, hoverLocalY = nil, nil
                            end
                        end
                    end

                    self.hoveredZone = closestZone
                    self.hoveredMapID = (closestID ~= "???") and tonumber(closestID) or nil

                    if self.lastHoveredMapID ~= self.hoveredMapID then
                        self.lastHoveredMapID = self.hoveredMapID
                        if f.DrawHoverPolygon then f:DrawHoverPolygon(self.hoveredMapID) end
                    end

                    local colorCode = "|cffffffff"
                    if isHoveringCity then
                        if hoverCityStatus == "Alliance" then
                            colorCode = "|cff003399"
                        elseif hoverCityStatus == "Horde" then
                            colorCode = "|cffff2020"
                        elseif hoverCityStatus == "Neutral" then
                            colorCode = "|cffffcc00"
                        end
                    end

                    if not self.isDragging then ResetCursor() end

                    local coordText = ""
                    if hoverLocalX and hoverLocalY then
                        coordText = string.format(" (%.0f, %.0f)", hoverLocalX * 100, hoverLocalY * 100)
                    end
                    local headerText = (closestID == "???") and "|cffaaaaaa#???|r" or
                        string.format("|cffaaaaaa#%s%s|r", closestID, coordText)

                    if closestComment ~= "" then
                        f.cursorTooltip.text:SetFormattedText("%s\n%s%s\n%s\n%.3f, %.3f|r", headerText, colorCode,
                            closestZone:upper(), closestComment, logicalX, logicalY)
                    else
                        f.cursorTooltip.text:SetFormattedText("%s\n%s%s\n%.3f, %.3f|r", headerText, colorCode,
                            closestZone:upper(), logicalX, logicalY)
                    end
                    f.cursorTooltip.text:SetFontObject("SystemFont_Small")
                else
                    self.hoveredCityID = nil
                    local mapName = "Unknown Map"
                    local colorCode = "|cffffffff"
                    local isCity = false

                    local cityKey, cityData = GetCityDataForZone(f.currentMapID)
                    local isHoveringZoneCity = false

                    if cityData then
                        local clX, clY = GetCityLocalCoords(cityData, f.currentMapID)
                        if clX and clY then
                            local contentW, contentH = f.mapContent:GetSize()
                            local dx = (pctX - clX) * contentW
                            local dy = (pctY - clY) * contentH
                            local CLICK_RADIUS = 14 / f.zoomLevel
                            if (dx * dx) + (dy * dy) <= (CLICK_RADIUS * CLICK_RADIUS) then
                                isHoveringZoneCity = true
                                self.hoveredCityID = cityData.id
                                mapName = cityData.name
                                isCity = true
                                if cityData.status == "Alliance" then
                                    colorCode = "|cff003399"
                                elseif cityData.status == "Horde" then
                                    colorCode = "|cffff2020"
                                elseif cityData.status == "Neutral" then
                                    colorCode = "|cffffcc00"
                                end
                            end
                        end
                    end

                    if not isHoveringZoneCity then
                        for key, data in pairs(cityDataByZone) do
                            if data.id == f.currentMapID then
                                isCity = true
                                mapName = data.name
                                if data.status == "Alliance" then
                                    colorCode = "|cff003399"
                                elseif data.status == "Horde" then
                                    colorCode = "|cffff2020"
                                elseif data.status == "Neutral" then
                                    colorCode = "|cffffcc00"
                                end
                                break
                            end
                        end
                        if not isCity and f.currentMapID > 0 and C_Map and C_Map.GetMapInfo then
                            local mapInfo = C_Map.GetMapInfo(f.currentMapID)
                            if mapInfo and mapInfo.name then mapName = mapInfo.name end
                        end
                        if f.currentMapID == -1416 and not isCity then
                            mapName = "Dalaran"
                            colorCode = "|cffffcc00"
                        end
                    end

                    local targetID = self.hoveredCityID or f.currentMapID or "???"
                    local coordText = string.format(" (%.0f, %.0f)", pctX * 100, pctY * 100)
                    local headerText = string.format("|cffaaaaaa#%s%s|r", targetID, coordText)

                    f.cursorTooltip.text:SetFormattedText("%s\n%s%s\n%.3f, %.3f|r", headerText, colorCode,
                        mapName:upper(), pctX, pctY)
                    f.cursorTooltip.text:SetFontObject("SystemFont_Small")
                    if not self.isDragging then ResetCursor() end
                end

                f.cursorTooltip:SetSize(f.cursorTooltip.text:GetStringWidth(), f.cursorTooltip.text:GetStringHeight())
                local uiScale = f.cursorTooltip:GetEffectiveScale()
                local cursorX = rawX / uiScale
                local cursorY = rawY / uiScale
                local anchorPoint, offsetX, offsetY = "", 0, 0

                if pctY > 0.5 then
                    anchorPoint = "BOTTOM"
                    offsetY = 15
                else
                    anchorPoint = "TOP"
                    offsetY = -15
                end

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
                f.cursorTooltip:SetPoint(anchorPoint, nil, "BOTTOMLEFT", cursorX + offsetX, cursorY + offsetY)
                f.cursorTooltip:Show()
            else
                f.cursorTooltip:Hide()
                if not self.isDragging then ResetCursor() end
                if self.hoveredMapID ~= nil then
                    self.hoveredMapID = nil
                    self.lastHoveredMapID = nil
                    if f.DrawHoverPolygon then f:DrawHoverPolygon(nil) end
                end
            end
        end
    else
        f.cursorTooltip:Hide()
        if not self.isDragging then ResetCursor() end
        if self.hoveredMapID ~= nil then
            self.hoveredMapID = nil
            self.lastHoveredMapID = nil
            if f.DrawHoverPolygon then f:DrawHoverPolygon(nil) end
        end
    end
end)

-- ==========================================
-- Hover Polygon Boundary Drawer
-- ==========================================
if not f.debugLinePool then f.debugLinePool = {} end
function f:DrawHoverPolygon(zoneID)
    for _, line in ipairs(f.debugLinePool) do line:Hide() end
    if f.currentMapID ~= 947 or not T1_OutlineDB or not zoneID or zoneID <= 0 then return end

    local data = T1_OutlineDB[zoneID]
    if not data or not data.loops then return end

    local lineIndex = 1
    local contentW, contentH = f.mapContent:GetSize()

    for _, loop in ipairs(data.loops) do
        local numPoints = #loop
        for i = 1, numPoints do
            local pt1 = loop[i]
            local pt2 = loop[(i % numPoints) + 1]
            local line = f.debugLinePool[lineIndex]
            if not line then
                line = f.mapContent:CreateLine(nil, "OVERLAY")
                table.insert(f.debugLinePool, line)
            end
            line:SetThickness(2 / f.zoomLevel)
            line:SetColorTexture(0.90, 0.82, 0.62, 0.5)

            local startX = (pt1.x / 1.5) * contentW
            local startY = pt1.y * contentH
            local endX = (pt2.x / 1.5) * contentW
            local endY = pt2.y * contentH

            line:SetStartPoint("CENTER", startX, startY)
            line:SetEndPoint("CENTER", endX, endY)
            line:Show()
            lineIndex = lineIndex + 1
        end
    end
end

-- ==========================================
-- Map Loading & Fog of War Rendering
-- ==========================================
f.blizzardTiles = {}
function f:LoadMap(mapID)
    if not mapID or (mapID <= 0 and mapID ~= -1416) then return end
    if mapID ~= 947 and mapID ~= -1416 and not C_Map.GetMapArtLayers(mapID) then return end

    if f.currentMapID == 947 and mapID ~= 947 then
        f.savedWorldZoom = f.zoomLevel
        f.savedWorldOffsetX = f.mapOffsetX
        f.savedWorldOffsetY = f.mapOffsetY
        f.savedTargetZoom = f.targetZoom
    end

    if mapID == 947 then
        if f.savedWorldZoom then
            f.zoomLevel = f.savedWorldZoom
            f.mapOffsetX = f.savedWorldOffsetX
            f.mapOffsetY = f.savedWorldOffsetY
            f.targetZoom = f.savedTargetZoom or f.savedWorldZoom
        end
    else
        f.zoomLevel = 1
        f.mapOffsetX = 0
        f.mapOffsetY = 0
        f.targetZoom = 1
    end

    f.targetOffsetX, f.targetOffsetY = nil, nil
    f.velocityX, f.velocityY = 0, 0
    f.currentMapID = mapID

    if f.MapToggleButton then
        if mapID == 947 then
            f.MapToggleButton:SetText(f.showFogOfWar and "Hide Mist" or "Show Mist")
        else
            f.MapToggleButton:SetText("Return")
        end
    end

    if f.worldMapTiles then for _, tile in ipairs(f.worldMapTiles) do tile:Hide() end end
    if f.dalaranMapTile then f.dalaranMapTile:Hide() end
    for _, tile in ipairs(f.blizzardTiles) do tile:Hide() end

    if mapID == 947 then
        local numCols, numRows = 3, 3
        if not f.worldMapTiles then f.worldMapTiles = {} end
        f.baseMapQueue = {}
        for r = 0, numRows - 1 do
            for c = 0, numCols - 1 do
                local idx = r * numCols + c + 1
                table.insert(f.baseMapQueue, { index = idx, row = r, col = c })
            end
        end

        if not f.baseMapLoader then
            f.baseMapLoader = CreateFrame("Frame", nil, f)
            f.baseMapLoader:SetScript("OnUpdate", function(self)
                if not f.baseMapQueue or #f.baseMapQueue == 0 then
                    self:Hide()
                    return
                end
                local left, right = f.mapContent:GetLeft(), f.mapContent:GetRight()
                local top, bottom = f.mapContent:GetTop(), f.mapContent:GetBottom()
                local canvasLeft, canvasRight = f.mapCanvas:GetLeft(), f.mapCanvas:GetRight()
                local canvasTop, canvasBottom = f.mapCanvas:GetTop(), f.mapCanvas:GetBottom()

                if not left or not right or not top or not bottom or not canvasLeft then return end
                local effW, effH = right - left, top - bottom
                if effW <= 0 or effH <= 0 then return end

                local canvasCenterX = (canvasLeft + canvasRight) / 2
                local canvasCenterY = (canvasTop + canvasBottom) / 2
                local pctX = math.max(0, math.min(1, (canvasCenterX - left) / effW))
                local pctY = math.max(0, math.min(1, (top - canvasCenterY) / effH))
                local targetCol, targetRow = pctX * numCols, pctY * numRows

                table.sort(f.baseMapQueue, function(a, b)
                    local distA = math.abs((a.row + 0.5) - targetRow) + math.abs((a.col + 0.5) - targetCol)
                    local distB = math.abs((b.row + 0.5) - targetRow) + math.abs((b.col + 0.5) - targetCol)
                    return distA < distB
                end)

                local contentW, contentH = f.mapContent:GetSize()
                local tileW, tileH = contentW / numCols, contentH / numRows
                for i = 1, 2 do
                    if #f.baseMapQueue > 0 then
                        local data = table.remove(f.baseMapQueue, 1)
                        local tile = f.worldMapTiles[data.index]
                        if not tile then
                            tile = f.mapContent:CreateTexture(nil, "BACKGROUND")
                            f.worldMapTiles[data.index] = tile
                        end
                        tile:SetSize(tileW, tileH)
                        tile:ClearAllPoints()
                        tile:SetPoint("TOPLEFT", f.mapContent, "TOPLEFT", data.col * tileW, -(data.row * tileH))
                        tile:SetTexture("Interface\\AddOns\\forever_track\\t1_TrackMap\\map_texture\\worldmap-forever-" ..
                            data.index .. ".tga")
                        if f.showFogOfWar then
                            tile:SetDesaturated(true)
                            tile:SetVertexColor(0.25, 0.25, 0.25)
                        else
                            tile:SetDesaturated(false)
                            tile:SetVertexColor(1, 1, 1)
                        end
                        tile:Show()
                    end
                end
            end)
        end
        f.baseMapLoader:Show()
    elseif mapID == -1416 then
        if not f.dalaranMapTile then
            f.dalaranMapTile = f.mapContent:CreateTexture(nil, "BACKGROUND")
            f.dalaranMapTile:SetAllPoints(f.mapContent)
            f.dalaranMapTile:SetTexture("Interface\\AddOns\\forever_track\\t1_TrackMap\\map_texture\\dalaran.tga")
        end
        f.dalaranMapTile:SetDesaturated(false)
        f.dalaranMapTile:SetVertexColor(1, 1, 1, 1)
        f.dalaranMapTile:Show()
    else
        local layers = C_Map.GetMapArtLayers(mapID)
        if layers and #layers > 0 then
            local textureIndex = 1
            for layerIndex, layerInfo in ipairs(layers) do
                local textures = C_Map.GetMapArtLayerTextures(mapID, layerIndex)
                if textures then
                    local numCols = math.ceil(layerInfo.layerWidth / layerInfo.tileWidth)
                    local numRows = math.ceil(layerInfo.layerHeight / layerInfo.tileHeight)
                    local scaleX = f.mapContent:GetWidth() / layerInfo.layerWidth
                    local scaleY = f.mapContent:GetHeight() / layerInfo.layerHeight

                    for row = 1, numRows do
                        for col = 1, numCols do
                            if textureIndex > #textures then break end
                            local tile = f.blizzardTiles[textureIndex]
                            if not tile then
                                tile = f.mapContent:CreateTexture(nil, "BACKGROUND")
                                f.blizzardTiles[textureIndex] = tile
                            end
                            tile:SetDrawLayer("BACKGROUND", layerIndex - 1)
                            local tileWidth = layerInfo.tileWidth * scaleX
                            local tileHeight = layerInfo.tileHeight * scaleY
                            tile:SetSize(tileWidth, tileHeight)
                            tile:SetPoint("TOPLEFT", f.mapContent, "TOPLEFT", (col - 1) * tileWidth,
                                -(row - 1) * tileHeight)
                            tile:SetTexture(textures[textureIndex])
                            tile:Show()
                            textureIndex = textureIndex + 1
                        end
                    end
                end
            end
        end
    end
    if f.RefreshFogOfWar then f:RefreshFogOfWar() end
end

if not f.exploredTexturePool then f.exploredTexturePool = CreateTexturePool(f.mapContent, "ARTWORK") end
if not f.exploredMaskPool then f.exploredMaskPool = {} end

function f:DrawExploredZone(zoneID)
    if not zoneID or zoneID <= 0 then return end
    local layers = C_Map.GetMapArtLayers(zoneID)
    if not layers or not layers[1] then return end

    local exploredTextures = C_MapExplorationInfo.GetExploredMapTextures(zoneID)
    if not exploredTextures then return end

    local layerW, layerH = layers[1].layerWidth, layers[1].layerHeight
    local contentW, contentH = f.mapContent:GetSize()
    local TILE_SIZE = 256
    local isWorldMap = (f.currentMapID == 947)
    local drawTopLeftX, drawTopLeftY, zonePixelW, zonePixelH, scaleX, scaleY

    if isWorldMap then
        if not T1_ZoneDB or not T1_ZoneDB[zoneID] then return end
        local zData = T1_ZoneDB[zoneID]
        local zoneW = (zData.w and zData.w > 0) and zData.w or 0.05
        if not zData.x or not zData.y then return end

        local nativeRatio = layerH / layerW
        local centerPctX, centerPctY = LogicalToUIPercent(zData.x, zData.y)
        zonePixelW = (zoneW / 1.5) * contentW
        zonePixelH = zonePixelW * nativeRatio
        drawTopLeftX = (centerPctX * contentW) - (zonePixelW / 2)
        drawTopLeftY = (centerPctY * contentH) - (zonePixelH / 2)
    else
        scaleX, scaleY = contentW / layerW, contentH / layerH
    end

    for _, expInfo in ipairs(exploredTextures) do
        local numCols = math.ceil(expInfo.textureWidth / TILE_SIZE)
        local numRows = math.ceil(expInfo.textureHeight / TILE_SIZE)
        local idx = 1
        for r = 0, numRows - 1 do
            for c = 0, numCols - 1 do
                local fileDataID = expInfo.fileDataIDs[idx]
                if fileDataID then
                    local tileW = math.min(TILE_SIZE, expInfo.textureWidth - (c * TILE_SIZE))
                    local tileH = math.min(TILE_SIZE, expInfo.textureHeight - (r * TILE_SIZE))
                    if isWorldMap then
                        local pctX = (expInfo.offsetX + (c * TILE_SIZE)) / layerW
                        local pctY = (expInfo.offsetY + (r * TILE_SIZE)) / layerH
                        local rectX = drawTopLeftX + (pctX * zonePixelW)
                        local rectY = drawTopLeftY + (pctY * zonePixelH)
                        local rectW = (tileW / layerW) * zonePixelW
                        local rectH = (tileH / layerH) * zonePixelH

                        local left, right = rectX / contentW, (rectX + rectW) / contentW
                        local top, bottom = rectY / contentH, (rectY + rectH) / contentH

                        if left < 0 then
                            local diff = -left * contentW; rectX = rectX + diff; rectW = rectW - diff; left = 0
                        end
                        if right > 1 then
                            local diff = (right - 1) * contentW; rectW = rectW - diff; right = 1
                        end
                        if top < 0 then
                            local diff = -top * contentH; rectY = rectY + diff; rectH = rectH - diff; top = 0
                        end
                        if bottom > 1 then
                            local diff = (bottom - 1) * contentH; rectH = rectH - diff; bottom = 1
                        end

                        if rectW > 0 and rectH > 0 then
                            local mask = f.exploredMaskPool[f.exploredMaskIndex]
                            if not mask then
                                mask = f.mapContent:CreateMaskTexture()
                                f.exploredMaskPool[f.exploredMaskIndex] = mask
                            end
                            f.exploredMaskIndex = f.exploredMaskIndex + 1

                            mask:SetTexture(fileDataID)
                            mask:SetSize(rectW, rectH)
                            mask:ClearAllPoints()
                            mask:SetPoint("TOPLEFT", f.mapContent, "TOPLEFT", rectX, -rectY)
                            pcall(function() mask:SetTexCoord(0, tileW / TILE_SIZE, 0, tileH / TILE_SIZE) end)
                            mask:Show()

                            local tex = f.exploredTexturePool:Acquire()
                            tex:SetTexture("Interface\\AddOns\\forever_track\\t1_TrackMap\\map_texture\\worldmap-forever-0.0.1.tga")
                            tex:SetDesaturated(false)
                            tex:SetVertexColor(1, 1, 1, 1)
                            tex:SetTexCoord(left, right, top, bottom)
                            tex:SetSize(rectW, rectH)
                            tex:ClearAllPoints()
                            tex:SetPoint("TOPLEFT", f.mapContent, "TOPLEFT", rectX, -rectY)
                            tex:AddMaskTexture(mask)
                            tex.activeMask = mask
                            tex:Show()
                        end
                    else
                        local drawX = (expInfo.offsetX + (c * TILE_SIZE)) * scaleX
                        local drawY = -((expInfo.offsetY + (r * TILE_SIZE)) * scaleY)
                        local drawW_scaled = tileW * scaleX
                        local drawH_scaled = tileH * scaleY

                        local tex = f.exploredTexturePool:Acquire()
                        tex:SetTexture(fileDataID)
                        tex:SetSize(drawW_scaled, drawH_scaled)
                        tex:ClearAllPoints()
                        tex:SetPoint("TOPLEFT", f.mapContent, "TOPLEFT", drawX, drawY)
                        if tex.activeMask then
                            tex:RemoveMaskTexture(tex.activeMask); tex.activeMask = nil
                        end
                        pcall(function() tex:SetTexCoord(0, tileW / TILE_SIZE, 0, tileH / TILE_SIZE) end)
                        tex:SetDesaturated(false)
                        tex:SetVertexColor(1, 1, 1, 1)
                        tex:Show()
                    end
                end
                idx = idx + 1
            end
        end
    end
end

function f:RefreshFogOfWar()
    f.fogQueue = {}
    if f.exploredTexturePool then
        for tex in f.exploredTexturePool:EnumerateActive() do
            if tex.activeMask then
                tex:RemoveMaskTexture(tex.activeMask); tex.activeMask = nil
            end
        end
        f.exploredTexturePool:ReleaseAll()
    end

    if f.exploredMaskPool then for _, mask in pairs(f.exploredMaskPool) do mask:Hide() end end
    f.exploredMaskIndex = 1

    if f.worldMapTiles and f.currentMapID == 947 then
        for _, tile in ipairs(f.worldMapTiles) do
            if f.showFogOfWar then
                tile:SetDesaturated(true); tile:SetVertexColor(0.25, 0.25, 0.25)
            else
                tile:SetDesaturated(false); tile:SetVertexColor(1, 1, 1)
            end
        end
    end

    if f.currentMapID ~= 947 and f.currentMapID ~= -1416 then
        for _, tile in ipairs(f.blizzardTiles) do
            tile:SetDesaturated(false); tile:SetVertexColor(1, 1, 1)
        end
    end

    if f.currentMapID == 947 then
        if f.showFogOfWar and T1_ZoneDB then
            for zoneID, _ in pairs(T1_ZoneDB) do
                if tonumber(zoneID) and tonumber(zoneID) > 0 then table.insert(f.fogQueue, tonumber(zoneID)) end
            end
        end
    elseif f.currentMapID ~= -1416 and f.currentMapID > 0 then
        f:DrawExploredZone(f.currentMapID)
    end
end

if not f.fogLoader then f.fogLoader = CreateFrame("Frame", nil, f) end
f.fogLoader:SetScript("OnUpdate", function(self, elapsed)
    if f.fogQueue and #f.fogQueue > 0 then
        local zonesToProcess = math.min(3, #f.fogQueue)
        for i = 1, zonesToProcess do
            local zoneID = table.remove(f.fogQueue)
            if zoneID then f:DrawExploredZone(zoneID) end
        end
    end
end)

-- ==========================================
-- Zoom & Pan Logic (and Flags / Pins)
-- ==========================================
f.zoomLevel = 1
f.mapOffsetX, f.mapOffsetY = 0, 0

function f:UpdateMapTransform()
    if not self.mapContent or not self.mapCanvas then return end
    local canvasW, canvasH = self.mapCanvas:GetSize()
    local contentW, contentH = self.mapContent:GetSize()
    if not canvasW or canvasW <= 0 or not contentW or contentW <= 0 then return end

    local absoluteMinZoom = math.max(canvasW / contentW, canvasH / contentH)
    if self.zoomLevel < absoluteMinZoom then self.zoomLevel = absoluteMinZoom end
    local maxZ = self:GetDynamicMaxZoom()
    if self.zoomLevel > maxZ then self.zoomLevel = maxZ end
    self.mapContent:SetScale(self.zoomLevel)

    local effW, effH = contentW * self.zoomLevel, contentH * self.zoomLevel
    local visualMinX, visualMaxX = canvasW - effW, 0
    local visualMinY, visualMaxY = 0, effH - canvasH
    local currentVisualX, currentVisualY = self.mapOffsetX * self.zoomLevel, self.mapOffsetY * self.zoomLevel

    if visualMinX > visualMaxX then
        currentVisualX = (canvasW - effW) / 2
    else
        if currentVisualX > visualMaxX then currentVisualX = visualMaxX end
        if currentVisualX < visualMinX then currentVisualX = visualMinX end
    end

    if visualMinY > visualMaxY then
        currentVisualY = (effH - canvasH) / 2
    else
        if currentVisualY < visualMinY then currentVisualY = visualMinY end
        if currentVisualY > visualMaxY then currentVisualY = visualMaxY end
    end

    self.mapOffsetX, self.mapOffsetY = currentVisualX / self.zoomLevel, currentVisualY / self.zoomLevel
    self.mapContent:ClearAllPoints()
    self.mapContent:SetPoint("TOPLEFT", self.mapCanvas, "TOPLEFT", self.mapOffsetX, self.mapOffsetY)

    if f.zoomText then f.zoomText:SetFormattedText("Scale: %.2fx", self.zoomLevel) end
    if f.zoomSlider then
        f.zoomSlider.isUpdating = true
        f.zoomSlider:SetValue(self.zoomLevel)
        f.zoomSlider.isUpdating = false
    end

    if not f.cityFlags then
        f.cityFlags = {}
        for key, data in pairs(cityDataByZone) do
            local flagFrame = CreateFrame("Frame", nil, self.mapContent)
            flagFrame:SetFrameLevel(self.mapContent:GetFrameLevel() + 50)
            local tex = flagFrame:CreateTexture(nil, "BACKGROUND")
            tex:SetAllPoints()
            if data.status == "Alliance" then
                tex:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
            elseif data.status == "Horde" then
                tex:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
            else
                tex:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
            end
            tex:SetTexCoord(10 / 64, 54 / 64, 10 / 64, 54 / 64)
            f.cityFlags[key] = { frame = flagFrame, tex = tex }
        end
    end

    local activeCityKey, activeCityData = GetCityDataForZone(f.currentMapID)
    local playerMap = C_Map.GetBestMapForUnit("player")
    local playerInCityID = nil
    for k, d in pairs(cityDataByZone) do
        if d.id == playerMap then
            playerInCityID = playerMap; break
        end
    end

    for key, flagObj in pairs(f.cityFlags) do
        local data = cityDataByZone[key]
        if f.currentMapID == 947 then
            flagObj.frame:Show()
            flagObj.baseOpacity = (playerInCityID and data.id ~= playerInCityID) and 0.3 or 1.0
            flagObj.tex:SetDesaturated(false)
            flagObj.tex:SetVertexColor(1, 1, 1, flagObj.baseOpacity)
            local baseWidth = (data.status == "Alliance") and (24 * 1.15) or 24
            flagObj.frame:SetSize(baseWidth / self.zoomLevel, 24 / self.zoomLevel)
            flagObj.frame:ClearAllPoints()
            local uiX, uiY = LogicalToUIPercent(data.x, data.y)
            flagObj.frame:SetPoint("CENTER", self.mapContent, "TOPLEFT", uiX * contentW, -uiY * contentH)
        elseif key == activeCityKey and data.zoneX and data.zoneY then
            flagObj.frame:Show()
            flagObj.baseOpacity = 1.0
            flagObj.tex:SetDesaturated(false)
            flagObj.tex:SetVertexColor(1, 1, 1, 1.0)
            local baseWidth = (data.status == "Alliance") and (24 * 1.15) or 24
            flagObj.frame:SetSize(baseWidth / self.zoomLevel, 24 / self.zoomLevel)
            flagObj.frame:ClearAllPoints()
            flagObj.frame:SetPoint("CENTER", self.mapContent, "TOPLEFT", data.zoneX * contentW, -data.zoneY * contentH)
        else
            flagObj.frame:Hide()
        end
    end

    if not f.pinFrames then f.pinFrames = {} end
    if not f.customPins then f.customPins = {} end
    local maxIndex = math.max(#f.customPins, #f.pinFrames)
    for i = 1, maxIndex do
        local pinData, frame = f.customPins[i], f.pinFrames[i]
        if pinData and not frame then
            frame = CreateFrame("Frame", nil, self.mapContent)
            frame:SetFrameLevel(self.mapContent:GetFrameLevel() + 60)
            local tex = frame:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints(); tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
            frame.tex = tex; f.pinFrames[i] = frame
        end
        if pinData and frame then
            frame.tex:SetVertexColor(pinData.r, pinData.g, pinData.b, 1)
            local showPin, drawX, drawY = false, 0, 0
            if f.currentMapID == pinData.mapID then
                drawX, drawY, showPin = pinData.x, pinData.y, true
            elseif f.currentMapID == 947 and T1_ZoneDB and T1_ZoneDB[pinData.mapID] then
                local zData = T1_ZoneDB[pinData.mapID]
                local zoneW = (zData.w and zData.w > 0) and zData.w or 0.05
                if zData.x and zData.y then
                    drawX = zData.x + ((pinData.x - 0.5) * zoneW)
                    drawY = zData.y + ((0.5 - pinData.y) * (zoneW / 1.5))
                    showPin = true
                end
            end
            if showPin then
                frame:Show(); frame:SetSize(24 / self.zoomLevel, 24 / self.zoomLevel)
                if frame.SetScale then frame:SetScale(1) end
                frame:ClearAllPoints()
                if f.currentMapID == 947 then
                    local uiX, uiY = LogicalToUIPercent(drawX, drawY)
                    frame:SetPoint("CENTER", self.mapContent, "TOPLEFT", uiX * contentW, -uiY * contentH)
                else
                    frame:SetPoint("CENTER", self.mapContent, "TOPLEFT", drawX * contentW, -drawY * contentH)
                end
            else
                frame:Hide()
            end
        elseif frame then
            frame:Hide()
        end
    end

    if f.currentMapID == 947 and T1_ZoneDB and f.showFogOfWar then
        if not f.debugDots then f.debugDots = {} end
        for zoneID, zData in pairs(T1_ZoneDB) do
            if tonumber(zoneID) and tonumber(zoneID) > 0 and zData.x and zData.y then
                local dotBtn = f.debugDots[zoneID]
                if not dotBtn then
                    dotBtn = CreateFrame("Button", nil, self.mapContent)
                    dotBtn:SetFrameLevel(self.mapContent:GetFrameLevel() + 90)
                    dotBtn.tex = dotBtn:CreateTexture(nil, "OVERLAY", nil, 7)
                    dotBtn.tex:SetAllPoints(); dotBtn.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_2")
                    dotBtn:SetScript("OnClick", function()
                        f:LoadMap(zoneID)
                        if f.UpdateMapTransform then f:UpdateMapTransform() end
                    end)
                    f.debugDots[zoneID] = dotBtn
                end
                dotBtn:Show(); dotBtn:SetSize(2 / self.zoomLevel, 2 / self.zoomLevel)
                dotBtn:ClearAllPoints()
                local uiX, uiY = LogicalToUIPercent(zData.x, zData.y)
                dotBtn:SetPoint("CENTER", self.mapContent, "TOPLEFT", uiX * contentW, -uiY * contentH)
            end
        end
    else
        if f.debugDots then for _, dotBtn in pairs(f.debugDots) do dotBtn:Hide() end end
    end

    if f.DrawHoverPolygon then f:DrawHoverPolygon(f.mapCanvas.hoveredMapID) end
    if f.RefreshQuestPins then f:RefreshQuestPins() end
    if f.RefreshNPCPins then f:RefreshNPCPins() end
    if f.RefreshFlightPins then f:RefreshFlightPins() end
end

f.mapCanvas:EnableMouseWheel(true)
f.targetZoom = f.zoomLevel or 1
f.zoomSmoother = CreateFrame("Frame", nil, f.mapCanvas)
f.zoomSmoother:Hide()

f.zoomSmoother:SetScript("OnUpdate", function(self, elapsed)
    local isAnimating = false
    local oldZoom = f.zoomLevel
    local targetZ = f.targetZoom or oldZoom
    local diffZ = targetZ - oldZoom
    local lerpRate = 1 - math.exp(-14 * elapsed)

    if math.abs(diffZ) > 0.002 then
        isAnimating = true
        local newZoom = oldZoom + diffZ * lerpRate
        if not f.targetOffsetX and (not f.velocityX or f.velocityX == 0) then
            local pivotX = f.zoomPivotX or (f.mapCanvas:GetWidth() / 2)
            local pivotY = f.zoomPivotY or (-(f.mapCanvas:GetHeight() / 2))
            f.mapOffsetX = f.mapOffsetX + pivotX * ((1 / newZoom) - (1 / oldZoom))
            f.mapOffsetY = f.mapOffsetY + pivotY * ((1 / newZoom) - (1 / oldZoom))
        end
        f.zoomLevel = newZoom
    else
        f.zoomLevel = targetZ
    end

    if f.targetOffsetX and f.targetOffsetY then
        isAnimating = true
        local diffX, diffY = f.targetOffsetX - f.mapOffsetX, f.targetOffsetY - f.mapOffsetY
        f.mapOffsetX = f.mapOffsetX + diffX * lerpRate
        f.mapOffsetY = f.mapOffsetY + diffY * lerpRate
        if math.abs(diffX) < 0.1 and math.abs(diffY) < 0.1 then
            f.mapOffsetX, f.mapOffsetY = f.targetOffsetX, f.targetOffsetY
            f.targetOffsetX, f.targetOffsetY = nil, nil
        end
    elseif f.velocityX and f.velocityY and (math.abs(f.velocityX) > 1 or math.abs(f.velocityY) > 1) then
        isAnimating = true
        local friction = math.exp(-7 * elapsed)
        f.mapOffsetX = f.mapOffsetX + (f.velocityX * elapsed)
        f.mapOffsetY = f.mapOffsetY + (f.velocityY * elapsed)
        f.velocityX, f.velocityY = f.velocityX * friction, f.velocityY * friction
        if math.abs(f.velocityX) < 10 and math.abs(f.velocityY) < 10 then f.velocityX, f.velocityY = 0, 0 end
    end
    f:UpdateMapTransform()
    if not isAnimating then self:Hide() end
end)

f.mapCanvas:SetScript("OnMouseWheel", function(self, delta)
    local maxZ = f.GetDynamicMaxZoom and f:GetDynamicMaxZoom() or 20
    local scaleFactor = (delta > 0) and 1.22 or (1 / 1.22)
    local currentTarget = f.targetZoom or f.zoomLevel
    f.targetZoom = math.max(1, math.min(maxZ, currentTarget * scaleFactor))

    local cX, cY = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale()
    f.zoomPivotX = (cX / uiScale) - self:GetLeft()
    f.zoomPivotY = (cY / uiScale) - self:GetTop()
    f.targetOffsetX, f.targetOffsetY = nil, nil
    f.velocityX, f.velocityY = 0, 0
    if f.zoomSmoother then f.zoomSmoother:Show() end
end)

function f:ZoomToPoint(pctX, pctY, targetZoom)
    if not pctX or not pctY then return end
    targetZoom = math.max(1, math.min(targetZoom or 5, self.GetDynamicMaxZoom and self:GetDynamicMaxZoom() or 10))
    local canvasW, canvasH = self.mapCanvas:GetSize()
    local contentW, contentH = self.mapContent:GetSize()
    if canvasW and canvasH and contentW and contentH then
        self.targetZoom = targetZoom
        self.targetOffsetX = ((canvasW / 2) - ((pctX * contentW) * targetZoom)) / targetZoom
        self.targetOffsetY = (-(canvasH / 2) - ((-pctY * contentH) * targetZoom)) / targetZoom
        if self.zoomSmoother then self.zoomSmoother:Show() end
    end
end

function f:ZoomToZone(zoneID)
    if f.currentMapID ~= 947 or not zoneID or zoneID <= 0 then return end
    if T1_ZoneDB and T1_ZoneDB[zoneID] then
        local zData = T1_ZoneDB[zoneID]
        local zoneW = (zData.w and zData.w > 0) and zData.w or 0.05
        if zData.x and zData.y then
            local uiX, uiY = LogicalToUIPercent(zData.x, zData.y)
            f:ZoomToPoint(uiX, uiY, math.min(1.5 / math.max(zoneW * 1.3, 0.10), 1.0 / math.max(zoneW * 1.3, 0.10)))
        end
    end
end

local function GetDalaranLocalCoords(rawX, rawY)
    local wX, wY = rawX, rawY
    if T1_ZoneDB and T1_ZoneDB[1416] then
        local zData = T1_ZoneDB[1416]
        local zoneW = (zData.w and zData.w > 0) and zData.w or 0.05
        if zData.x and zData.y then
            wX = zData.x + ((rawX - 0.5) * zoneW)
            wY = zData.y + ((0.5 - rawY) * (zoneW / 1.5))
        end
    end
    return (14.6444 * wX) - (32.8666 * wY) + 1.2725, (-33.2444 * wX) - (18.5333 * wY) + 15.0464
end

function f:ZoomFitPlayerAndPin()
    if f.currentMapID ~= 947 then return end
    local pX, pY = f.playerArrow and f.playerArrow.pX, f.playerArrow and f.playerArrow.pY
    local pinX, pinY = nil, nil
    if f.customPins and #f.customPins > 0 then
        local pinData = f.customPins[#f.customPins]
        if pinData.mapID == 947 then
            pinX, pinY = pinData.x, pinData.y
        elseif T1_ZoneDB and T1_ZoneDB[pinData.mapID] then
            local zData = T1_ZoneDB[pinData.mapID]
            local zoneW = (zData.w and zData.w > 0) and zData.w or 0.05
            if zData.x and zData.y then
                pinX = zData.x + ((pinData.x - 0.5) * zoneW)
                pinY = zData.y + ((0.5 - pinData.y) * (zoneW / 1.5))
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

    local distW, distH = maxX - minX, maxY - minY
    local targetZoom = math.min(1.5 / math.max(distW * 1.5, 0.10), 1.0 / math.max(distH * 1.5, 0.10))
    local centerUI_X, centerUI_Y = LogicalToUIPercent((minX + maxX) / 2, (minY + maxY) / 2)
    f:ZoomToPoint(centerUI_X, centerUI_Y, targetZoom)
end

-- ==========================================
-- Exposed Map APIs
-- ==========================================
f.customPins = {}
_G.func_T1_AddPin = function(mapID, localX, localY, r, g, b)
    if localX and localX > 1 then localX = localX / 100 end
    if localY and localY > 1 then localY = localY / 100 end
    table.insert(f.customPins, { mapID = mapID, x = localX, y = localY, r = r or 0, g = g or 1, b = b or 1 })
    if f:IsShown() and f.UpdateMapTransform then f:UpdateMapTransform() end
    if f:IsShown() and f.ZoomFitPlayerAndPin then f:ZoomFitPlayerAndPin() end
    if C_Map.CanSetUserWaypointOnMap(mapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, localX, localY))
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
end
_G.func_T1_ClearPins = function(skipUpdate)
    wipe(f.customPins)
    if not skipUpdate and f:IsShown() and f.UpdateMapTransform then f:UpdateMapTransform() end
    if C_Map.HasUserWaypoint() then C_Map.ClearUserWaypoint() end
end
_G.func_T1_SetPin = function(mapID, localX, localY, r, g, b)
    _G.func_T1_ClearPins(true)
    _G.func_T1_AddPin(mapID, localX, localY, r, g, b)
end

-- ==========================================
-- Live Trackers
-- ==========================================
local function IsCustomCityMap(mapID)
    if not mapID or mapID == 0 then return false end
    for _, data in pairs(cityDataByZone) do if data.id == mapID then return true end end
    return false
end

local function ConvertToCitySpace(unitMapID, rawX, rawY, targetCityID)
    if not unitMapID or unitMapID <= 0 or not targetCityID or targetCityID == 0 then return false, 0, 0 end
    local cityData = nil
    for _, data in pairs(cityDataByZone) do
        if data.id == targetCityID then
            cityData = data; break
        end
    end
    if not cityData then return false, 0, 0 end

    if cityData.zoneID == unitMapID and cityData.zoneX and cityData.zoneY then
        return true, ((rawX - cityData.zoneX) * (cityData.cityScaleX or 5.0)) + 0.5,
            0.5 - ((cityData.zoneY - rawY) * (cityData.cityScaleY or 5.0))
    end
    if T1_ZoneDB and T1_ZoneDB[unitMapID] then
        local zData = T1_ZoneDB[unitMapID]
        local zoneW = (zData.w and zData.w > 0) and zData.w or 0.05
        if zData.x and zData.y then
            local worldX = zData.x + ((rawX - 0.5) * zoneW)
            local worldY = zData.y + ((0.5 - rawY) * (zoneW / 1.5))
            local cityW = (cityData.w and cityData.w > 0) and cityData.w or 0.14
            return true, ((worldX - (cityData.x or 0)) / cityW) + 0.5,
                0.5 - ((worldY - (cityData.y or 0)) / (cityW / 1.5))
        end
    end
    return false, 0, 0
end

f.playerArrow = f.mapContent:CreateTexture(nil, "OVERLAY")
f.playerArrow:SetTexture("Interface\\Minimap\\MinimapArrow")
f.playerArrow:SetDrawLayer("OVERLAY", 7)
f.playerArrowTracker = CreateFrame("Frame", nil, f.mapCanvas)
f.playerArrowTracker:SetScript("OnUpdate", function()
    local hasValidData, pX, pY = false, 0, 0
    local currentZoneID = C_Map.GetBestMapForUnit("player")

    if currentZoneID and currentZoneID > 0 then
        local pos = C_Map.GetPlayerMapPosition(currentZoneID, "player")
        if pos and pos.x and pos.y then
            if currentZoneID == 1416 then
                local dalX, dalY = GetDalaranLocalCoords(pos.x, pos.y)
                local isInside = (dalX >= 0.10 and dalX <= 0.82 and dalY >= 0.03 and dalY <= 0.93)
                if f.lastDalaranState == nil then
                    f.lastDalaranState = isInside
                elseif f.lastDalaranState ~= isInside then
                    f.lastDalaranState = isInside
                    if f:IsShown() then
                        if isInside and f.currentMapID ~= -1416 then
                            f:LoadMap(-1416)
                        elseif not isInside and f.currentMapID == -1416 then
                            f:LoadMap(947)
                        end
                        if f.UpdateMapTransform then f:UpdateMapTransform() end
                    end
                end
            else
                f.lastDalaranState = nil
            end

            if f.currentMapID == 947 then
                if T1_ZoneDB and T1_ZoneDB[currentZoneID] then
                    local zoneData = T1_ZoneDB[currentZoneID]
                    local zoneW = (zoneData.w and zoneData.w > 0) and zoneData.w or 0.05
                    if zoneData.x and zoneData.y then
                        pX, pY, hasValidData = zoneData.x + ((pos.x - 0.5) * zoneW),
                            zoneData.y + ((0.5 - pos.y) * (zoneW / 1.5)), true
                    end
                end
            elseif f.currentMapID == -1416 and currentZoneID == 1416 then
                pX, pY, hasValidData = GetDalaranLocalCoords(pos.x, pos.y)
                hasValidData = true
            elseif f.currentMapID == currentZoneID then
                pX, pY, hasValidData = pos.x, pos.y, true
            elseif IsCustomCityMap(f.currentMapID) then
                hasValidData, pX, pY = ConvertToCitySpace(currentZoneID, pos.x, pos.y, f.currentMapID)
            end
        end
    end

    if hasValidData then
        f.playerArrow:Show(); f.playerArrow:SetSize(32 / f.zoomLevel, 32 / f.zoomLevel)
        local facing = GetPlayerFacing()
        if facing then f.playerArrow:SetRotation(f.currentMapID == -1416 and facing + math.rad(61.5) or facing) end
        f.playerArrow.pX, f.playerArrow.pY = pX, pY
        local drawUI_X, drawUI_Y = f.currentMapID == 947 and LogicalToUIPercent(pX, pY) or pX,
            f.currentMapID == 947 and select(2, LogicalToUIPercent(pX, pY)) or pY
        f.playerArrow:SetPoint("CENTER", f.mapContent, "TOPLEFT", drawUI_X * f.mapContent:GetWidth(),
            -drawUI_Y * f.mapContent:GetHeight())
    else
        f.playerArrow:Hide(); f.playerArrow.pX, f.playerArrow.pY = nil, nil
    end
end)

if not f.partyFrames then
    f.partyFrames = {}
    for i = 1, 4 do
        local pf = CreateFrame("Frame", nil, f.mapContent)
        pf:SetFrameLevel(f.mapContent:GetFrameLevel() + 5); pf:EnableMouse(true)
        pf:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" and self.pX and self.pY then
                local targetX, targetY = f.currentMapID == 947 and LogicalToUIPercent(self.pX, self.pY) or self.pX,
                    f.currentMapID == 947 and select(2, LogicalToUIPercent(self.pX, self.pY)) or self.pY
                f:ZoomToPoint(targetX, targetY, 6)
            end
        end)
        pf.tex = pf:CreateTexture(nil, "OVERLAY"); pf.tex:SetAllPoints(); pf.tex:SetTexture(
            "Interface\\CharacterFrame\\TempPortraitAlphaMask")
        f.partyFrames[i] = pf
    end
end

if not f.partyTracker then f.partyTracker = CreateFrame("Frame", nil, f.mapCanvas) end
f.partyTracker:SetScript("OnUpdate", function()
    local contentW, contentH = f.mapContent:GetSize()
    for i = 1, 4 do
        local unit, pf, showPartyMember, drawX, drawY = "party" .. i, f.partyFrames[i], false, 0, 0
        if UnitExists(unit) and UnitIsConnected(unit) then
            local unitMapID = C_Map.GetBestMapForUnit(unit)
            if unitMapID and unitMapID > 0 then
                local pos = C_Map.GetPlayerMapPosition(unitMapID, unit)
                if pos and pos.x and pos.y then
                    if f.currentMapID == 947 then
                        if T1_ZoneDB and T1_ZoneDB[unitMapID] then
                            local zData = T1_ZoneDB[unitMapID]
                            local zoneW = (zData.w and zData.w > 0) and zData.w or 0.05
                            if zData.x and zData.y then
                                drawX, drawY, showPartyMember = zData.x + ((pos.x - 0.5) * zoneW),
                                    zData.y + ((0.5 - pos.y) * (zoneW / 1.5)), true
                            end
                        end
                    elseif f.currentMapID == -1416 and unitMapID == 1416 then
                        drawX, drawY = GetDalaranLocalCoords(pos.x, pos.y); showPartyMember = true
                    elseif f.currentMapID == unitMapID then
                        drawX, drawY, showPartyMember = pos.x, pos.y, true
                    elseif IsCustomCityMap(f.currentMapID) then
                        showPartyMember, drawX, drawY = ConvertToCitySpace(unitMapID, pos.x, pos.y, f.currentMapID)
                    end
                end
            end
        end
        if showPartyMember then
            local _, classFilename = UnitClass(unit)
            if classFilename and RAID_CLASS_COLORS[classFilename] then
                local c = RAID_CLASS_COLORS[classFilename]; pf.tex:SetVertexColor(c.r, c.g, c.b, 1)
            else
                pf.tex:SetVertexColor(0.5, 0.5, 1, 1)
            end
            pf.pX, pf.pY = drawX, drawY
            local drawUI_X, drawUI_Y = f.currentMapID == 947 and LogicalToUIPercent(drawX, drawY) or drawX,
                f.currentMapID == 947 and select(2, LogicalToUIPercent(drawX, drawY)) or drawY
            pf:Show(); pf:SetSize(6 / f.zoomLevel, 6 / f.zoomLevel)
            if pf.SetScale then pf:SetScale(1) end
            pf:ClearAllPoints(); pf:SetPoint("CENTER", f.mapContent, "TOPLEFT", drawUI_X * contentW, -drawUI_Y * contentH)
        else
            pf:Hide(); pf.pX, pf.pY = nil, nil
        end
    end
end)

f.corpseFrame = CreateFrame("Frame", nil, f.mapContent)
f.corpseFrame:SetFrameLevel(f.mapContent:GetFrameLevel() + 55)
f.corpseTex = f.corpseFrame:CreateTexture(nil, "OVERLAY"); f.corpseTex:SetAllPoints(); f.corpseTex:SetTexture(
    "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
f.corpseFrame:Hide()

if not f.deathTracker then f.deathTracker = CreateFrame("Frame", nil, f.mapCanvas) end
f.deathTracker:SetScript("OnUpdate", function()
    local hasCorpse, cX, cY = false, 0, 0
    if UnitIsDeadOrGhost("player") then
        local currentZoneID = C_Map.GetBestMapForUnit("player")
        if currentZoneID and currentZoneID > 0 and C_DeathInfo then
            local corpsePos = C_DeathInfo.GetCorpseMapPosition and C_DeathInfo.GetCorpseMapPosition(currentZoneID)
            if corpsePos and corpsePos.x and corpsePos.y then
                if f.currentMapID == 947 then
                    if T1_ZoneDB and T1_ZoneDB[currentZoneID] then
                        local zData = T1_ZoneDB[currentZoneID]
                        local zoneW = (zData.w and zData.w > 0) and zData.w or 0.05
                        if zData.x and zData.y then
                            cX, cY, hasCorpse = zData.x + ((corpsePos.x - 0.5) * zoneW),
                                zData.y + ((0.5 - corpsePos.y) * (zoneW / 1.5)), true
                        end
                    end
                elseif f.currentMapID == -1416 and currentZoneID == 1416 then
                    cX, cY = GetDalaranLocalCoords(corpsePos.x, corpsePos.y); hasCorpse = true
                elseif f.currentMapID == currentZoneID then
                    cX, cY, hasCorpse = corpsePos.x, corpsePos.y, true
                elseif IsCustomCityMap(f.currentMapID) then
                    hasCorpse, cX, cY = ConvertToCitySpace(currentZoneID, corpsePos.x, corpsePos.y, f.currentMapID)
                end
            end
        end
    end
    if hasCorpse then
        local drawUI_X, drawUI_Y = f.currentMapID == 947 and LogicalToUIPercent(cX, cY) or cX,
            f.currentMapID == 947 and select(2, LogicalToUIPercent(cX, cY)) or cY
        f.corpseFrame:Show(); f.corpseFrame:SetSize(12 / f.zoomLevel, 12 / f.zoomLevel)
        if f.corpseFrame.SetScale then f.corpseFrame:SetScale(1) end
        f.corpseFrame:ClearAllPoints(); f.corpseFrame:SetPoint("CENTER", f.mapContent, "TOPLEFT",
            drawUI_X * f.mapContent:GetWidth(), -drawUI_Y * f.mapContent:GetHeight())
    else
        f.corpseFrame:Hide()
    end
end)

if not f.flagHoverTracker then f.flagHoverTracker = CreateFrame("Frame", nil, f.mapCanvas) end
f.flagHoverTracker:SetScript("OnUpdate", function()
    if not f.cityFlags then return end
    if f.currentMapID == 947 then
        local rawX, rawY = GetCursorPosition()
        local left, top = f.mapContent:GetLeft(), f.mapContent:GetTop()
        if not left or not top then return end
        local logicalMouseX, logicalMouseY = UIPercentToLogical(
            ((rawX / f.mapContent:GetEffectiveScale()) - left) / f.mapContent:GetWidth(),
            (top - (rawY / f.mapContent:GetEffectiveScale())) / f.mapContent:GetHeight())
        local CLICK_RADIUS_SQ = 0.0006 / (f.zoomLevel * f.zoomLevel)
        for key, flagObj in pairs(f.cityFlags) do
            if cityDataByZone[key] then
                local dx, dy = (cityDataByZone[key].x or 0) - logicalMouseX, (cityDataByZone[key].y or 0) - logicalMouseY
                if (dx * dx) + (dy * dy) <= CLICK_RADIUS_SQ then
                    flagObj.tex:SetVertexColor(1, 1, 1, 0.7)
                else
                    flagObj
                        .tex:SetVertexColor(1, 1, 1, flagObj.baseOpacity or 1)
                end
            end
        end
    else
        local cityKey = GetCityDataForZone(f.currentMapID)
        if cityKey and f.cityFlags[cityKey] then
            if f.mapCanvas.hoveredCityID then
                f.cityFlags[cityKey].tex:SetVertexColor(1, 1, 1, 0.7)
            else
                f.cityFlags
                    [cityKey].tex:SetVertexColor(1, 1, 1, 1.0)
            end
        end
    end
end)

-- ==========================================
-- Auto-Refresh & Events
-- ==========================================
f.explorationTracker = CreateFrame("Frame")
f.explorationTracker:RegisterEvent("ZONE_CHANGED")
f.explorationTracker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f.explorationTracker:RegisterEvent("ZONE_CHANGED_INDOORS")
pcall(function() f.explorationTracker:RegisterEvent("MAP_EXPLORATION_UPDATED") end)
f.explorationTracker:SetScript("OnEvent",
    function() if f:IsShown() and f.showFogOfWar and f.RefreshFogOfWar then f:RefreshFogOfWar() end end)

f.zoneTracker = CreateFrame("Frame")
f.zoneTracker:RegisterEvent("ZONE_CHANGED")
f.zoneTracker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f.zoneTracker:RegisterEvent("ZONE_CHANGED_INDOORS")
f.zoneTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
f.zoneTracker:RegisterEvent("QUEST_LOG_UPDATE")

f.lastPlayerZone = nil

f.zoneTracker:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        f:Hide()
        return
    end

    local currentPlayerZone = C_Map.GetBestMapForUnit("player")
    if not currentPlayerZone or currentPlayerZone <= 0 or f.lastPlayerZone == currentPlayerZone then return end
    f.lastPlayerZone = currentPlayerZone
    if not f:IsShown() then return end

    if currentPlayerZone == 1416 then
        local pos = C_Map.GetPlayerMapPosition(1416, "player")
        if pos and pos.x and pos.y then
            local dalX, dalY = GetDalaranLocalCoords(pos.x, pos.y)
            if (dalX >= 0.10 and dalX <= 0.82 and dalY >= 0.03 and dalY <= 0.93) then f:LoadMap(-1416) else f:LoadMap(947) end
            if f.UpdateMapTransform then f:UpdateMapTransform() end
        end
    elseif T1.IsCustomCityMap(currentPlayerZone) then
        f:LoadMap(currentPlayerZone)
        if f.UpdateMapTransform then f:UpdateMapTransform() end
    elseif f.currentMapID ~= 947 then
        f:LoadMap(947)
        if f.ZoomToZone then f:ZoomToZone(currentPlayerZone) end
        if f.UpdateMapTransform then f:UpdateMapTransform() end
    end
end)


if T1_OutlineDB then
    for id, outlineData in pairs(T1_OutlineDB) do
        if outlineData.loops then
            local minX, maxX, minY, maxY = 999, -999, 999, -999
            for _, loop in ipairs(outlineData.loops) do
                for _, pt in ipairs(loop) do
                    if pt.x < minX then minX = pt.x end
                    if pt.x > maxX then maxX = pt.x end
                    if pt.y < minY then minY = pt.y end
                    if pt.y > maxY then maxY = pt.y end
                end
            end
            outlineData.bounds = { minX = minX, maxX = maxX, minY = minY, maxY = maxY }
        end
    end
end

--


f:SetScript("OnShow", function(self)
    if not self.currentMapID then
        local playerMap = C_Map.GetBestMapForUnit("player")
        local defaultMap = 947
        if playerMap == 1416 then
            defaultMap = -1416
        elseif T1.IsCustomCityMap(playerMap) then
            defaultMap = playerMap
        end

        self:LoadMap(defaultMap)
        if defaultMap == 947 and playerMap and playerMap > 0 then self:ZoomToZone(playerMap) end
    end
    if self.UpdateMapTransform then self:UpdateMapTransform() end
end)





-- ==========================================
-- Custom Window Focus Visuals & Gamepad Blocker
-- ==========================================
f.focusBorder = CreateFrame("Frame", nil, f, "BackdropTemplate")
-- Expand the border slightly outside the frame for a better glow outline
f.focusBorder:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
f.focusBorder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
f.focusBorder:SetFrameLevel(f:GetFrameLevel() + 20)
f.focusBorder:EnableMouse(false)

f.focusBorder:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 3, -- Thicker border for a better glow
})

-- Create the smooth "Breathing" Glow Animation
f.focusBorder.glowAnim = f.focusBorder:CreateAnimationGroup()
f.focusBorder.glowAnim:SetLooping("BOUNCE") -- Automatically reverses back and forth

local alphaPulse = f.focusBorder.glowAnim:CreateAnimation("Alpha")
alphaPulse:SetFromAlpha(0.3) -- Dims to 30% opacity
alphaPulse:SetToAlpha(1.0)   -- Glows to 100% opacity
alphaPulse:SetDuration(1.0)  -- 1 second per pulse
alphaPulse:SetSmoothing("IN_OUT")

-- 1. Create the invisible pad blocker
f.padBlocker = CreateFrame("Button", "T1_PadBlocker", UIParent)
f.padBlocker:SetScript("OnClick", function() end)

local padKeysToBlock = {
    "PAD1", "PAD2", "PAD3", "PAD4",
    "PADFORWARD",
    "PADLSHOULDER", "PADRSHOULDER",
    "PADDPADUP", "PADDPADDOWN", "PADDPADLEFT", "PADDPADRIGHT",
    "PADLSTICK", "PADRSTICK"
}

f.isMapFocused = false
function f:SetMapFocus(focused)
    f.isMapFocused = focused
    if focused then
        -- Show the frame and ignite the gold color
        f.focusBorder:Show() 
        f.focusBorder:SetBackdropBorderColor(1, 0.82, 0, 1) 
        f.focusBorder.glowAnim:Play() 
        
        if not InCombatLockdown() then
            for _, key in ipairs(padKeysToBlock) do
                SetOverrideBindingClick(f.padBlocker, true, key, "T1_PadBlocker")
                SetOverrideBindingClick(f.padBlocker, true, "PADLTRIGGER-" .. key, "T1_PadBlocker")
            end
        end
    else
        -- Physically hide the frame to remove the black ghosting
        f.focusBorder:Hide() 
        f.focusBorder.glowAnim:Stop() 
        
        if not InCombatLockdown() then
            ClearOverrideBindings(f.padBlocker)
        end
    end
end

-- Ensure it starts completely hidden instead of transparent
f.focusBorder:Hide()

f.focusBorder:SetBackdropBorderColor(0, 0, 0, 0)

-- Auto-Focus Triggers
f:HookScript("OnShow", function() f:SetMapFocus(false) end)
f.mapCanvas:HookScript("OnMouseDown", function() f:SetMapFocus(true) end)
f:HookScript("OnMouseDown", function() f:SetMapFocus(true) end)
f:HookScript("OnHide", function() f:SetMapFocus(false) end)

local focusWatcher = CreateFrame("Frame")
focusWatcher:RegisterEvent("GLOBAL_MOUSE_DOWN")
focusWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")

focusWatcher:SetScript("OnEvent", function(self, event)
    if event == "GLOBAL_MOUSE_DOWN" then
        if f:IsShown() and not f:IsMouseOver() and not f.mapCanvas:IsMouseOver() then
            f:SetMapFocus(false)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if f.isMapFocused then f:SetMapFocus(false) end
    end
end)

hooksecurefunc("ShowUIPanel", function(frame)
    if frame and frame ~= f and f.isMapFocused then f:SetMapFocus(false) end
end)

hooksecurefunc("ToggleFrame", function(frame)
    if frame and frame ~= f and f.isMapFocused then f:SetMapFocus(false) end
end)




--print("|cFF00FF00t1_TrackMap UI Built! Type /t1 or Ctrl+Numpad 1|r")
