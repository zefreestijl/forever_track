local addonName, TrackCore = ...
TrackCore.T2_NPCFrame = CreateFrame("Frame", "t2_TrackNPC", UIParent, "BasicFrameTemplateWithInset")

local f = TrackCore.T2_NPCFrame


--
f:SetSize(320, 480)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")

f:SetResizable(true)
if f.SetResizeBounds then
    f:SetResizeBounds(320, 250, 320, 1200)
else
    f:SetMinResize(320, 250)
    f:SetMaxResize(320, 1200)
end

f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if type(T2_NPC_DATA) == "table" then
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint(1)
        T2_NPC_DATA.windowPos = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
    end
end)

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f, "TOP", 0, -6)
f.title:SetText("t2_TrackNPC")

local RefreshLogDisplay

-- ==========================================
-- Search Box
-- ==========================================
local currentSearchQuery = ""
local searchBox = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
searchBox:SetSize(200, 20)
searchBox:SetPoint("TOP", f, "TOP", 0, -25)
searchBox:SetAutoFocus(false)

searchBox:SetScript("OnTextChanged", function(self)
    SearchBoxTemplate_OnTextChanged(self)
    if self:GetText() == "" then
        currentSearchQuery = ""
        if RefreshLogDisplay then RefreshLogDisplay() end
    end
end)

searchBox:SetScript("OnEnterPressed", function(self)
    currentSearchQuery = strtrim(self:GetText()):lower()
    if RefreshLogDisplay then RefreshLogDisplay() end
    self:ClearFocus()
end)

searchBox:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    currentSearchQuery = ""
    if RefreshLogDisplay then RefreshLogDisplay() end
    self:ClearFocus()
end)

-- ==========================================
-- State Variables & Session Database
-- ==========================================
local activeRegion = nil
local activeTabZone = nil
local isCollapsed = false
local selectedItemIndex = nil
local collapsedGroups = {}

-- NEW: In-memory list that merges Static DBs and User Notes
local Session_NPC_List = {}

local inputBox, inputLabel, CollapseWindow

local function GetContinent(regionName)
    if not regionName then return "Unknown Region" end
    local c = string.match(regionName, "^(.-)%s*<.*>$")
    if c then return strtrim(c) end
    return strtrim(regionName)
end

-- ==========================================
-- Core Functions
-- ==========================================
local resizeHandle

CollapseWindow = function(collapse)
    local point, relativeTo, relativePoint, xOfs, yOfs = f:GetPoint(1)
    if not collapse then
        local targetHeight = (T2_NPC_DATA and T2_NPC_DATA.windowHeight) or 480
        f:SetSize(320, targetHeight)
        if f.Bg then f.Bg:Show() end
        if f.InsetBg then f.InsetBg:Show() end
        if f.scrollArea then f.scrollArea:Show() end
        if inputBox then inputBox:Show() end
        if inputLabel then inputLabel:Show() end
        if f.scanBtn then f.scanBtn:Show() end
        if f.clearBtn then f.clearBtn:Show() end
        if f.tabContainer then f.tabContainer:Show() end
        if resizeHandle then resizeHandle:Show() end
        f.collapseBtn:SetText("_")
        isCollapsed = false
        if searchBox then searchBox:Show() end
    else
        if f.Bg then f.Bg:Hide() end
        if f.InsetBg then f.InsetBg:Hide() end
        if f.scrollArea then f.scrollArea:Hide() end
        if inputBox then inputBox:Hide() end
        if inputLabel then inputLabel:Hide() end
        if f.scanBtn then f.scanBtn:Hide() end
        if f.clearBtn then f.clearBtn:Hide() end
        if f.tabContainer then f.tabContainer:Hide() end
        if resizeHandle then resizeHandle:Hide() end
        f:SetSize(320, 32)
        f.collapseBtn:SetText("+")
        isCollapsed = true
        if searchBox then searchBox:Hide() end
    end
    if point and relativeTo then
        f:ClearAllPoints()
        f:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
    end
end

local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
collapseBtn:SetText("_")
collapseBtn:SetScript("OnClick", function() CollapseWindow(not isCollapsed) end)
f.collapseBtn = collapseBtn

