-- Which equipped items are missing an enchant (Character tab markers).
-- Classic enchanting rules; Forever is reported to keep the original
-- enchantable slots. Only a yes/no check: the enchant ID is read from the
-- item link, so no table of enchant IDs is needed.
local _, SK = ...
SK.Data = SK.Data or {}

local Ench = {}
SK.Data.Enchants = Ench

-- Always enchantable when something is equipped there.
Ench.SLOTS = {
	[1] = "Head", [3] = "Shoulder", [15] = "Back", [5] = "Chest", [9] = "Wrist",
	[10] = "Hands", [7] = "Legs", [8] = "Feet", [16] = "Main Hand",
}

local OFFHAND_OK = { INVTYPE_SHIELD = true, INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }
local WEAPON_CLASS, FISHING_POLE, WAND = 2, 20, 19

-- Should this slot/item be enchanted? nil means "can't tell" (not flagged).
function Ench.Enchantable(slot, link, class)
	local itemID = SK.Compat.ItemIDFromLink(link)
	if not itemID then return false end
	if slot == 16 then
		local _, classID, sub = SK.Compat.ItemEquipInfo(itemID)
		return not (classID == WEAPON_CLASS and sub == FISHING_POLE)
	end
	if Ench.SLOTS[slot] then return true end
	if slot == 17 then
		local equipLoc = SK.Compat.ItemEquipInfo(itemID)
		if not equipLoc then return nil end
		return OFFHAND_OK[equipLoc] or false
	end
	if slot == 18 and class == "HUNTER" then
		local equipLoc, classID, sub = SK.Compat.ItemEquipInfo(itemID)
		if not equipLoc then return nil end
		if equipLoc == "INVTYPE_RANGED" then return true end
		return equipLoc == "INVTYPE_RANGEDRIGHT" and not (classID == WEAPON_CLASS and sub == WAND)
	end
	return false
end

-- Sorted list of slot IDs that hold an item which should be enchanted but isn't.
-- Only characters at max level are checked: levelling gear isn't worth
-- enchanting, so flagging it is noise. `level` nil = unknown, still checked.
function Ench.Missing(gear, class, level)
	local out = {}
	if level and level < SK.Compat.MaxPlayerLevel() then return out end
	for slot, link in pairs(gear or {}) do
		if Ench.Enchantable(slot, link, class) and SK.Compat.EnchantFromLink(link) == 0 then
			out[#out + 1] = slot
		end
	end
	table.sort(out)
	return out
end
