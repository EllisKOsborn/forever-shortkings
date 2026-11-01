local H = require("tests.helpers.load")

describe("Sync", function()
	local SK, W, sent
	local BOB, CAT = "Player-1-B", "Player-1-C"

	local function bobProfile(updated, extra)
		local p = { v = 1, guid = BOB, name = "Bob", class = "WARRIOR", updated = updated, gear = {} }
		for k, v in pairs(extra or {}) do p[k] = v end
		p.hash = SK.Profile.HashOf(p)
		return p
	end

	local function deliver(t, fields, sender, fromGUID, dist)
		SK.Sync:OnCommReceived(SK.PREFIX, H.peerMessage(SK, t, fields, fromGUID), dist or "GUILD", sender)
	end

	before_each(function()
		SK, W = H.load()
		W.member("Pip", W.player.guid)
		W.member("Bob", BOB)
		W.member("Cat", CAT)
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		sent = H.captureSends(SK)
	end)

	it("announces only this account's characters", function()
		SK.Sync:SendHello()
		SK.Sync:Flush()
		assert.equal(1, #sent)
		assert.equal("HI", sent[1].msg.t)
		assert.equal("GUILD", sent[1].dist)
		assert.equal(1, #sent[1].msg.c)
		assert.equal(W.player.guid, sent[1].msg.c[1].g)
	end)

	it("requests missing profiles by whisper after a HI", function()
		deliver("HI", { c = { { g = BOB, u = W.now, h = "abc" } } }, "Bob", BOB)
		SK.Sync:Flush()
		assert.equal(1, #sent)
		assert.equal("RQ", sent[1].msg.t)
		assert.equal("WHISPER", sent[1].dist)
		assert.equal("Bob", sent[1].target)
		assert.same({ BOB }, sent[1].msg.w)
		assert.is_not_nil(SK.Identity:Member(BOB).addon)
	end)

	it("does not request a profile it already has (same hash)", function()
		local p = bobProfile(W.now); p.source = "owner"
		SK.DBM:Guild().profiles[BOB] = p
		deliver("HI", { c = { { g = BOB, u = p.updated, h = p.hash } } }, "Bob", BOB)
		SK.Sync:Flush()
		assert.equal(0, #sent)
	end)

	it("ignores HI entries for non-members", function()
		deliver("HI", { c = { { g = "Player-9-X", u = W.now, h = "x" } } }, "Bob", BOB)
		SK.Sync:Flush()
		assert.equal(0, #sent)
	end)

	it("answers a request with profiles at BULK priority", function()
		SK.DBM:Guild().profiles[BOB] = bobProfile(W.now)
		deliver("RQ", { w = { W.player.guid, BOB } }, "Cat", CAT, "WHISPER")
		SK.Sync:Flush()
		assert.equal(2, #sent)
		for _, s in ipairs(sent) do
			assert.equal("PR", s.msg.t)
			assert.equal("BULK", s.prio)
			assert.equal("Cat", s.target)
			assert.is_nil(s.msg.prof.source)
		end
	end)

	it("stores an owner profile and records the source", function()
		deliver("PR", { prof = bobProfile(W.now) }, "Bob", BOB, "WHISPER")
		local p = SK.DBM:Guild().profiles[BOB]
		assert.equal("owner", p.source)
		assert.equal(1, SK.Sync.stats.accepted)
	end)

	it("keeps a relayed copy from overwriting a newer owner copy", function()
		deliver("PR", { prof = bobProfile(W.now, { ilvl = 70 }) }, "Bob", BOB, "WHISPER")
		deliver("PR", { prof = bobProfile(W.now - 50, { ilvl = 10 }) }, "Cat", CAT, "WHISPER")
		assert.equal(70, SK.DBM:Guild().profiles[BOB].ilvl)
	end)

	it("refuses profiles of our own characters from others", function()
		local mine = SK.Profile:Own()
		local fake = SK.CopyTable(mine)
		fake.source = nil
		fake.ilvl = 1
		fake.updated = W.now + 10
		fake.hash = SK.Profile.HashOf(fake)
		deliver("PR", { prof = fake }, "Bob", BOB, "WHISPER")
		assert.equal("self", SK.Profile:Own().source)
		assert.are_not.equal(1, SK.Profile:Own().ilvl)
	end)

	it("drops messages from unknown senders and newer protocols", function()
		deliver("PR", { prof = bobProfile(W.now) }, "Stranger", "Player-9-Z", "WHISPER")
		assert.is_nil(SK.DBM:Guild().profiles[BOB])
		local msg = SK.Codec.Encode({ t = "PR", p = SK.PROTOCOL + 1, s = BOB, prof = bobProfile(W.now) })
		SK.Sync:OnCommReceived(SK.PREFIX, msg, "WHISPER", "Bob")
		assert.is_nil(SK.DBM:Guild().profiles[BOB])
	end)

	it("ignores its own echo on the guild channel", function()
		SK.DBM:Guild().profiles[BOB] = bobProfile(W.now)
		deliver("RQ", { w = { BOB } }, "Pip", W.player.guid)
		deliver("SQ", { k = {} }, "Pip", W.player.guid)
		W.advance(10)
		SK.Sync:Flush()
		assert.equal(0, #sent)
	end)

	describe("pausing", function()
		it("queues sends in combat and sends afterwards", function()
			W.combat = true
			SK.Sync:SendHello()
			SK.Sync:Flush()
			assert.equal(0, #sent)
			W.combat = false
			SK.Sync:Flush()
			assert.equal(1, #sent)
		end)

		for _, kind in ipairs({ "raid", "party", "pvp", "arena" }) do
			it("pauses inside " .. kind .. " instances", function()
				W.instance = kind
				SK.Sync:SendHello()
				SK.Sync:Flush()
				assert.equal(0, #sent)
			end)
		end

		it("buffers incoming messages while paused", function()
			W.lockdown = true
			deliver("PR", { prof = bobProfile(W.now) }, "Bob", BOB, "WHISPER")
			assert.is_nil(SK.DBM:Guild().profiles[BOB])
			W.lockdown = false
			SK.Sync:DrainBuffer()
			assert.is_not_nil(SK.DBM:Guild().profiles[BOB])
		end)

		it("re-queues a message that hit chat lockdown", function()
			SK.Sync.transport = function(_, _, _, _, cb, item)
				sent[#sent + 1] = true
				cb(item, 0, 0, 11)
			end
			SK.Sync:SendHello()
			SK.Sync:Flush()
			assert.equal(1, #SK.Sync.queue)
		end)
	end)

	it("never sends from a trial account", function()
		W.trial = true
		SK.Sync:SendHello()
		SK.Sync:Flush()
		assert.equal(0, #sent)
	end)

	it("does nothing when sync is turned off", function()
		SK.DB.settings.sync = false
		deliver("PR", { prof = bobProfile(W.now) }, "Bob", BOB, "WHISPER")
		SK.Sync:SendHello()
		SK.Sync:Flush()
		assert.is_nil(SK.DBM:Guild().profiles[BOB])
		assert.equal(0, #sent)
	end)

	describe("offline backfill (SQ/SO)", function()
		it("offers newer copies after a random delay", function()
			SK.DBM:Guild().profiles[BOB] = bobProfile(W.now)
			deliver("SQ", { k = { [BOB] = W.now - 100 } }, "Cat", CAT)
			SK.Sync:Flush()
			assert.equal(0, #sent)
			W.advance(SK.Sync.OFFER_DELAY_MAX + 1)
			SK.Sync:Flush()
			assert.equal(1, #sent)
			assert.equal("SO", sent[1].msg.t)
			assert.equal(CAT, sent[1].msg.to)
		end)

		it("stays quiet if another member offered first", function()
			SK.DBM:Guild().profiles[BOB] = bobProfile(W.now)
			deliver("SQ", { k = {} }, "Cat", CAT)
			deliver("SO", { to = CAT, g = { BOB } }, "Bob", BOB)
			W.advance(SK.Sync.OFFER_DELAY_MAX + 1)
			SK.Sync:Flush()
			assert.equal(0, #sent)
		end)

		it("accepts one offer and requests from that member", function()
			deliver("SO", { to = W.player.guid, g = { BOB, "Player-9-X", W.player.guid } }, "Cat", CAT)
			deliver("SO", { to = W.player.guid, g = { BOB } }, "Bob", BOB)
			SK.Sync:Flush()
			assert.equal(1, #sent)
			assert.equal("RQ", sent[1].msg.t)
			assert.equal("Cat", sent[1].target)
			assert.same({ BOB }, sent[1].msg.w)
		end)
	end)

	it("compares versions", function()
		assert.is_true(SK.Sync.versionNewer("0.2.0", "0.1.9"))
		assert.is_false(SK.Sync.versionNewer("0.1.0", "0.1.0"))
		assert.is_false(SK.Sync.versionNewer("dev", "0.1.0"))
	end)
end)
