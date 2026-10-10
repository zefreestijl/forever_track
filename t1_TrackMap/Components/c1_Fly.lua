local addonName, T1 = ...
local f = T1.MapFrame

f.showT1Fly = true

-- ==========================================
-- Flight Path Component Init
-- ==========================================
if not f.flightPinPool then f.flightPinPool = {} end
if not f.flightLinePool then f.flightLinePool = {} end

-- Initialize the DB globally ONLY if it doesn't already exist from an external file
if not T1_FlightRouteDB then 
    T1_FlightRouteDB = {} 
end

-- Initialize the UI Toggle utilizing the namespace component helper
f.chk_T1 = T1.CreatePoICheckbox("T1_Chk_T1", "T1_Fly", false, function(isChecked)
    f.showT1Fly = isChecked
    if f.RefreshFlightPins then f:RefreshFlightPins() end
end)

-- ==========================================
-- Flight Path Rendering
-- ==========================================
function f:RefreshFlightPins()
    -- Hide all existing pins and lines
    for _, pin in ipairs(f.flightPinPool) do pin:Hide() end
    for _, line in ipairs(f.flightLinePool) do line:Hide() end

    if not f.showT1Fly then return end
    if f.currentMapID == 947 or f.currentMapID == -1416 or f.currentMapID <= 0 then return end

    local contentW = f.mapContent:GetWidth()
    local contentH = f.mapContent:GetHeight()

    -- ------------------------------------------
    -- A. Draw Routes (Lines) from a Custom Database
    -- ------------------------------------------
    local lineIndex = 1
    if T1_FlightRouteDB and T1_FlightRouteDB[f.currentMapID] then
        for _, route in ipairs(T1_FlightRouteDB[f.currentMapID]) do
            local line = f.flightLinePool[lineIndex]
            if not line then
                line = f.mapContent:CreateLine(nil, "OVERLAY")
                table.insert(f.flightLinePool, line)
            end

            line:SetThickness(2 / f.zoomLevel)
            -- A classic dotted-flight-path color (Pale Yellow/Orange)
            line:SetColorTexture(1.0, 0.82, 0.0, 0.6)

            line:SetStartPoint("CENTER", route.startX * contentW, -route.startY * contentH)
            line:SetEndPoint("CENTER", route.endX * contentW, -route.endY * contentH)
            line:Show()

            lineIndex = lineIndex + 1
        end
    end

    -- ------------------------------------------
    -- B. Draw Nodes (Pins)
    -- ------------------------------------------
    if not C_TaxiMap or not C_TaxiMap.GetTaxiNodesForMap then return end

    local nodes = C_TaxiMap.GetTaxiNodesForMap(f.currentMapID)
    if not nodes or #nodes == 0 then return end

    local pinIndex = 1
    for _, node in ipairs(nodes) do
        if node.position and node.position.x and node.position.y then
            local pin = f.flightPinPool[pinIndex]
            if not pin then
                pin = CreateFrame("Button", nil, f.mapContent)
                pin:SetFrameLevel(f.mapContent:GetFrameLevel() + 66)

                pin.tex = pin:CreateTexture(nil, "OVERLAY")
                pin.tex:SetAllPoints()
                f.flightPinPool[pinIndex] = pin
            end

            if node.state == Enum.FlightPathState.Active then
                pin.tex:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-Green")
                pin.tex:SetDesaturated(false)
            else
                pin.tex:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-Gray")
                pin.tex:SetDesaturated(true)
            end

            pin:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local nodeName = node.name or "Unknown Flight Path"
                GameTooltip:SetText(nodeName, 1, 0.82, 0)
                if node.state ~= Enum.FlightPathState.Active then
                    GameTooltip:AddLine("|cFF808080Undiscovered|r")
                end
                GameTooltip:Show()
            end)

            pin:SetScript("OnLeave", function() GameTooltip:Hide() end)

            pin:SetSize(12 / f.zoomLevel, 12 / f.zoomLevel)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", f.mapContent, "TOPLEFT", node.position.x * contentW, -node.position.y * contentH)
            pin:Show()

            -- ==== Interactive Route Developer Tool ====
            pin:RegisterForClicks("LeftButtonUp")
            pin.nodeX = node.position.x
            pin.nodeY = node.position.y
            pin.nodeName = node.name or "Unknown"

            pin:SetScript("OnClick", function(self)
                if IsAltKeyDown() then
                    if not f.routeStartNode then
                        f.routeStartNode = self
                        print(string.format("|cff00ccff[T1_Fly] Route Start:|r %s", self.nodeName))
                    else
                        -- Format the exact Lua table row needed for your database
                        local mapStr = string.format(
                            "    { startX = %.4f, startY = %.4f, endX = %.4f, endY = %.4f }, -- %s to %s",
                            f.routeStartNode.nodeX, f.routeStartNode.nodeY, self.nodeX, self.nodeY,
                            f.routeStartNode.nodeName, self.nodeName)
                        print("|cff00ff00" .. mapStr .. "|r")
                        f.routeStartNode = nil
                    end
                end
            end)

            pinIndex = pinIndex + 1
        end
    end
end