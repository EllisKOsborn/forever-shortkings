-- Tests for the v0.1.x "now" features from docs/FEATURE-REVIEW.md (A1-A7).
local H = require("tests.helpers.load")

local loadUI = H.loadUI

local function profile(SK, guid, fields)
	local p = { v = 1, guid = guid, name = guid, updated = 1, gear = {} }
	for k, v in pairs(fields or {}) do p[k] = v end
	p.hash = SK.Profile.HashOf(p)
	return p
end

describe("A1 status dots", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		loadUI(SK)
	end)

	it("distinguishes online-with-addon, online-without and offline", function()
		local now = W.now
		assert.equal("offline", SK.RosterTab.Status({ online = false, addonSeen = now }, false, now))
		assert.equal("online", SK.RosterTab.Status({ online = true }, false, now))
		assert.equal("addon", SK.RosterTab.Status({ online = true, addonSeen = now - 60 }, false, now))
		assert.equal("online", SK.RosterTab.Status({ online = true, addonSeen = now - 3600 }, false, now))
		assert.equal("addon", SK.RosterTab.Status({ online = true }, true, now)) -- ourselves
	end)

	it("any message from a member marks them as running the addon", function()
		W.member("Pip", W.player.guid)
		W.member("Bob", "Player-1-B")
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		H.captureSends(SK)
		SK.Sync:OnCommReceived(SK.PREFIX, H.peerMessage(SK, "SQ", { k = {} }, "Player-1-B", "0.1.3"), "GUILD", "Bob")
		local m = SK.Identity:Member("Player-1-B")
		assert.equal("0.1.3", m.addon)
		assert.equal(W.now, m.addonSeen)
	end)
end)

