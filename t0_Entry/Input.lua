--local addonName, Entry = ...


-- ==========================================
-- t0_Entry/Input.lua
-- ==========================================
-- Create the global registry that all other addons will plug into
_G.ForeverTrack = {
    Modules = {}
}
local core = _G.ForeverTrack

_G.func_ToggleT0Window = function()
    local t0Frame = core.Modules.T0
    if not t0Frame then
        print("T0 Window not found in registry.")
        return
    end

    local modules = { "t1_TrackMap", "t2_TrackNPC", "t3_TrackQst", "t4_TrackRes", "t5_TrackDgn" }

    if UIParent:IsShown() then
        -- 1. Hide all built-in HUD
        UIParent:Hide()

        -- 2. Prompt up the t0_Entry window
        t0Frame:Show()

        -- 3. Prompt up other enabled custom addon windows
        if ForeverTrack_DB then
            for _, modID in ipairs(modules) do
                if ForeverTrack_DB[modID] and _G[modID] then
                    _G[modID]:SetParent(nil) -- Enforce detachment
                    _G[modID]:Show()

                    if _G["t0_Btn_" .. modID] then
                        _G["t0_Btn_" .. modID]:SetText("|cFFFFD100On|r")
                    end
                end
            end
        end
    else
        -- 1. Capture which custom windows are currently open BEFORE the HUD returns
        local openWindows = {}
        for _, modID in ipairs(modules) do
            if _G[modID] and _G[modID]:IsShown() then
                openWindows[modID] = true
            end
        end

        -- 2. Restore the built-in HUD (This often triggers WoW's auto-hide wipe)
        UIParent:Show()

        -- 3. Hide ONLY the t0_Entry window
        t0Frame:Hide()

        -- 4. Force previously open windows to stay open and float above the HUD
        for modID, _ in pairs(openWindows) do
            if _G[modID] then
                _G[modID]:SetParent(nil)         -- Ensure it wasn't secretly attached to t0_Entry
                _G[modID]:SetFrameStrata("HIGH") -- Prevent sinking behind the default HUD
                _G[modID]:Show()                 -- Override WoW's auto-close panel manager
            end
        end
    end
end



SLASH_T0_CMD1 = "/t0"
SlashCmdList["T0_CMD"] = function()
    _G.func_ToggleT0Window()
end

-- 6. Setup Ctrl + Numpad 1 keybinding via secure button
local toggleBtn = CreateFrame("Button", "T0_KeybindButton", nil, "SecureActionButtonTemplate")
toggleBtn:SetAttribute("type", "macro")
toggleBtn:SetAttribute("macrotext", "/t0")

toggleBtn:SetScript("OnClick", function()
    _G.func_ToggleT0Window()
end)



--






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
    -- Guard clause: Do nothing if the module is disabled in t0_Entry
    if not ForeverTrack_DB["t1_TrackMap"] then
        return
    end


    -- FIX: Debounce to prevent the gamepad from firing on both Button-Down and Button-Up
    if GetTime() - lastToggleTime < 0.2 then return end
    lastToggleTime = GetTime()

    local f = core.Modules.T1
    if not f then
        print("t1_TrackMap is disabled or missing.")
        return
    end

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
        if core.Modules.T2_NPCFrame:IsShown() then
            core.Modules.T2_NPCFrame:Hide()
        else
            core.Modules.T2_NPCFrame:Show()
        end
    end
end


-- T3 Slash Command
SLASH_T3_CMD1 = "/t3"
SlashCmdList["T3_CMD"] = function(msg)
    msg = msg and strtrim(msg) or ""

    if msg ~= "" then
        local questID = tonumber(msg)
        if questID then
            if _G.func_ToggleT3Window then _G.func_ToggleT3Window(questID) end
        else
            print("|cFFFF3333[T3]|r Invalid quest ID. Usage: /t3 OR /t3 <QuestID>")
        end
    else
        if _G.func_ToggleT3Window then _G.func_ToggleT3Window() end
    end
end



-- ==========================================
-- T4 Slash Command & Toggle
-- ==========================================
_G.func_ToggleT4Window = function()
    local f4 = core.Modules.T4 or _G["t4_TrackRes"]
    if not f4 then
        print("|cFFFF2020[T4]|r t4_TrackRes is disabled or missing.")
        return
    end

    if f4:IsShown() then
        f4:Hide()
    else
        f4:Show()
    end
end

SLASH_T4_CMD1 = "/t4"
SlashCmdList["T4_CMD"] = function()
    if _G.func_ToggleT4Window then
        _G.func_ToggleT4Window()
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


--
local t3ToggleBtn = CreateFrame("Button", "T3_KeybindButton", UIParent)
t3ToggleBtn:SetSize(1, 1)
t3ToggleBtn:SetAlpha(0)
t3ToggleBtn:RegisterForClicks("AnyDown")
t3ToggleBtn:SetScript("OnClick", function()
    if _G.func_ToggleT3Window then _G.func_ToggleT3Window() end
end)

local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)

    SetBinding("PADBACK", nil)

    SetBindingClick("CTRL-NUMPAD0", "T0_KeybindButton")
    SetBindingClick("CTRL-NUMPAD1", "Entry_KeybindButton")
    SetBindingClick("CTRL-NUMPAD3", "T3_KeybindButton") -- NEW: T3 Keybind

    SaveBindings(GetCurrentBindingSet() or 1)
