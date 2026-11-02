-- Attunements: read from the table in Data/Attunements.lua.
-- Result: { [key] = true | false, [key .. "_item"] = true | false }.
--   key           the attunement quest is done (any of `quests`)
--   key_item      the required item (e.g. the Drakefire Amulet) is in our bags
-- Entries without quest IDs are left out (shown as "unknown"); the item flag
-- is left out when the client can't count items.
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
		if a.item then
			local n = SK.Compat.ItemCountInBags(a.item)
			if n ~= nil then out[a.key .. "_item"] = n > 0 end
		end
	end
	return out
end
