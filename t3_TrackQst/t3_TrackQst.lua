-- =========================================================================
-- 0. Localization (Auto-detects CHT / zhTW)
-- =========================================================================
local locale = GetLocale()
local L = {
    TITLE = "t3_TrackQst",
    TAB_ALL = "All",
    TAB_RECENT = "Recent",
    TAB_READY = "Ready",
    TAB_TRACKED = "Tracked",
    TAB_UNTRACKED = "Untracked",
    BTN_EXPAND = "Expand All",
    BTN_COLLAPSE = "Collapse All",
    BTN_UNTRACK = "Untrack All",
    FOCUSED = "★ Focused Quest",
    PREFACE = "Preface:",
    STORY = "Story:",
    REWARDS = "Rewards:",
    ITEMS = "Item Rewards:",
    CHOOSE = "Choose One:",
    PROGRESS = "Live Progress:",
    LOCATION = "Location:",
    MAP_ID = "Map ID: ",
    WAYPOINT = "Waypoint: ",
    COORDS_NONE = "None found in client API.",
    UNKNOWN = "Unknown",
    READY = "(Ready)"
}

if locale == "zhTW" then
    L.TITLE = "t3_TrackQst"
    L.TAB_ALL = "全部"
    L.TAB_RECENT = "最近更新"
    L.TAB_READY = "可回報"
    L.TAB_TRACKED = "已追蹤"
    L.TAB_UNTRACKED = "未追蹤"
    L.BTN_EXPAND = "全部展開"
    L.BTN_COLLAPSE = "全部收合"
    L.BTN_UNTRACK = "取消追蹤"
    L.FOCUSED = "★ 當前專注任務"
    L.PREFACE = "前言："
    L.STORY = "故事："
    L.REWARDS = "獎勵："
    L.ITEMS = "物品獎勵："
    L.CHOOSE = "選擇一項："
    L.PROGRESS = "當前進度："
    L.LOCATION = "位置："
    L.MAP_ID = "地圖 ID: "
    L.WAYPOINT = "導航點: "
    L.COORDS_NONE = "客戶端 API 無座標資料。"
    L.UNKNOWN = "未知"
    L.READY = "(完成)"
end

-- =========================================================================
-- 1. Main Frame Setup & Resizing (Width set to 250)
-- =========================================================================
local f = CreateFrame("Frame", "t3_TrackQst", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(250, 500)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

f:SetResizable(true)
if f.SetResizeBounds then
    f:SetResizeBounds(250, 200, 250, 1200)
else
    f:SetMinResize(250, 200)
    f:SetMaxResize(250, 1200)
end

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f, "TOP", 0, -6)
f.title:SetText(L.TITLE)

local collapseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
collapseBtn:SetSize(24, 22)
collapseBtn:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
collapseBtn:SetText("_")
local isCollapsed = false
local expandedHeight = 500

local resizeBtn = CreateFrame("Button", nil, f)
resizeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
resizeBtn:SetSize(16, 16)
resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

resizeBtn:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then f:StartSizing("BOTTOM") end
end)
resizeBtn:SetScript("OnMouseUp", function(self, button)
    f:StopMovingOrSizing()
    expandedHeight = f:GetHeight()
end)

local UpdateQuestList

-- =========================================================================
-- 2. Bottom Action Buttons (Resized to 74px to fit 250px total width)
-- =========================================================================
local btnExpandAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
btnExpandAll:SetSize(74, 22)
btnExpandAll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
btnExpandAll:SetText(L.BTN_EXPAND)
btnExpandAll:SetNormalFontObject("GameFontNormalSmall")
btnExpandAll:SetHighlightFontObject("GameFontHighlightSmall")

local btnCollapseAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
btnCollapseAll:SetSize(74, 22)
btnCollapseAll:SetPoint("LEFT", btnExpandAll, "RIGHT", 5, 0)
btnCollapseAll:SetText(L.BTN_COLLAPSE)
btnCollapseAll:SetNormalFontObject("GameFontNormalSmall")
btnCollapseAll:SetHighlightFontObject("GameFontHighlightSmall")

local btnUntrackAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
btnUntrackAll:SetSize(74, 22)
btnUntrackAll:SetPoint("LEFT", btnCollapseAll, "RIGHT", 5, 0)
btnUntrackAll:SetText(L.BTN_UNTRACK)
btnUntrackAll:SetNormalFontObject("GameFontNormalSmall")
btnUntrackAll:SetHighlightFontObject("GameFontHighlightSmall")

local untrackText = btnUntrackAll:GetFontString()
if untrackText then untrackText:SetTextColor(0.5, 0.5, 0.5) end
for _, region in ipairs({ btnUntrackAll:GetRegions() }) do
    if region.IsObjectType and region:IsObjectType("Texture") then
        region:SetVertexColor(0.4, 0.4, 0.4)
    end
end

-- =========================================================================
-- 3. ScrollFrame Setup & Custom Scrolling
-- =========================================================================
local scrollFrame = CreateFrame("ScrollFrame", "T3_QuestScrollFrame", f, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -50)
scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 35)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(210, 1)
scrollFrame:SetScrollChild(content)

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
        f:SetHeight(expandedHeight)
        f:SetResizable(true)
        if f.Bg then f.Bg:Show() end
        if f.InsetBg then f.InsetBg:Show() end
        scrollFrame:Show()
        btnExpandAll:Show()
        btnCollapseAll:Show()
        btnUntrackAll:Show()
        resizeBtn:Show()
        collapseBtn:SetText("_")
        isCollapsed = false
        UpdateQuestList()
    else
        expandedHeight = f:GetHeight()
        f:SetHeight(32)
        f:SetResizable(false)
        if f.Bg then f.Bg:Hide() end
        if f.InsetBg then f.InsetBg:Hide() end
        scrollFrame:Hide()
        btnExpandAll:Hide()
        btnCollapseAll:Hide()
        btnUntrackAll:Hide()
        resizeBtn:Hide()
        for _, tab in ipairs(tabButtons) do tab:Hide() end
        collapseBtn:SetText("+")
        isCollapsed = true
    end
