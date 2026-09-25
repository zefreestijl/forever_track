-- =========================================================================
-- 1. Main Frame Setup
-- =========================================================================
local f = CreateFrame("Frame", "t3_TrackQst", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(270, 500)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f, "TOP", 0, -6)
f.title:SetText("t3_TrackQst - Rewards & Choices")

local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
collapseBtn:SetText("_")
local isCollapsed = false

-- =========================================================================
-- 2. Bottom Action Buttons (Expand/Collapse/Untrack All)
-- =========================================================================
local btnExpandAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
btnExpandAll:SetSize(90, 22)
btnExpandAll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 5, 8)
btnExpandAll:SetText("Expand All")

local btnCollapseAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
btnCollapseAll:SetSize(90, 22)
btnCollapseAll:SetPoint("LEFT", btnExpandAll, "RIGHT", 2, 0)
btnCollapseAll:SetText("Collapse All")

local btnUntrackAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
btnUntrackAll:SetSize(90, 22)
btnUntrackAll:SetPoint("LEFT", btnCollapseAll, "RIGHT", 2, 0)
btnUntrackAll:SetText("Untrack All")

-- =========================================================================
-- 3. ScrollFrame Setup & Custom Scrolling
-- =========================================================================
local scrollFrame = CreateFrame("ScrollFrame", "T3_QuestScrollFrame", f, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -50)
scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 35)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(scrollFrame:GetWidth(), 1)
scrollFrame:SetScrollChild(content)

-- Custom 3-Item Mouse Wheel Scrolling Override
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
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

local tabButtons = {}

collapseBtn:SetScript("OnClick", function()
    if isCollapsed then
        f:SetHeight(500)
        if f.Bg then f.Bg:Show() end
        if f.InsetBg then f.InsetBg:Show() end
        scrollFrame:Show()
        btnExpandAll:Show()
        btnCollapseAll:Show()
        btnUntrackAll:Show()
        collapseBtn:SetText("_")
        isCollapsed = false
        if _G.UpdateQuestList then _G.UpdateQuestList() end
    else
        f:SetHeight(32)
        if f.Bg then f.Bg:Hide() end
        if f.InsetBg then f.InsetBg:Hide() end
        scrollFrame:Hide()
        btnExpandAll:Hide()
        btnCollapseAll:Hide()
        btnUntrackAll:Hide()
        for _, tab in ipairs(tabButtons) do tab:Hide() end
        collapseBtn:SetText("+")
        isCollapsed = true
    end
end)

-- =========================================================================
-- 4. Dynamic Tabs Logic
-- =========================================================================
local activeFilter = "All"

local function GetOrCreateTab(index)
    local tab = tabButtons[index]
    if not tab then
        tab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        tab:SetHeight(22)
        tab.text = tab:GetFontString()
        table.insert(tabButtons, tab)
    end
    return tab
end

-- =========================================================================
-- 5. Accordion Logic & Data Population
-- =========================================================================
local questLines = {}
local expandedQuests = {} 

btnExpandAll:SetScript("OnClick", function()
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local q = C_QuestLog.GetInfo(i)
        if q and not q.isHidden and not q.isHeader then
            expandedQuests[q.questID] = true
        end
    end
    if _G.UpdateQuestList then _G.UpdateQuestList() end
end)

btnCollapseAll:SetScript("OnClick", function()
    wipe(expandedQuests)
    if _G.UpdateQuestList then _G.UpdateQuestList() end
end)

btnUntrackAll:SetScript("OnClick", function()
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local questInfo = C_QuestLog.GetInfo(i)
        if questInfo and not questInfo.isHidden and not questInfo.isHeader then
            local isCurrentlyTracked = false
            if type(C_QuestLog.GetQuestWatchType) == "function" then
                isCurrentlyTracked = (C_QuestLog.GetQuestWatchType(questInfo.questID) ~= nil)
            elseif type(IsQuestWatched) == "function" then
                isCurrentlyTracked = IsQuestWatched(i)
            end
            
            if isCurrentlyTracked then
                if type(C_QuestLog.RemoveQuestWatch) == "function" then
                    C_QuestLog.RemoveQuestWatch(questInfo.questID)
                elseif type(RemoveQuestWatch) == "function" then
                    RemoveQuestWatch(i)
                end
            end
        end
    end
    if _G.UpdateQuestList then _G.UpdateQuestList() end
end)

