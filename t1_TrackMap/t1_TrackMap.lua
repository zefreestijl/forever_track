-- ==========================================
-- 1. Create the Main Frame
-- ==========================================
local f = CreateFrame("Frame", "t1_TrackMap", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(916, 640)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:SetFrameLevel(10)

f:SetResizable(true)
if f.SetResizeBounds then
    f:SetResizeBounds(304, 210, 1216, 840)
else
    f:SetMinResize(304, 210)
    f:SetMaxResize(1216, 840)
end

function f:GetDynamicMaxZoom()
    local w = self:GetWidth() or 916
    -- Scale from 20x (at 304 width) to 10x (at 1216 width)
    local maxZoom = 20 - ((w - 304) / (1216 - 304)) * 10

    -- Clamp the values strictly between 10 and 20 just to be safe
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
    ["elwynn-forest"] = { name = "Stormwind", id = 1453, status = "Alliance", x = 0.716, y = 0.631 },
    ["durotar"] = { name = "Orgrimmar", id = 1454, status = "Horde", x = 0.297, y = 0.435 },
    ["dun-morogh"] = { name = "Ironforge", id = 1455, status = "Alliance", x = 0.755, y = 0.488 },
    ["mulgore"] = { name = "Thunder Bluff", id = 1456, status = "Horde", x = 0.200, y = 0.529 },
    ["teldrassil"] = { name = "Darnassus", id = 1457, status = "Alliance", x = 0.140, y = 0.160 },
    ["tirisfal-glades"] = { name = "Undercity", id = 1458, status = "Horde", x = 0.728, y = 0.274 },
    ["alterac-mountains"] = { name = "Dalaran", id = 1416, status = "Neutral", x = 0.726, y = 0.328, w = 0.14, h = 0.08, scale = 3.5 },
}


-- ==========================================
-- Map Toggle & Return Button (Top Left)
-- ==========================================
f.showFogOfWar = true
f.MapToggleButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.MapToggleButton:SetSize(110, 20)
f.MapToggleButton:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
f.MapToggleButton:SetText("Hide Mist")
f.MapToggleButton:SetNormalFontObject("GameFontNormalSmall")
f.MapToggleButton:SetHighlightFontObject("GameFontHighlightSmall")

f.MapToggleButton:SetScript("OnClick", function()
    local MY_CUSTOM_WORLD_MAP_ID = 947
    local previousMapID = f.currentMapID

    if previousMapID ~= MY_CUSTOM_WORLD_MAP_ID then
        -- 1. Returning from a City / Dalaran back to the World Map
        f:LoadMap(MY_CUSTOM_WORLD_MAP_ID)

        local activeCity = nil
        for _, data in pairs(cityDataByZone) do
            if data.id == previousMapID then
                activeCity = data
                break
            end
        end

        if activeCity then
            local pinX, pinY = nil, nil
            if f.customPins and #f.customPins > 0 then
                local pinData = f.customPins[#f.customPins]
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

            if pinX and pinY then
                local minX = math.min(activeCity.x, pinX)
                local maxX = math.max(activeCity.x, pinX)
                local minY = math.min(activeCity.y, pinY)
                local maxY = math.max(activeCity.y, pinY)
                local boxW = math.max((maxX - minX) * 1.5, 0.10)
                local boxH = math.max((maxY - minY) * 1.5, 0.10)
                f:ZoomToPoint((minX + maxX) / 2, (minY + maxY) / 2, math.min(1 / boxW, 1 / boxH))
            else
                f:ZoomToPoint(activeCity.x, activeCity.y, 4)
            end
        else
            f:ZoomToPoint(0.5, 0.5, 1)
        end
    else
        -- 2. On World Map: Toggle Mist on/off
        f.showFogOfWar = not f.showFogOfWar
        if f.RefreshFogOfWar then f:RefreshFogOfWar() end
        f.MapToggleButton:SetText(f.showFogOfWar and "Hide Mist" or "Show Mist")
    end

    if f.UpdateMapTransform then f:UpdateMapTransform() end
end)

-- ==========================================
-- Zoom Slider (Top Right)
-- ==========================================
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
    -- Prevent infinite loops when UpdateMapTransform moves the slider visually
    if self.isUpdating then return end
    if f.targetZoom == value then return end

    -- 1. Update the target scale for the smoother to chase
    f.targetZoom = value

    local canvasW, canvasH = f.mapCanvas:GetSize()
    local contentW, contentH = f.mapContent:GetSize()

    if canvasW and canvasH and contentW and contentH then
        -- 2. Determine the focal point for the zoom
        if f.playerArrow and f.playerArrow:IsShown() and f.playerArrow.pX and f.playerArrow.pY then
            -- Pivot around the player's current visual coordinate on the canvas
            local exactPixelX = f.playerArrow.pX * contentW
            local exactPixelY = -f.playerArrow.pY * contentH
            f.zoomPivotX = (f.mapOffsetX + exactPixelX) * f.zoomLevel
            f.zoomPivotY = (f.mapOffsetY + exactPixelY) * f.zoomLevel
        else
            -- Default pivot: center of the map canvas
            f.zoomPivotX = canvasW / 2
            f.zoomPivotY = -canvasH / 2
        end
    end

    -- 3. Activate the animation loop
    if f.zoomSmoother then
        f.zoomSmoother:Show()
    end
end)