end)

-- =========================================================================
-- 4. Dynamic Tabs Logic & Helpers
-- =========================================================================
local activeFilter = L.TAB_RECENT
local questLines = {}
local expandedQuests = {}

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

btnExpandAll:SetScript("OnClick", function()
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local q = C_QuestLog.GetInfo(i)
        if q and not q.isHidden and not q.isHeader then expandedQuests[q.questID] = true end
    end
    UpdateQuestList()
end)

btnCollapseAll:SetScript("OnClick", function()
    wipe(expandedQuests)
    UpdateQuestList()
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
                    pcall(C_QuestLog.RemoveQuestWatch, questInfo.questID)
                elseif type(RemoveQuestWatch) == "function" then
                    pcall(RemoveQuestWatch, i)
                end
            end
        end
    end
    UpdateQuestList()
end)

local function GetOrCreateLine(index)
    local btn = questLines[index]
    if not btn then
        btn = CreateFrame("Button", nil, content)

        -- Add a tracking checkbox (hidden by default)
        btn.trackBtn = CreateFrame("CheckButton", nil, btn, "UICheckButtonTemplate")
        btn.trackBtn:SetSize(18, 18)
        btn.trackBtn:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -1)
        btn.trackBtn:Hide()

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

    -- Reset state for recycled lines
    btn.bg:Hide()
    btn.bg:SetColorTexture(0.5, 0.5, 0.5, 0.25)
    btn.trackBtn:Hide()
    btn.trackBtn:SetScript("OnClick", nil)
    btn.text:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)

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
        return "|cFFFF1A1A"
    elseif diff >= 3 then
        return "|cFFFF8040"
    elseif diff >= -2 then
        return "|cFFFFFF00"
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
            return "|cFF808080"
        else
            return "|cFF40C040"
        end
    end
end

-- =========================================================================
-- AGGRESSIVE QUEST COMPLETION SCANNER
-- =========================================================================
local function IsQuestReadySafe(questInfo, logIndex)
    if questInfo.isComplete == true or questInfo.isComplete == 1 then return true end
    if type(C_QuestLog.IsComplete) == "function" and C_QuestLog.IsComplete(questInfo.questID) then return true end
    if type(IsQuestComplete) == "function" and IsQuestComplete(questInfo.questID) then return true end

    if type(C_QuestLog.GetQuestObjectives) == "function" then
        local objs = C_QuestLog.GetQuestObjectives(questInfo.questID)
        if objs and #objs > 0 then
            local allDone = true
            for _, obj in ipairs(objs) do
                if not obj.finished then
                    allDone = false
                    break
                end
            end
            if allDone then return true end
        end
    end

    if type(GetNumQuestLeaderBoards) == "function" and type(GetQuestLogLeaderBoard) == "function" then
        local numObjs = GetNumQuestLeaderBoards(logIndex)
        if numObjs and numObjs > 0 then
            local allDone = true
            for objIndex = 1, numObjs do
                local _, _, finished = GetQuestLogLeaderBoard(objIndex, logIndex)
                if not finished then
                    allDone = false
                    break
                end
            end
            if allDone then return true end
        end
    end

    if type(GetQuestLogTitle) == "function" then
        local _, _, _, _, _, t6, t7 = GetQuestLogTitle(logIndex)
        if t6 == 1 or t7 == 1 then return true end
    end

    return false
end

-- =========================================================================
-- STATE CACHING: Auto-Tracker & Recent Updated
-- =========================================================================
local questProgressCache = {}
local recentQuests = {}
local isFirstScan = true


local function GetQuestProgressHash(questID, logIndex)
    local hash = ""
    if type(C_QuestLog.GetQuestObjectives) == "function" then
        local objs = C_QuestLog.GetQuestObjectives(questID)
        if objs then
            for _, obj in ipairs(objs) do
                hash = hash .. tostring(obj.numFulfilled) .. ":" .. tostring(obj.finished) .. "|"
            end
        end
    elseif type(GetNumQuestLeaderBoards) == "function" then
        local numObjs = GetNumQuestLeaderBoards(logIndex)
        if numObjs and numObjs > 0 then
            for objIndex = 1, numObjs do
                local text, _, finished = GetQuestLogLeaderBoard(objIndex, logIndex)
                hash = hash .. tostring(text) .. ":" .. tostring(finished) .. "|"
            end
        end
    end
    return hash
end

