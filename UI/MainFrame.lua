-- The main window (docs/DESIGN.md sections 3–6): a 64 px rail on the left,
-- the header band (wordmark, fuse and sparks, close), a toolbar band with
-- the page title and that tab's tools, the content box and a status line.
-- Built lazily the first time it is opened, so nothing is created at login.
local _, SK = ...

local Main = SK:NewModule("MainFrame")
local Theme, W = SK.Theme, SK.Widgets

Main.tabs = {}        -- ordered { key, title, module, icon }
Main.FRAME_NAME = "ShortKingsMainFrame"
Main.WIDTH, Main.HEIGHT = 936, 600
Main.RAIL, Main.BAND, Main.TOOLBAR, Main.STATUS = 64, 64, 48, 28

-- Tab modules call this at load time. module:Build(page, tools) once,
-- module:Refresh() whenever data changes while the tab is visible.
-- `tools` sits in the toolbar band, right of the page title.
function Main:AddTab(key, title, module, icon)
	self.tabs[#self.tabs + 1] = { key = key, title = title, module = module, icon = icon or key }
end

local function savePosition(f)
	local point, _, relPoint, x, y = f:GetPoint(1)
	local w = SK.DB.settings.window
	w.point, w.relPoint, w.x, w.y = point, relPoint, x, y
end

-- Header band: sky -> bg, a brand wash from the left, the fuse along the
-- bottom edge and three sparks at its lit tip.
local function buildBand(f)
	local band = CreateFrame("Frame", nil, f)
	band:SetPoint("TOPLEFT", Main.RAIL, 0)
	band:SetPoint("TOPRIGHT")
	band:SetHeight(Main.BAND)
	band:EnableMouse(true)
	band:RegisterForDrag("LeftButton")
	band:SetScript("OnDragStart", function() f:StartMoving() end)
	band:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
	local sky = band:CreateTexture(nil, "BACKGROUND", nil, 1)
	sky:SetAllPoints()
	Theme.Gradient(sky, "VERTICAL", "bg", "sky")
	local glow = band:CreateTexture(nil, "BACKGROUND", nil, 2)
	glow:SetPoint("TOPLEFT")
	glow:SetPoint("BOTTOMLEFT")
	glow:SetWidth((Main.WIDTH - Main.RAIL) * 0.6)
	Theme.Gradient(glow, "HORIZONTAL", "brand", "brand", 0.22, 0)

	local title = Theme.Text(band, "display", "text")
	title:SetPoint("TOPLEFT", 24, -13)
	title:SetText("Short Kings")
	local tagline = Theme.Text(band, "small", "textDim")
	tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -2)
	tagline:SetText("Small in stature. Big in loot.")

	-- The fuse: transparent ember to a warning-yellow tip at 46% width.
	local fuseW = math.floor((Main.WIDTH - Main.RAIL) * 0.46)
	local fuse = band:CreateTexture(nil, "ARTWORK")
	fuse:SetPoint("BOTTOMLEFT")
	fuse:SetSize(fuseW, 1)
	SK.Compat.PixelHeight(fuse, 1)
	Theme.Gradient(fuse, "HORIZONTAL", "ember", "warning", 0, 0.9)

	-- Sparks: a warning core and a faint ember glow, flickering on alpha loops.
	band.sparks = {}
	local SPARKS = { { 0, 1, 3, 1.1 }, { 6, 8, 2, 0.9 }, { -7, 11, 2, 1.6 } } -- x, y above the line, size, seconds
	for i, s in ipairs(SPARKS) do
		local holder = CreateFrame("Frame", nil, band)
		holder:SetSize(s[3] + 6, s[3] + 6)
		holder:SetPoint("CENTER", band, "BOTTOMLEFT", fuseW + s[1], s[2])
		local halo = holder:CreateTexture(nil, "ARTWORK", nil, 1)
		halo:SetAllPoints()
		Theme.Solid(halo, "ember", 0.25)
		local core = holder:CreateTexture(nil, "ARTWORK", nil, 2)
		core:SetSize(s[3], s[3])
		core:SetPoint("CENTER")
		Theme.Solid(core, "warning")
		local ag = holder:CreateAnimationGroup()
		ag:SetLooping("BOUNCE")
		local a = ag:CreateAnimation("Alpha")
		a:SetFromAlpha(1)
		a:SetToAlpha(0.25)
		a:SetDuration(s[4])
		a:SetStartDelay(i * 0.15)
		holder.anim = ag
		band.sparks[i] = holder
	end

	local close = W.IconButton(band, "close", 24, function() f:Hide() end, "Close (Esc)")
	close:SetPoint("TOPRIGHT", -12, -12)
	f.close = close
	return band
