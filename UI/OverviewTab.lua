-- Overview tab: the guild at a glance, with a button on each card that
-- jumps to the tab where you can act on it. Everything comes from data the
-- addon already has (see Core/Overview.lua and Core/Feed.lua).
local _, SK = ...

local Ov = SK:NewModule("OverviewTab")
local Theme, W, Compat = SK.Theme, SK.Widgets, SK.Compat

Ov.CARD_W, Ov.CARD_H, Ov.GAP = 264, 206, 16
Ov.LINES_TOP, Ov.LINES_TOP_PLAIN = 94, 42 -- detail lines under a big number / under the title

-- A card at grid position (col, row) with a label/value block.
local function card(parent, col, row, title, plain)
	local c = W.Card(parent, Ov.CARD_W, Ov.CARD_H, title)
	c:SetPoint("TOPLEFT", (col - 1) * (Ov.CARD_W + Ov.GAP), -(row - 1) * (Ov.CARD_H + Ov.GAP))
	c.lines = W.Lines(c, "label", 20)
	c.lines:SetPoint("TOPLEFT", 16, -(plain and Ov.LINES_TOP_PLAIN or Ov.LINES_TOP))
	c.lines:SetPoint("RIGHT", -16, 0)
	c.lines:SetHeight(80)
	-- One short warning next to the button (bottom right).
	c.note = Theme.Text(c, "small", "warning")
	c.note:SetPoint("RIGHT", c, "BOTTOMRIGHT", -16, 30) -- centred on the button
	c.note:SetJustifyH("RIGHT")
	return c
end

local function n(v) return tostring(v or 0) end
local C = function(name) return Theme.Code(name) end
local function v(x, color) return C(color or "text") .. n(x) .. "|r" end

