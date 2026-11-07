-- Tests for v0.1.2: raid attunement filter, "Ask for latest", faster updates.
local H = require("tests.helpers.load")

local loadUI = H.loadUI

local function profile(SK, guid, fields)
	local p = { v = 1, guid = guid, name = guid, updated = 1, gear = {} }
	for k, v in pairs(fields or {}) do p[k] = v end
	p.hash = SK.Profile.HashOf(p)
	return p
end

describe("v0.1.2 raid attunement rows", function()
	local SK, W, guild
	before_each(function()
		SK, W = H.load()
		loadUI(SK)
		W.member("Pip", W.player.guid, { level = 60 })
		W.member("Ann", "A", { level = 60 })
		W.member("Ben", "B", { level = 60 })
		W.member("Cid", "C", { level = 60 })     -- no data
		W.member("Dot", "D", { level = 60 })     -- gear hidden
		W.member("Eve", "E", { level = 42 })     -- below max level
		W.member("Ann Alt", "A2", { level = 60 }) -- Ann's alt, attuned
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf() -- Pip: quest 6502 not done -> ony = false
		guild = SK.DBM:Guild()
		local P = guild.profiles
		P.A = profile(SK, "A", { att = { ony = true }, family = { "A2" }, level = 60 })
		P.A2 = profile(SK, "A2", { att = { ony = true }, family = { "A" }, level = 60, main = "A" })
		P.B = profile(SK, "B", { att = { ony = false }, level = 60 })
		P.D = profile(SK, "D", { att = { ony = true }, hidden = { gear = true }, level = 60 })
		P.E = profile(SK, "E", { att = { ony = true }, level = 42 })
	end)

	local function byGuid(rows)
		local out = {}
		for _, r in ipairs(rows) do out[r.guid] = r end
		return out
	end

	it("gives every character its own row with yes / no / unknown", function()
		local rows, counts, maxLevel = SK.RosterTab.AttunementRows(guild, "ony", "all", false, nil, W.now)
		assert.equal(60, maxLevel)
		local r = byGuid(rows)
		assert.equal(7, #rows)
		assert.equal("yes", r.A.att)
		assert.equal("yes", r.A2.att)       -- alts are not folded into their main
		assert.equal("no", r.B.att)
		assert.equal("unknown", r.C.att)    -- no Short Royalty data
		assert.equal("unknown", r.D.att)    -- gear/talents hidden
		assert.equal("no", r[W.player.guid].att)
		assert.same({ yes = 3, no = 2, unknown = 2, none = 0 }, counts)
	end)

	it("marks alts with the name of their main", function()
		local r = byGuid(SK.RosterTab.AttunementRows(guild, "ony", "all", false, nil, W.now))
		assert.equal("Ann", r.A2.altOf)
		assert.is_nil(r.A.altOf)
	end)

	it("max level only drops lower characters from rows and counts", function()
		local rows, counts = SK.RosterTab.AttunementRows(guild, "ony", "all", true, nil, W.now)
		assert.equal(6, #rows)
		assert.is_nil(byGuid(rows).E)
		assert.same({ yes = 2, no = 2, unknown = 2, none = 0 }, counts)
	end)

	it("filters by status but counts everything", function()
		local yes, counts = SK.RosterTab.AttunementRows(guild, "ony", "yes", true, nil, W.now)
		assert.equal(2, #yes)
		assert.same({ yes = 2, no = 2, unknown = 2, none = 0 }, counts)
		local no = SK.RosterTab.AttunementRows(guild, "ony", "no", true, nil, W.now)
		assert.equal(2, #no)
		local unknown = SK.RosterTab.AttunementRows(guild, "ony", "unknown", true, nil, W.now)
		local u = byGuid(unknown)
		assert.truthy(u.C and u.D)
	end)

	it("applies the search box too", function()
		local rows, counts = SK.RosterTab.AttunementRows(guild, "ony", "all", false, "ann", W.now)
		assert.equal(2, #rows)
		assert.same({ yes = 2, no = 0, unknown = 0, none = 0 }, counts)
	end)

	it("treats raids whose quests are TODO as unknown for everyone", function()
		local rows, counts = SK.RosterTab.AttunementRows(guild, "naxx", "all", false, nil, W.now)
		assert.equal(7, #rows)
		assert.same({ yes = 0, no = 0, unknown = 7, none = 0 }, counts)
	end)

	it("returns nothing for an unknown raid key", function()
		local rows = SK.RosterTab.AttunementRows(guild, "nope", "all", false, nil, W.now)
		assert.equal(0, #rows)
	end)

	it("remembers the raid and filter, and the Roster refreshes in raid mode", function()
		assert.is_true(SK.DB.settings.roster.maxLevelOnly) -- default on
		assert.equal("all", SK.DB.settings.roster.attFilter)
		SK.MainFrame:Show("roster")
		SK.DB.settings.roster.raid = "ony"
		SK.DB.settings.roster.attFilter = "no"
		SK.RosterTab:Refresh()
		assert.equal(2, #SK.RosterTab.attList.items)
		assert.truthy(SK.RosterTab.attCount:GetText():find("2 attuned · 2 not · 2 unknown", 1, true))
		SK.DB.settings.roster.raid = "hyjal"
		SK.RosterTab:Refresh()
		assert.truthy(SK.RosterTab.attCount:GetText():find("No attunement needed", 1, true))
		SK.DB.settings.roster.raid = "mc" -- not in the first wave: back to the normal Roster
		SK.RosterTab:Refresh()
		assert.is_nil(SK.DB.settings.roster.raid)
		SK.DB.settings.roster.raid = nil
		SK.RosterTab:Refresh()
		assert.is_true(SK.RosterTab.list:IsShown())
	end)
end)

describe("v0.1.2 Ask for latest", function()
	local SK, W, sent
	local BOB, BOBALT = "Player-1-B", "Player-1-B2"
	before_each(function()
		SK, W = H.load()
		loadUI(SK)
		W.member("Pip", W.player.guid)
		W.member("Bob", BOB)
		W.member("Bobby", BOBALT)
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		sent = H.captureSends(SK)
		local g = SK.DBM:Guild()
		g.profiles[BOB] = profile(SK, BOB, { family = { BOBALT }, source = "owner" })
		g.profiles[BOBALT] = profile(SK, BOBALT, { family = { BOB }, source = "owner" })
	end)

	local function heardFrom(guid) SK.Identity:Member(guid).addonSeen = W.now end

	it("needs the character or a linked alt online with the addon", function()
		assert.is_nil(SK.Sync:FreshSource(BOB))            -- online, but no addon heard
		local ok, why = SK.Sync:RequestFresh(BOB)
		assert.is_false(ok)
		assert.equal("offline", why)
		heardFrom(BOBALT)
		assert.equal(BOBALT, SK.Sync:FreshSource(BOB))     -- reachable via the alt
		heardFrom(BOB)
		assert.equal(BOB, SK.Sync:FreshSource(BOB))        -- the character itself first
		assert.is_nil(SK.Sync:FreshSource(W.player.guid))  -- never for our own characters
	end)

	it("whispers an RQ for that GUID, at most once per 30 s", function()
		heardFrom(BOBALT)
		assert.is_true(SK.Sync:RequestFresh(BOB))
		SK.Sync:Flush()
		assert.equal(1, #sent)
		assert.equal("RQ", sent[1].msg.t)
		assert.equal("WHISPER", sent[1].dist)
		assert.equal("Bobby", sent[1].target)
		assert.same({ BOB }, sent[1].msg.w)
		local ok, why = SK.Sync:RequestFresh(BOB)
		assert.is_false(ok)
		assert.equal("wait", why)
		W.advance(29)
		assert.is_false((SK.Sync:RequestFresh(BOB)))
		W.advance(2)
		assert.is_true(SK.Sync:RequestFresh(BOB))
	end)

	it("the owner rebuilds its profile before answering", function()
		W.gear[1] = "|cffa335ee|Hitem:16914::::|h[Netherwind Crown]|h|r" -- changed since the last build
		W.advance(60)
		local before = SK.DBM:Guild().profiles[W.player.guid].hash
		SK.Sync:OnCommReceived(SK.PREFIX, H.peerMessage(SK, "RQ", { w = { W.player.guid } }, BOB), "WHISPER", "Bob")
		SK.Sync:Flush()
		assert.equal(1, #sent)
		assert.equal("PR", sent[1].msg.t)
		assert.are_not.equal(before, sent[1].msg.prof.hash)
		assert.equal("|cffa335ee|Hitem:16914::::|h[Netherwind Crown]|h|r", sent[1].msg.prof.gear[1])
	end)

	it("rebuilds at most once per 10 s and never in combat", function()
		local builds = 0
		local real = SK.Profile.BuildSelf
		SK.Profile.BuildSelf = function(...) builds = builds + 1; return real(...) end
		local function ask() SK.Sync.handlers.RQ(SK.Sync, { w = { W.player.guid } }, BOB) end
		ask(); ask()
		assert.equal(1, builds)
		W.advance(11)
		ask()
		assert.equal(2, builds)
		W.advance(11)
		W.combat = true
		ask()
		assert.equal(2, builds)
		-- A request only for someone else's character does not rebuild.
		W.combat = false
		W.advance(11)
		SK.Sync.handlers.RQ(SK.Sync, { w = { BOB } }, BOBALT)
		assert.equal(2, builds)
	end)

	it("tells the UI when an answer arrives, even if nothing changed", function()
		local answered
		SK:On("PROFILE_ANSWERED", function(g) answered = g end)
		local p = SK.DBM:Guild().profiles[BOB]
		SK.Sync.handlers.PR(SK.Sync, { prof = SK.CopyTable(p) }, BOB)
		assert.equal(BOB, answered)
	end)

	it("status text: asking, timed out, answered", function()
		local now = W.now
		assert.equal("Asked for the latest data…", SK.CharacterTab.AskStatus(now - 5, nil, now, 30))
		assert.truthy(SK.CharacterTab.AskStatus(now - 31, nil, now, 30):find("No answer", 1, true))
		assert.equal("Got their latest data", SK.CharacterTab.AskStatus(nil, now - 5, now, 30))
		assert.is_nil(SK.CharacterTab.AskStatus(nil, nil, now, 30))
	end)

	it("the Character tab button works end to end", function()
		heardFrom(BOB)
		SK.CharacterTab:ShowCharacter(BOB)
		assert.is_false(SK.CharacterTab.askLatest.disabled)
		SK.CharacterTab.askLatest:GetScript("OnClick")(SK.CharacterTab.askLatest)
		assert.truthy(SK.CharacterTab.asked[BOB])
		assert.truthy(SK.CharacterTab.meta:GetText():find("Asked for the latest", 1, true))
		SK:Fire("PROFILE_ANSWERED", BOB)
		assert.is_nil(SK.CharacterTab.asked[BOB])
		SK.CharacterTab:ShowCharacter(BOBALT) -- alt is reachable through Bob
		assert.is_false(SK.CharacterTab.askLatest.disabled)
		SK.Identity:Member(BOB).addonSeen = nil
		SK.CharacterTab:Refresh()
		assert.is_true(SK.CharacterTab.askLatest.disabled)
	end)
end)

describe("v0.1.2 faster updates", function()
	it("announces changes 30 s after they happen", function()
		local SK = H.load()
		assert.equal(30, SK.Sync.HELLO_DEBOUNCE)
	end)
end)
