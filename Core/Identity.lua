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
Identity.byFirst = {}        -- first word of each member's name -> true (loose-match candidates)
Identity.confirmed = {}      -- sender string -> guid, loose matches seen on the GUILD channel
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

-- Weaker check used when the exact formats differ (e.g. sender "Bob-Ruleset"
-- vs roster "Bob Smith"): the first word of both names must match.
local function firstWord(name)
	local n = normalise(name)
	return n and n:match("^([^%s%-]+)")
end

function Identity:Rebuild(entries)
	local byKey, byFirst = {}, {}
	for _, e in ipairs(entries) do
		local w = firstWord(e.name)
		if w then byFirst[w] = true end
		for _, k in ipairs(keysFor(e.name)) do
			if byKey[k] == nil then
				byKey[k] = e.guid
			elseif byKey[k] ~= e.guid then
				byKey[k] = false -- two members share this short form: ambiguous
			end
		end
	end
	self.byKey = byKey
	self.byFirst = byFirst
end

-- Returns the GUID of a guild member for a sender name, or nil.
function Identity:ResolveSender(sender)
	for _, k in ipairs(keysFor(sender)) do
		local guid = self.byKey[k]
		if guid then return guid end
	end
	return nil
end

function Identity:LooseMatch(guid, sender)
	local m = self:Member(guid)
	if not m then return false end
	local a, b = firstWord(m.name), firstWord(sender)
	return a ~= nil and a == b
end

-- Could this sender be a guild member at all? Cheap, checked before a
-- message is decoded so strangers can't make us decompress anything.
function Identity:KnownSender(sender)
	if self:ResolveSender(sender) then return true end
	local w = firstWord(sender)
	return w ~= nil and self.byFirst[w] == true
end

-- Resolve a message's sender to a member GUID. `claimed` is the GUID the
-- message says it is from; it is only trusted if the name agrees.
--
-- An exact roster match is safe on any channel: the game sets `sender`.
-- A loose (first word) match is weaker, because first names aren't unique:
-- a stranger called "Bob Jones" could whisper us claiming to be our "Bob
-- Smith". Only guild members can send on the GUILD channel, so a loose
-- match is accepted there and remembered; a whisper is accepted only from a
-- sender already confirmed that way this session.
function Identity:SenderGUID(sender, claimed, dist)
	local guid = self:ResolveSender(sender)
	if guid then
		if claimed and claimed ~= guid then return nil, "guid mismatch" end
		return guid
	end
	if not (claimed and self:IsMember(claimed) and self:LooseMatch(claimed, sender)) then
		return nil, "unknown sender"
	end
	local seen = self.confirmed[sender]
	if seen and seen ~= claimed then return nil, "guid mismatch" end
	if dist == "GUILD" then
		self.confirmed[sender] = claimed
		return claimed
	end
	if seen == claimed then return claimed end
	return nil, "unconfirmed sender"
end

Identity.ADDON_FRESH = 25 * 60 -- a HI arrives every 10 min; allow two misses

-- "addon" = online with Short Kings, "online" = online without it, "offline".
function Identity.Status(m, isSelf, now)
	if not m or not m.online then return "offline" end
	if isSelf or (m.addonSeen and now - m.addonSeen < Identity.ADDON_FRESH) then return "addon" end
	return "online"
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
		m.note = e.note
		m.officerNote = e.officerNote -- only present when the game lets us read it
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

-- Live-client check: is a character's GUID the same every login? Pure; tested.
function Identity.NoteLogin(seen, name, guid, now)
	if not name or not guid then return nil end
	local e = seen[name]
	if not e then
		e = { guid = guid, first = now, logins = 0 }
		seen[name] = e
	elseif e.guid ~= guid then
		e.changedFrom, e.guid, e.logins = e.guid, guid, 0
	end
	e.logins = e.logins + 1
	return e
end

-- The logged-in character's name as used for that check.
function Identity.LoginKey()
	local name, realm = Compat.PlayerFullName()
	if not name then return nil end
	return (realm and realm ~= "") and (name .. "-" .. realm) or name
end

function Identity:OnLogin()
	Identity.NoteLogin(SK.DB.seenGuids, Identity.LoginKey(), Compat.PlayerGUID(), Compat.Now())
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
