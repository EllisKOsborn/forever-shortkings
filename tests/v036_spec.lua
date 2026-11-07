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

-- "Who has the addon" passed on between guildmates.

describe("v0.4.0 alt guessing removed", function()
	it("profiles from v0.3.6 guildmates (with 'This is my alt' marks) are still accepted", function()
		local SK = H.load()
		local p = { v = 1, guid = "P-1", updated = 1, hash = "h", claims = { "P-2", "P-3" } }
		assert.is_true((SK.Merge.Validate(p)))
		p.claims = { { "nested" } }
		assert.is_false((SK.Merge.Validate(p)))
		assert.is_nil(SK.Accounts)
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

describe("v0.4.0 alt rank", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pocus Hocus", W.player.guid, { rank = "Officer" })
		W.member("Ann", "P-A", { rank = "Member", level = 60 })
		W.member("Annbank", "P-A2", { rank = "Alt", level = 12 })
		W.member("Bobalt", "P-B2", { rank = "Alts", level = 60, online = false })
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		SK.DBM:Guild().profiles["P-A2"] = { v = 1, guid = "P-A2", updated = 1, hash = "h",
			profs = { [197] = { name = "Tailoring", rank = 300 } } }
	end)

	it("recognises the alt rank by name", function()
		assert.is_true(SK.Identity.IsAltRank({ rank = "Alt" }))
		assert.is_true(SK.Identity.IsAltRank({ rank = "alts" }))
		assert.is_true(SK.Identity.IsAltRank({ rank = "Alt rank" }))
		assert.is_false(SK.Identity.IsAltRank({ rank = "Altruist" }))
		assert.is_false(SK.Identity.IsAltRank({ rank = "Member" }))
		assert.is_false(SK.Identity.IsAltRank({}))
	end)

	it("leaves alt-rank characters out of the Overview, except professions", function()
		local o = SK.Overview.Build(SK.DBM:Guild(), W.now)
		assert.equal(2, o.members)          -- Pocus, Ann
		assert.equal(2, o.altRank)
		assert.equal(1, #o.without)         -- Ann; the alts aren't "not seen"
		assert.equal("Ann", o.without[1].name)
		assert.equal(1, o.profs[197].count) -- Annbank's Tailoring still counts
		local ony
		for _, r in ipairs(o.raids) do if r.key == "ony" then ony = r end end
		assert.equal(2, ony.eligible)       -- Pocus and Ann at 60; Bobalt (alt rank) isn't counted
	end)

	it("Not seen yet in the Roster lists real gaps before the alt rank", function()
		SK.MainFrame:Show("overview")
		SK.OverviewTab.guild.button:GetScript("OnClick")(SK.OverviewTab.guild.button)
		local items = SK.RosterTab.list.items
		assert.equal("Ann", items[1].name)    -- not seen, not alt rank
		assert.equal("Bobalt", items[2].name) -- not seen, alt rank: after the real gaps
		assert.equal(0, #SK.errors)
	end)
end)
