-- v0.3.4: clicking a crafter in the Professions tab shows that crafter's
-- recipes (Character is a separate button), and the Overview says who has
-- Short Royalty and lists who doesn't.
local H = require("tests.helpers.load")

local R_ARCANITE, R_TITAN = 17187, 17635 -- recipe IDs used as plain test data
local ARCANITE_BAR = 12360
local ANN, BEN, CID = "Player-1-A", "Player-1-B", "Player-1-C"

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
	W.member("Ann Smith", ANN, { class = "MAGE" })
	W.member("Ben", BEN, { online = false })
	W.member("Cid", CID)
	SK.Identity:ReadRoster()
	SK.Profile:BuildSelf()
	local guild = SK.DBM:Guild()
	guild.profiles[ANN] = profile(SK, ANN, {
		profs = { [171] = { name = "Alchemy", rank = 300, scanned = W.now - 3600 } },
		recipes = { [171] = { [R_ARCANITE] = ARCANITE_BAR, [R_TITAN] = 0 } } })
	guild.profiles[BEN] = profile(SK, BEN, {
		profs = { [171] = { name = "Alchemy", rank = 280, scanned = W.now } },
		recipes = { [171] = { [R_ARCANITE] = ARCANITE_BAR } } })
	guild.profiles[CID] = profile(SK, CID, { hidden = { recipes = true },
		profs = { [171] = { name = "Alchemy", rank = 300, scanned = W.now } } })
	W.itemNames[ARCANITE_BAR] = "Arcanite Bar"
	W.spellNames[R_ARCANITE] = "Transmute: Arcanite"
	W.spellNames[R_TITAN] = "Elixir of the Titans"
	return SK, W, guild
end

