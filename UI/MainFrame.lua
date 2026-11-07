-- The main window: title bar (crest, name, sync status, close), tabs with
-- a gliding gold underline, and the content area. Built lazily the first
-- time it is opened, so nothing is created at login.
local _, SK = ...

local Main = SK:NewModule("MainFrame")
local Theme, W, Motion = SK.Theme, SK.Widgets, SK.Motion
local S, SP, M = Theme.SIZES, Theme.SPACE, Theme.MOTION

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

-- The chosen window size, shrunk if it wouldn't fit on screen (big UI
-- scale on a small display). Pure; tested.
function Main.FitScale(chosen, screenW, screenH)
	local ww, wh = S.window[1], S.window[2]
	local fit = 1e9
	if screenW and screenW > 0 then fit = math.min(fit, screenW * 0.96 / ww) end
	if screenH and screenH > 0 then fit = math.min(fit, screenH * 0.94 / wh) end
	return math.max(0.5, math.min(chosen or 1, fit))
end

function Main:ApplyScale()
	if not self.frame then return end
	local chosen = SK.DB.settings.window.scale or 1
	self.frame:SetScale(Main.FitScale(chosen, UIParent:GetWidth(), UIParent:GetHeight()))
end

function Main:Build()
	if self.frame then return self.frame end
	local s = SK.DB.settings.window
	local f = CreateFrame("Frame", self.FRAME_NAME, UIParent)
	f:SetSize(S.window[1], S.window[2])
	f:SetPoint(s.point or "CENTER", UIParent, s.relPoint or s.point or "CENTER", s.x or 0, s.y or 0)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:Hide()
	Theme.Panel(f, { bg = "void", border = "line" })
	tinsert(UISpecialFrames, self.FRAME_NAME) -- Esc closes it (instantly)
	self.frame = f
	self:ApplyScale()

	-- Title bar (drag handle)
	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("TOPLEFT", 1, -1)
	bar:SetPoint("TOPRIGHT", -1, -1)
	bar:SetHeight(S.titleBar)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() f:StartMoving() end)
	bar:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
	f.titleBar = bar

	local crest = bar:CreateTexture(nil, "ARTWORK")
	crest:SetSize(S.crest, S.crest)
	crest:SetPoint("LEFT", SP.l - 1, 0)
	crest:SetTexture(Theme.TEX.crest)
	f.crest = crest
	local title = Theme.Text(bar, "brand", "text")
	title:SetPoint("TOPLEFT", crest, "TOPRIGHT", SP.m, 2)
	title:SetText("SHORT KINGS")
	local tagline = Theme.Text(bar, "small", "dim")
	tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -1)
	tagline:SetText(SK.TAGLINE)

	local close = W.CloseButton(bar, function() Main:Close() end)
	close:SetPoint("RIGHT", -SP.m, 0)
	f.close = close

	-- Sync status: a spark dot (the lit fuse) + words. Grey dot when paused.
	local status = CreateFrame("Frame", nil, bar)
	status:SetPoint("RIGHT", close, "LEFT", -SP.m, 0)
	status:SetSize(260, S.control)
	status:EnableMouse(true)
	f.status = Theme.Text(status, "small", "dim")
	f.status:SetPoint("RIGHT")
	f.status:SetJustifyH("RIGHT")
	f.status:SetWordWrap(false)
	f.status:SetWidth(240)
	local dot = status:CreateTexture(nil, "ARTWORK")
	dot:SetSize(8, 8)
	dot:SetTexture(Theme.TEX.dot)
	f.dot = dot
	local ring = status:CreateTexture(nil, "OVERLAY")
	ring:SetSize(16, 16)
	ring:SetPoint("CENTER", dot, "CENTER")
	ring:SetTexture(Theme.TEX.ring)
	ring:SetVertexColor(Theme.RGB("spark"))
	ring:SetAlpha(0)
	f.ring = ring
	status:SetScript("OnEnter", function() Main:StatusTooltip(status) end)
	status:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.statusFrame = status

	-- Tabs
	local tabBar = CreateFrame("Frame", nil, f)
	tabBar:SetPoint("TOPLEFT", 1, -1 - S.titleBar)
	tabBar:SetPoint("TOPRIGHT", -1, -1 - S.titleBar)
	tabBar:SetHeight(S.tabBar)
	local tabRule = Theme.Rule(tabBar, "line")
	tabRule:SetPoint("BOTTOMLEFT")
	tabRule:SetPoint("BOTTOMRIGHT")
	f.tabButtons = {}
	local prev
	for i, tab in ipairs(self.tabs) do
		local b = W.Tab(tabBar, tab.title, function() Main:Select(tab.key) end)
		-- Tabs carry SP.l padding, so the first label lines up with the content.
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 0, 0) else b:SetPoint("LEFT", 0, 0) end
		f.tabButtons[i] = b
		prev = b
	end
	-- One underline, moved between tabs.
	local underline = tabBar:CreateTexture(nil, "OVERLAY")
	underline:SetHeight(S.underline)
	Theme.Solid(underline, "gold")
	underline:Hide()
	f.underline = underline

	-- Content area
	local content = CreateFrame("Frame", nil, f)
	content:SetPoint("TOPLEFT", SP.l, -(S.titleBar + S.tabBar + SP.l))
	content:SetPoint("BOTTOMRIGHT", -SP.l, SP.l)
	f.content = content
	for _, tab in ipairs(self.tabs) do
		local page = CreateFrame("Frame", nil, content)
		page:SetAllPoints()
		page:Hide()
		tab.page = page
	end

	f:SetScript("OnShow", function() Main:Refresh() end)
	f:SetScript("OnHide", function() f:SetAlpha(1) end)

	local function changed() if f:IsShown() then SK:Debounce("ui", 0.5, function() Main:Refresh() end) end end
	SK:On("ROSTER_UPDATED", changed)
	SK:On("SELF_UPDATED", changed)
	SK:On("PROFILE_UPDATED", function()
		changed()
		Motion.Pulse(ring, SK.Compat.Now())
	end)
	SK:RegisterEvent("UI_SCALE_CHANGED", function() Main:ApplyScale() end)
	SK:RegisterEvent("DISPLAY_SIZE_CHANGED", function() Main:ApplyScale() end)
	return f