resizeHandle = CreateFrame("Button", nil, f)
resizeHandle:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
resizeHandle:SetSize(16, 16)
resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeHandle:SetScript("OnMouseDown", function() f:StartSizing("BOTTOM") end)
resizeHandle:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    if type(T2_NPC_DATA) == "table" then
        T2_NPC_DATA.windowHeight = f:GetHeight()
    end
end)

local scrollArea = CreateFrame("ScrollFrame", "T2_TrackNPCScrollFrame", f, "UIPanelScrollFrameTemplate")
scrollArea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 75)
f.scrollArea = scrollArea

scrollArea:SetScript("OnMouseWheel", function(self, delta)
    local scrollBar = _G[self:GetName() .. "ScrollBar"]
    if scrollBar then
        local scrollStep = 90
        local minVal, maxVal = scrollBar:GetMinMaxValues()
        local newVal = scrollBar:GetValue() - (delta * scrollStep)
        if newVal < minVal then newVal = minVal end
        if newVal > maxVal then newVal = maxVal end
        scrollBar:SetValue(newVal)
    end
end)

local content = CreateFrame("Frame", nil, scrollArea)
content:SetSize(330, 1)
scrollArea:SetScrollChild(content)
content.rows = {}

local tabContainer = CreateFrame("Frame", nil, f)
tabContainer:SetSize(330, 28)
tabContainer:Show()
f.tabContainer = tabContainer
tabContainer.tabs = {}
tabContainer.labels = {}


-- ==========================================
-- Database Merger (Static Data + User Notes)
-- ==========================================
local function BuildSessionDatabase()
    Session_NPC_List = {}
    if type(T2_NPC_DATA.customNotes) ~= "table" then T2_NPC_DATA.customNotes = {} end

    for globalName, globalData in pairs(_G) do
        if type(globalName) == "string" and string.sub(globalName, 1, 3) == "DB_"
            and type(globalData) == "table" and type(globalData.entries) == "table" then
            local fileMapID = globalData.mapID
            local mapInfo = nil

            -- RESTORED: Fetch the localized map info from the client
            if type(fileMapID) == "number" then
                mapInfo = C_Map.GetMapInfo(fileMapID)
            end

            -- RESTORED: Use the API map name if the DB file doesn't hardcode a zoneName
            local fileZoneName = globalData.zoneName
            if not fileZoneName or fileZoneName == "" then
                fileZoneName = mapInfo and mapInfo.name or "Unknown Zone"
            end

            local fileRegion = globalData.region or "Unknown Region"

            for _, entry in ipairs(globalData.entries) do
                local newEntry = {}
                for k, v in pairs(entry) do newEntry[k] = v end

                newEntry.mapID = entry.mapID or fileMapID
                newEntry.mainLocation = fileZoneName
                newEntry.subLocation = entry.subLocation or fileZoneName
                newEntry.region = entry.region or fileRegion

                -- MERGE: Overwrite static comment if user has a custom note saved
                local nID = tostring(newEntry.id or "")
                if nID ~= "" and T2_NPC_DATA.customNotes[nID] then
                    newEntry.comment = T2_NPC_DATA.customNotes[nID].comment
                end

                table.insert(Session_NPC_List, newEntry)
            end
        end
    end
end



