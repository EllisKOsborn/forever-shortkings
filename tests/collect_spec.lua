local H = require("tests.helpers.load")

describe("Collection", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		W.member("Pip Sparkfuse", W.player.guid)
		SK.Identity:ReadRoster()
		W.gear[1] = "|cffa335ee|Hitem:16914::::|h[Netherwind Crown]|h|r"
		W.professions = {
			{ name = "Tailoring", rank = 300, max = 300, skillLine = 197 },
			{ name = "Enchanting", rank = 250, max = 300, skillLine = 333 },
			{ name = "Fishing", rank = 150, max = 225, skillLine = 356 },
		}
		W.talentNodes = {
			{ id = 1, rank = 5, groups = { 1 }, spellID = 1001 },
			{ id = 2, rank = 3, groups = { 2 }, spellID = 1002 },
			{ id = 3, rank = 2, groups = { 1 }, spellID = 1003 },
		}
		W.factions = {
			{ factionID = 529, name = "Argent Dawn", reaction = 6, currentStanding = 12000, isHeader = false },
			{ factionID = 1118, name = "Classic", isHeader = true },
		}
		W.quests[7848] = true
	end)

	it("builds the own profile with everything", function()
		assert.is_true(SK.Profile:BuildSelf())
		local p = SK.Profile:Own()
		assert.equal("Pip Sparkfuse", p.name) -- roster name preferred
		assert.equal(W.gear[1], p.gear[1])
		assert.equal(61.0, p.ilvl)
		assert.equal(300, p.profs[197].rank)
		assert.is_true(p.profs[197].primary)
		assert.is_false(p.profs[356].primary)
		assert.same({ n = "Arcane", p = 7, i = 1 }, p.talents.trees[1])
		assert.equal(3, p.talents.trees[2].p)
		assert.equal(0, p.talents.trees[3].p)
		assert.equal(5, p.talents.nodes[1001])
		assert.equal("7/3/0", (SK.Talents.Summary(p.talents)))
		assert.equal(12000, p.reps[529].v)
		assert.is_nil(p.reps[1118])
		assert.is_true(p.att.mc)
		assert.is_false(p.att.ony)
		assert.is_nil(p.att.barrow) -- no attunement needed: nothing recorded
		assert.is_false(p.att.ony_item) -- no Drakefire Amulet in bags
		assert.is_true(SK.DB.account[W.player.guid])
		assert.equal("self", p.source)
	end)

	it("only bumps `updated` when content changes", function()
		local fired = 0
		SK:On("SELF_UPDATED", function() fired = fired + 1 end)
		SK.Profile:BuildSelf()
		local first = SK.Profile:Own().updated
		W.now = W.now + 100
		assert.is_false(SK.Profile:BuildSelf())
		assert.equal(first, SK.Profile:Own().updated)
		W.gear[1] = nil
		assert.is_true(SK.Profile:BuildSelf())
		assert.equal(W.now, SK.Profile:Own().updated)
		assert.equal(2, fired)
	end)

	it("lists crafting professions that still need a scan", function()
		SK.Profile:BuildSelf()
		assert.same({ "Enchanting", "Tailoring" }, SK.Professions.Unscanned(SK.Profile:Own()))
	end)

	it("scans recipes, cooldowns and the recipe universe", function()
		SK.Profile:BuildSelf()
		W.tradeskill = { skillLine = 197, name = "Tailoring", rank = 300, max = 300, recipes = {
			[18560] = { learned = true, itemID = 14342, cd = 3600 },
			[18403] = { learned = true, itemID = 13856 },
			[99999] = { learned = false, itemID = 1 },
		} }
		SK.Professions:Scan()
		W.advance(1)
		local p = SK.Profile:Own()
		assert.same({ [18560] = 14342, [18403] = 13856 }, p.recipes[197])
		assert.equal(W.now - 1 + 3600, p.cds[18560])
		assert.is_not_nil(p.profs[197].scanned)
		assert.same({ "Enchanting" }, SK.Professions.Unscanned(p))
		assert.equal(1, SK.DBM:Guild().recipeUniverse[197][99999])
		-- scan results survive a rebuild
		W.now = W.now + 10
		SK.Profile:BuildSelf()
		assert.same({ [18560] = 14342, [18403] = 13856 }, SK.Profile:Own().recipes[197])
	end)

	it("ignores linked (other people's) profession windows", function()
		SK.Profile:BuildSelf()
		W.tradeskill = { skillLine = 197, name = "Tailoring", linked = true,
			recipes = { [1] = { learned = true } } }
		SK.Professions:Scan()
		W.advance(1)
		assert.is_nil(SK.Profile:Own().recipes[197])
	end)

	it("processes large recipe lists in chunks across frames", function()
		local ids = {}
		W.tradeskill = { skillLine = 197, recipes = {} }
		for i = 1, 120 do ids[i] = i; W.tradeskill.recipes[i] = { learned = i % 2 == 0, itemID = i } end
		local result
		SK.Professions.ProcessRecipes(ids, function(r) result = r end)
		assert.is_nil(result) -- first chunk only
		W.advance(0)
		assert.equal(60, SK.Count(result.learned))
		assert.equal(120, SK.Count(result.universe))
	end)

	it("drops recipes for a profession that was unlearned", function()
		SK.Profile:BuildSelf()
		W.tradeskill = { skillLine = 333, name = "Enchanting", recipes = { [7] = { learned = true } } }
		SK.Professions:Scan()
		W.advance(1)
		assert.is_not_nil(SK.Profile:Own().recipes[333])
		table.remove(W.professions, 2)
		SK.Profile:BuildSelf()
		assert.is_nil(SK.Profile:Own().recipes[333])
	end)
end)
