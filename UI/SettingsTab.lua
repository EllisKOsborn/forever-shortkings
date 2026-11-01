-- Settings tab: sync on/off, minimap button, debug logging, window scale,
-- plus a few maintenance buttons and a live status read-out.
local _, SK = ...

local Settings = SK:NewModule("SettingsTab")
local Theme, W = SK.Theme, SK.Widgets

local SCALES = { 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3 }

function Settings:Build(page)
	local s = SK.DB.settings
	local heading = Theme.Text(page, 16, "pink")
	heading:SetPoint("TOPLEFT", 0, 0)
	heading:SetText("Settings")

	self.checks = {}
	local function check(label, get, set)
		local c = W.Check(page, label, get, set)
		c:SetPoint("TOPLEFT", 4, -30 - #self.checks * 28)
		self.checks[#self.checks + 1] = c
		return c
	end
	check("Share and receive guild data (sync)", function() return s.sync end, function(v)
		s.sync = v
		SK:Print(v and "Sync turned on." or "Sync turned off. Nothing will be sent or received.")
		SK.MainFrame:Refresh()
	end)
	check("Show minimap button", function() return not s.minimap.hide end, function(v)
		SK.Minimap:SetShown(v)
	end)
	check("Debug logging in chat", function() return s.debug end, function(v) s.debug = v end)

	-- Window scale: a row of small buttons (works at every UI scale)
	local scaleLabel = Theme.Text(page, 12, "text")
	scaleLabel:SetPoint("TOPLEFT", 4, -30 - #self.checks * 28 - 8)
	scaleLabel:SetText("Window size")
	self.scaleButtons = {}
	local prev
	for _, v in ipairs(SCALES) do
		local b = W.Tab(page, string.format("%d%%", v * 100), function()
			SK.MainFrame:SetScale(v)
			Settings:Refresh()
		end)
		b:SetWidth(54)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", scaleLabel, "RIGHT", 12, 0) end
		b.value = v
		self.scaleButtons[#self.scaleButtons + 1] = b
		prev = b
	end

	-- Actions
	local y = -30 - #self.checks * 28 - 50
	local actions = {
		{ "Rescan my character", "Re-read gear, talents, professions and reputation now.", function()
			SK.Profile:BuildSelf(); SK:Print("Character rescanned.")
		end },
		{ "Sync now", "Announce your data and ask guildmates for anything missing.", function()
			SK.Sync:SendHello(); SK.Sync:SendQuery(); SK:Print("Sync requested.")
		end },
		{ "Reset window position", nil, function() SK.MainFrame:ResetPosition() end },
		{ "Debug report", "Same as /sk debug: what the addon can see on this client.", function()
			SK.DebugWindow:Open()
		end },
	}
	prev = nil
	for _, a in ipairs(actions) do
		local b = W.Button(page, a[1], 170, 24, a[3])
		b.tooltip = a[2]
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("TOPLEFT", 4, y) end
		prev = b
	end

	-- Status
	self.status = W.TextPanel(page)
	self.status:SetPoint("TOPLEFT", 4, y - 40)
	self.status:SetPoint("BOTTOMRIGHT", -14, 0)
end

function Settings:Refresh()
	if not self.checks then return end
	for _, c in ipairs(self.checks) do c:Refresh() end
	local scale = SK.DB.settings.window.scale or 1
	for _, b in ipairs(self.scaleButtons) do b:SetActive(math.abs(b.value - scale) < 0.01) end

	local C = Theme.Code
	local paused, why = SK.Sync:IsPaused()
	local canSend, sendWhy = SK.Sync:CanSend()
	local st = SK.Sync.stats
	local own = SK.Profile:Own()
	local lines = {
		C("pink") .. "Status|r",
		"  Version " .. SK.VERSION .. "   ·   Guild: " .. (SK.guildName or "none"),
		"  Sync: " .. (paused and (C("ember") .. "paused (" .. why .. ")|r") or (C("good") .. "running|r")),
		"  Sending: " .. (canSend and "allowed" or (C("bad") .. "not allowed (" .. tostring(sendWhy) .. ")|r")),
		string.format("  Messages: %d sent, %d received, %d accepted, %d rejected, %d queued",
			st.sent, st.received, st.accepted, st.rejected, #SK.Sync.queue),
	}
	if own then
		local missing = SK.Professions.Unscanned(own)
		lines[#lines + 1] = "  Your data updated " .. SK.Theme.Ago(own.updated) .. " ago"
		if #missing > 0 then
			lines[#lines + 1] = "  " .. C("flame") .. "Open these profession windows once: " .. table.concat(missing, ", ") .. "|r"
		end
	end
	self.status:SetText(table.concat(lines, "\n"))
end

SK.MainFrame:AddTab("settings", "Settings", Settings)
