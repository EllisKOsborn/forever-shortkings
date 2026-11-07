-- luacheck: globals C_ChatInfo Enum
-- Fixes from the first in-game test on launch day (5 Nov 2026, build 70790).
local H = require("tests.helpers.load")

describe("Sending is not blocked by Blizzard's 'restricted' flag", function()
	local SK, W, sent
	before_each(function()
		SK, W = H.load()
		W.member("Pocus Hocus", W.player.guid)
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		sent = H.captureSends(SK)
		-- What the live client reported: the flag says "restricted"...
		C_ChatInfo.AreOutgoingAddonChatMessagesRestricted = function() return true end
	end)

	it("still sends (the in-game test returned Success)", function()
		assert.is_true((SK.Compat.CanSendAddonMessages()))
		SK.Sync:SendHello()
		SK.Sync:Flush()
		assert.equal(1, #sent)
		assert.is_true(SK.Compat.AddonChatFlag()) -- reported in /sr debug only
	end)

	it("trial accounts are still blocked", function()
		W.trial = true
		local ok, why = SK.Compat.CanSendAddonMessages()
		assert.is_false(ok)
		assert.equal("trial", why)
	end)

	it("counts real send failures and warns once after several", function()
		local item = { tries = 0, msg = {} }
		SK.Sync.transport = function(_, _, _, _, cb, it) cb(it, 0, 0, 9) end -- GeneralError
		Enum.SendAddonMessageResult.GeneralError = 9
		for _ = 1, SK.Sync.SEND_FAIL_WARN do
			SK.Sync:Enqueue(nil, "GUILD", nil, "NORMAL", { t = "HI", c = {} })
			SK.Sync:Flush()
		end
		assert.equal(SK.Sync.SEND_FAIL_WARN, SK.Sync.stats.sendErrors)
		assert.equal("GeneralError", SK.Sync.lastSendError)
		local warned = 0
		for _, line in ipairs(W.prints) do
			if line:find("Sending to guildmates is failing", 1, true) then warned = warned + 1 end
		end
		assert.equal(1, warned)
		assert.is_table(item)
	end)

	it("treats AceComm's 'true' (sent) as success, not an error (v0.2.5 bug)", function()
		SK.Sync.transport = function(_, _, _, _, cb, it) cb(it, 10, 10, true) end
		for _ = 1, 6 do
			SK.Sync:Enqueue(nil, "GUILD", nil, "NORMAL", { t = "HI", c = {} })
			SK.Sync:Flush()
		end
		assert.equal(0, SK.Sync.stats.sendErrors or 0)
		for _, line in ipairs(W.prints) do
			assert.is_nil(line:find("is failing", 1, true))
		end
	end)

	it("counts 'false' (not sent) as a failure, or retries it during chat lockdown", function()
		SK.Sync.transport = function(_, _, _, _, cb, it) cb(it, 10, 10, false) end
		SK.Sync:SendHello()
		SK.Sync:Flush()
		assert.equal(1, SK.Sync.stats.sendErrors)
		assert.equal("not sent", SK.Sync.lastSendError)
		W.lockdown = true
		assert.equal("lockdown", (SK.Sync.SendOutcome(false)))
		W.lockdown = false
		assert.equal("ok", (SK.Sync.SendOutcome(true)))
		assert.equal("ok", (SK.Sync.SendOutcome(nil)))
		assert.equal("throttle", (SK.Sync.SendOutcome(3)))
	end)

	it("a success resets the failure streak", function()
		SK.Sync.failStreak = 3
		SK.Sync.transport = function(_, _, _, _, cb, it) cb(it, 0, 0, 0) end
		SK.Sync:SendHello()
		SK.Sync:Flush()
		assert.equal(0, SK.Sync.failStreak)
	end)
end)

describe("Sender names on Forever", function()
	it("matches the real format: 'First Surname' with a space, same as the roster", function()
		local SK, W = H.load()
		W.member("Pocus Hocus", W.player.guid)
		W.member("Bramble Cogwhistle", "Player-6937-000000BB")
		SK.Identity:ReadRoster()
		assert.equal("Player-6937-000000BB", (SK.Identity:SenderGUID("Bramble Cogwhistle", "Player-6937-000000BB", "GUILD")))
		assert.equal("Player-6937-000000BB", (SK.Identity:SenderGUID("Bramble Cogwhistle", "Player-6937-000000BB", "WHISPER")))
	end)
end)

describe("Missing enchants only at max level", function()
	local SK, W
	before_each(function() SK, W = H.load() end)
	local gear = { [1] = "item:100::::", [16] = "item:103::::" }

	it("ignores levelling characters", function()
		assert.same({}, SK.Data.Enchants.Missing(gear, "PRIEST", 1))
		assert.same({}, SK.Data.Enchants.Missing(gear, "PRIEST", 59))
	end)

	it("checks max-level characters (and unknown levels)", function()
		assert.same({ 1, 16 }, SK.Data.Enchants.Missing(gear, "PRIEST", 60))
		assert.same({ 1, 16 }, SK.Data.Enchants.Missing(gear, "PRIEST", nil))
	end)

	it("uses the game's max level when it can", function()
		_G.GetMaxLevelForPlayerExpansion = function() return 70 end
		assert.same({}, SK.Data.Enchants.Missing(gear, "PRIEST", 60))
		_G.GetMaxLevelForPlayerExpansion = nil
		assert.equal(60, SK.Compat.MaxPlayerLevel())
		assert.is_table(W)
	end)
end)
