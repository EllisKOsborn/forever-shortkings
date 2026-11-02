-- Roster tab: every guild member, sortable, with class colours, level,
-- spec, professions, item level, online status (with addon dots), addon
-- version and data age. Alts can be grouped under their main.
local _, SK = ...

local Roster = SK:NewModule("RosterTab")
local Theme, W = SK.Theme, SK.Widgets

-- "addon" = online with Short Kings, "online" = online without it, "offline".
-- (Lives in Identity so non-UI code such as Sync and CraftIndex can use it.)
Roster.Status = SK.Identity.Status

local STATUS_RANK = { addon = 3, online = 2, offline = 1 }
-- Status marks: shape and colour (Theme.StatusMark). Kept under the old name.
local DOT = Theme.STATUS_MARK
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
		outdated = version and newest and version ~= "dev" and SK.Sync.versionNewer(newest, version) or false,
		note = m.note, officerNote = m.officerNote,
		missingEnchants = p and p.gear and #SK.Data.Enchants.Missing(p.gear, p.class) or nil,
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

local COLUMNS = {
	{ key = "name", title = "Name", width = 187, sort = byName },
	{ key = "level", title = "Lvl", width = 36, align = "RIGHT", sort = byNum("level") },
	{ key = "rank", title = "Rank", width = 92, sort = byNum("rankIndex") },
	{ key = "spec", title = "Spec", width = 132, sort = function(a, b) return (a.mainTree or "~") < (b.mainTree or "~") end },
	{ key = "profs", title = "Professions", width = 142, sort = function(a, b) return a.profText < b.profText end },
	{ key = "ilvl", title = "iLvl", width = 40, align = "RIGHT", sort = byNum("ilvl") },
	{ key = "seen", title = "Online", width = 80, sort = function(a, b)
		if a.status ~= b.status then return STATUS_RANK[a.status] > STATUS_RANK[b.status] end
		return (a.lastSeen or 0) > (b.lastSeen or 0)
	end },
	{ key = "addon", title = "Ver", width = 48, sort = function(a, b) return (a.addon or "") > (b.addon or "") end },
	{ key = "data", title = "Data", width = 50, sort = byNum("updated") },
}

local ATT_RANK = { yes = 3, no = 2, unknown = 1, none = 0 }

-- While a raid is selected: Professions and Ver make room for Attuned.
local ATT_COLUMNS = {
	COLUMNS[1], COLUMNS[2], COLUMNS[3], COLUMNS[4],
	{ key = "att", title = "Attuned", width = 140, sort = function(a, b)
		if a.att ~= b.att then return ATT_RANK[a.att] > ATT_RANK[b.att] end
		return byName(a, b)
	end },
	COLUMNS[6], COLUMNS[7], COLUMNS[9],
}

-- The game font has no check-mark glyphs, so the marks are the ready-check
-- atlases from Blizzard's Forever ReadyCheck.lua (READY_CHECK_*_TEXTURE).
local ATT_TEXT = {
	yes = "|A:UI-LFG-ReadyMark:12:12|a " .. Theme.Code("success") .. "yes|r",
	no = "|A:UI-LFG-DeclineMark:12:12|a " .. Theme.Code("danger") .. "no|r",
	unknown = "|A:UI-LFG-PendingMark:12:12|a " .. Theme.Code("textMuted") .. "unknown|r",
	none = Theme.Code("textMuted") .. "not needed|r",
}
Roster.ATT_TEXT = ATT_TEXT

local function setCell(fs, r, col)
	local k = col.key
	local now = SK.Compat.Now()
	local C = Theme.Code
	if k == "name" then
		local extra = ""
		if r.isSelf then extra = " " .. C("textMuted") .. "(you)|r" end
		if r.alts and #r.alts > 0 then extra = extra .. " " .. C("textDim") .. "+" .. #r.alts .. "|r" end
		fs:SetText(Theme.ClassText(r.name, r.class) .. extra)
	elseif k == "level" then
		fs:SetText(r.level > 0 and r.level or "")
	elseif k == "rank" then
		fs:SetText(C("textDim") .. r.rank .. "|r")
	elseif k == "spec" then
		fs:SetText(r.spec and ((r.mainTree or "") .. " " .. C("textMuted") .. r.spec .. "|r") or "")
	elseif k == "profs" then
		fs:SetText(C("textDim") .. r.profText .. "|r")
	elseif k == "ilvl" then
		fs:SetText(r.ilvl and string.format("%.0f", r.ilvl) or "")
	elseif k == "seen" then
		local dot = DOT[r.status] .. " "
		if r.status == "offline" then
			fs:SetText(dot .. C("textMuted") .. Theme.Ago(r.lastSeen, now) .. "|r")
		elseif r.onAlt then
			fs:SetText(dot .. C("textDim") .. "on alt|r")
		else
			fs:SetText(dot .. "Online")
		end
	elseif k == "addon" then
		if not r.addon then fs:SetText("")
		elseif r.outdated then fs:SetText(C("warning") .. r.addon .. "|r")
		else fs:SetText(C("textMuted") .. r.addon .. "|r") end
	elseif k == "att" then
		fs:SetText(ATT_TEXT[r.att or "unknown"] .. (r.attNote and ("  " .. C("warning") .. "no amulet|r") or ""))
	elseif k == "data" then
		if r.hasData and not r.isSelf and Theme.IsStale(r.updated, now) then
			fs:SetText(C("warning") .. Theme.Ago(r.updated, now) .. "|r")
		elseif r.hasData then fs:SetText(C("textDim") .. Theme.Ago(r.updated, now) .. "|r")
		else fs:SetText(C("textMuted") .. "none|r") end
	end
