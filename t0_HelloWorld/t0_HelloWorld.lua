-- Create a frame to handle events
local frame = CreateFrame("Frame")

-- Register for the PLAYER_LOGIN event
frame:RegisterEvent("PLAYER_LOGIN")

-- Set up the event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        print("|cFF00FF00Hello WoW Addon World!|r")
        print("Welcome, " .. UnitName("player") .. "!")
    end
end)