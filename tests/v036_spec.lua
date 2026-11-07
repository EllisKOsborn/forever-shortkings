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