local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        if type(T2_NPC_DATA) ~= "table" then T2_NPC_DATA = {} end
        if type(T2_NPC_DATA.customNotes) ~= "table" then T2_NPC_DATA.customNotes = {} end

        BuildSessionDatabase()

        if type(T2_NPC_DATA.windowPos) == "table" then
            local pos = T2_NPC_DATA.windowPos
            f:ClearAllPoints()
            f:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
        end

        if T2_NPC_DATA.windowHeight then
            f:SetHeight(T2_NPC_DATA.windowHeight)
        end

        RefreshLogDisplay()
        --print("|cFF00FF00t2_TrackNPC Loaded! Working Entries: " .. #Session_NPC_List .. "|r")
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

local RefreshTabs

RefreshLogDisplay = function()
    for _, row in ipairs(content.rows) do
        row:Hide()
        row:SetParent(nil)
    end
    content.rows = {}
    RefreshTabs()

    if #Session_NPC_List == 0 then
        local emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
        emptyLabel:SetText("(Log is currently empty. Add static DB files.)")
        table.insert(content.rows, emptyLabel)
        content:SetSize(330, 40)
        return
    end

    if not activeRegion then
        local emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
        emptyLabel:SetText("Please select a Region from the index above.")
        table.insert(content.rows, emptyLabel)
        content:SetSize(300, 40)
        return
    end

    if not activeTabZone then
        local emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
        emptyLabel:SetText("Please select a Zone from the tabs above.")
        table.insert(content.rows, emptyLabel)
        content:SetSize(330, 40)
        return
    end

    local filteredEntries = {}
    for index, item in ipairs(Session_NPC_List) do
        if item.region == activeRegion and item.mainLocation == activeTabZone then
            local passesSearch = true

            if currentSearchQuery and currentSearchQuery ~= "" then
                passesSearch = false
                local nameStr = item.name and item.name:lower() or ""
                local descStr = item.description and item.description:lower() or ""
                local commStr = item.comment and item.comment:lower() or ""

                if string.find(nameStr, currentSearchQuery, 1, true) or
                    string.find(descStr, currentSearchQuery, 1, true) or
                    string.find(commStr, currentSearchQuery, 1, true) then
                    passesSearch = true
                end
            end

            if passesSearch then
                item.originalIndex = index
                table.insert(filteredEntries, item)
            end
        end
    end

    if #filteredEntries == 0 then
        local emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
        emptyLabel:SetText("(No entries found for this zone.)")
        table.insert(content.rows, emptyLabel)
        content:SetSize(350, 40)
        return
    end

    local groupedBySubZone = {}
    for _, item in ipairs(filteredEntries) do
        local subZone = item.subLocation or "General Area"
        if not groupedBySubZone[subZone] then groupedBySubZone[subZone] = {} end
        table.insert(groupedBySubZone[subZone], item)
    end

    local yOffset = -4
    local rowHeight = 26

    for subZoneName, items in pairs(groupedBySubZone) do
        local isGroupCollapsed = collapsedGroups[subZoneName]
        local headerBtn = CreateFrame("Button", nil, content)
        headerBtn:SetSize(330, 20)
        headerBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 4, yOffset)

        local headerText = headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        headerText:SetPoint("LEFT", headerBtn, "LEFT", 0, 0)

        if isGroupCollapsed then
            headerText:SetText(string.format("|cffffd100[+] 📍 %s|r", subZoneName))
        else
            headerText:SetText(string.format("|cffffd100[-] 📍 %s|r", subZoneName))
        end

        headerBtn:SetScript("OnClick", function()
            collapsedGroups[subZoneName] = not collapsedGroups[subZoneName]
            RefreshLogDisplay()
        end)

        table.insert(content.rows, headerBtn)
        yOffset = yOffset - 22

        if not isGroupCollapsed then
            table.sort(items, function(a, b)
                local aHasComment = (a.comment and a.comment ~= "")
                local bHasComment = (b.comment and b.comment ~= "")
                if aHasComment and bHasComment then
                    if a.comment:lower() == b.comment:lower() then
                        return (a.name or "") < (b.name or "")
                    else
                        return a.comment:lower() < b.comment:lower()
                    end
                elseif aHasComment and not bHasComment then
                    return true
                elseif bHasComment and not aHasComment then
                    return false
                else
                    return (a.name or "") < (b.name or "")
                end
            end)

            for _, item in ipairs(items) do
                local row = CreateFrame("Button", nil, content)
                row:SetSize(330, rowHeight)
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)

                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints(row)

                if selectedItemIndex == item.originalIndex then
                    row.bg:SetColorTexture(0.2, 0.6, 1, 0.25)
                else
                    row.bg:SetColorTexture(1, 1, 1, 0.04)
                end

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.text:SetPoint("LEFT", row, "LEFT", 16, 0)
                row.text:SetWidth(250)
                row.text:SetJustifyH("LEFT")

                local displayString = "• " .. item.name
                if item.description and item.description ~= "" then displayString = displayString ..
                    " <" .. item.description .. ">" end
                if item.comment and item.comment ~= "" then
                    displayString = displayString .. " — " .. item.comment
                    row.text:SetTextColor(1, 0.82, 0)
                else
                    row.text:SetTextColor(0.65, 0.65, 0.65)
                end

                row.text:SetText(displayString)

                row:SetScript("OnClick", function()
                    selectedItemIndex = item.originalIndex

                    if inputBox then
                        inputBox:SetText(item.comment or "")
                        inputBox:SetFocus()
                    end

                    if inputLabel then
                        inputLabel:SetText(string.format("Editing: |cff00ff00%s|r (Press Enter to save)", item.name))
                    end

                    -- SAFTEY FIX: Convert values to numbers to prevent string mismatches from breaking the pin
                    local tMapID = tonumber(item.mapID)
                    local tX = tonumber(item.x)
                    local tY = tonumber(item.y)

                    -- Process the Pin and Zoom logic FIRST
                    if tMapID and tX and tY then
                        if _G.func_T1_SetPin then
                            _G.func_T1_SetPin(tMapID, tX, tY, 0.2, 1, 0.2)
                        else
                            print("|cFFFF0000Error: func_T1_SetPin not found in T1 addon.|r")
                        end

                        if _G.func_ToggleT1Window then
                            local capitalCities = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true,
                                [1458] = true }
                            if capitalCities[tMapID] then
                                _G.func_ToggleT1Window(tMapID)
                            else
                                _G.func_ToggleT1Window(947)
                            end
                        else
                            print("|cFFFF0000Error: T1 custom map window function not found.|r")
                        end
                    else
                        print(string.format(
                        "|cFFFF0000Error: Map Pin failed. 'mapID', 'x', or 'y' is missing or invalid for %s!|r",
                            item.name or "Unknown"))
                    end

                    -- Execute the UI refresh LAST so the button isn't destroyed during the execution above
                    RefreshLogDisplay()
                end)

                local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                delBtn:SetSize(17, 20)
                delBtn:SetPoint("RIGHT", row, "RIGHT", -53, 0)
                delBtn:SetText("X")
                delBtn:SetScript("OnClick", function()
                    if selectedItemIndex == item.originalIndex then
                        selectedItemIndex = nil
                        if inputLabel then inputLabel:SetText("Type comment and press Enter (or click Scan):") end
                        if inputBox then inputBox:SetText("") end
                    end

                    -- Remove from saved variables if it exists
                    local nID = tostring(item.id or "")
                    if nID ~= "" and T2_NPC_DATA.customNotes then
                        T2_NPC_DATA.customNotes[nID] = nil
                    end

                    table.remove(Session_NPC_List, item.originalIndex)
                    RefreshLogDisplay()
                    print("Removed entry from session and cleared saved notes.")
                end)

                yOffset = yOffset - (rowHeight + 4)
                table.insert(content.rows, row)
            end
        end
        yOffset = yOffset - 8
    end
    content:SetSize(330, math.abs(yOffset) + 10)
