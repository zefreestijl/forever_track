local addonName, T1 = ...
local f = T1.MapFrame

f.chk_T4 = T1.CreatePoICheckbox("T1_Chk_T4", "T4_Res", false, nil)
f.chk_T4:Disable()
f.chk_T4:SetAlpha(0.5)