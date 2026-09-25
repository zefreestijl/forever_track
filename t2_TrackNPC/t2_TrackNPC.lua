-- t2_TrackNPC.lua --
local addonName = ...

local f = CreateFrame("Frame", "T2_TrackNPCPanel", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(500, 480)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")

f:SetResizable(true)
if f.SetResizeBounds then
    f:SetResizeBounds(500, 250, 500, 1200)
else
    f:SetMinResize(500, 250)
    f:SetMaxResize(500, 1200)
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
f.title:SetText("t2_TrackNPC Manager")

-- State Variables
local activeRegion = nil     -- LEVEL 1: e.g. "Eastern Kingdoms <Alliance>"
local activeTabZone = nil    -- LEVEL 2: e.g. "Elwynn Forest"
local isCollapsed = false
local selectedItemIndex = nil
local collapsedGroups = {}

local RefreshLogDisplay
local inputBox, inputLabel, CollapseWindow

-- ==========================================
-- Utility: Extract Base Group from Region String
-- ==========================================
local function GetContinent(regionName)
    if not regionName then return "Unknown Region" end
    local c = string.match(regionName, "^(.-)%s*<.*>$")
    if c then return strtrim(c) end
    return strtrim(regionName)
end

-- ==========================================
-- Export Window UI
-- ==========================================
local exportFrame = CreateFrame("Frame", "T2_ExportFrame", f, "BasicFrameTemplateWithInset")
exportFrame:SetSize(400, 350)
exportFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
exportFrame:Hide()
exportFrame:SetFrameStrata("DIALOG")

exportFrame.title = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
exportFrame.title:SetPoint("TOP", exportFrame, "TOP", 0, -6)
exportFrame.title:SetText("Press Ctrl+C to Copy DB")

local exportScroll = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
exportScroll:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", 12, -30)
exportScroll:SetPoint("BOTTOMRIGHT", exportFrame, "BOTTOMRIGHT", -32, 12)

local exportEditBox = CreateFrame("EditBox", nil, exportScroll)
exportEditBox:SetMultiLine(true)
exportEditBox:SetFontObject("ChatFontNormal")
exportEditBox:SetWidth(340)
exportEditBox:SetAutoFocus(true)
exportScroll:SetScrollChild(exportEditBox)

exportEditBox:SetScript("OnEscapePressed", function(self)
    exportFrame:Hide()
end)

local function ShowExportData()
    if type(T2_NPC_DATA) ~= "table" or type(T2_NPC_DATA.entries) ~= "table" then return end

    local groupedData = {}
    for _, entry in ipairs(T2_NPC_DATA.entries) do
        local mID = entry.mapID or 0
        local zName = entry.mainLocation or "Unknown Zone"
        local rName = entry.region or "Unknown Region"
        local groupKey = tostring(mID) .. "_" .. zName .. "_" .. rName
        
        if not groupedData[groupKey] then 
            groupedData[groupKey] = { mapID = mID, zoneName = zName, region = rName, items = {} } 
        end
        table.insert(groupedData[groupKey].items, entry)
    end

    local str = ""
    for _, group in pairs(groupedData) do
        if (not activeRegion or group.region == activeRegion) and (not activeTabZone or group.zoneName == activeTabZone) then
            local safeZoneName = string.gsub(group.zoneName, "%s+", "_")
            safeZoneName = string.upper(safeZoneName)
            
            str = str .. "DB_" .. safeZoneName .. "_GENERAL = {\n"
            str = str .. string.format('  ["mapID"] = %s,\n', group.mapID)
            str = str .. string.format('  ["zoneName"] = "%s",\n', group.zoneName)
            str = str .. string.format('  ["region"] = "%s",\n', group.region)
            str = str .. "  [\"entries\"] = {\n"
            
            for _, entry in ipairs(group.items) do
                str = str .. "    {\n"
                
                if entry.category and entry.category ~= "general" and entry.category ~= "" then
                    str = str .. string.format('      ["category"] = "%s",\n', entry.category)
                end
                
                str = str .. string.format('      ["name"] = "%s",\n', entry.name or "Unknown")
                
                if entry.id and entry.id ~= "" then
                    str = str .. string.format('      ["id"] = "%s",\n', entry.id)
                end
                if entry.description and entry.description ~= "" then
                    str = str .. string.format('      ["description"] = "%s",\n', entry.description)
                end
                if entry.comment and entry.comment ~= "" then
                    str = str .. string.format('      ["comment"] = "%s",\n', entry.comment)
                end
                
                if entry.subLocation and entry.subLocation ~= group.zoneName and entry.subLocation ~= "" then
                    str = str .. string.format('      ["subLocation"] = "%s",\n', entry.subLocation)
                end
                
                local xStr = entry.x and tostring(entry.x) or "0.0"
                local yStr = entry.y and tostring(entry.y) or "0.0"
                
                str = str .. string.format('      ["x"] = %s,\n', xStr)
                str = str .. string.format('      ["y"] = %s,\n', yStr)
                str = str .. "    },\n"
            end
            str = str .. "  }\n}\n\n"
        end
    end

    exportEditBox:SetText(str)
    exportEditBox:HighlightText()
    exportFrame:Show()
end

-- ==========================================
-- Core Functions
-- ==========================================
local resizeHandle

CollapseWindow = function(collapse)
    local point, relativeTo, relativePoint, xOfs, yOfs = f:GetPoint(1)
    if not collapse then
        local targetHeight = (T2_NPC_DATA and T2_NPC_DATA.windowHeight) or 480
        f:SetSize(500, targetHeight)
        if f.Bg then f.Bg:Show() end
        if f.InsetBg then f.InsetBg:Show() end
        if f.scrollArea then f.scrollArea:Show() end
        if inputBox then inputBox:Show() end
        if inputLabel then inputLabel:Show() end
        if f.scanBtn then f.scanBtn:Show() end
        if f.clearBtn then f.clearBtn:Show() end
        if f.expandAllBtn then f.expandAllBtn:Show() end
        if f.collapseAllBtn then f.collapseAllBtn:Show() end
        if f.exportBtn then f.exportBtn:Show() end
        if f.importBtn then f.importBtn:Show() end
        if f.tabContainer then f.tabContainer:Show() end
        if resizeHandle then resizeHandle:Show() end
        f.collapseBtn:SetText("_")
        isCollapsed = false
    else
        if f.Bg then f.Bg:Hide() end
        if f.InsetBg then f.InsetBg:Hide() end
        if f.scrollArea then f.scrollArea:Hide() end
        if inputBox then inputBox:Hide() end
        if inputLabel then inputLabel:Hide() end
        if f.scanBtn then f.scanBtn:Hide() end
        if f.clearBtn then f.clearBtn:Hide() end
        if f.expandAllBtn then f.expandAllBtn:Hide() end
        if f.collapseAllBtn then f.collapseAllBtn:Hide() end
        if f.exportBtn then f.exportBtn:Hide() end
        if f.importBtn then f.importBtn:Hide() end
        if f.tabContainer then f.tabContainer:Hide() end
        if resizeHandle then resizeHandle:Hide() end
        f:SetSize(500, 32)
        f.collapseBtn:SetText("+")
        isCollapsed = true
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
resizeHandle:SetScript("OnMouseDown", function()
    f:StartSizing("BOTTOM")
end)
resizeHandle:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    if type(T2_NPC_DATA) == "table" then
        T2_NPC_DATA.windowHeight = f:GetHeight()
    end
end)