end

RefreshTabs = function()
    for _, tab in ipairs(tabContainer.tabs) do
        tab:Hide(); tab:SetParent(nil)
    end
    tabContainer.tabs = {}
    for _, label in ipairs(tabContainer.labels) do
        label:Hide(); label:SetParent(nil)
    end
    tabContainer.labels = {}

    local maxTabWidth = 330; local tabHeight = 20; local spacingY = 23; local spacingX = 4; local xOffset = 12; local yOffset = -12

    if not activeRegion then
        local continents = {}
        for _, item in ipairs(Session_NPC_List) do
            local r = item.region or "Unknown Region"
            local c = GetContinent(r)
            if not continents[c] then continents[c] = {} end
            local found = false
            for _, v in ipairs(continents[c]) do if v == r then
                    found = true; break
                end end
            if not found then table.insert(continents[c], r) end
        end

        local contNames = {}
        for c in pairs(continents) do table.insert(contNames, c) end
        table.sort(contNames)

        for i, cName in ipairs(contNames) do
            local groupLabel = tabContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            groupLabel:SetText(cName .. ":")
            groupLabel:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", 12, yOffset)
            groupLabel:SetTextColor(1, 0.82, 0)
            table.insert(tabContainer.labels, groupLabel)
            yOffset = yOffset - 26

            table.sort(continents[cName])
            for _, rName in ipairs(continents[cName]) do
                local tabBtn = CreateFrame("Button", nil, tabContainer, "UIPanelButtonTemplate")
                tabBtn:SetText(rName)
                tabBtn:SetWidth(math.max(180, tabBtn:GetFontString():GetStringWidth() + 24))
                tabBtn:SetHeight(tabHeight)
                tabBtn:Show()
                tabBtn:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", 24, yOffset)
                tabBtn:SetScript("OnClick", function()
                    activeRegion = rName; activeTabZone = nil; RefreshLogDisplay()
                end)
                table.insert(tabContainer.tabs, tabBtn)
                yOffset = yOffset - spacingY
            end
            if i < #contNames then yOffset = yOffset - (spacingY * 1.5) end
        end
    else
        xOffset = 12; yOffset = -4
        local upBtn = CreateFrame("Button", nil, tabContainer, "UIPanelButtonTemplate")
        upBtn:SetText("<- Up To Regions")
        upBtn:SetWidth(math.max(65, upBtn:GetFontString():GetStringWidth() + 18))
        upBtn:SetHeight(tabHeight)
        if upBtn.Left then upBtn.Left:SetVertexColor(0.55, 0.55, 0.55) end
        if upBtn.Middle then upBtn.Middle:SetVertexColor(0.55, 0.55, 0.55) end
        if upBtn.Right then upBtn.Right:SetVertexColor(0.55, 0.55, 0.55) end
        upBtn:Show()
        upBtn:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", xOffset, yOffset)
        upBtn:SetScript("OnClick", function()
            activeRegion = nil; activeTabZone = nil; RefreshLogDisplay()
        end)
        table.insert(tabContainer.tabs, upBtn)
        xOffset = xOffset + upBtn:GetWidth() + spacingX

        local zones, zoneNames = {}, {}
        for _, item in ipairs(Session_NPC_List) do
            if (item.region or "Unknown Region") == activeRegion then
                local z = item.mainLocation or "Unknown Zone"
                if not zones[z] then
                    zones[z] = true; table.insert(zoneNames, z)
                end
            end
        end
        table.sort(zoneNames)

        for _, zName in ipairs(zoneNames) do
            local tabBtn = CreateFrame("Button", nil, tabContainer, "UIPanelButtonTemplate")
            tabBtn:SetText(zName)
            tabBtn:SetWidth(math.max(65, tabBtn:GetFontString():GetStringWidth() + 18))
            tabBtn:SetHeight(tabHeight)
            tabBtn:Show()

            if (xOffset + tabBtn:GetWidth()) > maxTabWidth then
                xOffset = 12; yOffset = yOffset - spacingY
            end
            tabBtn:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", xOffset, yOffset)

            if activeTabZone == zName then
                if tabBtn.Left then tabBtn.Left:SetVertexColor(1, 1, 1) end
                if tabBtn.Middle then tabBtn.Middle:SetVertexColor(1, 1, 1) end
                if tabBtn.Right then tabBtn.Right:SetVertexColor(1, 1, 1) end
                if tabBtn:GetFontString() then tabBtn:GetFontString():SetTextColor(1, 0.82, 0) end
            else
                if tabBtn.Left then tabBtn.Left:SetVertexColor(0.4, 0.4, 0.4) end
                if tabBtn.Middle then tabBtn.Middle:SetVertexColor(0.4, 0.4, 0.4) end
                if tabBtn.Right then tabBtn.Right:SetVertexColor(0.4, 0.4, 0.4) end
                if tabBtn:GetFontString() then tabBtn:GetFontString():SetTextColor(0.5, 0.5, 0.5) end
            end

            tabBtn:SetScript("OnClick",
                function() if activeTabZone ~= zName then
                        activeTabZone = zName; RefreshLogDisplay()
                    end end)
            xOffset = xOffset + tabBtn:GetWidth() + spacingX
            table.insert(tabContainer.tabs, tabBtn)
        end
    end

    tabContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -52)
    local totalTabContainerHeight = math.abs(yOffset) + (activeRegion and tabHeight or 0) + 8
    tabContainer:SetSize(330, totalTabContainerHeight)
    scrollArea:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32 - totalTabContainerHeight - 8)
