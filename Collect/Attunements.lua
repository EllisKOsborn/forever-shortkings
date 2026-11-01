-- Attunements: read from the quest ID table in Data/Attunements.lua.
-- Result: { [key] = true | false }. Entries without quest IDs are left out
-- (shown as "unknown").
local _, SK = ...

local Att = SK:NewModule("Attunements")

function Att.Read()
	local out = {}
	for _, a in ipairs(SK.Data.ATTUNEMENTS) do
		if a.quests and #a.quests > 0 then
			local done, known = false, false
			for _, q in ipairs(a.quests) do
				local r = SK.Compat.IsQuestDone(q)
				if r ~= nil then known = true end
				if r then done = true end
			end
			if known then out[a.key] = done end
		end
	end
	return out
end
