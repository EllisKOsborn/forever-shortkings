-- Overview tab: the guild at a glance, with a button on each card that
-- jumps to the tab where you can act on it. Everything comes from data the
-- addon already has (see Core/Overview.lua and Core/Feed.lua).
local _, SK = ...

local Ov = SK:NewModule("OverviewTab")
local Theme, W, Compat = SK.Theme, SK.Widgets, SK.Compat

Ov.CARD_W, Ov.CARD_H, Ov.GAP, Ov.TOP = 270, 209, 13, 24

local function card(parent, col, row, title)
	local c = CreateFrame("Frame", nil, parent)
	c:SetSize(Ov.CARD_W, Ov.CARD_H)
	c:SetPoint("TOPLEFT", (col - 1) * (Ov.CARD_W + Ov.GAP), -Ov.TOP - (row - 1) * (Ov.CARD_H + 10))
	Theme.Panel(c, { thickness = 1, gold = false, from = "plumDark", to = "plumLift" })
	c.title = Theme.Text(c, 14, "pink")
	c.title:SetPoint("TOPLEFT", 10, -8)
	c.title:SetText(title)
	c.body = W.TextPanel(c)
	c.body:SetPoint("TOPLEFT", 10, -30)
	c.body:SetPoint("BOTTOMRIGHT", -14, 36)
	return c
end

local function footer(c, text, onClick, tooltip)
	local b = W.Button(c, text, 120, 22, onClick)
	b:SetPoint("BOTTOMLEFT", 8, 8)
	b.tooltip = tooltip
	c.button = b
	return b
end

local function n(v) return tostring(v or 0) end

---------------------------------------------------------------------------
-- Card texts (pure; tested)
---------------------------------------------------------------------------
local C = function(name) return Theme.Code(name) end

