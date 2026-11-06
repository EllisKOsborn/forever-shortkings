-- luacheck: globals C_TradeSkillUI
-- v0.3.0 Professions: coverage board, one profession, cooldown board,
-- specialisations, reagents, favourites and freshness nudges.
local H = require("tests.helpers.load")

local R_ARCANITE, R_MOONCLOTH, R_TITAN = 17187, 18560, 17635 -- recipe IDs used as plain test data
local ARCANITE_BAR, MOONCLOTH = 12360, 14342
local ANN, BEN, CID, DOT = "Player-1-A", "Player-1-B", "Player-1-C", "Player-1-D"

local function profile(SK, guid, fields)
	local p = { v = 1, guid = guid, name = guid, updated = 1, gear = {} }
	for k, v in pairs(fields or {}) do p[k] = v end
	p.hash = SK.Profile.HashOf(p)
	return p
end

local function setup()
	local SK, W = H.load()
	H.loadUI(SK)
	W.member("Pip", W.player.guid)
	W.member("Ann", ANN)
	W.member("Ben", BEN, { online = false })
	W.member("Cid", CID)
	W.member("Dot", DOT, { online = false })
	W.professions = { { name = "Tailoring", rank = 250, max = 300, skillLine = 197 } }
	SK.Identity:ReadRoster()
	SK.Profile:BuildSelf()
	local guild = SK.DBM:Guild()
	local P = guild.profiles
	P[ANN] = profile(SK, ANN, { received = W.now - 60,
		profs = { [171] = { name = "Alchemy", rank = 300, max = 300, scanned = W.now - 3600 } },
		recipes = { [171] = { [R_ARCANITE] = ARCANITE_BAR, [R_TITAN] = 0 } },
		cds = { [R_ARCANITE] = W.now + 7200 } })
	P[BEN] = profile(SK, BEN, { received = W.now - 3 * 86400,
		profs = { [171] = { name = "Alchemy", rank = 280, scanned = W.now - 10 * 86400 },
			[202] = { name = "Engineering", rank = 230, specs = { 20219 } } },
		recipes = { [171] = { [R_ARCANITE] = ARCANITE_BAR } },
		cds = { [R_ARCANITE] = W.now - 10 } })
	P[CID] = profile(SK, CID, { hidden = { recipes = true },
		profs = { [171] = { name = "Alchemy", rank = 300, scanned = W.now } } })
	P[DOT] = profile(SK, DOT, { profs = { [186] = { name = "Mining", rank = 300 } } })
	SK.Identity:Member(ANN).addonSeen = W.now
	W.itemNames[ARCANITE_BAR] = "Arcanite Bar"
	W.itemNames[MOONCLOTH] = "Mooncloth"
	W.spellNames[R_ARCANITE] = "Transmute: Arcanite"
	W.spellNames[R_TITAN] = "Elixir of the Titans"
	return SK, W, guild
end

local function byLine(rows)
	local out = {}
	for _, r in ipairs(rows) do out[r.skillLine] = r end
	return out
end

