-- v0.3.3: our own numbered pieces replace AceComm's multi-part messages,
-- which arrived corrupted between two players on different Forever servers
-- (owner + Aura, 7 Nov 2026: "bad compression" on both sides).
local H = require("tests.helpers.load")

describe("Frames", function()
	local SK, F
	before_each(function()
		SK = H.load()
		F = SK.Frames
	end)

	local function payload(n)
		local t = {}
		for i = 1, n do t[i] = string.char(1 + (i * 37) % 255) end -- every byte value but 0
		return table.concat(t)
	end

	it("sends short messages whole", function()
		local wires = F.Split("hello")
		assert.equal(1, #wires)
		assert.equal(F.WHOLE .. "hello", wires[1])
		assert.equal("hello", (F.Add(F.NewAssembler(), "Bob", wires[1], 0)))
	end)

	it("splits long messages into numbered pieces that each fit in one addon message", function()
		local text = payload(5000)
		local wires = F.Split(text)
		assert.equal(math.ceil(5000 / F.PIECE_DATA), #wires)
		for _, w in ipairs(wires) do
			assert.is_true(#w <= 255)
			assert.is_nil(w:byte(1) >= 1 and w:byte(1) <= 9 or nil) -- never an AceComm control byte
		end
	end)

	it("rebuilds a message whatever order the pieces arrive in", function()
		local text = payload(3000)
		for _, order in ipairs({ "forward", "reverse", "shuffle" }) do
			local wires = F.Split(text)
			if order == "reverse" then
				local r = {}
				for i = #wires, 1, -1 do r[#r + 1] = wires[i] end
				wires = r
			elseif order == "shuffle" then
				math.randomseed(7)
				for i = #wires, 2, -1 do local j = math.random(i); wires[i], wires[j] = wires[j], wires[i] end
			end
			local asm, out = F.NewAssembler(), nil
			for i, w in ipairs(wires) do
				local got, why = F.Add(asm, "Aura Guardian", w, 0)
				if i < #wires then assert.is_nil(got); assert.equal("piece", why) else out = got end
			end
			assert.equal(text, out, order)
		end
	end)

	it("ignores duplicate pieces", function()
		local wires = F.Split(payload(600))
		local asm = F.NewAssembler()
		assert.is_nil((F.Add(asm, "Bob", wires[1], 0)))
		assert.equal("duplicate", select(2, F.Add(asm, "Bob", wires[1], 0)))
		assert.equal(1, asm.stats.duplicates)
		for i = 2, #wires do F.Add(asm, "Bob", wires[i], 0) end
		assert.is_nil(asm.open.Bob)
	end)

	it("keeps two senders' messages apart, and two messages from one sender", function()
		local a, b = payload(700), payload(900):reverse()
		local wa, wb = F.Split(a), F.Split(b)
		local asm, got = F.NewAssembler(), {}
		for i = 1, math.max(#wa, #wb) do
			if wa[i] then got.a = F.Add(asm, "Bob", wa[i], 0) or got.a end
			if wb[i] then got.b = F.Add(asm, "Bob", wb[i], 0) or got.b end
		end
		assert.equal(a, got.a)
		assert.equal(b, got.b)
	end)

	it("reports a lost piece after the timeout, naming the sender and the gap", function()
		local wires = F.Split(payload(1000))
		local asm = F.NewAssembler()
		for i = 1, #wires do if i ~= 2 then F.Add(asm, "Aura Guardian", wires[i], 0) end end
		F.Expire(asm, F.TIMEOUT + 1)
		assert.equal(1, asm.stats.expired)
		assert.truthy(asm.lastIncomplete:find("Aura Guardian", 1, true))
		assert.truthy(asm.lastIncomplete:find("missing 2", 1, true))
		assert.is_nil(asm.open["Aura Guardian"])
	end)

	it("rejects malformed pieces and old-format messages", function()
		local asm = F.NewAssembler()
		assert.equal("old protocol", select(2, F.Add(asm, "Bob", "\133compressed", 0)))
		assert.equal("bad frame", select(2, F.Add(asm, "Bob", F.PIECE .. "aa" .. string.char(33, 33) .. "x", 0))) -- 1 of 1
		assert.equal("bad frame", select(2, F.Add(asm, "Bob", F.PIECE .. "aa" .. string.char(32, 34) .. "x", 0))) -- piece 0
		assert.equal("bad frame", select(2, F.Add(asm, "Bob", F.PIECE .. "aa" .. string.char(36, 34) .. "x", 0))) -- 4 of 2
		assert.equal("bad frame", select(2, F.Add(asm, "Bob", F.PIECE .. "aa" .. string.char(33, 32 + F.MAX_PIECES + 1) .. "x", 0)))
		assert.equal("bad frame", select(2, F.Add(asm, "Bob", F.PIECE .. "aa", 0)))
	end)

	it("keeps only a few unfinished messages per sender", function()
		local asm = F.NewAssembler()
		for _ = 1, F.MAX_OPEN + 3 do F.Add(asm, "Bob", F.Split(payload(600))[1], 0) end
		local n = 0
		for _ in pairs(asm.open.Bob) do n = n + 1 end
		assert.equal(F.MAX_OPEN, n)
	end)
end)

describe("Sync with numbered pieces", function()
	local SK, W
	local AURA = "Player-6855-00C6B9B2"
	before_each(function()
		SK, W = H.load()
		W.member("Pocus Hocus", W.player.guid)
		W.member("Aura Guardian", AURA)
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
	end)

	local function auraProfile()
		local p = { v = 1, guid = AURA, name = "Aura Guardian", class = "PALADIN", level = 21,
			updated = W.now, gear = {}, profs = {}, recipes = { [164] = {} } }
		for i = 1, 11 do p.gear[i] = "|cff1eff00|Hitem:" .. (2000 + i) .. "::::::::21:::::::::|h[Item " .. i .. "]|h|r" end
		for i = 1, 20 do p.recipes[164][2660 + i] = 2850 + i end
		p.hash = SK.Profile.HashOf(p)
		return p
	end

	it("accepts a real-sized profile sent in pieces, even out of order", function()
		local text = SK.Codec.Encode({ t = "PR", p = SK.PROTOCOL, s = AURA, v = "0.3.2", prof = auraProfile() })
		local wires = SK.Frames.Split(text)
		assert.is_true(#wires > 1)
		for i = #wires, 1, -1 do SK.Sync:OnCommReceived(SK.PREFIX, wires[i], "WHISPER", "Aura Guardian") end
		assert.is_not_nil(SK.DBM:Guild().profiles[AURA])
		assert.equal(1, SK.Sync.stats.accepted)
		assert.equal(1, SK.Sync.stats.received) -- one message, not one per piece
	end)

	it("our own profile goes out in pieces that rebuild exactly", function()
		local sent = H.captureSends(SK)
		SK.DBM:Guild().profiles[AURA] = auraProfile()
		SK.Sync:OnCommReceived(SK.PREFIX, H.peerMessage(SK, "RQ", { w = { W.player.guid, AURA } }, AURA), "WHISPER", "Aura Guardian")
		SK.Sync:Flush()
		assert.equal(2, #sent)
		for _, s in ipairs(sent) do
			assert.equal("PR", s.msg.t)
			assert.is_true((SK.Merge.Validate(s.msg.prof)))
		end
	end)

	it("says clearly when a guildmate still runs an old version", function()
		local old = SK.Codec.Encode({ t = "HI", p = 1, s = AURA, v = "0.3.1", c = {} })
		SK.Sync:OnCommReceived(SK.PREFIX, old, "GUILD", "Aura Guardian")
		assert.truthy(SK.Sync.lastReject:find("older Short Royalty", 1, true))
	end)

	it("drops pieces from strangers before storing them", function()
		local wires = SK.Frames.Split(string.rep("x", 1000))
		SK.Sync:OnCommReceived(SK.PREFIX, wires[1], "WHISPER", "Some Stranger")
		assert.is_nil(SK.Sync.assembler and SK.Sync.assembler.open["Some Stranger"])
	end)
end)
