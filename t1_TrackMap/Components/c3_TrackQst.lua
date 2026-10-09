local addonName, T1 = ...
local f = T1.MapFrame

f.showT3Quests = true
if not f.questPinPool then f.questPinPool = {} end

-- 1. Initialize the UI Toggle (Using the new 4-parameter auto-anchoring signature)
f.chk_T3 = T1.CreatePoICheckbox("T1_Chk_T3", "T3_Qst", true, function(isChecked)
    f.showT3Quests = isChecked
    if f.RefreshQuestPins then f:RefreshQuestPins() end
end)

-- 2. Render Quest Pins
function f:RefreshQuestPins()
    for _, pin in ipairs(f.questPinPool) do pin:Hide() end
    if not f.showT3Quests or f.currentMapID == 947 or f.currentMapID == -1416 or f.currentMapID <= 0 then return end

    local quests = C_QuestLog.GetQuestsOnMap(f.currentMapID)
    if not quests or #quests == 0 then return end

    local contentW, contentH = f.mapContent:GetSize()
    local pinIndex = 1

    for _, questData in ipairs(quests) do
        if questData.x and questData.y then
            local pin = f.questPinPool[pinIndex]
            if not pin then
                pin = CreateFrame("Button", nil, f.mapContent)
                pin:SetFrameLevel(f.mapContent:GetFrameLevel() + 65)
                pin.tex = pin:CreateTexture(nil, "OVERLAY")
                pin.tex:SetAllPoints()
                pin.iconText = pin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                pin.iconText:SetPoint("CENTER", pin, "CENTER", 0, 0)
                f.questPinPool[pinIndex] = pin
            end

            pin.questID = questData.questID

            local function UpdatePinVisuals()
                local isComplete = C_QuestLog.IsComplete(pin.questID)
                local isWatched = false
                if C_QuestLog.GetQuestWatchType then
                    isWatched = (C_QuestLog.GetQuestWatchType(pin.questID) ~= nil)
                elseif QuestUtils_IsQuestWatched then
                    isWatched = QuestUtils_IsQuestWatched(pin.questID)
                end

                local isSuperTracked = false
                if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
                    isSuperTracked = (C_SuperTrack.GetSuperTrackedQuestID() == pin.questID)
                end

                if isComplete then
                    pin.tex:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
                    pin.tex:Show()
                    pin.iconText:Hide()
                    if isSuperTracked then
                        pin.tex:SetDesaturated(false); pin.tex:SetVertexColor(1, 0.6, 0.0)
                        pin:SetSize(20 / f.zoomLevel, 20 / f.zoomLevel)
                    elseif isWatched then
                        pin.tex:SetDesaturated(false); pin.tex:SetVertexColor(1, 1, 1)
                        pin:SetSize(20 / f.zoomLevel, 20 / f.zoomLevel)
                    else
                        pin.tex:SetDesaturated(true); pin.tex:SetVertexColor(0.5, 0.5, 0.5)
                        pin:SetSize(20 / f.zoomLevel, 20 / f.zoomLevel)
                    end
                else
                    pin.tex:Hide()
                    pin.iconText:Show()
                    if isSuperTracked then
                        pin.iconText:SetText("|TInterface\\MoneyFrame\\UI-CopperIcon:6:6|t|TInterface\\MoneyFrame\\UI-CopperIcon:6:6|t|TInterface\\MoneyFrame\\UI-CopperIcon:6:6|t")
                        pin:SetSize(18 / f.zoomLevel, 6 / f.zoomLevel)
                    elseif isWatched then
                        pin.iconText:SetText("|TInterface\\MoneyFrame\\UI-GoldIcon:6:6|t|TInterface\\MoneyFrame\\UI-GoldIcon:6:6|t|TInterface\\MoneyFrame\\UI-GoldIcon:6:6|t")
                        pin:SetSize(18 / f.zoomLevel, 6 / f.zoomLevel)
                    else
                        pin.iconText:SetText("|TInterface\\MoneyFrame\\UI-SilverIcon:6:6|t|TInterface\\MoneyFrame\\UI-SilverIcon:6:6|t|TInterface\\MoneyFrame\\UI-SilverIcon:6:6|t")
                        pin:SetSize(18 / f.zoomLevel, 6 / f.zoomLevel)
                    end
                end
            end

            UpdatePinVisuals()

            pin:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local title = C_QuestLog.GetTitleForQuestID(self.questID)
                GameTooltip:SetText(title .. " (|cFF00FFFF#" .. self.questID .. "|r)", 1, 0.82, 0)
                local objectives = C_QuestLog.GetQuestObjectives(self.questID)
                if objectives and #objectives > 0 then
                    for _, obj in ipairs(objectives) do
                        local color = obj.finished and "|cFF808080" or "|cFFFFFFFF"
                        GameTooltip:AddLine(color .. "- " .. obj.text)
                    end
                else
                    GameTooltip:AddLine("|cFFFFFFFFIn Progress|r")
                end
                if C_QuestLog.IsComplete(self.questID) then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cFF00FF00Ready for turn-in!|r")
                end
                GameTooltip:AddLine(" ")
                GameTooltip:Show()
            end)
            pin:SetScript("OnLeave", function() GameTooltip:Hide() end)

            pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            pin:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    local isWatched = false
                    if C_QuestLog.GetQuestWatchType then
                        isWatched = (C_QuestLog.GetQuestWatchType(self.questID) ~= nil)
                    elseif QuestUtils_IsQuestWatched then
                        isWatched = QuestUtils_IsQuestWatched(self.questID)
                    end
                    if isWatched then
                        if C_QuestLog.RemoveQuestWatch then C_QuestLog.RemoveQuestWatch(self.questID) end
                        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
                    else
                        if C_QuestLog.AddQuestWatch then C_QuestLog.AddQuestWatch(self.questID) end
                        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                    end
                    UpdatePinVisuals()
                    self:GetScript("OnEnter")(self)
                elseif button == "RightButton" then
                    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then C_SuperTrack.SetSuperTrackedQuestID(self.questID) end
                    if f.RefreshQuestPins then f:RefreshQuestPins() end
                    if _G.func_ToggleT3Window then _G.func_ToggleT3Window(self.questID)
                    else print("|cffff2020T1_TrackMap:|r t3_TrackQst addon is not loaded.") end
                end
            end)

            local fontScale = math.max(0.2, 1 / f.zoomLevel)
            pin.iconText:SetScale(fontScale)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", f.mapContent, "TOPLEFT", questData.x * contentW, -questData.y * contentH)
            pin:Show()
            pinIndex = pinIndex + 1
        end
    end
end