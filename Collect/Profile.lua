-- Profile: assembles the logged-in character's profile.
--
-- Two copies are kept for each of our own characters:
--   SK.DB.own[guid]            the FULL profile (only on this computer)
--   guild.profiles[guid]       the PUBLIC copy that is shared, with gear or
--                              recipes left out if the player turned sharing off
-- SELF_UPDATED fires when the full profile's content actually changes.
local _, SK = ...

local Profile = SK:NewModule("Profile")
local Compat = SK.Compat

Profile.VERSION = 1

-- Fields that are bookkeeping, not content: excluded from the hash.
local NOT_HASHED = { updated = true, hash = true, source = true, received = true }

function Profile.HashOf(p)
	local copy = {}
	for k, v in pairs(p) do
		if not NOT_HASHED[k] then copy[k] = v end
	end
	return SK.Codec.Hash(copy)
end

-- Our own full profile (this character, or another of ours by guid).
function Profile:Own(guid)
	guid = guid or Compat.PlayerGUID()
	return guid and SK.DB.own[guid]
end

-- The best copy to DISPLAY for a character: full for our own, else shared.
function Profile:Get(guid, guild)
	if not guid then return nil end
	if SK.DB.account[guid] and SK.DB.own[guid] then return SK.DB.own[guid] end
	guild = guild or SK.DBM:Guild()
	return guild and guild.profiles[guid]
end

-- Strip what the player chose not to share. Pure; tested.
function Profile.Public(p, share)
	local pub = SK.CopyTable(p)
	local hidden = {}
	if share and share.gear == false then
		pub.gear, pub.ilvl, pub.talents = nil, nil, nil
		hidden.gear = true
	end
	if share and share.recipes == false then
		pub.recipes, pub.cds = nil, nil
		hidden.recipes = true
	end
	pub.hidden = next(hidden) and hidden or nil
	return pub
end

-- What guildmates receive, for the Settings "sharing preview". Built from
-- the actual public copy (Profile.Public), so it can't drift from what is
-- sent. Returns { { label, shared = bool }, ... }. Pure; tested.
local SHARING = {
	{ "Name, class, race, level and addon version", function(p) return p.name ~= nil or p.class ~= nil end },
	{ "Gear and item level", function(p) return p.gear ~= nil end },
	{ "Talents", function(p) return p.talents ~= nil end },
	{ "Profession skill levels", function(p) return p.profs ~= nil end },
	{ "Recipes", function(p) return p.recipes ~= nil end },
	{ "Profession cooldowns", function(p) return p.cds ~= nil end },
	{ "Reputations", function(p) return p.reps ~= nil end },
	{ "Raid attunements (and whether the Drakefire Amulet is in your bags)", function(p) return p.att ~= nil end },
	{ "Which characters are yours, and your main", function(p) return p.family ~= nil end },
}
Profile.NEVER_SHARED = "Notes and officer notes, gold, bag and bank contents (except the amulet yes/no), chat, location"

