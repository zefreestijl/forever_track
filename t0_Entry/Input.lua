--local addonName, Entry = ...


-- ==========================================
-- t0_Entry/Input.lua
-- ==========================================
-- Create the global registry that all other addons will plug into
_G.ForeverTrack = {
    Modules = {}
}
local core = _G.ForeverTrack


-- ==========================================
-- Init & Slash Commands (T1)
-- ==========================================
_G.func_ConvertClassicIDToMapID = function(classicID)
    if not T1_ZoneDB then return nil end
    local targetClassicID = tonumber(classicID)
    if not targetClassicID then return nil end
    for mapID, data in pairs(T1_ZoneDB) do 
        if data.classic == targetClassicID then return tonumber(mapID) end 
    end
    return nil
end

local lastToggleTime = 0

_G.func_ToggleT1Window = function(mapID)
    -- FIX: Debounce to prevent the gamepad from firing on both Button-Down and Button-Up
    if GetTime() - lastToggleTime < 0.2 then return end
    lastToggleTime = GetTime()

    local f = core.Modules.T1 
    if not f then print("t1_TrackMap is disabled or missing.") return end

    if mapID and type(mapID) == "number" then
        if mapID < 0 then return end
        if f.currentMapID ~= mapID then f:LoadMap(mapID) end
        if f.UpdateMapTransform then f:UpdateMapTransform() end
        f:Show()
    else
        if f:IsShown() then
            if f.isMapFocused then
                -- 1. Opened and Focused -> Toggle OFF
                f:Hide()
            else
                -- 2. Opened and Unfocused -> Focus the custom window
                f:SetMapFocus(true)
                f:Raise() 
            end
        else
            -- 3. Not Opened -> Toggle ON
            f:Show() 
        end
    end
end


_G.func_OpenZoneMapByID = function(mapID)
    local targetMapID = tonumber(mapID)
    if not targetMapID or targetMapID <= 0 then return end
    if _G.func_ToggleT1Window then _G.func_ToggleT1Window(targetMapID) end
end

SLASH_T1_CMD1 = "/t1"
SlashCmdList["T1_CMD"] = function(msg)
    msg = strtrim(msg or "")
    if msg == "" then
        _G.func_ToggleT1Window(); return
    end
    local mapIDToOpen = nil
    local classicMatch = msg:match("^[cC](%d+)$")
    if classicMatch then
        mapIDToOpen = _G.func_ConvertClassicIDToMapID(classicMatch)
    else
        local idMatch = msg:match("^(%d+)$")
        if idMatch then mapIDToOpen = tonumber(idMatch) end
    end
    if mapIDToOpen then 
        _G.func_OpenZoneMapByID(mapIDToOpen) 
    else 
        print("|cffff2020T1_TrackMap:|r Invalid command format.") 
    end
end

-- Future T2 Slash Command
SLASH_T2_CMD1 = "/t2"
SlashCmdList["T2_CMD"] = function(msg)
    if core.Modules.T2_NPCFrame then
        if core.Modules.T2_NPCFrame:IsShown() then core.Modules.T2_NPCFrame:Hide()
        else core.Modules.T2_NPCFrame:Show() end
    end
end


-- ==========================================
-- Gamepad & Keyboard Hotkey Bindings
-- ==========================================
local toggleBtn = CreateFrame("Button", "Entry_KeybindButton", UIParent)
toggleBtn:SetSize(1, 1) 
toggleBtn:SetAlpha(0)
toggleBtn:RegisterForClicks("AnyDown") -- Add this line right here
toggleBtn:SetScript("OnClick", function() 
    -- Defaults to toggling T1 for now. Later we can make this smart based on context.
    _G.func_ToggleT1Window() 
end)



local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    SetBinding("PADBACK", nil)
    SetBindingClick("CTRL-NUMPAD1", "Entry_KeybindButton")
    SaveBindings(GetCurrentBindingSet() or 1)
end)

-- ==========================================
-- Dynamic Hardware Poller (L2 + Select, Pan, Zoom, L3/R3, Unfocus)
-- ==========================================
local isL2Held = false
local wasSelectPressed = false
local wasStartPressed = false
local wasL3Pressed = false
local wasR3Pressed = false

