-- Attunement quests. RULE: never guess an ID.
--   status = "classic"  -> ID checked against Wowhead (Classic) on 2026-11-01;
--                          not yet confirmed that Forever uses the same quest.
--                          /sk debug shows whether this client knows the quest.
--   status = "todo"     -> ID not known yet; the entry is shown as "unknown".
-- `quests` = any one of these completes it (e.g. Alliance/Horde variants).
local _, SK = ...
SK.Data = SK.Data or {}

SK.Data.ATTUNEMENTS = {
	{ key = "ony",  name = "Onyxia's Lair", status = "classic", faction = "Alliance",
	  quests = { 6502 }, note = "Drakefire Amulet (Alliance). Confirmed by Blizzard to remain in Forever." },
	{ key = "mc",   name = "Molten Core", status = "classic",
	  quests = { 7848 }, note = "Attunement to the Core. Not in the first Forever raid wave." },
	{ key = "bwl",  name = "Blackwing Lair", status = "classic",
	  quests = { 7761 }, note = "Blackhand's Command. No Forever announcement yet." },
	{ key = "barrow", name = "Barrow Deeps", status = "todo", quests = {},
	  note = "New Forever raid (opens 9 Dec 2026). Attunement, if any, unknown." },
	{ key = "hyjal", name = "Hyjal Summit", status = "todo", quests = {},
	  note = "New Forever raid (opens 9 Dec 2026). Attunement, if any, unknown." },
	{ key = "naxx", name = "Naxxramas", status = "todo", quests = {},
	  note = "TODO: verify the Forever attunement quest IDs before adding." },
}