end)




-- T4 Hidden Clickable Button
local t4ToggleBtn = CreateFrame("Button", "T4_KeybindButton", UIParent)
t4ToggleBtn:SetSize(1, 1)
t4ToggleBtn:SetAlpha(0)
t4ToggleBtn:RegisterForClicks("AnyDown")
t4ToggleBtn:SetScript("OnClick", function()
    if _G.func_ToggleT4Window then
        _G.func_ToggleT4Window()
    end
end)

-- Unified Bind Initializer
local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)

    SetBinding("PADBACK", nil)

    SetBindingClick("CTRL-NUMPAD0", "T0_KeybindButton")
    SetBindingClick("CTRL-NUMPAD1", "Entry_KeybindButton")
    SetBindingClick("CTRL-NUMPAD3", "T3_KeybindButton")
    SetBindingClick("CTRL-NUMPAD4", "T4_KeybindButton") -- Added T4 Binding

    SaveBindings(GetCurrentBindingSet() or 1)
end)



-- ==========================================
-- Custom Window Focus Cycler
-- ==========================================
local function CycleCustomWindows()
    local f1 = core.Modules.T1 or _G["t1_TrackMap"]
    local f3 = core.Modules.T3 or _G["t3_TrackQst"]
    local f4 = core.Modules.T4 or _G["t4_TrackRes"]

    -- Collect all currently open and uncollapsed windows
    local openWindows = {}
    if f1 and f1:IsShown() and (f1:GetHeight() > 100) then table.insert(openWindows, { frame = f1, id = 1 }) end
    if f3 and f3:IsShown() and (f3:GetHeight() > 100) then table.insert(openWindows, { frame = f3, id = 3 }) end
    if f4 and f4:IsShown() and (f4:GetHeight() > 100) then table.insert(openWindows, { frame = f4, id = 4 }) end

    if #openWindows == 0 then return end

    -- Determine which window currently has focus
    local currentIndex = 0
    for i, win in ipairs(openWindows) do
        if win.id == 1 and win.frame.isMapFocused then currentIndex = i end
        if (win.id == 3 or win.id == 4) and win.frame.isFocused then currentIndex = i end
    end

    -- Clear focus on all custom windows
    if f1 then
        if f1.SetMapFocus then f1:SetMapFocus(false) else f1.isMapFocused = false end
        if f1.title then f1.title:SetTextColor(1, 1, 1) end
    end
    if f3 then
        if f3.SetFocus then f3:SetFocus(false) else f3.isFocused = false end
        if f3.title then f3.title:SetTextColor(1, 1, 1) end
    end
    if f4 then
        if f4.SetFocus then f4:SetFocus(false) else f4.isFocused = false end
        if f4.title then f4.title:SetTextColor(1, 1, 1) end
    end

    -- If exactly 1 window is open and it was already focused, we just dropped its focus. Stop here.
    if #openWindows == 1 and currentIndex == 1 then
        return
    end

    -- Target the next window in the list (wrap around to 1)
    local nextIndex = currentIndex + 1
    if nextIndex > #openWindows then nextIndex = 1 end

    -- Apply focus to the target window
    local nextWin = openWindows[nextIndex]
    if nextWin.id == 1 then
        if nextWin.frame.SetMapFocus then nextWin.frame:SetMapFocus(true) else nextWin.frame.isMapFocused = true end
        if nextWin.frame.title then nextWin.frame.title:SetTextColor(1, 0.82, 0) end
    elseif nextWin.id == 3 or nextWin.id == 4 then
        if nextWin.frame.SetFocus then nextWin.frame:SetFocus(true) else nextWin.frame.isFocused = true end
        if nextWin.frame.title then nextWin.frame.title:SetTextColor(1, 0.82, 0) end
    end
    nextWin.frame:Raise()
