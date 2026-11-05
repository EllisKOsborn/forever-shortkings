-- Standard SkillLine IDs for the original professions. Used only as a
-- fallback to recognise professions in the skill list and to label them.
-- (These IDs have been stable since 2004; Forever-only professions, if any,
-- are picked up from GetProfessions() at runtime.)
local _, SK = ...
SK.Data = SK.Data or {}

SK.Data.PROFESSIONS = {
	[171] = { key = "Alchemy",        short = "Alch",  primary = true },
	[164] = { key = "Blacksmithing",  short = "BS",    primary = true },
	[333] = { key = "Enchanting",     short = "Ench",  primary = true },
	[202] = { key = "Engineering",    short = "Eng",   primary = true },
	[182] = { key = "Herbalism",      short = "Herb",  primary = true },
	[165] = { key = "Leatherworking", short = "LW",    primary = true },
	[186] = { key = "Mining",         short = "Mine",  primary = true },
	[393] = { key = "Skinning",       short = "Skin",  primary = true },
	[197] = { key = "Tailoring",      short = "Tail",  primary = true },
	[185] = { key = "Cooking",        short = "Cook",  primary = false },
	[129] = { key = "First Aid",      short = "FA",    primary = false },
	[356] = { key = "Fishing",        short = "Fish",  primary = false },
}

-- Professions that have recipes worth scanning (gathering skills do not).
SK.Data.GATHERING = { [182] = true, [186] = true, [393] = true, [356] = true }

function SK.Data.ProfessionShort(skillLine, name)
	local p = SK.Data.PROFESSIONS[skillLine]
	if p then return p.short end
	return name and name:sub(1, 4) or "?"
end

-- Original-game specialisations (B3), candidates for v0.3. The spell IDs
-- match on two sources (wowhead.com/classic and classicdb.ch, checked
-- 5 Nov 2026) but are still status = "todo" until the in-game probe
-- (/sk debug, "Specialisations") confirms them on the Forever client.
-- Alchemy and Tailoring specialisations came in TBC, so they are not listed.
SK.Data.SPECIALISATIONS = {
	[202] = { -- Engineering
		{ spell = 20219, name = "Gnomish Engineer", status = "todo" },
		{ spell = 20222, name = "Goblin Engineer", status = "todo" },
	},
	[165] = { -- Leatherworking
		{ spell = 10656, name = "Dragonscale Leatherworking", status = "todo" },
		{ spell = 10658, name = "Elemental Leatherworking", status = "todo" },
		{ spell = 10660, name = "Tribal Leatherworking", status = "todo" },
	},
	[164] = { -- Blacksmithing
		{ spell = 9788, name = "Armorsmith", status = "todo" },
		{ spell = 9787, name = "Weaponsmith", status = "todo" },
		{ spell = 17041, name = "Master Axesmith", status = "todo" },
		{ spell = 17040, name = "Master Hammersmith", status = "todo" },
		{ spell = 17039, name = "Master Swordsmith", status = "todo" },
	},
}

-- spellID -> { skillLine, name } for display. Profiles may carry any number;
-- only IDs in this table are ever shown.
SK.Data.SPEC_BY_SPELL = {}
for skillLine, list in pairs(SK.Data.SPECIALISATIONS) do
	for _, spec in ipairs(list) do
		SK.Data.SPEC_BY_SPELL[spec.spell] = { skillLine = skillLine, name = spec.name, status = spec.status }
	end
end

-- Highest skill in the original game (Forever is level 60, Classic-era
-- professions). "At max" on the Professions board counts characters here.
SK.Data.SKILL_CAP = 300

-- Board order: crafting first, then gathering, then secondary.
function SK.Data.ProfessionGroup(skillLine)
	local p = SK.Data.PROFESSIONS[skillLine]
	if p and not p.primary then return 3 end
	if SK.Data.GATHERING[skillLine] then return 2 end
	return 1
end
