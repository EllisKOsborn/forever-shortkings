-- Reputations: every faction the character can see, plus the highlight
-- list from Data/Factions.lua looked up by ID.
local _, SK = ...

local Reputation = SK:NewModule("Reputation")

function Reputation.Read()
	local ok, reps = pcall(SK.Compat.ReadReputations, SK.Data.FactionIDs())
	if not ok then
		SK:RecordError("reputation read", reps)
		return {}
	end
	return reps
end
