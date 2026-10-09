local addonName, T1 = ...
local f = T1.MapFrame

f.chk_T5 = T1.CreatePoICheckbox("T1_Chk_T5", "T5_Dgn", false, nil)
f.chk_T5:Disable()
f.chk_T5:SetAlpha(0.5)