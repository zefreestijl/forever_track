local addonName, T1 = ...
local f = T1.MapFrame

f.showT5DGNs = true
if not f.dgnPinPool then f.dgnPinPool = {} end

-- 1. Initialize the UI Toggle
f.chk_T5 = T1.CreatePoICheckbox("T1_Chk_T5", "T5_Dgn", true, function(isChecked)
    f.showT5DGNs = isChecked
    if f.RefreshDgnPins then f:RefreshDgnPins() end
end)
f.chk_T5:Enable()
f.chk_T5:SetAlpha(1.0)


function f:RefreshDgnPins()
    -- 1. Ensure pool exists and hide all existing pins first to prevent ghosting
    if not f.dgnPinPool then f.dgnPinPool = {} end
    for _, pin in ipairs(f.dgnPinPool) do
        pin:Hide()
    end

    if not T1_InstanceDB or not f.showT5DGNs or f.currentMapID <= 0 then return end

    local contentW, contentH = f.mapContent:GetSize()
    local pinIndex = 1


    for instanceID, data in pairs(T1_InstanceDB) do
        if data.x and data.y then
            local drawX, drawY, showPin = 0, 0, false

            -- Coordinate Resolution
            if f.currentMapID == data.zoneID then
                drawX = data.x > 1 and data.x / 100 or data.x
                drawY = data.y > 1 and data.y / 100 or data.y
                showPin = true
            elseif f.currentMapID == 947 then
                if T1_ZoneDB and T1_ZoneDB[data.zoneID] then
                    local zData = T1_ZoneDB[data.zoneID]
                    local zoneW = (zData.w and zData.w > 0) and zData.w or 0.05
                    if zData.x and zData.y and (zData.x ~= 0 or zData.y ~= 0) then
                        local baseDataX = data.x > 1 and data.x / 100 or data.x
                        local baseDataY = data.y > 1 and data.y / 100 or data.y
                        drawX = zData.x + ((baseDataX - 0.5) * zoneW)
                        drawY = zData.y + ((0.5 - baseDataY) * (zoneW / 1.5))
                        showPin = true
                    end
                end
            end

            if showPin and drawX == 0 and drawY == 0 then
                showPin = false
            end


            -- Render Pin
            if showPin then
                local pin = f.dgnPinPool[pinIndex]
                if not pin then
                    pin = CreateFrame("Button", nil, f.mapContent)
                    pin:SetFrameLevel(f.mapContent:GetFrameLevel() + 65)
                    pin.tex = pin:CreateTexture(nil, "OVERLAY")
                    pin.tex:SetAllPoints()

                    -- Circular mask application
                    pin.mask = pin:CreateMaskTexture()
                    pin.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
                    pin.mask:SetAllPoints(pin.tex)

                    -- Custom texture
                    pin.tex:SetTexture("Interface\\AddOns\\forever_track\\t1_TrackMap\\icon_texture\\dungeon_portal.tga")
                    pin.tex:AddMaskTexture(pin.mask)

                    f.dgnPinPool[pinIndex] = pin
                end

                -- FIX 1: Store the exact pixel coordinates directly on the pin object
                if f.currentMapID == 947 then
                    local uiX = (drawX / 1.5) + 0.5
                    local uiY = 0.5 - drawY
                    pin.targetX = uiX * contentW
                    pin.targetY = -uiY * contentH
                else
                    pin.targetX = drawX * contentW
                    pin.targetY = -drawY * contentH
                end

                -- Dynamic Level Color Logic
                local pR, pG, pB = 1, 1, 1
                if data.level and data.level > 0 and data.level < 1000 then
                    local color = GetQuestDifficultyColor(data.level)
                    if color then pR, pG, pB = color.r, color.g, color.b end
                elseif data.level == 1000 then
                    pR, pG, pB = 0.8, 0.4, 1.0
                end
                pin.tex:SetVertexColor(pR, pG, pB)

                -- Hover Tooltips & Immediate Redraw Logic
                pin:SetScript("OnEnter", function(self)
                    self:SetAlpha(0.5)

                    local hoverSize = 12 / f.zoomLevel
                    self:SetSize(hoverSize, hoverSize)

                    -- FIX 2: Force the client to immediately redraw the center coordinate
                    self:ClearAllPoints()
                    self:SetPoint("CENTER", f.mapContent, "TOPLEFT", self.targetX, self.targetY)

                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    local displayID = type(instanceID) == "number" and instanceID or "???"
                    GameTooltip:SetText(data.name .. " (|cFF00FFFF#" .. displayID .. "|r)", pR, pG, pB)
                    if data.zone and data.zone ~= "" then GameTooltip:AddLine("Zone: " .. data.zone, 1, 1, 1, true) end
                    if data.level and data.level > 0 then
                        local levelText = data.level == 1000 and "Raid/PvP" or tostring(data.level)
                        GameTooltip:AddLine("Level: " .. levelText, pR, pG, pB)
                    end
                    if data.comment and data.comment ~= "" then GameTooltip:AddLine("|cFF808080" .. data.comment .. "|r",
                            1, 1, 1, true) end
                    GameTooltip:Show()
                end)

                pin:SetScript("OnLeave", function(self)
                    self:SetAlpha(1.0)

                    local normalSize = 10 / f.zoomLevel
                    self:SetSize(normalSize, normalSize)

                    -- FIX 3: Force the client to immediately redraw the center coordinate on exit
                    self:ClearAllPoints()
                    self:SetPoint("CENTER", f.mapContent, "TOPLEFT", self.targetX, self.targetY)

                    GameTooltip:Hide()
                end)

                pin:SetScript("OnClick", function()
                    if f.LoadMap and type(instanceID) == "number" then
                        f:LoadMap(instanceID)
                        if f.UpdateMapTransform then f:UpdateMapTransform() end
                    end
                end)

                -- FIX 4: Check if the mouse is actively hovering while zooming the map to prevent jitter
                local initialSize = pin:IsMouseOver() and (12 / f.zoomLevel) or (10 / f.zoomLevel)
                pin:SetSize(initialSize, initialSize)

                pin:ClearAllPoints()
                pin:SetPoint("CENTER", f.mapContent, "TOPLEFT", pin.targetX, pin.targetY)

                pin:Show()
                pinIndex = pinIndex + 1
            end
        end
    end
end

-- 3. Hook into Main Map Updates
hooksecurefunc(f, "UpdateMapTransform", function(self)
    if self.RefreshDgnPins then self:RefreshDgnPins() end
end)