end

local cycleBtn = CreateFrame("Button", "Entry_CycleButton", UIParent)
cycleBtn:SetScript("OnClick", function()
    CycleCustomWindows()
end)



-- ==========================================
-- Dynamic Hardware Poller (L2 + Select, Pan, Zoom, L3/R3, Unfocus)
-- ==========================================
local isL2Held = false
local wasSelectPressed = false
local wasStartPressed = false
local wasL3Pressed = false
local wasR3Pressed = false
local wasAPressed = false
local wasBPressed = false

-- ==========================================================
-- Tracked Gamepad Key Registry for HUD & Custom Actions
-- ==========================================================
local trackedPadKeys = {
    -- Corrected D-Pad API IDs
    "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",

    -- Face Buttons (A = PAD1, B = PAD2, X = PAD3, Y = PAD4)
    "PAD1", "PAD2", "PAD3", "PAD4",

    -- Bumpers & Triggers
    "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER",

    -- Sticks & Meta
    "PADLSTICK", "PADRSTICK", "PADBACK", "PADFORWARD"
}

local prevKeyState = {}


-- Helper to detect if standard built-in windows are open
local function AreAnyUIPanelsOpen()
    if GetUIPanel then
        return GetUIPanel("left") or GetUIPanel("center") or GetUIPanel("right") or GetUIPanel("doublewide") or
            GetUIPanel("fullscreen")
    end
    return false
end

