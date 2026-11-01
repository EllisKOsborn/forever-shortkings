-- SavedVariables (ShortKingsDB, account-wide): schema, defaults, pruning.
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
	},
	own = {},             -- [guid] = full profile of our own characters (never sent)
	cooldownSpells = {},  -- [guid] = { [recipeID] = true } recipes with cooldowns
	account = {},  -- [guid] = true for characters seen on this account
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
		SK:Print("Your saved data is from a newer version of Short Kings. Please update the addon.")
	end
	SK.ApplyDefaults(saved, DEFAULTS)
	migrate(saved)
	SK.DB = saved
	return saved
end

function DBM:OnInit()
	ShortKingsDB = self:Load(ShortKingsDB)
end

function DBM.GuildKey(guildName, realm)
	if not guildName then return nil end
	if realm and realm ~= "" then return guildName .. "-" .. realm end
	return guildName
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