function Profile.SharingSummary(full, share)
	local pub = Profile.Public(full or {}, share)
	local out = {}
	for _, c in ipairs(SHARING) do out[#out + 1] = { label = c[1], shared = c[2](pub) and true or false } end
	return out
end

-- Other characters of this account that are in the same guild.
local function familyOf(guild, guid)
	local fam = {}
	for g in pairs(SK.DB.account) do
		if g ~= guid and guild.members[g] then fam[#fam + 1] = g end
	end
	table.sort(fam)
	return fam
end

-- Store `p` as our own profile (full + public copy). `updated` only moves
-- when content changed.
function Profile:Commit(guild, p, now)
	local oldFull = SK.DB.own[p.guid]
	p.v = Profile.VERSION
	p.source = "self"
	p.hash = Profile.HashOf(p)
	local changed = not oldFull or oldFull.hash ~= p.hash
	p.updated = changed and now or oldFull.updated
	SK.DB.own[p.guid] = p
	if changed and oldFull then SK.Feed:Note(p.guid, oldFull, p, now) end

	local pub = Profile.Public(p, SK.DB.settings.share)
	pub.hash = Profile.HashOf(pub)
	local oldPub = guild.profiles[p.guid]
	local pubChanged = not oldPub or oldPub.hash ~= pub.hash
	pub.updated = pubChanged and now or oldPub.updated
	guild.profiles[p.guid] = pub

	-- Either copy changing matters: privacy toggles change only the public one.
	if changed or pubChanged then SK:Fire("SELF_UPDATED", p.guid) end
	return changed or pubChanged
end

-- Recipes that have a cooldown (learned from scans), per character.
local function cooldownSpells(guid)
	SK.DB.cooldownSpells[guid] = SK.DB.cooldownSpells[guid] or {}
	return SK.DB.cooldownSpells[guid]
end

-- Refresh cooldowns from the spell API, so they are right even when the
-- profession window has not been opened this session.
local function refreshCooldowns(guid, cds, now)
	for id in pairs(cooldownSpells(guid)) do
		local left = Compat.SpellCooldownRemaining(id)
		if left then cds[id] = now + math.floor(left) end
	end
end

-- "This is my alt" marks as a sorted list for the profile (v0.3.6): only
-- current members that aren't our own logged-in characters. Pure; tested.
function Profile.Claims(myAlts, guild)
	local out = {}
	for guid in pairs(type(myAlts) == "table" and myAlts or {}) do
		local m = guild and guild.members[guid]
		if m and not m.leftAt and not SK.DB.account[guid] then out[#out + 1] = guid end
	end
	table.sort(out)
	while #out > SK.Merge.LIMITS.family do table.remove(out) end
	return #out > 0 and out or nil
end

-- Raid roles for the profile (v0.4.0): only valid values, nil if none.
local VALID_ROLE = { TANK = true, HEALER = true, DPS = true }
function Profile.Roles(r)
	if type(r) ~= "table" or not VALID_ROLE[r.main] then return nil end
	return { main = r.main, second = (VALID_ROLE[r.second] and r.second ~= r.main) and r.second or nil }
end

-- Set this character's raid roles (main may be nil to clear both).
function Profile:SetRoles(main, second)
	local guid = Compat.PlayerGUID()
	if not guid then return end
	SK.DB.roles[guid] = main and { main = main, second = second } or nil
	self:BuildSelf()
end

function Profile:ToggleMyAlt(guid)
	if not guid or SK.DB.account[guid] then return end
	SK.DB.myAlts[guid] = (not SK.DB.myAlts[guid]) or nil
	self:BuildSelf() -- fires SELF_UPDATED, which announces the change
end

function Profile:BuildSelf()
	local guild = SK.DBM:Guild()
	local guid = Compat.PlayerGUID()
	if not guild or not guid then return false end
	SK.DB.account[guid] = true
	local now = Compat.Now()
	local old = SK.DB.own[guid] or {}
	local member = guild.members[guid]
	local main = SK.DB.settings.main

	local c = SK.Character.Read()
	local p = {
		guid = guid,
		name = (member and member.name) or c.name,
		realm = c.realm,
		class = c.class, race = c.race, level = c.level, faction = c.faction,
		addon = SK.VERSION,
		gear = c.gear, ilvl = c.ilvl,
		talents = SK.Talents.Read() or old.talents,
		profs = SK.Professions.ReadSkills(),
		reps = SK.Reputation.Read(),
		att = SK.Attunements.Read(),
		family = familyOf(guild, guid),
		claims = Profile.Claims(SK.DB.myAlts, guild),
		roles = Profile.Roles(SK.DB.roles[guid]),
		main = (main and SK.DB.account[main] and guild.members[main]) and main or nil,
		recipes = {},
		cds = {},
	}
	-- Keep scan results for professions the character still has.
	for skillLine, prof in pairs(p.profs) do
		local oldProf = old.profs and old.profs[skillLine]
		if oldProf and oldProf.scanned then prof.scanned = oldProf.scanned end
		if old.recipes and old.recipes[skillLine] then p.recipes[skillLine] = old.recipes[skillLine] end
	end
	-- Keep cooldowns: tracked cooldown recipes always (shown as "ready"
	-- once expired), anything else only until it expires.
	local tracked = cooldownSpells(guid)
	for id, expires in pairs(old.cds or {}) do
		if tracked[id] or expires > now then p.cds[id] = expires end
	end
	refreshCooldowns(guid, p.cds, now)
	return self:Commit(guild, p, now)
end

-- Called by Professions after a recipe scan.
function Profile:SetScan(skillLine, scan)
	local guild = SK.DBM:Guild()
	if guild and not self:Own() then self:BuildSelf() end
	local own = self:Own()
	if not guild or not own then return end
	local p = SK.CopyTable(own)
	p.profs = p.profs or {}
	local prof = p.profs[skillLine] or { name = scan.name }
	prof.rank = (scan.rank and scan.rank > 0) and scan.rank or prof.rank
	prof.max = (scan.max and scan.max > 0) and scan.max or prof.max
	prof.scanned = scan.at
	p.profs[skillLine] = prof
	p.recipes = p.recipes or {}
	p.recipes[skillLine] = scan.learned
	p.cds = p.cds or {}
	local tracked = cooldownSpells(p.guid)
	for id, expires in pairs(scan.cds) do
		p.cds[id] = expires
		tracked[id] = true
	end
	-- A tracked cooldown recipe with no cooldown in this scan is ready.
	for id in pairs(tracked) do
		if scan.learned[id] and not scan.cds[id] then p.cds[id] = scan.at end
	end
	-- Grow the guild-wide list of recipes that exist (learned or not).
	local uni = guild.recipeUniverse[skillLine] or {}
	for id, itemID in pairs(scan.universe) do
		if uni[id] == nil or uni[id] == 0 then uni[id] = itemID end
	end
	guild.recipeUniverse[skillLine] = uni
	self:Commit(guild, p, scan.at)
end

-- Mark one of our characters as the main (shown first when alts are grouped).
function Profile:SetMain(guid)
	SK.DB.settings.main = guid
	self:BuildSelf()
end

function Profile:OnLogin()
	local dirty = false
	local function rebuild()
		if Compat.InCombat() then dirty = true; return end
		dirty = false
		local ok, err = pcall(Profile.BuildSelf, Profile)
		if not ok then SK:RecordError("profile build", err) end
	end
	local function queue() SK:Debounce("buildself", 5, rebuild) end
	for _, ev in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED",
		"ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
		"SKILL_LINES_CHANGED", "UPDATE_FACTION", "QUEST_TURNED_IN", "PLAYER_AVG_ITEM_LEVEL_UPDATE" }) do
		SK:RegisterEvent(ev, queue)
	end
	SK:RegisterEvent("PLAYER_REGEN_ENABLED", function() if dirty then queue() end end)
	-- The first build waits for the guild roster (we need the guild name);
	-- later roster reads keep our display name and family list current.
	SK:On("ROSTER_UPDATED", function()
		if Profile:Own() then queue() else rebuild() end
	end)
	SK.After(8, queue)
end