local function CheckForQuestUpdates()
    local numEntries = C_QuestLog.GetNumQuestLogEntries()

    for i = 1, numEntries do
        local q = C_QuestLog.GetInfo(i)
        if q and not q.isHidden and not q.isHeader then
            local hash = GetQuestProgressHash(q.questID, i)
            
            -- Condition 1: We already know this quest, and its progress changed
            if questProgressCache[q.questID] and questProgressCache[q.questID] ~= hash then
                recentQuests[q.questID] = GetTime()

                local isTracked = false
                if type(C_QuestLog.GetQuestWatchType) == "function" then
                    isTracked = (C_QuestLog.GetQuestWatchType(q.questID) ~= nil)
                elseif type(IsQuestWatched) == "function" then
                    isTracked = IsQuestWatched(i)
                end

                if not isTracked then
                    if type(C_QuestLog.AddQuestWatch) == "function" then
                        pcall(C_QuestLog.AddQuestWatch, q.questID)
                    elseif type(AddQuestWatch) == "function" then
                        pcall(AddQuestWatch, i)
                    end
                end
                
            -- Condition 2: We have NEVER seen this quest, and it's not the initial login scan
            elseif not questProgressCache[q.questID] and not isFirstScan then
                -- This is a newly accepted quest!
                recentQuests[q.questID] = GetTime()
                
                -- Auto-track newly accepted quests
                if type(C_QuestLog.AddQuestWatch) == "function" then
                    pcall(C_QuestLog.AddQuestWatch, q.questID)
                elseif type(AddQuestWatch) == "function" then
                    pcall(AddQuestWatch, i)
                end
            end
            
            questProgressCache[q.questID] = hash
        end
    end
    
    -- After the first login scan runs, turn off the flag
    isFirstScan = false 
end

-- =========================================================================
-- LIVE TIMER CACHING & HELPERS
-- =========================================================================
local activeTimers = {}

local function GetFormattedTimerString(timeLeft)
    if not timeLeft or timeLeft <= 0 then return "|cFFFF3333⏱ 0s|r" end
    local hours = math.floor(timeLeft / 3600)
    local mins = math.floor((timeLeft % 3600) / 60)
    local secs = math.floor(timeLeft % 60)

    if hours > 0 then
        return string.format("|cFFFF3333⏱ %dh %02dm|r", hours, mins)
    elseif mins > 0 then
        return string.format("|cFFFF3333⏱ %dm %02ds|r", mins, secs)
    else
        return string.format("|cFFFF3333⏱ %ds|r", secs)
    end
end

local function FetchQuestTimeLeft(questID, logIndex)
    local timeLeft = nil
    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestTimeLeftSeconds) == "function" then
        local s, v = pcall(C_TaskQuest.GetQuestTimeLeftSeconds, questID)
        if s and v and v > 0 then timeLeft = v end
    end
    if not timeLeft and type(GetQuestLogTimeLeft) == "function" then
        local s, v = pcall(GetQuestLogTimeLeft, logIndex)
        if s and v and v > 0 then timeLeft = v end
        if not timeLeft then
            s, v = pcall(GetQuestLogTimeLeft, questID)
            if s and v and v > 0 then timeLeft = v end
        end
    end
    return timeLeft
end