local function GetOrCreateLine(index)
    local btn = questLines[index]
    if not btn then
        btn = CreateFrame("Button", nil, content)
        btn.text = btn:CreateFontString(nil, "OVERLAY")
        btn.text:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        btn.text:SetJustifyH("LEFT")
        btn.text:SetWordWrap(true)
        
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.5, 0.5, 0.5, 0.25)
        btn.bg:Hide()
        
        table.insert(questLines, btn)
    end
    
    btn.bg:Hide()
    btn.bg:SetColorTexture(0.5, 0.5, 0.5, 0.25)
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    btn:SetScript("OnClick", nil)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    return btn
end

local function GetItemLinkSafe(typeStr, index, questID)
    if type(GetQuestLogItemLink) == "function" then
        local s, l = pcall(GetQuestLogItemLink, typeStr, index, questID)
        if s and l then return l end
        s, l = pcall(GetQuestLogItemLink, typeStr, index)
        if s and l then return l end
    end
    return nil
end

local function GetMoneyStringPlain(money)
    if not money or money <= 0 then return "" end
    local g = math.floor(money / 10000)
    local s = math.floor((money % 10000) / 100)
    local c = money % 100
    local str = ""
    if g > 0 then str = str .. g .. "g " end
    if s > 0 then str = str .. s .. "s " end
    if c > 0 then str = str .. c .. "c" end
    return str
end

local function GetDifficultyColorHex(questLevel)
    if not questLevel or questLevel <= 0 then return "|cFFFFFF00" end
    
    local playerLevel = UnitLevel("player") or 1
    local diff = questLevel - playerLevel
    
    if diff >= 5 then 
        return "|cFFFF1A1A" -- Red
    elseif diff >= 3 then 
        return "|cFFFF8040" -- Orange
    elseif diff >= -2 then 
        return "|cFFFFFF00" -- Yellow
    else
        local grayLevel = 0
        if playerLevel <= 5 then 
            grayLevel = 0
        elseif playerLevel <= 39 then 
            grayLevel = playerLevel - 5 - math.floor(playerLevel / 10)
        elseif playerLevel <= 59 then 
            grayLevel = playerLevel - 1 - math.floor(playerLevel / 5)
        else 
            grayLevel = playerLevel - 9 
        end
        
        if questLevel <= grayLevel then
            return "|cFF808080" -- Gray
        else
            return "|cFF40C040" -- Green
        end
    end
end