toggleBtn:SetScript("OnUpdate", function(self, elapsed)
    elapsed = elapsed or (1 / 60)

    local l2Down = IsKeyDown("PADLTRIGGER")
    local selectDown = IsKeyDown("PADBACK")
    local startDown = IsKeyDown("PADFORWARD")
    local l3Down = IsKeyDown("PADLSTICK")
    local r3Down = IsKeyDown("PADRSTICK")
    local aDown = IsKeyDown("PAD1")
    local bDown = IsKeyDown("PAD2")

    -- 1. L2 Modifier Hijack (Must check CombatLockdown to avoid WoW UI errors)
    if not InCombatLockdown() then
        if l2Down and not isL2Held then
            isL2Held = true
            SetOverrideBindingClick(self, true, "PADBACK", "Entry_KeybindButton")
        elseif not l2Down and isL2Held then
            isL2Held = false
            ClearOverrideBindings(self)
        end
    end


    -- 2. Custom Window Focus Cycling (Select button)
    if selectDown and not wasSelectPressed then
        if not l2Down then
            -- Only cycle if WoW isn't natively trying to close a built-in window
            if not AreAnyUIPanelsOpen() then
                CycleCustomWindows()
            end
        end
    end

    -- 3. Panic / Unfocus Button (Start / Pause)
    if startDown and not wasStartPressed then
        local f1 = core.Modules.T1 or _G["t1_TrackMap"]
        local f3 = core.Modules.T3 or _G["t3_TrackQst"]
        local f4 = core.Modules.T4 or _G["t4_TrackRes"]

        if f1 and f1.isMapFocused then f1:SetMapFocus(false) end
        if f3 and f3.SetFocus then f3:SetFocus(false) elseif f3 then f3.isFocused = false end
        if f4 and f4.SetFocus then f4:SetFocus(false) elseif f4 then f4.isFocused = false end
    end


    wasSelectPressed = selectDown
    wasStartPressed = startDown

    -- 3. Gamepad Controls (Requires L2 + A Window Focused)
    if l2Down then
        local f = core.Modules.T1

        -- If T1 Map is focused, route controls to it
        if f and f:IsShown() and f.isMapFocused then
            -- --- A (PAD1): ENTER CURRENT ZONE MAP ---
            if aDown and not wasAPressed then
                local currentZoneID = C_Map.GetBestMapForUnit("player")
                if currentZoneID and currentZoneID > 0 then
                    if f.currentMapID ~= currentZoneID then
                        f:LoadMap(currentZoneID)
                        if f.UpdateMapTransform then f:UpdateMapTransform() end
                    end
                end
            end

            -- --- B (PAD2): RETURN TO WORLD MAP ---
            if bDown and not wasBPressed then
                if f.currentMapID ~= 947 then
                    f:LoadMap(947)
                    if f.UpdateMapTransform then f:UpdateMapTransform() end
                end
            end


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

    -- ------------------------------------------------------
    -- Hardware Poller for Visualizer (T4)
    -- ------------------------------------------------------
    local t4 = core.Modules.T4 or _G["t4_TrackRes"]
    local isT4Active = t4 and t4:IsShown()

    for _, key in ipairs(trackedPadKeys) do
        local isDown = IsKeyDown(key)

        if isT4Active and t4.SetButtonState then
            t4:SetButtonState(key, isDown)
        end

        prevKeyState[key] = isDown
    end

    -- Update Joystick positions on the visualizer
    if isT4Active and t4.UpdateSticks then
        local lx, ly, rx, ry = 0, 0, 0, 0
        if C_GamePad and C_GamePad.GetActiveDeviceID then
            local deviceID = C_GamePad.GetActiveDeviceID()
            if deviceID then
                local state = C_GamePad.GetDeviceMappedState(deviceID)
                if state and state.sticks then
                    local ls = state.sticks[1]
                    local rs = state.sticks[2]
                    -- Note: Sticks naturally rest slightly off-center (deadzone).
                    -- You can wrap this in a `math.abs(val) > 0.1` deadzone check if desired.
                    if ls then lx, ly = ls.x, ls.y end
                    if rs then rx, ry = rs.x, rs.y end
                end
            end
        end
        t4:UpdateSticks(lx, ly, rx, ry)
    end


    --
    wasL3Pressed = l3Down
    wasR3Pressed = r3Down
    wasAPressed = aDown -- NEW
    wasBPressed = bDown -- NEW
end)



-- ==========================================
-- Game Menu Suppressor
-- ==========================================
hooksecurefunc("ToggleGameMenu", function()
    local f1 = core.Modules.T1 or _G["t1_TrackMap"]
    local f3 = core.Modules.T3 or _G["t3_TrackQst"]
    local f4 = core.Modules.T4 or _G["t4_TrackRes"]

    local hasT1 = f1 and f1:IsShown() and (f1:GetHeight() > 100)
    local hasT3 = f3 and f3:IsShown() and (f3:GetHeight() > 100)
    local hasT4 = f4 and f4:IsShown() and (f4:GetHeight() > 100)

    -- If custom windows are open and the Game Menu popped up, hide it instantly.
    if (hasT1 or hasT3 or hasT4) and GameMenuFrame and GameMenuFrame:IsShown() then
        HideUIPanel(GameMenuFrame)
    end
end)
