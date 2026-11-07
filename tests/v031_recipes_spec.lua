-- luacheck: globals C_TradeSkillUI C_Spell
-- v0.3.1: every recipe in the game (Data/Recipes.lua from wago.tools),
-- search by name / group / material, Wowhead links, and Getting started.
local H = require("tests.helpers.load")

local R_ARCANITE, R_SEED = 17187, 1263070
local ARCANITE_BAR, THORIUM_BAR, SEED_HYBRIDIZER = 12360, 12359, 279947

local function setup()
	local SK, W = H.load()
	H.loadUI(SK)
	W.member("Pip", W.player.guid)
	W.member("Ann", "Player-1-A")
	W.professions = { { name = "Tailoring", rank = 250, max = 300, skillLine = 197 } }
	SK.Identity:ReadRoster()
	SK.Profile:BuildSelf()
	W.itemNames[ARCANITE_BAR] = "Arcanite Bar"
	W.itemNames[THORIUM_BAR] = "Thorium Bar"
	W.itemNames[SEED_HYBRIDIZER] = "Seed Hybridizer"
	W.spellNames[R_ARCANITE] = "Transmute: Arcanite"
	return SK, W
end

describe("v0.3.1 recipe data from the game", function()
	local SK
	before_each(function() SK = setup() end)

	it("has every profession's recipes, with items, groups and reagents", function()
		assert.is_true(SK.RecipeDB.Count() > 2000)
		assert.truthy(SK.Data.RECIPE_SOURCE.build:match("^1%.60%.1%."))
		local r = SK.RecipeDB.Get(R_ARCANITE)
		assert.equal(171, r.skillLine)
		assert.equal(ARCANITE_BAR, r.itemID)
		-- what the owner's game showed on 6 Nov for the Seed Hybridizer
		local seed = SK.RecipeDB.Get(R_SEED)
		assert.equal(182, seed.skillLine)
		assert.equal(SEED_HYBRIDIZER, seed.itemID)
		assert.equal("Camping", SK.RecipeDB.CategoryName(seed.cat))
		assert.same({ { itemID = 13465, qty = 4 }, { itemID = 8925, qty = 1 }, { itemID = 14047, qty = 2 } },
			SK.RecipeDB.Reagents(R_SEED))
		for skillLine in pairs(SK.Data.PROFESSIONS) do
			assert.is_true(#SK.RecipeDB.List(skillLine) > 0, tostring(skillLine))
		end
	end)

	it("leaves out Season of Discovery and test categories, and is well formed", function()
		for id, c in pairs(SK.Data.RECIPE_CATS) do
			assert.is_number(id)
			assert.is_nil(c[1]:lower():find("season of discovery", 1, true))
			assert.is_nil(c[1]:find("[DNT]", 1, true))
		end
		for skillLine, list in pairs(SK.Data.RECIPE_LIST) do
			assert.truthy(SK.Data.PROFESSIONS[skillLine])
			for _, e in ipairs(list) do
				assert.is_number(e[1]); assert.is_number(e[2]); assert.is_number(e[3])
				assert.truthy(e[4] == "" or e[4]:match("^%d+:%d+[%d:,]*$"), tostring(e[1]))
			end
		end
	end)

	it("hides recipes this client says don't exist, and prefers the game's group names", function()
		local before = #SK.RecipeDB.List(171)
		_G.C_Spell.DoesSpellExist = function(id) return id ~= R_ARCANITE end
		assert.equal(before - 1, #SK.RecipeDB.List(171))
		_G.C_Spell.DoesSpellExist = nil
		C_TradeSkillUI.GetCategoryInfo = function(id) if id == 2716 then return { name = "Camper" } end end
		SK.RecipeDB.Reset()
		assert.equal("Camper", SK.RecipeDB.CategoryName(2716))
	end)

	it("gives reagents without the profession window, from the game data", function()
		C_TradeSkillUI.GetRecipeSchematic = nil
		local lines = SK.Reagents.Lines(R_ARCANITE)
		assert.equal(2, #lines)
		assert.equal(THORIUM_BAR, lines[1].itemID)
	end)

	it("makes Wowhead links for Forever", function()
		assert.equal("https://www.wowhead.com/forever/item=12360", SK.RecipeDB.WowheadURL(R_ARCANITE, ARCANITE_BAR))
		assert.equal("https://www.wowhead.com/forever/spell=7", SK.RecipeDB.WowheadURL(7, 0))
	end)
end)

describe("v0.3.1 recipe search", function()
	local SK, W
	before_each(function() SK, W = setup() end)

	-- Names arrive in batches (REQUESTS_PER_SEARCH per search), as in game.
	local function settle(q, prof, index)
		for _ = 1, 20 do SK.RecipeDB.Search(q, prof, index); W.advance(1) end
		return SK.RecipeDB.Search(q, prof, index)
	end

	local function ids(rows)
		local t = {}
		for _, r in ipairs(rows) do t[r.recipeID] = r end
		return t
	end

	it("needs a few letters unless a profession is picked", function()
		local rows, state = SK.RecipeDB.Search("ar")
		assert.equal("short", state)
		assert.equal(0, #rows)
		rows, state = SK.RecipeDB.Search("", 182)
		assert.equal("ok", state)
		assert.is_true(#rows >= 4) -- every Herbalism recipe
	end)

	it("finds by name, by the window's group and by material", function()
		local byName = ids(settle("arcanite bar"))
		assert.equal("name", byName[R_ARCANITE].match)
		local byGroup = ids(settle("camping"))
		assert.equal("group", byGroup[R_SEED].match)
		local byMat = ids(settle("thorium bar"))
		assert.equal("material", byMat[R_ARCANITE].match)
		assert.equal("Thorium Bar", byMat[R_ARCANITE].matched)
	end)

	it("counts guild crafters and never asks the game for too many names at once", function()
		local requests = 0
		local real = _G.C_Item.RequestLoadItemDataByID
		_G.C_Item.RequestLoadItemDataByID = function(...) requests = requests + 1; return real(...) end
		SK.RecipeDB.Search("zzz")
		assert.is_true(requests <= SK.RecipeDB.REQUESTS_PER_SEARCH)
		_G.C_Item.RequestLoadItemDataByID = real
		local guild = SK.DBM:Guild()
		local p = { v = 1, guid = "Player-1-A", name = "Ann", updated = 1, profs = { [171] = { name = "Alchemy", rank = 300 } },
			recipes = { [171] = { [R_ARCANITE] = ARCANITE_BAR } } }
		p.hash = SK.Profile.HashOf(p)
		guild.profiles["Player-1-A"] = p
		local rows = ids(settle("arcanite bar", nil, SK.CraftIndex:Rebuild()))
		assert.equal(1, rows[R_ARCANITE].count)
	end)

	it("an item the game can't load isn't asked for again", function()
		SK.CraftIndex.ItemName(424242)
		W.advance(1) -- the stub answers "failed" for unknown items
		assert.is_true(SK.CraftIndex.failedItems[424242])
		local asked = 0
		local real = _G.C_Item.RequestLoadItemDataByID
		_G.C_Item.RequestLoadItemDataByID = function(...) asked = asked + 1; return real(...) end
		SK.CraftIndex.ItemName(424242)
		assert.equal(0, asked)
		_G.C_Item.RequestLoadItemDataByID = real
	end)

	it("the All recipes view lists results and opens one in Crafters with a Wowhead link", function()
		C_TradeSkillUI.GetRecipeSchematic = nil
		SK.DB.settings.profView = "recipes"
		SK.MainFrame:Show("professions")
		local tab = SK.ProfessionsTab
		assert.is_true(tab.allList:IsShown())
		tab.query = "camping"
		tab:Refresh()
		local seed
		for _, r in ipairs(tab.allList.items) do if r.recipeID == R_SEED then seed = r end end
		assert.truthy(seed)
		tab.allProf = 182
		tab.query = ""
		tab:Refresh()
		assert.is_true(#tab.allList.items >= 4)
		SK.CraftersTab:ShowRecipe(R_SEED, 182)
		assert.equal("crafters", SK.MainFrame.current)
		assert.truthy(SK.CraftersTab.reagents:GetText():find("Needs:", 1, true)) -- from the game data
		assert.equal("https://www.wowhead.com/forever/item=279947", SK.CraftersTab:WowheadLink())
		assert.equal(0, #SK.errors)
	end)
end)

describe("v0.3.1 getting started", function()
	local SK, W
	before_each(function() SK, W = setup() end)

	it("lists the steps and ticks them off", function()
		local steps, done = SK.Onboarding.Steps(SK.Profile:Own(), {}, nil, 1, 2)
		assert.is_false(done)
		local by = {}
		for _, s in ipairs(steps) do by[s.key] = s end
		assert.is_false(by.profs.done)
		assert.equal("Tailoring", by.profs.detail)
		assert.equal("1 of 2 have it", by.guild.detail)
		assert.is_nil(by.main) -- no alts
		SK.Profile:Own().profs[197].scanned = W.now
		local _, allDone = SK.Onboarding.Steps(SK.Profile:Own(), { character = true, settings = true }, nil, 2, 2)
		assert.is_true(allDone)
	end)

	it("the main step is optional and only for players with alts", function()
		local own = SK.Profile:Own()
		own.family = { "Player-1-Z" }
		local steps = SK.Onboarding.Steps(own, {}, nil, 1, 2)
		local main
		for _, s in ipairs(steps) do if s.key == "main" then main = s end end
		assert.is_true(main.optional)
	end)

	it("says welcome once, remembers tabs, and the Overview card can be hidden", function()
		assert.is_true(SK.Onboarding:Welcome())
		assert.is_false(SK.Onboarding:Welcome())
		SK.MainFrame:Show("overview")
		local ov = SK.OverviewTab
		assert.is_true(ov.start:IsShown())
		assert.is_false(ov.feed:IsShown())
		SK.MainFrame:Select("character")
		assert.is_true(SK.DB.settings.seen.character)
		SK.MainFrame:Select("overview")
		ov.start.button:GetScript("OnClick")(ov.start.button)
		assert.is_false(ov.start:IsShown())
		assert.is_true(ov.feed:IsShown())
	end)

	it("rows show what's left in orange and what's done in green", function()
		local rows = SK.OverviewTab.StartRows({ { text = "A", done = true }, { text = "B", done = false, detail = "x" },
			{ text = "C", done = false, optional = true } })
		assert.equal("good", rows[1].tone)
		assert.equal("spark", rows[2].tone)
		assert.equal("x", rows[3].text)
		assert.equal("optional", rows[4].value)
	end)
end)