function _G.UpdateQuestList()
    if not f:IsShown() or isCollapsed then return end

    for _, line in ipairs(questLines) do line:Hide() end
    for _, tab in ipairs(tabButtons) do tab:Hide() end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    local filters = { ["All"] = true, ["Tracked"] = true, ["Untracked"] = true }
    
    for i = 1, numEntries do
        local q = C_QuestLog.GetInfo(i)
        if q and not q.isHidden and q.isHeader then filters[q.title] = true end
    end

    local sortedFilters = {}
    for k in pairs(filters) do table.insert(sortedFilters, k) end
    table.sort(sortedFilters, function(a, b)
        local order = { ["All"] = 1, ["Tracked"] = 2, ["Untracked"] = 3 }
        if order[a] and order[b] then return order[a] < order[b] end
        if order[a] then return true end
        if order[b] then return false end
        return a < b
    end)

    local tabX, tabY = 10, -28
    for i, filterName in ipairs(sortedFilters) do
        local tab = GetOrCreateTab(i)
        tab:SetText(filterName)
        local tabWidth = tab.text:GetStringWidth() + 20
        tab:SetWidth(tabWidth)
        
        if tabX + tabWidth > f:GetWidth() - 20 then
            tabX = 10
            tabY = tabY - 24
        end
        
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", tabX, tabY)
        tabX = tabX + tabWidth + 4
        
        local isSelected = (activeFilter == filterName)
        if isSelected then 
            tab:LockHighlight() 
            tab.text:SetTextColor(1, 0.82, 0)
        else 
            tab:UnlockHighlight() 
            tab.text:SetTextColor(0.5, 0.5, 0.5)
        end
        
        for _, region in ipairs({tab:GetRegions()}) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                if isSelected then
                    region:SetVertexColor(1, 1, 1)
                else
                    region:SetVertexColor(0.4, 0.4, 0.4)
                end
            end
        end
        
        tab:SetScript("OnClick", function() activeFilter = filterName; _G.UpdateQuestList() end)
        tab:Show()
    end
    
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, tabY - 26)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 35)

    local yOffset = -5
    local lineIndex = 1

    local function FlushText(textStr, indent)
        if textStr == "" then return end
        local dBtn = GetOrCreateLine(lineIndex)
        dBtn:ClearAllPoints()
        dBtn:SetPoint("TOPLEFT", content, "TOPLEFT", indent or 35, yOffset)
        dBtn.text:SetWidth(scrollFrame:GetWidth() - (indent or 35) - 5)
        dBtn.text:SetFontObject("GameFontHighlightSmall")
        dBtn.text:SetText(textStr)
        local h = dBtn.text:GetStringHeight()
        dBtn:SetSize(scrollFrame:GetWidth() - (indent or 35) - 5, h + 4)
        dBtn:Show()
        yOffset = yOffset - (h + 8)
        lineIndex = lineIndex + 1
    end

    local function RenderSingleQuest(questInfo, logIndex)
        local qBtn = GetOrCreateLine(lineIndex)
        qBtn:ClearAllPoints()
        qBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
        qBtn.text:SetWidth(scrollFrame:GetWidth() - 25)
        qBtn.text:SetFontObject("GameFontHighlight")
        
        local hexDiff = GetDifficultyColorHex(questInfo.level)

        local expandSymbol = expandedQuests[questInfo.questID] and "[-] " or "[+] "
        local levelText = questInfo.level > 0 and ("[" .. questInfo.level .. "] ") or ""
        local status = questInfo.isComplete and " |cFF00FF00(Ready)|r" or ""
        
        qBtn.text:SetText(hexDiff .. expandSymbol .. levelText .. questInfo.title .. "|r" .. status)
        
        qBtn:SetScript("OnEnter", function(self) self.text:SetAlpha(0.7) end)
        qBtn:SetScript("OnLeave", function(self) self.text:SetAlpha(1.0) end)
        qBtn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                local isCurrentlyTracked = false
                if type(C_QuestLog.GetQuestWatchType) == "function" then
                    isCurrentlyTracked = (C_QuestLog.GetQuestWatchType(questInfo.questID) ~= nil)
                elseif type(IsQuestWatched) == "function" then
                    isCurrentlyTracked = IsQuestWatched(logIndex)
                end
                
                if isCurrentlyTracked then
                    if type(C_QuestLog.RemoveQuestWatch) == "function" then
                        C_QuestLog.RemoveQuestWatch(questInfo.questID)
                    elseif type(RemoveQuestWatch) == "function" then
                        RemoveQuestWatch(logIndex)
                    end
                else
                    if type(C_QuestLog.AddQuestWatch) == "function" then
                        C_QuestLog.AddQuestWatch(questInfo.questID)
                    elseif type(AddQuestWatch) == "function" then
                        AddQuestWatch(logIndex)
                    end
                end
            else
                expandedQuests[questInfo.questID] = not expandedQuests[questInfo.questID]
            end
            _G.UpdateQuestList()
        end)

        local qHeight = qBtn.text:GetStringHeight()
        qBtn:SetSize(scrollFrame:GetWidth() - 25, qHeight + 4)
        qBtn:Show()
        yOffset = yOffset - (qHeight + 6)
        lineIndex = lineIndex + 1

        if expandedQuests[questInfo.questID] then
            C_QuestLog.SetSelectedQuest(questInfo.questID)
            
            -- 1. Story & Money Block
            local textBlock1 = ""
            local description, objectiveText = GetQuestLogQuestText()
            if objectiveText and objectiveText ~= "" then textBlock1 = textBlock1 .. "|cFFFFFF00Preface:|r\n" .. objectiveText .. "\n\n" end
            if description and description ~= "" then textBlock1 = textBlock1 .. "|cFFFFFF00Story:|r\n" .. description .. "\n\n" end
            
            local xp = 0
            if type(GetQuestLogRewardXP) == "function" then
                local s, v = pcall(GetQuestLogRewardXP, questInfo.questID)
                if s and v then xp = v end
            end
            local money = 0
            if type(GetQuestLogRewardMoney) == "function" then
                local s, v = pcall(GetQuestLogRewardMoney, questInfo.questID)
                if s and v then money = v end
            end
            if xp > 0 or money > 0 then
                textBlock1 = textBlock1 .. "|cFFFFFF00Rewards:|r\n"
                if xp > 0 then textBlock1 = textBlock1 .. xp .. " XP\n" end
                if money > 0 then textBlock1 = textBlock1 .. GetMoneyStringPlain(money) .. "\n" end
            end
            FlushText(textBlock1, 35)

            -- 2. Mandatory Item Rewards
            local numRewards = 0
            if type(GetNumQuestLogRewards) == "function" then
                local s, v = pcall(GetNumQuestLogRewards, questInfo.questID)
                if s and v then numRewards = v end
            end
            
            if numRewards > 0 then
                FlushText("|cFFFFFF00Item Rewards:|r", 35)
                for r = 1, numRewards do
                    local s, itemName, _, count = pcall(GetQuestLogRewardInfo, r, questInfo.questID)
                    if not s or not itemName then s, itemName, _, count = pcall(GetQuestLogRewardInfo, r) end
                    if itemName then
                        local link = GetItemLinkSafe("reward", r, questInfo.questID)
                        count = (count and count > 1) and (count.."x ") or ""
                        
                        local iBtn = GetOrCreateLine(lineIndex)
                        iBtn:ClearAllPoints()
                        iBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 45, yOffset)
                        iBtn.text:SetWidth(scrollFrame:GetWidth() - 55)
                        iBtn.text:SetFontObject("GameFontHighlightSmall")
                        iBtn.text:SetText("- " .. count .. (link or itemName))
                        
                        iBtn.bg:Show()
                        iBtn:SetScript("OnEnter", function(self)
                            self.bg:SetColorTexture(0.7, 0.7, 0.7, 0.4)
                            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                            if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetQuestLogItem("reward", r) end
                            GameTooltip:Show()
                        end)
                        iBtn:SetScript("OnLeave", function(self)
                            self.bg:SetColorTexture(0.5, 0.5, 0.5, 0.25)
                            GameTooltip:Hide() 
                        end)
                        
                        local h = iBtn.text:GetStringHeight()
                        iBtn:SetSize(scrollFrame:GetWidth() - 55, h + 4)
                        iBtn:Show()
                        yOffset = yOffset - (h + 6)
                        lineIndex = lineIndex + 1
                    end
                end
                yOffset = yOffset - 4
            end
            
            -- 3. Choice Item Rewards
            local numChoices = 0
            if type(GetNumQuestLogChoices) == "function" then
                local s, v = pcall(GetNumQuestLogChoices, questInfo.questID)
                if s and v then numChoices = v end
            end
            
            if numChoices > 0 then
                FlushText("|cFFFFFF00Choose One:|r", 35)
                for c = 1, numChoices do
                    local s, itemName, _, count = pcall(GetQuestLogChoiceInfo, c, questInfo.questID)
                    if not s or not itemName then s, itemName, _, count = pcall(GetQuestLogChoiceInfo, c) end
                    if itemName then
                        local link = GetItemLinkSafe("choice", c, questInfo.questID)
                        count = (count and count > 1) and (count.."x ") or ""
                        
                        local cBtn = GetOrCreateLine(lineIndex)
                        cBtn:ClearAllPoints()
                        cBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 45, yOffset)
                        cBtn.text:SetWidth(scrollFrame:GetWidth() - 55)
                        cBtn.text:SetFontObject("GameFontHighlightSmall")
                        cBtn.text:SetText("- " .. count .. (link or itemName))
                        
                        cBtn.bg:Show()
                        cBtn:SetScript("OnEnter", function(self)
                            self.bg:SetColorTexture(0.7, 0.7, 0.7, 0.4)
                            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                            if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetQuestLogItem("choice", c) end
                            GameTooltip:Show()
                        end)
                        cBtn:SetScript("OnLeave", function(self)
                            self.bg:SetColorTexture(0.5, 0.5, 0.5, 0.25)
                            GameTooltip:Hide() 
                        end)
                        
                        local h = cBtn.text:GetStringHeight()
                        cBtn:SetSize(scrollFrame:GetWidth() - 55, h + 4)
                        cBtn:Show()
                        yOffset = yOffset - (h + 6)
                        lineIndex = lineIndex + 1
                    end
                end
                yOffset = yOffset - 4
            end

            -- 4. Live Progress Block
            local objectives = C_QuestLog.GetQuestObjectives(questInfo.questID)
            if objectives and #objectives > 0 then
                local objText = "|cFFFFFF00Live Progress:|r\n"
                for _, obj in ipairs(objectives) do
                    local objColor = obj.finished and "|cFF808080" or "|cFFFFFFFF"
                    objText = objText .. objColor .. "• " .. (obj.text or "") .. "|r\n"
                end
                FlushText(objText, 35)
            end

            -- 5. Location Block (Map ID & Coords)
            local questMapID = type(QuestUtils_GetQuestMapID) == "function" and QuestUtils_GetQuestMapID(questInfo.questID) or nil
            
            local mapText = questMapID and tostring(questMapID) or "|cFF808080Unknown|r"
            local locText = "|cFFFFFF00Location:|r\nMap ID: " .. mapText
            local foundCoords = false
            
            if type(C_QuestLog.GetNextWaypoint) == "function" then
                local wp = C_QuestLog.GetNextWaypoint(questInfo.questID)
                if wp and wp.x and wp.y then
                    locText = locText .. string.format("\nWaypoint: %.1f, %.1f", wp.x * 100, wp.y * 100)
                    foundCoords = true
                end
            end
            
            if not foundCoords and type(C_QuestLog.GetQuestPOIs) == "function" and questMapID then
                local pois = C_QuestLog.GetQuestPOIs(questInfo.questID)
                if pois and #pois > 0 then
                    locText = locText .. "\nPOIs:"
                    for _, poi in ipairs(pois) do
                        if type(poi.GetXY) == "function" then
                            local x, y = poi:GetXY()
                            if x and y then
                                locText = locText .. string.format(" [%.1f, %.1f]", x * 100, y * 100)
                                foundCoords = true
                            end
                        end
                    end
                end
            end

            if not foundCoords then
                locText = locText .. "\nCoords: |cFF808080None found in client API.|r"
            end
            
            FlushText(locText .. "\n", 35)
        end
        yOffset = yOffset - 4
    end

    local focusedQuestID = nil
    if C_SuperTrack and type(C_SuperTrack.GetSuperTrackedQuestID) == "function" then
        focusedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
    elseif type(GetSuperTrackedQuestID) == "function" then
        focusedQuestID = GetSuperTrackedQuestID()
    end

    if focusedQuestID then
        local focusedQuestInfo = nil
        local focusedLogIndex = nil
        for i = 1, numEntries do
            local qInfo = C_QuestLog.GetInfo(i)
            if qInfo and not qInfo.isHidden and not qInfo.isHeader and qInfo.questID == focusedQuestID then
                focusedQuestInfo = qInfo
                focusedLogIndex = i
                break
            end
        end
        
        if focusedQuestInfo then
            local hBtn = GetOrCreateLine(lineIndex)
            hBtn:ClearAllPoints()
            hBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 5, yOffset)
            hBtn.text:SetWidth(scrollFrame:GetWidth() - 25)
            hBtn.text:SetFontObject("GameFontNormalLarge")
            hBtn.text:SetText("|cFFFFFFFF★ Focused Quest|r")
            local h = hBtn.text:GetStringHeight()
            hBtn:SetSize(scrollFrame:GetWidth() - 25, h + 4)
            hBtn:Show()
            yOffset = yOffset - (h + 8)
            lineIndex = lineIndex + 1

            RenderSingleQuest(focusedQuestInfo, focusedLogIndex)
        end
    end

    local currentHeaderTitle = nil
    local headerDrawn = false

    for i = 1, numEntries do
        local questInfo = C_QuestLog.GetInfo(i)
        
        if questInfo and not questInfo.isHidden then
            if questInfo.isHeader then
                currentHeaderTitle = questInfo.title
                headerDrawn = false
            else
                if questInfo.questID ~= focusedQuestID then
                    local isTracked = false
                    if type(C_QuestLog.GetQuestWatchType) == "function" then
                        isTracked = (C_QuestLog.GetQuestWatchType(questInfo.questID) ~= nil)
                    elseif type(IsQuestWatched) == "function" then
                        isTracked = IsQuestWatched(i)
                    end
                    
                    local isUntracked = not isTracked

                    if activeFilter == "All" or 
                       (activeFilter == "Tracked" and isTracked) or 
                       (activeFilter == "Untracked" and isUntracked) or 
                       (activeFilter == currentHeaderTitle) then
                        
                        if currentHeaderTitle and not headerDrawn then
                            local hBtn = GetOrCreateLine(lineIndex)
                            hBtn:ClearAllPoints()
                            hBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 5, yOffset)
                            hBtn.text:SetWidth(scrollFrame:GetWidth() - 25)
                            hBtn.text:SetFontObject("GameFontNormalLarge")
                            hBtn.text:SetText("|cFFFFFFFF" .. currentHeaderTitle .. "|r")
                            local h = hBtn.text:GetStringHeight()
                            hBtn:SetSize(scrollFrame:GetWidth() - 25, h + 4)
                            hBtn:Show()
                            
                            yOffset = yOffset - (h + 8)
                            lineIndex = lineIndex + 1
                            headerDrawn = true
                        end

                        RenderSingleQuest(questInfo, i)
                    end
                end
            end
        end
    end

    content:SetHeight(math.abs(yOffset) + 10)
end

-- =========================================================================
-- 6. Events & Keybinds
-- =========================================================================
f:SetScript("OnShow", _G.UpdateQuestList)
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("SUPER_TRACKING_CHANGED")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:SetScript("OnEvent", function(self, event) _G.UpdateQuestList() end)

tinsert(UISpecialFrames, f:GetName())
f:Hide()

local function ToggleT3Window()
    if f:IsShown() then f:Hide() else f:Show() end
end

SLASH_T3_CMD1 = "/t3"
SlashCmdList["T3_CMD"] = ToggleT3Window

local toggleBtn = CreateFrame("Button", "T3_KeybindButton", UIParent, "SecureActionButtonTemplate")
toggleBtn:SetAttribute("type", "macro")
toggleBtn:SetAttribute("macrotext", "/t3")
toggleBtn:SetScript("OnClick", ToggleT3Window)

local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    SetBindingClick("CTRL-NUMPAD3", "T3_KeybindButton")
    SaveBindings(GetCurrentBindingSet())
end)