end

local STATUS_TEXT = {
	addon = "Online with Short Kings",
	online = "Online without Short Kings (or not heard from yet)",
	offline = "Offline",
}

local function tooltip(row, r)
	local now = SK.Compat.Now()
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Theme.ClassText(r.name, r.class))
	if r.altOf then GameTooltip:AddLine("alt of " .. r.altOf, Theme.RGB("textMuted")) end
	if r.att then
		local raid = Roster.Raid(SK.DB.settings.roster.raid)
		local tr, tg, tb = Theme.RGB("textDim")
		GameTooltip:AddDoubleLine((raid and raid.name or "Raid") .. " attunement", ATT_TEXT[r.att], tr, tg, tb)
		if r.attNote then GameTooltip:AddLine(r.attNote, Theme.RGB("warning")) end
	end
	GameTooltip:AddLine(DOT[r.status] .. " " .. STATUS_TEXT[r.status], Theme.RGB("textDim"))
	if r.spec then GameTooltip:AddLine((r.mainTree or "Talents") .. " " .. r.spec, 1, 1, 1) end
	for _, pr in ipairs(r.profs) do GameTooltip:AddDoubleLine(pr.name, pr.rank, 1, 1, 1, 1, 1, 1) end
	if r.missingEnchants and r.missingEnchants > 0 then
		GameTooltip:AddLine(r.missingEnchants .. " item(s) missing an enchant", Theme.RGB("warning"))
	end
	if r.note and r.note ~= "" then
		local nr, ng, nb = Theme.RGB("accent")
		GameTooltip:AddLine("Note: " .. r.note, nr, ng, nb, true)
	end
	if r.officerNote and r.officerNote ~= "" then
		local orr, og, ob = Theme.RGB("warning")
		GameTooltip:AddLine("Officer note: " .. r.officerNote, orr, og, ob, true)
	end
	if r.alts and #r.alts > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Alts", Theme.RGB("textDim"))
		local mr, mg, mb = Theme.RGB("textMuted")
		for _, alt in ipairs(r.alts) do
			local right = alt.status == "offline" and Theme.Ago(alt.lastSeen, now) or "online"
			GameTooltip:AddDoubleLine(DOT[alt.status] .. " " .. Theme.ClassText(alt.name, alt.class) ..
				"  " .. (alt.level > 0 and alt.level or ""), right, 1, 1, 1, mr, mg, mb)
		end
	end
	GameTooltip:AddLine(" ")
	if not r.hasData then
		local mr, mg, mb = Theme.RGB("textMuted")
		GameTooltip:AddLine("No data yet. They may not have the addon, or be on a trial account (trials can't sync).",
			mr, mg, mb, true)
	elseif r.addon then
		if not r.isSelf and Theme.IsStale(r.updated, now) then
			GameTooltip:AddLine("Data is " .. Theme.Ago(r.updated, now) .. " old and may be out of date", Theme.RGB("warning"))
		end
		GameTooltip:AddLine("Short Kings " .. r.addon .. (r.outdated and "  (update available)" or ""),
			Theme.RGB(r.outdated and "warning" or "textMuted"))
	end
	GameTooltip:AddLine("Click to view character", Theme.RGB("accent"))
	GameTooltip:Show()
end

local FILTERS = {
	{ "all", "All" }, { "yes", "Attuned" }, { "no", "Not attuned" }, { "unknown", "Unknown" },
}

