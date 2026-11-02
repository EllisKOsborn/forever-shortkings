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

describe("v0.2.1 sync hardening", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		W.member("Pip", W.player.guid)
		W.member("Bob", "Player-1-B")
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
	end)

	it("refuses oversized messages before decompressing", function()
		assert.equal(32 * 1024, SK.Codec.MAX_ENCODED)
		local msg, why = SK.Codec.Decode(string.rep("a", 32 * 1024 + 1))
		assert.is_nil(msg)
		assert.equal("too large", why)
	end)

	it("does not send a message receivers would refuse, and records why", function()
		local sent = H.captureSends(SK)
		local big = {}
		math.randomseed(7)
		for i = 1, 15000 do big[i] = math.random(1, 2 ^ 30) end -- incompressible
		SK.Sync:Enqueue("X", "GUILD", nil, "NORMAL", { t = "XX", junk = big })
		SK.Sync:Flush()
		assert.equal(0, #sent)
		assert.truthy(SK.errors[1].msg:find("too large", 1, true))
	end)

	it("limits incoming messages per sender, per minute", function()
		local handled = 0
		SK.Sync.Handle = function() handled = handled + 1 end
		for _ = 1, 70 do SK.Sync:OnCommReceived(SK.PREFIX, "x", "GUILD", "Bob") end
		assert.equal(60, handled)
		assert.equal(10, SK.Sync.stats.limited)
		SK.Sync:OnCommReceived(SK.PREFIX, "x", "GUILD", "Cat") -- others unaffected
		assert.equal(61, handled)
		W.advance(61)
		SK.Sync:OnCommReceived(SK.PREFIX, "x", "GUILD", "Bob") -- new window
		assert.equal(62, handled)
	end)
end)

describe("v0.2.1 sharing preview and data freshness", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pip", W.player.guid)
		SK.Identity:ReadRoster()
		W.gear[1] = "|cffa335ee|Hitem:16914::::|h[Netherwind Crown]|h|r"
		SK.Profile:BuildSelf()
	end)

	local function shared(list)
		local out = {}
		for _, c in ipairs(list) do out[c.label] = c.shared end
		return out
	end

	it("matches the public copy for every combination of the privacy switches", function()
		local own = SK.Profile:Own()
		own.recipes = { [197] = { [1] = 2 } }
		for _, gear in ipairs({ true, false }) do
			for _, recipes in ipairs({ true, false }) do
				local share = { gear = gear, recipes = recipes }
				local pub = SK.Profile.Public(own, share)
				local s = shared(SK.Profile.SharingSummary(own, share))
				assert.equal(pub.gear ~= nil, s["Gear and item level"])
				assert.equal(pub.talents ~= nil, s["Talents"])
				assert.equal(pub.recipes ~= nil, s["Recipes"])
				assert.equal(pub.cds ~= nil, s["Profession cooldowns"])
				assert.equal(gear, s["Gear and item level"])
				assert.equal(recipes, s["Recipes"])
				assert.is_true(s["Profession skill levels"])
				assert.is_true(s["Name, class, race, level and addon version"])
				assert.is_nil(pub.note)
				assert.is_nil(pub.officerNote)
			end
		end
	end)

	it("Settings shows the preview and what is never shared", function()
		SK.DB.settings.share.gear = false
		SK.MainFrame:Show("settings")
		local text = SK.SettingsTab.status.fs:GetText()
		assert.truthy(SK.SettingsTab.sharingHeading:GetText():find("WHAT GUILDMATES SEE FROM YOU", 1, true))
		assert.truthy(text:find("private|r  Gear and item level", 1, true))
		assert.truthy(text:find("shared|r   Recipes", 1, true))
		assert.truthy(text:find("Never shared: Notes and officer notes", 1, true))
	end)

	it("labels data older than a week", function()
		assert.is_false(SK.Theme.IsStale(W.now - 3600, W.now))
		assert.is_true(SK.Theme.IsStale(W.now - 8 * 86400, W.now))
		assert.is_false(SK.Theme.IsStale(nil, W.now))
		W.member("Bob", "Player-1-B")
		SK.Identity:ReadRoster()
		local p = { v = 1, guid = "Player-1-B", name = "Bob", updated = W.now - 9 * 86400, gear = {}, source = "relay" }
		p.hash = SK.Profile.HashOf(p)
		SK.DBM:Guild().profiles["Player-1-B"] = p
		SK.CharacterTab:ShowCharacter("Player-1-B")
		local meta = SK.CharacterTab.meta:GetText()
		assert.truthy(meta:find("relayed by a guildmate", 1, true))
		assert.truthy(meta:find("may be out of date", 1, true))
	end)

	it("the craft index knows when each crafter's recipes were recorded", function()
		W.tradeskill = { skillLine = 197, name = "Tailoring", rank = 300, max = 300,
			recipes = { [18560] = { learned = true, itemID = 14342 } } }
		W.professions = { { name = "Tailoring", rank = 300, max = 300, skillLine = 197 } }
		SK.Profile:BuildSelf()
		SK.Professions:Scan()
		W.advance(1)
		local list = SK.CraftIndex.Crafters(SK.CraftIndex:Rebuild(), 18560, SK.DBM:Guild(), W.now)
		assert.equal(1, #list)
		assert.is_not_nil(list[1].scanned)
	end)
end)

