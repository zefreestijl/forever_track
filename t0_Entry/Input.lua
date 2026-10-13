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

    if not t0Frame:IsShown() then
        -- 1. Show the t0_Entry window (Removed UIParent:Hide() to prevent Taint)
        t0Frame:Show()
        -- NEW: Auto-focus the dashboard when opened
        if t0Frame.SetFocus then t0Frame:SetFocus(true) end


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
        -- 1. Drop focus from the dashboard
        if t0Frame.SetFocus then t0Frame:SetFocus(false) end

        -- 2. Hide ONLY the t0_Entry window
        t0Frame:Hide()
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
local toggleBtn = CreateFrame("Button", "Entry_KeybindButton", nil)
toggleBtn:SetSize(1, 1)
toggleBtn:SetAlpha(0)
toggleBtn:RegisterForClicks("AnyDown")
toggleBtn:SetScript("OnClick", function()
    if _G.func_ToggleT0Window then _G.func_ToggleT0Window() end
end)

local t3ToggleBtn = CreateFrame("Button", "T3_KeybindButton", nil)
t3ToggleBtn:SetSize(1, 1)
t3ToggleBtn:SetAlpha(0)
t3ToggleBtn:RegisterForClicks("AnyDown")
t3ToggleBtn:SetScript("OnClick", function()
    if _G.func_ToggleT3Window then _G.func_ToggleT3Window() end
end)

local t4ToggleBtn = CreateFrame("Button", "T4_KeybindButton", nil)
t4ToggleBtn:SetSize(1, 1)
t4ToggleBtn:SetAlpha(0)
t4ToggleBtn:RegisterForClicks("AnyDown")
t4ToggleBtn:SetScript("OnClick", function()
    if _G.func_ToggleT4Window then _G.func_ToggleT4Window() end
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

    -- FIX: Force 1 to prevent client version mismatch errors
    -- SaveBindings(1)
    -- Forcing a global binding save during login severely taints the Gamepad UI.
end)

-- ==========================================
-- Custom Window Focus Cycler
-- ==========================================


-- ==========================================
-- Custom Window Focus Cycler
-- ==========================================
local function CycleCustomWindows()
    local f0 = core.Modules.T0 or _G["t0_Entry"]
    local fDebug = core.Modules.T0_Debug or _G["GamepadLayout"]
    local f1 = core.Modules.T1 or _G["t1_TrackMap"]
    local f3 = core.Modules.T3 or _G["t3_TrackQst"]
    local f4 = core.Modules.T4 or _G["t4_TrackRes"]

    -- Collect all currently open and uncollapsed windows
    local openWindows = {}
    if f0 and f0:IsShown() and (f0:GetHeight() > 100) then table.insert(openWindows, { frame = f0, id = 0 }) end
    if fDebug and fDebug:IsShown() then table.insert(openWindows, { frame = fDebug, id = 99 }) end
    if f1 and f1:IsShown() and (f1:GetHeight() > 100) then table.insert(openWindows, { frame = f1, id = 1 }) end
    if f3 and f3:IsShown() and (f3:GetHeight() > 100) then table.insert(openWindows, { frame = f3, id = 3 }) end
    if f4 and f4:IsShown() and (f4:GetHeight() > 100) then table.insert(openWindows, { frame = f4, id = 4 }) end

    if #openWindows == 0 then return end

    -- Determine which window currently has focus
    local currentIndex = 0
    for i, win in ipairs(openWindows) do
        if win.id == 1 and win.frame.isMapFocused then currentIndex = i end
        if (win.id == 0 or win.id == 3 or win.id == 4 or win.id == 99) and win.frame.isFocused then currentIndex = i end
    end

    -- Clear focus on all custom windows
    if f0 then if f0.SetFocus then f0:SetFocus(false) else f0.isFocused = false end end
    if fDebug then if fDebug.SetFocus then fDebug:SetFocus(false) else fDebug.isFocused = false end end
    if f1 then
        if f1.SetMapFocus then f1:SetMapFocus(false) else f1.isMapFocused = false end; if f1.title then
            f1.title
                :SetTextColor(1, 1, 1)
        end
    end
    if f3 then if f3.SetFocus then f3:SetFocus(false) else f3.isFocused = false end end
    if f4 then if f4.SetFocus then f4:SetFocus(false) else f4.isFocused = false end end

    -- If exactly 1 window is open and it was already focused, we just dropped its focus. Stop here.
    if #openWindows == 1 and currentIndex == 1 then return end

    -- Target the next window in the list (wrap around to 1)
    local nextIndex = currentIndex + 1
    if nextIndex > #openWindows then nextIndex = 1 end

    -- Apply focus to the target window
    local nextWin = openWindows[nextIndex]
    if nextWin.id == 1 then
        if nextWin.frame.SetMapFocus then nextWin.frame:SetMapFocus(true) else nextWin.frame.isMapFocused = true end
        if nextWin.frame.title then nextWin.frame.title:SetTextColor(1, 0.82, 0) end
    elseif nextWin.id == 0 or nextWin.id == 3 or nextWin.id == 4 or nextWin.id == 99 then
        if nextWin.frame.SetFocus then nextWin.frame:SetFocus(true) else nextWin.frame.isFocused = true end
    end
    nextWin.frame:Raise()
end


