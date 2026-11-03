-- Tests for v0.2.2: the Overview tab and the local milestones feed.
local H = require("tests.helpers.load")

local function profile(SK, guid, fields)
	local p = { v = 1, guid = guid, name = guid, updated = 1, gear = {} }
	for k, v in pairs(fields or {}) do p[k] = v end
	p.hash = SK.Profile.HashOf(p)
	return p
end

describe("v0.2.2 milestones feed", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
	end)

	it("finds level, skill, attunement and recipe milestones", function()
		local old = { level = 58, profs = { [197] = { name = "Tailoring", rank = 290 } },
			recipes = { [197] = { [1] = 0 } }, att = { ony = false } }
		local new = { level = 60, profs = { [197] = { name = "Tailoring", rank = 300 } },
			recipes = { [197] = { [1] = 0, [2] = 5, [3] = 6 } }, att = { ony = true } }
		local ev = SK.Feed.Diff(old, new)
		local texts = {}
		for _, e in ipairs(ev) do texts[#texts + 1] = e.text end
		assert.same({ "reached level 60", "reached Tailoring 300", "is attuned to Onyxia's Lair",
			"learned 2 new Tailoring recipes" }, texts)
		assert.equal("level 60", ev[1].grats)
		assert.is_nil(ev[4].grats) -- no Grats button for recipes
	end)

	it("reports only the highest milestone crossed, and nothing for small steps", function()
		local ev = SK.Feed.Diff({ level = 18 }, { level = 41 })
		assert.equal(1, #ev)
		assert.equal("reached level 40", ev[1].text)
		assert.equal(0, #SK.Feed.Diff({ level = 41 }, { level = 42 }))
	end)

	it("says nothing about a first copy or a first profession scan", function()
		assert.equal(0, #SK.Feed.Diff(nil, { level = 60 }))
		local ev = SK.Feed.Diff({ level = 60, recipes = {} }, { level = 60, recipes = { [197] = { [1] = 0 } } })
		assert.equal(0, #ev)
	end)

	it("records milestones from guildmates' profiles, newest first, without duplicates", function()
		W.member("Pip", W.player.guid)
		W.member("Bob Smith", "Player-1-B", { class = "WARRIOR" })
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		local function deliver(p)
			SK.Sync:OnCommReceived(SK.PREFIX, H.peerMessage(SK, "PR", { prof = p }, "Player-1-B"), "WHISPER", "Bob Smith")
		end
		deliver(profile(SK, "Player-1-B", { level = 39, updated = W.now - 10 }))
		assert.equal(0, #SK.DB.feed) -- first copy: nothing
		deliver(profile(SK, "Player-1-B", { level = 40, updated = W.now - 5 }))
		assert.equal(1, #SK.DB.feed)
		local e = SK.Feed.Entries(SK.DBM:Guild())[1]
		assert.equal("Bob Smith", e.name)
		assert.equal("reached level 40", e.text)
		assert.equal("Grats Bob on level 40!", SK.Feed.GratsText(e))
		SK.Feed:Note("Player-1-B", { level = 39 }, { level = 40 }, W.now)
		assert.equal(1, #SK.DB.feed)
	end)

	it("records our own milestones and respects the setting", function()
		W.member("Pip", W.player.guid)
		SK.Identity:ReadRoster()
		W.player.level = 59
		SK.Profile:BuildSelf()
		W.player.level = 60
		SK.Profile:BuildSelf()
		assert.equal("reached level 60", SK.DB.feed[1].text)
		SK.DB.settings.feed = false
		assert.equal(0, SK.Feed:Note(W.player.guid, { level = 1 }, { level = 10 }, W.now))
	end)

	it("keeps at most 50 entries and hides members who left", function()
		W.member("Pip", W.player.guid)
		SK.Identity:ReadRoster()
		for i = 1, 60 do SK.Feed:Note(W.player.guid, { level = 1 }, { level = 10 }, i); SK.DB.feed[1].text = "x" .. i end
		assert.equal(50, #SK.DB.feed)
		SK.Feed:Note("Player-9-GONE", { level = 50 }, { level = 60 }, W.now)
		for _, e in ipairs(SK.Feed.Entries(SK.DBM:Guild())) do assert.are_not.equal("Player-9-GONE", e.guid) end
	end)
end)

describe("v0.2.2 Overview numbers", function()
	local SK, W, guild
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pip", W.player.guid, { level = 60 })
		W.member("Ann", "A", { level = 60 })
		W.member("Ann Alt", "A2", { level = 42, online = false })
		W.member("Ben", "B", { level = 60, online = false })
		W.member("Cid", "C", { level = 30, online = false }) -- no data
		W.professions = { { name = "Tailoring", rank = 300, max = 300, skillLine = 197 } }
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		guild = SK.DBM:Guild()
		local P = guild.profiles
		P.A = profile(SK, "A", { level = 60, updated = W.now, family = { "A2" }, att = { ony = true, ony_item = false },
			profs = { [171] = { name = "Alchemy", rank = 300, scanned = 1 } }, recipes = { [171] = { [100] = 7, [101] = 8 } } })
		P.A2 = profile(SK, "A2", { level = 42, updated = W.now, family = { "A" },
			profs = { [171] = { name = "Alchemy", rank = 150 } } }) -- not scanned
		P.B = profile(SK, "B", { level = 60, updated = W.now - 10 * 86400, att = { ony = false },
			profs = { [171] = { name = "Alchemy", rank = 280, scanned = 1 } }, recipes = { [171] = { [100] = 7 } } })
		SK.Identity:Member("A").addonSeen = W.now
		SK.Identity:Member("B").addon = "0.0.1"
	end)

	it("counts members, players, online and levels", function()
		local o = SK.Overview.Build(guild, W.now)
		assert.equal(5, o.members)
		assert.equal(4, o.players)     -- Ann and her alt count once
		assert.equal(2, o.online)      -- Pip, Ann
		assert.equal(2, o.withAddon)   -- Pip (us), Ann (heard from)
		assert.equal(4, o.withData)
		assert.same({ 3, 0, 1, 1 }, o.levels)
		assert.equal(60, o.maxLevel)
	end)

	it("finds data-health problems", function()
		local o = SK.Overview.Build(guild, W.now)
		assert.equal(1, o.noData)      -- Cid
		assert.equal(1, o.stale)       -- Ben, 10 days old
		assert.equal(2, o.unscanned)   -- Pip's Tailoring (we never opened it) and Ann Alt's Alchemy
		assert.equal(1, o.outdated)    -- Ben runs 0.0.1
		assert.truthy(SK.OverviewTab.HealthText(o):find("Member without Short Kings data  " .. SK.Theme.Code("dim") .. "1|r", 1, true))
	end)

	it("summarises professions and recipes", function()
		local o = SK.Overview.Build(guild, W.now)
		assert.equal(3, o.profs[171].count)
		assert.equal(1, o.profs[171].maxed)
		assert.equal(1, o.profs[197].count)
		assert.equal(0, o.profs[202].count)
		assert.truthy(SK.OverviewTab.ProfessionText(o):find("Engineering  " .. SK.Theme.Code("bad") .. "nobody", 1, true))
		assert.equal(2, o.recipes.total)
		assert.equal(1, o.recipes.single) -- recipe 101: only Ann
	end)

	it("counts raid attunement among max-level characters", function()
		local o = SK.Overview.Build(guild, W.now)
		local ony
		for _, r in ipairs(o.raids) do if r.key == "ony" then ony = r end end
		assert.equal(3, ony.eligible)   -- Pip, Ann, Ben (level 60)
		assert.equal(1, ony.yes)        -- Ann (quest done)
		assert.equal(2, ony.no)         -- Pip, Ben
		assert.equal(1, ony.noItem)     -- Ann's amulet isn't in her bags
		assert.equal("none", o.raids[1].status)
		assert.equal(3, o.raids[1].eligible)
		assert.equal(math.ceil((1796774400 - W.now) / 86400), o.raidDays)
		local text = SK.OverviewTab.RaidText(o)
		assert.truthy(text:find("1 without the amulet in their bags", 1, true))
		assert.truthy(text:find("no attunement needed", 1, true))
	end)

	it("handles no guild at all", function()
		local o = SK.Overview.Build(nil, W.now)
		assert.equal(0, o.members)
		assert.truthy(SK.OverviewTab.RecipeText(o):find("Recipes appear", 1, true))
	end)
end)

describe("v0.2.2 Overview tab", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pip", W.player.guid)
		W.member("Bob", "Player-1-B", { online = false })
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
	end)

	it("is the first tab and opens first once, then remembers your last tab", function()
		assert.equal("overview", SK.MainFrame.tabs[1].key)
		SK.MainFrame:Toggle()
		assert.equal("overview", SK.MainFrame.current)
		assert.truthy(SK.OverviewTab.header:GetText():find("2 members", 1, true))
		SK.MainFrame:Select("crafters")
		SK.MainFrame.current = nil
		SK.MainFrame:Refresh()
		assert.equal("crafters", SK.MainFrame.current)
	end)

	it("card buttons jump to the right place", function()
		SK.MainFrame:Show("overview")
		SK.OverviewTab.raids.button:GetScript("OnClick")(SK.OverviewTab.raids.button)
		assert.equal("roster", SK.MainFrame.current)
		assert.equal("ony", SK.DB.settings.roster.raid)
		SK.MainFrame:Select("overview")
		SK.OverviewTab.health.button:GetScript("OnClick")(SK.OverviewTab.health.button)
		assert.is_nil(SK.DB.settings.roster.raid)
		assert.equal(9, SK.RosterTab.list.sortCol)
		assert.equal("Player-1-B", SK.RosterTab.list.items[1].guid) -- no data comes first
		SK.MainFrame:Select("overview")
		SK.OverviewTab.recipes.button:GetScript("OnClick")(SK.OverviewTab.recipes.button)
		assert.equal("crafters", SK.MainFrame.current)
	end)

	it("lists milestones with a Grats button that only pre-fills guild chat", function()
		SK.Feed:Note("Player-1-B", { level = 59 }, { level = 60 }, W.now)
		SK.MainFrame:Show("overview")
		local list = SK.OverviewTab.feed.list
		assert.equal(1, #list.items)
		assert.is_false(SK.OverviewTab.feed.empty:IsShown())
		local row = list.rows[1]
		row.grats:GetScript("OnClick")(row.grats)
		assert.same({ "open", "/g Grats Bob on level 60!" }, W.chat[#W.chat])
	end)
end)
