-- Raids tab (v0.4.0): upcoming raid events from Blizzard's guild calendar on
-- the left; the selected event's sign-ups on the right with role, spec,
-- item level and attunement, role counts and a readiness summary. Read-only:
-- events are made in Blizzard's calendar (New raid opens it), and signing up
-- happens there too for now. Numbers come from Core/Raids.lua.
local _, SK = ...

local Tab = SK:NewModule("RaidsTab")
local Theme, W, Compat = SK.Theme, SK.Widgets, SK.Compat
local Raids = SK.Raids
local S, SP = Theme.SIZES, Theme.SPACE

Tab.EVENTS_W = 300
Tab.LINEUP_W = S.window[1] - 2 * SP.l - Tab.EVENTS_W - SP.l

local WEEKDAY = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local MONTH = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local STATUS_TONE = { coming = "good", maybe = "text", bench = "dim", invited = "dim", out = "faint" }
local ATT_TEXT = { yes = "yes", no = "no", unknown = "?", none = "not needed" }
local ATT_TONE = { yes = "good", no = "bad", unknown = "dim", none = "dim" }

-- "Thu 10 Dec 20:00". Pure; tested.
function Tab.When(e)
	local wd = 1 + (math.floor(Raids.Minutes(e) / 1440) + 4) % 7 -- 1970-01-01 was a Thursday
	return string.format("%s %d %s %02d:%02d", WEEKDAY[wd], e.monthDay, MONTH[e.month] or "?", e.hour or 0, e.minute or 0)
end

---------------------------------------------------------------------------
-- Columns (each list: its width minus the 12 px scroll bar)
---------------------------------------------------------------------------
-- Events: 300 - 12 = 288.
local EVENT_COLUMNS = {
	{ key = "when", title = "When", width = 126 },
	{ key = "title", title = "Event", width = 162 },
}

-- Line-up: 532 - 12 = 520.
local LINEUP_COLUMNS = {
	{ key = "status", title = "Status", width = 84 },
	{ key = "name", title = "Name", width = 136 },
	{ key = "role", title = "Role", width = 76 },
	{ key = "spec", title = "Spec", width = 112 },
	{ key = "ilvl", title = "iLvl", width = 40, align = "RIGHT" },
	{ key = "att", title = "Attuned", width = 72, align = "RIGHT" },
}

local function setEventCell(fs, e, col)
	if col.key == "when" then
		fs:SetText(Theme.Paint("dim", Tab.When(e)))
	else
		local raid = e.raid and Theme.Paint("dim", "  " .. e.raid.name) or ""
		fs:SetText(e.title .. raid)
	end
end

local function setLineupCell(fs, r, col)
	local k = col.key
	if k == "status" then
		fs:SetText(Theme.Paint(STATUS_TONE[r.group] or "dim", r.statusName))
	elseif k == "name" then
		local dup = r.duplicateOf and Theme.Paint("spark", " !") or ""
		fs:SetText(Theme.ClassText(r.name, r.class) .. dup)
	elseif k == "role" then
		if not r.role then fs:SetText(Theme.DASH)
		else
			local name = SK.Data.ROLE_NAMES[r.role]
			fs:SetText(r.roleGuess and Theme.Paint("dim", name .. "?") or name)
		end
	elseif k == "spec" then
		fs:SetText(r.spec and Theme.Paint("dim", (r.tree and (r.tree .. " ") or "") .. r.spec) or Theme.DASH)
	elseif k == "ilvl" then
		fs:SetText(r.ilvl and string.format("%.0f", r.ilvl) or Theme.DASH)
	else
		local t = ATT_TEXT[r.att] or "?"
		if r.attNote then t = t .. " !" end
		fs:SetText(Theme.Paint(r.attNote and "spark" or (ATT_TONE[r.att] or "dim"), t))
	end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local ROLE_ITEMS = {
	{ value = "none", text = "Not set" }, { value = "TANK", text = "Tank" },
	{ value = "HEALER", text = "Healer" }, { value = "DPS", text = "DPS" },
}

