-- Settings tab: sharing and sync, display options (including Reduce
-- motion), window size, maintenance buttons, and a live status read-out
-- with a preview of exactly what guildmates see.
local _, SK = ...

local Settings = SK:NewModule("SettingsTab")
local Theme, W = SK.Theme, SK.Widgets
local S, SP = Theme.SIZES, Theme.SPACE

local SCALES = { 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3 }
Settings.LEFT_W = 380
Settings.RIGHT_W = S.window[1] - 2 * SP.l - Settings.LEFT_W - SP.xxl - SP.m

function Settings:Build(page)
	local s = SK.DB.settings
	self.checks = {}
	local y = 0
	local function heading(text)
		local b = W.Block(page, Settings.LEFT_W, text)
		b:SetRows({})
		b:SetPoint("TOPLEFT", 0, -y)
		y = y + b.headH
	end
	local function check(label, get, set, tip)
		local c = W.Check(page, label, get, set)
		c:SetPoint("TOPLEFT", 0, -y - SP.xs)
		c.tooltip = tip
		self.checks[#self.checks + 1] = c
		y = y + S.check + SP.m
		return c
	end

	heading("Sharing")
	check("Share and receive guild data (sync)", function() return s.sync end, function(v)
		s.sync = v
		SK:Print(v and "Sync turned on." or "Sync turned off. Nothing will be sent or received.")
		SK.MainFrame:Refresh()
	end)
	check("Share my gear and talents", function() return s.share.gear end, function(v)
		s.share.gear = v
		SK.Profile:BuildSelf()
		SK:Print(v and "Your gear and talents will be shared." or "Your gear and talents are now private.")
	end)
	check("Share my recipes and cooldowns", function() return s.share.recipes end, function(v)
		s.share.recipes = v
		SK.Profile:BuildSelf()
		SK:Print(v and "Your recipes will be shared." or "Your recipes are now private.")
	end)

	y = y + SP.s
	heading("Display")
	check("Show guild crafters in item tooltips", function() return s.craftTooltips end, function(v)
		s.craftTooltips = v
	end)
	check("Record guild milestones (Overview)", function() return s.feed end, function(v)
		s.feed = v
	end)
	check("Show minimap button", function() return not s.minimap.hide end, function(v)
		SK.Minimap:SetShown(v)
	end)
	check("Reduce motion", function() return s.reduceMotion end, function(v)
		s.reduceMotion = v
	end, "Turns off the window, tab and sync animations.")
	check("Debug logging in chat", function() return s.debug end, function(v) s.debug = v end)

	-- Window size: a label, then a row of chips under it (seven chips are
	-- too wide to share a line with the label in this column).
	local scaleLabel = Theme.Text(page, "body", "text")
	scaleLabel:SetPoint("TOPLEFT", 0, -y - SP.xs)
	scaleLabel:SetText("Window size")
	y = y + S.specRow + SP.xs
	self.scaleButtons = {}
	local prev
	for _, v in ipairs(SCALES) do
		local b = W.Chip(page, string.format("%d%%", v * 100), function()
			SK.MainFrame:SetScale(v)
			Settings:Refresh()
		end)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", SP.xs, 0) else b:SetPoint("TOPLEFT", 0, -y) end
		b.value = v
		self.scaleButtons[#self.scaleButtons + 1] = b
		prev = b
	end
	y = y + S.control + SP.m

	-- Actions, two per row
	heading("Tools")
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
	local bw = (Settings.LEFT_W - SP.s) / 2
	for i, a in ipairs(actions) do
		local b = W.Button(page, a[1], bw, S.control, a[3])
		b.tooltip = a[2]
		b:SetPoint("TOPLEFT", ((i - 1) % 2) * (bw + SP.s), -y - math.floor((i - 1) / 2) * (S.control + SP.s))
	end

	-- Status and sharing preview (scrolls)
	self.status = W.Sheet(page, Settings.RIGHT_W)
	self.status:SetPoint("TOPLEFT", Settings.LEFT_W + SP.xxl, 0)
	self.status:SetPoint("BOTTOM", 0, 0)
	self.status:SetWidth(Settings.RIGHT_W)
end

-- Status sections. Pure apart from reading SK state; tested.
function Settings.StatusSections()
	local paused, why = SK.Sync:IsPaused()
	local canSend, sendWhy = SK.Sync:CanSend()
	local st = SK.Sync.stats
	local own = SK.Profile:Own()
	local status = {
		{ label = "Version", value = SK.VERSION },
		{ label = "Guild", value = SK.guildName or "none" },
		{ label = "Sync", value = paused and ("paused (" .. why .. ")") or "running", tone = paused and "dim" or "good" },
		{ label = "Sending", value = canSend and "allowed" or ("not allowed (" .. tostring(sendWhy) .. ")"),
			tone = canSend and "text" or "bad" },
		{ label = "Messages sent / received", value = st.sent .. " / " .. st.received },
		{ label = "Accepted / rejected / queued", value = st.accepted .. " / " .. st.rejected .. " / " .. #SK.Sync.queue },
	}
	if #SK.errors > 0 then
		status[#status + 1] = { label = "Lua errors caught", value = tostring(#SK.errors), tone = "spark" }
	end
	if own then
		status[#status + 1] = { label = "Your data updated", value = SK.Theme.Ago(own.updated) .. " ago" }
		local missing = SK.Professions.Unscanned(own)
		if #missing > 0 then
			status[#status + 1] = { text = "Open these profession windows once: " .. table.concat(missing, ", "), tone = "spark" }
		end
	end
	-- Sharing preview (read-only): exactly what the public copy contains.
	local share = {}
	if own then
		for _, c in ipairs(SK.Profile.SharingSummary(own, SK.DB.settings.share)) do
			share[#share + 1] = { label = c.label, labelTone = "text", value = c.shared and "shared" or "private",
				tone = c.shared and "good" or "dim" }
		end
		local pub = SK.DBM:Guild() and SK.DBM:Guild().profiles[own.guid]
		if pub then share[#share + 1] = { label = "Last shared copy", value = SK.Theme.Ago(pub.updated) .. " ago" } end
	else
		share[#share + 1] = { text = "Nothing yet: your profile is built once the guild roster loads." }
	end
	share[#share + 1] = { text = "Never shared: " .. SK.Profile.NEVER_SHARED }
	if not SK.DB.settings.sync then
		share[#share + 1] = { text = "Sync is off, so nothing is being sent right now.", tone = "spark" }
	end
	share[#share + 1] = { text = "Turning sharing off stops future updates. Copies guildmates already have"
		.. " stay until they're replaced." }
	return {
		{ title = "Status", rows = status },
		{ title = "What guildmates see from you", rows = share },
	}
end

function Settings:Refresh()
	if not self.checks then return end
	for _, c in ipairs(self.checks) do c:Refresh() end
	local scale = SK.DB.settings.window.scale or 1
	for _, b in ipairs(self.scaleButtons) do b:SetActive(math.abs(b.value - scale) < 0.01) end
	self.sections = Settings.StatusSections()
	self.status:SetSections(self.sections)
end

SK.MainFrame:AddTab("settings", "Settings", Settings)
