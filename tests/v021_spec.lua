-- Tests for v0.2.1 launch readiness.
local H = require("tests.helpers.load")

local function profile(SK, guid, fields)
	local p = { v = 1, guid = guid, name = guid, updated = 1, gear = {} }
	for k, v in pairs(fields or {}) do p[k] = v end
	p.hash = SK.Profile.HashOf(p)
	return p
end

describe("v0.2.1 attunements (first raid wave)", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
	end)

	local function raid(key) return SK.RosterTab.Raid(key) end

	it("shows only Barrow Deeps, Hyjal Summit and Onyxia's Lair", function()
		local keys = {}
		for _, a in ipairs(SK.Data.ShownAttunements()) do keys[#keys + 1] = a.key end
		assert.same({ "barrow", "hyjal", "ony" }, keys)
		assert.is_true(raid("mc").hidden) -- kept, just not shown
	end)

	it("Barrow Deeps and Hyjal Summit need no attunement", function()
		assert.equal("none", SK.RosterTab.AttunementOf(nil, raid("barrow")))
		assert.equal("none", SK.RosterTab.AttunementOf(profile(SK, "A"), raid("hyjal")))
	end)

	it("Onyxia: the quest or the amulet in bags counts, and a missing amulet is noted", function()
		local ony = raid("ony")
		local function of(att) return SK.RosterTab.AttunementOf(profile(SK, "A", { att = att }), ony) end
		assert.equal("yes", of({ ony = true, ony_item = true }))
		local state, note = of({ ony = true, ony_item = false })
		assert.equal("yes", state)
		assert.equal("Drakefire Amulet not in bags", note)
		assert.equal("yes", of({ ony = false, ony_item = true }))
		assert.equal("no", of({ ony = false, ony_item = false }))
		assert.equal("yes", (of({ ony = true })))      -- profile from v0.2.0: no bag flag
		assert.is_nil(select(2, of({ ony = true })))
		assert.equal("unknown", of({}))
	end)

	it("records the amulet from our bags", function()
		W.member("Pip", W.player.guid)
		SK.Identity:ReadRoster()
		W.bags[16309] = 1
		SK.Profile:BuildSelf()
		assert.is_true(SK.Profile:Own().att.ony_item)
		assert.is_false(SK.Profile:Own().att.ony)
		local text = table.concat(SK.Commands.BuildReport(), "\n")
		assert.truthy(text:find("Onyxia's Lair item 16309", 1, true))
		assert.truthy(text:find("Barrow Deeps: no attunement needed", 1, true))
	end)

	it("Roster: a raid needing no attunement hides the filters and says so", function()
		W.member("Pip", W.player.guid)
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		SK.MainFrame:Show("roster")
		SK.DB.settings.roster.raid = "barrow"
		SK.DB.settings.roster.attFilter = "no"
		SK.RosterTab:Refresh()
		assert.equal(1, #SK.RosterTab.attList.items) -- the filter is ignored
		assert.equal("none", SK.RosterTab.attList.items[1].att)
		assert.truthy(SK.RosterTab.attCount:GetText():find("No attunement needed", 1, true))
	end)
end)

describe("v0.2.1 live-client checks and error capture", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pip", W.player.guid)
		SK.Identity:ReadRoster()
	end)

	local function report() return table.concat(SK.Commands.BuildReport(), "\n") end

	it("tracks whether a character's GUID stays the same between logins", function()
		local seen = {}
		local e = SK.Identity.NoteLogin(seen, "Pip", "G1", 1)
		assert.equal(1, e.logins)
		SK.Identity.NoteLogin(seen, "Pip", "G1", 2)
		assert.equal(2, seen.Pip.logins)
		assert.is_nil(seen.Pip.changedFrom)
		SK.Identity.NoteLogin(seen, "Pip", "G2", 3)
		assert.equal("G1", seen.Pip.changedFrom)
		assert.equal("G2", seen.Pip.guid)
		assert.is_nil(SK.Identity.NoteLogin(seen, nil, "G3", 4))
	end)

	it("reports GUID stability, calendar and unlearned recipes", function()
		assert.truthy(report():find("first login seen", 1, true))
		SK.Identity:OnLogin()
		SK.Identity:OnLogin()
		local text = report()
		assert.truthy(text:find("GUID stable between logins: yes so far (2 logins as Pip)", 1, true))
		assert.truthy(text:find("Calendar: C_Calendar present=no", 1, true))
		assert.truthy(text:find("open a profession window", 1, true))
		_G.C_Calendar = { GetNumGuildEvents = function() return 3 end, AddEvent = function() end }
		assert.truthy(report():find("present=yes, guild events listed=3, AddEvent present=yes", 1, true))
		_G.C_Calendar = nil
		W.player.guid = "Player-1-CHANGED"
		SK.Identity:OnLogin()
		assert.truthy(report():find("GUID stable between logins: NO", 1, true))
	end)

	it("records errors from event handlers and messages without stopping the others", function()
		local ran = false
		local seenErrors = {}
		_G.geterrorhandler = function() return function(e) seenErrors[#seenErrors + 1] = e end end
		SK:On("TEST_MSG", function() error("boom") end)
		SK:On("TEST_MSG", function() ran = true end)
		SK:Fire("TEST_MSG")
		SK:Fire("TEST_MSG")
		assert.is_true(ran)
		assert.equal(1, #SK.errors)          -- same error twice is counted, not duplicated
		assert.equal(2, SK.errors[1].count)
		assert.equal(2, #seenErrors)          -- still passed to the game's error handler
		SK:RegisterEvent("TEST_EVENT", function() error("event boom") end)
		W.fire("TEST_EVENT")
		assert.equal("TEST_EVENT", SK.errors[1].where)
		local text = report()
		assert.truthy(text:find("Recent Lua errors caught: 2", 1, true))
		assert.truthy(text:find("event boom", 1, true))
	end)

	it("keeps only the last 10 errors", function()
		for i = 1, 15 do SK:RecordError("where" .. i, "e" .. i) end
		assert.equal(10, #SK.errors)
		assert.equal("where15", SK.errors[1].where)
	end)
end)
