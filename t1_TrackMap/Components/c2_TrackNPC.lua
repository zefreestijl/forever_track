local addonName, T1 = ...
local f = T1.MapFrame

f.showT2NPCs = false
if not f.npcPinPool then f.npcPinPool = {} end

-- 1. Initialize the UI Toggle (Using the new 4-parameter auto-anchoring signature)
f.chk_T2 = T1.CreatePoICheckbox("T1_Chk_T2", "T2_NPC", false, function(isChecked)
    f.showT2NPCs = isChecked
    if f.RefreshNPCPins then f:RefreshNPCPins() end
end)

-- 2. Handle Map Canvas Right-Click Integration
function T1:OpenT2Window(targetMapID)
    if targetMapID and targetMapID ~= 0 then
        if _G.func_ToggleT2Window then
            _G.func_ToggleT2Window(targetMapID)
        else
            print("|cffff2020T1_TrackMap:|r T2_TrackNPC addon is not loaded.")
        end
    end
end

-- 3. Render NPC Pins
function f:RefreshNPCPins()
    for _, pin in ipairs(f.npcPinPool) do pin:Hide() end
    if not f.showT2NPCs or f.currentMapID == 947 or f.currentMapID == -1416 or f.currentMapID <= 0 then return end
    if not _G.func_T2_GetNpcInfos then return end

    local npcs = _G.func_T2_GetNpcInfos(f.currentMapID)
    if not npcs or #npcs == 0 then return end

    local contentW, contentH = f.mapContent:GetSize()
    local pinIndex = 1

    for _, npc in ipairs(npcs) do
        if npc.x and npc.y then
            local drawX = npc.x > 1 and npc.x / 100 or npc.x
            local drawY = npc.y > 1 and npc.y / 100 or npc.y

            local pin = f.npcPinPool[pinIndex]
            if not pin then
                pin = CreateFrame("Button", nil, f.mapContent)
                pin:SetFrameLevel(f.mapContent:GetFrameLevel() + 64)
                pin.tex = pin:CreateTexture(nil, "OVERLAY")
                pin.tex:SetAllPoints()
                pin.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_3")
                f.npcPinPool[pinIndex] = pin
            end

            pin:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(npc.name .. " (|cFF00FFFF#" .. (npc.id or "???") .. "|r)", 1, 0.82, 0)
                if npc.description and npc.description ~= "" then GameTooltip:AddLine(npc.description, 1, 1, 1, true) end
                if npc.comment and npc.comment ~= "" then GameTooltip:AddLine("|cFF808080" .. npc.comment .. "|r", 1, 1, 1, true) end
                GameTooltip:Show()
            end)
            pin:SetScript("OnLeave", function() GameTooltip:Hide() end)

            pin:SetSize(10 / f.zoomLevel, 10 / f.zoomLevel)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", f.mapContent, "TOPLEFT", drawX * contentW, -drawY * contentH)
            pin:Show()
            pinIndex = pinIndex + 1
        end
    end
end