describe("A2 alts", function()
	local SK
	before_each(function() SK = H.load() end)
	local member = function() return true end

	it("groups characters only when both list each other", function()
		local profiles = {
			A = profile(SK, "A", { family = { "B", "C" }, level = 60 }),
			B = profile(SK, "B", { family = { "A", "C" }, level = 40 }),
			C = profile(SK, "C", { family = {}, level = 60 }), -- C never confirmed
		}
		local groupOf = SK.Alts.Groups(profiles, member)
		assert.equal(groupOf.A, groupOf.B)
		assert.are_not.equal(groupOf.A, groupOf.C)
		assert.equal("A", groupOf.A.main) -- highest level
	end)

	it("uses the main the player chose", function()
		local profiles = {
			A = profile(SK, "A", { family = { "B" }, level = 60, main = "B" }),
			B = profile(SK, "B", { family = { "A" }, level = 30, main = "B" }),
		}
		local groupOf = SK.Alts.Groups(profiles, member)
		assert.equal("B", groupOf.A.main)
		assert.same({ "B", "A" }, groupOf.A.members)
	end)

	it("ignores characters who are no longer members", function()
		local profiles = {
			A = profile(SK, "A", { family = { "B" } }),
			B = profile(SK, "B", { family = { "A" } }),
		}
		local groupOf = SK.Alts.Groups(profiles, function(g) return g == "A" end)
		assert.equal(1, #groupOf.A.members)
		assert.is_nil(groupOf.B)
	end)

	it("the Roster folds alts under the main and shows them online", function()
		local SK2, W = H.load()
		loadUI(SK2)
		W.member("Main", "Player-1-M", { online = false, lastOnlineHours = 3 })
		W.member("Alt", "Player-1-L", { online = true })
		W.member("Solo", "Player-1-S", { online = true })
		SK2.Identity:ReadRoster()
		local g = SK2.DBM:Guild()
		g.profiles["Player-1-M"] = profile(SK2, "Player-1-M", { family = { "Player-1-L" }, level = 60 })
		g.profiles["Player-1-L"] = profile(SK2, "Player-1-L", { family = { "Player-1-M" }, level = 20 })
		g.members["Player-1-L"].addonSeen = W.now
		local rows = SK2.RosterTab.Rows(g, W.now, nil, true)
		assert.equal(2, #rows)
		local main
		for _, r in ipairs(rows) do if r.guid == "Player-1-M" then main = r end end
		assert.equal(1, #main.alts)
		assert.equal("addon", main.status)
		assert.equal("Alt", main.onAlt)
		-- searching an alt's name finds the main row
		assert.equal(1, #SK2.RosterTab.Rows(g, W.now, "alt", true))
		-- ungrouped shows everyone
		assert.equal(3, #SK2.RosterTab.Rows(g, W.now, nil, false))
	end)

	it("our own profiles carry family (the main is picked automatically since v0.4.0)", function()
		local SK2, W = H.load()
		W.member("Pip", W.player.guid)
		W.member("Pipalt", "Player-1-ALT")
		SK2.Identity:ReadRoster()
		SK2.DB.account["Player-1-ALT"] = true
		SK2.DB.settings.main = "Player-1-ALT" -- an old saved choice is no longer sent
		SK2.Profile:BuildSelf()
		local pub = SK2.DBM:Guild().profiles[W.player.guid]
		assert.same({ "Player-1-ALT" }, pub.family)
		assert.is_nil(pub.main)
	end)
end)

describe("A3 notes", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		W.member("Bob", "Player-1-B", { note = "Tank, alt of Bramble", officerNote = "Trial until Dec" })
	end)

	it("stores the public note for everyone", function()
		SK.Identity:ReadRoster()
		assert.equal("Tank, alt of Bramble", SK.Identity:Member("Player-1-B").note)
		assert.is_nil(SK.Identity:Member("Player-1-B").officerNote)
	end)

	it("stores the officer note only when the game allows it", function()
		W.officer = true
		SK.Identity:ReadRoster()
		assert.equal("Trial until Dec", SK.Identity:Member("Player-1-B").officerNote)
	end)

	it("never puts notes into the shared profile", function()
		W.officer = true
		W.member("Pip", W.player.guid, { note = "mine", officerNote = "secret" })
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		local text = SK.Codec.Serialize(SK.DBM:Guild().profiles[W.player.guid])
		assert.is_nil(text:find("secret", 1, true))
		assert.is_nil(text:find("mine", 1, true))
	end)

	it("roster search finds text in notes", function()
		loadUI(SK)
		SK.Identity:ReadRoster()
		assert.equal(1, #SK.RosterTab.Rows(SK.DBM:Guild(), W.now, "bramble", false))
	end)
end)

describe("A4 versions", function()
	it("flags members on an older version", function()
		local SK, W = H.load()
		loadUI(SK)
		W.member("New", "Player-1-N")
		W.member("Old", "Player-1-O")
		SK.Identity:ReadRoster()
		local g = SK.DBM:Guild()
		g.members["Player-1-N"].addon = "0.2.0"
		g.members["Player-1-O"].addon = "0.1.0"
		assert.equal("0.2.0", SK.RosterTab.NewestVersion(g))
		local rows = SK.RosterTab.Rows(g, W.now, nil, false)
		for _, r in ipairs(rows) do
			assert.equal(r.guid == "Player-1-O", r.outdated)
		end
	end)
end)

describe("A5 missing enchants", function()
	local SK, W
	before_each(function() SK, W = H.load() end)
	local E = function(SK2) return SK2.Data.Enchants end

	it("reads the enchant ID from item links", function()
		assert.equal(0, SK.Compat.EnchantFromLink("|cffa335ee|Hitem:16914::::|h[Crown]|h|r"))
		assert.equal(2588, SK.Compat.EnchantFromLink("|cffa335ee|Hitem:16914:2588:::|h[Crown]|h|r"))
		assert.equal(0, SK.Compat.EnchantFromLink("item:16914:0:0:0"))
	end)

	it("flags enchantable slots without an enchant", function()
		local gear = {
			[1] = "item:100::::",          -- head, missing
			[2] = "item:101::::",          -- neck, never enchantable
			[5] = "item:102:1891:::",      -- chest, enchanted
			[16] = "item:103::::",         -- main hand, missing
			[17] = "item:104::::",         -- off hand: held-in-off-hand item
			[18] = "item:105::::",         -- ranged (only hunters)
		}
		W.items[104] = { "INVTYPE_HOLDABLE", 4, 0 }
		W.items[105] = { "INVTYPE_RANGED", 2, 2 }
		assert.same({ 1, 16 }, E(SK).Missing(gear, "MAGE"))
		assert.same({ 1, 16, 18 }, E(SK).Missing(gear, "HUNTER"))
		W.items[104] = { "INVTYPE_SHIELD", 4, 6 }
		assert.same({ 1, 16, 17 }, E(SK).Missing(gear, "WARRIOR"))
	end)

	it("does not flag wands or fishing poles", function()
		W.items[200] = { "INVTYPE_RANGEDRIGHT", 2, 19 } -- wand
		W.items[201] = { "INVTYPE_2HWEAPON", 2, 20 }    -- fishing pole
		assert.same({}, E(SK).Missing({ [18] = "item:200::::", [16] = "item:201::::" }, "HUNTER"))
	end)
end)

describe("A6 accurate cooldowns", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		W.member("Pip", W.player.guid)
		W.professions = { { name = "Alchemy", rank = 300, max = 300, skillLine = 171 } }
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		W.tradeskill = { skillLine = 171, name = "Alchemy", rank = 300, max = 300, recipes = {
			[17187] = { learned = true, itemID = 12360, cd = 7200 }, -- a transmute on cooldown
		} }
		SK.Professions:Scan()
		W.advance(1)
	end)

	it("remembers which recipes have cooldowns", function()
		assert.is_true(SK.DB.cooldownSpells[W.player.guid][17187])
	end)

	it("updates from the spell API without opening the profession window", function()
		W.tradeskill = nil
		W.advance(3600)
		W.spellCD[17187] = { W.now - 3600, 7200 } -- started an hour ago, 1h left
		SK.Profile:BuildSelf()
		assert.equal(W.now + 3600, SK.Profile:Own().cds[17187])
	end)

	it("keeps a ready cooldown so it can show as ready", function()
		W.tradeskill = nil
		W.advance(8000)
		W.spellCD[17187] = { 0, 0 }
		SK.Profile:BuildSelf()
		local expires = SK.Profile:Own().cds[17187]
		assert.is_not_nil(expires)
		assert.is_true(expires <= W.now)
	end)
end)

describe("A7 privacy", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		W.member("Pip", W.player.guid)
		W.gear[1] = "item:16914::::"
		W.professions = { { name = "Tailoring", rank = 300, max = 300, skillLine = 197 } }
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
	end)

	it("shares everything by default", function()
		local pub = SK.DBM:Guild().profiles[W.player.guid]
		assert.is_not_nil(pub.gear[1])
		assert.is_nil(pub.hidden)
	end)

	it("hides gear and talents from the shared copy but keeps them locally", function()
		local fired = 0
		SK:On("SELF_UPDATED", function() fired = fired + 1 end)
		SK.DB.settings.share.gear = false
		assert.is_true(SK.Profile:BuildSelf())
		assert.equal(1, fired) -- triggers a fresh announcement
		local pub = SK.DBM:Guild().profiles[W.player.guid]
		assert.is_nil(pub.gear)
		assert.is_nil(pub.talents)
		assert.is_true(pub.hidden.gear)
		assert.equal(pub.hash, SK.Profile.HashOf(pub)) -- peers can verify it
		assert.is_not_nil(SK.Profile:Own().gear[1])     -- we still see our own
		assert.is_not_nil(SK.Profile:Get(W.player.guid).gear[1])
		assert.equal(300, pub.profs[197].rank)          -- basics still shared
	end)

	it("hides recipes and cooldowns", function()
		SK.DB.settings.share.recipes = false
		W.tradeskill = { skillLine = 197, name = "Tailoring", recipes = { [18560] = { learned = true, itemID = 1 } } }
		SK.Professions:Scan()
		W.advance(1)
		local pub = SK.DBM:Guild().profiles[W.player.guid]
		assert.is_nil(pub.recipes)
		assert.is_true(pub.hidden.recipes)
		assert.is_not_nil(SK.Profile:Own().recipes[197][18560])
	end)

	it("a hidden profile is accepted by peers (shape and hash)", function()
		SK.DB.settings.share.gear = false
		SK.DB.settings.share.recipes = false
		SK.Profile:BuildSelf()
		local pub = SK.CopyTable(SK.DBM:Guild().profiles[W.player.guid])
		pub.source = nil
		assert.is_true((SK.Merge.Validate(pub)))
		assert.is_true((SK.Merge.Decide(nil, pub, true, W.now, true)))
	end)

	it("the character view says what is hidden", function()
		loadUI(SK)
		SK.DB.settings.share.gear = false
		SK.Profile:BuildSelf()
		local text = SK.CharacterTab.DetailText(SK.DBM:Guild().profiles[W.player.guid], W.now)
		assert.truthy(text:find("hidden by this player", 1, true))
	end)
end)
