local H = require("tests.helpers.load")

describe("Codec", function()
	local SK
	before_each(function() SK = H.load() end)

	it("round-trips a profile-like table", function()
		local t = { guid = "Player-1-2", gear = { [1] = "|cffa335ee|Hitem:123::::|h[Helm]|h|r" },
			recipes = { [197] = { [18560] = 14342 } }, name = "Pip Sparkfuse" }
		local enc = SK.Codec.Encode(t)
		assert.is_string(enc)
		assert.is_nil(enc:find("[%z\n\r]")) -- addon-channel safe
		assert.same(t, SK.Codec.Decode(enc))
	end)

	it("hash is stable regardless of insertion order", function()
		local a, b = {}, {}
		for i = 1, 50 do a["k" .. i] = i end
		for i = 50, 1, -1 do b["k" .. i] = i end
		assert.equal(SK.Codec.Hash(a), SK.Codec.Hash(b))
		b.k1 = 2
		assert.are_not.equal(SK.Codec.Hash(a), SK.Codec.Hash(b))
	end)

	it("rejects garbage without throwing", function()
		assert.is_nil(SK.Codec.Decode("not valid"))
		assert.is_nil(SK.Codec.Decode(""))
		assert.is_nil(SK.Codec.Decode(string.rep("a", SK.Codec.MAX_ENCODED + 1)))
	end)
end)

describe("Merge rules", function()
	local SK
	local NOW = 1800000000
	before_each(function() SK = H.load() end)

	local function prof(updated, extra)
		local p = { v = 1, guid = "Player-1-B", name = "Bob", updated = updated, gear = {} }
		for k, v in pairs(extra or {}) do p[k] = v end
		p.hash = SK.Profile.HashOf(p)
		return p
	end

	it("accepts a new profile from a member", function()
		assert.is_true((SK.Merge.Decide(nil, prof(NOW), true, NOW, true)))
	end)

	it("rejects characters not in the guild", function()
		local ok, why = SK.Merge.Decide(nil, prof(NOW), true, NOW, false)
		assert.is_false(ok)
		assert.equal("not in guild", why)
	end)

	it("rejects timestamps far in the future", function()
		assert.is_false((SK.Merge.Decide(nil, prof(NOW + 301), true, NOW, true)))
		assert.is_true((SK.Merge.Decide(nil, prof(NOW + 299), true, NOW, true)))
	end)

	it("rejects a tampered hash", function()
		local p = prof(NOW)
		p.name = "Mallory"
		local ok, why = SK.Merge.Decide(nil, p, true, NOW, true)
		assert.is_false(ok)
		assert.equal("hash mismatch", why)
	end)

	it("never lets a relay overwrite a newer owner copy", function()
		local stored = prof(NOW, { ilvl = 70 })
		stored.source = "owner"
		local relayOld = prof(NOW - 100, { ilvl = 50 })
		assert.is_false((SK.Merge.Decide(stored, relayOld, false, NOW, true)))
		local relaySame = prof(NOW, { ilvl = 51 })
		assert.is_false((SK.Merge.Decide(stored, relaySame, false, NOW, true)))
	end)

	it("accepts a strictly newer relay", function()
		local stored = prof(NOW - 100, { ilvl = 50 })
		stored.source = "owner"
		assert.is_true((SK.Merge.Decide(stored, prof(NOW, { ilvl = 70 }), false, NOW, true)))
	end)

	it("owner copy beats any relay copy, even an apparently newer one", function()
		local stored = prof(NOW + 200, { ilvl = 99 })
		stored.source = "relay"
		assert.is_true((SK.Merge.Decide(stored, prof(NOW, { ilvl = 60 }), true, NOW, true)))
	end)

	it("an older owner copy does not replace a newer owner copy", function()
		local stored = prof(NOW, { ilvl = 70 })
		stored.source = "owner"
		assert.is_false((SK.Merge.Decide(stored, prof(NOW - 10, { ilvl = 60 }), true, NOW, true)))
	end)

	it("never overwrites our own characters", function()
		local stored = prof(NOW - 100)
		stored.source = "self"
		assert.is_false((SK.Merge.Decide(stored, prof(NOW, { ilvl = 1 }), true, NOW, true)))
	end)

	it("treats an alt as owner only if the character itself listed it", function()
		local stored = prof(NOW - 100, { family = { "Player-1-ALT" } })
		stored.source = "owner"
		assert.is_true(SK.Merge.IsOwnerCopy("Player-1-ALT", prof(NOW), stored))
		stored.source = "relay"
		assert.is_false(SK.Merge.IsOwnerCopy("Player-1-ALT", prof(NOW), stored))
		assert.is_true(SK.Merge.IsOwnerCopy("Player-1-B", prof(NOW), nil))
	end)

	it("validates shape", function()
		assert.is_false((SK.Merge.Validate({ guid = 5 })))
		assert.is_false((SK.Merge.Validate({ v = 1, guid = "Player-1-B", updated = 1, hash = "x", gear = "oops" })))
		assert.is_true((SK.Merge.Validate(prof(NOW))))
	end)
end)
