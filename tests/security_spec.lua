-- Hostile input: messages crafted by a stranger or a guild member. See
-- docs/SECURITY-REVIEW.md for what each test protects against.
local H = require("tests.helpers.load")

describe("Security", function()
	local SK, W
	local BOB, EVE = "Player-1-B", "Player-1-E"

	local function profile(extra)
		local p = { v = 1, guid = BOB, name = "Bob Smith", class = "WARRIOR", updated = W.now, gear = {} }
		for k, v in pairs(extra or {}) do p[k] = v end
		p.hash = SK.Profile.HashOf(p)
		return p
	end

	local function deliver(t, fields, sender, fromGUID, dist, version)
		SK.Sync:OnCommReceived(SK.PREFIX, H.peerMessage(SK, t, fields, fromGUID, version), dist or "WHISPER", sender)
	end

	before_each(function()
		SK, W = H.load()
		W.member("Pip", W.player.guid)
		W.member("Bob Smith", BOB)
		W.member("Eve Evil", EVE)
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		H.captureSends(SK)
	end)

	describe("impersonation", function()
		it("refuses a stranger who shares a member's first name", function()
			deliver("PR", { prof = profile({ updated = W.now + 200 }) }, "Bob Jones", BOB)
			assert.is_nil(SK.DBM:Guild().profiles[BOB])
			assert.equal("unconfirmed sender", SK.Sync.lastReject)
		end)

		it("never decodes messages from strangers", function()
			local decoded = 0
			local real = SK.Codec.Decode
			SK.Codec.Decode = function(...) decoded = decoded + 1; return real(...) end
			deliver("PR", { prof = profile() }, "Mallory Moe", "Player-9-Z")
			assert.equal(0, decoded)
			assert.equal(1, SK.Sync.stats.dropped)
		end)

		it("ignores channels we never send on", function()
			deliver("PR", { prof = profile() }, "Bob Smith", BOB, "PARTY")
			deliver("PR", { prof = profile() }, "Bob Smith", BOB, "RAID")
			assert.is_nil(SK.DBM:Guild().profiles[BOB])
		end)
	end)

	describe("decompression bombs", function()
		local function bomb(size)
			local LD = LibStub("LibDeflate")
			local s = LibStub("LibSerialize"):Serialize({ t = "PR", p = 1, s = BOB, x = string.rep("A", size) })
			return LD:EncodeForWoWAddonChannel(LD:CompressDeflate(s, { level = 9 }))
		end

		it("refuses messages that decompress to more than MAX_DECODED", function()
			local text = bomb(SK.Codec.MAX_DECODED + 1)
			assert.is_true(#text < SK.Codec.MAX_ENCODED)
			local msg, why = SK.Codec.Decode(text)
			assert.is_nil(msg)
			assert.equal("too large decoded", why)
		end)

		it("ignores a sender for the session after repeated bad messages", function()
			local text = bomb(SK.Codec.MAX_DECODED + 1)
			for _ = 1, SK.Sync.MAX_STRIKES do SK.Sync:OnCommReceived(SK.PREFIX, text, "WHISPER", "Bob Smith") end
			assert.is_true(SK.Sync.blocked["Bob Smith"])
			local decoded = 0
			local real = SK.Codec.Decode
			SK.Codec.Decode = function(...) decoded = decoded + 1; return real(...) end
			deliver("PR", { prof = profile() }, "Bob Smith", BOB)
			assert.equal(0, decoded)
			assert.equal(1, SK.Sync.stats.blocked)
		end)

		it("leaves room for a worst-case real profile", function()
			local recipes, reps, nodes, gear = {}, {}, {}, {}
			for _, line in ipairs({ 164, 165, 171, 197 }) do
				recipes[line] = {}
				for i = 1, 450 do recipes[line][20000 + i] = 15000 + i end
			end
			for i = 1, 150 do reps[1000 + i] = { n = "The Faction Of Some Long Name " .. i, r = 5, v = 12345 } end
			for i = 1, 300 do nodes[30000 + i] = 5 end
			for slot = 1, 19 do
				gear[slot] = "|cffa335ee|Hitem:" .. (16900 + slot) .. ":2505:0:0:0:0:0:0:60:0:0:0:0|h[A Long Epic Item Name]|h|r"
			end
			local p = profile({ recipes = recipes, reps = reps, gear = gear, ilvl = 70.5, level = 60,
				talents = { api = "traits", trees = { { n = "Arms", p = 31, i = 132355 } }, nodes = nodes } })
			assert.is_true(SK.Merge.Validate(p))
			assert.is_true(#SK.Codec.Serialize(p) < SK.Codec.MAX_DECODED / 4)
		end)
	end)

	describe("malformed profiles", function()
		local BAD = {
			{ "talent trees as text", { talents = { trees = "x" } } },
			{ "profession rank as text", { profs = { [164] = { name = "Blacksmithing", rank = "x" } } } },
			{ "item level as text", { ilvl = "big" } },
			{ "level as a table", { level = {} } },
			{ "cooldown as text", { cds = { [123] = "soon" } } },
			{ "reputation as text", { reps = { [529] = "x" } } },
			{ "attunement as a number", { att = { ony = 1 } } },
			{ "family with a table", { family = { {} } } },
			{ "gear that isn't an item link", { gear = { [1] = "|Hurl:evil|h[Click me]|h" } } },
			{ "gear with two links", { gear = { [1] = "|Hitem:1|h[a]|h|Hitem:2|h[b]|h" } } },
			{ "a huge name", { name = string.rep("A", 5000) } },
			{ "a version with free text", { addon = "9.9 get the fix at evil.example" } },
			{ "not-a-number timestamp", { updated = 0 / 0 } },
			{ "too many recipes", { recipes = { [164] = (function() local t = {} for i = 1, 2000 do t[i] = i end return t end)() } } },
			{ "specialisation as text", { profs = { [202] = { name = "Engineering", rank = 1, specs = { "Gnome" } } } } },
			{ "too many specialisations", { profs = { [202] = { name = "Engineering", rank = 1, specs = { 1, 2, 3, 4, 5 } } } } },
			{ "deeply nested extra field", { extra = { { { { { { { 1 } } } } } } } } },
		}
		for _, case in ipairs(BAD) do
			it("rejects " .. case[1], function()
				local p = profile(case[2])
				p.hash = SK.Profile.HashOf(p)
				deliver("PR", { prof = p }, "Bob Smith", BOB)
				assert.is_nil(SK.DBM:Guild().profiles[BOB])
				assert.equal(1, SK.Sync.stats.rejected)
			end)
		end

		it("keeps plain fields from a newer version", function()
			deliver("PR", { prof = profile({ raids = { bd = { kills = 3 } } }) }, "Bob Smith", BOB)
			assert.is_not_nil(SK.DBM:Guild().profiles[BOB])
		end)

		it("accepts our own profile (what guildmates receive from us)", function()
			local guild = SK.DBM:Guild()
			assert.is_true(SK.Merge.Validate(guild.profiles[W.player.guid]))
		end)
	end)

	describe("chat text", function()
		it("never prints a version that isn't a version", function()
			deliver("HI", { c = {} }, "Bob Smith", BOB, "GUILD", "9.9 - download the fix at evil.example")
			assert.equal(0, #W.prints)
			assert.is_nil(SK.Identity:Member(BOB).addon)
		end)

		it("does not let a stranger trigger the update notice", function()
			deliver("HI", { c = {} }, "Mallory Moe", "Player-9-Z", "WHISPER", "9.9.9")
			assert.equal(0, #W.prints)
		end)

		it("strips links and colours from profession names in a grats message", function()
			local old = profile({ profs = { [164] = { name = "Smithing", rank = 290 } } })
			local new = profile({ profs = { [164] = { name = "|cffff0000|Hitem:1|h[Smithing]|h|r", rank = 300 } } })
			local events = SK.Feed.Diff(old, new)
			local text = SK.Feed.GratsText({ name = "Bob Smith", grats = events[1].grats })
			assert.is_nil(text:find("|", 1, true))
			assert.equal("Grats Bob on [Smithing] 300!", text) -- link text kept, link removed
		end)
	end)

	it("keeps the rate table small", function()
		for i = 1, SK.Sync.MAX_RATE_KEYS * 3 do
			SK.Sync:AllowFrom("Sender" .. i, W.now)
			W.advance(1)
		end
		assert.is_true(SK.Count(SK.Sync.rate) <= SK.Sync.MAX_RATE_KEYS + 1)
	end)
end)
