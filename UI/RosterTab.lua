-- Roster tab: every guild member, sortable, with class colours, level,
-- spec, professions, item level, online status (with addon dots), addon
-- version and data age. Alts can be grouped under their main.
local _, SK = ...

local Roster = SK:NewModule("RosterTab")
local Theme, W = SK.Theme, SK.Widgets
local S, SP = Theme.SIZES, Theme.SPACE

-- "addon" = online with Short Royalty, "online" = online without it, "offline".
-- (Lives in Identity so non-UI code such as Sync and CraftIndex can use it.)
Roster.Status = SK.Identity.Status

local STATUS_RANK = { addon = 3, online = 2, offline = 1 }
-- Round dots: green = online with Short Royalty, white = online without it,
-- dark grey = offline. (Gold and spark stay free for actions and alerts.)
local DOT = {
	addon = Theme.Dot("good"),
	online = Theme.Dot("text"),
	offline = Theme.Dot("faint"),
}
Roster.DOT = DOT

-- Newest addon version anyone in the guild runs (for "needs update").
function Roster.NewestVersion(guild)
	local newest = SK.VERSION ~= "dev" and SK.VERSION or nil
	for _, m in pairs(guild.members) do
		if m.addon and (not newest or SK.Sync.versionNewer(m.addon, newest)) then newest = m.addon end
	end
	return newest
end