toggleBtn:SetScript("OnUpdate", function(self, elapsed)
    elapsed = elapsed or (1 / 60)
    
    local l2Down = IsKeyDown("PADLTRIGGER")
    local selectDown = IsKeyDown("PADBACK")
    local startDown = IsKeyDown("PADFORWARD")
    local l3Down = IsKeyDown("PADLSTICK")
    local r3Down = IsKeyDown("PADRSTICK")
    
    -- 1. L2 Hijack Logic
    if l2Down and not isL2Held then
        isL2Held = true
        SetOverrideBindingClick(self, true, "PADBACK", "Entry_KeybindButton")
    elseif not l2Down and isL2Held then
        isL2Held = false
        ClearOverrideBindings(self)
    end

    -- 2. Focus Dropping Logic (Select or Pause)
    if (selectDown and not wasSelectPressed) or (startDown and not wasStartPressed) then
        if not l2Down then
            if core.Modules.T1 and core.Modules.T1.isMapFocused then
                core.Modules.T1:SetMapFocus(false)
            end
            -- Future T2 unfocus logic goes here
        end
    end
    wasSelectPressed = selectDown
    wasStartPressed = startDown

    -- 3. Gamepad Controls (Requires L2 + A Window Focused)
    if l2Down then
        local f = core.Modules.T1
        
        -- If T1 Map is focused, route controls to it
        if f and f:IsShown() and f.isMapFocused then
            
            -- --- PANNING & ZOOMING ---
            local panSpeed = (800 / f.zoomLevel) * elapsed 
            local zoomSpeed = 20 * elapsed
            local dx, dy, zDelta = 0, 0, 0

            if C_GamePad and C_GamePad.GetActiveDeviceID then
                local deviceID = C_GamePad.GetActiveDeviceID()
                if deviceID then
                    local state = C_GamePad.GetDeviceMappedState(deviceID)
                    if state and state.sticks then
                        local ls = state.sticks[1]
                        local rs = state.sticks[2]
                        if ls then
                            if math.abs(ls.x) > 0.15 then dx = -ls.x * panSpeed end
                            if math.abs(ls.y) > 0.15 then dy = -ls.y * panSpeed end 
                        end
                        if rs then
                            if math.abs(rs.y) > 0.15 then zDelta = rs.y * zoomSpeed end
                        end
                    end
                end
            end

            if dx == 0 and dy == 0 then
                if IsKeyDown("PADDPADLEFT") then dx = panSpeed end
                if IsKeyDown("PADDPADRIGHT") then dx = -panSpeed end
                if IsKeyDown("PADDPADUP") then dy = panSpeed end
                if IsKeyDown("PADDPADDOWN") then dy = -panSpeed end
            end
            
            if zDelta == 0 then
                if IsKeyDown("PADRSHOULDER") or IsKeyDown("PADRTRIGGER") then zDelta = zoomSpeed end
                if IsKeyDown("PADLSHOULDER") then zDelta = -zoomSpeed end
            end

            if dx ~= 0 or dy ~= 0 then
                f.mapOffsetX = (f.mapOffsetX or 0) + dx
                f.mapOffsetY = (f.mapOffsetY or 0) + dy
                f.velocityX, f.velocityY = 0, 0
                f.targetOffsetX, f.targetOffsetY = nil, nil
                f:UpdateMapTransform()
            end

            if zDelta ~= 0 then
                local maxZ = f.GetDynamicMaxZoom and f:GetDynamicMaxZoom() or 20
                local currentTarget = f.targetZoom or f.zoomLevel
                f.targetZoom = math.max(1, math.min(maxZ, currentTarget + zDelta))
                
                local canvasW, canvasH = f.mapCanvas:GetSize()
                if canvasW and canvasH then
                    f.zoomPivotX = canvasW / 2
                    f.zoomPivotY = -canvasH / 2
                end
                f.targetOffsetX, f.targetOffsetY = nil, nil
                f.velocityX, f.velocityY = 0, 0
                if f.zoomSmoother then f.zoomSmoother:Show() end
            end

            -- --- L3: RECENTER ON PLAYER ---
            if l3Down and not wasL3Pressed then
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
                        f:ZoomToPoint((wX / 1.5) + 0.5, 0.5 - wY, 8)
                    else
                        if f.ZoomToZone then f:ZoomToZone(currentZoneID) end
                    end
                    if f.UpdateMapTransform then f:UpdateMapTransform() end
                end
            end

            -- --- R3: ZOOM TO FIT MAP ---
            if r3Down and not wasR3Pressed then
                f.savedWorldZoom = nil
                if f.currentMapID ~= 947 then f:LoadMap(947) end
                
                local canvasW, canvasH = f.mapCanvas:GetSize()
                local contentW, contentH = f.mapContent:GetSize()
                if canvasW and canvasH and contentW and contentH then
                    local fitScale = math.max(canvasW / contentW, canvasH / contentH)
                    f.targetZoom = fitScale
                    f.targetOffsetX = ((canvasW - (contentW * fitScale)) / 2) / fitScale
                    f.targetOffsetY = (-(canvasH - (contentH * fitScale)) / 2) / fitScale
                    if f.zoomSmoother then f.zoomSmoother:Show() end
                end
                if f.UpdateMapTransform then f:UpdateMapTransform() end
            end
        end
    end
    
    wasL3Pressed = l3Down
    wasR3Pressed = r3Down
end)