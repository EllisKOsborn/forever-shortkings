-- Raids (v0.4.0): the numbers behind the Raids tab, from Blizzard's guild
-- calendar plus the profiles we already have. Events and sign-ups live on
-- Blizzard's servers, so nothing here is synced: members without the addon
-- still show (name, class, level, status) and count.
--
-- Pure parts (tested): Raids.Match, Raids.Upcoming, Raids.LineUp, Raids.Text.
-- Stateful part: Raids:Read(event) reads one event's sign-ups through
-- Compat (only while Blizzard's calendar window is closed, never in combat
-- or chat lockdown) and caches them for the session.
local _, SK = ...

local Raids = SK:NewModule("Raids")
local Compat = SK.Compat

Raids.DAYS_AHEAD = 30
Raids.KEEP_HOURS = 6     -- an event stays listed this long after it started
Raids.READ_TIMEOUT = 5   -- seconds to wait for the calendar to answer

-- Enum.CalendarStatus (CalendarConstantsDocumentation.lua, forever branch).
Raids.STATUS_NAME = {
	[0] = "Invited", [1] = "Available", [2] = "Declined", [3] = "Confirmed", [4] = "Out",
	[5] = "Standby", [6] = "Signed up", [7] = "Not signed up", [8] = "Tentative",
}
-- Groups used for counting: coming (signed up, confirmed, available),
-- maybe (tentative), bench (standby), out (declined, out), invited (no answer).
Raids.STATUS_GROUP = { [0] = "invited", [1] = "coming", [2] = "out", [3] = "coming", [4] = "out",
	[5] = "bench", [6] = "coming", [7] = "invited", [8] = "maybe" }
local GROUP_ORDER = { coming = 1, maybe = 2, bench = 3, invited = 4, out = 5 }
local ROLE_ORDER = { TANK = 1, HEALER = 2, DPS = 3 }