local function raidItems()
	local items = { { value = "none", text = "All raids" }, { separator = true } }
	for _, a in ipairs(SK.Data.ShownAttunements()) do
		items[#items + 1] = { value = a.key, text = a.name .. (a.size and (" (" .. a.size .. ")") or "") }
	end
	return items
end

function Roster:Build(page, tools)
	local rs = SK.DB.settings.roster
	tools = tools or page
	self.filter = ""
	self.search = W.SearchBox(tools, 232, "Search name, profession, note…", function(text)
		Roster.filter = text
		Roster:Refresh()
	end)
	self.search:SetPoint("LEFT", 0, 0)
	self.raidMenu = W.Menu(tools, {
		width = 168, items = raidItems,
		get = function() return rs.raid or "none" end,
		set = function(v)
			rs.raid = (v ~= "none") and v or nil
			Roster:Refresh()
		end,
	})
	self.raidMenu.tooltip = "Pick a raid to see who is attuned"
	self.raidMenu:SetPoint("LEFT", self.search, "RIGHT", 16, 0)
	self.groupCheck = W.Check(tools, "Group alts", function() return SK.DB.settings.groupAlts end, function(v)
		SK.DB.settings.groupAlts = v
		Roster:Refresh()
	end)
	self.groupCheck:SetPoint("LEFT", self.raidMenu, "RIGHT", 16, 0)
	self.copy = W.Button(tools, "Copy", 84, 28, function() Roster:CopyText() end, { icon = "copy" })
	self.copy:SetPoint("RIGHT", 0, 0)
	self.copy.tooltip = "Copy this list as plain text (for Discord). Notes are never included."
	self.countText = ""

	-- Raid row above the list, shown only while a raid is selected.
	local bar = CreateFrame("Frame", nil, page)
	bar:SetPoint("TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", 0, 0)
	bar:SetHeight(24)
	self.attBar = bar
	self.filterSeg = W.Segments(bar, (function()
		local items = {}
		for _, f in ipairs(FILTERS) do items[#items + 1] = { value = f[1], text = f[2] } end
		return items
	end)(), function() return rs.attFilter or "all" end, function(v)
		rs.attFilter = v
		Roster:Refresh()
	end)
	self.filterSeg:SetPoint("LEFT", 0, 0)
	self.maxCheck = W.Check(bar, "Max level only", function() return rs.maxLevelOnly end, function(v)
		rs.maxLevelOnly = v
		Roster:Refresh()
	end)
	self.maxCheck:SetPoint("LEFT", self.filterSeg, "RIGHT", 24, 0)
	self.attCount = Theme.Text(bar, "label", "textDim")
	self.attCount:SetPoint("RIGHT", 0, 0)
	self.attCount:SetJustifyH("RIGHT")

	-- Two lists: the List widget builds its columns once, so instead of
	-- rebuilding it we keep one per column set and show the one in use.
	local function makeList(columns, sortCol)
		local l = W.List(page, {
			columns = columns, rowHeight = 22, setCell = setCell,
			onClick = function(r) SK.CharacterTab:ShowCharacter(r.guid) end,
			onEnter = tooltip,
		})
		l:SetPoint("BOTTOMRIGHT")
		l.sortCol = sortCol
		return l
	end
	self.list = makeList(COLUMNS, 7)          -- online first
	self.list:SetPoint("TOPLEFT", 0, 0)
	self.attList = makeList(ATT_COLUMNS, 7)    -- online first
	self.attList:SetPoint("TOPLEFT", 0, -40)
	self.attList:Hide()
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

-- The list as shown (current filters and sort) as plain text.
function Roster:CopyText()
	local rs = SK.DB.settings.roster
	local raid = rs.raid and Roster.Raid(rs.raid)
	local list = raid and self.attList or self.list
	local title = "Short Kings roster" .. (raid and (": " .. raid.name) or "")
	if self.filter and self.filter ~= "" then title = title .. " (search: " .. self.filter .. ")" end
	local text = SK.Export.Roster(list.items, { title = title, hideOwnGear = SK.DB.settings.share.gear == false })
	SK.DebugWindow:ShowText("Copy as text", text)
	return text
end

-- The counter lives in the window's status line.
function Roster:SetCount(text)
	self.countText = text
	SK.MainFrame:SetStatus("roster", text)
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
		self.filterSeg:Refresh()
		self.filterSeg:SetShown(not noneNeeded)
		self.maxCheck:Refresh()
		self.maxCheck.label:SetText(maxLevel > 0 and ("Max level only (" .. maxLevel .. ")") or "Max level only")
		if noneNeeded then
			self.attCount:SetText(Theme.Code("success") .. "No attunement needed for this raid.|r")
		elseif raid.status == "todo" then
			self.attCount:SetText(Theme.Code("warning") .. "Attunement quests for this raid aren't known yet.|r")
		else
			self.attCount:SetText(string.format("|A:UI-LFG-ReadyMark:12:12|a %d attuned · |A:UI-LFG-DeclineMark:12:12|a"
				.. " %d not · |A:UI-LFG-PendingMark:12:12|a %d unknown", counts.yes, counts.no, counts.unknown))
		end
		self:SetCount(string.format("%d characters", counts.yes + counts.no + counts.unknown + counts.none)
			.. (raid.key == "ony" and "  ·  Onyxia needs the quest and the Drakefire Amulet in your bags" or ""))
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
	local text = string.format("%d characters · %d with data", total, withData)
	if outdated > 0 then text = text .. " · " .. Theme.Code("warning") .. outdated .. " need an update|r" end
	local newest = Roster.NewestVersion(guild)
	if guild and newest and SK.VERSION ~= "dev" and SK.Sync.versionNewer(newest, SK.VERSION) then
		text = text .. " · " .. Theme.Code("warning") .. "Short Kings " .. newest .. " is out (you have " .. SK.VERSION .. ")|r"
	end
	self:SetCount(text)
	self.groupCheck:Refresh()
	self.list:SetItems(rows)
end

SK.MainFrame:AddTab("roster", "Roster", Roster)