end

-- Move the underline under the active tab (gliding from the old one).
function Main:PlaceUnderline(button)
	local u = self.frame.underline
	local oldLeft, oldWidth = u:IsShown() and u:GetLeft(), u:GetWidth()
	u:ClearAllPoints()
	u:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", SP.l, 0)
	u:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -SP.l, 0)
	u:Show()
	local newLeft, newWidth = button:GetLeft(), button:GetWidth() - SP.l * 2
	if oldLeft and newLeft and newWidth and newWidth > 0 and oldWidth and oldWidth > 0 then
		Motion.Glide(u, oldLeft - (newLeft + SP.l), oldWidth / newWidth, M.slide)
	end
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
		if active then
			self:PlaceUnderline(self.frame.tabButtons[i])
		end
	end
	self.current = key
	SK.DB.settings.window.tab = key
	SK.Onboarding.Seen(key)
	self:Refresh()
end

-- Words for the title-bar status. Pure; tested.
function Main.StatusText(guildName, paused, why, errors)
	local text
	if paused then text = "Sync paused: " .. why else text = "Sync on" end
	text = (guildName or "No guild") .. "  ·  " .. text
	if errors and errors > 0 then
		text = text .. "  ·  " .. Theme.Paint("spark", errors .. (errors == 1 and " error" or " errors"))
	end
	return text
end

function Main:StatusTooltip(owner)
	local paused, why = SK.Sync:IsPaused()
	GameTooltip:SetOwner(owner, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:AddLine(paused and ("Sync paused: " .. why) or "Sync on", Theme.RGB(paused and "dim" or "spark"))
	GameTooltip:AddLine(paused and "Your guildmates' data stays as it was. It starts again on its own."
		or "Changes reach guildmates in about a minute. The dot flashes when new data arrives.", Theme.RGB("text"))
	if #SK.errors > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(#SK.errors .. " Lua error(s) caught. Type /sk debug and send the text to the addon author.",
			Theme.RGB("spark"))
	end
	GameTooltip:Show()
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
	local paused, why = SK.Sync:IsPaused()
	local f = self.frame
	f.status:SetText(Main.StatusText(SK.guildName, paused, why, #SK.errors))
	f.dot:ClearAllPoints()
	-- (a cut-off status still reports its full width: keep the dot inside)
	local w = math.min(f.status:GetStringWidth() or 0, f.status:GetWidth() or 0)
	f.dot:SetPoint("RIGHT", f.status, "RIGHT", -w - SP.s, 0)
	f.dot:SetVertexColor(Theme.RGB(paused and "faint" or "spark"))
end

-- instant = true when opened from the keyboard (/sk): no animation.
function Main:Open(key, instant)
	local f = self:Build()
	if not f:IsShown() or Motion.IsLeaving(f) then
		Motion.In(f, M.open, M.openScale, "CENTER", instant)
	end
	if key then self:Select(key) end
end

function Main:Close(instant)
	if not self.frame then return end
	Motion.Out(self.frame, M.close, instant)
end

function Main:Toggle(instant)
	local f = self:Build()
	if f:IsShown() then self:Close(instant) else self:Open(nil, instant) end
end

function Main:Show(key)
	self:Open(key)
end

function Main:SetScale(scale)
	SK.DB.settings.window.scale = scale
	self:ApplyScale()
end

function Main:ResetPosition()
	local w = SK.DB.settings.window
	w.point, w.relPoint, w.x, w.y = "CENTER", "CENTER", 0, 0
	if self.frame then
		self.frame:ClearAllPoints()
		self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end
