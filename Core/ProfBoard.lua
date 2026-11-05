-- ProfBoard: the numbers behind the Professions tab (v0.3). Pure functions
-- over the guild's saved data, covered by tests; no UI here.
--
--   Coverage(ctx)            one row per profession (crafting, gathering, secondary)
--   Crafters(ctx, skillLine) everyone with that profession
--   Recipes(ctx, skillLine, filter)  recipes known in the guild, with crafter counts
--   Cooldowns(ctx)           everyone's profession cooldowns, ready first
--
-- ctx = { guild, now, index (CraftIndex), profile = fn(guid), isMember = fn(guid) }
-- Profiles with hidden recipes still count for skill levels (those are always
-- shared) but never for recipes or cooldowns.
local _, SK = ...

local PB = SK:NewModule("ProfBoard")

function PB.Context(now)
	local guild = SK.DBM:Guild()
	return {
		guild = guild, now = now or SK.Compat.Now(), index = SK.CraftIndex:Get(),
		profile = function(g) return SK.Profile:Get(g, guild) end,
		isMember = function(g) return SK.Identity:IsMember(g) end,
	}
end

-- Active members with a profile: fn(guid, member, profile).
local function eachProfile(ctx, fn)
	if not ctx.guild then return end
	for guid, m in pairs(ctx.guild.members) do
		if not m.leftAt and ctx.isMember(guid) then
			local p = ctx.profile(guid)
			if type(p) == "table" then fn(guid, m, p) end
		end
	end
end

local function statusOf(ctx, guid, m)
	return SK.Identity.Status(m, SK.DB.account[guid] and m.online, ctx.now)
end