-- =========================================================================
-- 5. Main Update Function
-- =========================================================================
UpdateQuestList = function()
    if not f:IsShown() or isCollapsed then return end

    local oldSelectionIndex
    local oldSelectionID
    if type(GetQuestLogSelection) == "function" then oldSelectionIndex = GetQuestLogSelection() end
    if C_QuestLog and type(C_QuestLog.GetSelectedQuest) == "function" then oldSelectionID = C_QuestLog.GetSelectedQuest() end

    for _, line in ipairs(questLines) do line:Hide() end
    for _, tab in ipairs(tabButtons) do tab:Hide() end

    wipe(activeTimers)

    local numEntries = C_QuestLog.GetNumQuestLogEntries()

    local filters = {
        [L.TAB_ALL] = true,
        [L.TAB_RECENT] = true,
        [L.TAB_READY] = true,
        [L.TAB_TRACKED] = true,
        [L.TAB_UNTRACKED] = true
    }

    for i = 1, numEntries do
        local q = C_QuestLog.GetInfo(i)
        if q and not q.isHidden and q.isHeader then filters[q.title] = true end
    end

    local sortedFilters = {}
    for k in pairs(filters) do table.insert(sortedFilters, k) end
    table.sort(sortedFilters, function(a, b)
        local order = {
            [L.TAB_ALL] = 1,
            [L.TAB_RECENT] = 2,
            [L.TAB_READY] = 3,
            [L.TAB_TRACKED] = 4,
            [L.TAB_UNTRACKED] = 5
        }
        if order[a] and order[b] then return order[a] < order[b] end
        if order[a] then return true end
        if order[b] then return false end
        return a < b
    end)

    local tabX, tabY = 10, -28
    for i, filterName in ipairs(sortedFilters) do
        local tab = GetOrCreateTab(i)
        tab:SetText(filterName)
        -- Reduced horizontal padding to 14 to save space in narrow view
        local tabWidth = tab.text:GetStringWidth() + 14
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

        for _, region in ipairs({ tab:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                if isSelected then
                    region:SetVertexColor(1, 1, 1)
                else
                    region:SetVertexColor(0.4, 0.4, 0.4)
                end
            end
        end

        tab:SetScript("OnClick", function()
            activeFilter = filterName; UpdateQuestList()
        end)
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

        local qBtn = GetOrCreateLine(lineIndex)
        qBtn:ClearAllPoints()
        qBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)

        -- Shift text to the right to make room for the checkbox
        qBtn.text:SetPoint("TOPLEFT", qBtn, "TOPLEFT", 20, -2)
        qBtn.text:SetWidth(scrollFrame:GetWidth() - 45)
        qBtn.text:SetFontObject("GameFontHighlight")

        -- Determine current tracking status
        local isCurrentlyTracked = false
        if type(C_QuestLog.GetQuestWatchType) == "function" then
            isCurrentlyTracked = (C_QuestLog.GetQuestWatchType(questInfo.questID) ~= nil)
        elseif type(IsQuestWatched) == "function" then
            isCurrentlyTracked = IsQuestWatched(logIndex)
        end

        -- Configure Checkbox
        qBtn.trackBtn:Show()
        qBtn.trackBtn:SetChecked(isCurrentlyTracked)
        qBtn.trackBtn:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked()
            if not isChecked then
                -- Clear SuperTrack and untrack
                if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
                    if C_SuperTrack.GetSuperTrackedQuestID() == questInfo.questID then
                        pcall(
                            C_SuperTrack.SetSuperTrackedQuestID, 0)
                    end
                elseif type(SetSuperTrackedQuestID) == "function" then
                    if GetSuperTrackedQuestID() == questInfo.questID then pcall(SetSuperTrackedQuestID, 0) end
                end

                if type(C_QuestLog.RemoveQuestWatch) == "function" then
                    pcall(C_QuestLog.RemoveQuestWatch, questInfo.questID)
                elseif type(RemoveQuestWatch) == "function" then
                    pcall(RemoveQuestWatch, logIndex)
                end
            else
                -- Add track
                if type(C_QuestLog.AddQuestWatch) == "function" then
                    pcall(C_QuestLog.AddQuestWatch, questInfo.questID)
                elseif type(AddQuestWatch) == "function" then
                    pcall(AddQuestWatch, logIndex)
                end
            end

            if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                C_Timer.After(0.05, UpdateQuestList)
            else
                UpdateQuestList()
            end
        end)

        qBtn.text:SetWidth(scrollFrame:GetWidth() - 25)
        qBtn.text:SetFontObject("GameFontHighlight")


        local hexDiff = GetDifficultyColorHex(questInfo.level)
        local expandSymbol = expandedQuests[questInfo.questID] and "[-] " or "[+] "

        -- Replaced the Level text with the Quest ID prefix
        local idText = "[" .. questInfo.questID .. "] "

        local isReady = IsQuestReadySafe(questInfo, logIndex)
        local status = isReady and " |cFF00FF00" .. L.READY .. "|r" or ""

        qBtn.text:SetText(hexDiff .. expandSymbol .. idText .. questInfo.title .. "|r" .. status)


        qBtn:SetScript("OnEnter", function(self)
            self.text:SetAlpha(0.7)

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()

            -- Title & Basic Details
            GameTooltip:AddLine(questInfo.title, 1, 1, 1)
            GameTooltip:AddDoubleLine("Quest ID:", tostring(questInfo.questID), 0.7, 0.7, 0.7, 1, 0.82, 0)

            local questMapID = type(QuestUtils_GetQuestMapID) == "function" and
                QuestUtils_GetQuestMapID(questInfo.questID) or nil
            if questMapID then
                GameTooltip:AddDoubleLine("Map ID:", tostring(questMapID), 0.7, 0.7, 0.7, 0.3, 0.8, 1)
            end


            -- ==========================================
            -- T3_QuestDB Custom Data Hook
            -- ==========================================
            if T3_QuestDB and T3_QuestDB[questInfo.questID] then
                local dbData = T3_QuestDB[questInfo.questID]
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("T3_QuestDB Info:", 0.2, 1, 0.8)

                if dbData.startedBy and #dbData.startedBy > 0 then
                    -- Yellow ! mark
                    GameTooltip:AddDoubleLine("|cFFFFFF00!|r Started By:", table.concat(dbData.startedBy, ", "), 1, 0.82,
                        0, 1, 1, 1)
                end

                if dbData.finishedBy and #dbData.finishedBy > 0 then
                    -- Yellow ? mark
                    GameTooltip:AddDoubleLine("|cFFFFFF00?|r Finished By:", table.concat(dbData.finishedBy, ", "), 1,
                        0.82, 0, 1, 1, 1)
                end

                if dbData.objectives and #dbData.objectives > 0 then
                    local formattedObjs = {}
                    local qType = dbData.type or 0
                    local labelText = "DB Objectives:"

                    -- Dynamically change the label text based on the type
                    if qType == 1 then
                        labelText = "DB NPC:"
                    elseif qType == 2 then
                        labelText = "DB Object:"
                    elseif qType == 3 then
                        labelText = "DB Item:"
                    end

                    for _, objID in ipairs(dbData.objectives) do
                        local objName = nil

                        -- Type 1: NPC Database
                        if qType == 1 and T3_NpcDB and T3_NpcDB[objID] then
                            objName = T3_NpcDB[objID][1] or T3_NpcDB[objID].name

                            -- Type 2: Object Database
                        elseif qType == 2 and T3_ObjectDB and T3_ObjectDB[objID] then
                            objName = T3_ObjectDB[objID][1] or T3_ObjectDB[objID].name

                            -- Type 3: Item Database
                        elseif qType == 3 and T3_itemDB and T3_itemDB[objID] then
                            objName = T3_itemDB[objID].name or T3_itemDB[objID][1]
                        end

                        if objName then
                            table.insert(formattedObjs, "[" .. objID .. "] " .. objName)
                        else
                            -- Fallback if the ID isn't found in the designated DB
                            table.insert(formattedObjs, tostring(objID))
                        end
                    end

                    GameTooltip:AddDoubleLine("|TInterface\\MoneyFrame\\UI-GoldIcon:8:8|t " .. labelText,
                        table.concat(formattedObjs, ", "), 1, 0.5, 0, 1, 1, 1)
                end
            end

            -- ==========================================
            -- Client API Item Data
            -- ==========================================
            GameTooltip:AddLine(" ")

            -- Special Quest Action Item
            if type(GetQuestLogSpecialItemInfo) == "function" then
                local _, _, _, questItemID = pcall(GetQuestLogSpecialItemInfo, logIndex)
                if questItemID then
                    GameTooltip:AddDoubleLine(" ", tostring(questItemID), 0.7,
                        0.7, 0.7, 0.2, 1, 0.2)
                end
            end

            -- Reward Item IDs
            local itemIDs = {}
            local numRewards = 0
            if type(GetNumQuestLogRewards) == "function" then
                local s, v = pcall(GetNumQuestLogRewards, questInfo.questID)
                if not s or not v then s, v = pcall(GetNumQuestLogRewards) end
                if s and v then numRewards = v end
            end

            for r = 1, numRewards do
                local link = GetItemLinkSafe("reward", r, questInfo.questID)
                if link then
                    local id = link:match("item:(%d+)")
                    if id then table.insert(itemIDs, id) end
                end
            end

            -- ==========================================
            -- Objective Metadata (Types & Strings)
            -- ==========================================
            if type(C_QuestLog.GetQuestObjectives) == "function" then
                local objs = C_QuestLog.GetQuestObjectives(questInfo.questID)
                if objs and #objs > 0 then
                    for i, obj in ipairs(objs) do
                        local oType = obj.type or "unknown"
                        GameTooltip:AddDoubleLine(" ",
                            (obj.text or ""), 0.5, 0.8, 1, 0.8, 0.8, 0.8)
                    end
                end
            elseif type(GetNumQuestLeaderBoards) == "function" then
                local numObjs = GetNumQuestLeaderBoards(logIndex)
                if numObjs and numObjs > 0 then
                    for i = 1, numObjs do
                        local text, oType = GetQuestLogLeaderBoard(i, logIndex)
                        oType = oType or "unknown"
                        GameTooltip:AddDoubleLine(" ",
                            (text or ""), 0.5, 0.8, 1, 0.8, 0.8, 0.8)
                    end
                end
            end

            GameTooltip:Show()
        end)


        qBtn:SetScript("OnLeave", function(self)
            self.text:SetAlpha(1.0)
            GameTooltip:Hide()
        end)

        qBtn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                -- 1. Set the clicked quest as the focused (SuperTracked) quest
                if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
                    pcall(C_SuperTrack.SetSuperTrackedQuestID, questInfo.questID)
                elseif type(SetSuperTrackedQuestID) == "function" then
                    pcall(SetSuperTrackedQuestID, questInfo.questID)
                end

                -- 2. Execute POI Map lookups
                if T3_QuestDB and T3_QuestDB[questInfo.questID] then
                    local dbData = T3_QuestDB[questInfo.questID]
                    local qType = dbData.type or 0
                    local foundZones = {}

                    if dbData.objectives and #dbData.objectives > 0 then
                        for _, objID in ipairs(dbData.objectives) do
                            -- Type 1: NPC
                            if qType == 1 and T3_NpcDB and T3_NpcDB[objID] then
                                local zoneID = T3_NpcDB[objID][2]
                                if zoneID then foundZones[zoneID] = true end
                                
                            -- Type 2: Object
                            elseif qType == 2 and T3_ObjectDB and T3_ObjectDB[objID] then
                                local zoneID = T3_ObjectDB[objID][5]
                                if zoneID then foundZones[zoneID] = true end
                                
                            -- Type 3: Item
                            elseif qType == 3 and T3_itemDB and T3_itemDB[objID] then
                                local itemData = T3_itemDB[objID]
                                
                                if itemData.npcDrops and #itemData.npcDrops > 0 then
                                    for _, dropNpcID in ipairs(itemData.npcDrops) do
                                        if T3_NpcDB and T3_NpcDB[dropNpcID] then
                                            local zoneID = T3_NpcDB[dropNpcID][2]
                                            if zoneID then foundZones[zoneID] = true end
                                        end
                                    end
                                end
                                
                                if itemData.objectDrops and #itemData.objectDrops > 0 then
                                    for _, dropObjID in ipairs(itemData.objectDrops) do
                                        if T3_ObjectDB and T3_ObjectDB[dropObjID] then
                                            local zoneID = T3_ObjectDB[dropObjID][5]
                                            if zoneID then foundZones[zoneID] = true end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Extract the first found zone for mapping
                    local targetClassicZone = nil
                    for zID, _ in pairs(foundZones) do
                        targetClassicZone = zID
                        break 
                    end
                    
                    if targetClassicZone then
                        if _G.func_ConvertClassicIDToMapID and _G.func_OpenZoneMapByID then
                            local modernMapID = _G.func_ConvertClassicIDToMapID(targetClassicZone)
                            if modernMapID then
                                _G.func_OpenZoneMapByID(modernMapID)
                            end
                        end
                    else
                        -- Fallback to client API map ID if DB fails
                        local fallbackMapID = type(QuestUtils_GetQuestMapID) == "function" and QuestUtils_GetQuestMapID(questInfo.questID) or nil
                        if fallbackMapID and _G.func_OpenZoneMapByID then
                            _G.func_OpenZoneMapByID(fallbackMapID)
                        end
                    end
                end
            else
                -- Left-click expand/collapse
                expandedQuests[questInfo.questID] = not expandedQuests[questInfo.questID]
                UpdateQuestList()
            end
        end)

        local qHeight = qBtn.text:GetStringHeight()
        qBtn:SetSize(scrollFrame:GetWidth() - 25, qHeight + 4)
        qBtn:Show()
        yOffset = yOffset - (qHeight + 4)
        lineIndex = lineIndex + 1

        -- Objectives
        local objLines = ""
        if type(C_QuestLog.GetQuestObjectives) == "function" then
            local objectives = C_QuestLog.GetQuestObjectives(questInfo.questID)
            if objectives and #objectives > 0 then
                for _, obj in ipairs(objectives) do
                    local objColor = obj.finished and "|cFF808080" or "|cFFFFFFFF"
                    objLines = objLines .. objColor .. "• " .. (obj.text or "") .. "|r\n"
                end
            end
        end

        if objLines == "" and type(GetNumQuestLeaderBoards) == "function" and type(GetQuestLogLeaderBoard) == "function" then
            local numObjs = GetNumQuestLeaderBoards(logIndex)
            if numObjs and numObjs > 0 then
                for objIndex = 1, numObjs do
                    local desc, _, finished = GetQuestLogLeaderBoard(objIndex, logIndex)
                    if desc and desc ~= "" then
                        local objColor = finished and "|cFF808080" or "|cFFFFFFFF"
                        objLines = objLines .. objColor .. "• " .. desc .. "|r\n"
                    end
                end
            end
        end

        if objLines ~= "" then
            FlushText(objLines, 32)
        end