end

-- Sparks flicker only while the window is shown and Reduce motion is off.
function Main:UpdateMotion()
	local f = self.frame
	if not f then return end
	local animate = f:IsShown() and not Theme.ReduceMotion()
	for _, s in ipairs(f.band.sparks) do
		if animate then s.anim:Play() else s.anim:Stop(); s:SetAlpha(1) end
	end
end

local function buildRail(f)
	local rail = CreateFrame("Frame", nil, f)
	rail:SetPoint("TOPLEFT")
	rail:SetPoint("BOTTOMLEFT")
	rail:SetWidth(Main.RAIL)
	local bg = rail:CreateTexture(nil, "BACKGROUND", nil, 1)
	bg:SetAllPoints()
	Theme.Solid(bg, "sidebar")
	Theme.Edge(rail, "RIGHT")
	local emblem = rail:CreateTexture(nil, "ARTWORK")
	emblem:SetSize(36, 36)
	emblem:SetPoint("TOPLEFT", 14, -14)
	emblem:SetTexture(Theme.EMBLEM)
	emblem:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	f.railButtons = {}
	for i, tab in ipairs(Main.tabs) do
		local b = W.RailItem(rail, tab.icon, tab.title, function() Main:Select(tab.key) end)
		b:SetPoint("TOPLEFT", 4, -76 - (i - 1) * 60)
		f.railButtons[i] = b
	end
	return rail
end

function Main:Build()
	if self.frame then return self.frame end
	local s = SK.DB.settings.window
	local f = CreateFrame("Frame", self.FRAME_NAME, UIParent)
	f:SetSize(self.WIDTH, self.HEIGHT)
	f:SetPoint(s.point or "CENTER", UIParent, s.relPoint or s.point or "CENTER", s.x or 0, s.y or 0)
	f:SetScale(s.scale or 1)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:Hide()
	Theme.Shadow(f)
	Theme.Panel(f, { tone = "bg" })
	tinsert(UISpecialFrames, self.FRAME_NAME) -- ESC closes it

	f.band = buildBand(f)
	f.titleBar = f.band
	f.rail = buildRail(f)

	-- Toolbar band: page title + the current tab's tools.
	local toolbar = CreateFrame("Frame", nil, f)
	toolbar:SetPoint("TOPLEFT", self.RAIL, -self.BAND)
	toolbar:SetPoint("TOPRIGHT", 0, -self.BAND)
	toolbar:SetHeight(self.TOOLBAR)
	local tbg = toolbar:CreateTexture(nil, "BACKGROUND", nil, 1)
	tbg:SetAllPoints()
	Theme.Solid(tbg, "panel")
	Theme.Edge(toolbar, "BOTTOM")
	f.pageTitle = Theme.Text(toolbar, "title", "text")
	f.pageTitle:SetPoint("LEFT", 24, 0)
	f.toolbar = toolbar

	-- Status line: this tab's summary on the left, sync state on the right.
	local status = CreateFrame("Frame", nil, f)
	status:SetPoint("BOTTOMLEFT", self.RAIL, 0)
	status:SetPoint("BOTTOMRIGHT")
	status:SetHeight(self.STATUS)
	local sbg = status:CreateTexture(nil, "BACKGROUND", nil, 1)
	sbg:SetAllPoints()
	Theme.Solid(sbg, "sidebar")
	Theme.Edge(status, "TOP")
	f.statusLeft = Theme.Text(status, "small", "textDim")
	f.statusLeft:SetPoint("LEFT", 24, 0)
	f.statusLeft:SetJustifyH("LEFT")
	f.statusLeft:SetWordWrap(false)
	f.status = Theme.Text(status, "small", "textDim")
	f.status:SetPoint("RIGHT", -24, 0)
	f.statusLeft:SetPoint("RIGHT", f.status, "LEFT", -16, 0)

	-- Content box: x 88-912, y 128-556 (824 x 428).
	local content = CreateFrame("Frame", nil, f)
	content:SetPoint("TOPLEFT", self.RAIL + 24, -(self.BAND + self.TOOLBAR + 16))
	content:SetPoint("BOTTOMRIGHT", -24, self.STATUS + 16)
	f.content = content
	for _, tab in ipairs(self.tabs) do
		local page = CreateFrame("Frame", nil, content)
		page:SetAllPoints()
		page:Hide()
		tab.page = page
		local tools = CreateFrame("Frame", nil, toolbar)
		tools:SetPoint("LEFT", f.pageTitle, "RIGHT", 24, 0)
		tools:SetPoint("RIGHT", -24, 0)
		tools:SetHeight(28)
		tools:Hide()
		tab.tools = tools
	end

	f:SetScript("OnShow", function()
		Theme.FadeIn(f)
		Main:UpdateMotion()
		Main:Refresh()
	end)
	f:SetScript("OnHide", function() Main:UpdateMotion() end)
	self.frame = f

	local function changed() if f:IsShown() then SK:Debounce("ui", 0.5, function() Main:Refresh() end) end end
	SK:On("ROSTER_UPDATED", changed)
	SK:On("PROFILE_UPDATED", changed)
	SK:On("SELF_UPDATED", changed)
	SK:On("MOTION_CHANGED", function() Main:UpdateMotion() end)
	return f