describe("v0.2.1 Copy as text", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pip", W.player.guid, { note = "secret note", officerNote = "officer secret" })
		W.member("Bob", "Player-1-B", { online = false, note = "bob's note" })
		W.professions = { { name = "Tailoring", rank = 300, max = 300, skillLine = 197 } }
		W.gear[1] = "|cffa335ee|Hitem:16914::::|h[Netherwind Crown]|h|r"
		W.talentNodes = { { id = 1, rank = 5, groups = { 2 }, spellID = 1001 } }
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
	end)

	it("strips colours, icons and links", function()
		assert.equal("Netherwind Crown x", SK.Export.Plain("|cffa335ee|Hitem:16914::::|h[Netherwind Crown]|h|r x"):gsub("[%[%]]", ""))
		assert.equal("yes", SK.Export.Plain("|A:UI-LFG-ReadyMark:12:12|a|cff7CD67Cyes|r"))
		assert.equal("a b", SK.Export.Plain("|T134400:14:14|ta b"))
		assert.equal("", SK.Export.Plain(nil))
	end)

	it("copies the Roster as shown, without notes or colour codes", function()
		SK.MainFrame:Show("roster")
		local text = SK.RosterTab:CopyText()
		assert.truthy(text:find("^Short Kings roster\n"))
		assert.truthy(text:find("- Pip · lvl 60 · Fire 0/5/0 · Tail 300 · ilvl 61 · online", 1, true))
		assert.truthy(text:find("- Bob · lvl 60 · offline", 1, true))
		assert.is_nil(text:find("note", 1, true))
		assert.is_nil(text:find("secret", 1, true))
		assert.is_nil(text:find("|c", 1, true))
		assert.equal(text, SK.DebugWindow.text)
	end)

	it("leaves your own gear and talents out when you don't share them", function()
		SK.DB.settings.share.gear = false
		SK.MainFrame:Show("roster")
		local text = SK.RosterTab:CopyText()
		assert.is_nil(text:find("ilvl", 1, true))
		assert.is_nil(text:find("Fire", 1, true))
	end)

	it("copies the raid view with attunement", function()
		SK.DB.settings.roster.raid = "ony"
		SK.MainFrame:Show("roster")
		local text = SK.RosterTab:CopyText()
		assert.truthy(text:find("Short Kings roster: Onyxia's Lair", 1, true))
		assert.truthy(text:find("not attuned", 1, true))
	end)

	it("copies a crafter list", function()
		local text = SK.Export.Crafters("|cff1eff00Arcanite Bar|r", "Alchemy", {
			{ name = "Ann", skill = 300, status = "addon" },
			{ name = "Dot", skill = 290, status = "online", via = "x", viaName = "Dotty", altOf = "Bob" },
			{ name = "Ben", skill = 0, status = "offline" },
		})
		assert.equal("Arcanite Bar (Alchemy) can be made by:\n- Ann (skill 300, online)\n" ..
			"- Dot (skill 290, online on Dotty, alt of Bob)\n- Ben (offline)", text)
		assert.truthy(SK.Export.Crafters("X", nil, {}):find("nobody yet", 1, true))
	end)
end)

describe("v0.2.1 update available", function()
	it("says so in the Roster counter when a guildmate runs a newer version", function()
		local SK, W = H.load()
		H.loadUI(SK)
		W.member("Pip", W.player.guid)
		W.member("Bob", "Player-1-B")
		SK.Identity:ReadRoster()
		SK.MainFrame:Show("roster")
		assert.is_nil(SK.RosterTab.countText:find("is out", 1, true))
		SK.Identity:Member("Player-1-B").addon = "0.9.0"
		SK.RosterTab:Refresh()
		assert.truthy(SK.RosterTab.countText:find("Short Kings 0.9.0 is out (you have 0.1.0)", 1, true))
	end)
end)
