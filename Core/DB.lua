-- SavedVariables (ShortRoyaltyDB, account-wide): schema, defaults, pruning.
local _, SK = ...

local DBM = SK:NewModule("DBM")

DBM.PRUNE_AFTER = 30 * 24 * 3600 -- delete members who left more than 30 days ago

local DEFAULTS = {
	schema = SK.SCHEMA,
	settings = {
		sync = true,
		debug = false,
		minimap = { hide = false, minimapPos = 210 },
		window = { point = "CENTER", x = 0, y = 0, scale = 1 },
		share = { gear = true, recipes = true }, -- privacy toggles (A7)
		groupAlts = true,                         -- Roster: alts under their main
		main = nil,                               -- guid of the player's main
		roster = { raid = nil, attFilter = "all", maxLevelOnly = true }, -- Raid filter (v0.1.2)
		craftTooltips = true,                     -- "Crafted by" lines on item tooltips (v0.2)
		feed = true,                              -- record guild milestones for the Overview (v0.2.2)
		reduceMotion = false,                     -- turn off UI animation (v0.2.3 design refresh)
		profNudges = true,                        -- "open your Tailoring window" reminders (v0.3)
		profView = "board",                       -- Professions tab: "board", "recipes" or "cooldowns" (v0.3)
		welcomed = false,                         -- first-load welcome line shown (v0.3.1)
		seen = {},                                -- tabs looked at, for "Getting started" (v0.3.1)
		onboarding = { hidden = false },          -- "Getting started" card hidden by the player (v0.3.1)
	},
	own = {},             -- [guid] = full profile of our own characters (never sent)
	cooldownSpells = {},  -- [guid] = { [recipeID] = true } recipes with cooldowns
	account = {},  -- [guid] = true for characters seen on this account
	seenGuids = {}, -- [name] = { guid, first, logins, changedFrom } (GUID stability check for /sr debug)
	feed = {},      -- recent milestones, newest first, max 50 (local only, never sent)
	favourites = { recipes = {}, crafters = {} }, -- starred recipes and crafters (v0.3, local only)
	reagents = { build = nil, list = {} },        -- recipe reagents read from the game (v0.3, local only)
	scanRank = {},  -- [guid] = { [skillLine] = skill when the recipes were last scanned } (nudges, local)
	nudgedAt = nil, -- last "open your profession window" chat reminder
	guilds = {},
}

local function migrate(db)
	-- schema 1 is the first version; future migrations go here, e.g.
	-- if db.schema < 2 then ... db.schema = 2 end
	db.schema = SK.SCHEMA
end

-- Separate from OnInit so tests can call it with a fresh table.
function DBM:Load(saved)
	saved = type(saved) == "table" and saved or {}
	if saved.schema and saved.schema > SK.SCHEMA then
		SK:Print("Your saved data is from a newer version of Short Royalty. Please update the addon.")
	end
	SK.ApplyDefaults(saved, DEFAULTS)
	migrate(saved)
	SK.DB = saved
	return saved
end

function DBM:OnInit()
	ShortRoyaltyDB = self:Load(ShortRoyaltyDB)
end

function DBM.GuildKey(guildName, realm)
	if not guildName then return nil end
	if realm and realm ~= "" then return guildName .. "-" .. realm end
	return guildName
end

-- A guild rename (e.g. "Sweaty Pumpers" -> "Short Royalty", 7 Nov 2026)
-- changes the key that guild data is stored under. When the roster arrives
-- under a key we have no data for yet, adopt the old bucket whose current
-- members are mostly in this roster, so nobody's data starts from empty.
-- Pure apart from SK.DB; tested. Returns the old key if it moved one.
function DBM.AdoptRenamedGuild(newKey, rosterGUIDs)
	local guilds = SK.DB.guilds
	local existing = guilds[newKey]
	if existing and next(existing.members or {}) then return nil end
	local inRoster, rosterSize = {}, 0
	for _, guid in ipairs(rosterGUIDs) do
		inRoster[guid] = true
		rosterSize = rosterSize + 1
	end
	if rosterSize == 0 then return nil end
	local bestKey, bestShared = nil, 0
	for key, g in pairs(guilds) do
		if key ~= newKey then
			local active, shared = 0, 0
			for guid, m in pairs(g.members or {}) do
				if not m.leftAt then
					active = active + 1
					if inRoster[guid] then shared = shared + 1 end
				end
			end
			-- Most of the old guild is here, and it's not a tiny coincidence.
			if active > 0 and shared >= active * 0.5 and shared >= math.min(3, rosterSize)
				and shared > bestShared then
				bestKey, bestShared = key, shared
			end
		end
	end
	if not bestKey then return nil end
	local g = guilds[bestKey]
	g.renamedFrom = bestKey
	guilds[newKey] = g
	guilds[bestKey] = nil
	return bestKey
end

-- Guild bucket, created on demand.
function DBM:Guild(key)
	key = key or SK.guildKey
	if not key then return nil end
	local g = SK.DB.guilds[key]
	if not g then
		g = { members = {}, profiles = {}, recipeUniverse = {} }
		SK.DB.guilds[key] = g
	end
	return g
end

-- Called after a full roster read. `present` = { [guid] = true }.
-- Members missing from the roster get leftAt; after 30 days they and
-- their profiles are deleted. Rejoining clears leftAt.
function DBM.ApplyRosterPresence(guild, present, now)
	local removed = 0
	for guid, m in pairs(guild.members) do
		if present[guid] then
			m.leftAt = nil
		else
			m.leftAt = m.leftAt or now
			if now - m.leftAt > DBM.PRUNE_AFTER then
				guild.members[guid] = nil
				guild.profiles[guid] = nil
				removed = removed + 1
			end
		end
	end
	-- Profiles for characters we never saw in the roster are dropped too.
	for guid in pairs(guild.profiles) do
		if not guild.members[guid] then
			guild.profiles[guid] = nil
			removed = removed + 1
		end
	end
	return removed
end
