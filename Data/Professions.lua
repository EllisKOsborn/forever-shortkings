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
