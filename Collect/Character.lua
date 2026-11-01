-- Basics, equipped gear and item level for the logged-in character.
local _, SK = ...

local Character = SK:NewModule("Character")
local Compat = SK.Compat

function Character.Read()
	local basics = Compat.PlayerBasics()
	local name, realm = Compat.PlayerFullName()
	return {
		name = name,
		realm = realm,
		class = basics.class,
		race = basics.race,
		level = basics.level,
		faction = basics.faction,
		gear = Compat.ReadGear(),
		ilvl = Compat.AverageItemLevel(),
	}
end