local function professionsOf(p)
	local profs, text = {}, {}
	if p and p.profs then
		for skillLine, pr in pairs(p.profs) do
			profs[#profs + 1] = { name = pr.name or SK.Data.ProfessionShort(skillLine), rank = pr.rank or 0,
				short = SK.Data.ProfessionShort(skillLine, pr.name), primary = pr.primary and true or false }
		end
		table.sort(profs, function(a, b)
			if a.primary ~= b.primary then return a.primary end
			return a.name < b.name
		end)
		for _, pr in ipairs(profs) do
			if pr.primary then text[#text + 1] = pr.short .. " " .. pr.rank end
		end
	end
	return profs, table.concat(text, ", ")
end

local function makeRow(guild, guid, m, now, newest)
	local p = SK.Profile:Get(guid, guild)
	local isSelf = SK.DB.account[guid] or false
	local profs, profText = professionsOf(p)
	local spec, mainTree = SK.Talents.Summary(p and p.talents)
	local version = isSelf and SK.VERSION or m.addon
	return {
		guid = guid, name = m.name or (p and p.name) or "?", class = m.class or (p and p.class),
		level = m.level or (p and p.level) or 0, rank = m.rank or "", rankIndex = m.rankIndex or 99,
		online = m.online, lastSeen = m.lastSeen, hasData = p ~= nil, updated = p and p.updated,
		ilvl = p and p.ilvl, spec = spec, mainTree = mainTree, profText = profText, profs = profs,
		status = Roster.Status(m, isSelf, now), addon = version, isSelf = isSelf,
		hasAddon = SK.Identity.HasAddon(guid, m, p),
		outdated = (version and newest and version ~= "dev" and SK.Sync.versionNewer(newest, version))
			or (not version and m.oldAddon ~= nil) or false,
		oldAddon = not version and m.oldAddon ~= nil or nil,
		note = m.note, officerNote = m.officerNote,
		missingEnchants = p and p.gear and #SK.Data.Enchants.Missing(p.gear, p.class, p.level) or nil,
		hidden = p and p.hidden,
	}
end

local function matches(row, filter)
	local hay = { row.name, row.profText, row.mainTree or "", row.class or "", row.rank, row.note or "" }
	for _, pr in ipairs(row.profs) do hay[#hay + 1] = pr.name end
	for _, alt in ipairs(row.alts or {}) do hay[#hay + 1] = alt.name end
	return table.concat(hay, " "):lower():find(filter, 1, true) ~= nil
end

-- Build display rows from saved members + profiles. Pure; tested.
-- With `group`, alts are folded into their main's row (row.alts).
function Roster.Rows(guild, now, filter, group)
	local rows = {}
	if not guild then return rows end
	filter = filter and filter ~= "" and filter:lower() or nil
	now = now or SK.Compat.Now()
	local newest = Roster.NewestVersion(guild)

	local byGuid = {}
	for guid, m in pairs(guild.members) do
		if not m.leftAt then byGuid[guid] = makeRow(guild, guid, m, now, newest) end
	end

	if group then
		local profiles = {}
		for guid in pairs(byGuid) do
			local p = guild.profiles[guid]
			if p then profiles[guid] = p end
		end
		local groupOf = SK.Alts.Groups(profiles, function(g) return byGuid[g] ~= nil end)
		for guid, row in pairs(byGuid) do
			local g = groupOf[guid]
			if g and #g.members > 1 then
				if g.main == guid then
					row.alts = {}
					for _, other in ipairs(g.members) do
						if other ~= guid then
							local alt = byGuid[other]
							row.alts[#row.alts + 1] = alt
							if STATUS_RANK[alt.status] > STATUS_RANK[row.status] then
								row.status, row.onAlt = alt.status, alt.name
							end
							if alt.online then row.online = true end
						end
					end
				else
					row.hiddenAlt = true
				end
			end
		end
	end

	for _, row in pairs(byGuid) do
		if not row.hiddenAlt and (not filter or matches(row, filter)) then rows[#rows + 1] = row end
	end
	return rows
end

---------------------------------------------------------------------------
-- Raid attunement view (v0.1.2)
---------------------------------------------------------------------------
function Roster.Raid(key)
	for _, a in ipairs(SK.Data.ATTUNEMENTS) do
		if a.key == key then return a end
	end
end

-- Attunement state for one profile and raid (logic in Collect/Attunements).
Roster.AttunementOf = SK.Attunements.StateOf

-- Highest level of any current member (the guild's "max level").
function Roster.MaxLevel(guild)
	local max = 0
	for _, m in pairs(guild and guild.members or {}) do
		if not m.leftAt and (m.level or 0) > max then max = m.level end
	end
	return max
end

-- One row per character (alts are never folded in here, because attunement
-- belongs to a character). Pure; tested.
--   filter: "all" | "yes" | "no" | "unknown"
-- Returns rows, counts { yes, no, unknown } (before `filter`, after search
-- and the max-level rule), maxLevel.
function Roster.AttunementRows(guild, raidKey, filter, maxLevelOnly, search, now)
	local counts = { yes = 0, no = 0, unknown = 0, none = 0 }
	local out = {}
	local raid = Roster.Raid(raidKey)
	if not guild or not raid then return out, counts, 0 end
	now = now or SK.Compat.Now()
	filter = filter or "all"
	local maxLevel = Roster.MaxLevel(guild)

	-- "alt of X" for the tooltip.
	local profiles = {}
	for guid, m in pairs(guild.members) do
		if not m.leftAt and guild.profiles[guid] then profiles[guid] = guild.profiles[guid] end
	end
	local groupOf = SK.Alts.Groups(profiles, function(g) return profiles[g] ~= nil end)

	for _, row in ipairs(Roster.Rows(guild, now, search, false)) do
		if not maxLevelOnly or row.level >= maxLevel then
			row.att, row.attNote = Roster.AttunementOf(SK.Profile:Get(row.guid, guild), raid)
			local g = groupOf[row.guid]
			if g and #g.members > 1 and g.main ~= row.guid then
				local mm = guild.members[g.main]
				row.altOf = (mm and mm.name) or (profiles[g.main] and profiles[g.main].name)
			end
			counts[row.att] = counts[row.att] + 1
			if filter == "all" or filter == row.att then out[#out + 1] = row end
		end
	end
	return out, counts, maxLevel
end

local function byName(a, b) return a.name:lower() < b.name:lower() end
local function byNum(key) return function(a, b)
	local x, y = a[key] or -1, b[key] or -1
	if x == y then return byName(a, b) end
	return x < y
end end

-- Version column: members without the addon first, then newest version first.
function Roster.ByVersion(a, b)
	if a.hasAddon ~= b.hasAddon then return not a.hasAddon end
	local x, y = a.addon or "", b.addon or ""
	if x ~= y then
		if x == "" or y == "" then return y == "" end
		return SK.Sync.versionNewer(x, y) or (not SK.Sync.versionNewer(y, x) and x > y)
	end
	return byName(a, b)
end

-- Widths add up to the content width minus the scroll bar (836). The name
-- gets the most room; numbers are right-aligned.
local COLUMNS = {
	{ key = "name", title = "Name", width = 196, sort = byName },
	{ key = "level", title = "Level", width = 46, align = "RIGHT", sort = byNum("level") },
	{ key = "rank", title = "Rank", width = 96, sort = byNum("rankIndex") },
	{ key = "spec", title = "Spec", width = 128, sort = function(a, b) return (a.mainTree or "~") < (b.mainTree or "~") end },
	{ key = "profs", title = "Professions", width = 140, sort = function(a, b) return a.profText < b.profText end },
	{ key = "ilvl", title = "iLvl", width = 46, align = "RIGHT", sort = byNum("ilvl") },
	{ key = "seen", title = "Online", width = 82, sort = function(a, b)
		if a.status ~= b.status then return STATUS_RANK[a.status] > STATUS_RANK[b.status] end
		return (a.lastSeen or 0) > (b.lastSeen or 0)
	end },
	{ key = "addon", title = "Version", width = 52, align = "RIGHT", sort = Roster.ByVersion },
	{ key = "data", title = "Data", width = 50, align = "RIGHT", sort = byNum("updated") },
}

local ATT_RANK = { yes = 3, no = 2, unknown = 1, none = 0 }

-- While a raid is selected: Professions and Ver make room for Attuned.
local ATT_COLUMNS = {
	COLUMNS[1], COLUMNS[2], COLUMNS[3], COLUMNS[4],
	{ key = "att", title = "Attuned", width = 140, sort = function(a, b)
		if a.att ~= b.att then return ATT_RANK[a.att] > ATT_RANK[b.att] end
		return byName(a, b)
	end },
	COLUMNS[6], COLUMNS[7],
	{ key = "data", title = "Data", width = 102, align = "RIGHT", sort = byNum("updated") },
}

-- The game font has no check-mark glyphs, so the marks are the ready-check
-- atlases from Blizzard's Forever ReadyCheck.lua (READY_CHECK_*_TEXTURE).
local ATT_TEXT = {
	yes = "|A:UI-LFG-ReadyMark:12:12|a " .. Theme.Paint("good", "yes"),
	no = "|A:UI-LFG-DeclineMark:12:12|a " .. Theme.Paint("bad", "no"),
	unknown = "|A:UI-LFG-PendingMark:12:12|a " .. Theme.Paint("dim", "unknown"),
	none = Theme.Paint("dim", "not needed"),
}
Roster.ATT_TEXT = ATT_TEXT

local function setCell(fs, r, col)
	local k = col.key
	local now = SK.Compat.Now()
	local C = Theme.Code
	if k == "name" then
		local extra = ""
		if r.isSelf then extra = " " .. C("beard") .. "(you)|r" end
		if r.alts and #r.alts > 0 then extra = extra .. " " .. C("dim") .. "+" .. #r.alts .. "|r" end
		fs:SetText(Theme.ClassText(r.name, r.class) .. extra)
	elseif k == "level" then
		fs:SetText(r.level > 0 and r.level or Theme.DASH)
	elseif k == "rank" then
		fs:SetText(C("dim") .. r.rank .. "|r")
	elseif k == "spec" then
		fs:SetText(r.spec and ((r.mainTree or "") .. " " .. C("dim") .. r.spec .. "|r") or Theme.DASH)
	elseif k == "profs" then
		fs:SetText(r.profText ~= "" and (C("dim") .. r.profText .. "|r") or Theme.DASH)
	elseif k == "ilvl" then
		fs:SetText(r.ilvl and string.format("%.0f", r.ilvl) or Theme.DASH)
	elseif k == "seen" then
		local dot = DOT[r.status] .. " "
		if r.status == "offline" then
			fs:SetText(dot .. C("dim") .. Theme.Ago(r.lastSeen, now) .. "|r")
		elseif r.onAlt then
			fs:SetText(dot .. "on alt")
		else
			fs:SetText(dot .. "online")
		end
	elseif k == "addon" then
		if not r.addon and r.oldAddon then fs:SetText(C("spark") .. "old|r")
		elseif not r.addon then fs:SetText(r.hasAddon and C("dim") .. "?|r" or Theme.DASH)
		elseif r.outdated then fs:SetText(C("spark") .. r.addon .. "|r")
		else fs:SetText(C("dim") .. r.addon .. "|r") end
	elseif k == "att" then
		fs:SetText(ATT_TEXT[r.att or "unknown"] .. (r.attNote and (" " .. C("spark") .. "!|r") or ""))
	elseif k == "data" then
		if r.hasData and not r.isSelf and Theme.IsStale(r.updated, now) then
			fs:SetText(C("spark") .. Theme.Ago(r.updated, now) .. "|r")
		elseif r.hasData then fs:SetText(C("dim") .. Theme.Ago(r.updated, now) .. "|r")
		else fs:SetText(C("faint") .. "none|r") end
	end
end

local STATUS_TEXT = {
	addon = "Online with Short Royalty",
	online = "Online without Short Royalty (or not heard from yet)",
	offline = "Offline",
}

local function tooltip(row, r)
	local now = SK.Compat.Now()
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Theme.ClassText(r.name, r.class))
	if r.altOf then Theme.TipLine(GameTooltip, "alt of " .. r.altOf, "dim") end
	if r.att then
		local raid = Roster.Raid(SK.DB.settings.roster.raid)
		Theme.TipDouble(GameTooltip, (raid and raid.name or "Raid") .. " attunement", ATT_TEXT[r.att], "gold")
		if r.attNote then Theme.TipLine(GameTooltip, r.attNote, "spark") end
	end
	Theme.TipLine(GameTooltip, DOT[r.status] .. " " .. STATUS_TEXT[r.status], "text")
	if r.spec then Theme.TipLine(GameTooltip, (r.mainTree or "Talents") .. " " .. r.spec, "text") end
	for _, pr in ipairs(r.profs) do Theme.TipDouble(GameTooltip, pr.name, pr.rank, "text", "text") end
	if r.missingEnchants and r.missingEnchants > 0 then
		Theme.TipLine(GameTooltip, r.missingEnchants .. " item(s) missing an enchant", "spark")
	end
	if r.note and r.note ~= "" then Theme.TipLine(GameTooltip, "Note: " .. r.note, "beard", true) end
	if r.officerNote and r.officerNote ~= "" then
		Theme.TipLine(GameTooltip, "Officer note: " .. r.officerNote, "gold", true)
	end
	if r.alts and #r.alts > 0 then
		GameTooltip:AddLine(" ")
		Theme.TipLine(GameTooltip, "Alts", "beard")
		for _, alt in ipairs(r.alts) do
			local right = alt.status == "offline" and Theme.Ago(alt.lastSeen, now) or "online"
			Theme.TipDouble(GameTooltip, DOT[alt.status] .. " " .. Theme.ClassText(alt.name, alt.class) ..
				"  " .. (alt.level > 0 and alt.level or ""), right, "text", "dim")
		end
	end
	GameTooltip:AddLine(" ")
	if r.oldAddon then
		Theme.TipLine(GameTooltip, "Runs an old Short Royalty (v0.3.2 or earlier) that can't share with yours. " ..
			"They need to update.", "spark", true)
	elseif not r.hasData and r.hasAddon then
		Theme.TipLine(GameTooltip, "Has Short Royalty" .. (r.addon and (" " .. r.addon) or "") ..
			", but their data hasn't reached you yet.", "spark", true)
	elseif not r.hasData then
		Theme.TipLine(GameTooltip, "Doesn't have Short Royalty yet (or is on a trial account: trials can't sync).", "dim", true)
	elseif r.addon then
		if not r.isSelf and Theme.IsStale(r.updated, now) then
			Theme.TipLine(GameTooltip, "Data is " .. Theme.Ago(r.updated, now) .. " old and may be out of date", "spark")
		end
		Theme.TipLine(GameTooltip, "Short Royalty " .. r.addon .. (r.outdated and "  (update available)" or ""),
			r.outdated and "spark" or "dim")
	end
	Theme.TipLine(GameTooltip, "Click to view character", "gold")
	GameTooltip:Show()
end

local FILTERS = {
	{ "all", "All" }, { "yes", "Attuned" }, { "no", "Not attuned" }, { "unknown", "Unknown" },
}

local function raidItems()
	local items = { { value = "none", text = "All raids" } }
	for _, a in ipairs(SK.Data.ShownAttunements()) do
		items[#items + 1] = { value = a.key, text = a.name .. (a.size and (" (" .. a.size .. ")") or "") }
	end
	return items
end

function Roster:Build(page)
	local rs = SK.DB.settings.roster
	self.filter = ""
	-- Toolbar: search, raid picker, group alts, count, Copy.
	self.search = W.SearchBox(page, 220, "Search name, profession, note", function(text)
		Roster.filter = text
		Roster:Refresh()
	end)
	self.search:SetPoint("TOPLEFT", 0, 0)
	self.raidMenu = W.Menu(page, {
		width = 170, items = raidItems,
		get = function() return rs.raid or "none" end,
		set = function(v)
			rs.raid = (v ~= "none") and v or nil
			Roster:Refresh()
		end,
	})
	self.raidMenu.tooltip = "Pick a raid to see who is attuned"
	self.raidMenu:SetPoint("LEFT", self.search, "RIGHT", SP.s, 0)
	self.groupCheck = W.Check(page, "Group alts", function() return SK.DB.settings.groupAlts end, function(v)
		SK.DB.settings.groupAlts = v
		Roster:Refresh()
	end)
	self.groupCheck.tooltip = "Show each player once, with their alts in the tooltip"
	self.groupCheck:SetPoint("LEFT", self.raidMenu, "RIGHT", SP.l, 0)
	self.copy = W.Button(page, "Copy", nil, S.control, function() Roster:CopyText() end)
	self.copy:SetPoint("TOPRIGHT", 0, 0)
	self.copy.tooltip = "Copy this list as plain text (for Discord). Notes are never included."
	self.count = Theme.Text(page, "small", "dim")
	self.count:SetPoint("LEFT", self.groupCheck.label, "RIGHT", SP.l, 0)
	-- The counter stops at the Copy button (long texts are cut, not overlapped).
	self.count:SetPoint("RIGHT", self.copy, "LEFT", -SP.s, 0)
	self.count:SetJustifyH("RIGHT")
	self.count:SetWordWrap(false)

	-- Second toolbar row, shown only while a raid is selected.
	local bar = CreateFrame("Frame", nil, page)
	bar:SetPoint("TOPLEFT", 0, -(S.control + SP.s))
	bar:SetPoint("TOPRIGHT", 0, -(S.control + SP.s))
	bar:SetHeight(S.control)
	self.attBar = bar
	self.filterTabs = {}
	local prev
	for _, f in ipairs(FILTERS) do
		local t = W.Chip(bar, f[2], function()
			rs.attFilter = f[1]
			Roster:Refresh()
		end)
		t.value = f[1]
		if prev then t:SetPoint("LEFT", prev, "RIGHT", SP.xs, 0) else t:SetPoint("LEFT", 0, 0) end
		self.filterTabs[#self.filterTabs + 1] = t
		prev = t
	end
	self.maxCheck = W.Check(bar, "Max level only", function() return rs.maxLevelOnly end, function(v)
		rs.maxLevelOnly = v
		Roster:Refresh()
	end)
	self.maxCheck:SetPoint("LEFT", prev, "RIGHT", SP.l, 0)
	self.attCount = Theme.Text(bar, "small", "dim")
	self.attCount:SetPoint("LEFT", self.maxCheck.label, "RIGHT", SP.l, 0)
	self.attCount:SetPoint("RIGHT", 0, 0)
	self.attCount:SetJustifyH("RIGHT")
	self.attCount:SetWordWrap(false)

	-- Two lists: the List widget builds its columns once, so instead of
	-- rebuilding it we keep one per column set and show the one in use.
	local function makeList(columns, sortCol)
		local l = W.List(page, {
			columns = columns, setCell = setCell,
			onClick = function(r) SK.CharacterTab:ShowCharacter(r.guid) end,
			onEnter = tooltip,
		})
		l:SetPoint("BOTTOMRIGHT")
		l.sortCol = sortCol
		return l
	end
	self.list = makeList(COLUMNS, 7)          -- online first
	self.list:SetPoint("TOPLEFT", 0, -(S.control + SP.m))
	self.attList = makeList(ATT_COLUMNS, 7)    -- online first
	self.attList:SetPoint("TOPLEFT", 0, -(2 * S.control + SP.s + SP.m))
	self.attList:Hide()
end

-- What an empty roster says. Pure; tested.
function Roster.EmptyText(hasGuild, filter)
	if not hasGuild then return "You're not in a guild, so there's no roster to show." end
	if filter and filter ~= "" then return "Nobody matches \"" .. filter .. "\". Try a name, a profession or part of a note." end
	return "The guild roster hasn't loaded yet. It fills in a few seconds after login."
end

-- From the Overview's Data health card: normal Roster, missing and oldest
-- data first (Data column ascending).
function Roster:ShowOldestFirst()
	SK.DB.settings.roster.raid = nil
	SK.MainFrame:Select("roster")
	for i, col in ipairs(COLUMNS) do
		if col.key == "data" then self.list.sortCol, self.list.sortDesc = i, false end
	end
	self.list:Sort()
end

-- Overview "Without addon": the plain roster, people without Short Royalty first.
function Roster:ShowWithoutAddon()
	SK.DB.settings.roster.raid = nil
	SK.MainFrame:Select("roster")
	for i, col in ipairs(COLUMNS) do
		if col.key == "addon" then self.list.sortCol, self.list.sortDesc = i, false end
	end
	self.list:Sort()
end

-- The list as shown (current filters and sort) as plain text.
function Roster:CopyText()
	local rs = SK.DB.settings.roster
	local raid = rs.raid and Roster.Raid(rs.raid)
	local list = raid and self.attList or self.list
	local title = "Short Royalty roster" .. (raid and (": " .. raid.name) or "")
	if self.filter and self.filter ~= "" then title = title .. " (search: " .. self.filter .. ")" end
	local text = SK.Export.Roster(list.items, { title = title, hideOwnGear = SK.DB.settings.share.gear == false })
	SK.DebugWindow:ShowText("Copy as text", text)
	return text
end

function Roster:Refresh()
	if not self.list then return end
	local guild = SK.DBM:Guild()
	local rs = SK.DB.settings.roster
	local raid = rs.raid and Roster.Raid(rs.raid)
	if raid and raid.hidden then raid = nil end -- not in the first raid wave
	if rs.raid and not raid then rs.raid = nil end
	self.raidMenu:Refresh()
	self.groupCheck:SetShown(raid == nil)
	self.attBar:SetShown(raid ~= nil)
	self.list:SetShown(raid == nil)
	self.attList:SetShown(raid ~= nil)

	if raid then
		local noneNeeded = raid.status == "none"
		local rows, counts, maxLevel = Roster.AttunementRows(guild, raid.key, noneNeeded and "all" or rs.attFilter,
			rs.maxLevelOnly, self.filter, SK.Compat.Now())
		for _, t in ipairs(self.filterTabs) do
			t:SetActive(t.value == (rs.attFilter or "all"))
			t:SetShown(not noneNeeded)
		end
		self.maxCheck:Refresh()
		self.maxCheck:SetLabel(maxLevel > 0 and ("Max level only (" .. maxLevel .. ")") or "Max level only")
		if noneNeeded then
			self.attCount:SetText(Theme.Code("good") .. "No attunement needed for this raid.|r")
		elseif raid.status == "todo" then
			self.attCount:SetText(Theme.Paint("spark", "Attunement quests for this raid aren't known yet."))
		else
			self.attCount:SetText(string.format("%d attuned · %d not · %d unknown", counts.yes, counts.no, counts.unknown))
		end
		self.count:SetText(Theme.Count(counts.yes + counts.no + counts.unknown + counts.none, "character"))
		self.attList:SetEmptyText(Roster.EmptyText(guild ~= nil, self.filter))
		self.attList:SetItems(rows)
		return
	end

	local rows = Roster.Rows(guild, SK.Compat.Now(), self.filter, SK.DB.settings.groupAlts)
	local withData, outdated, total = 0, 0, 0
	for _, r in ipairs(rows) do
		for _, x in ipairs({ r, unpack(r.alts or {}) }) do
			total = total + 1
			if x.hasData then withData = withData + 1 end
			if x.outdated then outdated = outdated + 1 end
		end
	end
	local text = Theme.Count(total, "character") .. " · " .. withData .. " with data"
	if outdated > 0 then text = text .. " · " .. Theme.Paint("spark", outdated .. " need an update") end
	local newest = Roster.NewestVersion(guild)
	if guild and newest and SK.VERSION ~= "dev" and SK.Sync.versionNewer(newest, SK.VERSION) then
		text = text .. " · " .. Theme.Paint("spark", "Short Royalty " .. newest .. " is out (you have " .. SK.VERSION .. ")")
	end
	self.count:SetText(text)
	self.groupCheck:Refresh()
	self.list:SetEmptyText(Roster.EmptyText(guild ~= nil, self.filter))
	self.list:SetItems(rows)
end

SK.MainFrame:AddTab("roster", "Roster", Roster)
