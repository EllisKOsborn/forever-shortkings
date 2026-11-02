-- Tests for v0.2.0: the craft index, Crafters tab and "Crafted by" tooltips.
local H = require("tests.helpers.load")

local ARCANITE_BAR, MOONCLOTH = 12360, 14342
local R_ARCANITE, R_MOONCLOTH, R_BOOTS = 17187, 18560, 20023 -- recipe (spell) IDs used as plain test data

local function profile(SK, guid, fields)
	local p = { v = 1, guid = guid, name = guid, updated = 1, gear = {} }
	for k, v in pairs(fields or {}) do p[k] = v end
	p.hash = SK.Profile.HashOf(p)
	return p
end

describe("v0.2 craft index", function()
	local SK, W, guild
	local ANN, BEN, CID, DOT, DOTALT = "A", "B", "C", "D", "D2"
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pip", W.player.guid)
		W.member("Ann", ANN)
		W.member("Ben", BEN, { online = false })
		W.member("Cid", CID)
		W.member("Dot", DOT, { online = false })
		W.member("Dotty", DOTALT)
		W.professions = { { name = "Alchemy", rank = 290, max = 300, skillLine = 171 } }
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		guild = SK.DBM:Guild()
		local P = guild.profiles
		P[ANN] = profile(SK, ANN, { profs = { [171] = { name = "Alchemy", rank = 300 } },
			recipes = { [171] = { [R_ARCANITE] = ARCANITE_BAR } } })
		P[BEN] = profile(SK, BEN, { profs = { [171] = { name = "Alchemy", rank = 275 }, [197] = { name = "Tailoring", rank = 300 } },
			recipes = { [171] = { [R_ARCANITE] = ARCANITE_BAR }, [197] = { [R_MOONCLOTH] = MOONCLOTH } } })
		P[CID] = profile(SK, CID, { hidden = { recipes = true }, profs = { [171] = { name = "Alchemy", rank = 300 } } })
		P[DOT] = profile(SK, DOT, { family = { DOTALT }, profs = { [333] = { name = "Enchanting", rank = 300 } },
			recipes = { [333] = { [R_BOOTS] = 0 } } })
		P[DOTALT] = profile(SK, DOTALT, { family = { DOT }, level = 10 })
		W.itemNames[ARCANITE_BAR] = "Arcanite Bar"
		W.itemNames[MOONCLOTH] = "Mooncloth"
		W.spellNames[R_ARCANITE] = "Transmute: Arcanite"
		W.spellNames[R_MOONCLOTH] = "Mooncloth"
		W.spellNames[R_BOOTS] = "Enchant Boots - Minor Speed"
		SK.Identity:Member(ANN).addonSeen = W.now
	end)

	it("indexes recipes by recipe and by item, skipping hidden recipes", function()
		local idx = SK.CraftIndex:Rebuild()
		assert.equal(3, idx.recipeCount)
		assert.equal(3, idx.crafterCount)   -- Ann, Ben, Dot (Cid hides recipes)
		assert.same({ ANN, BEN }, idx.recipes[R_ARCANITE].crafters)
		assert.same({ R_ARCANITE }, idx.byItem[ARCANITE_BAR])
		assert.equal(0, idx.recipes[R_BOOTS].itemID) -- enchant: no item
		assert.is_nil(idx.byItem[0])
		assert.equal(300, idx.skill[ANN][171])
		assert.equal("Tailoring", SK.CraftIndex.ProfessionName(idx, 197))
	end)

	it("uses the full copy for our own characters, even when sharing is off", function()
		SK.DB.settings.share.recipes = false
		W.tradeskill = { skillLine = 171, name = "Alchemy", rank = 290, max = 300,
			recipes = { [R_ARCANITE] = { learned = true, itemID = ARCANITE_BAR } } }
		SK.Professions:Scan()
		W.advance(1)
		assert.is_nil(guild.profiles[W.player.guid].recipes) -- not shared
		local idx = SK.CraftIndex:Rebuild()
		assert.same({ ANN, BEN, W.player.guid }, (function()
			local t = {}
			for _, g in ipairs(idx.recipes[R_ARCANITE].crafters) do t[#t + 1] = g end
			table.sort(t, function(a, b) return a < b end)
			return t
		end)())
	end)

	it("is built lazily and rebuilt (debounced) when profiles change", function()
		assert.is_nil(SK.CraftIndex.index)
		SK.CraftIndex:Get()
		assert.is_not_nil(SK.CraftIndex.index)
		guild.profiles[CID] = profile(SK, CID, { recipes = { [197] = { [R_MOONCLOTH] = MOONCLOTH } } })
		SK:Fire("PROFILE_UPDATED", CID)
		assert.is_true(SK.CraftIndex.dirty)
		assert.equal(1, #SK.CraftIndex:Get(true).recipes[R_MOONCLOTH].crafters) -- stale copy for tooltips
		W.advance(SK.CraftIndex.REBUILD_DELAY + 0.1)
		assert.is_false(SK.CraftIndex.dirty)
		assert.equal(2, #SK.CraftIndex.index.recipes[R_MOONCLOTH].crafters)
	end)

	it("searches item and recipe names, case-insensitively, after names load", function()
		local idx = SK.CraftIndex:Get()
		local results, state = SK.CraftIndex.Search(idx, "arcanite")
		-- "Transmute: Arcanite" matches by its recipe name straight away;
		-- the item name is still loading.
		assert.equal("ok", state)
		assert.equal(1, #results)
		assert.equal("Transmute: Arcanite", results[1].name)
		assert.is_true(#W.requestedItems >= 2)
		local fired = false
		SK:On("NAMES_LOADED", function() fired = true end)
		W.advance(1)
		assert.is_true(fired)
		local loading
		results, state, loading = SK.CraftIndex.Search(idx, "ARCANITE")
		assert.equal("ok", state)
		assert.equal(0, loading)
		assert.equal("Arcanite Bar", results[1].name)
		assert.equal(1, #SK.CraftIndex.Search(idx, "enchant boots"))
		assert.equal(1, #SK.CraftIndex.Search(idx, "mooncloth"))
		assert.equal(0, #SK.CraftIndex.Search(idx, "thorium"))
	end)

	it("asks for at least 3 letters, says when nobody has scanned, and caps results", function()
		local idx = SK.CraftIndex:Get()
		assert.equal("short", select(2, SK.CraftIndex.Search(idx, "ar")))
		assert.equal("empty", select(2, SK.CraftIndex.Search(SK.CraftIndex.Build(nil), "arcanite")))
		local big = { recipes = {}, byItem = {}, skill = {}, profNames = {}, recipeCount = 0 }
		for i = 1, 250 do
			big.recipes[i] = { recipeID = i, itemID = 0, skillLine = 171, crafters = {} }
			big.recipeCount = big.recipeCount + 1
		end
		assert.equal(SK.CraftIndex.MAX_RESULTS, #SK.CraftIndex.Search(big, "spell"))
	end)

	it("lists crafters online first, reachable through an online alt", function()
		local idx = SK.CraftIndex:Get()
		local list = SK.CraftIndex.Crafters(idx, R_ARCANITE, guild, W.now)
		assert.equal("Ann", list[1].name)
		assert.equal("addon", list[1].status)
		assert.equal(ANN, list[1].whisper)
		assert.equal("Ben", list[2].name)
		assert.equal("offline", list[2].status)
		assert.is_nil(list[2].whisper)
		assert.equal(1, SK.CraftIndex.OnlineCount(list))
		local boots = SK.CraftIndex.Crafters(idx, R_BOOTS, guild, W.now)
		assert.equal("online", boots[1].status)  -- Dot is offline, Dotty is online
		assert.equal(DOTALT, boots[1].via)
		assert.equal(DOTALT, boots[1].whisper)
	end)

	it("builds the tooltip line: online first, at most three names", function()
		local idx = SK.CraftIndex:Get()
		assert.equal("Ann (online), Ben", SK.CraftIndex.TooltipText(idx, ARCANITE_BAR, guild, W.now, 3))
		assert.equal("Ann (online) +1 more", SK.CraftIndex.TooltipText(idx, ARCANITE_BAR, guild, W.now, 1))
		assert.is_nil(SK.CraftIndex.TooltipText(idx, 99999, guild, W.now, 3))
	end)

	it("adds the line through TooltipDataProcessor and respects the setting", function()
		SK.Tooltip:OnLogin()
		assert.is_true(SK.Tooltip.hooked)
		assert.equal(1, #W.tooltipHooks)
		assert.equal(0, W.tooltipHooks[1][1]) -- Enum.TooltipDataType.Item
		local lines = {}
		local tip = { AddLine = function(_, text) lines[#lines + 1] = text end }
		W.tooltipHooks[1][2](tip, { id = ARCANITE_BAR })
		assert.equal(1, #lines)
		assert.truthy(lines[1]:find("Ann (online), Ben", 1, true))
		SK.DB.settings.craftTooltips = false
		W.tooltipHooks[1][2](tip, { id = ARCANITE_BAR })
		assert.equal(1, #lines)
		SK.DB.settings.craftTooltips = true
		W.tooltipHooks[1][2](tip, { id = 12345 }) -- nobody makes it
		W.tooltipHooks[1][2](tip, {})             -- no item id
		assert.equal(1, #lines)
	end)

	it("builds a guild chat line under the length limit", function()
		local list = {}
		for i = 1, 60 do list[i] = { name = "Crafter" .. i } end
		local text = SK.CraftIndex.ChatText("[Arcanite Bar]", list, 255)
		assert.is_true(#text <= 255)
		assert.truthy(text:find("^%[Arcanite Bar%] can be made by: Crafter1, Crafter2"))
		assert.truthy(text:find("more$"))
		assert.equal("[X] can be made by: A, B", SK.CraftIndex.ChatText("[X]", { { name = "A" }, { name = "B" } }))
	end)

	it("Crafters tab: search, select, whisper and post to guild chat", function()
		SK.MainFrame:Show("crafters")
		local tab = SK.CraftersTab
		assert.truthy(tab.hint:GetText():find("at least 3 letters", 1, true))
		tab.query = "arcanite"
		tab:Refresh()
		W.advance(1) -- names arrive; the tab refreshes itself
		assert.equal(1, #tab.results.items)
		assert.equal("Arcanite Bar", tab.results.items[1].name)
		assert.equal("2 crafters (1 online)", SK.CraftersTab.CountText(2, 1))
		tab:Select(R_ARCANITE)
		assert.equal(2, #tab.crafters.items)
		assert.truthy(tab.sub:GetText():find("2 crafters (1 online)", 1, true))
		tab:PostToGuild()
		local open = W.chat[#W.chat]
		assert.equal("open", open[1])
		assert.truthy(open[2]:find("^/g |cff0070dd|Hitem:12360"))
		assert.truthy(open[2]:find("can be made by: Ann, Ben", 1, true))
		SK.Compat.SendTell(SK.Identity:WhisperTarget(ANN))
		assert.same({ "tell", "Ann" }, W.chat[#W.chat])
	end)

	it("Crafters tab shows the scan hint when nobody has recipes", function()
		for g, p in pairs(guild.profiles) do
			if g ~= W.player.guid then p.recipes = nil end
		end
		SK.MainFrame:Show("crafters")
		SK.CraftersTab.query = "arcanite"
		SK.CraftersTab:Refresh()
		assert.truthy(SK.CraftersTab.hint:GetText():find("open their profession window once", 1, true))
	end)

	it("the debug report covers the craft index and tooltip hook", function()
		SK.Tooltip:OnLogin()
		local text = table.concat(SK.Commands.BuildReport(), "\n")
		assert.truthy(text:find("Index: 3 recipes from 3 crafters", 1, true))
		assert.truthy(text:find("Item tooltip line: hooked=yes", 1, true))
		assert.is_nil(text:find("missing: C_Item.GetItemNameByID", 1, true))
	end)
end)
