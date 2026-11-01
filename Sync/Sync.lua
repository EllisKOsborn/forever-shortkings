-- Sync: hash-then-fetch over the guild addon channel.
--
--   HI  GUILD    my account's characters {g = guid, u = updated, h = hash}
--   RQ  WHISPER  "please send me these profiles" { w = {guid, ...} }
--   PR  WHISPER  one profile { prof = Profile }
--   SQ  GUILD    once per session: { k = {[guid] = updated} } for what I hold
--   SO  GUILD    "I have newer copies for <to>" { to = guid, g = {guid, ...} }
--                (sent after a random delay; others cancel theirs on seeing it)
--
-- Sending pauses in combat, in instances, during chat lockdown and when
-- sync is turned off; messages wait in a queue. Incoming messages received
-- while paused are buffered and handled later.
local _, SK = ...

local Sync = SK:NewModule("Sync")
local Compat = SK.Compat

Sync.HELLO_INTERVAL = 600      -- seconds between HI broadcasts
Sync.HELLO_DEBOUNCE = 60       -- after own data changes
Sync.QUERY_DELAY = 60          -- SQ this long after the first HI
Sync.OFFER_DELAY_MIN = 2
Sync.OFFER_DELAY_MAX = 8
Sync.MAX_WANT = 60             -- profiles per RQ / SO
Sync.MAX_BUFFER = 200          -- buffered incoming messages
Sync.SENDS_PER_FLUSH = 4
Sync.MAX_TRIES = 5

Sync.queue = {}
Sync.queued = {}               -- key -> queue item
Sync.buffer = {}
Sync.pendingOffers = {}        -- requester guid -> true while our SO waits
Sync.offerAcceptedAt = nil
Sync.stats = { sent = 0, received = 0, dropped = 0, accepted = 0, rejected = 0 }
Sync.lastReject = nil
Sync.lastSender = nil          -- raw sender string of the last message (debug)

local LOCKDOWN = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.AddOnMessageLockdown or 11

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
function Sync:Enabled()
	return SK.DB and SK.DB.settings.sync
end

-- Returns paused, reason
function Sync:IsPaused()
	if not self:Enabled() then return true, "sync off" end
	if Compat.InCombat() then return true, "combat" end
	local inInstance, kind = Compat.InInstance()
	if inInstance then return true, "instance (" .. tostring(kind) .. ")" end
	if Compat.InChatLockdown() then return true, "chat lockdown" end
	if not SK.Identity.loaded then return true, "roster not loaded" end
	return false
end

function Sync:CanSend()
	return Compat.CanSendAddonMessages()
end

local function myGUID() return Compat.PlayerGUID() end

---------------------------------------------------------------------------
-- Transport (replaced in tests)
---------------------------------------------------------------------------
function Sync.transport(text, dist, target, prio, callback, arg)
	Sync:SendCommMessage(SK.PREFIX, text, dist, target, prio, callback, arg)
end

