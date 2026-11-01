-- Identity: who is in the guild, and which character sent a message.
--
-- Forever has no realms and uses two-part names (first name + surname), so
-- characters are keyed by player GUID. The exact `sender` format in
-- CHAT_MSG_ADDON is not documented for Forever, so a sender is matched
-- against the roster in several forms (exact, without "-Realm", lower case).
local _, SK = ...

local Identity = SK:NewModule("Identity")
local Compat = SK.Compat

Identity.loaded = false      -- true after the first complete roster read
Identity.byKey = {}          -- normalised name -> guid (or false if ambiguous)
Identity.lastSender = {}     -- guid -> sender string exactly as received (for whispers)
Identity.rosterSource = "none"
Identity.rosterSample = nil  -- first raw roster name, for /sk debug

local function normalise(name)
	if type(name) ~= "string" then return nil end
	return (name:gsub("%s+$", ""):gsub("^%s+", "")):lower()
end

-- All the keys a name may be looked up by.
local function keysFor(name)
	local keys = {}
	local n = normalise(name)
	if not n then return keys end
	keys[#keys + 1] = n
	local base = n:match("^(.-)%-[^%-]+$")
	if base and base ~= "" then keys[#keys + 1] = base end
	return keys
end
Identity.keysFor = keysFor

function Identity:Rebuild(entries)
	local byKey = {}
	for _, e in ipairs(entries) do
		for _, k in ipairs(keysFor(e.name)) do
			if byKey[k] == nil then
				byKey[k] = e.guid
			elseif byKey[k] ~= e.guid then
				byKey[k] = false -- two members share this short form: ambiguous
			end
		end
	end
	self.byKey = byKey
end

-- Returns the GUID of a guild member for a sender name, or nil.
function Identity:ResolveSender(sender)
	for _, k in ipairs(keysFor(sender)) do
		local guid = self.byKey[k]
		if guid then return guid end
	end
	return nil
end

-- Weaker check used when the exact formats differ (e.g. sender "Bob-Ruleset"
-- vs roster "Bob Smith"): the first word of both names must match.
local function firstWord(name)
	local n = normalise(name)
	return n and n:match("^([^%s%-]+)")
end

function Identity:LooseMatch(guid, sender)
	local m = self:Member(guid)
	if not m then return false end
	local a, b = firstWord(m.name), firstWord(sender)
	return a ~= nil and a == b
end

-- Resolve a message's sender to a member GUID. `claimed` is the GUID the
-- message says it is from; it is only trusted if the name agrees.
function Identity:SenderGUID(sender, claimed)
	local guid = self:ResolveSender(sender)
	if guid then
		if claimed and claimed ~= guid then return nil, "guid mismatch" end
		return guid
	end
	if claimed and self:IsMember(claimed) and self:LooseMatch(claimed, sender) then
		return claimed
	end
	return nil, "unknown sender"
end

function Identity:IsMember(guid)
	local g = SK.DBM:Guild()
	local m = g and guid and g.members[guid]
	return m ~= nil and m.leftAt == nil
end

function Identity:Member(guid)
	local g = SK.DBM:Guild()
	return g and g.members[guid]
end

-- Name to whisper a member: the last sender string we saw from them works
-- best; otherwise the roster name.
function Identity:WhisperTarget(guid)
	if self.lastSender[guid] then return self.lastSender[guid] end
	local m = self:Member(guid)
	return m and m.name
end

function Identity:NoteSender(guid, sender)
	if guid and sender then self.lastSender[guid] = sender end
end

---------------------------------------------------------------------------
-- Roster reading
---------------------------------------------------------------------------
function Identity:UpdateGuildKey()
	local guildName, _, _, realm = Compat.GuildInfo()
	if guildName then
		SK.guildKey = SK.DBM.GuildKey(guildName, realm)
		SK.guildName = guildName
	elseif not Compat.IsInGuild() then
		SK.guildKey, SK.guildName = nil, nil
	end
	return SK.guildKey
end

-- Merge a roster read into the saved member list. Pure enough to test.
function Identity:ApplyRoster(entries, complete, now)
	local guild = SK.DBM:Guild()
	if not guild then return end
	local present = {}
	for _, e in ipairs(entries) do
		present[e.guid] = true
		local m = guild.members[e.guid]
		if not m then
			m = {}
			guild.members[e.guid] = m
		end
		m.name, m.class, m.level = e.name, e.class or m.class, e.level or m.level
		m.rank, m.rankIndex = e.rank or m.rank, e.rankIndex or m.rankIndex
		m.online = e.online
		if e.online then
			m.lastSeen = now
		elseif e.lastOnlineHours then
			local seen = now - e.lastOnlineHours * 3600
			if not m.lastSeen or seen > m.lastSeen then m.lastSeen = seen end
		end
	end
	self:Rebuild(entries)

	-- Only mark people as "left" when the read looks complete and sane
	-- (a half-loaded roster must never start the 30-day prune clock).
	local previous = SK.Count(guild.members)
	if complete and #entries > 0 and #entries >= previous * 0.5 then
		SK.DBM.ApplyRosterPresence(guild, present, now)
		self.loaded = true
	elseif #entries > 0 then
		self.loaded = true
	end
	SK:Fire("ROSTER_UPDATED")
end

function Identity:ReadRoster()
	if not self:UpdateGuildKey() then return end
	local entries, complete, source = Compat.ReadRoster()
	self.rosterSource = source
	self.rosterSample = entries[1] and entries[1].name or nil
	if #entries == 0 then return end
	self:ApplyRoster(entries, complete, Compat.Now())
	SK:Debug("roster: %d members (%s, complete=%s)", #entries, source, tostring(complete))
end

function Identity:OnLogin()
	SK:RegisterEvent("GUILD_ROSTER_UPDATE", function()
		SK:Debounce("roster", 2, function() Identity:ReadRoster() end)
	end)
	SK:RegisterEvent("PLAYER_GUILD_UPDATE", function()
		Identity:UpdateGuildKey()
		Compat.RequestRoster()
	end)
	Compat.RequestRoster()
	-- The roster is server-throttled; refresh it every 2 minutes.
	SK.NewTicker(120, function() Compat.RequestRoster() end)
end