--
local cycleBtn = CreateFrame("Button", "Entry_CycleButton", nil)
cycleBtn:SetScript("OnClick", function()
    local f0 = core.Modules.T0; local f1 = core.Modules.T1; local f3 = core.Modules.T3; local f4 = core.Modules.T4
    if not ((f0 and f0:IsShown()) or (f1 and f1:IsShown()) or (f3 and f3:IsShown()) or (f4 and f4:IsShown())) then
        ToggleWorldMap()
    end
end)

local startBtn = CreateFrame("Button", "Entry_StartButton", nil)
startBtn:SetScript("OnClick", function()
    local f0 = core.Modules.T0; local f1 = core.Modules.T1; local f3 = core.Modules.T3; local f4 = core.Modules.T4
    if not ((f0 and f0:IsShown()) or (f1 and f1:IsShown()) or (f3 and f3:IsShown()) or (f4 and f4:IsShown())) then
        ToggleGameMenu()
    end
end)

local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)

    SetBinding("PADBACK", nil) -- Keep PADBACK unbound natively to prevent conflicts
    -- We do NOT bind PADFORWARD, allowing it to natively open the Game Menu securely

    SetBindingClick("CTRL-NUMPAD0", "T0_KeybindButton")
    SetBindingClick("CTRL-NUMPAD1", "Entry_KeybindButton")
    SetBindingClick("CTRL-NUMPAD3", "T3_KeybindButton")
    SetBindingClick("CTRL-NUMPAD4", "T4_KeybindButton")
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


    -- REMOVED the old L2 Modifier Hijack block, we handle this purely with hardware polling now.

    -- 1. L2 + Select (Toggle T0) OR Single Select (Cycle Windows)
    if selectDown and not wasSelectPressed then
        if l2Down then
            if _G.func_ToggleT0Window then _G.func_ToggleT0Window() end
        else
            if not AreAnyUIPanelsOpen() then
                CycleCustomWindows()
            end
        end
    end

    -- 2. Panic / Close T0 Button (Single Start / Pause)
    if startDown and not wasStartPressed then
        local f0 = core.Modules.T0 or _G["t0_Entry"]
        local fDebug = core.Modules.T0_Debug or _G["GamepadLayout"]
        local f1 = core.Modules.T1 or _G["t1_TrackMap"]
        local f3 = core.Modules.T3 or _G["t3_TrackQst"]
        local f4 = core.Modules.T4 or _G["t4_TrackRes"]

        local isAnyCustomWindowOpen = (f0 and f0:IsShown()) or (fDebug and fDebug:IsShown()) or (f1 and f1:IsShown()) or
        (f3 and f3:IsShown()) or (f4 and f4:IsShown())

        if isAnyCustomWindowOpen then
            -- Close T0 Dashboard if it's open
            if f0 and f0:IsShown() then _G.func_ToggleT0Window() end

            -- Explicitly hide the debug layout if it was expanded
            if fDebug and fDebug:IsShown() then fDebug:Hide() end

            -- Unfocus the remaining open custom windows (T1, T3, T4)
            if f1 and f1.isMapFocused then f1:SetMapFocus(false) end
            if f3 and f3.SetFocus then f3:SetFocus(false) elseif f3 then f3.isFocused = false end
            if f4 and f4.SetFocus then f4:SetFocus(false) elseif f4 then f4.isFocused = false end

            -- Hide the native Game Menu that WoW just tried to open securely
            if GameMenuFrame and GameMenuFrame:IsShown() then
                GameMenuFrame:Hide()
            end
        end
    end


    wasSelectPressed = selectDown
    wasStartPressed = startDown

    -- 3. Gamepad Controls (Requires L2 + A Window Focused)
    if l2Down then
        local f = core.Modules.T1

        -- If T1 Map is focused, route controls to it
        if f and f:IsShown() and f.isMapFocused then
            -- --- R3: ZOOM TO FIT MAP ---
            if r3Down and not wasR3Pressed then
                if f.UpdateMapTransform then f:UpdateMapTransform() end
            end
        end
    end

    -- ------------------------------------------------------
    -- Hardware Poller for Visualizer (GamepadLayout)
    -- ------------------------------------------------------
    local debugPanel = core.Modules.T0_Debug or _G["GamepadLayout"]
    local isDebugActive = debugPanel and debugPanel:IsShown()

    for _, key in ipairs(trackedPadKeys) do
        local isDown = IsKeyDown(key)

        if isDebugActive and debugPanel.SetButtonState then
            debugPanel:SetButtonState(key, isDown)
        end

        prevKeyState[key] = isDown
    end

    -- Update Joystick positions on the visualizer
    if isDebugActive and debugPanel.UpdateSticks then
        local lx, ly, rx, ry = 0, 0, 0, 0
        if C_GamePad and C_GamePad.GetActiveDeviceID then
            local deviceID = C_GamePad.GetActiveDeviceID()
            if deviceID then
                local state = C_GamePad.GetDeviceMappedState(deviceID)
                if state and state.sticks then
                    local ls = state.sticks[1]
                    local rs = state.sticks[2]
                    -- Note: Sticks naturally rest slightly off-center (deadzone).
                    if ls then lx, ly = ls.x, ls.y end
                    if rs then rx, ry = rs.x, rs.y end
                end
            end
        end
        debugPanel:UpdateSticks(lx, ly, rx, ry)
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