---------------------------------------------------------------------------
-- Outgoing queue
---------------------------------------------------------------------------
function Sync:Enqueue(key, dist, target, prio, msg)
	if not self:CanSend() then return end
	msg.p, msg.s, msg.v = SK.PROTOCOL, myGUID(), SK.VERSION
	local existing = key and self.queued[key]
	if existing then
		existing.msg = msg
		return existing
	end
	local item = { key = key, dist = dist, target = target, prio = prio or "NORMAL", msg = msg, tries = 0 }
	self.queue[#self.queue + 1] = item
	if key then self.queued[key] = item end
	return item
end

local function onChunkSent(item, _, _, result)
	if result == LOCKDOWN and not item.requeued then
		item.requeued = true
		item.tries = item.tries + 1
		if item.tries < Sync.MAX_TRIES then
			table.insert(Sync.queue, 1, item)
			if item.key then Sync.queued[item.key] = item end
		end
	end
end

function Sync:Flush()
	if #self.queue == 0 then return end
	if self:IsPaused() or not self:CanSend() then return end
	local n = 0
	while self.queue[1] and n < self.SENDS_PER_FLUSH do
		local item = table.remove(self.queue, 1)
		if item.key then self.queued[item.key] = nil end
		item.requeued = false
		local ok, text = pcall(SK.Codec.Encode, item.msg)
		if ok then
			self.transport(text, item.dist, item.target, item.prio, onChunkSent, item)
			self.stats.sent = self.stats.sent + 1
		else
			SK:Debug("encode failed: %s", tostring(text))
		end
		n = n + 1
	end
end

---------------------------------------------------------------------------
-- Outgoing messages
---------------------------------------------------------------------------
function Sync:SendHello()
	local guild = SK.DBM:Guild()
	if not guild then return end
	local entries = {}
	for guid in pairs(SK.DB.account) do
		local p = guild.profiles[guid]
		if p and guild.members[guid] then
			entries[#entries + 1] = { g = guid, u = p.updated, h = p.hash }
		end
	end
	if #entries == 0 then return end
	self:Enqueue("HI", "GUILD", nil, "NORMAL", { t = "HI", c = entries })
end

function Sync:SendQuery()
	local guild = SK.DBM:Guild()
	if not guild then return end
	local k = {}
	for guid, p in pairs(guild.profiles) do
		if not SK.DB.account[guid] then k[guid] = p.updated end
	end
	self:Enqueue("SQ", "GUILD", nil, "NORMAL", { t = "SQ", k = k })
end

local function request(self, ownerGUID, wantList)
	if #wantList == 0 then return end
	local target = SK.Identity:WhisperTarget(ownerGUID)
	if not target then return end
	local key = "RQ:" .. ownerGUID
	local existing = self.queued[key]
	if existing then
		local seen = {}
		for _, g in ipairs(existing.msg.w) do seen[g] = true end
		for _, g in ipairs(wantList) do
			if not seen[g] and #existing.msg.w < self.MAX_WANT then existing.msg.w[#existing.msg.w + 1] = g end
		end
		return
	end
	local w = {}
	for i = 1, math.min(#wantList, self.MAX_WANT) do w[i] = wantList[i] end
	self:Enqueue(key, "WHISPER", target, "NORMAL", { t = "RQ", w = w })
end

---------------------------------------------------------------------------
-- Handlers
---------------------------------------------------------------------------
local handlers = {}

-- Owner if the entry is the sender itself, or the stored owner copy lists
-- the sender as family.
local function isOwnerEntry(from, guid, stored)
	return SK.Merge.IsOwnerCopy(from, { guid = guid }, stored)
end

handlers.HI = function(self, msg, from)
	if type(msg.c) ~= "table" then return end
	local guild = SK.DBM:Guild()
	local want = {}
	for _, e in ipairs(msg.c) do
		if type(e) == "table" and type(e.g) == "string" and type(e.u) == "number"
			and SK.Identity:IsMember(e.g) and not SK.DB.account[e.g] then
			local m = guild.members[e.g]
			m.addon, m.addonSeen = msg.v, Compat.Now()
			local stored = guild.profiles[e.g]
			local owner = isOwnerEntry(from, e.g, stored)
			if not stored then
				want[#want + 1] = e.g
			elseif stored.hash ~= e.h then
				if (owner and (stored.source ~= "owner" or e.u >= stored.updated)) or e.u > stored.updated then
					want[#want + 1] = e.g
				end
			end
		end
	end
	request(self, from, want)
end

handlers.RQ = function(self, msg, from)
	if type(msg.w) ~= "table" then return end
	local guild = SK.DBM:Guild()
	local target = SK.Identity:WhisperTarget(from)
	for i = 1, math.min(#msg.w, self.MAX_WANT) do
		local guid = msg.w[i]
		local p = type(guid) == "string" and guild.profiles[guid]
		if p and SK.Identity:IsMember(guid) then
			local copy = SK.CopyTable(p)
			copy.source, copy.received = nil, nil
			self:Enqueue("PR:" .. from .. ":" .. guid, "WHISPER", target, "BULK", { t = "PR", prof = copy })
		end
	end
end

handlers.PR = function(self, msg, from)
	local prof = msg.prof
	local ok, why = SK.Merge.Validate(prof)
	if not ok then
		self.lastReject = why
		self.stats.rejected = self.stats.rejected + 1
		return
	end
	local guild = SK.DBM:Guild()
	local stored = guild.profiles[prof.guid]
	if SK.DB.account[prof.guid] then return end
	local isOwner = SK.Merge.IsOwnerCopy(from, prof, stored)
	local accept, reason = SK.Merge.Decide(stored, prof, isOwner, Compat.Now(), SK.Identity:IsMember(prof.guid))
	if accept then
		prof.source = isOwner and "owner" or "relay"
		prof.received = Compat.Now()
		guild.profiles[prof.guid] = prof
		self.stats.accepted = self.stats.accepted + 1
		SK:Fire("PROFILE_UPDATED", prof.guid)
	else
		self.stats.rejected = self.stats.rejected + 1
		self.lastReject = reason
	end
	SK:Debug("profile %s from %s: %s", tostring(prof.name), tostring(from), reason)
end

handlers.SQ = function(self, msg, from)
	if type(msg.k) ~= "table" then return end
	local guild = SK.DBM:Guild()
	local offer = {}
	for guid, p in pairs(guild.profiles) do
		if guid ~= from and SK.Identity:IsMember(guid) then
			local theirs = msg.k[guid]
			if type(theirs) ~= "number" or (p.updated or 0) > theirs then
				offer[#offer + 1] = guid
				if #offer >= self.MAX_WANT then break end
			end
		end
	end
	if #offer == 0 then return end
	self.pendingOffers[from] = true
	local delay = self.OFFER_DELAY_MIN + math.random() * (self.OFFER_DELAY_MAX - self.OFFER_DELAY_MIN)
	SK.After(delay, function()
		if not self.pendingOffers[from] then return end -- someone else offered first
		self.pendingOffers[from] = nil
		self:Enqueue("SO:" .. from, "GUILD", nil, "NORMAL", { t = "SO", to = from, g = offer })
	end)
end

handlers.SO = function(self, msg, from)
	if type(msg.to) ~= "string" or type(msg.g) ~= "table" then return end
	if msg.to ~= myGUID() then
		self.pendingOffers[msg.to] = nil
		return
	end
	local now = Compat.Now()
	if self.offerAcceptedAt and now - self.offerAcceptedAt < 300 then return end
	self.offerAcceptedAt = now
	local want = {}
	for _, g in ipairs(msg.g) do
		if type(g) == "string" and SK.Identity:IsMember(g) and not SK.DB.account[g] then want[#want + 1] = g end
	end
	request(self, from, want)
end

Sync.handlers = handlers

---------------------------------------------------------------------------
-- Incoming
---------------------------------------------------------------------------
local versionWarned = false

-- Only real release versions ("0.2.0", "v1.0.1-beta") are compared; test
-- builds named after a commit hash are ignored.
local function versionNewer(a, b)
	if not tostring(a):match("^v?%d+%.%d+") or not tostring(b):match("^v?%d+%.%d+") then return false end
	local function parts(v)
		local out = {}
		for n in tostring(v):gmatch("%d+") do out[#out + 1] = tonumber(n) end
		return out
	end
	local pa, pb = parts(a), parts(b)
	if #pa == 0 or #pb == 0 then return false end
	for i = 1, math.max(#pa, #pb) do
		local x, y = pa[i] or 0, pb[i] or 0
		if x ~= y then return x > y end
	end
	return false
end
Sync.versionNewer = versionNewer

function Sync:Handle(text, dist, sender)
	local msg = SK.Codec.Decode(text)
	if not msg or type(msg.t) ~= "string" then
		self.stats.dropped = self.stats.dropped + 1
		return
	end
	if type(msg.p) ~= "number" or msg.p > SK.PROTOCOL then
		self.stats.dropped = self.stats.dropped + 1
		return
	end
	if not versionWarned and SK.VERSION ~= "dev" and versionNewer(msg.v, SK.VERSION) then
		versionWarned = true
		SK:Print("A guildmate has Short Kings %s (you have %s). Please update.", tostring(msg.v), SK.VERSION)
	end
	local from, why = SK.Identity:SenderGUID(sender, type(msg.s) == "string" and msg.s or nil)
	if not from then
		self.stats.dropped = self.stats.dropped + 1
		SK:Debug("dropped %s from %s: %s", msg.t, tostring(sender), tostring(why))
		return
	end
	if from == myGUID() or SK.DB.account[from] then return end -- our own echo
	SK.Identity:NoteSender(from, sender)
	-- Any message proves the sender runs the addon (status dots, version column).
	local m = SK.Identity:Member(from)
	if m and type(msg.v) == "string" then
		m.addon, m.addonSeen = msg.v, Compat.Now()
	end
	local h = handlers[msg.t]
	if h then h(self, msg, from, dist) end
end

function Sync:OnCommReceived(prefix, text, dist, sender)
	if prefix ~= SK.PREFIX or not self:Enabled() then return end
	self.stats.received = self.stats.received + 1
	self.lastSender = sender
	if self:IsPaused() then
		if #self.buffer >= self.MAX_BUFFER then table.remove(self.buffer, 1) end
		self.buffer[#self.buffer + 1] = { text, dist, sender }
		return
	end
	local ok, err = pcall(self.Handle, self, text, dist, sender)
	if not ok then SK:Debug("message error: %s", tostring(err)) end
end

function Sync:DrainBuffer()
	if #self.buffer == 0 or self:IsPaused() then return end
	local batch = self.buffer
	self.buffer = {}
	for _, m in ipairs(batch) do
		local ok, err = pcall(self.Handle, self, m[1], m[2], m[3])
		if not ok then SK:Debug("message error: %s", tostring(err)) end
	end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function Sync:Start()
	if self.started then return end
	self.started = true
	local delay = 10 + math.random() * 10
	SK.After(delay, function()
		self:SendHello()
		SK.After(self.QUERY_DELAY, function() self:SendQuery() end)
	end)
	SK.NewTicker(self.HELLO_INTERVAL, function() self:SendHello() end)
end

function Sync:OnLogin()
	local AceComm = LibStub("AceComm-3.0")
	AceComm:Embed(self)
	self:RegisterComm(SK.PREFIX, "OnCommReceived")

	local canSend, why = self:CanSend()
	if not canSend then
		SK:Print("This account can't send addon messages (%s). You'll see your own characters, " ..
			"but guildmates won't receive your data and sync will be limited.", tostring(why))
	end

	SK:On("SELF_UPDATED", function()
		if SK.Identity.loaded then self:Start() end
		SK:Debounce("hello", self.HELLO_DEBOUNCE, function() self:SendHello() end)
	end)
	SK:On("ROSTER_UPDATED", function()
		self:DrainBuffer()
		if SK.Profile:Own() then self:Start() end
	end)
	SK.NewTicker(2, function()
		self:DrainBuffer()
		self:Flush()
	end)
end