local function ids(rows)
	local out = {}
	for _, r in ipairs(rows) do out[#out + 1] = r.recipeID end
	table.sort(out)
	return out
end

describe("v0.3.4 one crafter's recipes", function()
	local SK, W
	before_each(function() SK, W = setup() end)

	it("ProfBoard.Recipes keeps only that crafter's recipes, with guild-wide counts", function()
		local ctx = SK.ProfBoard.Context(W.now)
		assert.same({ R_ARCANITE, R_TITAN }, ids(SK.ProfBoard.Recipes(ctx, 171, "all", ANN)))
		local ben = SK.ProfBoard.Recipes(ctx, 171, "all", BEN)
		assert.same({ R_ARCANITE }, ids(ben))
		assert.equal(2, ben[1].count) -- Ann knows it too
		assert.same({ R_TITAN }, ids(SK.ProfBoard.Recipes(ctx, 171, "one", ANN))) -- only Ann knows it
		assert.same({}, ids(SK.ProfBoard.Recipes(ctx, 171, "one", BEN)))
		assert.same({}, ids(SK.ProfBoard.Recipes(ctx, 171, "all", CID))) -- private
		assert.same({}, ids(SK.ProfBoard.Recipes(ctx, 171, "nobody", ANN)))
	end)

	it("clicking a crafter shows their recipes; clicking again shows everyone's", function()
		SK.MainFrame:Show("professions")
		local tab = SK.ProfessionsTab
		tab:Open(171)
		assert.equal(2, #tab.recipes.items)
		assert.is_false(tab.picked:IsShown())
		local ben
		for _, c in ipairs(tab.crafters.items) do if c.guid == BEN then ben = c end end
		tab.crafters.opts.onClick(ben, "LeftButton")
		assert.equal("professions", SK.MainFrame.current) -- no jump to the Character tab
		assert.equal(BEN, tab.crafter)
		assert.equal(1, #tab.recipes.items)
		assert.is_true(tab.picked:IsShown())
		assert.truthy(tab.pickedName:GetText():find("Ben", 1, true))
		assert.truthy(tab.status:GetText():find("Ben knows 1 recipe", 1, true))
		assert.is_true(tab.crafters.isSelected(ben))
		assert.is_false(tab.filterChips[4]:IsShown()) -- "Nobody knows" makes no sense for one person
		tab.crafters.opts.onClick(ben, "LeftButton")
		assert.is_nil(tab.crafter)
		assert.equal(2, #tab.recipes.items)
		assert.equal(0, #SK.errors)
	end)

	it("the Character button opens the character; Everyone clears the pick", function()
		SK.MainFrame:Show("professions")
		local tab = SK.ProfessionsTab
		tab:Open(171)
		tab:PickCrafter(ANN)
		tab.charButton:GetScript("OnClick")(tab.charButton)
		assert.equal("character", SK.MainFrame.current)
		SK.MainFrame:Show("professions")
		assert.equal(ANN, tab.crafter) -- still picked when you come back
		tab.everyone:GetScript("OnClick")(tab.everyone)
		assert.is_nil(tab.crafter)
		assert.equal(0, #SK.errors)
	end)

	it("explains an empty list: private recipes, or a window never opened", function()
		SK.MainFrame:Show("professions")
		local tab = SK.ProfessionsTab
		tab:Open(171)
		tab:PickCrafter(CID)
		assert.equal(0, #tab.recipes.items)
		assert.truthy(tab.recipes.emptyText:find("Cid keeps their recipes private", 1, true))
		SK.DBM:Guild().profiles[BEN].profs[171].scanned = nil
		SK.DBM:Guild().profiles[BEN].recipes = nil
		SK.CraftIndex:Get(true)
		tab:PickCrafter(BEN)
		assert.truthy(tab.recipes.emptyText:find("hasn't opened their Alchemy window", 1, true))
	end)

	it("opening another profession forgets the pick", function()
		local tab = SK.ProfessionsTab
		SK.MainFrame:Show("professions")
		tab:Open(171)
		tab:PickCrafter(ANN)
		tab:Open(202)
		assert.is_nil(tab.crafter)
	end)
end)

describe("v0.3.4 who has Short Royalty", function()
	local SK, W, guild
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pip", W.player.guid)                                -- us
		W.member("Ann", "A")                                          -- profile
		W.member("Ben", "B", { online = false })                      -- heard a version, no profile yet
		W.member("Zed Last", "Z", { class = "ROGUE" })                -- online, no addon
		W.member("Cat", "C", { online = false, class = "PRIEST" })    -- offline, no addon
		W.member("Abe", "E", { online = false })                      -- offline, no addon
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		guild = SK.DBM:Guild()
		guild.profiles.A = profile(SK, "A", { updated = W.now })
		SK.Identity:Member("B").addon = "0.3.3"
	end)

	it("counts who has it and lists the rest, online first", function()
		local o = SK.Overview.Build(guild, W.now)
		assert.equal(3, o.hasAddon)     -- Pip, Ann, Ben
		assert.equal(1, o.addonNoData)  -- Ben
		local names = {}
		for _, w in ipairs(o.without) do names[#names + 1] = w.name end
		assert.same({ "Zed Last", "Abe", "Cat" }, names)
		local text = SK.OverviewTab.GuildText(o)
		assert.truthy(text:find("Have Short Royalty", 1, true))
		assert.truthy(text:find("Don't have it yet  " .. SK.Theme.Code("spark") .. "3|r", 1, true))
		local list = SK.OverviewTab.WithoutText(o.without)
		assert.truthy(list:find("Zed", 1, true) and not list:find("Last", 1, true)) -- first names
		assert.truthy(list:find(SK.RosterTab.DOT.online, 1, true))                -- Zed is online
	end)

	it("lists ten names, then says how many more", function()
		local many = {}
		for i = 1, 14 do many[i] = { name = "N" .. i, online = false } end
		local text = SK.OverviewTab.WithoutText(many)
		assert.truthy(text:find("N10", 1, true))
		assert.is_nil(text:find("N11", 1, true))
		assert.truthy(text:find("and 4 more", 1, true))
	end)

	it("Getting started counts everyone who has it, not just who's online", function()
		SK.MainFrame:Show("overview")
		local steps = SK.Onboarding.Steps(SK.Profile:Own(), {}, nil, SK.OverviewTab.data.hasAddon, SK.OverviewTab.data.members)
		local guildStep
		for _, s in ipairs(steps) do if s.key == "guild" then guildStep = s end end
		assert.equal("3 of 6 have it", guildStep.detail)
		assert.is_true(guildStep.done)
	end)

	it("Without addon opens the roster with those members first", function()
		SK.MainFrame:Show("overview")
		SK.OverviewTab.guild.button:GetScript("OnClick")(SK.OverviewTab.guild.button)
		assert.equal("roster", SK.MainFrame.current)
		local items = SK.RosterTab.list.items
		assert.equal("Abe", items[1].name)
		assert.equal("Cat", items[2].name)
		assert.equal("Zed Last", items[3].name)
		assert.is_false(items[1].hasAddon)
		assert.is_true(items[4].hasAddon)
		assert.equal(0, #SK.errors)
	end)
end)
