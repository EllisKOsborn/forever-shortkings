-- luacheck: globals C_Calendar C_DateAndTime CalendarFrame ToggleCalendar
-- v0.4.0 Raids tab: Blizzard's guild calendar, read-only.
local H = require("tests.helpers.load")

local NOW = { year = 2026, month = 12, monthDay = 8, hour = 18, minute = 0 }

-- A tiny stand-in for Blizzard's calendar: guild events, day events and sign-ups.
local function fakeCalendar(_, events, invites)
	local cal = { opened = nil, closed = 0, absMonth = nil, toggled = 0 }
	_G.C_DateAndTime = { GetCurrentCalendarTime = function() return NOW end }
	_G.C_Calendar = {
		OpenCalendar = function() cal.requested = true end,
		GetNumGuildEvents = function() return #events end,
		GetGuildEventInfo = function(i) return events[i] end,
		SetAbsMonth = function(m, y) cal.absMonth = { m, y } end,
		GetNumDayEvents = function(offset, day)
			local n = 0
			for _, e in ipairs(events) do
				if (e.year * 12 + e.month) - (NOW.year * 12 + NOW.month) == offset and e.monthDay == day then n = n + 1 end
			end
			return n
		end,
		GetDayEvent = function(offset, day, i)
			local n = 0
			for _, e in ipairs(events) do
				if (e.year * 12 + e.month) - (NOW.year * 12 + NOW.month) == offset and e.monthDay == day then
					n = n + 1
					if n == i then return { eventID = e.eventID, title = e.title } end
				end
			end
		end,
		OpenEvent = function(offset, day, i)
			cal.opened = { offset, day, i }
			return true
		end,
		GetNumInvites = function() return #invites end,
		EventGetInvite = function(i) return invites[i] end,
		CloseEvent = function() cal.closed = cal.closed + 1 end,
	}
	_G.ToggleCalendar = function() cal.toggled = cal.toggled + 1 end
	return cal
end

local function profile(SK, guid, fields)
	local p = { v = 1, guid = guid, name = guid, updated = 1, gear = {} }
	for k, v in pairs(fields or {}) do p[k] = v end
	p.hash = SK.Profile.HashOf(p)
	return p
end

local EVENTS = {
	{ eventID = 101, title = "Ony Thursday", eventType = 0, year = 2026, month = 12, monthDay = 10, hour = 20, minute = 0, inviteStatus = 6 },
	{ eventID = 102, title = "BD clear", eventType = 0, year = 2026, month = 12, monthDay = 9, hour = 19, minute = 30, inviteStatus = 0 },
	{ eventID = 103, title = "Guild meeting", eventType = 3, year = 2026, month = 12, monthDay = 9, hour = 18, minute = 0, inviteStatus = 0 },
	{ eventID = 104, title = "Far away", eventType = 0, year = 2027, month = 2, monthDay = 20, hour = 20, minute = 0, inviteStatus = 0 },
	{ eventID = 105, title = "New year raid", eventType = 0, year = 2027, month = 1, monthDay = 2, hour = 20, minute = 0, inviteStatus = 0 },
}