function Ov.GuildText(o)
	local L = {
		string.format("%s members  %s(about %s players)|r", n(o.members), C("muted"), n(o.players)),
		string.format("%s online  ·  %s%s with Short Kings|r", n(o.online), C("good"), n(o.withAddon)),
		string.format("%s have shared their data", n(o.withData)),
		"",
		C("pink") .. "Levels|r",
	}
	for i, b in ipairs(SK.Overview.LEVEL_BANDS) do
		L[#L + 1] = string.format("  %-6s %s%s|r", b[3], C("flame"), n(o.levels[i]))
	end
	return table.concat(L, "\n")
end

function Ov.RaidText(o)
	local L = {}
	if o.raidDays and o.raidDays > 0 then
		L[#L + 1] = string.format("%sOpen 9 Dec: in about %d day%s|r", C("flame"), o.raidDays, o.raidDays == 1 and "" or "s")
	elseif o.raidDays then
		L[#L + 1] = C("good") .. "Open now|r"
	end
	L[#L + 1] = ""
	for _, r in ipairs(o.raids) do
		L[#L + 1] = string.format("%s%s|r (%s)", C("pink"), r.name, n(r.size))
		if r.status == "none" then
			L[#L + 1] = string.format("  no attunement needed  ·  %s at level %s", n(r.eligible), n(o.maxLevel))
		else
			L[#L + 1] = string.format("  %s%s attuned|r · %s%s not|r · %s%s unknown|r", C("good"), n(r.yes),
				C("bad"), n(r.no), C("muted"), n(r.unknown))
			if r.noItem > 0 then
				L[#L + 1] = string.format("  %s%d without the amulet in their bags|r", C("ember"), r.noItem)
			end
		end
	end
	return table.concat(L, "\n")
end

function Ov.HealthText(o)
	local L = {}
	local function item(count, text, color)
		if count > 0 then L[#L + 1] = string.format("%s%d|r %s", C(color or "ember"), count, text) end
	end
	item(o.noData, o.noData == 1 and "member without Short Kings data" or "members without Short Kings data", "muted")
	item(o.stale, o.stale == 1 and "profile older than a week" or "profiles older than a week")
	item(o.unscanned, o.unscanned == 1 and "character hasn't opened a profession window"
		or "characters haven't opened a profession window")
	item(o.outdated, "running an old Short Kings")
	if o.selfOutdated then
		L[#L + 1] = string.format("%sShort Kings %s is out (you have %s)|r", C("flame"), tostring(o.newest), SK.VERSION)
	end
	if #L == 0 then
		L[1] = C("good") .. "All good: everyone's data is current.|r"
	else
		L[#L + 1] = ""
		L[#L + 1] = C("muted") .. "No data usually means no addon, or a trial account (trials can't share).|r"
	end
	return table.concat(L, "\n")
end

function Ov.ProfessionText(o)
	local L = {}
	for _, id in ipairs(SK.Overview.CRAFTS) do
		local s = o.profs[id]
		local name = SK.Data.PROFESSIONS[id].key
		if s.count == 0 then
			L[#L + 1] = string.format("%s  %snobody|r", name, C("bad"))
		else
			L[#L + 1] = string.format("%s  %s%d|r%s", name, C("flame"), s.count,
				s.maxed > 0 and (C("muted") .. "  (" .. s.maxed .. " at 300)|r") or (C("muted") .. "  (best " .. s.best .. ")|r"))
		end
	end
	local g = {}
	for _, id in ipairs(SK.Overview.GATHERING) do
		g[#g + 1] = SK.Data.PROFESSIONS[id].short .. " " .. o.profs[id].count
	end
	L[#L + 1] = C("muted") .. "Gathering: " .. table.concat(g, " · ") .. "|r"
	return table.concat(L, "\n")
end

function Ov.RecipeText(o)
	local r = o.recipes
	if r.total == 0 then
		return C("muted") .. "Recipes appear after crafters open their profession window once.|r"
	end
	local L = {
		string.format("%s%d|r recipes known in the guild", C("flame"), r.total),
		string.format("from %d crafter%s", r.crafters, r.crafters == 1 and "" or "s"),
		"",
		string.format("%s%d|r only one character knows", C(r.single > 0 and "ember" or "good"), r.single),
	}
	for _, name in ipairs(r.singleExamples) do L[#L + 1] = "  " .. C("muted") .. name .. "|r" end
	return table.concat(L, "\n")
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function setFeedCell(fs, e, col)
	if col.key == "when" then
		fs:SetText(Theme.Code("muted") .. Theme.Ago(e.at) .. "|r")
	elseif col.key == "what" then
		local first = (e.name or "?"):match("^(%S+)") or e.name
		fs:SetText(Theme.ClassText(first, e.class) .. " " .. e.text)
	else
		fs:SetText("")
	end
end

function Ov:Build(page)
	self.header = Theme.Text(page, 12, "muted")
	self.header:SetPoint("TOPLEFT", 2, -4)

	self.guild = card(page, 1, 1, "Guild")
	footer(self.guild, "Roster", function()
		SK.DB.settings.roster.raid = nil
		SK.MainFrame:Select("roster")
	end, "Open the full roster")

	self.raids = card(page, 2, 1, "Raids")
	footer(self.raids, "Onyxia list", function()
		SK.DB.settings.roster.raid = "ony"
		SK.DB.settings.roster.attFilter = "all"
		SK.MainFrame:Select("roster")
	end, "Roster with Onyxia's Lair attunement")

	self.health = card(page, 3, 1, "Data health")
	footer(self.health, "Oldest first", function() SK.RosterTab:ShowOldestFirst() end,
		"Roster sorted so missing and oldest data come first")

	self.profs = card(page, 1, 2, "Professions")
	footer(self.profs, "Crafters", function() SK.MainFrame:Select("crafters") end, "Find who can make an item")

	self.recipes = card(page, 2, 2, "Recipes")
	footer(self.recipes, "Search recipes", function() SK.MainFrame:Select("crafters") end, "Open the Crafters tab")

	-- Recent milestones: a small list with a Grats button per row.
	local feed = card(page, 3, 2, "Recent milestones")
	feed.body:Hide()
	self.feed = feed
	feed.list = W.List(feed, {
		columns = { { key = "when", title = "", width = 32 }, { key = "what", title = "", width = 166 },
			{ key = "btn", title = "", width = 52 } },
		rowHeight = 20, setCell = setFeedCell,
		decorate = function(row)
			row.grats = W.Button(row, "Grats", 46, 16, function(b)
				if b.entry then Compat.OpenChat("/g " .. SK.Feed.GratsText(b.entry)) end
			end)
			row.grats:SetPoint("RIGHT", -2, 0)
			row.grats.tooltip = "Types a congratulation into guild chat. Press Enter to send it."
		end,
		update = function(row, e)
			row.grats.entry = e
			row.grats:SetShown(e.grats ~= nil and not SK.DB.account[e.guid])
		end,
		onEnter = function(row, e)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:AddLine(Theme.ClassText(e.name, e.class) .. " " .. e.text, 1, 1, 1, true)
			GameTooltip:AddLine(Theme.Ago(e.at) .. " ago (seen by your addon)", 0.72, 0.6, 0.67)
			GameTooltip:AddLine("Click to view character", 1, 0.76, 0.29)
			GameTooltip:Show()
		end,
		onClick = function(e) SK.CharacterTab:ShowCharacter(e.guid) end,
	})
	feed.list:SetPoint("TOPLEFT", 4, -26)
	feed.list:SetPoint("BOTTOMRIGHT", -4, 6)
	feed.empty = Theme.Text(feed, 12, "muted")
	feed.empty:SetPoint("TOPLEFT", 10, -56)
	feed.empty:SetWidth(Ov.CARD_W - 20)
	feed.empty:SetJustifyH("LEFT")
	feed.empty:SetText("Level-ups, profession milestones, attunements and new recipes show here as your addon sees them.")

	SK:On("FEED_UPDATED", function()
		if page:IsShown() then SK:Debounce("overviewfeed", 0.5, function() Ov:Refresh() end) end
	end)
end

function Ov:Refresh()
	if not self.guild then return end
	local guild = SK.DBM:Guild()
	local o = SK.Overview.Build(guild, Compat.Now())
	self.data = o
	self.header:SetText(string.format("%s  ·  %d members  ·  %d online", SK.guildName or "No guild", o.members, o.online)
		.. (o.raidDays and o.raidDays > 0 and string.format("  ·  raids open in about %d days", o.raidDays) or ""))
	self.guild.body:SetText(Ov.GuildText(o))
	self.raids.body:SetText(Ov.RaidText(o))
	self.health.body:SetText(Ov.HealthText(o))
	self.profs.body:SetText(Ov.ProfessionText(o))
	self.recipes.body:SetText(Ov.RecipeText(o))
	local entries = SK.Feed.Entries(guild, SK.Feed.MAX)
	self.feed.list:SetItems(entries)
	self.feed.empty:SetShown(#entries == 0)
end

SK.MainFrame:AddTab("overview", "Overview", Ov)
