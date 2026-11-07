-- v0.3.6: guildmates still on v0.3.2 or earlier send the old message format,
-- which is dropped before decoding. It still proves they run Short Royalty,
-- so they must not be listed as "doesn't have it".
local H = require("tests.helpers.load")

describe("v0.3.6 old versions count as having the addon", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pocus Hocus", W.player.guid)
		W.member("Aura Guardian", "Player-6855-A")
		W.member("Some Stranger", "Player-6855-S")
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
	end)

	it("an old-format message marks the sender as running an old version", function()
		local before = SK.Overview.Build(SK.DBM:Guild(), W.now)
		assert.equal(2, #before.without)
		SK.Sync:OnCommReceived(SK.PREFIX, "\133old compressed message", "GUILD", "Aura Guardian")
		local o = SK.Overview.Build(SK.DBM:Guild(), W.now)
		assert.equal(1, #o.without)
		assert.equal("Some Stranger", o.without[1].name)
		assert.equal(1, o.outdated)
		local row
		for _, r in ipairs(SK.RosterTab.Rows(SK.DBM:Guild(), W.now)) do if r.name == "Aura Guardian" then row = r end end
		assert.is_true(row.hasAddon)
		assert.is_true(row.oldAddon)
		assert.is_true(row.outdated)
	end)

	it("doesn't mark strangers, and a real version replaces 'old'", function()
		SK.Sync:OnCommReceived(SK.PREFIX, "\133old", "WHISPER", "Not In Guild")
		assert.equal(2, #SK.Overview.Build(SK.DBM:Guild(), W.now).without)
		SK.Sync:OnCommReceived(SK.PREFIX, "\133old", "GUILD", "Aura Guardian")
		SK.Identity:Member("Player-6855-A").addon = "0.3.6"
		local row
		for _, r in ipairs(SK.RosterTab.Rows(SK.DBM:Guild(), W.now)) do if r.name == "Aura Guardian" then row = r end end
		assert.is_nil(row.oldAddon)
		assert.equal("0.3.6", row.addon)
	end)
end)

-- Alts of addon users (same Battle.net account, "This is my alt", guild notes)
-- and "who has the addon" passed on between guildmates.
local function profile(SK, guid, fields)
	local p = { v = 1, guid = guid, name = guid, updated = 1, gear = {} }
	for k, v in pairs(fields or {}) do p[k] = v end
	p.hash = SK.Profile.HashOf(p)
	return p
end

describe("v0.3.6 alts of players who have the addon", function()
	local SK, W, guild
	local ANN, ANNALT, BOB, BOBALT, CAT, DAN = "P-ANN", "P-ANN2", "P-BOB", "P-BOB2", "P-CAT", "P-DAN"
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pocus Hocus", W.player.guid)
		W.member("Ann Smith", ANN, { class = "PRIEST" })
		W.member("Annbank", ANNALT, { online = false })
		W.member("Bob Jones", BOB)
		W.member("Bobby Tables", BOBALT, { online = false, note = "Bob's alt!" })
		W.member("Cat Nap", CAT, { online = false, note = "the best" })
		W.member("Dan Dare", DAN, { online = false, officerNote = "alt - nobody we know" })
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		guild = SK.DBM:Guild()
		guild.profiles[ANN] = profile(SK, ANN, { claims = { ANNALT } })
		SK.Identity:Member(BOB).addon = "0.3.5"
	end)

	it("links by guild note, by 'this is my alt', and leaves the rest alone", function()
		local links = SK.Accounts.Current(guild, W.now)
		assert.same({ owner = BOB, how = "note" }, links[BOBALT])
		assert.same({ owner = ANN, how = "claim" }, links[ANNALT])
		assert.is_nil(links[CAT])
		assert.is_nil(links[DAN])
		assert.is_nil(links[ANN]) -- has the addon itself
	end)

	it("a shared Battle.net account wins, and only for people the game tells us about", function()
		local hasIt = function(g) return g == ANN end
		local members = guild.members
		local links = SK.Accounts.Links(members, hasIt, function() return nil end, { [ANN] = 77, [CAT] = 77, [DAN] = 99 })
		assert.same({ owner = ANN, how = "bnet" }, links[CAT])
		assert.is_nil(links[DAN])
	end)

	it("a note naming two different addon users, or a too-short name, links nobody", function()
		local members = {
			A = { name = "Ann One" }, B = { name = "Bob Two" }, E = { name = "Ed Three" },
			X = { name = "Xen", note = "alt of ann or bob" }, Y = { name = "Yo", note = "ed's alt" },
		}
		local hasIt = function(g) return g == "A" or g == "B" or g == "E" end
		local links = SK.Accounts.Links(members, hasIt, function() return nil end, {})
		assert.is_nil(links.X)
		assert.is_nil(links.Y) -- "Ed" is under MIN_NAME letters
	end)

	it("the Overview lists them separately, with who they belong to", function()
		local o = SK.Overview.Build(guild, W.now)
		local names = {}
		for _, w in ipairs(o.without) do names[#names + 1] = w.name end
		table.sort(names)
		assert.same({ "Cat Nap", "Dan Dare" }, names)
		assert.equal(2, #o.altsOf)
		assert.equal("Ann Smith", o.altsOf[1].ownerName)
		local text = SK.OverviewTab.GuildText(o)
		assert.truthy(text:find("Alts of players who have it", 1, true))
		local tt = { lines = {} }
		function tt:AddLine(t) self.lines[#self.lines + 1] = t end
		function tt:AddDoubleLine(l, r) self.lines[#self.lines + 1] = l .. " | " .. r end
		SK.OverviewTab.AltsTip(tt, o.altsOf)
		local all = table.concat(tt.lines, "\n")
		assert.truthy(all:find("Annbank", 1, true) and all:find("they said so", 1, true))
		assert.truthy(all:find("Bobby Tables", 1, true) and all:find("guild note", 1, true))
	end)

	it("the Roster says 'alt of' and sorts them after real gaps", function()
		local rows = SK.RosterTab.Rows(guild, W.now)
		local byName = {}
		for _, r in ipairs(rows) do byName[r.name] = r end
		assert.equal("Bob Jones", byName["Bobby Tables"].altOf.name)
		assert.is_true(SK.RosterTab.ByVersion(byName["Cat Nap"], byName["Bobby Tables"]))
		assert.is_false(SK.RosterTab.ByVersion(byName["Bobby Tables"], byName["Cat Nap"]))
	end)
end)

describe("v0.3.6 'This is my alt'", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pocus Hocus", W.player.guid)
		W.member("Pocusbank", "P-BANK", { online = false })
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
	end)

	it("goes into our profile, passes guildmates' check, and can be undone", function()
		SK.Profile:ToggleMyAlt("P-BANK")
		local own = SK.Profile:Own()
		assert.same({ "P-BANK" }, own.claims)
		local pub = SK.DBM:Guild().profiles[W.player.guid]
		assert.same({ "P-BANK" }, pub.claims)
		assert.is_true((SK.Merge.Validate(pub)))
		-- older versions (no "claims" check) accept it as a plain extra field
		local check = SK.Merge.FIELDS.claims
		SK.Merge.FIELDS.claims = nil
		assert.is_true((SK.Merge.Validate(pub)))
		SK.Merge.FIELDS.claims = check
		SK.Profile:ToggleMyAlt("P-BANK")
		assert.is_nil(SK.Profile:Own().claims)
	end)

	it("refuses junk claims from others", function()
		assert.is_false((SK.Merge.Validate({ v = 1, guid = "X-1", updated = 1, hash = "h", claims = { { "nested" } } })))
		local many = {}
		for i = 1, SK.Merge.LIMITS.family + 1 do many[i] = "P-" .. i end
		assert.is_false((SK.Merge.Validate({ v = 1, guid = "X-1", updated = 1, hash = "h", claims = many })))
	end)

	it("the Character tab button marks and unmarks", function()
		SK.MainFrame:Show("character")
		local tab = SK.CharacterTab
		tab:ShowCharacter("P-BANK")
		assert.is_true(tab.myAlt:IsShown())
		assert.equal("This is my alt", tab.myAlt.label:GetText())
		tab.myAlt:GetScript("OnClick")(tab.myAlt)
		assert.is_true(SK.DB.myAlts["P-BANK"])
		assert.equal("Not my alt", tab.myAlt.label:GetText())
		tab:ShowCharacter(nil) -- our own character: no button
		assert.is_false(tab.myAlt:IsShown())
		assert.equal(0, #SK.errors)
	end)
end)

describe("v0.3.6 passing on who has the addon", function()
	local SK, W
	local ANN, BOB, CAT = "Player-1-A", "Player-1-B", "Player-1-C"
	before_each(function()
		SK, W = H.load()
		W.member("Pocus Hocus", W.player.guid)
		W.member("Ann", ANN)
		W.member("Bob", BOB, { online = false })
		W.member("Cat", CAT, { online = false })
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
	end)

	it("learns from a guildmate's SQ, without taking a version from it", function()
		SK.Sync:OnCommReceived(SK.PREFIX, H.peerMessage(SK, "SQ", { k = {}, a = { ANN, BOB, "Not-A-Member" } }, ANN, "0.3.6"),
			"GUILD", "Ann")
		local bob = SK.Identity:Member(BOB)
		assert.truthy(bob.addonRelay)
		assert.is_nil(bob.addon)
		assert.is_true(SK.Identity.HasAddon(BOB, bob, nil))
		assert.is_false(SK.Identity.HasAddon(CAT, SK.Identity:Member(CAT), nil))
	end)

	it("sends who it knows in its SQ, and answers a newer SQ even with no profiles to offer", function()
		local sent = H.captureSends(SK)
		SK.Identity:Member(BOB).addon = "0.3.5"
		SK.Sync:SendQuery()
		SK.Sync:Flush()
		local sq = sent[#sent].msg
		assert.equal("SQ", sq.t)
		assert.truthy(table.concat(sq.a, ","):find(BOB, 1, true))
		-- Ann (new version) doesn't know Bob: we offer just the list
		local k = { [W.player.guid] = W.now + 60 } -- she already has our profile
		SK.Sync:OnCommReceived(SK.PREFIX, H.peerMessage(SK, "SQ", { k = k, a = { ANN } }, ANN, "0.3.6"), "GUILD", "Ann")
		W.advance(10)
		SK.Sync:Flush()
		local so = sent[#sent].msg
		assert.equal("SO", so.t)
		assert.same({}, so.g)
		-- an old SQ (no list) gets nothing extra
		local before = #sent
		SK.Sync:OnCommReceived(SK.PREFIX, H.peerMessage(SK, "SQ", { k = k }, ANN, "0.3.5"), "GUILD", "Ann")
		W.advance(10)
		SK.Sync:Flush()
		assert.equal(before, #sent)
	end)

	it("an SO with only the list doesn't use up the 'accept one offer' slot", function()
		SK.Sync:OnCommReceived(SK.PREFIX, H.peerMessage(SK, "SO", { to = W.player.guid, g = {}, a = { BOB } }, ANN, "0.3.6"),
			"GUILD", "Ann")
		assert.is_nil(SK.Sync.offerAcceptedAt)
		assert.truthy(SK.Identity:Member(BOB).addonRelay)
	end)
end)

describe("v0.3.6 Battle.net account lookup", function()
	it("reads the guild community and Battle.net friends, and ignores what isn't a number", function()
		local SK = H.load()
		_G.C_Club = {
			GetGuildClubId = function() return 1 end,
			GetClubMembers = function() return { 10, 11, 12 } end,
			GetMemberInfo = function(_, id)
				return ({ [10] = { guid = "G-A", bnetAccountId = 5 }, [11] = { guid = "G-B" },
					[12] = { guid = "G-C", bnetAccountId = "secret" } })[id]
			end,
		}
		_G.C_BattleNet = { GetAccountInfoByGUID = function(g) if g == "G-B" then return { bnetAccountID = 5 } end end }
		local ids, n = SK.Compat.AccountIDs({ "G-A", "G-B", "G-C" })
		assert.same({ ["G-A"] = 5, ["G-B"] = 5 }, ids)
		assert.equal(2, n)
		_G.C_Club, _G.C_BattleNet = nil, nil
		assert.same({}, (SK.Compat.AccountIDs({ "G-A" })))
	end)
end)
