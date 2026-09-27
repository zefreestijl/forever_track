-- 1. Create the Main Frame using Blizzard's built-in template
local f = CreateFrame("Frame", "t0_BlankPanel", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(400, 300) -- Width and Height
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) -- Position in the middle of the screen

-- Enable moving/dragging around the screen
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

-- 2. Add a Title Text
f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f, "TOP", 0, -6)
f.title:SetText("t0_BlankPanel - Zone 2521")

-- 3. Create a Container for the Map
f.MapContainer = CreateFrame("Frame", nil, f)
f.MapContainer:SetSize(370, 230) -- Fits inside the 400x300 inset
f.MapContainer:SetPoint("CENTER", f, "CENTER", 0, -10)
f.MapContainer:SetClipsChildren(true) -- Keeps textures from spilling out

-- 4. Create a Custom Collapse (Minimize) Button next to the close button
local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
collapseBtn:SetText("_")

-- Track collapsed state
local isCollapsed = false

collapseBtn:SetScript("OnClick", function()
    if isCollapsed then
        -- Restore full size and show background elements
        f:SetHeight(300)
        if f.Bg then f.Bg:Show() end
        if f.InsetBg then f.InsetBg:Show() end
        f.MapContainer:Show()
        collapseBtn:SetText("_")
        isCollapsed = false
    else
        -- Collapse down to just the header bar and hide backgrounds
        f:SetHeight(32)
        if f.Bg then f.Bg:Hide() end
        if f.InsetBg then f.InsetBg:Hide() end
        f.MapContainer:Hide()
        collapseBtn:SetText("+")
        isCollapsed = true
    end
end)

-- 5. Render the Map (ZoneID 2521) using C_Map API safely
local function RenderMap(zoneID)
    local layers = C_Map.GetMapArtLayers(zoneID)
    
    if layers and layers[1] then
        local layerInfo = layers[1]
        local textures = C_Map.GetMapArtLayerTextures(zoneID, 1)

        local totalWidth = layerInfo.layerWidth
        local totalHeight = layerInfo.layerHeight
        local tileWidth = layerInfo.tileWidth
        local tileHeight = layerInfo.tileHeight

        -- Calculate scale to fit our 370x230 MapContainer
        local scale = math.min(370 / totalWidth, 230 / totalHeight)
        
        local scaledTileWidth = tileWidth * scale
        local scaledTileHeight = tileHeight * scale

        local numCols = math.ceil(totalWidth / tileWidth)
        local actualMapWidth = totalWidth * scale
        local actualMapHeight = totalHeight * scale

        -- A. Stitch the base texture tiles together
        if textures then
            for i, fileDataID in ipairs(textures) do
                local row = math.floor((i - 1) / numCols)
                local col = (i - 1) % numCols

                local t = f.MapContainer:CreateTexture(nil, "BACKGROUND")
                t:SetTexture(fileDataID)
                t:SetSize(scaledTileWidth, scaledTileHeight)
                t:SetPoint("TOPLEFT", f.MapContainer, "TOPLEFT", col * scaledTileWidth, -row * scaledTileHeight)
            end
        end

        -- B. Draw Fog of War (Exploration) safely if available
        if C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures then
            local exploredTextures = C_MapExplorationInfo.GetExploredMapTextures(zoneID)
            if exploredTextures then
                for _, expInfo in ipairs(exploredTextures) do
                    local textureID = (expInfo.fileDataIDs and expInfo.fileDataIDs[1]) or expInfo.textureWidth
                    if textureID then
                        local t = f.MapContainer:CreateTexture(nil, "ARTWORK")
                        t:SetTexture(textureID)
                        t:SetSize(expInfo.textureWidth * scale, expInfo.textureHeight * scale)
                        t:SetPoint("TOPLEFT", f.MapContainer, "TOPLEFT", expInfo.offsetX * scale, -expInfo.offsetY * scale)
                    end
                end
            end
        end

        -- C. Draw Map Labels safely if available
        if C_Map.GetMapLabels then
            local mapLabels = C_Map.GetMapLabels(zoneID)
            if mapLabels then
                for _, labelInfo in ipairs(mapLabels) do
                    if labelInfo and labelInfo.name then
                        local textString = f.MapContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        textString:SetText(labelInfo.name)
                        local x = (labelInfo.normalizedX or 0) * actualMapWidth
                        local y = (labelInfo.normalizedY or 0) * actualMapHeight
                        textString:SetPoint("CENTER", f.MapContainer, "TOPLEFT", x, -y)
                    end
                end
            end
        end
    else
        print("|cFFFF0000t0_BlankPanel Error: Could not load map layers for Zone ID " .. tostring(zoneID) .. ".|r")
    end
end

-- Initialize the map for Zone 2521
RenderMap(2521)

-- 6. Make the window close when pressing the ESC key
tinsert(UISpecialFrames, f:GetName())

-- 7. Hide it by default on load, provide the /t0 slash command
f:Hide()

local function ToggleT0Window()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

SLASH_T0_CMD1 = "/t0"
SlashCmdList["T0_CMD"] = function()
    ToggleT0Window()
end

-- 8. Setup Ctrl + Numpad keybinding via secure button
local toggleBtn = CreateFrame("Button", "T0_KeybindButton", UIParent, "SecureActionButtonTemplate")
toggleBtn:SetAttribute("type", "macro")
toggleBtn:SetAttribute("macrotext", "/t0")

toggleBtn:SetScript("OnClick", function()
    ToggleT0Window()
end)

local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    SetBindingClick("CTRL-NUMPAD0", "T0_KeybindButton")
    SaveBindings(GetCurrentBindingSet())
end)

print("|cFF00FF00t0_BlankPanel loaded successfully! Type /t0 or press Ctrl+Numpad 0 to toggle.|r")