-- Profile: assembles the logged-in character's profile, stores it in the
-- guild bucket, and fires SELF_UPDATED when its content actually changes.
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

function Profile:Own()
	local guild = SK.DBM:Guild()
	local guid = Compat.PlayerGUID()
	return guild and guid and guild.profiles[guid]
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

-- Store `p` as our own profile; bump `updated` only if content changed.
function Profile:Commit(guild, p, now)
	local old = guild.profiles[p.guid]
	p.v = Profile.VERSION
	p.source = "self"
	p.hash = Profile.HashOf(p)
	local changed = not old or old.hash ~= p.hash
	p.updated = changed and now or old.updated
	guild.profiles[p.guid] = p
	if changed then SK:Fire("SELF_UPDATED", p.guid) end
	return changed
end

function Profile:BuildSelf()
	local guild = SK.DBM:Guild()
	local guid = Compat.PlayerGUID()
	if not guild or not guid then return false end
	SK.DB.account[guid] = true
	local now = Compat.Now()
	local old = guild.profiles[guid] or {}
	local member = guild.members[guid]

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
		recipes = {},
		cds = {},
	}
	-- Keep scan results for professions the character still has.
	for skillLine, prof in pairs(p.profs) do
		local oldProf = old.profs and old.profs[skillLine]
		if oldProf and oldProf.scanned then prof.scanned = oldProf.scanned end
		if old.recipes and old.recipes[skillLine] then p.recipes[skillLine] = old.recipes[skillLine] end
	end
	-- Keep cooldowns that have not expired yet.
	for id, expires in pairs(old.cds or {}) do
		if expires > now then p.cds[id] = expires end
	end
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
	for id, expires in pairs(scan.cds) do p.cds[id] = expires end
	-- Grow the guild-wide list of recipes that exist (learned or not).
	local uni = guild.recipeUniverse[skillLine] or {}
	for id, itemID in pairs(scan.universe) do
		if uni[id] == nil or uni[id] == 0 then uni[id] = itemID end
	end
	guild.recipeUniverse[skillLine] = uni
	self:Commit(guild, p, scan.at)
end

function Profile:OnLogin()
	local dirty = false
	local function rebuild()
		if Compat.InCombat() then dirty = true; return end
		dirty = false
		local ok, err = pcall(Profile.BuildSelf, Profile)
		if not ok then SK:Debug("profile build failed: %s", tostring(err)) end
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
