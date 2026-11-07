-- Raid roles (v0.4.0). A player picks a main and second role in Settings
-- (shared in the profile as `roles`). Until they do, the Raids tab shows a
-- greyed guess from their class and their talent tree with the most points.
--
-- Trees are keyed by their ORDER in the talent data (1, 2, 3), not by name,
-- so other client languages work. The order below is the original game's;
-- status = "todo" until a Forever client confirms the order (the Raids tab
-- marks every guess "(guess)" anyway).
local _, SK = ...
SK.Data = SK.Data or {}

SK.Data.ROLES = { "TANK", "HEALER", "DPS" }
SK.Data.ROLE_NAMES = { TANK = "Tank", HEALER = "Healer", DPS = "DPS" }

SK.Data.ROLE_GUESS = {
	status = "todo",
	WARRIOR = { "DPS", "DPS", "TANK" },        -- Arms, Fury, Protection
	PALADIN = { "HEALER", "TANK", "DPS" },     -- Holy, Protection, Retribution
	HUNTER  = { "DPS", "DPS", "DPS" },
	ROGUE   = { "DPS", "DPS", "DPS" },
	PRIEST  = { "HEALER", "HEALER", "DPS" },   -- Discipline, Holy, Shadow
	SHAMAN  = { "DPS", "DPS", "HEALER" },      -- Elemental, Enhancement, Restoration
	MAGE    = { "DPS", "DPS", "DPS" },
	WARLOCK = { "DPS", "DPS", "DPS" },
	DRUID   = { "DPS", "TANK", "HEALER" },     -- Balance, Feral (tank or cat), Restoration
}

-- Guess from a profile's talents: (role, treeIndex) or nil.
function SK.Data.GuessRole(class, talents)
	local byTree = SK.Data.ROLE_GUESS[class or ""]
	if not byTree then return nil end
	local best, bestIdx = -1, nil
	for i, t in ipairs(type(talents) == "table" and type(talents.trees) == "table" and talents.trees or {}) do
		local pts = type(t) == "table" and tonumber(t.p) or 0
		if pts > best then best, bestIdx = pts, i end
	end
	if not bestIdx or best <= 0 then
		-- No talents yet: a class with only one role still has an answer.
		if byTree[1] == byTree[2] and byTree[2] == byTree[3] then return byTree[1] end
		return nil
	end
	return byTree[bestIdx], bestIdx
end
