-- Reputations highlighted on the Character tab. The addon records EVERY
-- faction a character can see; this list only decides what is shown first.
--   status = "classic" -> Classic faction ID, not yet confirmed on Forever.
--   status = "todo"    -> Forever faction, ID unknown.
local _, SK = ...
SK.Data = SK.Data or {}

SK.Data.FACTIONS = {
	{ id = 529, name = "Argent Dawn",          status = "classic" },
	{ id = 749, name = "Hydraxian Waterlords", status = "classic" },
	{ id = 609, name = "Cenarion Circle",      status = "classic" },
	{ id = 576, name = "Timbermaw Hold",       status = "classic" },
	{ id = 59,  name = "Thorium Brotherhood",  status = "classic" },
	{ id = 270, name = "Zandalar Tribe",       status = "classic" },
	{ id = 910, name = "Brood of Nozdormu",    status = "classic" },
}

function SK.Data.FactionIDs()
	local ids = {}
	for _, f in ipairs(SK.Data.FACTIONS) do ids[#ids + 1] = f.id end
	return ids
end