function Tab:Build(page)
	self.page = page

	-- Toolbar: my roles (this character), New raid.
	local label = Theme.Text(page, "small", "dim")
	label:SetPoint("TOPLEFT", 0, -SP.xs)
	label:SetText("My roles")
	local function myRoles() return SK.DB.roles[Compat.PlayerGUID() or ""] or {} end
	self.mainRole = W.Menu(page, {
		width = 110, items = function() return ROLE_ITEMS end,
		get = function() return myRoles().main or "none" end,
		set = function(v)
			local second = myRoles().second
			if v == "none" then SK.Profile:SetRoles(nil) else SK.Profile:SetRoles(v, second ~= v and second or nil) end
			Tab:Refresh()
		end,
	})
	self.mainRole:SetPoint("LEFT", label, "RIGHT", SP.s, 0)
	self.mainRole.tooltip = "Your main raid role on this character. Guildmates see it in raid line-ups."
	self.secondRole = W.Menu(page, {
		width = 110, items = function() return ROLE_ITEMS end,
		get = function() return myRoles().second or "none" end,
		set = function(v)
			local main = myRoles().main
			if main then SK.Profile:SetRoles(main, v ~= "none" and v ~= main and v or nil) end
			Tab:Refresh()
		end,
	})
	self.secondRole:SetPoint("LEFT", self.mainRole, "RIGHT", SP.xs, 0)
	self.secondRole.tooltip = "A second role you can also play (optional). Set your main role first."

	self.newRaid = W.Button(page, "New raid", nil, S.control, function()
		if not Compat.ToggleCalendar() then SK:Print("Couldn't open the calendar on this client.") end
	end)
	self.newRaid:SetPoint("TOPRIGHT", 0, 0)
	self.newRaid.tooltip = "Opens Blizzard's calendar. Make a Guild Event of type Raid, and put Ony, BD " ..
		"or Hyjal in the title so Short Royalty knows which raid it is."
	self.status = Theme.Text(page, "small", "dim")
	self.status:SetPoint("RIGHT", self.newRaid, "LEFT", -SP.m, 0)
	self.status:SetPoint("LEFT", self.secondRole, "RIGHT", SP.m, 0)
	self.status:SetJustifyH("RIGHT")
	self.status:SetWordWrap(false)

	local top = -(S.control + SP.m)
	self.events = W.List(page, {
		columns = EVENT_COLUMNS, setCell = setEventCell,
		onClick = function(e) Tab:Select(e.eventID, true) end,
		onEnter = function(row, e)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:AddLine(e.title)
			Theme.TipLine(GameTooltip, Tab.When(e), "dim")
			Theme.TipLine(GameTooltip, e.raid and (e.raid.name .. " (" .. e.raid.size .. ")") or
				"Raid not recognised from the title: pick it on the right", e.raid and "text" or "spark", true)
			if e.inviteStatus then
				Theme.TipLine(GameTooltip, "You: " .. (Raids.STATUS_NAME[e.inviteStatus] or "?"), "dim")
			end
			Theme.TipLine(GameTooltip, "Click to see who signed up", "gold")
			GameTooltip:Show()
		end,
	})
	self.events:SetPoint("TOPLEFT", 0, top)
	self.events:SetPoint("BOTTOMLEFT")
	self.events:SetWidth(Tab.EVENTS_W)
	self.events:SetSelected(function(e) return e.eventID == Tab.selected end)
	self.events:SetEmptyText("No raids in the next " .. Raids.DAYS_AHEAD .. " days. Press New raid to make one in " ..
		"Blizzard's calendar (type Raid; put Ony, BD or Hyjal in the title).")

	-- Right: the selected event.
	local right = CreateFrame("Frame", nil, page)
	right:SetPoint("TOPLEFT", self.events, "TOPRIGHT", SP.l, 0)
	right:SetPoint("BOTTOMRIGHT")
	self.right = right
	self.title = Theme.Text(right, "title", "text")
	self.title:SetPoint("TOPLEFT", 0, -2)
	self.title:SetWordWrap(false)
	self.copy = W.Button(right, "Copy", nil, S.controlSmall, function() Tab:CopyText() end, "quiet")
	self.copy:SetPoint("TOPRIGHT", 0, 0)
	self.copy.tooltip = "The line-up as plain text, for Discord"
	self.reread = W.Button(right, "Read again", nil, S.controlSmall, function()
		local e = Tab:SelectedEvent()
		if e then Raids:Read(e); Tab:Refresh() end
	end, "quiet")
	self.reread:SetPoint("RIGHT", self.copy, "LEFT", -SP.xs, 0)
	self.raidMenu = W.Menu(right, {
		width = 150,
		items = function()
			local items = { { value = "auto", text = "Raid: from the title" } }
			for _, r in ipairs(SK.Data.ShownAttunements()) do items[#items + 1] = { value = r.key, text = r.name } end
			return items
		end,
		get = function() return Tab.selected and SK.DB.raidPick[Tab.selected] or "auto" end,
		set = function(v)
			if Tab.selected then SK.DB.raidPick[Tab.selected] = v ~= "auto" and v or nil end
			Tab:Refresh()
		end,
	})
	self.raidMenu:SetPoint("RIGHT", self.reread, "LEFT", -SP.s, 0)
	self.raidMenu.tooltip = "Which raid this event is for (sets the size and the attunement check)"
	self.title:SetPoint("RIGHT", self.raidMenu, "LEFT", -SP.s, 0)

	self.counts = Theme.Text(right, "body", "text")
	self.counts:SetPoint("TOPLEFT", 0, -(S.control + SP.xs))
	self.counts:SetPoint("RIGHT", 0, 0)
	self.counts:SetWordWrap(false)
	self.ready = Theme.Text(right, "small", "dim")
	self.ready:SetPoint("TOPLEFT", self.counts, "BOTTOMLEFT", 0, -SP.xs)
	self.ready:SetPoint("RIGHT", 0, 0)
	self.ready:SetWordWrap(true)
	self.ready:SetJustifyH("LEFT")

	self.lineup = W.List(right, {
		columns = LINEUP_COLUMNS, setCell = setLineupCell,
		onEnter = function(row, r)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:AddLine(Theme.ClassText(r.name, r.class) .. Theme.Paint("dim", "  level " .. r.level))
			Theme.TipLine(GameTooltip, r.statusName, STATUS_TONE[r.group] or "dim")
			if r.role then
				Theme.TipLine(GameTooltip, SK.Data.ROLE_NAMES[r.role] ..
					(r.second and (", or " .. SK.Data.ROLE_NAMES[r.second]) or "") ..
					(r.roleGuess and " (guessed from talents)" or ""), "text")
			end
			if not r.hasData then
				Theme.TipLine(GameTooltip, "No Short Royalty data: role, spec, gear and attunement unknown", "dim", true)
			end
			if r.attNote then Theme.TipLine(GameTooltip, r.attNote, "spark") end
			if r.enchants > 0 then Theme.TipLine(GameTooltip, Theme.Count(r.enchants, "missing enchant"), "spark") end
			if r.stale then Theme.TipLine(GameTooltip, "Data older than a week", "spark") end
			if r.duplicateOf then Theme.TipLine(GameTooltip, "Also signed up as " .. r.duplicateOf, "spark") end
			Theme.TipLine(GameTooltip, "Click to view character", "gold")
			GameTooltip:Show()
		end,
		onClick = function(r) SK.CharacterTab:ShowCharacter(r.guid) end,
	})
	self.lineup:SetPoint("BOTTOMRIGHT")

	local function refreshIfShown() if page:IsShown() then Tab:Refresh() end end
	SK:On("RAIDS_UPDATED", refreshIfShown)
	SK:On("SELF_UPDATED", refreshIfShown)
end

function Tab:SelectedEvent()
	for _, e in ipairs(self.list or {}) do
		if e.eventID == self.selected then return e end
	end
end

-- Pick an event; read its sign-ups if we don't have them (or `force`).
function Tab:Select(eventID, force)
	self.selected = eventID
	local e = self:SelectedEvent()
	if e and (force or not Raids.cache[eventID]) then Raids:Read(e) end
	self:Refresh()
end

function Tab:Lineup()
	local e = self:SelectedEvent()
	local cached = e and Raids.cache[e.eventID]
	if not cached then return e, nil end
	local guild = SK.DBM:Guild()
	local ctx = { guild = guild, now = Compat.Now(), profile = function(g) return SK.Profile:Get(g, guild) end,
		isOwn = function(g) return SK.DB.account[g] == true end }
	local rows, s = Raids.LineUp(cached.invites, e.raid, ctx)
	return e, rows, s, cached
end

function Tab:CopyText()
	local e, rows, s = self:Lineup()
	if not rows then return end
	local text = Raids.Text(e, e.raid, rows, s)
	SK.DebugWindow:ShowText("Copy as text", text)
	return text
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
function Tab:Refresh()
	if not self.events then return end
	self.mainRole:Refresh()
	self.secondRole:Refresh()
	self.secondRole:SetDisabled(not (SK.DB.roles[Compat.PlayerGUID() or ""] or {}).main)

	self.list = Raids:Events()
	if #self.list == 0 and not self.requested then
		self.requested = true
		Compat.CalendarRequest() -- the calendar may not have loaded yet; RAIDS_UPDATED follows
	end
	self.events:SetItems(self.list)
	if not self:SelectedEvent() and self.list[1] then
		return self:Select(self.list[1].eventID)
	end

	local e, rows, s, cached = self:Lineup()
	self.right:SetShown(e ~= nil)
	self.status:SetText(Theme.Count(#self.list, "raid") .. " in the next " .. Raids.DAYS_AHEAD .. " days")
	if not e then return end
	self.title:SetText(e.title)
	self.raidMenu:Refresh()
	self.copy:SetShown(rows ~= nil)

	if not rows then
		local why = Raids.pending and "Reading sign-ups..." or (Raids.lastError and ("Can't read sign-ups: " ..
			Raids.lastError .. ". Press Read again.") or "Reading sign-ups...")
		self.counts:SetText(Theme.Paint("dim", why))
		self.ready:SetText("")
		self.lineup:SetItems({})
		self.lineup:SetEmptyText(nil)
		self.lineup:SetPoint("TOPLEFT", self.counts, "BOTTOMLEFT", 0, -SP.m)
		return
	end
	local ago = Theme.Ago(cached.at, Compat.Now())
	self.counts:SetText(Raids.CountsText(s) .. Theme.Paint("dim", "  ·  read " .. (ago == "now" and "just now" or (ago .. " ago"))))
	local parts = {}
	for _, r in ipairs(Raids.Readiness(s)) do parts[#parts + 1] = Theme.Paint(r.tone, r.text) end
	if not e.raid then parts[#parts + 1] = Theme.Paint("spark", "Raid not recognised: pick it in the menu above") end
	self.ready:SetText(table.concat(parts, Theme.Paint("dim", "  ·  ")))
	self.lineup:SetPoint("TOPLEFT", self.ready, "BOTTOMLEFT", 0, -SP.m)
	self.lineup:SetItems(rows)
	self.lineup:SetEmptyText("Nobody has signed up yet.")
end

SK.MainFrame:AddTab("raids", "Raids", Tab)