end

function Main:Select(key)
	self:Build()
	for i, tab in ipairs(self.tabs) do
		local active = tab.key == key
		if active and not tab.built then
			tab.module:Build(tab.page, tab.tools)
			tab.built = true
		end
		tab.page:SetShown(active)
		tab.tools:SetShown(active)
		self.frame.railButtons[i]:SetActive(active)
		if active then
			self.frame.pageTitle:SetText(tab.title)
			self.frame.statusLeft:SetText(tab.status or "")
			if self.current ~= key then Theme.FadeIn(tab.page) end
		end
	end
	self.current = key
	SK.DB.settings.window.tab = key
	self:Refresh()
end

-- A tab's one-line summary for the status line (shown while it's open).
function Main:SetStatus(key, text)
	for _, tab in ipairs(self.tabs) do
		if tab.key == key then tab.status = text end
	end
	if self.frame and self.current == key then self.frame.statusLeft:SetText(text or "") end
end

function Main:Refresh()
	if not self.frame or not self.frame:IsShown() then return end
	if not self.current then
		-- v0.2.2: open on the new Overview once, then remember the last tab again.
		if not SK.DB.settings.overviewShown then
			SK.DB.settings.overviewShown = true
			return self:Select("overview")
		end
		return self:Select(SK.DB.settings.window.tab or "overview")
	end
	for _, tab in ipairs(self.tabs) do
		if tab.key == self.current and tab.built and tab.module.Refresh then tab.module:Refresh() end
	end
	self.frame.status:SetText(Main.SyncText())
end

-- "■ Short Kings · sync on" (shape + words; never colour alone).
function Main.SyncText()
	local paused, why = SK.Sync:IsPaused()
	local guild = SK.guildName or "no guild"
	return (paused and Theme.StatusMark("offline") or Theme.StatusMark("addon")) .. "  " .. guild .. "  ·  "
		.. (paused and ("sync paused: " .. why) or "sync on")
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
	Theme.RefreshPixels()
end

function Main:ResetPosition()
	local w = SK.DB.settings.window
	w.point, w.relPoint, w.x, w.y = "CENTER", "CENTER", 0, 0
	if self.frame then
		self.frame:ClearAllPoints()
		self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end