-- ==========================================
        -- Location & Map coordinates (Moved Outside)
        -- ==========================================
        local dbMapIDs = {}
        local dbCoords = {}
        
        if T3_QuestDB and T3_QuestDB[questInfo.questID] then
            local dbData = T3_QuestDB[questInfo.questID]
            local qType = dbData.type or 0
            
            if dbData.objectives and #dbData.objectives > 0 then
                for _, objID in ipairs(dbData.objectives) do
                    -- Type 1: NPC
                    if qType == 1 and T3_NpcDB and T3_NpcDB[objID] then
                        local zID = T3_NpcDB[objID][2]
                        if zID then dbMapIDs[zID] = true end
                        local coordsList = T3_NpcDB[objID][3]
                        if coordsList and #coordsList > 0 then
                            table.insert(dbCoords, string.format("{%.1f, %.1f}", coordsList[1][1], coordsList[1][2]))
                        end
                    
                    -- Type 2: Object
                    elseif qType == 2 and T3_ObjectDB and T3_ObjectDB[objID] then
                        local zID = T3_ObjectDB[objID][5]
                        if zID then dbMapIDs[zID] = true end
                        local spawns = T3_ObjectDB[objID][4]
                        if spawns and zID and spawns[zID] and #spawns[zID] > 0 then
                            table.insert(dbCoords, string.format("{%.1f, %.1f}", spawns[zID][1][1], spawns[zID][1][2]))
                        end
                    
                    -- Type 3: Item (Check npcDrops and objectDrops)
                    elseif qType == 3 and T3_itemDB and T3_itemDB[objID] then
                        local itemData = T3_itemDB[objID]
                        
                        -- Search NPC Drops
                        if itemData.npcDrops and #itemData.npcDrops > 0 then
                            for _, dropID in ipairs(itemData.npcDrops) do
                                if T3_NpcDB and T3_NpcDB[dropID] then
                                    local zID = T3_NpcDB[dropID][2]
                                    if zID then dbMapIDs[zID] = true end
                                    local coordsList = T3_NpcDB[dropID][3]
                                    if coordsList and #coordsList > 0 then
                                        table.insert(dbCoords, string.format("{%.1f, %.1f}", coordsList[1][1], coordsList[1][2]))
                                    end
                                end
                            end
                        end
                        
                        -- Search Object Drops
                        if itemData.objectDrops and #itemData.objectDrops > 0 then
                            for _, dropID in ipairs(itemData.objectDrops) do
                                if T3_ObjectDB and T3_ObjectDB[dropID] then
                                    local zID = T3_ObjectDB[dropID][5]
                                    if zID then dbMapIDs[zID] = true end
                                    local spawns = T3_ObjectDB[dropID][4]
                                    if spawns and zID and spawns[zID] and #spawns[zID] > 0 then
                                        table.insert(dbCoords, string.format("{%.1f, %.1f}", spawns[zID][1][1], spawns[zID][1][2]))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        -- 1. Format Map ID output
        local mapTextList = {}
        for zID, _ in pairs(dbMapIDs) do table.insert(mapTextList, tostring(zID)) end
        
        local mapText = ""
        if #mapTextList > 0 then
            mapText = "[" .. table.concat(mapTextList, ", ") .. "]"
        else
            mapText = "Unknown"
        end

        -- 2. Format Coordinates output
        local coordsStr = ""
        local foundCoords = false

        -- DB First
        if #dbCoords > 0 then
            local maxCoords = math.min(#dbCoords, 3) -- Limit to 3 visible points
            local displayCoords = {}
            for i = 1, maxCoords do
                table.insert(displayCoords, dbCoords[i])
            end
            coordsStr = " {" .. table.concat(displayCoords, ", ")
            if #dbCoords > 3 then coordsStr = coordsStr .. ", ..." end
            coordsStr = coordsStr .. "}"
            foundCoords = true
        end

        -- API Fallbacks
        if not foundCoords and type(C_QuestLog.GetNextWaypoint) == "function" then
            local wp = C_QuestLog.GetNextWaypoint(questInfo.questID)
            if wp and wp.x and wp.y then
                coordsStr = string.format(" {{%.1f, %.1f}}", wp.x * 100, wp.y * 100)
                foundCoords = true
            end
        end

        if not foundCoords and type(C_QuestLog.GetQuestPOIs) == "function" then
            local fallbackMapID = type(QuestUtils_GetQuestMapID) == "function" and QuestUtils_GetQuestMapID(questInfo.questID) or nil
            if fallbackMapID then
                local pois = C_QuestLog.GetQuestPOIs(questInfo.questID)
                if pois and #pois > 0 then
                    local poiList = {}
                    local maxPois = math.min(#pois, 3)
                    for i = 1, maxPois do
                        local poi = pois[i]
                        if type(poi.GetXY) == "function" then
                            local x, y = poi:GetXY()
                            if x and y then table.insert(poiList, string.format("{%.1f, %.1f}", x * 100, y * 100)) end
                        end
                    end
                    if #poiList > 0 then
                        coordsStr = " {" .. table.concat(poiList, ", ")
                        if #pois > 3 then coordsStr = coordsStr .. ", ..." end
                        coordsStr = coordsStr .. "}"
                    end
                end
            end
        end

        -- 3. Render final string
        local locText = "|cFF808080" .. mapText .. coordsStr .. "|r"
        FlushText(locText, 32)
        -- ==========================================
        


        -- Timers
        local initialTimeLeft = FetchQuestTimeLeft(questInfo.questID, logIndex)

        -- Timers
        local initialTimeLeft = FetchQuestTimeLeft(questInfo.questID, logIndex)
        if initialTimeLeft and initialTimeLeft > 0 then
            local tBtn = GetOrCreateLine(lineIndex)
            tBtn:ClearAllPoints()
            tBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 32, yOffset)
            tBtn.text:SetWidth(scrollFrame:GetWidth() - 37)
            tBtn.text:SetFontObject("GameFontHighlightSmall")
            tBtn.text:SetText(GetFormattedTimerString(initialTimeLeft))

            local h = tBtn.text:GetStringHeight()
            tBtn:SetSize(scrollFrame:GetWidth() - 37, h + 4)
            tBtn:Show()

            yOffset = yOffset - (h + 4)
            lineIndex = lineIndex + 1

            table.insert(activeTimers, {
                btn = tBtn,
                questID = questInfo.questID,
                logIndex = logIndex
            })
        end

        -- Expanded Details
        if expandedQuests[questInfo.questID] then
            if C_QuestLog and type(C_QuestLog.SetSelectedQuest) == "function" then
                pcall(C_QuestLog.SetSelectedQuest, questInfo.questID)
            elseif type(SelectQuestLogEntry) == "function" then
                pcall(SelectQuestLogEntry, logIndex)
            end

            local textBlock1 = ""
            local description, objectiveText = GetQuestLogQuestText()
            if objectiveText and objectiveText ~= "" then
                textBlock1 = textBlock1 ..
                    "|cFFFFFF00" .. L.PREFACE .. "|r\n" .. objectiveText .. "\n\n"
            end
            if description and description ~= "" then
                textBlock1 = textBlock1 ..
                    "|cFFFFFF00" .. L.STORY .. "|r\n" .. description .. "\n\n"
            end

            local xp = 0
            if type(GetQuestLogRewardXP) == "function" then
                local s, v = pcall(GetQuestLogRewardXP, questInfo.questID)
                if not s or not v then s, v = pcall(GetQuestLogRewardXP) end
                if s and v then xp = v end
            end

            local money = 0
            if type(GetQuestLogRewardMoney) == "function" then
                local s, v = pcall(GetQuestLogRewardMoney, questInfo.questID)
                if not s or not v then s, v = pcall(GetQuestLogRewardMoney) end
                if s and v then money = v end
            end

            if xp > 0 or money > 0 then
                textBlock1 = textBlock1 .. "|cFFFFFF00" .. L.REWARDS .. "|r\n"
                if xp > 0 then textBlock1 = textBlock1 .. xp .. " XP\n" end
                if money > 0 then textBlock1 = textBlock1 .. GetMoneyStringPlain(money) .. "\n" end
            end
            FlushText(textBlock1, 35)

            local numRewards = 0
            if type(GetNumQuestLogRewards) == "function" then
                local s, v = pcall(GetNumQuestLogRewards, questInfo.questID)
                if not s or not v then s, v = pcall(GetNumQuestLogRewards) end
                if s and v then numRewards = v end
            end

            if numRewards > 0 then
                FlushText("|cFFFFFF00" .. L.ITEMS .. "|r", 35)
                for r = 1, numRewards do
                    local s, itemName, _, count = pcall(GetQuestLogRewardInfo, r, questInfo.questID)
                    if not s or not itemName then s, itemName, _, count = pcall(GetQuestLogRewardInfo, r) end
                    if itemName then
                        local link = GetItemLinkSafe("reward", r, questInfo.questID)
                        count = (count and count > 1) and (count .. "x ") or ""

                        local iBtn = GetOrCreateLine(lineIndex)
                        iBtn:ClearAllPoints()
                        iBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 35, yOffset)
                        iBtn.text:SetWidth(scrollFrame:GetWidth() - 45)
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
                        iBtn:SetSize(scrollFrame:GetWidth() - 45, h + 4)
                        iBtn:Show()
                        yOffset = yOffset - (h + 6)
                        lineIndex = lineIndex + 1
                    end
                end
                yOffset = yOffset - 4
            end

            local numChoices = 0
            if type(GetNumQuestLogChoices) == "function" then
                local s, v = pcall(GetNumQuestLogChoices, questInfo.questID)
                if not s or not v then s, v = pcall(GetNumQuestLogChoices) end
                if s and v then numChoices = v end
            end

            if numChoices > 0 then
                FlushText("|cFFFFFF00" .. L.CHOOSE .. "|r", 35)
                for c = 1, numChoices do
                    local s, itemName, _, count = pcall(GetQuestLogChoiceInfo, c, questInfo.questID)
                    if not s or not itemName then s, itemName, _, count = pcall(GetQuestLogChoiceInfo, c) end
                    if itemName then
                        local link = GetItemLinkSafe("choice", c, questInfo.questID)
                        count = (count and count > 1) and (count .. "x ") or ""

                        local cBtn = GetOrCreateLine(lineIndex)
                        cBtn:ClearAllPoints()
                        cBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 35, yOffset)
                        cBtn.text:SetWidth(scrollFrame:GetWidth() - 45)
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
                        cBtn:SetSize(scrollFrame:GetWidth() - 45, h + 4)
                        cBtn:Show()
                        yOffset = yOffset - (h + 6)
                        lineIndex = lineIndex + 1
                    end
                end
                yOffset = yOffset - 4
            end
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
            hBtn.text:SetText("|cFFFFFFFF" .. L.FOCUSED .. "|r")
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
                    local isReady = IsQuestReadySafe(questInfo, i)
                    local isRecent = (recentQuests[questInfo.questID] ~= nil)

                    if activeFilter == L.TAB_ALL or
                        (activeFilter == L.TAB_RECENT and isRecent) or
                        (activeFilter == L.TAB_READY and isReady) or
                        (activeFilter == L.TAB_TRACKED and isTracked) or
                        (activeFilter == L.TAB_UNTRACKED and isUntracked) or
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

    if oldSelectionID and C_QuestLog and type(C_QuestLog.SetSelectedQuest) == "function" then
        pcall(C_QuestLog.SetSelectedQuest, oldSelectionID)
    elseif oldSelectionIndex and type(SelectQuestLogEntry) == "function" then
        pcall(SelectQuestLogEntry, oldSelectionIndex)
    end