end

local function ProcessScanOrNote(customNote)
    if type(T2_NPC_DATA) ~= "table" then T2_NPC_DATA = {} end
    if type(T2_NPC_DATA.customNotes) ~= "table" then T2_NPC_DATA.customNotes = {} end

    if selectedItemIndex then
        local itemToUpdate = Session_NPC_List[selectedItemIndex]
        if itemToUpdate then
            itemToUpdate.comment = customNote or ""
            local nID = tostring(itemToUpdate.id or "")
            if nID ~= "" then
                T2_NPC_DATA.customNotes[nID] = { mapID = itemToUpdate.mapID, comment = customNote or "" }
            end
            print(string.format("Updated comment for %s.", itemToUpdate.name))
        end
        selectedItemIndex = nil
        if inputLabel then inputLabel:SetText("Type comment and press Enter (or click Scan):") end
        RefreshLogDisplay()
        return
    end

    local unit = nil
    if UnitExists("mouseover") and not UnitIsPlayer("mouseover") then
        unit = "mouseover"
    elseif UnitExists("target") and not UnitIsPlayer("target") then
        unit = "target"
    end

    local targetName = unit and UnitName(unit)
    local targetID = ""
    if unit then
        local guid = UnitGUID(unit)
        if guid then
            local _, _, _, _, _, npcID = strsplit("-", guid); targetID = npcID or ""
        end
    end

    if not targetName and (not customNote or customNote == "") then
        print("No NPC hovered/targeted and no entry selected.")
        return
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    local mainLocation = "Unknown Zone"
    if type(mapID) == "number" then
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name then mainLocation = mapInfo.name end
    end

    local subLocation = GetSubZoneText()
    if not subLocation or subLocation == "" then subLocation = mainLocation end

    local posX, posY = nil, nil
    if type(mapID) == "number" then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then posX, posY = pos:GetXY() end
    end

    local resolvedRegion = "Unknown Region"
    if mapID then
        for _, item in ipairs(Session_NPC_List) do
            if item.mapID == mapID and item.region and item.region ~= "Unknown Region" then
                resolvedRegion = item.region; break
            end
        end
    end

    if targetName then
        local existingIndex = nil
        for i, item in ipairs(Session_NPC_List) do
            if item.name == targetName then
                existingIndex = i; break
            end
        end

        if existingIndex then
            if customNote and customNote ~= "" then Session_NPC_List[existingIndex].comment = customNote end
            Session_NPC_List[existingIndex].id = targetID
            Session_NPC_List[existingIndex].mainLocation = mainLocation
            Session_NPC_List[existingIndex].subLocation = subLocation
            Session_NPC_List[existingIndex].region = resolvedRegion
            Session_NPC_List[existingIndex].mapID = mapID
            Session_NPC_List[existingIndex].x = posX
            Session_NPC_List[existingIndex].y = posY

            if targetID ~= "" then T2_NPC_DATA.customNotes[targetID] = { mapID = mapID, comment = customNote or "" } end
            print(string.format("Updated %s under [%s > %s > %s].", targetName, resolvedRegion, mainLocation, subLocation))
        else
            table.insert(Session_NPC_List,
                { category = "general", name = targetName, id = targetID, description = "", comment = customNote or "", mainLocation =
                mainLocation, subLocation = subLocation, region = resolvedRegion, mapID = mapID, x = posX, y = posY })
            if targetID ~= "" then T2_NPC_DATA.customNotes[targetID] = { mapID = mapID, comment = customNote or "" } end
            print(string.format("Added %s under [%s > %s > %s].", targetName, resolvedRegion, mainLocation, subLocation))
        end
    else
        if customNote and customNote ~= "" then
            table.insert(Session_NPC_List,
                { category = "general", name = "[Note Only]", id = "", description = "", comment = customNote, mainLocation =
                mainLocation, subLocation = subLocation, region = resolvedRegion, mapID = mapID, x = posX, y = posY })
            print(string.format("Added standalone note under [%s].", mainLocation))
        end
    end

    selectedItemIndex = nil
    if inputLabel then inputLabel:SetText("Type comment and press Enter (or click Scan):") end
    RefreshLogDisplay()
