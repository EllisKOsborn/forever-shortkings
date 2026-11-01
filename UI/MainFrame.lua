-- The main window: title bar, tabs, content area. Built lazily the first
-- time it is opened, so nothing is created at login.
local _, SK = ...

local Main = SK:NewModule("MainFrame")
local Theme, W = SK.Theme, SK.Widgets

Main.tabs = {}        -- ordered { key, title, module }
Main.FRAME_NAME = "ShortKingsMainFrame"

-- Tab modules call this at load time. module:Build(content) once,
-- module:Refresh() whenever data changes while the tab is visible.
function Main:AddTab(key, title, module)
	self.tabs[#self.tabs + 1] = { key = key, title = title, module = module }
end

local function savePosition(f)
	local point, _, relPoint, x, y = f:GetPoint(1)
	local w = SK.DB.settings.window
	w.point, w.relPoint, w.x, w.y = point, relPoint, x, y
end

function Main:Build()
	if self.frame then return self.frame end
	local s = SK.DB.settings.window
	local f = CreateFrame("Frame", self.FRAME_NAME, UIParent)
	f:SetSize(860, 560)
	f:SetPoint(s.point or "CENTER", UIParent, s.relPoint or s.point or "CENTER", s.x or 0, s.y or 0)
	f:SetScale(s.scale or 1)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:Hide()
	Theme.Panel(f, { thickness = 3 })
	tinsert(UISpecialFrames, self.FRAME_NAME) -- ESC closes it

	-- Title bar (drag handle)
	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("TOPLEFT", 3, -3)
	bar:SetPoint("TOPRIGHT", -3, -3)
	bar:SetHeight(54)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() f:StartMoving() end)
	bar:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
	local barBg = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
	barBg:SetAllPoints()
	Theme.Gradient(barBg, "HORIZONTAL", "magenta", "plum", 0.55, 0.05)
	local glow = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
	glow:SetPoint("BOTTOMLEFT")
	glow:SetPoint("BOTTOMRIGHT")
	glow:SetHeight(2)
	Theme.Gradient(glow, "HORIZONTAL", "ember", "flame", 1, 0.2)
	f.titleBar = bar

	local title = Theme.Text(bar, 22, "pink")
	title:SetPoint("TOPLEFT", 16, -8)
	title:SetText("Short Kings")
	local tagline = Theme.Text(bar, 11, "flame")
	tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -2)
	tagline:SetText("Small in stature. Big in loot.")
	f.status = Theme.Text(bar, 11, "muted")
	f.status:SetPoint("RIGHT", -40, 0)

	local close = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 0, 0)
	close:SetScript("OnClick", function() f:Hide() end)

	-- Tabs
	f.tabButtons = {}
	local prev
	for i, tab in ipairs(self.tabs) do
		local b = W.Tab(f, tab.title, function() Main:Select(tab.key) end)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 12, -62) end
		f.tabButtons[i] = b
		prev = b
	end

	-- Content area
	local content = CreateFrame("Frame", nil, f)
	content:SetPoint("TOPLEFT", 12, -96)
	content:SetPoint("BOTTOMRIGHT", -12, 12)
	f.content = content
	for _, tab in ipairs(self.tabs) do
		local page = CreateFrame("Frame", nil, content)
		page:SetAllPoints()
		page:Hide()
		tab.page = page
	end

	f:SetScript("OnShow", function() Main:Refresh() end)
	self.frame = f

	local function changed() if f:IsShown() then SK:Debounce("ui", 0.5, function() Main:Refresh() end) end end
	SK:On("ROSTER_UPDATED", changed)
	SK:On("PROFILE_UPDATED", changed)
	SK:On("SELF_UPDATED", changed)
	return f
end

function Main:Select(key)
	self:Build()
	for i, tab in ipairs(self.tabs) do
		local active = tab.key == key
		if active and not tab.built then
			tab.module:Build(tab.page)
			tab.built = true
		end
		tab.page:SetShown(active)
		self.frame.tabButtons[i]:SetActive(active)
	end
	self.current = key
	SK.DB.settings.window.tab = key
	self:Refresh()
end

function Main:Refresh()
	if not self.frame or not self.frame:IsShown() then return end
	if not self.current then return self:Select(SK.DB.settings.window.tab or "roster") end
	for _, tab in ipairs(self.tabs) do
		if tab.key == self.current and tab.built and tab.module.Refresh then tab.module:Refresh() end
	end
	local paused, why = SK.Sync:IsPaused()
	local guild = SK.guildName or "no guild"
	self.frame.status:SetText(guild .. "  ·  " .. (paused and ("sync paused: " .. why) or "sync on"))
end

function Main:Toggle()
	local f = self:Build()
	f:SetShown(not f:IsShown())
end

function Main:Show(key)
	self:Build():Show()
	if key then self:Select(key) end
end

function Main:SetScale(scale)
	SK.DB.settings.window.scale = scale
	if self.frame then self.frame:SetScale(scale) end
end

function Main:ResetPosition()
	local w = SK.DB.settings.window
	w.point, w.relPoint, w.x, w.y = "CENTER", "CENTER", 0, 0
	if self.frame then
		self.frame:ClearAllPoints()
		self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end