describe("Raids: events and matching", function()
	local SK
	before_each(function() SK = H.load() end)

	it("matches titles to first-wave raids by whole words", function()
		assert.equal("ony", SK.Raids.Match("Ony Thursday 8pm").key)
		assert.equal("ony", SK.Raids.Match("Onyxia's Lair!").key)
		assert.equal("barrow", SK.Raids.Match("BD clear").key)
		assert.equal("hyjal", SK.Raids.Match("hyjal farm").key)
		assert.is_nil(SK.Raids.Match("Money run")) -- "ony" inside a word doesn't count
		assert.is_nil(SK.Raids.Match("Molten Core")) -- not in the first wave
		assert.equal("hyjal", SK.Raids.Match("Ony Thursday", "hyjal").key) -- the player's own pick wins
	end)

	it("lists raid events in the next 30 days, soonest first, across a new year", function()
		local list = SK.Raids.Upcoming(EVENTS, NOW, {})
		local ids = {}
		for _, e in ipairs(list) do ids[#ids + 1] = e.eventID end
		assert.same({ 102, 101, 105 }, ids)
		assert.equal("barrow", list[1].raid.key)
		assert.is_nil(list[3].raid)
	end)
end)

describe("Raids: line-up", function()
	local SK, W, guild
	local TANK, HEAL, ALT, NODATA, OUT = "P-T", "P-H", "P-H2", "P-N", "P-O"
	before_each(function()
		SK, W = H.load()
		W.member("Pocus Hocus", W.player.guid)
		W.member("Tanky", TANK, { class = "WARRIOR" })
		W.member("Healz", HEAL, { class = "PRIEST" })
		W.member("Healzalt", ALT, { class = "MAGE" })
		W.member("Newbie", NODATA, { class = "ROGUE" })
		W.member("Nope", OUT, { class = "MAGE" })
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		guild = SK.DBM:Guild()
		guild.profiles[TANK] = profile(SK, TANK, { class = "WARRIOR", level = 60, ilvl = 62, updated = W.now,
			roles = { main = "TANK", second = "DPS" }, att = { ony = true, ony_item = false } })
		guild.profiles[HEAL] = profile(SK, HEAL, { class = "PRIEST", level = 60, ilvl = 58, updated = W.now - 9 * 86400,
			family = { ALT }, att = { ony = false },
			talents = { api = "traits", trees = { { n = "Discipline", p = 5 }, { n = "Holy", p = 31 }, { n = "Shadow", p = 0 } } } })
		guild.profiles[ALT] = profile(SK, ALT, { class = "MAGE", level = 60, updated = W.now, family = { HEAL } })
	end)

	local INVITES = {
		{ guid = "P-T", name = "Tanky", level = 60, class = "WARRIOR", status = 6 },
		{ guid = "P-H", name = "Healz", level = 60, class = "PRIEST", status = 3 },
		{ guid = "P-H2", name = "Healzalt", level = 60, class = "MAGE", status = 8 },
		{ guid = "P-N", name = "Newbie", level = 58, class = "ROGUE", status = 6 },
		{ guid = "P-O", name = "Nope", level = 60, class = "MAGE", status = 2 },
	}

	local function lineUp(raidKey)
		local ctx = { guild = guild, now = W.now, profile = function(g) return SK.Profile:Get(g, guild) end,
			isOwn = function(g) return SK.DB.account[g] == true end }
		local raid = SK.Raids.Match("x", raidKey)
		return SK.Raids.LineUp(INVITES, raid, ctx)
	end

	it("uses chosen roles, guesses the rest from talents, and counts who's coming", function()
		local rows, s = lineUp("ony")
		local by = {}
		for _, r in ipairs(rows) do by[r.name] = r end
		assert.equal("TANK", by.Tanky.role)
		assert.is_false(by.Tanky.roleGuess)
		assert.equal("HEALER", by.Healz.role) -- Holy has the most points
		assert.is_true(by.Healz.roleGuess)
		assert.equal("DPS", by.Newbie.role)   -- rogues only have one role
		assert.equal(3, s.coming)
		assert.equal(1, s.maybe)
		assert.equal(1, s.out)
		assert.same({ TANK = 1, HEALER = 1, DPS = 1, unknown = 0 }, s.roles)
		assert.equal("Tanks 1  ·  Healers 1  ·  DPS 1  ·  3 / 40", SK.Raids.CountsText(s))
		assert.equal("Nope", rows[#rows].name) -- declined last
	end)

	it("readiness: attunement, amulet, stale data, no data, signed up twice", function()
		local _, s = lineUp("ony")
		assert.equal(1, s.notAttuned)  -- Healz
		assert.equal(1, s.noItem)      -- Tanky's amulet isn't in bags
		assert.equal(1, s.stale)       -- Healz, 9 days
		assert.equal(1, s.noData)      -- Newbie
		assert.equal(1, #s.duplicates) -- Healz and Healzalt (tentative counts)
		local text = {}
		for _, r in ipairs(SK.Raids.Readiness(s)) do text[#text + 1] = r.text end
		local all = table.concat(text, "\n")
		assert.truthy(all:find("1 not attuned", 1, true))
		assert.truthy(all:find("Signed up twice", 1, true))
		assert.truthy(all:find("Item level 58 to 62", 1, true))
	end)

	it("no attunement needed for Barrow Deeps; missing roles are flagged", function()
		local _, s = lineUp("barrow")
		assert.equal(0, s.notAttuned)
		INVITES[1].status = 2 -- the tank declines
		local _, s2 = lineUp("barrow")
		assert.truthy(table.concat(s2.missing, " "):find("No tanks yet", 1, true))
		INVITES[1].status = 6
	end)

	it("copies as plain text", function()
		local rows, s = lineUp("ony")
		local text = SK.Raids.Text(EVENTS[1], SK.Raids.Match("Ony"), rows, s)
		assert.truthy(text:find("Ony Thursday (Onyxia's Lair), 2026-12-10 20:00", 1, true))
		assert.truthy(text:find("Healz · Confirmed · Healer (guess) · Holy 5/31/0 · ilvl 58 · not attuned", 1, true))
		assert.is_nil(text:find("|c", 1, true))
	end)
end)

describe("Raids: reading the calendar", function()
	local SK, W, cal
	before_each(function()
		SK, W = H.load()
		W.member("Pocus Hocus", W.player.guid)
		SK.Identity:ReadRoster()
		cal = fakeCalendar(W, EVENTS, { { guid = W.player.guid, name = "Pocus Hocus", level = 15, classFilename = "PRIEST", inviteStatus = 6 } })
	end)
	after_each(function() _G.C_Calendar, _G.C_DateAndTime, _G.CalendarFrame, _G.ToggleCalendar = nil, nil, nil, nil end)

	it("opens the right event by its day position, reads, closes, caches", function()
		local list = SK.Raids:Events()
		local ony = list[2]
		assert.equal(101, ony.eventID)
		assert.is_true(SK.Raids:Read(ony))
		assert.same({ 0, 10, 1 }, cal.opened)
		assert.same({ 12, 2026 }, cal.absMonth)
		SK.Raids:OnEventOpened()
		assert.equal(1, cal.closed)
		local c = SK.Raids.cache[101]
		assert.equal(1, #c.invites)
		assert.equal("PRIEST", c.invites[1].class)
		assert.equal(6, c.invites[1].status)
	end)

	it("never reads while Blizzard's calendar is open, in combat or in chat lockdown", function()
		local ev = SK.Raids:Events()[1]
		_G.CalendarFrame = W.stub()
		_G.CalendarFrame:Show()
		assert.is_false(SK.Raids:Read(ev))
		assert.truthy(SK.Raids.lastError:find("close Blizzard's calendar", 1, true))
		assert.is_nil(cal.opened)
		_G.CalendarFrame = nil
		W.combat = true
		assert.is_false(SK.Raids:Read(ev))
		W.combat = false
		-- the player opening an event in Blizzard's calendar is left alone
		SK.Raids:OnEventOpened()
		assert.equal(0, cal.closed)
	end)

	it("gives up after a few seconds if the calendar doesn't answer", function()
		local ev = SK.Raids:Events()[1]
		assert.is_true(SK.Raids:Read(ev))
		W.advance(SK.Raids.READ_TIMEOUT + 1)
		assert.is_nil(SK.Raids.pending)
		assert.truthy(SK.Raids.lastError:find("didn't answer", 1, true))
	end)

	it("drops secret values from the calendar", function()
		_G.issecretvalue = function(v) return v == "SECRET" end
		local events = { { eventID = 9, title = "SECRET", eventType = 0, year = 2026, month = 12, monthDay = 9, hour = 20, minute = 0 } }
		fakeCalendar(W, events, {})
		local list = SK.Compat.GuildEvents()
		assert.equal("?", list[1].title)
		_G.issecretvalue = nil
	end)
end)

describe("Raids: roles in the profile", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		W.member("Pocus Hocus", W.player.guid)
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
	end)

	it("saves this character's roles in its profile; older versions accept the field", function()
		SK.Profile:SetRoles("HEALER", "DPS")
		local pub = SK.DBM:Guild().profiles[W.player.guid]
		assert.same({ main = "HEALER", second = "DPS" }, pub.roles)
		assert.is_true((SK.Merge.Validate(pub)))
		local check = SK.Merge.FIELDS.roles
		SK.Merge.FIELDS.roles = nil
		assert.is_true((SK.Merge.Validate(pub)))
		SK.Merge.FIELDS.roles = check
		SK.Profile:SetRoles(nil)
		assert.is_nil(SK.DBM:Guild().profiles[W.player.guid].roles)
	end)

	it("refuses made-up roles", function()
		local base = { v = 1, guid = "X-1", updated = 1, hash = "h" }
		base.roles = { main = "KING" }
		assert.is_false((SK.Merge.Validate(base)))
		base.roles = { main = "TANK", extra = "DPS" }
		assert.is_false((SK.Merge.Validate(base)))
	end)
end)

describe("Raids tab", function()
	local SK, W, cal
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pocus Hocus", W.player.guid, { class = "PRIEST" })
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		cal = fakeCalendar(W, EVENTS, { { guid = W.player.guid, name = "Pocus Hocus", level = 15, classFilename = "PRIEST", inviteStatus = 6 } })
	end)
	after_each(function() _G.C_Calendar, _G.C_DateAndTime, _G.CalendarFrame, _G.ToggleCalendar = nil, nil, nil, nil end)

	it("lists events, picks the first, reads it and shows the line-up", function()
		SK.MainFrame:Show("raids")
		local tab = SK.RaidsTab
		assert.equal(3, #tab.events.items)
		assert.equal(102, tab.selected) -- BD on 9 Dec comes first
		assert.truthy(tab.counts:GetText():find("Reading", 1, true))
		SK.Raids:OnEventOpened()
		SK.Raids.cache[102].at = W.now
		tab:Refresh()
		assert.equal(1, #tab.lineup.items)
		assert.truthy(tab.counts:GetText():find("1 / 10", 1, true))
		assert.truthy(tab.ready:GetText():find("No tanks yet", 1, true))
		assert.truthy(tab:CopyText():find("BD clear (Barrow Deeps)", 1, true))
		assert.equal(0, #SK.errors)
	end)

	it("lets you set your roles and change an event's raid", function()
		SK.MainFrame:Show("raids")
		local tab = SK.RaidsTab
		SK.Raids:OnEventOpened()
		tab.mainRole:Choose("HEALER")
		tab.secondRole:Choose("DPS")
		assert.same({ main = "HEALER", second = "DPS" }, SK.Profile:Own().roles)
		tab:Refresh()
		assert.equal("HEALER", tab.lineup.items[1].role)
		assert.is_false(tab.lineup.items[1].roleGuess)
		tab.raidMenu:Choose("ony")
		assert.equal("ony", SK.DB.raidPick[102])
		assert.truthy(tab.counts:GetText():find("1 / 40", 1, true))
		tab.newRaid:GetScript("OnClick")(tab.newRaid)
		assert.equal(1, cal.toggled)
		assert.equal(0, #SK.errors)
	end)

	it("says when there are no raids", function()
		fakeCalendar(W, {}, {})
		SK.MainFrame:Show("raids")
		assert.equal(0, #SK.RaidsTab.events.items)
		assert.truthy(SK.RaidsTab.events.emptyText:find("New raid", 1, true))
		assert.equal(0, #SK.errors)
	end)

	it("formats dates", function()
		assert.equal("Thu 10 Dec 20:00", SK.RaidsTab.When(EVENTS[1]))
		assert.equal("Sat 2 Jan 20:00", SK.RaidsTab.When(EVENTS[5]))
	end)
end)