describe("v0.3 coverage board", function()
	local SK, W
	before_each(function() SK, W = setup() end)

	it("has a row for every profession, crafting first, then gathering, then secondary", function()
		local rows = SK.ProfBoard.Coverage(SK.ProfBoard.Context(W.now))
		assert.equal(12, #rows)
		local groups = {}
		for _, r in ipairs(rows) do groups[#groups + 1] = r.group end
		for i = 2, #groups do assert.is_true(groups[i - 1] <= groups[i]) end
		assert.equal("Alchemy", rows[1].name)
		assert.equal(3, rows[#rows].group)
	end)

	it("counts characters, at max, online, top skill, latest scan and specialisations", function()
		local rows = byLine(SK.ProfBoard.Coverage(SK.ProfBoard.Context(W.now)))
		local alch = rows[171]
		assert.equal(3, alch.chars)      -- Ann, Ben, Cid
		assert.equal(2, alch.atMax)      -- Ann, Cid
		assert.equal(2, alch.online)     -- Ann, Cid (Ben is offline)
		assert.equal(300, alch.top)
		assert.equal(W.now - 3600, alch.lastScan) -- Cid's newer scan is private
		assert.same({ ["Gnomish Engineer"] = 1 }, rows[202].specs)
		assert.equal("Gnomish Engineer 1", SK.ProfBoard.SpecText(rows[202].specs))
		assert.equal(0, rows[333].chars) -- Enchanting: nobody
		assert.equal(1, rows[186].chars)
		assert.equal(1, rows[197].chars) -- our own Tailoring
	end)

	it("ignores members who left and spec IDs it doesn't know", function()
		local guild = SK.DBM:Guild()
		guild.members[DOT].leftAt = W.now
		guild.profiles[BEN].profs[202].specs = { 999999 }
		local rows = byLine(SK.ProfBoard.Coverage(SK.ProfBoard.Context(W.now)))
		assert.equal(0, rows[186].chars)
		assert.same({}, rows[202].specs)
	end)
end)

describe("v0.3 one profession", function()
	local SK, W
	before_each(function() SK, W = setup() end)

	it("lists crafters reachable first, with skill, specs and recipe age", function()
		local list = SK.ProfBoard.Crafters(SK.ProfBoard.Context(W.now), 171)
		assert.equal(3, #list)
		assert.equal("offline", list[3].status) -- Ben
		local cid
		for _, c in ipairs(list) do if c.guid == CID then cid = c end end
		assert.is_true(cid.hidden)
		assert.is_nil(cid.scanned) -- private recipes: no "recorded" date
		local eng = SK.ProfBoard.Crafters(SK.ProfBoard.Context(W.now), 202)
		assert.same({ "Gnomish Engineer" }, eng[1].specs)
	end)

	it("starred crafters come first within the same status", function()
		SK.Identity:Member(CID).addonSeen = W.now -- Ann and Cid: same status
		local ctx = SK.ProfBoard.Context(W.now)
		local before = SK.ProfBoard.Crafters(ctx, 171)
		assert.equal(before[1].status, before[2].status)
		local second = before[2].guid
		SK.Favourites.ToggleCrafter(second)
		local after = SK.ProfBoard.Crafters(SK.ProfBoard.Context(W.now), 171)
		assert.equal(second, after[1].guid)
		assert.is_true(after[1].fav)
	end)

	it("filters recipes: all, only one crafter, favourites, nobody knows", function()
		local ctx = SK.ProfBoard.Context(W.now)
		local all = SK.ProfBoard.Recipes(ctx, 171, "all")
		assert.equal(2, #all)
		local one = SK.ProfBoard.Recipes(ctx, 171, "one")
		assert.equal(1, #one)
		assert.equal(R_TITAN, one[1].recipeID)
		assert.equal(0, #SK.ProfBoard.Recipes(ctx, 171, "fav"))
		SK.Favourites.ToggleRecipe(R_ARCANITE)
		local fav = SK.ProfBoard.Recipes(SK.ProfBoard.Context(W.now), 171, "fav")
		assert.equal(1, #fav)
		assert.is_true(fav[1].fav)
		-- nothing unknown until a window has listed an unlearned recipe
		assert.equal(0, #SK.ProfBoard.Unknown(ctx, 171))
		SK.DBM:Guild().recipeUniverse[171] = { [R_ARCANITE] = ARCANITE_BAR, [99] = 5 }
		local nobody = SK.ProfBoard.Recipes(SK.ProfBoard.Context(W.now), 171, "nobody")
		assert.equal(1, #nobody)
		assert.equal(99, nobody[1].recipeID)
		assert.equal(0, nobody[1].count)
	end)
end)

describe("v0.3 cooldown board", function()
	local SK, W
	before_each(function() SK, W = setup() end)

	it("lists ready cooldowns first, then by time left, and flags old data", function()
		local rows = SK.ProfBoard.Cooldowns(SK.ProfBoard.Context(W.now))
		assert.equal(2, #rows)
		assert.equal(BEN, rows[1].guid)
		assert.is_true(rows[1].ready)
		assert.is_true(rows[1].stale)  -- heard from 3 days ago
		assert.is_nil(rows[1].whisper) -- offline
		assert.equal(ANN, rows[2].guid)
		assert.equal(7200, rows[2].left)
		assert.is_false(rows[2].stale)
		assert.equal("2h 0m", SK.ProfBoard.TimeLeft(rows[2].left))
	end)

	it("formats time left", function()
		assert.equal("Ready", SK.ProfBoard.TimeLeft(0))
		assert.equal("1m", SK.ProfBoard.TimeLeft(20))
		assert.equal("45m", SK.ProfBoard.TimeLeft(45 * 60))
		assert.equal("2d 4h", SK.ProfBoard.TimeLeft(2 * 86400 + 4 * 3600 + 5))
	end)

	it("never shows cooldowns from someone who keeps recipes private", function()
		local guild = SK.DBM:Guild()
		guild.profiles[CID].cds = { [R_ARCANITE] = W.now }
		for _, r in ipairs(SK.ProfBoard.Cooldowns(SK.ProfBoard.Context(W.now))) do
			assert.is_not.equal(CID, r.guid)
		end
	end)
end)

describe("v0.3 specialisations", function()
	local SK, W
	before_each(function()
		SK, W = setup()
		W.professions = { { name = "Engineering", rank = 250, max = 300, skillLine = 202 } }
	end)
	after_each(function() _G.C_SpellBook = nil end)

	it("are read only when the client's spell name matches", function()
		_G.C_SpellBook = { IsSpellKnown = function(id) return id == 20219 or id == 20222 end }
		W.spellNames[20219] = "Gnomish Engineer"
		W.spellNames[20222] = "Something Else" -- wrong ID on this client: ignored
		for _, spec in ipairs(SK.Data.SPECIALISATIONS[202]) do spec.status = "todo" end -- not confirmed
		SK.Profile:BuildSelf()
		assert.same({ 20219 }, SK.Profile:Own().profs[202].specs)
		-- and they reach the shared copy, which still passes guildmates' checks
		local pub = SK.DBM:Guild().profiles[W.player.guid]
		assert.same({ 20219 }, pub.profs[202].specs)
		assert.is_true((SK.Merge.Validate(pub)))
		for _, spec in ipairs(SK.Data.SPECIALISATIONS[202]) do spec.status = "ok" end
	end)

	it("a confirmed ID (status ok) doesn't need the name check", function()
		_G.C_SpellBook = { IsSpellKnown = function(id) return id == 20222 end }
		W.spellNames[20222] = "Gobelin" -- e.g. a French client
		assert.same({ 20222 }, SK.Professions.ReadSpecs(202))
	end)

	it("nothing is recorded when the client can't tell", function()
		assert.is_nil(SK.Professions.ReadSpecs(202))
		assert.is_nil(SK.Professions.ReadSpecs(171)) -- Alchemy: none in the original game
	end)

	it("guildmates' checks reject malformed specs", function()
		local p = profile(SK, ANN, { profs = { [202] = { name = "Engineering", rank = 1, specs = { "x" } } } })
		assert.is_false((SK.Merge.Validate(p)))
		p = profile(SK, ANN, { profs = { [202] = { name = "Engineering", rank = 1, specs = { 1, 2, 3, 4, 5 } } } })
		assert.is_false((SK.Merge.Validate(p)))
		p = profile(SK, ANN, { profs = { [202] = { name = "Engineering", rank = 1, specs = { 20219 } } } })
		assert.is_true((SK.Merge.Validate(p)))
	end)
end)

describe("v0.3 reagents", function()
	local SK, W
	before_each(function()
		SK, W = setup()
		C_TradeSkillUI.GetRecipeSchematic = function(id)
			if id ~= R_ARCANITE then return { reagentSlotSchematics = {} } end
			return { name = "Transmute: Arcanite", outputItemID = ARCANITE_BAR, quantityMin = 1, quantityMax = 1,
				reagentSlotSchematics = {
					{ quantityRequired = 1, required = true, reagents = { { itemID = 12359 } } },
					{ quantityRequired = 1, required = true, reagents = { { itemID = 12363 } } },
				} }
		end
		W.itemNames[12359] = "Thorium Bar"
		W.itemNames[12363] = "Arcane Crystal"
	end)

	it("reads reagents from the game, caches them, and shows bag counts", function()
		W.bags[12359] = 3
		local lines = SK.Reagents.Lines(R_ARCANITE)
		assert.equal(2, #lines)
		assert.equal(12359, lines[1].itemID)
		assert.equal(3, lines[1].have)
		assert.equal(0, lines[2].have)
		assert.truthy(SK.DB.reagents.list[R_ARCANITE])
		-- cached: works even when the game stops answering
		C_TradeSkillUI.GetRecipeSchematic = nil
		W.advance(1) -- names arrive
		local text = SK.Reagents.Text(SK.Reagents.Lines(R_ARCANITE))
		assert.truthy(text:find("1 Thorium Bar (have 3)", 1, true))
		assert.truthy(text:find("1 Arcane Crystal (have 0)", 1, true))
	end)

	it("an empty answer is not cached, and a new game build clears the cache", function()
		assert.is_nil(SK.Reagents.Lines(R_TITAN))
		assert.is_nil(SK.DB.reagents.list[R_TITAN])
		SK.Reagents.Learn(R_ARCANITE)
		SK.DB.reagents.build = "older"
		C_TradeSkillUI.GetRecipeSchematic = nil
		assert.is_nil(SK.Reagents.Learn(R_ARCANITE))
	end)

	it("are learned during a profession scan and never synced", function()
		W.tradeskill = { skillLine = 171, name = "Alchemy", rank = 300, max = 300,
			recipes = { [R_ARCANITE] = { learned = true, itemID = ARCANITE_BAR } } }
		SK.Professions:Scan()
		W.advance(1)
		assert.truthy(SK.DB.reagents.list[R_ARCANITE])
		local pub = SK.DBM:Guild().profiles[W.player.guid]
		assert.is_nil(pub.reagents)
		assert.is_nil(SK.Codec.Encode(pub):find("Thorium", 1, true))
	end)
end)

describe("v0.3 favourites", function()
	local SK
	before_each(function() SK = setup() end)

	it("toggle on and off, stay local and never reach the shared profile", function()
		assert.is_true(SK.Favourites.ToggleRecipe(R_ARCANITE))
		assert.is_true(SK.Favourites.IsRecipe(R_ARCANITE))
		assert.is_false(SK.Favourites.ToggleRecipe(R_ARCANITE))
		assert.is_false(SK.Favourites.IsRecipe(R_ARCANITE))
		SK.Favourites.ToggleCrafter(ANN)
		SK.Profile:BuildSelf()
		local pub = SK.DBM:Guild().profiles[SK.Compat.PlayerGUID()]
		assert.is_nil(pub.favourites)
		assert.is_true(SK.DB.favourites.crafters[ANN])
	end)

	it("the Crafters tab can list only starred recipes", function()
		SK.Favourites.ToggleRecipe(R_TITAN)
		local idx = SK.CraftIndex:Rebuild()
		local results = SK.CraftIndex.FavouriteResults(idx, SK.Favourites.Recipes(), "")
		assert.equal(1, #results)
		assert.equal(R_TITAN, results[1].recipeID)
		assert.equal(0, #SK.CraftIndex.FavouriteResults(idx, SK.Favourites.Recipes(), "arcanite"))
	end)
end)

describe("v0.3 freshness nudges", function()
	local SK, W
	before_each(function()
		SK, W = setup()
		W.tradeskill = { skillLine = 197, name = "Tailoring", rank = 240, max = 300,
			recipes = { [R_MOONCLOTH] = { learned = true, itemID = MOONCLOTH } } }
		W.professions = { { name = "Tailoring", rank = 240, max = 300, skillLine = 197 } }
		SK.Profile:BuildSelf()
		SK.Professions:Scan()
		W.advance(1)
	end)

	local function levelTo(rank)
		W.professions = { { name = "Tailoring", rank = rank, max = 300, skillLine = 197 } }
		SK.Profile:BuildSelf()
	end

	it("only after a real gain since the last scan", function()
		levelTo(240 + SK.Professions.NUDGE_POINTS - 1)
		assert.same({}, SK.Professions.CurrentNudges())
		levelTo(262)
		local n = SK.Professions.CurrentNudges()
		assert.equal(1, #n)
		assert.equal("Your Tailoring went from 240 to 262 since you last opened it. Open the window to update your recipes.",
			SK.Professions.NudgeText(n))
	end)

	it("chat says it at most once per session and once every few days", function()
		levelTo(262)
		assert.is_true(SK.Professions:Nudge(W.now))
		assert.is_false(SK.Professions:Nudge(W.now)) -- same session
		SK.Professions.nudged = nil                    -- next session...
		assert.is_false(SK.Professions:Nudge(W.now + 86400)) -- ...but only a day later
		assert.is_true(SK.Professions:Nudge(W.now + SK.Professions.NUDGE_EVERY + 1))
	end)

	it("can be turned off, and goes away once the window is opened again", function()
		levelTo(262)
		SK.DB.settings.profNudges = false
		assert.is_false(SK.Professions:Nudge(W.now))
		W.tradeskill.rank = 262
		SK.Professions:Scan()
		W.advance(1)
		assert.same({}, SK.Professions.CurrentNudges())
	end)

	it("older data starts counting from today instead of nagging", function()
		SK.DB.scanRank = {}
		levelTo(290)
		assert.same({}, SK.Professions.CurrentNudges())
		assert.equal(290, SK.DB.scanRank[W.player.guid][197])
	end)
end)

describe("v0.3 gathering professions with recipes (Forever's camping items)", function()
	it("are scanned, indexed and shown like crafting ones", function()
		local SK, W = setup()
		W.professions = { { name = "Herbalism", rank = 4, max = 75, skillLine = 182 } }
		SK.Profile:BuildSelf()
		-- What the owner's game listed on 6 Nov: category "Camping", nothing learned yet
		W.tradeskill = { skillLine = 182, name = "Herbalism", rank = 4, max = 75, recipes = {
			[1263070] = { learned = true, itemID = 279947 }, [1263071] = { learned = false, itemID = 0 } } }
		SK.Professions:Scan()
		W.advance(1)
		assert.same({ [1263070] = 279947 }, SK.Profile:Own().recipes[182])
		local ctx = SK.ProfBoard.Context(W.now)
		assert.equal(1, #SK.ProfBoard.Recipes(ctx, 182, "all"))
		assert.equal(1, #SK.ProfBoard.Unknown(ctx, 182))
		local me = SK.ProfBoard.Crafters(ctx, 182)[1]
		assert.equal(W.now - 1, me.scanned)
		local text = SK.CharacterTab.DetailText(SK.Profile:Own(), W.now)
		assert.truthy(text:find("1 recipe", 1, true))
	end)
end)

describe("v0.3 Professions tab", function()
	local SK, W
	before_each(function() SK, W = setup() end)

	it("shows the board, one profession, cooldowns, and opens recipes in Crafters", function()
		SK.MainFrame:Show("professions")
		local tab = SK.ProfessionsTab
		assert.equal(12, #tab.board.items)
		tab:Open(171)
		assert.equal(3, #tab.crafters.items)
		assert.equal(2, #tab.recipes.items)
		assert.is_false(tab.filterChips[4]:IsShown()) -- "Nobody knows": nothing unknown yet
		tab.filter = "one"
		tab:Refresh()
		assert.equal(1, #tab.recipes.items)
		tab.skillLine = nil
		SK.DB.settings.profView = "cooldowns"
		tab:Refresh()
		assert.equal(2, #tab.cooldowns.items)
		-- a recipe nobody knows still opens in Crafters
		SK.DBM:Guild().recipeUniverse[171] = { [99] = 5 }
		SK.CraftersTab:ShowRecipe(99, 171)
		assert.equal("crafters", SK.MainFrame.current)
		assert.equal(99, SK.CraftersTab:Picked(SK.CraftIndex:Get()).recipeID)
		assert.equal(0, #SK.CraftersTab.crafters.items)
		assert.equal(0, #SK.errors)
	end)

	it("Crafters shows reagents and the Favourites filter", function()
		C_TradeSkillUI.GetRecipeSchematic = function()
			return { reagentSlotSchematics = { { quantityRequired = 2, reagents = { { itemID = 12359 } } } } }
		end
		SK.MainFrame:Show("crafters")
		SK.CraftersTab:Select(R_ARCANITE)
		local text = SK.CraftersTab.reagents:GetText()
		assert.truthy(text:find("Needs: ", 1, true))
		assert.truthy(text:find("2 ... ", 1, true) and text:find("(have 0)", 1, true))
		SK.Favourites.ToggleRecipe(R_ARCANITE)
		SK.CraftersTab.favOnly = true
		SK.CraftersTab:Refresh()
		assert.equal(1, #SK.CraftersTab.results.items)
		assert.equal(0, #SK.errors)
	end)

	it("shows the reminder line on the tab", function()
		SK.DB.scanRank[W.player.guid] = { [197] = 200 }
		SK.Profile:Own().profs[197].scanned = W.now
		SK.MainFrame:Show("professions")
		assert.truthy(SK.ProfessionsTab.nudge:GetText():find("Tailoring went from 200 to 250", 1, true))
	end)
end)