end

-- =========================================================================
-- 6. Events & Keybinds
-- =========================================================================
f:SetScript("OnShow", function()
    f:SetWidth(250) -- Forces the width to bypass WoW's layout cache
    UpdateQuestList()
end)
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
f:RegisterEvent("SUPER_TRACKING_CHANGED")
f:RegisterEvent("PLAYER_LEVEL_UP")

f:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
f:RegisterEvent("QUEST_WATCH_UPDATE")
f:RegisterEvent("QUEST_ACCEPTED") -- Add this new listener


f:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "QUEST_ACCEPTED" then
        -- Depending on the client version, questID is usually arg2, but we check both safely
        local questID = type(arg2) == "number" and arg2 or arg1
        if type(questID) == "number" then
            recentQuests[questID] = GetTime()
        end
    elseif event == "QUEST_LOG_UPDATE" or (event == "UNIT_QUEST_LOG_CHANGED" and arg1 == "player") then
        CheckForQuestUpdates()
    end
    UpdateQuestList()
end)


tinsert(UISpecialFrames, f:GetName())
f:Hide()



-- =========================================================================
-- Global Toggle & Focus Function
-- =========================================================================
_G.func_ToggleT3Window = function(questID)
    if type(questID) == "number" then
        -- 1. Inject into Recent cache
        recentQuests[questID] = GetTime()
        
        -- 2. Switch tab to Recent
        activeFilter = L.TAB_RECENT
        
        -- 3. Set to focused state (SuperTrack)
        if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
            pcall(C_SuperTrack.SetSuperTrackedQuestID, questID)
        elseif type(SetSuperTrackedQuestID) == "function" then
            pcall(SetSuperTrackedQuestID, questID)
        end
        
        -- 4. Show window or force UI refresh if already open
        if not f:IsShown() then
            f:Show() -- The OnShow script automatically calls UpdateQuestList()
        else
            UpdateQuestList()
        end
    else
        -- Default toggle behavior if no valid ID is passed
        if f:IsShown() then f:Hide() else f:Show() end
    end
