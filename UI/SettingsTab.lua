-- Settings tab (docs/DESIGN.md): grouped 40 px setting rows on the left
-- (Sharing, Display, Window size); status, the sharing preview and the
-- maintenance buttons on the right.
local _, SK = ...

local Settings = SK:NewModule("SettingsTab")
local Theme, W = SK.Theme, SK.Widgets

local SCALES = { 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3 }
local COL_W, ROW_H = 400, 40

-- A heading and a raised panel under it. Returns the panel.
local function group(page, title, x, y, h)
	local head = Theme.Heading(page, title)
	head:SetPoint("TOPLEFT", x, y)
	local p = CreateFrame("Frame", nil, page)
	p:SetPoint("TOPLEFT", x, y - 20)
	p:SetSize(COL_W, h)
	Theme.Panel(p, { tone = "panel" })
	p.heading = head
	return p
end

function Settings:Build(page)
	local s = SK.DB.settings
	self.checks = {}
	local function rows(panel, list)
		for i, r in ipairs(list) do
			local row = CreateFrame("Frame", nil, panel)
			row:SetPoint("TOPLEFT", 1, -(i - 1) * ROW_H)
			row:SetPoint("TOPRIGHT", -1, -(i - 1) * ROW_H)
			row:SetHeight(ROW_H)
			if i < #list then Theme.Edge(row, "BOTTOM") end
			local c = W.Check(row, r[1], r[2], r[3])
			c:SetPoint("LEFT", 16, r[4] and 6 or 0)
			c.tooltip = r[5]
			if r[4] then
				local hint = Theme.Text(row, "small", "textMuted")
				hint:SetPoint("TOPLEFT", c.label, "BOTTOMLEFT", 0, -2)
				hint:SetText(r[4])
			end
			self.checks[#self.checks + 1] = c
		end
	end

	-- Left column
	local sharing = group(page, "Sharing", 0, 0, 3 * ROW_H)
	rows(sharing, {
		{ "Share and receive guild data (sync)", function() return s.sync end, function(v)
			s.sync = v
			SK:Print(v and "Sync turned on." or "Sync turned off. Nothing will be sent or received.")
			SK.MainFrame:Refresh()
		end },
		{ "Share my gear and talents", function() return s.share.gear end, function(v)
			s.share.gear = v
			SK.Profile:BuildSelf()
			SK:Print(v and "Your gear and talents will be shared." or "Your gear and talents are now private.")
		end },
		{ "Share my recipes and cooldowns", function() return s.share.recipes end, function(v)
			s.share.recipes = v
			SK.Profile:BuildSelf()
			SK:Print(v and "Your recipes will be shared." or "Your recipes are now private.")
		end },
	})
	local display = group(page, "Display", 0, -152, 5 * ROW_H)
	rows(display, {
		{ "Show guild crafters in item tooltips", function() return s.craftTooltips end, function(v)
			s.craftTooltips = v
		end },
		{ "Record guild milestones (Overview)", function() return s.feed end, function(v)
			s.feed = v
		end },
		{ "Show minimap button", function() return not s.minimap.hide end, function(v)
			SK.Minimap:SetShown(v)
		end },
		{ "Reduce motion", function() return s.reduceMotion end, function(v)
			s.reduceMotion = v
			SK:Fire("MOTION_CHANGED")
		end, "Stops the header sparks and the fades" },
		{ "Debug logging in chat", function() return s.debug end, function(v) s.debug = v end },
	})
	local sizeHead = Theme.Heading(page, "Window size")
	sizeHead:SetPoint("TOPLEFT", 0, -386)
	local items = {}
	for _, v in ipairs(SCALES) do items[#items + 1] = { value = v, text = string.format("%d%%", v * 100) } end
	self.scale = W.Segments(page, items, function()
		local cur = s.window.scale or 1
		for _, v in ipairs(SCALES) do if math.abs(v - cur) < 0.01 then return v end end
		return cur
	end, function(v) SK.MainFrame:SetScale(v) end)
	self.scale:SetPoint("TOPLEFT", 0, -404)

	-- Right column
	local x = COL_W + 24
	local status = group(page, "Status", x, 0, 3 * ROW_H)
	self.statusPanel = W.TextPanel(status, "label", 4)
	self.statusPanel:SetPoint("TOPLEFT", 16, -12)
	self.statusPanel:SetPoint("BOTTOMRIGHT", -16, 8)
	local sharingBox = group(page, "What guildmates see from you", x, -152, 156)
	self.sharingHeading = sharingBox.heading
	self.status = W.TextPanel(sharingBox, "label", 4)
	self.status:SetPoint("TOPLEFT", 16, -12)
	self.status:SetPoint("BOTTOMRIGHT", -16, 8)
	self.sharing = self.status

	local actions = {
		{ "Rescan my character", "Re-read gear, talents, professions and reputation now.", function()
			SK.Profile:BuildSelf(); SK:Print("Character rescanned.")
		end },
		{ "Sync now", "Announce your data and ask guildmates for anything missing.", function()
			SK.Sync:SendHello(); SK.Sync:SendQuery(); SK:Print("Sync requested.")
		end },
		{ "Reset window position", nil, function() SK.MainFrame:ResetPosition() end, "ghost" },
		{ "Debug report", "Same as /sk debug: what the addon can see on this client.", function()
			SK.DebugWindow:Open()
		end, "ghost" },
	}
	self.actions = {}
	for i, a in ipairs(actions) do
		local b = W.Button(page, a[1], (COL_W - 16) / 2, 28, a[3], { style = a[4] })
		b.tooltip = a[2]
		b:SetPoint("TOPLEFT", x + ((i - 1) % 2) * ((COL_W + 16) / 2), -344 - math.floor((i - 1) / 2) * 40)
		self.actions[i] = b
	end
	SK.MainFrame:SetStatus("settings", "Changes apply straight away")
end

function Settings:Refresh()
	if not self.checks then return end
	for _, c in ipairs(self.checks) do c:Refresh() end
	self.scale:Refresh()

	local C = Theme.Code
	local paused, why = SK.Sync:IsPaused()
	local canSend, sendWhy = SK.Sync:CanSend()
	local st = SK.Sync.stats
	local own = SK.Profile:Own()
	local lines = {
		"Version " .. SK.VERSION .. "   ·   Guild: " .. (SK.guildName or "none"),
		"Sync: " .. (paused and (Theme.StatusMark("offline") .. " " .. C("warning") .. "paused (" .. why .. ")|r")
			or (Theme.StatusMark("addon") .. " running")) .. "  ·  sending "
			.. (canSend and "allowed" or (C("danger") .. "not allowed (" .. tostring(sendWhy) .. ")|r")),
		string.format("Messages: %d sent, %d received", st.sent, st.received),
		string.format("%d accepted, %d rejected, %d queued", st.accepted, st.rejected, #SK.Sync.queue),
	}
	if own then
		local missing = SK.Professions.Unscanned(own)
		lines[#lines + 1] = "Your data updated " .. SK.Theme.Ago(own.updated) .. " ago"
		if #missing > 0 then
			lines[#lines + 1] = C("warning") .. "Open these profession windows once: " .. table.concat(missing, ", ") .. "|r"
		end
	end
	self.statusPanel:SetText(table.concat(lines, "\n"))

	-- Sharing preview (read-only): exactly what the public copy contains.
	local share = {}
	if own then
		for _, c in ipairs(SK.Profile.SharingSummary(own, SK.DB.settings.share)) do
			share[#share + 1] = (c.shared and (C("success") .. "shared|r   ") or (C("textMuted") .. "private|r  ")) .. c.label
		end
		local pub = SK.DBM:Guild() and SK.DBM:Guild().profiles[own.guid]
		if pub then share[#share + 1] = "Last shared copy updated " .. SK.Theme.Ago(pub.updated) .. " ago" end
	else
		share[#share + 1] = "(nothing yet: your profile is built once the guild roster loads)"
	end
	share[#share + 1] = C("textMuted") .. "Never shared: " .. SK.Profile.NEVER_SHARED .. "|r"
	if not SK.DB.settings.sync then
		share[#share + 1] = C("warning") .. "Sync is off, so nothing is being sent right now.|r"
	end
	share[#share + 1] = C("textMuted") .. "Turning sharing off stops future updates. Copies guildmates already have"
		.. " stay until they're replaced.|r"
	self.status:SetText(table.concat(share, "\n"))
end

SK.MainFrame:AddTab("settings", "Settings", Settings)