local scrollArea = CreateFrame("ScrollFrame", "T2_TrackNPCScrollFrame", f, "UIPanelScrollFrameTemplate")
scrollArea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 75)
f.scrollArea = scrollArea

local content = CreateFrame("Frame", nil, scrollArea)
content:SetSize(430, 1)
scrollArea:SetScrollChild(content)
content.rows = {}

local tabContainer = CreateFrame("Frame", nil, f)
tabContainer:SetSize(470, 28) 
tabContainer:Show()
f.tabContainer = tabContainer
tabContainer.tabs = {}
tabContainer.labels = {}

-- ==========================================
-- Safe Import Function 
-- ==========================================
local function ImportFromStaticDB()
    if type(T2_NPC_DATA) ~= "table" then T2_NPC_DATA = {} end
    T2_NPC_DATA.entries = {}
    
    local foundAny = false
    local ignoredCount = 0
    
    for globalName, globalData in pairs(_G) do
        if type(globalName) == "string" and string.sub(globalName, 1, 3) == "DB_" 
           and type(globalData) == "table" and type(globalData.entries) == "table" then
            
            local fileMapID = globalData.mapID
            local mapInfo = nil
            
            if type(fileMapID) == "number" then
                mapInfo = C_Map.GetMapInfo(fileMapID)
            end
            
            if fileMapID and not mapInfo then
                ignoredCount = ignoredCount + 1
            else
                foundAny = true
                local fileZoneName = globalData.zoneName
                local fileRegion = globalData.region or "Unknown Region"
                
                if not fileZoneName or fileZoneName == "" then
                    fileZoneName = mapInfo and mapInfo.name or "Unknown Zone"
                end
                
                for i, entry in ipairs(globalData.entries) do
                    local entryMapID = entry.mapID or fileMapID
                    local entryMapInfo = nil
                    if type(entryMapID) == "number" then
                        entryMapInfo = C_Map.GetMapInfo(entryMapID)
                    end
                    
                    if entryMapID and not entryMapInfo then
                        -- Silently ignore
                    else
                        local newEntry = {}
                        for k, v in pairs(entry) do
                            newEntry[k] = v
                        end
                        
                        newEntry.mapID = entryMapID
                        newEntry.mainLocation = fileZoneName
                        newEntry.subLocation = entry.subLocation or fileZoneName
                        newEntry.region = entry.region or fileRegion
                        
                        table.insert(T2_NPC_DATA.entries, newEntry)
                    end
                end
            end
        end
    end

    if foundAny then
        activeRegion = nil
        activeTabZone = nil
        selectedItemIndex = nil
        RefreshLogDisplay()
        
        local msg = "|cFF00FF00Databases successfully imported from db_map files!|r"
        if ignoredCount > 0 then
            msg = msg .. string.format(" |cFFFFFF00(%d unsupported zone files ignored)|r", ignoredCount)
        end
        print(msg)
    elseif ignoredCount > 0 then
        print("|cFFFF0000t2_TrackNPC: No valid databases loaded. (Ignored unsupported zones).|r")
    else
        print("|cFFFF0000Error: Could not find any global tables starting with DB_. Make sure they are listed in your .toc file.|r")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        if type(T2_NPC_DATA) ~= "table" then T2_NPC_DATA = {} end
        if type(T2_NPC_DATA.entries) ~= "table" then T2_NPC_DATA.entries = {} end

        if #T2_NPC_DATA.entries == 0 then
            print("Detected empty log. Auto-restoring from db_map files...")
            ImportFromStaticDB()
        end

        if type(T2_NPC_DATA.windowPos) == "table" then
            local pos = T2_NPC_DATA.windowPos
            f:ClearAllPoints()
            f:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
        end

        if T2_NPC_DATA.windowHeight then
            f:SetHeight(T2_NPC_DATA.windowHeight)
        end

        RefreshLogDisplay()
        print("|cFF00FF00t2_TrackNPC Loaded! Database Entries: " .. #T2_NPC_DATA.entries .. "|r")
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

local RefreshTabs

RefreshLogDisplay = function()
    if type(T2_NPC_DATA) ~= "table" or type(T2_NPC_DATA.entries) ~= "table" then return end

    for _, row in ipairs(content.rows) do
        row:Hide()
        row:SetParent(nil)
    end
    content.rows = {}
    RefreshTabs()

    if #T2_NPC_DATA.entries == 0 then
        local emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
        emptyLabel:SetText("(Log is currently empty. Hover/Target an NPC and scan!)")
        table.insert(content.rows, emptyLabel)
        content:SetSize(430, 40)
        return
    end

    if not activeRegion then
        local emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
        emptyLabel:SetText("Please select a Region from the index above.")
        table.insert(content.rows, emptyLabel)
        content:SetSize(430, 40)
        return
    end

    if not activeTabZone then
        local emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
        emptyLabel:SetText("Please select a Zone from the tabs above.")
        table.insert(content.rows, emptyLabel)
        content:SetSize(430, 40)
        return
    end

    local filteredEntries = {}
    for index, item in ipairs(T2_NPC_DATA.entries) do
        if item.region == activeRegion and item.mainLocation == activeTabZone then
            item.originalIndex = index
            table.insert(filteredEntries, item)
        end
    end

    if #filteredEntries == 0 then
        local emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
        emptyLabel:SetText("(No entries found for this zone.)")
        table.insert(content.rows, emptyLabel)
        content:SetSize(430, 40)
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
        headerBtn:SetSize(430, 20)
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
                row:SetSize(430, rowHeight)
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
                if item.description and item.description ~= "" then
                    displayString = displayString .. " <" .. item.description .. ">"
                end
                
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
                    RefreshLogDisplay()

                    if type(item.mapID) == "number" and item.x and item.y then
                        local mapInfo = C_Map.GetMapInfo(item.mapID)
                        if mapInfo then
                            local mapPoint = UiMapPoint.CreateFromCoordinates(item.mapID, item.x, item.y)
                            C_Map.SetUserWaypoint(mapPoint)
                            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                            C_Map.OpenWorldMap(item.mapID)
                            print(string.format("Waypoint set and tracked for %s.", item.name))
                        else
                            print(string.format("|cFFFF0000Error: Invalid Map ID '%s' for %s. Cannot open map.|r", item.mapID, item.name))
                        end
                    else
                        print(string.format("|cFFFF0000Error: Map Pin failed. 'mapID' is missing for %s!|r", item.name))
                    end
                end)

                local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                delBtn:SetSize(50, 20)
                delBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                delBtn:SetText("Delete")
                delBtn:SetScript("OnClick", function()
                    if selectedItemIndex == item.originalIndex then
                        selectedItemIndex = nil
                        if inputLabel then inputLabel:SetText("Type comment and press Enter (or click Scan):") end
                        if inputBox then inputBox:SetText("") end
                    end
                    table.remove(T2_NPC_DATA.entries, item.originalIndex)
                    RefreshLogDisplay()
                    print("Removed entry from log.")
                end)

                yOffset = yOffset - (rowHeight + 4)
                table.insert(content.rows, row)
            end
        end
        yOffset = yOffset - 8
    end
    content:SetSize(430, math.abs(yOffset) + 10)
