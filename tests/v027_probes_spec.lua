-- luacheck: globals C_TradeSkillUI
-- v0.2.7: /sr debug probes that answer the questions v0.3 Professions needs
-- (docs/prompts/next-v0.3-professions.md, Step 1).
local H = require("tests.helpers.load")

describe("v0.2.7 profession probes", function()
	local SK, W
	local function report() return table.concat(SK.Commands.BuildReport(), "\n") end

	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pocus Hocus", W.player.guid)
		SK.Identity:ReadRoster()
		W.professions = { { name = "Engineering", rank = 150, max = 225, skillLine = 202 } }
		SK.Profile:BuildSelf()
	end)

	it("says what to do before a profession window has been opened", function()
		local text = report()
		assert.truthy(text:find("Profession checks for v0.3", 1, true))
		assert.truthy(text:find("Last scan: none this session", 1, true))
		assert.truthy(text:find("no recipe to test", 1, true))
	end)

	it("lists categories, reagents and unlearned recipes after a scan", function()
		W.tradeskill = { skillLine = 202, name = "Engineering", rank = 150, max = 225, recipes = {
			[3918] = { learned = true, itemID = 4357 },
			[3922] = { learned = false, itemID = 4360 },
		} }
		local base = C_TradeSkillUI.GetRecipeInfo
		C_TradeSkillUI.GetRecipeInfo = function(id)
			local info = base(id)
			if info then info.categoryID = id == 3918 and 11 or 12 end
			return info
		end
		C_TradeSkillUI.GetCategoryInfo = function(id)
			return ({ [11] = { name = "Parts" }, [12] = { name = "Camp Blueprints", parentCategoryID = 11 } })[id]
		end
		C_TradeSkillUI.GetShowUnlearned = function() return true end
		C_TradeSkillUI.GetRecipeSchematic = function(id, isRecraft)
			assert.is_false(isRecraft)
			return { name = "Recipe " .. id, outputItemID = 4357, quantityMin = 1, quantityMax = 1,
				reagentSlotSchematics = { { quantityRequired = 2, required = true, reagents = { { itemID = 2835 } } } } }
		end
		SK.Professions:OnLogin()
		W.fire("TRADE_SKILL_SHOW")
		W.advance(2)
		local text = report()
		assert.truthy(text:find("Profession window open now: yes", 1, true))
		assert.truthy(text:find("show unlearned=yes", 1, true))
		assert.truthy(text:find("1 learned of 2 listed (unlearned listed: YES)", 1, true))
		assert.truthy(text:find('category 11 "Parts": 1 listed, 1 learned', 1, true))
		assert.truthy(text:find('category 12 "Camp Blueprints" in "Parts"', 1, true))
		assert.truthy(text:find("a recipe you know: recipe 3918", 1, true))
		assert.truthy(text:find("a recipe you don't know: recipe 3922", 1, true))
		assert.truthy(text:find("1 reagent slots: 2x 2835", 1, true))
		W.fire("TRADE_SKILL_CLOSE")
		assert.truthy(report():find("Profession window open now: no", 1, true))
	end)

	it("falls back to saved recipes for the reagent check after a relog", function()
		SK.Profile:Own().recipes = { [202] = { [3918] = 4357 } }
		C_TradeSkillUI.GetRecipeSchematic = nil
		local text = report()
		assert.truthy(text:find("a recipe you know: recipe 3918: no reagents (no GetRecipeSchematic)", 1, true))
	end)

	it("reports each candidate specialisation spell", function()
		_G.C_SpellBook = { IsSpellKnown = function(id) return id == 20219 end }
		local text = report()
		assert.truthy(text:find("Eng 20219 (Gnomish Engineer): known=yes via C_SpellBook.IsSpellKnown", 1, true))
		assert.truthy(text:find("Eng 20222 (Goblin Engineer): known=no", 1, true))
		assert.truthy(text:find("LW 10656", 1, true))
		assert.truthy(text:find("BS 17039", 1, true))
		_G.C_SpellBook = nil
	end)

	it("every specialisation ID is confirmed (the game's names matched on 5 Nov)", function()
		for _, list in pairs(SK.Data.SPECIALISATIONS) do
			for _, spec in ipairs(list) do assert.equal("ok", spec.status) end
		end
		assert.is_nil(SK.Data.SPECIALISATIONS[171]) -- Alchemy: TBC
		assert.is_nil(SK.Data.SPECIALISATIONS[197]) -- Tailoring: TBC
	end)

	it("degrades when the client has none of the new APIs", function()
		C_TradeSkillUI.GetCategoryInfo, C_TradeSkillUI.GetRecipeSchematic = nil, nil
		assert.is_nil(SK.Compat.CategoryInfo(1))
		assert.is_nil((SK.Compat.RecipeSchematic(1)))
		local known, how = SK.Compat.IsSpellKnown(1)
		assert.is_nil(known)
		assert.equal("none", how)
		C_TradeSkillUI.GetRecipeSchematic = function() error("boom") end
		local s, why = SK.Compat.RecipeSchematic(1)
		assert.is_nil(s)
		assert.truthy(why:find("boom", 1, true))
	end)
end)
