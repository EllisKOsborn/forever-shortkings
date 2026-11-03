local H = require("tests.helpers.load")

describe("Identity", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		W.member("Pip Sparkfuse", W.player.guid)
		W.member("Bob-Ruleset", "Player-1-B")
		W.member("Tink Gearloose", "Player-1-C")
		W.member("Tink Wobble", "Player-1-D")
		SK.Identity:ReadRoster()
	end)

	it("resolves exact and realm-less sender names", function()
		assert.equal("Player-1-B", SK.Identity:ResolveSender("Bob-Ruleset"))
		assert.equal("Player-1-B", SK.Identity:ResolveSender("bob"))
		assert.equal("Player-1-C", SK.Identity:ResolveSender("Tink Gearloose"))
	end)

	it("does not guess between members who share a first name", function()
		assert.is_nil(SK.Identity:ResolveSender("Tink"))
	end)

	it("cross-checks the GUID a message claims", function()
		assert.equal("Player-1-B", (SK.Identity:SenderGUID("Bob-Ruleset", "Player-1-B")))
		assert.is_nil((SK.Identity:SenderGUID("Bob-Ruleset", "Player-1-C")))
		-- unknown format, but first word matches the claimed member (guild channel)
		assert.equal("Player-1-C", (SK.Identity:SenderGUID("Tink-Ruleset", "Player-1-C", "GUILD")))
		assert.is_nil((SK.Identity:SenderGUID("Stranger", "Player-1-C", "GUILD")))
	end)

	it("only trusts a loose name match by whisper once the guild channel confirmed it", function()
		-- A stranger "Tink Jones" whispering as our Tink Gearloose is refused...
		local guid, why = SK.Identity:SenderGUID("Tink Jones", "Player-1-C", "WHISPER")
		assert.is_nil(guid)
		assert.equal("unconfirmed sender", why)
		-- ...but once that sender string was seen on the guild channel (where
		-- only members can send), its whispers are accepted.
		assert.equal("Player-1-C", (SK.Identity:SenderGUID("Tink-Ruleset", "Player-1-C", "GUILD")))
		assert.equal("Player-1-C", (SK.Identity:SenderGUID("Tink-Ruleset", "Player-1-C", "WHISPER")))
		-- A confirmed sender string can't then claim to be someone else.
		assert.is_nil((SK.Identity:SenderGUID("Tink-Ruleset", "Player-1-D", "GUILD")))
	end)

	it("knows which senders could be members before decoding anything", function()
		assert.is_true(SK.Identity:KnownSender("Bob-Ruleset"))
		assert.is_true(SK.Identity:KnownSender("Tink-Elsewhere")) -- possible loose match
		assert.is_false(SK.Identity:KnownSender("Stranger"))
		assert.is_false(SK.Identity:KnownSender(nil))
	end)

	it("records members and last seen", function()
		local m = SK.Identity:Member("Player-1-B")
		assert.equal("Bob-Ruleset", m.name)
		assert.equal(W.now, m.lastSeen)
		assert.is_true(SK.Identity.loaded)
	end)
end)

describe("Pruning", function()
	local SK, W
	local DAY = 86400
	before_each(function()
		SK, W = H.load()
		for i = 1, 10 do W.member("M" .. i, "Player-1-" .. i) end
		SK.Identity:ReadRoster()
		local g = SK.DBM:Guild()
		g.profiles["Player-1-10"] = { guid = "Player-1-10", updated = W.now }
	end)

	it("marks leavers, and deletes them after 30 days", function()
		table.remove(W.roster, 10)
		SK.Identity:ReadRoster()
		local g = SK.DBM:Guild()
		assert.is_not_nil(g.members["Player-1-10"].leftAt)
		assert.is_false(SK.Identity:IsMember("Player-1-10"))
		assert.is_not_nil(g.profiles["Player-1-10"])

		W.now = W.now + 31 * DAY
		SK.Identity:ReadRoster()
		assert.is_nil(g.members["Player-1-10"])
		assert.is_nil(g.profiles["Player-1-10"])
	end)

	it("clears leftAt when someone rejoins", function()
		local leaver = table.remove(W.roster, 10)
		SK.Identity:ReadRoster()
		W.now = W.now + 10 * DAY
		W.roster[#W.roster + 1] = leaver
		SK.Identity:ReadRoster()
		assert.is_nil(SK.DBM:Guild().members["Player-1-10"].leftAt)
	end)

	it("does not start the clock on a half-loaded roster", function()
		for _ = 1, 6 do table.remove(W.roster) end
		SK.Identity:ReadRoster()
		for _, m in pairs(SK.DBM:Guild().members) do assert.is_nil(m.leftAt) end
	end)

	it("does not mark leavers when offline members are hidden", function()
		W.showOffline = false
		table.remove(W.roster, 10)
		SK.Identity:ReadRoster()
		assert.is_nil(SK.DBM:Guild().members["Player-1-10"].leftAt)
	end)
end)