end

RefreshTabs = function()
    for _, tab in ipairs(tabContainer.tabs) do
        tab:Hide()
        tab:SetParent(nil)
    end
    tabContainer.tabs = {}
    
    for _, label in ipairs(tabContainer.labels) do
        label:Hide()
        label:SetParent(nil)
    end
    tabContainer.labels = {}

    if type(T2_NPC_DATA) ~= "table" or type(T2_NPC_DATA.entries) ~= "table" then return end

    local maxTabWidth = 450 
    local tabHeight = 24
    local spacingY = 28 
    local spacingX = 4
    local xOffset = 12
    local yOffset = -12 

    if not activeRegion then
        -- LEVEL 1: Vertical Index Menu
        local continents = {}
        for _, item in ipairs(T2_NPC_DATA.entries) do
            local r = item.region or "Unknown Region"
            local c = GetContinent(r)
            if not continents[c] then continents[c] = {} end
            
            local found = false
            for _, v in ipairs(continents[c]) do
                if v == r then found = true; break end
            end
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
                    activeRegion = rName
                    activeTabZone = nil
                    RefreshLogDisplay()
                end)
                
                table.insert(tabContainer.tabs, tabBtn)
                yOffset = yOffset - spacingY
            end
            
            if i < #contNames then
                yOffset = yOffset - (spacingY * 1.5)
            end
        end
    else
        -- LEVEL 2: Horizontal Wrap
        xOffset = 12
        yOffset = -4
        
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
            activeRegion = nil
            activeTabZone = nil
            RefreshLogDisplay()
        end)
        table.insert(tabContainer.tabs, upBtn)
        xOffset = xOffset + upBtn:GetWidth() + spacingX

        local zones = {}
        local zoneNames = {}
        for _, item in ipairs(T2_NPC_DATA.entries) do
            if (item.region or "Unknown Region") == activeRegion then
                local z = item.mainLocation or "Unknown Zone"
                if not zones[z] then
                    zones[z] = true
                    table.insert(zoneNames, z)
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
                xOffset = 12
                yOffset = yOffset - spacingY
            end
            
            tabBtn:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", xOffset, yOffset)

            if activeTabZone == zName then tabBtn:Disable() end
            tabBtn:SetScript("OnClick", function()
                activeTabZone = zName
                RefreshLogDisplay()
            end)
            
            xOffset = xOffset + tabBtn:GetWidth() + spacingX
            table.insert(tabContainer.tabs, tabBtn)
        end
    end
    
    tabContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -32)
    local totalTabContainerHeight = math.abs(yOffset) + (activeRegion and tabHeight or 0) + 8
    tabContainer:SetSize(470, totalTabContainerHeight)
    
    local scrollAreaTopAnchor = -32 - totalTabContainerHeight - 8
    scrollArea:SetPoint("TOPLEFT", f, "TOPLEFT", 12, scrollAreaTopAnchor)