-- Lines as one string ("left  right" per line), for tests and Copy.
function Ov.Join(lines, note)
	local out = {}
	for _, l in ipairs(lines) do
		out[#out + 1] = type(l) == "table" and ((l[1] or "") .. "  " .. (l[2] or "")) or l
	end
	if note and note ~= "" then out[#out + 1] = note end
	return table.concat(out, "\n")
end

local BAND_LABEL = { ["60"] = "Level 60", ["50-59"] = "50s", ["40-49"] = "40s", ["1-39"] = "<40" }

-- 1284 -> "1,284"
function Ov.Thousands(x)
	local s = tostring(math.floor(x or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local MARK = {
	yes = "|A:UI-LFG-ReadyMark:12:12|a", no = "|A:UI-LFG-DeclineMark:12:12|a", unknown = "|A:UI-LFG-PendingMark:12:12|a",
}

---------------------------------------------------------------------------
-- Card contents (pure; tested). Each returns big, caption, lines[, note].
---------------------------------------------------------------------------
function Ov.Guild(o)
	local bands = {}
	for i, b in ipairs(SK.Overview.LEVEL_BANDS) do
		bands[#bands + 1] = (BAND_LABEL[b[3]] or b[3]) .. " " .. v(o.levels[i])
	end
	return n(o.members), string.format("members, about %s players", n(o.players)), {
		{ Theme.StatusMark("addon") .. " " .. v(o.online) .. " online", v(o.withAddon) .. " with Short Kings" },
		{ "Have shared their data", v(o.withData) },
		table.concat(bands, "   "),
	}
end

function Ov.Raids(o)
	local big, caption
	if o.raidDays and o.raidDays > 0 then
		big = string.format("%d day%s", o.raidDays, o.raidDays == 1 and "" or "s")
		caption = "until raids open on 9 Dec"
	elseif o.raidDays then
		big, caption = "Open", "raids are open"
	else
		big, caption = "", ""
	end
	local lines, note, eligible = {}, nil, nil
	for _, r in ipairs(o.raids) do
		local name = string.format("%s (%s)", r.name, n(r.size))
		if r.status == "none" then
			lines[#lines + 1] = { name, "no attunement" }
			eligible = r.eligible
		else
			lines[#lines + 1] = { name, string.format("%s %s  %s %s  %s %s", MARK.yes, v(r.yes), MARK.no, v(r.no),
				MARK.unknown, v(r.unknown)) }
			if r.noItem > 0 then note = string.format("%d without the amulet", r.noItem) end
		end
	end
	if eligible then caption = caption .. string.format("  ·  %s at level %s", n(eligible), n(o.maxLevel)) end
	return big, caption, lines, note
end

function Ov.Health(o)
	local big, caption, color
	if o.noData > 0 then
		big, caption = n(o.noData), o.noData == 1 and "member without Short Kings data" or "members without Short Kings data"
	elseif o.stale + o.unscanned + o.outdated == 0 then
		big, caption, color = "All good", "everyone's data is current", "success"
	else
		big, caption = "0", "members without Short Kings data"
	end
	local lines = {
		{ "Profiles older than a week", v(o.stale, o.stale > 0 and "warning" or "text") },
		{ "Profession window never opened", v(o.unscanned, o.unscanned > 0 and "warning" or "text") },
		{ "Running an old Short Kings", v(o.outdated, o.outdated > 0 and "warning" or "text") },
	}
	local note
	if o.selfOutdated then note = string.format("%s is out (you have %s)", tostring(o.newest), SK.VERSION) end
	return big, caption, lines, note, color
end

function Ov.Professions(o)
	local lines = {}
	for _, id in ipairs(SK.Overview.CRAFTS) do
		local s = o.profs[id]
		local name = SK.Data.PROFESSIONS[id].key
		if s.count == 0 then
			lines[#lines + 1] = { name, C("danger") .. "nobody|r" }
		else
			lines[#lines + 1] = { name, v(s.count) .. C("textMuted") ..
				(s.maxed > 0 and ("  ·  " .. s.maxed .. " at 300") or ("  ·  best " .. s.best)) .. "|r" }
		end
	end
	return lines
end

function Ov.GatheringText(o)
	local g = {}
	for _, id in ipairs(SK.Overview.GATHERING) do
		g[#g + 1] = SK.Data.PROFESSIONS[id].key .. " " .. o.profs[id].count
	end
	return "Gathering: " .. table.concat(g, ", ")
end

function Ov.Recipes(o)
	local r = o.recipes
	if r.total == 0 then
		return "0", "recipes known so far", { "Recipes appear after crafters open", "their profession window once." }
	end
	local lines = {
		{ "Only one character knows", v(r.single, r.single > 0 and "warning" or "success") },
	}
	if #r.singleExamples > 0 then
		lines[#lines + 1] = C("textMuted") .. table.concat(r.singleExamples, "  ·  ", 1, math.min(2, #r.singleExamples)) .. "|r"
	end
	return Ov.Thousands(r.total), string.format("recipes known, from %d crafter%s", r.crafters,
		r.crafters == 1 and "" or "s"), lines
end

-- Old names (v0.2.2) as plain text, kept for tests and anyone calling them.
function Ov.GuildText(o) local _, cap, l = Ov.Guild(o); return Ov.Join(l, cap) end
function Ov.RaidText(o) local _, cap, l, note = Ov.Raids(o); return cap .. "\n" .. Ov.Join(l, note) end
function Ov.HealthText(o) local big, cap, l, note = Ov.Health(o); return big .. " " .. cap .. "\n" .. Ov.Join(l, note) end
function Ov.ProfessionText(o) return Ov.Join(Ov.Professions(o), Ov.GatheringText(o)) end
function Ov.RecipeText(o) local _, cap, l = Ov.Recipes(o); return cap .. "\n" .. Ov.Join(l) end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function setFeedCell(fs, e, col)
	if col.key == "when" then
		fs:SetText(Theme.Code("textMuted") .. Theme.Ago(e.at) .. "|r")
	elseif col.key == "what" then
		local first = (e.name or "?"):match("^(%S+)") or e.name
		fs:SetText(Theme.ClassText(first, e.class) .. " " .. Theme.Code("textDim") .. e.text .. "|r")
	else
		fs:SetText("")
	end
end

function Ov:Build(page, tools)
	self.header = Theme.Text(tools or page, "label", "textDim")
	self.header:SetPoint("LEFT", 0, 0)

	self.guild = card(page, 1, 1, "Guild")
	self.guild:SetButton("Roster", function()
		SK.DB.settings.roster.raid = nil
		SK.MainFrame:Select("roster")
	end, "Open the full roster")

	self.raids = card(page, 2, 1, "Raids")
	self.raids:SetButton("Onyxia list", function()
		SK.DB.settings.roster.raid = "ony"
		SK.DB.settings.roster.attFilter = "all"
		SK.MainFrame:Select("roster")
	end, "Roster with Onyxia's Lair attunement")

	self.health = card(page, 3, 1, "Data health")
	self.health:SetButton("Oldest first", function() SK.RosterTab:ShowOldestFirst() end,
		"Roster sorted so missing and oldest data come first. No data usually means no addon, "
		.. "or a trial account (trials can't share).")

	self.profs = card(page, 1, 2, "Professions", true)
	self.profs.lines.lineH = 15
	self.profs:SetButton("Crafters", function() SK.MainFrame:Select("crafters") end, "Find who can make an item")
	self.profs:EnableMouse(true)
	self.profs:SetScript("OnEnter", function(c)
		if not Ov.data then return end
		GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Professions in the guild")
		GameTooltip:AddLine(Ov.GatheringText(Ov.data), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	self.profs:SetScript("OnLeave", function() GameTooltip:Hide() end)

	self.recipes = card(page, 2, 2, "Recipes")
	self.recipes:SetButton("Search recipes", function() SK.MainFrame:Select("crafters") end, "Open the Crafters tab")

	-- Recent milestones: a small list with a Grats button per row.
	local feed = card(page, 3, 2, "Recent milestones", true)
	feed.lines:Hide()
	self.feed = feed
	feed.list = W.List(feed, {
		columns = { { key = "when", title = "", width = 32 }, { key = "what", title = "", width = 150 },
			{ key = "btn", title = "", width = 50 } },
		rowHeight = 22, setCell = setFeedCell, ground = false, header = false,
		decorate = function(row)
			row.grats = W.Button(row, "Grats", 46, 20, function(b)
				if b.entry then Compat.OpenChat("/g " .. SK.Feed.GratsText(b.entry)) end
			end, { style = "ghost" })
			row.grats:SetPoint("RIGHT", 0, 0)
			row.grats.tooltip = "Types a congratulation into guild chat. Press Enter to send it."
		end,
		update = function(row, e)
			row.grats.entry = e
			row.grats:SetShown(e.grats ~= nil and not SK.DB.account[e.guid])
		end,
		onEnter = function(row, e)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:AddLine(Theme.ClassText(e.name, e.class) .. " " .. e.text, 1, 1, 1, true)
			GameTooltip:AddLine(Theme.Ago(e.at) .. " ago (seen by your addon)", Theme.RGB("textMuted"))
			GameTooltip:AddLine("Click to view character", Theme.RGB("accent"))
			GameTooltip:Show()
		end,
		onClick = function(e) SK.CharacterTab:ShowCharacter(e.guid) end,
	})
	feed.list:SetPoint("TOPLEFT", 8, -40)
	feed.list:SetPoint("BOTTOMRIGHT", -8, 12)
	feed.empty = W.EmptyState(feed, "inbox", Ov.CARD_W - 32)
	feed.empty:SetPoint("TOP", 0, -44)
	feed.empty:Set("No milestones yet",
		"Level-ups, profession milestones, attunements and new recipes show here as your addon sees them.")

	SK:On("FEED_UPDATED", function()
		if page:IsShown() then SK:Debounce("overviewfeed", 0.5, function() Ov:Refresh() end) end
	end)
end

function Ov:Refresh()
	if not self.guild then return end
	local guild = SK.DBM:Guild()
	local o = SK.Overview.Build(guild, Compat.Now())
	self.data = o
	Ov.data = o
	self.header:SetText(string.format("%s  ·  %d members  ·  %d online", SK.guildName or "No guild", o.members, o.online)
		.. (o.raidDays and o.raidDays > 0 and string.format("  ·  raids open in about %d days", o.raidDays) or ""))
	local function fill(c, big, caption, lines, note, color)
		c:SetBig(big, caption, color)
		c.lines:SetLines(lines or {})
		c.note:SetText(note or "")
	end
	fill(self.guild, Ov.Guild(o))
	fill(self.raids, Ov.Raids(o))
	fill(self.health, Ov.Health(o))
	fill(self.profs, nil, nil, Ov.Professions(o))
	fill(self.recipes, Ov.Recipes(o))
	local entries = SK.Feed.Entries(guild, SK.Feed.MAX)
	self.feed.list:SetItems(entries)
	self.feed.list:SetShown(#entries > 0)
	self.feed.empty:SetShown(#entries == 0)
	SK.MainFrame:SetStatus("overview", "Milestones are what your addon has seen; they are never shared")
end

SK.MainFrame:AddTab("overview", "Overview", Ov)