end

inputBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
inputBox:SetSize(250, 30)
inputBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 42)
inputBox:SetAutoFocus(false)
inputBox:SetTextInsets(5, 5, 5, 5)
inputBox:SetScript("OnEnterPressed",
    function(self)
        ProcessScanOrNote(self:GetText()); self:SetText(""); self:ClearFocus()
    end)
inputLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
inputLabel:SetPoint("BOTTOMLEFT", inputBox, "BOTTOMLEFT", 4, -5)
inputLabel:SetText("Type comment and press Enter (or click Scan):")

local scanBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
scanBtn:SetSize(90, 24)
scanBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
scanBtn:SetText("Scan/Update")
scanBtn:SetScript("OnClick",
    function()
        ProcessScanOrNote(inputBox:GetText()); inputBox:SetText(""); inputBox:ClearFocus()
    end)
f.scanBtn = scanBtn

local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
clearBtn:SetSize(65, 24)
clearBtn:SetPoint("LEFT", scanBtn, "RIGHT", 4, 0)
clearBtn:SetText("Clear Pin")
clearBtn:SetScript("OnClick", function()
    if _G.func_T1_ClearPins then
        _G.func_T1_ClearPins(); print("Custom map pin cleared.")
    else
        print("|cFFFF0000Error: T1 pin clear function not found.|r")
    end
end)
f.clearBtn = clearBtn

