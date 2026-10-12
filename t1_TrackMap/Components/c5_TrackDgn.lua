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
        local drawX, drawY, showPin = 0, 0, false

        -- Coordinate Resolution
        if f.currentMapID == data.zoneID then
            drawX = data.x > 1 and data.x / 100 or data.x
            drawY = data.y > 1 and data.y / 100 or data.y
            showPin = true
            
        elseif f.currentMapID == 947 then
            -- World Map rendering: Ensure parent zone exists AND isn't defaulting to 0,0
            if T1_ZoneDB and T1_ZoneDB[data.zoneID] then
                local zData = T1_ZoneDB[data.zoneID]
                local zoneW = (zData.w and zData.w > 0) and zData.w or 0.05
                
                -- Safeguard: Only compute if the zone actually has valid world coordinates
                if zData.x and zData.y and (zData.x ~= 0 or zData.y ~= 0) then
                    local baseDataX = data.x > 1 and data.x / 100 or data.x
                    local baseDataY = data.y > 1 and data.y / 100 or data.y
                    drawX = zData.x + ((baseDataX - 0.5) * zoneW)
                    drawY = zData.y + ((0.5 - baseDataY) * (zoneW / 1.5))
                    showPin = true
                end
            end
        end

        -- Ultimate fallback: if coordinates somehow evaluated to exactly 0,0, hide it
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
                pin.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_4") 
                f.dgnPinPool[pinIndex] = pin
            end

            -- Hover Tooltips
            pin:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(data.name .. " (|cFF00FFFF#" .. instanceID .. "|r)", 1, 0.82, 0)
                if data.zone then GameTooltip:AddLine("Zone: " .. data.zone, 1, 1, 1, true) end
                if data.comment and data.comment ~= "" then 
                    GameTooltip:AddLine("|cFF808080" .. data.comment .. "|r", 1, 1, 1, true) 
                end
                GameTooltip:Show()
            end)
            pin:SetScript("OnLeave", function() GameTooltip:Hide() end)

            -- Click to enter map
            pin:SetScript("OnClick", function()
                if f.LoadMap then
                    f:LoadMap(instanceID)
                    if f.UpdateMapTransform then f:UpdateMapTransform() end
                end
            end)

            pin:SetSize(10 / f.zoomLevel, 10 / f.zoomLevel)
            pin:ClearAllPoints()

            if f.currentMapID == 947 then
                local uiX = (drawX / 1.5) + 0.5
                local uiY = 0.5 - drawY
                pin:SetPoint("CENTER", f.mapContent, "TOPLEFT", uiX * contentW, -uiY * contentH)
            else
                pin:SetPoint("CENTER", f.mapContent, "TOPLEFT", drawX * contentW, -drawY * contentH)
            end
            
            pin:Show()
            pinIndex = pinIndex + 1
        end
    end

end

-- 3. Hook into Main Map Updates
hooksecurefunc(f, "UpdateMapTransform", function(self)
    if self.RefreshDgnPins then self:RefreshDgnPins() end
end)