-- Specialisation names for a profession entry (only IDs we know about).
function PB.SpecNames(prof)
	local out = {}
	if type(prof) ~= "table" or type(prof.specs) ~= "table" then return out end
	for _, id in ipairs(prof.specs) do
		local s = SK.Data.SPEC_BY_SPELL[id]
		if s then out[#out + 1] = s.name end
	end
	return out
end

function PB.ProfessionName(ctx, skillLine)
	if ctx.index then return SK.CraftIndex.ProfessionName(ctx.index, skillLine) end
	local d = SK.Data.PROFESSIONS[skillLine]
	return d and d.key or ("Profession " .. tostring(skillLine))
end

---------------------------------------------------------------------------
-- Guild coverage board
---------------------------------------------------------------------------
function PB.Coverage(ctx)
	local rows = {}
	local function row(skillLine)
		local r = rows[skillLine]
		if not r then
			r = { skillLine = skillLine, chars = 0, atMax = 0, online = 0, top = 0, lastScan = nil,
				specs = {}, group = SK.Data.ProfessionGroup(skillLine) }
			rows[skillLine] = r
		end
		return r
	end
	for skillLine in pairs(SK.Data.PROFESSIONS) do row(skillLine) end
	eachProfile(ctx, function(guid, m, p)
		for skillLine, prof in pairs(type(p.profs) == "table" and p.profs or {}) do
			if type(skillLine) == "number" and type(prof) == "table" then
				local r = row(skillLine)
				local rank = type(prof.rank) == "number" and prof.rank or 0
				r.chars = r.chars + 1
				if rank >= SK.Data.SKILL_CAP then r.atMax = r.atMax + 1 end
				if statusOf(ctx, guid, m) ~= "offline" then r.online = r.online + 1 end
				if rank > r.top then r.top = rank end
				if type(prof.scanned) == "number" and not (p.hidden and p.hidden.recipes)
					and (not r.lastScan or prof.scanned > r.lastScan) then
					r.lastScan = prof.scanned
				end
				for _, name in ipairs(PB.SpecNames(prof)) do r.specs[name] = (r.specs[name] or 0) + 1 end
				if type(prof.name) == "string" and not r.name then r.name = prof.name end
			end
		end
	end)
	local out = {}
	for _, r in pairs(rows) do
		r.name = (ctx.index and ctx.index.profNames[r.skillLine]) or r.name or PB.ProfessionName(ctx, r.skillLine)
		out[#out + 1] = r
	end
	table.sort(out, function(a, b)
		if a.group ~= b.group then return a.group < b.group end
		return a.name < b.name
	end)
	return out
end

-- "Gnomish Engineer 2, Goblin Engineer 1"
function PB.SpecText(specs)
	local names = {}
	for name in pairs(specs or {}) do names[#names + 1] = name end
	table.sort(names)
	for i, name in ipairs(names) do names[i] = name .. " " .. specs[name] end
	return table.concat(names, ", ")
end

---------------------------------------------------------------------------
-- One profession
---------------------------------------------------------------------------
function PB.Crafters(ctx, skillLine)
	local out = {}
	eachProfile(ctx, function(guid, _, p)
		local prof = type(p.profs) == "table" and p.profs[skillLine]
		if type(prof) == "table" then
			local info = SK.CraftIndex.CrafterInfo(ctx.index, ctx.guild, guid, skillLine, ctx.now)
			info.skill = type(prof.rank) == "number" and prof.rank or 0
			info.max = prof.max
			info.specs = PB.SpecNames(prof)
			info.hidden = p.hidden and p.hidden.recipes or nil
			info.scanned = (not info.hidden) and prof.scanned or nil
			info.fav = SK.Favourites.IsCrafter(guid)
			out[#out + 1] = info
		end
	end)
	return SK.CraftIndex.SortCrafters(out)
end

-- Is there anything in the window's recipe list that nobody in the guild
-- knows? Only possible when the game lists unlearned recipes.
function PB.Unknown(ctx, skillLine)
	local out = {}
	local uni = ctx.guild and ctx.guild.recipeUniverse and ctx.guild.recipeUniverse[skillLine]
	for recipeID, itemID in pairs(type(uni) == "table" and uni or {}) do
		if not ctx.index.recipes[recipeID] then
			out[#out + 1] = { recipeID = recipeID, itemID = type(itemID) == "number" and itemID or 0,
				skillLine = skillLine, crafters = {} }
		end
	end
	return out
end

-- filter: "all" | "one" (one crafter) | "fav" | "nobody"
-- Returns rows { recipeID, itemID, skillLine, name, count, fav, recipe }, loading.
function PB.Recipes(ctx, skillLine, filter)
	filter = filter or "all"
	local source = {}
	if filter == "nobody" then
		source = PB.Unknown(ctx, skillLine)
	else
		for _, r in pairs(ctx.index.recipes) do
			if r.skillLine == skillLine then source[#source + 1] = r end
		end
	end
	local out, loading = {}, 0
	for _, r in ipairs(source) do
		local fav = SK.Favourites.IsRecipe(r.recipeID)
		local count = #r.crafters
		if filter == "all" or filter == "nobody" or (filter == "one" and count == 1) or (filter == "fav" and fav) then
			local name = SK.CraftIndex.NameOf(r)
			if not name then loading = loading + 1 end
			out[#out + 1] = { recipeID = r.recipeID, itemID = r.itemID, skillLine = skillLine,
				name = name or "...", count = count, fav = fav, recipe = r }
		end
	end
	table.sort(out, function(a, b)
		if (a.name == "...") ~= (b.name == "...") then return b.name == "..." end
		if a.name ~= b.name then return a.name < b.name end
		return a.recipeID < b.recipeID
	end)
	return out, loading
end

---------------------------------------------------------------------------
-- Cooldown board (B4)
---------------------------------------------------------------------------
PB.COOLDOWN_STALE = 24 * 3600 -- "as of" older than this is shown in orange

-- When we last heard from this character: now for the one you're playing,
-- else when their copy arrived (or was last changed).
local function asOf(ctx, guid, p)
	if guid == SK.Compat.PlayerGUID() then return ctx.now end
	return (type(p.received) == "number" and p.received) or (type(p.updated) == "number" and p.updated) or nil
end

function PB.Cooldowns(ctx)
	local out = {}
	eachProfile(ctx, function(guid, m, p)
		if type(p.cds) ~= "table" or (p.hidden and p.hidden.recipes) then return end
		local status = statusOf(ctx, guid, m)
		local seen = asOf(ctx, guid, p)
		for recipeID, expires in pairs(p.cds) do
			if type(recipeID) == "number" and type(expires) == "number" then
				local left = math.max(0, expires - ctx.now)
				out[#out + 1] = {
					recipeID = recipeID, guid = guid, name = m.name or p.name or "?", class = m.class or p.class,
					status = status, left = left, ready = left == 0, asOf = seen,
					stale = seen == nil or ctx.now - seen > PB.COOLDOWN_STALE,
					whisper = status ~= "offline" and guid or nil,
				}
			end
		end
	end)
	table.sort(out, function(a, b)
		if a.ready ~= b.ready then return a.ready end
		if not a.ready and a.left ~= b.left then return a.left < b.left end
		if a.name ~= b.name then return a.name < b.name end
		return a.recipeID < b.recipeID
	end)
	return out
end

-- "Ready", "45m", "3h 20m", "2d 4h"
function PB.TimeLeft(seconds)
	if not seconds or seconds <= 0 then return "Ready" end
	local d, h, m = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60)
	if d > 0 then return d .. "d " .. h .. "h" end
	if h > 0 then return h .. "h " .. m .. "m" end
	return math.max(1, m) .. "m"
end