tinsert(UISpecialFrames, f:GetName())
f:Hide()

local lastToggleTime = 0

_G.func_ToggleT2Window = function(mapID)
    local currentTime = GetTime()
    if currentTime - (lastToggleTime or 0) < 0.2 then return end
    lastToggleTime = currentTime

    activeRegion = nil
    activeTabZone = nil

    if type(mapID) == "number" then
        if type(Session_NPC_List) == "table" then
            for _, entry in ipairs(Session_NPC_List) do
                if entry.mapID == mapID then
                    activeRegion = entry.region; activeTabZone = entry.mainLocation; break
                end
            end

            if not activeRegion then
                local mapInfo = C_Map.GetMapInfo(mapID)
                local mapName = mapInfo and mapInfo.name or ""
                local function IsSameName(n1, n2)
                    if not n1 or not n2 then return false end
                    return strtrim(tostring(n1)):lower() == strtrim(tostring(n2)):lower()
                end

                for _, entry in ipairs(Session_NPC_List) do
                    local r = entry.region or "Unknown Region"
                    local c = GetContinent(r)
                    if IsSameName(r, mapName) or IsSameName(c, mapName) then
                        activeRegion = r; activeTabZone = nil; break
                    end
                end
            end
        end
    end

    RefreshLogDisplay()

    if f:IsShown() and not mapID then
        f:Hide()
    else
        if isCollapsed then CollapseWindow(false) end; f:Show()
    end
end

SLASH_T2_TRACK1 = "/t2"
SlashCmdList["T2_TRACK"] = function(msg)
    msg = msg and strtrim(msg) or ""
    if msg ~= "" then
        ProcessScanOrNote(msg); if isCollapsed then CollapseWindow(false) end; if not f:IsShown() then f:Show() end
    else
        _G.func_ToggleT2Window()
    end
end

local toggleBtn = CreateFrame("Button", "T2_TrackNPC_KeybindButton", UIParent, "SecureActionButtonTemplate")
toggleBtn:SetAttribute("type", "macro")
toggleBtn:SetAttribute("macrotext", "/t2")
toggleBtn:SetScript("OnClick", function() _G.func_ToggleT2Window() end)

local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    SetBindingClick("CTRL-NUMPAD2", "T2_TrackNPC_KeybindButton")
    SaveBindings(GetCurrentBindingSet())
end)

-- ==========================================
-- Global API for External Addons (e.g., T1)
-- ==========================================
_G.func_T2_GetNpcInfos = function(mapID)
    local results = {}
    
    -- Ensure the requested mapID is a strict number for comparison
    local targetMapID = tonumber(mapID)
    if not targetMapID then 
        return results 
    end

    -- Iterate through the active session list
    if type(Session_NPC_List) == "table" then
        for _, entry in ipairs(Session_NPC_List) do
            if tonumber(entry.mapID) == targetMapID then
                table.insert(results, {
                    id = entry.id or "",
                    name = entry.name or "Unknown",
                    description = entry.description or "",
                    comment = entry.comment or "",
                    x = tonumber(entry.x),
                    y = tonumber(entry.y)
                })
            end
        end
    end
    
    return results
end