-- ==========================================
-- Live Zoom Scale Display
-- ==========================================
f.zoomUI = CreateFrame("Frame", nil, f)
f.zoomUI:SetAllPoints(f.mapCanvas)
f.zoomUI:SetFrameLevel(f:GetFrameLevel() + 5)

f.zoomText = f.zoomUI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
f.zoomText:SetPoint("TOPLEFT", f.zoomUI, "TOPLEFT", 5, -5)
f.zoomText:SetJustifyH("LEFT")
f.zoomText:SetText("Scale: 1.00x")

f.showFogOfWar = true



-- ==========================================
-- Aspect Ratio Lock
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

        if newWidth < 304 then newWidth = 304 end
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

    -- NEW: Update the slider's maximum limit dynamically when resized
    if self.zoomSlider then
        local currentMin, _ = self.zoomSlider:GetMinMaxValues()
        self.zoomSlider:SetMinMaxValues(currentMin, self:GetDynamicMaxZoom())
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

    -- Catch the map: kill all active animations and velocity
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

        -- If it was a drag (not a click) and velocity is high, throw the map!
        if dragDistance >= 25 then
            if f.velocityX and f.velocityY and (math.abs(f.velocityX) > 50 or math.abs(f.velocityY) > 50) then
                if f.zoomSmoother then f.zoomSmoother:Show() end
            end
        else
            -- Clear velocity if it was just a regular click
            f.velocityX = 0
            f.velocityY = 0
        end
    end

    if dragDistance < 25 then
        if button == "RightButton" then
            local targetMapID = (f.currentMapID == MY_CUSTOM_WORLD_MAP_ID) and self.hoveredMapID or f.currentMapID
            if _G.func_ToggleT2Window then
                _G.func_ToggleT2Window(targetMapID)
            else
                print("|cffff2020T1_TrackMap:|r T2_TrackNPC addon is not loaded.")
            end
        elseif button == "MiddleButton" then
            local currentTime = GetTime()

            if self.lastMiddleClickTime and (currentTime - self.lastMiddleClickTime < 0.3) then
                self.lastMiddleClickTime = 0

                -- Double Click: Smoothly zoom fit to global map
                local canvasW, canvasH = self:GetSize()
                local contentW, contentH = f.mapContent:GetSize()
                if canvasW and canvasH and contentW and contentH then
                    local fitScale = math.min(canvasW / contentW, canvasH / contentH)
                    if fitScale < 1 then fitScale = 1 end

                    local maxZ = f.GetDynamicMaxZoom and f:GetDynamicMaxZoom() or 10
                    if fitScale > maxZ then fitScale = maxZ end

                    -- Feed the animation targets instead of setting them instantly
                    f.targetZoom = fitScale
                    f.targetOffsetX = ((canvasW - (contentW * fitScale)) / 2) / fitScale
                    f.targetOffsetY = (-(canvasH - (contentH * fitScale)) / 2) / fitScale

                    if f.zoomSmoother then f.zoomSmoother:Show() end
                end
            else
                -- Single Click: Load city map or zoom to player's zone
                self.lastMiddleClickTime = currentTime
                local playerMap = C_Map.GetBestMapForUnit("player")

                if playerMap then
                    -- Check if the player's current map is a recognized city
                    local isCity = false
                    for _, data in pairs(cityDataByZone) do
                        if data.id == playerMap then
                            isCity = true
                            break
                        end
                    end

                    if isCity and f.currentMapID ~= playerMap then
                        -- Player is in a city and viewing a different map: open the city map
                        f.zoomLevel = 1
                        f.mapOffsetX = 0
                        f.mapOffsetY = 0
                        f:LoadMap(playerMap)

                        -- Clear active animations
                        f.targetOffsetX = nil
                        f.targetOffsetY = nil
                        f.velocityX = 0
                        f.velocityY = 0
                        if f.zoomSmoother then f.zoomSmoother:Hide() end

                        if f.UpdateMapTransform then f:UpdateMapTransform() end
                    else
                        -- Player is in a normal zone or already on the city map: smooth zoom
                        f:ZoomToZone(playerMap)
                    end
                end
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
f.cursorTooltip:SetFrameStrata("TOOLTIP")
f.cursorTooltip:SetFrameLevel(f:GetFrameLevel() + 20)
f.cursorTooltip:Hide()

