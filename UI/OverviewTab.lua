-- Overview tab: the guild at a glance, set like a spec sheet in three
-- columns. Each section has a link to the tab where you can act on it.
-- Everything comes from data the addon already has (Core/Overview.lua,
-- Core/Feed.lua).
local _, SK = ...

local Ov = SK:NewModule("OverviewTab")
local Theme, W, Compat = SK.Theme, SK.Widgets, SK.Compat
local S, SP = Theme.SIZES, Theme.SPACE

local CONTENT_W = S.window[1] - 2 * SP.l
Ov.COL_W = math.floor((CONTENT_W - 2 * SP.xl) / 3)
Ov.TOP = 28           -- below the one-line summary
Ov.FEED_H = 196       -- milestones list height

local function n(v) return tostring(v or 0) end

---------------------------------------------------------------------------
-- Section rows (pure; tested). See W.Block for the row format.
---------------------------------------------------------------------------
Ov.NAMES_SHOWN = 10 -- names listed under "Don't have it yet"; the rest go to the Roster

-- "Bob, Cat, Dan and 12 more": first names, class colours, a dot for online.
function Ov.WithoutText(without, max)
	max = max or Ov.NAMES_SHOWN
	local names = {}
	for i = 1, math.min(#without, max) do
		local w = without[i]
		local first = w.name:match("^(%S+)") or w.name
		names[i] = (w.online and (SK.RosterTab.DOT.online .. " ") or "") .. Theme.ClassText(first, w.class)
	end
	local text = table.concat(names, ", ")
	if #without > max then text = text .. Theme.Paint("dim", " and " .. (#without - max) .. " more (point here to see all)") end
	return text
end

Ov.TIP_NAMES = 60 -- names in the hover list (two per line); the Roster has the rest

-- Hover list of everyone without the addon: two names per line, online first.
function Ov.WithoutTip(tt, without)
	Theme.TipLine(tt, "Don't have Short Royalty yet (" .. #without .. ")")
	local function name(w)
		if not w then return "" end
		return (w.online and (SK.RosterTab.DOT.online .. " ") or "") .. Theme.ClassText(w.name, w.class)
	end
	local shown = math.min(#without, Ov.TIP_NAMES)
	for i = 1, shown, 2 do
		Theme.TipDouble(tt, name(without[i]), i + 1 <= shown and name(without[i + 1]) or "")
	end
	if #without > shown then Theme.TipLine(tt, "and " .. (#without - shown) .. " more: Without addon lists everyone", "dim") end
	Theme.TipLine(tt, "Online first (white dot). Trial accounts show here too: they can't share.", "dim", true)
	Theme.TipLine(tt, "Without addon (top right) opens them in the Roster", "gold")
end

function Ov.GuildRows(o)
	local rows = {
		{ label = "Members", value = n(o.members) },
		{ label = "Players (alts counted once)", value = n(o.players) },
		{ label = "Online now", value = Theme.Paint("dim", n(o.withAddon) .. " with addon   ") .. n(o.online) },
		{ label = "Have Short Royalty", value = n(o.hasAddon), tone = o.hasAddon > 0 and "good" or "dim" },
		{ label = "Don't have it yet", value = n(#o.without), tone = #o.without > 0 and "spark" or "good" },
	}
	if #o.without > 0 then
		local tip = function(tt) Ov.WithoutTip(tt, o.without) end
		rows[#rows].tip = tip
		rows[#rows + 1] = { text = Ov.WithoutText(o.without), indent = true, tip = tip }
	end
	rows[#rows + 1] = { sub = "Levels" }
	for i, b in ipairs(SK.Overview.LEVEL_BANDS) do
		rows[#rows + 1] = { label = b[3], value = n(o.levels[i]), indent = true }
	end
	return rows
end

function Ov.RaidRows(o)
	local rows = {}
	if o.raidDays and o.raidDays > 0 then
		rows[#rows + 1] = { figure = n(o.raidDays), caption = (o.raidDays == 1 and "day" or "days") .. " until raids open, 9 Dec" }
	elseif o.raidDays then
		rows[#rows + 1] = { text = "Raids are open.", tone = "good" }
	end
	for _, r in ipairs(o.raids) do
		local name = string.format("%s (%s)", r.name, n(r.size))
		if r.status == "none" then
			rows[#rows + 1] = { label = name, labelTone = "text", value = "no attunement needed", tone = "dim" }
			rows[#rows + 1] = { label = "Level " .. n(o.maxLevel) .. " and ready", value = n(r.eligible), indent = true }
		else
			rows[#rows + 1] = { label = name, labelTone = "text", value = n(r.yes) .. " attuned", tone = r.yes > 0 and "good" or "dim" }
			rows[#rows + 1] = { label = "Not attuned", value = n(r.no), indent = true, tone = r.no > 0 and "bad" or "dim" }
			rows[#rows + 1] = { label = "Unknown", value = n(r.unknown), indent = true, tone = "dim" }
			if r.noItem > 0 then
				rows[#rows + 1] = { text = string.format("%d without the amulet in their bags", r.noItem), tone = "spark", indent = true }
			end
		end
	end
	return rows
end

function Ov.HealthRows(o)
	local rows = {}
	local function item(count, one, many, tone)
		if count > 0 then rows[#rows + 1] = { label = count == 1 and one or many, value = n(count), tone = tone or "spark" } end
	end
	item(o.addonNoData, "Has the addon, no data here yet", "Have the addon, no data here yet")
	item(o.stale, "Profile older than a week", "Profiles older than a week")
	item(o.unscanned, "Profession window never opened", "Profession windows never opened")
	item(o.outdated, "Running an old Short Royalty", "Running an old Short Royalty")
	if o.selfOutdated then
		rows[#rows + 1] = { text = string.format("Short Royalty %s is out (you have %s).", tostring(o.newest), SK.VERSION),
			tone = "spark" }
	end
	if #rows == 0 then
		rows[1] = { text = "All good: everyone's data is current.", tone = "good" }
	else
		rows[#rows + 1] = { text = "Trial accounts can't share, so they count as not having the addon." }
	end
	return rows
end

function Ov.ProfessionRows(o)
	local rows = {}
	for _, id in ipairs(SK.Overview.CRAFTS) do
		local s = o.profs[id] or { count = 0, maxed = 0, best = 0 }
		local name = SK.Data.PROFESSIONS[id].key
		if s.count == 0 then
			rows[#rows + 1] = { label = name, labelTone = "text", value = "nobody", tone = "bad" }
		else
			local note = s.maxed > 0 and (s.maxed .. " at 300") or ("best " .. s.best)
			rows[#rows + 1] = { label = name, labelTone = "text", value = Theme.Paint("dim", note .. "   ") .. s.count }
		end
	end
	local g = {}
	for _, id in ipairs(SK.Overview.GATHERING) do
		g[#g + 1] = SK.Data.PROFESSIONS[id].short .. " " .. (o.profs[id] and o.profs[id].count or 0)
	end
	rows[#rows + 1] = { text = "Gathering: " .. table.concat(g, "  ·  ") }
	return rows
end

function Ov.RecipeRows(o)
	local r = o.recipes
	if r.total == 0 then
		return { { text = "Recipes appear after crafters open their profession window once." } }
	end
	local rows = {
		{ label = "Recipes known in the guild", value = n(r.total) },
		{ label = "Crafters who shared them", value = n(r.crafters) },
		{ label = "Known by only one character", value = n(r.single), tone = r.single > 0 and "spark" or "good" },
	}
	for _, name in ipairs(r.singleExamples) do rows[#rows + 1] = { text = name, indent = true } end
	return rows
end

-- Plain text of a section (tests, Copy).
local function text(rows) return W.SheetText({ { rows = rows } }) end
function Ov.GuildText(o) return text(Ov.GuildRows(o)) end
function Ov.RaidText(o) return text(Ov.RaidRows(o)) end
function Ov.HealthText(o) return text(Ov.HealthRows(o)) end
function Ov.ProfessionText(o) return text(Ov.ProfessionRows(o)) end
function Ov.RecipeText(o) return text(Ov.RecipeRows(o)) end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function setFeedCell(fs, e, col)
	if col.key == "when" then
		fs:SetText(Theme.Paint("dim", Theme.Ago(e.at)))
	elseif col.key == "what" then
		local first = (e.name or "?"):match("^(%S+)") or e.name
		fs:SetText(Theme.ClassText(first, e.class) .. " " .. e.text)
	else
		fs:SetText("")
	end
end

local function column(i)
	return (i - 1) * (Ov.COL_W + SP.xl)
end

function Ov:Build(page)
	-- One line that answers "what's going on?" before anything else.
	self.header = Theme.Text(page, "body", "dim")
	self.header:SetPoint("TOPLEFT", 0, -2)
	self.header:SetPoint("RIGHT", 0, 0)
	self.header:SetWordWrap(false)

	local function block(col, title, action)
		local b = W.Block(page, Ov.COL_W, title, action)
		b:SetPoint("TOPLEFT", column(col), -Ov.TOP)
		return b
	end
	local function below(b, above)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -SP.xl)
	end

	self.guild = block(1, "Guild", { text = "Without addon", onClick = function() SK.RosterTab:ShowWithoutAddon() end,
		tooltip = "Roster with everyone who doesn't have Short Royalty first" })
	self.health = block(1, "Data health", { text = "Oldest first", onClick = function() SK.RosterTab:ShowOldestFirst() end,
		tooltip = "Roster sorted so missing and oldest data come first" })
	below(self.health, self.guild)

	self.raids = block(2, "Raids", { text = "Onyxia list", tooltip = "Roster with Onyxia's Lair attunement", onClick = function()
		SK.DB.settings.roster.raid = "ony"
		SK.DB.settings.roster.attFilter = "all"
		SK.MainFrame:Select("roster")
	end })
	self.profs = block(2, "Professions", { text = "Find a crafter", onClick = function() SK.MainFrame:Select("crafters") end,
		tooltip = "Find who can make an item" })
	below(self.profs, self.raids)

	-- Recent milestones: a list with a Grats button per row.
	local feed = block(3, "Recent milestones")
	feed:SetRows({})
	feed:SetHeight(Ov.FEED_H)
	self.feed = feed
	local gratsW = 52
	feed.list = W.List(feed, {
		header = false,
		columns = { { key = "when", title = "", width = 36 }, { key = "what", title = "", width = Ov.COL_W - 36 - gratsW - SP.m },
			{ key = "btn", title = "", width = gratsW } },
		setCell = setFeedCell,
		decorate = function(row)
			row.grats = W.Button(row, "Grats", gratsW - SP.xs, S.controlSmall, function(b)
				if b.entry then Compat.OpenChat("/g " .. SK.Feed.GratsText(b.entry)) end
			end)
			row.grats:SetPoint("RIGHT", -SP.xxs, 0)
			row.widgets[#row.widgets + 1] = row.grats
			row.grats.tooltip = "Types a congratulation into guild chat. Press Enter to send it."
		end,
		update = function(row, e)
			row.grats.entry = e
			row.grats:SetShown(e.grats ~= nil and not SK.DB.account[e.guid])
		end,
		onEnter = function(row, e)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:AddLine(Theme.ClassText(e.name, e.class) .. " " .. e.text, Theme.RGB("text"))
			GameTooltip:AddLine(Theme.Ago(e.at) .. " ago (seen by your addon)", Theme.RGB("dim"))
			GameTooltip:AddLine("Click to view character", Theme.RGB("gold"))
			GameTooltip:Show()
		end,
		onClick = function(e) SK.CharacterTab:ShowCharacter(e.guid) end,
	})
	feed.list:SetPoint("TOPLEFT", 0, -feed.headH)
	feed.list:SetPoint("BOTTOMRIGHT")
	feed.list:SetEmptyText("Level-ups, profession milestones, attunements and new recipes show here as your addon sees them.")
	feed.empty = feed.list.message

	-- Getting started (v0.3.1): takes the milestones' place until it's done
	-- or hidden (a new player has no milestones yet anyway).
	self.start = block(3, "Getting started", { text = "Hide", onClick = function() SK.Onboarding.Hide() end,
		tooltip = "Hide this list (it also goes away by itself once everything's done)" })

	self.recipes = block(3, "Recipes", { text = "Search recipes", onClick = function()
		SK.DB.settings.profView = "recipes"
		SK.MainFrame:Select("professions")
	end, tooltip = "Search every recipe in the game (Professions tab)" })
	below(self.recipes, feed)

	SK:On("ONBOARDING_CHANGED", function()
		if page:IsShown() then Ov:Refresh() end
	end)
	SK:On("FEED_UPDATED", function()
		if page:IsShown() then SK:Debounce("overviewfeed", 0.5, function() Ov:Refresh() end) end
	end)
end

function Ov:Refresh()
	if not self.guild then return end
	local guild = SK.DBM:Guild()
	local o = SK.Overview.Build(guild, Compat.Now())
	self.data = o
	local parts = { Theme.Paint("text", SK.guildName or "No guild"), Theme.Count(o.members, "member"), o.online .. " online" }
	if not guild then parts[#parts + 1] = "join a guild to see guildmates here" end
	self.header:SetText(table.concat(parts, "  ·  "))
	self.guild:SetRows(Ov.GuildRows(o))
	self.health:SetRows(Ov.HealthRows(o))
	self.raids:SetRows(Ov.RaidRows(o))
	self.profs:SetRows(Ov.ProfessionRows(o))
	self.recipes:SetRows(Ov.RecipeRows(o))
	local entries = SK.Feed.Entries(guild, SK.Feed.MAX)
	self.feed.list:SetItems(entries)

	local steps, allDone = SK.Onboarding.Steps(SK.Profile:Own(), SK.DB.settings.seen, SK.DB.settings.main,
		o.hasAddon, o.members)
	local showStart = SK.Onboarding.Visible(allDone)
	self.start:SetShown(showStart)
	self.feed:SetShown(not showStart)
	if showStart then self.start:SetRows(Ov.StartRows(steps)) end
	self.recipes:ClearAllPoints()
	self.recipes:SetPoint("TOPLEFT", showStart and self.start or self.feed, "BOTTOMLEFT", 0, -SP.xl)
end

-- Getting started rows (pure; tested).
function Ov.StartRows(steps)
	local rows = {}
	for _, s in ipairs(steps) do
		rows[#rows + 1] = { label = s.text, labelTone = s.done and "dim" or "text",
			value = s.done and "done" or (s.optional and "optional" or "to do"),
			tone = s.done and "good" or (s.optional and "dim" or "spark") }
		if s.detail and not s.done then rows[#rows + 1] = { text = s.detail, tone = "dim", indent = true } end
	end
	return rows
end

SK.MainFrame:AddTab("overview", "Overview", Ov)
