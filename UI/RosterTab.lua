-- Roster tab: every guild member, sortable, with class colours, level,
-- spec, professions, item level, online status (with addon dots), addon
-- version and data age. Alts can be grouped under their main.
local _, SK = ...

local Roster = SK:NewModule("RosterTab")
local Theme, W = SK.Theme, SK.Widgets

Roster.ADDON_FRESH = 25 * 60 -- a HI arrives every 10 min; allow two misses

-- "addon" = online with Short Kings, "online" = online without it, "offline".
function Roster.Status(m, isSelf, now)
	if not m or not m.online then return "offline" end
	if isSelf or (m.addonSeen and now - m.addonSeen < Roster.ADDON_FRESH) then return "addon" end
	return "online"
end

local STATUS_RANK = { addon = 3, online = 2, offline = 1 }
local DOT = {
	addon = "|TInterface\\Buttons\\WHITE8X8:8:8:0:0:8:8:0:8:0:8:124:214:124|t",
	online = "|TInterface\\Buttons\\WHITE8X8:8:8:0:0:8:8:0:8:0:8:255:194:74|t",
	offline = "|TInterface\\Buttons\\WHITE8X8:8:8:0:0:8:8:0:8:0:8:110:90:100|t",
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

local function byName(a, b) return a.name:lower() < b.name:lower() end
local function byNum(key) return function(a, b)
	local x, y = a[key] or -1, b[key] or -1
	if x == y then return byName(a, b) end
	return x < y
end end

local COLUMNS = {
	{ key = "name", title = "Name", width = 170, sort = byName },
	{ key = "level", title = "Lvl", width = 36, align = "RIGHT", sort = byNum("level") },
	{ key = "rank", title = "Rank", width = 90, sort = byNum("rankIndex") },
	{ key = "spec", title = "Spec", width = 120, sort = function(a, b) return (a.mainTree or "~") < (b.mainTree or "~") end },
	{ key = "profs", title = "Professions", width = 150, sort = function(a, b) return a.profText < b.profText end },
	{ key = "ilvl", title = "iLvl", width = 40, align = "RIGHT", sort = byNum("ilvl") },
	{ key = "seen", title = "Online", width = 82, sort = function(a, b)
		if a.status ~= b.status then return STATUS_RANK[a.status] > STATUS_RANK[b.status] end
		return (a.lastSeen or 0) > (b.lastSeen or 0)
	end },
	{ key = "addon", title = "Ver", width = 50, sort = function(a, b) return (a.addon or "") > (b.addon or "") end },
	{ key = "data", title = "Data", width = 70, sort = byNum("updated") },
}

local function setCell(fs, r, col)
	local k = col.key
	local now = SK.Compat.Now()
	local C = Theme.Code
	if k == "name" then
		local extra = ""
		if r.isSelf then extra = " " .. C("muted") .. "(you)|r" end
		if r.alts and #r.alts > 0 then extra = extra .. " " .. C("flame") .. "+" .. #r.alts .. "|r" end
		fs:SetText(Theme.ClassText(r.name, r.class) .. extra)
	elseif k == "level" then
		fs:SetText(r.level > 0 and r.level or "")
	elseif k == "rank" then
		fs:SetText(C("muted") .. r.rank .. "|r")
	elseif k == "spec" then
		fs:SetText(r.spec and ((r.mainTree or "") .. " " .. C("muted") .. r.spec .. "|r") or "")
	elseif k == "profs" then
		fs:SetText(r.profText)
	elseif k == "ilvl" then
		fs:SetText(r.ilvl and string.format("%.0f", r.ilvl) or "")
	elseif k == "seen" then
		local dot = DOT[r.status] .. " "
		if r.status == "offline" then
			fs:SetText(dot .. C("muted") .. Theme.Ago(r.lastSeen, now) .. "|r")
		elseif r.onAlt then
			fs:SetText(dot .. C("good") .. "on alt|r")
		else
			fs:SetText(dot .. C("good") .. "Online|r")
		end
	elseif k == "addon" then
		if not r.addon then fs:SetText("")
		elseif r.outdated then fs:SetText(C("ember") .. r.addon .. "|r")
		else fs:SetText(C("muted") .. r.addon .. "|r") end
	elseif k == "data" then
		if r.hasData then fs:SetText(Theme.Ago(r.updated, now))
		else fs:SetText(C("muted") .. "no addon|r") end
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
	GameTooltip:AddLine(DOT[r.status] .. " " .. STATUS_TEXT[r.status], 0.85, 0.8, 0.82)
	if r.spec then GameTooltip:AddLine((r.mainTree or "Talents") .. " " .. r.spec, 1, 1, 1) end
	for _, pr in ipairs(r.profs) do GameTooltip:AddDoubleLine(pr.name, pr.rank, 1, 1, 1, 1, 1, 1) end
	if r.missingEnchants and r.missingEnchants > 0 then
		GameTooltip:AddLine(r.missingEnchants .. " item(s) missing an enchant", 1, 0.48, 0.1)
	end
	if r.note and r.note ~= "" then GameTooltip:AddLine("Note: " .. r.note, 0.94, 0.48, 0.8, true) end
	if r.officerNote and r.officerNote ~= "" then
		GameTooltip:AddLine("Officer note: " .. r.officerNote, 1, 0.76, 0.29, true)
	end
	if r.alts and #r.alts > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Alts", 0.94, 0.48, 0.8)
		for _, alt in ipairs(r.alts) do
			local right = alt.status == "offline" and Theme.Ago(alt.lastSeen, now) or "online"
			GameTooltip:AddDoubleLine(DOT[alt.status] .. " " .. Theme.ClassText(alt.name, alt.class) ..
				"  " .. (alt.level > 0 and alt.level or ""), right, 1, 1, 1, 0.72, 0.6, 0.67)
		end
	end
	GameTooltip:AddLine(" ")
	if not r.hasData then
		GameTooltip:AddLine("No data yet. They may not have the addon, or be on a trial account (trials can't sync).", 0.7, 0.6, 0.65, true)
	elseif r.addon then
		GameTooltip:AddLine("Short Kings " .. r.addon .. (r.outdated and "  (update available)" or ""),
			r.outdated and 1 or 0.7, r.outdated and 0.48 or 0.6, r.outdated and 0.1 or 0.65)
	end
	GameTooltip:AddLine("Click to view character", 1, 0.76, 0.29)
	GameTooltip:Show()
end

function Roster:Build(page)
	self.filter = ""
	self.search = W.SearchBox(page, 240, "Search name, profession, spec, note...", function(text)
		Roster.filter = text
		Roster:Refresh()
	end)
	self.search:SetPoint("TOPLEFT", 0, 0)
	self.groupCheck = W.Check(page, "Group alts", function() return SK.DB.settings.groupAlts end, function(v)
		SK.DB.settings.groupAlts = v
		Roster:Refresh()
	end)
	self.groupCheck:SetPoint("LEFT", self.search, "RIGHT", 14, 0)
	self.count = Theme.Text(page, 12, "muted")
	self.count:SetPoint("LEFT", self.groupCheck.label, "RIGHT", 16, 0)

	self.list = W.List(page, {
		columns = COLUMNS, rowHeight = 20, setCell = setCell,
		onClick = function(r) SK.CharacterTab:ShowCharacter(r.guid) end,
		onEnter = tooltip,
	})
	self.list:SetPoint("TOPLEFT", 0, -30)
	self.list:SetPoint("BOTTOMRIGHT")
	self.list.sortCol = 7 -- online first
end

function Roster:Refresh()
	if not self.list then return end
	local guild = SK.DBM:Guild()
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
	if outdated > 0 then text = text .. " · " .. Theme.Code("ember") .. outdated .. " need an update|r" end
	self.count:SetText(text)
	self.groupCheck:Refresh()
	self.list:SetItems(rows)
end

SK.MainFrame:AddTab("roster", "Roster", Roster)