f.cursorTooltip.text = f.cursorTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
f.cursorTooltip.text:SetPoint("CENTER", f.cursorTooltip, "CENTER", 0, 0)

f.mapCanvas:SetScript("OnUpdate", function(self, elapsed)
    elapsed = elapsed or (1 / 60)

    -- 1. Panning / Dragging Logic
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

    -- 2. Tooltip Rendering Logic
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
                    -- A. WORLD MAP LOGIC (Zone searching)
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
                        elseif cityDataByZone[closestZone].status == "Neutral" then
                            colorCode = "|cffffcc00"
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

                    if isCity then
                        f.cursorTooltip.text:SetFontObject("GameFontHighlight")
                    else
                        f.cursorTooltip.text:SetFontObject("SystemFont_Small")
                    end
                else
                    -- B. CITY MAP LOGIC (Direct coordinate output)
                    local mapName = "Unknown Map"
                    local colorCode = "|cffffffff"
                    local isCity = false

                    -- Check against our city data table
                    for key, data in pairs(cityDataByZone) do
                        if data.id == f.currentMapID then
                            isCity = true
                            mapName = data.name
                            if data.status == "Alliance" then
                                colorCode = "|cff0044cc"
                            elseif data.status == "Horde" then
                                colorCode = "|cffff2020"
                            elseif data.status == "Neutral" then
                                colorCode = "|cffffcc00"
                            end
                            break
                        end
                    end

                    -- Fallback to the API name if not in our table
                    if not isCity and C_Map and C_Map.GetMapInfo then
                        local mapInfo = C_Map.GetMapInfo(f.currentMapID)
                        if mapInfo and mapInfo.name then mapName = mapInfo.name end
                    end

                    -- Hard fallback for custom map if C_Map fails
                    if f.currentMapID == 1416 and not isCity then
                        mapName = "Dalaran"
                        colorCode = "|cffffcc00"
                    end

                    local headerText = string.format("|cffaaaaaa#%s|r", f.currentMapID or "???")
                    f.cursorTooltip.text:SetFormattedText("%s\n%s%s\n%.3f, %.3f|r", headerText, colorCode,
                        mapName:upper(), pctX, pctY)

                    f.cursorTooltip.text:SetFontObject("GameFontHighlight")
                    if not self.isDragging then ResetCursor() end
                end

                -- 3. Tooltip Formatting and Screen Edge Positioning
                f.cursorTooltip:SetSize(f.cursorTooltip.text:GetStringWidth(), f.cursorTooltip.text:GetStringHeight())

                local uiScale = f.cursorTooltip:GetEffectiveScale()
                local cursorX = rawX / uiScale
                local cursorY = rawY / uiScale
                local anchorPoint = ""
                local offsetX = 0
                local offsetY = 0

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

local ALT_MAP_IDS = { -- Classic
    --[1416] = 36,      -- Alterac mountains
    --[1429] = 12,      -- Elwynn Forest
    --[1450] = 493,     -- Moonglade
    --[1433] = 0,      -- Redridge mountains
}

f.mapTiles = {}

function f:LoadMap(mapID)
    f.currentMapID = mapID
    for _, tile in ipairs(f.mapTiles) do tile:Hide() end
    wipe(f.mapTiles)

    -- Update Top-Left Button text according to the current map
    if f.MapToggleButton then
        if mapID == 947 then
            f.MapToggleButton:SetText(f.showFogOfWar and "Hide Mist" or "Show Mist")
        else
            f.MapToggleButton:SetText("Return")
        end
    end

    if mapID == 947 then
        local customTile = f.mapContent:CreateTexture(nil, "BACKGROUND")
        customTile:SetAllPoints(f.mapContent)
        customTile:SetTexture("Interface\\AddOns\\t1_TrackMap\\map_texture\\worldmap-forever-0.0.1.tga")

        f.worldMapTile = customTile
        table.insert(f.mapTiles, customTile)
    elseif mapID == 1416 then
        local customTile = f.mapContent:CreateTexture(nil, "BACKGROUND")
        customTile:SetAllPoints(f.mapContent)
        customTile:SetTexture("Interface\\AddOns\\t1_TrackMap\\map_texture\\dalaran.tga")
        customTile:SetDesaturated(false)
        customTile:SetVertexColor(1, 1, 1, 1)

        -- Separate reference so it avoids any mist coloring
        f.dalaranMapTile = customTile
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

    local layers = C_Map.GetMapArtLayers(zoneID)
    if not layers or not layers[1] then return end

    local exploredTextures = C_MapExplorationInfo.GetExploredMapTextures(zoneID)
    if not exploredTextures then return end

    -- 1. Calculate the native aspect ratio of the Blizzard map layer (e.g., 668 / 1002 = 0.666)
    local nativeRatio = layers[1].layerHeight / layers[1].layerWidth

    -- 2. Force the pixel height to respect the native ratio based on the width to prevent stretching
    local zonePixelW = zData.w * f.mapContent:GetWidth()
    local zonePixelH = zonePixelW * nativeRatio

    -- 3. Calculate the true center of your custom T1_ZoneDB coordinates
    local boxCenterX = zData.x * f.mapContent:GetWidth()
    local boxCenterY = zData.y * f.mapContent:GetHeight()

    -- 4. Calculate the un-distorted Top-Left anchor for the exploration tiles
    local drawTopLeftX = boxCenterX - (zonePixelW / 2)
    local drawTopLeftY = boxCenterY - (zonePixelH / 2)

    for _, expInfo in ipairs(exploredTextures) do
        if expInfo.fileDataIDs and expInfo.fileDataIDs[1] then
            local tex = f.exploredTexturePool:Acquire()
            tex:SetTexture(expInfo.fileDataIDs[1])

            -- 5. Calculate local percentages (your original accurate math)
            local pctX = expInfo.offsetX / layers[1].layerWidth
            local pctY = expInfo.offsetY / layers[1].layerHeight
            local pctW = expInfo.textureWidth / layers[1].layerWidth
            local pctH = expInfo.textureHeight / layers[1].layerHeight

            -- 6. Draw using the un-distorted pixel dimensions based on the native ratio
            local drawX = drawTopLeftX + (pctX * zonePixelW)
            local drawY = -(drawTopLeftY + (pctY * zonePixelH))

            tex:SetSize(pctW * zonePixelW, pctH * zonePixelH)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", f.mapContent, "TOPLEFT", drawX, drawY)
            tex:Show()
        end
    end
end

function f:RefreshFogOfWar()
    if f.exploredTexturePool then f.exploredTexturePool:ReleaseAll() end

    -- Only apply desaturation and dimming on the World Map (947)
    if f.worldMapTile and f.currentMapID == 947 then
        if f.showFogOfWar then
            f.worldMapTile:SetDesaturated(true)
            f.worldMapTile:SetVertexColor(0.4, 0.4, 0.4)
        else
            f.worldMapTile:SetDesaturated(false)
            f.worldMapTile:SetVertexColor(1, 1, 1)
        end
    end

    -- Dalaran is an open custom map texture; skip exploration overlay drawing
    if f.currentMapID == 1416 or not f.showFogOfWar then return end

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
    local maxZ = self:GetDynamicMaxZoom()
    if self.zoomLevel > maxZ then self.zoomLevel = maxZ end
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

                -- Support Neutral Cities
                if data.status == "Alliance" then
                    tex:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
                elseif data.status == "Horde" then
                    tex:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
                else
                    tex:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA") -- Neutral Free-For-All Flag
                end

                tex:SetTexCoord(10 / 64, 54 / 64, 10 / 64, 54 / 64)
                f.cityFlags[key] = {
                    frame = flagFrame,
                    tex = tex,
                    x = data.x or 0,
                    y = data.y or 0,
                    status = data.status
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

        for key, flagObj in pairs(f.cityFlags) do
            flagObj.frame:Show()

            if playerInCityID and cityDataByZone[key].id ~= playerInCityID then
                flagObj.baseOpacity = 0.3
            else
                flagObj.baseOpacity = 1.0
            end

            flagObj.tex:SetDesaturated(false)
            flagObj.tex:SetVertexColor(1, 1, 1, flagObj.baseOpacity)

            local baseWidth = 24
            local baseHeight = 24
            if cityDataByZone[key] and cityDataByZone[key].status == "Alliance" then
                baseWidth = baseWidth * 1.15
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
    -- ==========================================
    -- DEBUG: T1_ZoneDB Center Round Icons (Clickable)
    -- ==========================================
    local MY_CUSTOM_WORLD_MAP_ID = 947
    if f.currentMapID == MY_CUSTOM_WORLD_MAP_ID and T1_ZoneDB and f.showFogOfWar then
        if not f.debugDots then f.debugDots = {} end

        for zoneID, zData in pairs(T1_ZoneDB) do
            if zData.x and zData.y then
                local dotBtn = f.debugDots[zoneID]
                if not dotBtn then
                    -- Create a clickable Button frame instead of a raw Texture
                    dotBtn = CreateFrame("Button", nil, self.mapContent)
                    dotBtn:SetFrameLevel(self.mapContent:GetFrameLevel() + 90)

                    dotBtn.tex = dotBtn:CreateTexture(nil, "OVERLAY", nil, 7)
                    dotBtn.tex:SetAllPoints()
                    dotBtn.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_2") -- Orange Circle

                    -- Click event to load the specific zone map and reset zoom
                    dotBtn:SetScript("OnClick", function()
                        f.zoomLevel = 1
                        f.mapOffsetX = 0
                        f.mapOffsetY = 0
                        f:LoadMap(zoneID)
                        if f.UpdateMapTransform then f:UpdateMapTransform() end
                    end)

                    f.debugDots[zoneID] = dotBtn
                end

                dotBtn:Show()
                -- Scaled to 24 so the hitbox is large enough to comfortably click
                dotBtn:SetSize(2 / self.zoomLevel, 2 / self.zoomLevel)
                dotBtn:ClearAllPoints()
                dotBtn:SetPoint("CENTER", self.mapContent, "TOPLEFT", zData.x * contentW, -zData.y * contentH)
            end
        end
    else
        if f.debugDots then
            for _, dotBtn in pairs(f.debugDots) do dotBtn:Hide() end
        end
    end
end

f.mapCanvas:EnableMouseWheel(true)

-- ==========================================
-- Smooth Exponential Zoom Controller
-- ==========================================
f.targetZoom = f.zoomLevel or 1

-- Dedicated ticker frame for smooth animations (hidden when idle)
f.zoomSmoother = CreateFrame("Frame", nil, f.mapCanvas)
f.zoomSmoother:Hide()

f.zoomSmoother:SetScript("OnUpdate", function(self, elapsed)
    local isAnimating = false
    local oldZoom = f.zoomLevel
    local targetZ = f.targetZoom or oldZoom
    local diffZ = targetZ - oldZoom

    local lerpRate = 1 - math.exp(-14 * elapsed)

    -- 1. ZOOMING (Slider, Scroll Wheel)
    if math.abs(diffZ) > 0.002 then
        isAnimating = true
        local newZoom = oldZoom + diffZ * lerpRate

        -- Pivot zooming only applies if we aren't panning/sliding simultaneously
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

    -- 2. PAN TO TARGET (Auto-focus, Double-click)
    if f.targetOffsetX and f.targetOffsetY then
        isAnimating = true
        local diffX = f.targetOffsetX - f.mapOffsetX
        local diffY = f.targetOffsetY - f.mapOffsetY

        f.mapOffsetX = f.mapOffsetX + diffX * lerpRate
        f.mapOffsetY = f.mapOffsetY + diffY * lerpRate

        if math.abs(diffX) < 0.1 and math.abs(diffY) < 0.1 then
            f.mapOffsetX = f.targetOffsetX
            f.mapOffsetY = f.targetOffsetY
            f.targetOffsetX = nil
            f.targetOffsetY = nil
        end

        -- 3. KINETIC INERTIA (Mouse Drag Release)
    elseif f.velocityX and f.velocityY and (math.abs(f.velocityX) > 1 or math.abs(f.velocityY) > 1) then
        isAnimating = true
        local friction = math.exp(-7 * elapsed) -- Decay rate (lower = more slippery)

        f.mapOffsetX = f.mapOffsetX + (f.velocityX * elapsed)
        f.mapOffsetY = f.mapOffsetY + (f.velocityY * elapsed)

        f.velocityX = f.velocityX * friction
        f.velocityY = f.velocityY * friction

        -- Stop tracking when the slide becomes imperceptible
        if math.abs(f.velocityX) < 10 and math.abs(f.velocityY) < 10 then
            f.velocityX = 0
            f.velocityY = 0
        end
    end

    f:UpdateMapTransform()

    -- Put the ticker to sleep when all animations settle (Saves CPU)
    if not isAnimating then
        self:Hide()
    end
end)

f.mapCanvas:EnableMouseWheel(true)
f.mapCanvas:SetScript("OnMouseWheel", function(self, delta)
    local maxZ = f.GetDynamicMaxZoom and f:GetDynamicMaxZoom() or 20
    local minZ = 1

    local scaleFactor = (delta > 0) and 1.22 or (1 / 1.22)
    local currentTarget = f.targetZoom or f.zoomLevel
    f.targetZoom = math.max(minZ, math.min(maxZ, currentTarget * scaleFactor))

    local cX, cY = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale()
    f.zoomPivotX = (cX / uiScale) - self:GetLeft()
    f.zoomPivotY = (cY / uiScale) - self:GetTop()

    -- FIX: Instantly cancel any active auto-panning or kinetic sliding
    f.targetOffsetX = nil
    f.targetOffsetY = nil
    f.velocityX = 0
    f.velocityY = 0

    if f.zoomSmoother then f.zoomSmoother:Show() end
end)

-- ==========================================
-- Auto-Frame Logic
-- ==========================================
function f:ZoomToPoint(pctX, pctY, targetZoom)
    if not pctX or not pctY then return end
    targetZoom = targetZoom or 5
    if targetZoom < 1 then targetZoom = 1 end

    local maxZ = self.GetDynamicMaxZoom and self:GetDynamicMaxZoom() or 10
    if targetZoom > maxZ then targetZoom = maxZ end

    local canvasW, canvasH = self.mapCanvas:GetSize()
    local contentW, contentH = self.mapContent:GetSize()

    if canvasW and canvasH and contentW and contentH then
        local exactPixelX = pctX * contentW
        local exactPixelY = -pctY * contentH

        -- Feed the animation targets
        self.targetZoom = targetZoom
        self.targetOffsetX = ((canvasW / 2) - (exactPixelX * targetZoom)) / targetZoom
        self.targetOffsetY = (-(canvasH / 2) - (exactPixelY * targetZoom)) / targetZoom

        if self.zoomSmoother then self.zoomSmoother:Show() end
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

    local capitalCities = { [1416] = true, [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true,
        [1458] = true }

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

-- Helper: Check if the current map is a custom overlay (has w and h)
local function IsCustomCityMap(mapID)
    for _, data in pairs(cityDataByZone) do
        if data.id == mapID and data.w and data.h then
            return true
        end
    end
    return false
end


-- Helper: Convert API coordinates to your custom city map space using the World Map as a bridge
local function ConvertToCitySpace(unitMapID, rawX, rawY, targetCityID)
    local cityData = nil
    for _, data in pairs(cityDataByZone) do
        if data.id == targetCityID and data.w and data.h then
            cityData = data
            break
        end
    end

    if not cityData then return false, 0, 0 end

    if T1_ZoneDB and T1_ZoneDB[unitMapID] then
        local zData = T1_ZoneDB[unitMapID]
        if zData.x and zData.w and zData.y and zData.h then
            -- 1. Translate local API zone coordinates up to global World Map coordinates
            local worldX = zData.x + ((rawX - 0.5) * zData.w)
            local worldY = zData.y + ((rawY - 0.5) * zData.h)
            
            -- 2. Calculate the raw offset from the city's center point
            local dx = (worldX - cityData.x) / cityData.w
            local dy = (worldY - cityData.y) / cityData.h
            
            -- 3. Apply the custom movement scale to tune speed
            local customScale = cityData.scale or 1
            dx = dx * customScale
            dy = dy * customScale
            
            -- 4. Apply 2D Rotation Matrix with Aspect Ratio Correction
            if targetCityID == 1416 then
                local angle = math.rad(-70) 
                local cosA = math.cos(angle)
                local sinA = math.sin(angle)
                
                -- Multiply X by 1.5 to match your map's aspect ratio (8016/5344) before rotating
                local aspectX = dx * 1.5
                local aspectY = dy * 1.0
                
                local rotX = (aspectX * cosA) - (aspectY * sinA)
                local rotY = (aspectX * sinA) + (aspectY * cosA)
                
                -- Divide X by 1.5 to return to percentage-based coordinates
                dx = rotX / 1.5
                dy = rotY / 1.0
            end
            
            -- 5. Shift back to Top-Left anchor coordinates
            local localCityX = dx + 0.5
            local localCityY = dy + 0.5
            
            return true, localCityX, localCityY
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
    if currentZoneID then
        local pos = C_Map.GetPlayerMapPosition(currentZoneID, "player")
        if pos and pos.x and pos.y then
            if f.currentMapID == 947 then
                if T1_ZoneDB and T1_ZoneDB[currentZoneID] then
                    local zoneData = T1_ZoneDB[currentZoneID]
                    if zoneData.x and zoneData.y and zoneData.w and zoneData.h then
                        pX = zoneData.x + ((pos.x - 0.5) * zoneData.w)
                        pY = zoneData.y + ((pos.y - 0.5) * zoneData.h)
                        hasValidData = true
                    end
                end
            elseif IsCustomCityMap(f.currentMapID) then
                hasValidData, pX, pY = ConvertToCitySpace(currentZoneID, pos.x, pos.y, f.currentMapID)
            elseif f.currentMapID == currentZoneID then
                pX, pY, hasValidData = pos.x, pos.y, true
            end
        end
    end

    if hasValidData then
        f.playerArrow:Show()
        f.playerArrow:SetSize(32 / f.zoomLevel, 32 / f.zoomLevel)

        local facing = GetPlayerFacing()
        if facing then
            -- Apply a 70-degree clockwise offset when viewing Dalaran
            if f.currentMapID == 1416 then
                facing = facing - math.rad(-70)
            end
            f.playerArrow:SetRotation(facing)
        end

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
                                drawX = zData.x + ((pos.x - 0.5) * zData.w)
                                drawY = zData.y + ((pos.y - 0.5) * zData.h)
                                showPartyMember = true
                            end
                        end
                    elseif IsCustomCityMap(f.currentMapID) then
                        -- NEW FIX: Force reverse mapping for party members
                        showPartyMember, drawX, drawY = ConvertToCitySpace(unitMapID, pos.x, pos.y, f.currentMapID)
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

f.deathTracker = CreateFrame("Frame", nil, f.mapCanvas)
f.deathTracker:SetScript("OnUpdate", function()
    local hasCorpse, cX, cY = false, 0, 0

    if UnitIsDeadOrGhost("player") then
        local currentZoneID = C_Map.GetBestMapForUnit("player")
        if currentZoneID and C_DeathInfo then
            local corpsePos = C_DeathInfo.GetCorpseMapPosition and C_DeathInfo.GetCorpseMapPosition(currentZoneID)

            if corpsePos and corpsePos.x and corpsePos.y then
                if f.currentMapID == 947 then
                    if T1_ZoneDB and T1_ZoneDB[currentZoneID] then
                        local zData = T1_ZoneDB[currentZoneID]
                        if zData.x and zData.w and zData.y and zData.h then
                            cX = zData.x + ((corpsePos.x - 0.5) * zData.w)
                            cY = zData.y + ((corpsePos.y - 0.5) * zData.h)
                            hasCorpse = true
                        end
                    end
                elseif IsCustomCityMap(f.currentMapID) then
                    -- NEW FIX: Force reverse mapping for player corpse
                    hasCorpse, cX, cY = ConvertToCitySpace(currentZoneID, corpsePos.x, corpsePos.y, f.currentMapID)
                elseif f.currentMapID == currentZoneID then
                    cX, cY, hasCorpse = corpsePos.x, corpsePos.y, true
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
            -- Dalaran (1416) is now explicitly included in the toggle logic
            local capitalCities = { [1416] = true, [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true,
                [1458] = true }
            local defaultMap = (playerMap and capitalCities[playerMap]) and playerMap or 947

            -- Reset zoom and pan if we are opening a city map directly
            if defaultMap ~= 947 then
                f.zoomLevel = 1
                f.mapOffsetX = 0
                f.mapOffsetY = 0
                f.targetOffsetX = nil
                f.targetOffsetY = nil
            end

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
        -- Dalaran (1416) added here as well for the first-time initialization
        local capitalCities = { [1416] = true, [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true,
            [1458] = true }
        local defaultMap = (playerMap and capitalCities[playerMap]) and playerMap or 947
        self:LoadMap(defaultMap)
        if defaultMap == 947 and playerMap then self:ZoomToZone(playerMap) end
    end
    if self.UpdateMapTransform then self:UpdateMapTransform() end
end)

-- ==========================================
-- Auto-Refresh Mist Maps on Exploration
-- ==========================================
f.explorationTracker = CreateFrame("Frame")
f.explorationTracker:RegisterEvent("ZONE_CHANGED")
f.explorationTracker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f.explorationTracker:RegisterEvent("ZONE_CHANGED_INDOORS")

-- Wrap in pcall in case the client version doesn't support this specific modern event
pcall(function() f.explorationTracker:RegisterEvent("MAP_EXPLORATION_UPDATED") end)

f.explorationTracker:SetScript("OnEvent", function(self, event, ...)
    -- Only refresh if the map is actively open and Mist Maps is toggled on
    if f:IsShown() and f.showFogOfWar then
        if f.RefreshFogOfWar then
            f:RefreshFogOfWar()
        end
    end
end)


-- ==========================================
-- Auto-Switch Map on Zone Change
-- ==========================================
f.zoneTracker = CreateFrame("Frame")
f.zoneTracker:RegisterEvent("ZONE_CHANGED")
f.zoneTracker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f.zoneTracker:RegisterEvent("ZONE_CHANGED_INDOORS")
f.zoneTracker:RegisterEvent("PLAYER_ENTERING_WORLD")

f.lastPlayerZone = nil

f.zoneTracker:SetScript("OnEvent", function()
    local currentPlayerZone = C_Map.GetBestMapForUnit("player")
    if not currentPlayerZone then return end

    if f.lastPlayerZone == currentPlayerZone then return end
    f.lastPlayerZone = currentPlayerZone

    if not f:IsShown() then return end

    -- 1416 (Dalaran) is now explicitly added here to trigger the auto-enter swap
    local capitalCities = {
        [1416] = true,
        [1453] = true,
        [1454] = true,
        [1455] = true,
        [1456] = true,
        [1457] = true,
        [1458] = true
    }
    local MY_CUSTOM_WORLD_MAP_ID = 947

    if capitalCities[currentPlayerZone] then
        -- Scenario 1: Player walks INTO a capital city
        f.zoomLevel = 1
        f.mapOffsetX = 0
        f.mapOffsetY = 0
        
        -- Cancel any kinetic sliding or auto-panning from the world map
        f.targetOffsetX = nil
        f.targetOffsetY = nil
        f.velocityX = 0
        f.velocityY = 0
        
        f:LoadMap(currentPlayerZone)
        if f.UpdateMapTransform then f:UpdateMapTransform() end

    elseif f.currentMapID ~= MY_CUSTOM_WORLD_MAP_ID and not capitalCities[currentPlayerZone] then
        -- Scenario 2: Player walks OUT of a capital city
        f:LoadMap(MY_CUSTOM_WORLD_MAP_ID)
        
        -- Automatically frame the camera around the new zone you just walked into
        if f.ZoomToZone then f:ZoomToZone(currentPlayerZone) end
        if f.UpdateMapTransform then f:UpdateMapTransform() end
    end
end)


print("|cFF00FF00t1_TrackMap UI Built! Type /t1 or Ctrl+Numpad 1|r")