end

local function ProcessScanOrNote(customNote)
    if type(T2_NPC_DATA) ~= "table" then T2_NPC_DATA = {} end
    if type(T2_NPC_DATA.entries) ~= "table" then T2_NPC_DATA.entries = {} end

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
            local _, _, _, _, _, npcID = strsplit("-", guid)
            targetID = npcID or ""
        end
    end

    if not targetName and selectedItemIndex then
        local itemToUpdate = T2_NPC_DATA.entries[selectedItemIndex]
        if itemToUpdate then
            itemToUpdate.comment = customNote or ""
            print(string.format("Updated comment for %s.", itemToUpdate.name))
        end
        selectedItemIndex = nil
        if inputLabel then inputLabel:SetText("Type comment and press Enter (or click Scan):") end
        RefreshLogDisplay()
        return
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
        for _, item in ipairs(T2_NPC_DATA.entries) do
            if item.mapID == mapID and item.region and item.region ~= "Unknown Region" then
                resolvedRegion = item.region
                break
            end
        end
    end

    if targetName then
        local existingIndex = nil
        for i, item in ipairs(T2_NPC_DATA.entries) do
            if item.name == targetName then
                existingIndex = i
                break
            end
        end

        if existingIndex then
            if customNote and customNote ~= "" then
                T2_NPC_DATA.entries[existingIndex].comment = customNote
            end
            T2_NPC_DATA.entries[existingIndex].id = targetID
            T2_NPC_DATA.entries[existingIndex].mainLocation = mainLocation
            T2_NPC_DATA.entries[existingIndex].subLocation = subLocation
            T2_NPC_DATA.entries[existingIndex].region = resolvedRegion
            T2_NPC_DATA.entries[existingIndex].mapID = mapID
            T2_NPC_DATA.entries[existingIndex].x = posX
            T2_NPC_DATA.entries[existingIndex].y = posY
            print(string.format("Updated %s under [%s > %s > %s].", targetName, resolvedRegion, mainLocation, subLocation))
        else
            table.insert(T2_NPC_DATA.entries, {
                category = "general",
                name = targetName,
                id = targetID,
                description = "",
                comment = customNote or "",
                mainLocation = mainLocation,
                subLocation = subLocation,
                region = resolvedRegion,
                mapID = mapID,
                x = posX,
                y = posY
            })
            print(string.format("Added %s under [%s > %s > %s].", targetName, resolvedRegion, mainLocation, subLocation))
        end
    else
        if customNote and customNote ~= "" then
            table.insert(T2_NPC_DATA.entries, {
                category = "general",
                name = "[Note Only]",
                id = "",
                description = "",
                comment = customNote,
                mainLocation = mainLocation,
                subLocation = subLocation,
                region = resolvedRegion,
                mapID = mapID,
                x = posX,
                y = posY
            })
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
inputBox:SetScript("OnEnterPressed", function(self)
    ProcessScanOrNote(self:GetText())
    self:SetText("")
    self:ClearFocus()
end)

inputLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
inputLabel:SetPoint("BOTTOMLEFT", inputBox, "TOPLEFT", 4, 2)
inputLabel:SetText("Type comment and press Enter (or click Scan):")

-- ==========================================
-- Main Bottom Row Buttons
-- ==========================================
local scanBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
scanBtn:SetSize(90, 24)
scanBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
scanBtn:SetText("Scan/Update")
scanBtn:SetScript("OnClick", function()
    ProcessScanOrNote(inputBox:GetText())
    inputBox:SetText("")
    inputBox:ClearFocus()
end)
f.scanBtn = scanBtn

local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
clearBtn:SetSize(65, 24)
clearBtn:SetPoint("LEFT", scanBtn, "RIGHT", 4, 0)
clearBtn:SetText("Clear Pin")
clearBtn:SetScript("OnClick", function()
    C_Map.ClearUserWaypoint()
    print("Map pin cleared.")
end)
f.clearBtn = clearBtn

local expandAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
expandAllBtn:SetSize(75, 24)
expandAllBtn:SetPoint("LEFT", clearBtn, "RIGHT", 4, 0)
expandAllBtn:SetText("Expand All")
expandAllBtn:SetScript("OnClick", function()
    if type(T2_NPC_DATA) == "table" and type(T2_NPC_DATA.entries) == "table" then
        for _, item in ipairs(T2_NPC_DATA.entries) do
            local subZone = item.subLocation or "General Area"
            collapsedGroups[subZone] = false
        end
        RefreshLogDisplay()
    end
end)
f.expandAllBtn = expandAllBtn

local collapseAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseAllBtn:SetSize(80, 24)
collapseAllBtn:SetPoint("LEFT", expandAllBtn, "RIGHT", 4, 0)
collapseAllBtn:SetText("Collapse All")
collapseAllBtn:SetScript("OnClick", function()
    if type(T2_NPC_DATA) == "table" and type(T2_NPC_DATA.entries) == "table" then
        for _, item in ipairs(T2_NPC_DATA.entries) do
            local subZone = item.subLocation or "General Area"
            collapsedGroups[subZone] = true
        end
        RefreshLogDisplay()
    end
end)
f.collapseAllBtn = collapseAllBtn

local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
exportBtn:SetSize(60, 24)
exportBtn:SetPoint("LEFT", collapseAllBtn, "RIGHT", 4, 0)
exportBtn:SetText("Export")
exportBtn:SetScript("OnClick", ShowExportData)
f.exportBtn = exportBtn

local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
importBtn:SetSize(60, 24)
importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 4, 0)
importBtn:SetText("Import")
importBtn:SetScript("OnClick", function()
    ImportFromStaticDB()
end)
f.importBtn = importBtn

tinsert(UISpecialFrames, f:GetName())
f:Hide()

-- ==========================================
-- GLOBAL EXPOSED TOGGLE API
-- ==========================================
_G.func_ToggleT2Window = function(mapID)
    activeRegion = nil
    activeTabZone = nil

    if type(mapID) == "number" then
        local mapInfo = C_Map.GetMapInfo(mapID)
        local mapName = mapInfo and mapInfo.name
        local foundZone = false

        if type(T2_NPC_DATA) == "table" and type(T2_NPC_DATA.entries) == "table" then
            -- 1. Try to find a direct mapID match (Zone Level)
            for _, entry in ipairs(T2_NPC_DATA.entries) do
                if entry.mapID == mapID then
                    activeRegion = entry.region
                    activeTabZone = entry.mainLocation
                    foundZone = true
                    break
                end
            end
            
            -- 2. If no direct match, check if it matches a Region/Continent name (Region Level)
            if not foundZone and mapName then
                for _, entry in ipairs(T2_NPC_DATA.entries) do
                    local r = entry.region or "Unknown Region"
                    local c = GetContinent(r)
                    if r == mapName or c == mapName then
                        activeRegion = r
                        activeTabZone = nil
                        break
                    end
                end
            end
        end
    end

    RefreshLogDisplay()

    if f:IsShown() and not mapID then
        f:Hide()
    else
        if isCollapsed then CollapseWindow(false) end
        f:Show()
    end
end

SLASH_T2_TRACK1 = "/t2"
SlashCmdList["T2_TRACK"] = function(msg)
    msg = msg and strtrim(msg) or ""
    if msg ~= "" then
        ProcessScanOrNote(msg)
        if isCollapsed then CollapseWindow(false) end
        if not f:IsShown() then f:Show() end
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