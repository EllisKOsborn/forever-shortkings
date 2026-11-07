-- Overview: the numbers behind the Overview tab, from data we already hold
-- (roster, shared profiles, our own full profiles, the craft index). No new
-- collection and no sync change. Pure apart from reading SK state; tested.
local _, SK = ...

local Overview = {}
SK.Overview = Overview

Overview.STALE_AFTER = 7 * 86400
Overview.LEVEL_BANDS = { { 60, 60, "60" }, { 50, 59, "50-59" }, { 40, 49, "40-49" }, { 1, 39, "1-39" } }
-- Crafting professions shown on the Professions card, in this order.
Overview.CRAFTS = { 171, 164, 333, 202, 165, 197, 185, 129 }
Overview.GATHERING = { 182, 186, 393, 356 }

local function newer(a, b) return SK.Sync and SK.Sync.versionNewer(a, b) end

function Overview.Build(guild, now)
	now = now or SK.Compat.Now()
	local o = {
		members = 0, online = 0, withAddon = 0, withData = 0, players = 0,
		hasAddon = 0, without = {}, addonNoData = 0, altsOf = {},
		levels = {}, maxLevel = 0,
		stale = 0, noData = 0, unscanned = 0, outdated = 0, newest = nil, selfOutdated = false,
		profs = {}, raids = {}, recipes = { total = 0, crafters = 0, single = 0, singleExamples = {} },
	}
	for i in ipairs(Overview.LEVEL_BANDS) do o.levels[i] = 0 end
	if not guild then return o end

	local active, profiles = {}, {}
	for guid, m in pairs(guild.members) do
		if not m.leftAt then
			active[#active + 1] = guid
			local p = SK.Profile:Get(guid, guild)
			if p then profiles[guid] = p end
			if (m.level or 0) > o.maxLevel then o.maxLevel = m.level end
		end
	end
	table.sort(active)
	o.members = #active

	-- Newest addon version seen (for "needs an update").
	o.newest = SK.VERSION ~= "dev" and SK.VERSION or nil
	for _, guid in ipairs(active) do
		local v = guild.members[guid].addon
		if v and (not o.newest or newer(v, o.newest)) then o.newest = v end
	end
	o.selfOutdated = o.newest ~= nil and SK.VERSION ~= "dev" and newer(o.newest, SK.VERSION) or false

	-- Distinct players (mutually linked alts count once).
	local shared = {}
	for _, guid in ipairs(active) do shared[guid] = guild.profiles[guid] end
	local groupOf = SK.Alts.Groups(shared, function(g) return shared[g] ~= nil end)
	local seenGroup = {}
	for _, guid in ipairs(active) do
		local g = groupOf[guid]
		if not g then o.players = o.players + 1
		elseif not seenGroup[g] then seenGroup[g] = true; o.players = o.players + 1 end
	end

	for _, id in ipairs(Overview.CRAFTS) do o.profs[id] = { count = 0, maxed = 0, best = 0 } end
	for _, id in ipairs(Overview.GATHERING) do o.profs[id] = { count = 0, maxed = 0, best = 0 } end

	for _, guid in ipairs(active) do
		local m, p = guild.members[guid], profiles[guid]
		local mine = SK.DB.account[guid] and true or false
		if m.online then o.online = o.online + 1 end
		if SK.Identity.Status(m, mine and m.online, now) == "addon" then o.withAddon = o.withAddon + 1 end
		local lvl = m.level or (p and p.level) or 0
		for i, b in ipairs(Overview.LEVEL_BANDS) do
			if lvl >= b[1] and lvl <= b[2] then o.levels[i] = o.levels[i] + 1 end
		end
		if SK.Identity.HasAddon(guid, m, p) then
			o.hasAddon = o.hasAddon + 1
			if not p then o.addonNoData = o.addonNoData + 1 end
		else
			o.without[#o.without + 1] = { guid = guid, name = m.name or "?", class = m.class, level = m.level or 0,
				online = m.online and true or false }
		end
		if not p then
			o.noData = o.noData + 1
		else
			o.withData = o.withData + 1
			if not mine and p.updated and now - p.updated > Overview.STALE_AFTER then o.stale = o.stale + 1 end
			if not (p.hidden and p.hidden.recipes) and #SK.Professions.Unscanned(p) > 0 then
				o.unscanned = o.unscanned + 1
			end
			for id, pr in pairs(p.profs or {}) do
				local s = o.profs[id]
				if s then
					s.count = s.count + 1
					local rank = pr.rank or 0
					if rank > s.best then s.best = rank end
					if rank >= 300 then s.maxed = s.maxed + 1 end
				end
			end
		end
		local v = mine and SK.VERSION or m.addon
		if (v and o.newest and v ~= "dev" and newer(o.newest, v)) or (not v and m.oldAddon) then
			o.outdated = o.outdated + 1
		end
	end

	-- v0.3.6: characters without the addon that are alts of someone who has
	-- it (same Battle.net account, "This is my alt", or a guild note) move to
	-- their own list.
	local links = SK.Accounts.Current(guild, now)
	local still = {}
	for _, w in ipairs(o.without) do
		local l = links[w.guid]
		if l then
			local owner = guild.members[l.owner]
			w.owner, w.ownerName, w.ownerClass, w.how = l.owner, owner and owner.name or "?", owner and owner.class, l.how
			o.altsOf[#o.altsOf + 1] = w
		else
			still[#still + 1] = w
		end
	end
	o.without = still
	-- v0.4.0 (simpler Overview): a known alt of someone with the addon counts
	-- as "has it", so Have + Not seen = Members.
	o.hasAddon = o.hasAddon + #o.altsOf
	table.sort(o.altsOf, function(a, b)
		if a.ownerName ~= b.ownerName then return a.ownerName:lower() < b.ownerName:lower() end
		return a.name:lower() < b.name:lower()
	end)

	-- Members without the addon: online first (you can ask them now), then by name.
	table.sort(o.without, function(a, b)
		if a.online ~= b.online then return a.online end
		return a.name:lower() < b.name:lower()
	end)

	-- Raids of the first wave: attunement among max-level characters.
	for _, raid in ipairs(SK.Data.ShownAttunements()) do
		local r = { key = raid.key, name = raid.name, size = raid.size, status = raid.status,
			yes = 0, no = 0, unknown = 0, none = 0, noItem = 0, eligible = 0 }
		for _, guid in ipairs(active) do
			local m = guild.members[guid]
			if (m.level or 0) >= o.maxLevel and o.maxLevel > 0 then
				r.eligible = r.eligible + 1
				local state, note = SK.Attunements.StateOf(profiles[guid], raid)
				r[state] = r[state] + 1
				if note then r.noItem = r.noItem + 1 end
			end
		end
		o.raids[#o.raids + 1] = r
	end
	o.raidsOpenAt = SK.Data.RAIDS_OPEN_AT
	o.raidDays = SK.Data.RAIDS_OPEN_AT and math.ceil((SK.Data.RAIDS_OPEN_AT - now) / 86400) or nil

	-- Recipes: totals and recipes only one character knows.
	local index = SK.CraftIndex:Get(true)
	o.recipes.total, o.recipes.crafters = index.recipeCount, index.crafterCount
	local singles = {}
	for id, r in pairs(index.recipes) do
		if #r.crafters == 1 then singles[#singles + 1] = id end
	end
	table.sort(singles)
	o.recipes.single = #singles
	for _, id in ipairs(singles) do
		if #o.recipes.singleExamples >= 3 then break end
		local name = SK.CraftIndex.NameOf(index.recipes[id])
		if name then o.recipes.singleExamples[#o.recipes.singleExamples + 1] = name end
	end
	return o
end