end

SLASH_T3_CMD1 = "/t3"
SlashCmdList["T3_CMD"] = function(msg)
    -- Clean up the input string (removes leading/trailing spaces)
    msg = msg and strtrim(msg) or ""
    
    if msg ~= "" then
        local questID = tonumber(msg)
        if questID then
            -- Input was a valid number (e.g., /t3 1001)
            _G.func_ToggleT3Window(questID)
        else
            -- Input was text instead of a number
            print("|cFFFF3333[T3]|r Invalid quest ID. Usage: /t3 OR /t3 <QuestID>")
        end
    else
        -- No input provided, standard toggle behavior
        _G.func_ToggleT3Window()
    end
end


local toggleBtn = CreateFrame("Button", "T3_UniqueKeybindButton", UIParent)
toggleBtn:SetScript("OnClick", function() _G.func_ToggleT3Window() end)




--
local bindInitializer = CreateFrame("Frame")
bindInitializer:RegisterEvent("PLAYER_ENTERING_WORLD")
bindInitializer:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    SetBindingClick("CTRL-NUMPAD3", "T3_UniqueKeybindButton")
    SaveBindings(GetCurrentBindingSet())
end)

-- =========================================================================
-- LIVE TIMER TICKER (Runs only when window is open)
-- =========================================================================
local timerUpdateAccumulator = 0
f:SetScript("OnUpdate", function(self, elapsed)
    if #activeTimers == 0 then return end

    timerUpdateAccumulator = timerUpdateAccumulator + elapsed
    if timerUpdateAccumulator >= 1.0 then
        timerUpdateAccumulator = 0

        for _, tData in ipairs(activeTimers) do
            local current = FetchQuestTimeLeft(tData.questID, tData.logIndex)
            if current and current > 0 then
                tData.btn.text:SetText(GetFormattedTimerString(current))
            else
                tData.btn.text:SetText("|cFFFF3333⏱ 0s|r")
            end
        end
    end
end)