---------------------------------------------------------------------------
-- Dates
---------------------------------------------------------------------------
-- Days since 1970-01-01 for a calendar date (proleptic Gregorian).
local function days(y, m, d)
	y = m <= 2 and y - 1 or y
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = math.floor((153 * mp + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end

-- Minutes since 1970 for { year, month, monthDay, hour, minute } (calendar time).
function Raids.Minutes(t)
	return days(t.year, t.month, t.monthDay) * 1440 + (t.hour or 0) * 60 + (t.minute or 0)
end

---------------------------------------------------------------------------
-- Matching an event to a raid
---------------------------------------------------------------------------
-- The raid entry (Data/Attunements) for an event: the player's own pick if
-- they made one, else the first raid with a keyword in the title.
function Raids.Match(title, pickedKey)
	local shown = SK.Data.ShownAttunements()
	if pickedKey then
		for _, r in ipairs(shown) do if r.key == pickedKey then return r end end
	end
	local words = SK.Accounts.Words(title)
	for _, r in ipairs(shown) do
		for _, k in ipairs(r.keywords or {}) do
			if words[k] then return r end
		end
	end
	return nil
end

-- Upcoming raid events (calendar type Raid), soonest first, from
-- KEEP_HOURS ago to DAYS_AHEAD ahead. Each gets .when (minutes), .raid.
function Raids.Upcoming(events, now, picks)
	local out, nowM = {}, Raids.Minutes(now)
	for _, e in ipairs(events or {}) do
		if e.eventType == Compat.EVENT_RAID and e.year and e.month and e.monthDay then
			local when = Raids.Minutes(e)
			if when >= nowM - Raids.KEEP_HOURS * 60 and when <= nowM + Raids.DAYS_AHEAD * 1440 then
				local ev = SK.CopyTable(e)
				ev.when = when
				ev.raid = Raids.Match(e.title, picks and picks[e.eventID])
				out[#out + 1] = ev
			end
		end
	end
	table.sort(out, function(a, b)
		if a.when ~= b.when then return a.when < b.when end
		return a.eventID < b.eventID
	end)
	return out
end

---------------------------------------------------------------------------
-- Line-up
---------------------------------------------------------------------------
-- ctx = { guild, now (server time), profile = fn(guid), isOwn = fn(guid) }
-- Returns rows (sorted: coming first, then by role and name) and a summary.
function Raids.LineUp(invites, raid, ctx)
	local rows = {}
	local profiles = {}
	for _, inv in ipairs(invites or {}) do
		local p = ctx.profile(inv.guid)
		local m = ctx.guild and ctx.guild.members[inv.guid]
		local class = inv.class or (m and m.class) or (p and p.class)
		local roles = p and p.roles
		local role, guess = roles and roles.main, false
		if not role then role, guess = SK.Data.GuessRole(class, p and p.talents), true end
		local gearHidden = p and p.hidden and p.hidden.gear
		local spec, tree = nil, nil
		if p and not gearHidden then spec, tree = SK.Talents.Summary(p.talents) end
		local att, attNote = SK.Attunements.StateOf(p, raid)
		local status = inv.status
		local row = {
			guid = inv.guid, name = inv.name or (m and m.name) or "?", class = class,
			level = inv.level or (m and m.level) or 0,
			status = status, statusName = Raids.STATUS_NAME[status] or "?",
			group = Raids.STATUS_GROUP[status] or "invited",
			role = role, roleGuess = role ~= nil and guess or false, second = roles and roles.second,
			spec = spec, tree = tree, ilvl = (p and not gearHidden) and p.ilvl or nil,
			att = att, attNote = attNote, hasData = p ~= nil,
			stale = p ~= nil and not ctx.isOwn(inv.guid) and type(p.updated) == "number"
				and ctx.now - p.updated > SK.Overview.STALE_AFTER or false,
			enchants = (p and p.gear and not gearHidden) and #SK.Data.Enchants.Missing(p.gear, p.class, p.level) or 0,
		}
		if p and ctx.guild then profiles[inv.guid] = ctx.guild.profiles[inv.guid] or p end
		rows[#rows + 1] = row
	end

	-- The same player signed up on two characters (mutually linked alts).
	local groupOf = SK.Alts.Groups(profiles, function(g) return profiles[g] ~= nil end)
	local seen, dupes = {}, {}
	for _, r in ipairs(rows) do
		local g = groupOf[r.guid]
		if g and #g.members > 1 and (r.group == "coming" or r.group == "maybe") then
			if seen[g] then
				r.duplicateOf, dupes[#dupes + 1] = seen[g], r.name .. " and " .. seen[g]
			else
				seen[g] = r.name
			end
		end
	end

	table.sort(rows, function(a, b)
		if a.group ~= b.group then return GROUP_ORDER[a.group] < GROUP_ORDER[b.group] end
		local ra, rb = ROLE_ORDER[a.role or ""] or 4, ROLE_ORDER[b.role or ""] or 4
		if ra ~= rb then return ra < rb end
		return a.name:lower() < b.name:lower()
	end)

	local s = { coming = 0, maybe = 0, bench = 0, out = 0, invited = 0,
		roles = { TANK = 0, HEALER = 0, DPS = 0, unknown = 0 }, guesses = 0,
		notAttuned = 0, unknownAtt = 0, noItem = 0, enchants = 0, stale = 0, noData = 0,
		ilvlMin = nil, ilvlMax = nil, duplicates = dupes, size = raid and raid.size or nil }
	for _, r in ipairs(rows) do
		s[r.group] = s[r.group] + 1
		if r.group == "coming" then
			local k = r.role or "unknown"
			s.roles[k] = s.roles[k] + 1
			if r.roleGuess then s.guesses = s.guesses + 1 end
			if r.att == "no" then s.notAttuned = s.notAttuned + 1 end
			if r.att == "unknown" and raid and raid.status ~= "none" then s.unknownAtt = s.unknownAtt + 1 end
			if r.attNote then s.noItem = s.noItem + 1 end
			if r.enchants > 0 then s.enchants = s.enchants + 1 end
			if r.stale then s.stale = s.stale + 1 end
			if not r.hasData then s.noData = s.noData + 1 end
			if r.ilvl then
				s.ilvlMin = math.min(s.ilvlMin or r.ilvl, r.ilvl)
				s.ilvlMax = math.max(s.ilvlMax or r.ilvl, r.ilvl)
			end
		end
	end
	s.missing = {}
	if s.coming > 0 then
		if s.roles.TANK == 0 then s.missing[#s.missing + 1] = "No tanks yet" end
		if s.roles.HEALER == 0 then s.missing[#s.missing + 1] = "No healers yet" end
	end
	return rows, s
end

-- "Tanks 2 · Healers 6 · DPS 18 · 26 / 40"
function Raids.CountsText(s)
	local parts = {
		"Tanks " .. s.roles.TANK, "Healers " .. s.roles.HEALER, "DPS " .. s.roles.DPS,
	}
	if s.roles.unknown > 0 then parts[#parts + 1] = "Role unknown " .. s.roles.unknown end
	parts[#parts + 1] = s.size and (s.coming .. " / " .. s.size) or (s.coming .. " coming")
	return table.concat(parts, "  ·  ")
end

-- Readiness lines (raid night card): { text, tone } for the UI and Copy.
function Raids.Readiness(s)
	local out = {}
	local function add(text, tone) out[#out + 1] = { text = text, tone = tone or "dim" } end
	for _, m in ipairs(s.missing) do add(m, "bad") end
	if s.maybe > 0 then add(s.maybe .. " tentative", "dim") end
	if s.notAttuned > 0 then add(s.notAttuned .. " not attuned", "bad") end
	if s.noItem > 0 then add(s.noItem .. " without the amulet in their bags", "spark") end
	if s.ilvlMin then add(string.format("Item level %.0f to %.0f", s.ilvlMin, s.ilvlMax)) end
	if s.enchants > 0 then add(s.enchants .. " missing enchants", "spark") end
	if s.stale > 0 then add(s.stale .. " with data older than a week", "spark") end
	if s.noData > 0 then add(s.noData .. " without Short Royalty data (role, spec and gear unknown)") end
	if s.guesses > 0 then add(s.guesses .. " roles guessed from talents (they can set theirs on this tab)") end
	for _, d in ipairs(s.duplicates) do add("Signed up twice: " .. d, "spark") end
	return out
end

-- Plain text for Copy (Discord). No notes, no colour codes.
function Raids.Text(ev, raid, rows, s)
	local L = {}
	local title = ev and ev.title or "Raid"
	L[1] = string.format("%s%s, %04d-%02d-%02d %02d:%02d", title, raid and (" (" .. raid.name .. ")") or "",
		ev.year or 0, ev.month or 0, ev.monthDay or 0, ev.hour or 0, ev.minute or 0)
	L[2] = Raids.CountsText(s)
	for _, r in ipairs(Raids.Readiness(s)) do L[#L + 1] = "- " .. r.text end
	L[#L + 1] = ""
	for _, r in ipairs(rows) do
		local parts = { r.name, r.statusName }
		if r.role then parts[#parts + 1] = SK.Data.ROLE_NAMES[r.role] .. (r.roleGuess and " (guess)" or "") end
		if r.spec then parts[#parts + 1] = (r.tree and (r.tree .. " ") or "") .. r.spec end
		if r.ilvl then parts[#parts + 1] = string.format("ilvl %.0f", r.ilvl) end
		if r.att == "no" then parts[#parts + 1] = "not attuned" end
		L[#L + 1] = table.concat(parts, " · ")
	end
	return SK.Export.Plain(table.concat(L, "\n"))
end

---------------------------------------------------------------------------
-- Reading the calendar (stateful)
---------------------------------------------------------------------------
Raids.cache = {}      -- [eventID] = { at = time, invites = {...} }
Raids.lastError = nil

-- Why we can't read an event right now, or nil.
function Raids.Blocked()
	if not Compat.CalendarReady() then return "this client has no calendar" end
	if Compat.CalendarShown() then return "close Blizzard's calendar first" end
	if Compat.InCombat() then return "in combat" end
	if Compat.InChatLockdown() then return "chat lockdown" end
	return nil
end

function Raids:Events(now)
	return Raids.Upcoming(Compat.GuildEvents(), now or Compat.CalendarNow(), SK.DB.raidPick)
end

-- Ask for one event's sign-ups. Returns true when a read started.
function Raids:Read(ev)
	if not ev then return false end
	local why = Raids.Blocked()
	if why then Raids.lastError = why; return false end
	if self.pending then return false end
	self.pending = { eventID = ev.eventID, at = Compat.Now() }
	local ok, err = Compat.CalendarOpenEvent(ev)
	if not ok then
		self.pending = nil
		Raids.lastError = err == "not found" and "the calendar hasn't loaded this event yet" or tostring(err)
		return false
	end
	local pending = self.pending
	SK.After(Raids.READ_TIMEOUT, function()
		if self.pending == pending then
			self.pending = nil
			Raids.lastError = "the calendar didn't answer"
			SK:Fire("RAIDS_UPDATED")
		end
	end)
	return true
end

function Raids:OnEventOpened()
	local pending = self.pending
	if not pending then return end -- the player opened something in Blizzard's calendar
	self.pending = nil
	if Compat.CalendarShown() then return end
	local invites = Compat.CalendarInvites()
	Compat.CalendarCloseEvent()
	Raids.cache[pending.eventID] = { at = Compat.Now(), invites = invites }
	Raids.lastError = nil
	SK:Fire("RAIDS_UPDATED", pending.eventID)
end

function Raids:OnLogin()
	SK:RegisterEvent("CALENDAR_OPEN_EVENT", function() Raids:OnEventOpened() end)
	local function changed() SK:Debounce("raids", 1, function() SK:Fire("RAIDS_UPDATED") end) end
	SK:RegisterEvent("CALENDAR_UPDATE_GUILD_EVENTS", changed)
	SK:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST", changed)
	SK.After(15, function() Compat.CalendarRequest() end)
end
