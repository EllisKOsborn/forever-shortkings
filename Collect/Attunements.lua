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

-- State for one profile and raid, plus an optional note. Pure; tested.
--   "none"    the raid needs no attunement
--   "yes"     quest done, or the required item is in their bags
--   "no"      quest not done and the item isn't in their bags
--   "unknown" no Short Royalty data, gear/talents hidden, quests not known yet,
--             or a profile from a version that didn't record it
-- The note says "amulet not in bags" when the quest is done but the item
-- (e.g. the Drakefire Amulet) isn't in their bags.
function Att.StateOf(p, raid)
	if raid and raid.status == "none" then return "none" end
	if not raid or raid.status == "todo" or not raid.quests or #raid.quests == 0 then return "unknown" end
	if not p or (p.hidden and p.hidden.gear) then return "unknown" end
	local quest = p.att and p.att[raid.key]
	local item = raid.item and p.att and p.att[raid.key .. "_item"]
	if quest == true then
		if item == false then return "yes", (raid.itemName or "item") .. " not in bags" end
		return "yes"
	end
	if item == true then return "yes" end
	if quest == false then return "no" end
	return "unknown"
end
