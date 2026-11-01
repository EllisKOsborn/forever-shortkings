-- Roster tab: every guild member, sortable, with class colours, level,
-- spec, professions, item level, online status / last seen and data age.
local _, SK = ...

local Roster = SK:NewModule("RosterTab")
local Theme, W = SK.Theme, SK.Widgets

-- Build display rows from saved members + profiles. Pure; tested.
function Roster.Rows(guild, _now, filter)
	local rows = {}
	if not guild then return rows end
	filter = filter and filter ~= "" and filter:lower() or nil
	for guid, m in pairs(guild.members) do
		if not m.leftAt then
			local p = guild.profiles[guid]
			local profs, profText = {}, {}
			if p and p.profs then
				for skillLine, pr in pairs(p.profs) do
					profs[#profs + 1] = { name = pr.name or SK.Data.ProfessionShort(skillLine), rank = pr.rank or 0,
						short = SK.Data.ProfessionShort(skillLine, pr.name), primary = pr.primary }
				end
				table.sort(profs, function(a, b)
					if (a.primary and true or false) ~= (b.primary and true or false) then return a.primary and true or false end
					return a.name < b.name
				end)
				for _, pr in ipairs(profs) do
					if pr.primary then profText[#profText + 1] = pr.short .. " " .. pr.rank end
				end
			end
			local spec, mainTree = SK.Talents.Summary(p and p.talents)
			local row = {
				guid = guid, name = m.name or (p and p.name) or "?", class = m.class or (p and p.class),
				level = m.level or (p and p.level) or 0, rank = m.rank or "", rankIndex = m.rankIndex or 99,
				online = m.online, lastSeen = m.lastSeen, hasData = p ~= nil, updated = p and p.updated,
				ilvl = p and p.ilvl, spec = spec, mainTree = mainTree,
				profText = table.concat(profText, ", "), profs = profs,
				addon = m.addon, isSelf = SK.DB.account[guid] or false,
			}
			local keep = true
			if filter then
				local hay = (row.name .. " " .. row.profText .. " " .. (row.mainTree or "") .. " " ..
					(row.class or "") .. " " .. row.rank):lower()
				for _, pr in ipairs(profs) do hay = hay .. " " .. pr.name:lower() end
				keep = hay:find(filter, 1, true) ~= nil
			end
			if keep then rows[#rows + 1] = row end
		end
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
	{ key = "name", title = "Name", width = 180, sort = byName },
	{ key = "level", title = "Lvl", width = 40, align = "RIGHT", sort = byNum("level") },
	{ key = "rank", title = "Rank", width = 100, sort = byNum("rankIndex") },
	{ key = "spec", title = "Spec", width = 120, sort = function(a, b) return (a.mainTree or "~") < (b.mainTree or "~") end },
	{ key = "profs", title = "Professions", width = 170, sort = function(a, b) return a.profText < b.profText end },
	{ key = "ilvl", title = "iLvl", width = 45, align = "RIGHT", sort = byNum("ilvl") },
	{ key = "seen", title = "Online", width = 70, sort = function(a, b)
		if a.online ~= b.online then return a.online and true or false end
		return (a.lastSeen or 0) > (b.lastSeen or 0)
	end },
	{ key = "data", title = "Data", width = 85, sort = byNum("updated") },
}

local function setCell(fs, r, col)
	local k = col.key
	local now = SK.Compat.Now()
	if k == "name" then
		fs:SetText(Theme.ClassText(r.name, r.class) .. (r.isSelf and (" " .. Theme.Code("muted") .. "(you)|r") or ""))
	elseif k == "level" then
		fs:SetText(r.level > 0 and r.level or "")
	elseif k == "rank" then
		fs:SetText(Theme.Code("muted") .. r.rank .. "|r")
	elseif k == "spec" then
		fs:SetText(r.spec and ((r.mainTree or "") .. " " .. Theme.Code("muted") .. r.spec .. "|r") or "")
	elseif k == "profs" then
		fs:SetText(r.profText)
	elseif k == "ilvl" then
		fs:SetText(r.ilvl and string.format("%.0f", r.ilvl) or "")
	elseif k == "seen" then
		if r.online then fs:SetText(Theme.Code("good") .. "Online|r")
		else fs:SetText(Theme.Code("muted") .. Theme.Ago(r.lastSeen, now) .. "|r") end
	elseif k == "data" then
		if r.hasData then fs:SetText(Theme.Ago(r.updated, now))
		else fs:SetText(Theme.Code("muted") .. "no addon/trial|r") end
	end
end

local function tooltip(row, r)
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Theme.ClassText(r.name, r.class))
	if r.spec then GameTooltip:AddLine((r.mainTree or "Talents") .. " " .. r.spec, 1, 1, 1) end
	for _, pr in ipairs(r.profs) do GameTooltip:AddDoubleLine(pr.name, pr.rank, 1, 1, 1, 1, 1, 1) end
	if not r.hasData then
		GameTooltip:AddLine("No data yet. They may not have the addon, or be on a trial account (trials can't sync).", 0.7, 0.6, 0.65, true)
	elseif r.addon then
		GameTooltip:AddLine("Short Kings " .. r.addon, 0.7, 0.6, 0.65)
	end
	GameTooltip:AddLine("Click to view character", 1, 0.76, 0.29)
	GameTooltip:Show()
end

function Roster:Build(page)
	self.filter = ""
	self.search = W.SearchBox(page, 260, "Search name, profession, spec...", function(text)
		Roster.filter = text
		Roster:Refresh()
	end)
	self.search:SetPoint("TOPLEFT", 0, 0)
	self.count = Theme.Text(page, 12, "muted")
	self.count:SetPoint("LEFT", self.search, "RIGHT", 12, 0)

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
	local rows = Roster.Rows(SK.DBM:Guild(), SK.Compat.Now(), self.filter)
	local withData = 0
	for _, r in ipairs(rows) do if r.hasData then withData = withData + 1 end end
	self.count:SetText(string.format("%d members · %d with Short Kings data", #rows, withData))
	self.list:SetItems(rows)
end

SK.MainFrame:AddTab("roster", "Roster", Roster)
