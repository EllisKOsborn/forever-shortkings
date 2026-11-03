-- Widgets: buttons, tabs, chips, check boxes, a menu, a search box, a
-- virtual (recycling) list with sortable columns, a scrollable text panel,
-- and "blocks" (a section heading with key/value rows). Only core widget
-- types are used (Frame, Button, Slider, EditBox, ScrollFrame,
-- CheckButton) and no Blizzard templates. Every colour, size and font comes
-- from UI/Theme.lua.
local _, SK = ...

local W = {}
SK.Widgets = W
local Theme, Motion = SK.Theme, SK.Motion
local S, SP = Theme.SIZES, Theme.SPACE

-- Small controls keep a comfortable click area: widen the hit box to at
-- least SIZES.minHit without changing how they look.
local function padHit(frame, w, h)
	local dy = math.max(0, (S.minHit - (h or 0)) / 2)
	local dx = math.max(0, (S.minHit - (w or S.minHit)) / 2)
	if (dx > 0 or dy > 0) and frame.SetHitRectInsets then frame:SetHitRectInsets(-dx, -dx, -dy, -dy) end
end
W.padHit = padHit

local function tooltipFor(self)
	local tip = self.disabled and self.disabledTooltip or (not self.disabled and self.tooltip)
	if tip then
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(tip, Theme.RGB("text"))
		GameTooltip:Show()
	end
end

---------------------------------------------------------------------------
-- Button. kind = "ghost" (default: outline), "primary" (gold, one per
-- screen at most) or "quiet" (text only, for "Open roster"-style links).
---------------------------------------------------------------------------
local BUTTON_LOOK = {
	--             bg rest,  bg hover, bg press,   border rest,  border hover, label,    label hover
	ghost   = { nil,       "raised",  "pressed",  "lineStrong", "dim",        "text",   "text" },
	primary = { "gold",    "goldLit", "goldDeep", nil,          nil,          "onGold", "onGold" },
	quiet   = { nil,       nil,       nil,        nil,          nil,          "dim",    "gold" },
}

function W.Button(parent, text, width, height, onClick, kind)
	kind = kind or "ghost"
	local look = BUTTON_LOOK[kind]
	local b = CreateFrame("Button", nil, parent)
	b.kind, b.disabled, b.active, b.hover = kind, false, false, false
	height = height or S.control
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	if look[4] then Theme.Border(b, look[4]) end
	b.label = Theme.Text(b, kind == "quiet" and "small" or "body", look[6])
	b.label:SetPoint("CENTER")
	b.label:SetJustifyH("CENTER")
	b.label:SetWordWrap(false)
	b.label:SetText(text)
	b:SetSize(width or math.max(S.minHit * 2, (b.label:GetStringWidth() or 0) + SP.l * 2), height)
	padHit(b, width, height)

	function b:Paint(state) -- "rest" | "hover" | "press"
		if self.disabled then
			if look[1] then Theme.Solid(self.bg, "raised") else self.bg:SetColorTexture(0, 0, 0, 0) end
			Theme.SetBorderColor(self, "line")
			self.label:SetTextColor(Theme.RGB("faint"))
			return
		end
		local bg = (state == "press" and look[3]) or (state == "hover" and look[2]) or look[1]
		if bg then Theme.Solid(self.bg, bg) else self.bg:SetColorTexture(0, 0, 0, 0) end
		if look[4] then Theme.SetBorderColor(self, (state ~= "rest" or self.active) and look[5] or look[4]) end
		self.label:SetTextColor(Theme.RGB((state ~= "rest" or self.active) and look[7] or look[6]))
	end
	b:SetScript("OnEnter", function(self)
		self.hover = true
		self:Paint("hover")
		tooltipFor(self)
	end)
	b:SetScript("OnLeave", function(self)
		self.hover = false
		self:Paint("rest")
		GameTooltip:Hide()
	end)
	-- Press feedback is instant: darker fill and the label drops a pixel.
	b:SetScript("OnMouseDown", function(self)
		if self.disabled then return end
		self:Paint("press")
		self.label:SetPoint("CENTER", 0, -1)
	end)
	b:SetScript("OnMouseUp", function(self)
		self.label:SetPoint("CENTER", 0, 0)
		self:Paint(self.hover and "hover" or "rest")
	end)
	if onClick then b:SetScript("OnClick", function(self, ...) if not self.disabled then onClick(self, ...) end end) end
	function b:SetText(t) self.label:SetText(t) end
	function b:SetDisabled(flag)
		self.disabled = flag and true or false
		self:Paint(self.hover and "hover" or "rest")
	end
	b:Paint("rest")
	return b
end

-- Close (X) button: a drawn cross, dim until hovered.
function W.CloseButton(parent, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(S.control, S.control)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0)
	local x = b:CreateTexture(nil, "ARTWORK")
	x:SetSize(12, 12)
	x:SetPoint("CENTER")
	x:SetTexture(Theme.TEX.close)
	x:SetVertexColor(Theme.RGB("dim"))
	b:SetScript("OnEnter", function()
		Theme.Solid(bg, "raised")
		x:SetVertexColor(Theme.RGB("text"))
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText("Close (Esc)", Theme.RGB("text"))
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		bg:SetColorTexture(0, 0, 0, 0)
		x:SetVertexColor(Theme.RGB("dim"))
		GameTooltip:Hide()
	end)
	b:SetScript("OnMouseDown", function() Theme.Solid(bg, "pressed") end)
	b:SetScript("OnMouseUp", function() Theme.Solid(bg, "raised") end)
	b:SetScript("OnClick", onClick)
	return b
end

---------------------------------------------------------------------------
-- Tab: main navigation. Uppercase display type, dim until active; the
-- gold underline is one shared marker owned by MainFrame.
---------------------------------------------------------------------------
function W.Tab(parent, text, onClick)
	local t = CreateFrame("Button", nil, parent)
	t.label = Theme.Text(t, "tab", "dim")
	t.label:SetPoint("CENTER")
	t.label:SetText(text:upper())
	t:SetSize((t.label:GetStringWidth() or 0) + SP.l * 2, S.tabBar)
	t:SetScript("OnEnter", function(self) if not self.active then self.label:SetTextColor(Theme.RGB("text")) end end)
	t:SetScript("OnLeave", function(self) if not self.active then self.label:SetTextColor(Theme.RGB("dim")) end end)
	-- Feedback the moment the button goes down, not when it's released.
	t:SetScript("OnMouseDown", function(self) self.label:SetPoint("CENTER", 0, -1) end)
	t:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
	t:SetScript("OnClick", onClick)
	function t:SetActive(flag)
		self.active = flag
		self.label:SetTextColor(Theme.RGB(flag and "text" or "dim"))
	end
	return t
end

---------------------------------------------------------------------------
-- Chip: one of a small set of choices (filters, window size). The picked
-- chip is tinted with the beard colour.
---------------------------------------------------------------------------
function W.Chip(parent, text, onClick)
	local c = CreateFrame("Button", nil, parent)
	c.active, c.hover = false, false
	c.bg = c:CreateTexture(nil, "BACKGROUND")
	c.bg:SetAllPoints()
	Theme.Border(c, "line")
	c.label = Theme.Text(c, "small", "dim")
	c.label:SetPoint("CENTER")
	c.label:SetText(text)
	c:SetSize((c.label:GetStringWidth() or 0) + SP.m * 2, S.controlSmall + 2)
	padHit(c, nil, S.controlSmall + 2)
	function c:Paint()
		if self.active then
			Theme.Solid(self.bg, "beard", Theme.ALPHA.selected)
			Theme.SetBorderColor(self, "beard")
			self.label:SetTextColor(Theme.RGB("text"))
		else
			self.bg:SetColorTexture(Theme.RGBA("raised", self.hover and 1 or 0))
			Theme.SetBorderColor(self, self.hover and "lineStrong" or "line")
			self.label:SetTextColor(Theme.RGB(self.hover and "text" or "dim"))
		end
	end
	c:SetScript("OnEnter", function(self) self.hover = true; self:Paint(); tooltipFor(self) end)
	c:SetScript("OnLeave", function(self) self.hover = false; self:Paint(); GameTooltip:Hide() end)
	c:SetScript("OnMouseDown", function(self) if not self.active then Theme.Solid(self.bg, "pressed") end end)
	c:SetScript("OnMouseUp", function(self) self:Paint() end)
	c:SetScript("OnClick", onClick)
	function c:SetActive(flag) self.active = flag; self:Paint() end
	c:Paint()
	return c
end

---------------------------------------------------------------------------
-- Check box with label. The whole label is clickable.
---------------------------------------------------------------------------
function W.Check(parent, label, getter, setter)
	local c = CreateFrame("CheckButton", nil, parent)
	c:SetSize(S.check, S.check)
	local box = c:CreateTexture(nil, "BACKGROUND")
	box:SetAllPoints()
	Theme.Solid(box, "surface")
	Theme.Border(c, "lineStrong")
	local tick = c:CreateTexture(nil, "ARTWORK")
	tick:SetPoint("TOPLEFT", 3, -3)
	tick:SetPoint("BOTTOMRIGHT", -3, 3)
	Theme.Solid(tick, "beard")
	c:SetCheckedTexture(tick)
	c.label = Theme.Text(c, "body", "text")
	c.label:SetPoint("LEFT", c, "RIGHT", SP.s, 0)
	c.label:SetWordWrap(false)
	function c:SetLabel(text)
		self.label:SetText(text)
		local w = (self.label:GetStringWidth() or 0) + SP.s
		if self.SetHitRectInsets then self:SetHitRectInsets(0, -w, -4, -4) end
	end
	c:SetLabel(label)
	c:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
	c:SetScript("OnEnter", function(self) Theme.SetBorderColor(self, "dim"); tooltipFor(self) end)
	c:SetScript("OnLeave", function(self) Theme.SetBorderColor(self, "lineStrong"); GameTooltip:Hide() end)
	function c:Refresh() self:SetChecked(getter() and true or false) end
	c:Refresh()
	return c
end

---------------------------------------------------------------------------
-- Menu: a button that opens a small pop-up list. opts = {
--   width = 150, items = function() return { {value=, text=}, ... } end,
--   get = function() return value end, set = function(value) end,
-- }
---------------------------------------------------------------------------
local openMenu

function W.Menu(parent, opts)
	local width = opts.width or 150
	local b = W.Button(parent, "", width, S.control)
	local arrow = b:CreateTexture(nil, "ARTWORK")
	arrow:SetSize(8, 8)
	arrow:SetPoint("RIGHT", -SP.s, 0)
	arrow:SetTexture(Theme.TEX.arrow)
	arrow:SetTexCoord(0, 1, 1, 0) -- point down
	arrow:SetVertexColor(Theme.RGB("dim"))
	b.label:ClearAllPoints()
	b.label:SetPoint("LEFT", SP.s, 0)
	b.label:SetPoint("RIGHT", -SP.l - SP.xs, 0)
	b.label:SetJustifyH("LEFT")

	local pop = CreateFrame("Frame", nil, b)
	pop:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -SP.xxs)
	pop:SetWidth(width)
	pop:SetFrameStrata("FULLSCREEN_DIALOG")
	pop:EnableMouse(true)
	Theme.Panel(pop, { bg = "surface", border = "lineStrong" })
	pop:Hide()
	pop.entries = {}
	b.pop = pop

	function b:Refresh()
		local current = opts.get()
		for _, it in ipairs(opts.items()) do
			if it.value == current then self:SetText(it.text) return end
		end
		self:SetText("")
	end

	function b:Close()
		pop:Hide()
		if openMenu == self then openMenu = nil end
	end

	function b:Open()
		if openMenu and openMenu ~= self then openMenu:Close() end
		local items = opts.items()
		local current = opts.get()
		local h = S.row
		for i, it in ipairs(items) do
			local e = pop.entries[i]
			if not e then
				e = CreateFrame("Button", nil, pop)
				e:SetHeight(h)
				e:SetPoint("TOPLEFT", 1, -1 - (i - 1) * h)
				e:SetPoint("TOPRIGHT", -1, -1 - (i - 1) * h)
				local hl = e:CreateTexture(nil, "HIGHLIGHT")
				hl:SetAllPoints()
				Theme.Solid(hl, "raised")
				e.text = Theme.Text(e, "body", "text")
				e.text:SetPoint("LEFT", SP.s, 0)
				e:SetScript("OnClick", function(self)
					b:Close()
					opts.set(self.value)
					b:Refresh()
				end)
				pop.entries[i] = e
			end
			e.value = it.value
			e.text:SetText(it.text)
			e.text:SetTextColor(Theme.RGB(it.value == current and "beard" or "text"))
			e:Show()
		end
		for i = #items + 1, #pop.entries do pop.entries[i]:Hide() end
		pop:SetHeight(#items * h + 2)
		Motion.In(pop, Theme.MOTION.page, 0.96, "TOP")
		openMenu = self
	end

	b:SetScript("OnClick", function(self)
		if pop:IsShown() then self:Close() else self:Open() end
	end)
	b:SetScript("OnHide", function(self) self:Close() end)
	b:Refresh()
	return b
end

---------------------------------------------------------------------------
-- Search box (with a clear button once something is typed)
---------------------------------------------------------------------------
function W.SearchBox(parent, width, placeholder, onChange)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(width, S.control)
	e:SetAutoFocus(false)
	e:SetMaxLetters(60)
	e:SetTextInsets(SP.s, S.control, 0, 0)
	Theme.Font(e, "body", "text")
	local bg = e:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	Theme.Solid(bg, "surface")
	Theme.Border(e, "lineStrong")
	local hint = Theme.Text(e, "body", "dim")
	hint:SetPoint("LEFT", SP.s, 0)
	hint:SetPoint("RIGHT", -S.control, 0)
	hint:SetWordWrap(false)
	hint:SetText(placeholder)
	local clear = CreateFrame("Button", nil, e)
	clear:SetSize(S.control, S.control)
	clear:SetPoint("RIGHT")
	local x = clear:CreateTexture(nil, "ARTWORK")
	x:SetSize(10, 10)
	x:SetPoint("CENTER")
	x:SetTexture(Theme.TEX.close)
	x:SetVertexColor(Theme.RGB("dim"))
	clear:SetScript("OnEnter", function() x:SetVertexColor(Theme.RGB("text")) end)
	clear:SetScript("OnLeave", function() x:SetVertexColor(Theme.RGB("dim")) end)
	clear:SetScript("OnClick", function() e:SetText(""); e:ClearFocus() end)
	clear:Hide()
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEditFocusGained", function(self) Theme.SetBorderColor(self, "gold") end)
	e:SetScript("OnEditFocusLost", function(self) Theme.SetBorderColor(self, "lineStrong") end)
	e:SetScript("OnTextChanged", function(self)
		local text = self:GetText() or ""
		hint:SetShown(text == "")
		clear:SetShown(text ~= "")
		onChange(text)
	end)
	return e
end

---------------------------------------------------------------------------
-- Vertical scroll bar (core Slider) shared by List, TextPanel and Sheet.
-- A thin thumb, a wider hit area.
---------------------------------------------------------------------------
local function ScrollBar(parent, onValue)
	local s = CreateFrame("Slider", nil, parent)
	s:SetOrientation("VERTICAL")
	s:SetWidth(SP.m)
	s:SetMinMaxValues(0, 0)
	s:SetValueStep(1)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	s:SetThumbTexture(Theme.TEX.white)
	local thumb = s:GetThumbTexture()
	thumb:SetSize(S.scrollbar, S.minHit)
	thumb:SetVertexColor(Theme.RGB("lineStrong"))
	s:SetScript("OnEnter", function() thumb:SetVertexColor(Theme.RGB("dim")) end)
	s:SetScript("OnLeave", function() thumb:SetVertexColor(Theme.RGB("lineStrong")) end)
	s:SetScript("OnValueChanged", function(_, v) onValue(math.floor(v + 0.5)) end)
	return s
end

---------------------------------------------------------------------------
-- List: virtual rows + sortable header, with empty and loading states.
-- opts = {
--   columns = { { key=, title=, width=, align="LEFT", sort=function(a,b) } },
--   rowHeight = SIZES.row,
--   setCell = function(fontString, item, column) end,  -- fill a cell
--   onClick = function(item, button) end,
--   onEnter = function(row, item) end,                  -- optional tooltip
--   decorate = function(row) end,                       -- optional: add widgets to a new row
--                                                       -- (put them in row.widgets so empty rows hide them)
--   update = function(row, item) end,                   -- optional: after a row is filled
--   header = false,                                     -- optional: no header row
-- }
---------------------------------------------------------------------------
function W.List(parent, opts)
	local list = CreateFrame("Frame", nil, parent)
	list.opts = opts
	list.items, list.offset = {}, 0
	local rowH = opts.rowHeight or S.row
	local headH = opts.header == false and 0 or S.header

	-- header: dim sentence-case labels, one rule under it, a sort arrow on
	-- the active column only.
	local header = CreateFrame("Frame", nil, list)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT", -SP.m, 0)
	header:SetHeight(math.max(headH, 1))
	header:SetShown(headH > 0)
	local rule = Theme.Rule(header, "line")
	rule:SetPoint("BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT")
	list.header = header
	local x = 0
	list.headerButtons = {}
	for i, col in ipairs(opts.columns) do
		local hb = CreateFrame("Button", nil, header)
		hb:SetPoint("LEFT", x, 0)
		hb:SetSize(col.width, headH)
		hb.text = Theme.Text(hb, "small", "dim")
		local right = col.align == "RIGHT"
		hb.text:SetPoint(right and "RIGHT" or "LEFT", right and -SP.s or SP.s, 0)
		hb.text:SetText(col.title)
		hb.arrow = hb:CreateTexture(nil, "ARTWORK")
		hb.arrow:SetSize(8, 8)
		hb.arrow:SetTexture(Theme.TEX.arrow)
		hb.arrow:SetVertexColor(Theme.RGB("text"))
		if right then hb.arrow:SetPoint("RIGHT", hb.text, "LEFT", -SP.xs, 0)
		else hb.arrow:SetPoint("LEFT", hb.text, "RIGHT", SP.xs, 0) end
		hb.arrow:Hide()
		if col.sort then
			hb:SetScript("OnClick", function()
				if list.sortCol == i then list.sortDesc = not list.sortDesc else list.sortCol, list.sortDesc = i, false end
				list:Sort()
			end)
			hb:SetScript("OnEnter", function(self) self.text:SetTextColor(Theme.RGB("text")) end)
			hb:SetScript("OnLeave", function(self)
				self.text:SetTextColor(Theme.RGB(list.sortCol == i and "text" or "dim"))
			end)
		end
		list.headerButtons[i] = hb
		x = x + col.width
	end

	-- scroll bar
	local bar = ScrollBar(list, function(v) list.offset = v; list:Draw() end)
	bar:SetPoint("TOPRIGHT", 0, -headH)
	bar:SetPoint("BOTTOMRIGHT")
	list.bar = bar

	-- empty / error sentence: keeps the header and frame, one line of help.
	list.message = Theme.Text(list, "body", "dim")
	list.message:SetPoint("TOPLEFT", SP.s, -headH - SP.m)
	list.message:SetPoint("RIGHT", -SP.l, 0)
	list.message:SetJustifyV("TOP")
	list.message:Hide()

	list.rows = {}
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta)
		bar:SetValue(math.max(0, list.offset - delta * 3))
	end)

	function list:RowCount()
		return math.max(1, math.floor((self:GetHeight() - headH) / rowH))
	end

	function list:EnsureRows()
		local need = self:RowCount()
		for i = #self.rows + 1, need do
			local row = CreateFrame("Button", nil, self)
			row:SetHeight(rowH)
			row:SetPoint("TOPLEFT", 0, -headH - (i - 1) * rowH)
			row:SetPoint("TOPRIGHT", -SP.m, -headH - (i - 1) * rowH)
			row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			local ruleRow = Theme.Rule(row, "rule", "BACKGROUND")
			ruleRow:SetPoint("BOTTOMLEFT")
			ruleRow:SetPoint("BOTTOMRIGHT")
			row.sel = row:CreateTexture(nil, "BACKGROUND", nil, 1)
			row.sel:SetAllPoints()
			Theme.Solid(row.sel, "beard", Theme.ALPHA.selected)
			row.sel:Hide()
			row.hl = row:CreateTexture(nil, "BACKGROUND", nil, 2)
			row.hl:SetAllPoints()
			Theme.Solid(row.hl, "raised")
			row.hl:Hide()
			-- loading placeholder: a flat bar at the size of the text
			row.skeleton = row:CreateTexture(nil, "ARTWORK")
			row.skeleton:SetPoint("LEFT", SP.s, 0)
			row.skeleton:SetSize(120 + (i * 37) % 90, 8)
			Theme.Solid(row.skeleton, "raised")
			row.skeleton:Hide()
			row.cells = {}
			row.widgets = {}
			local cx = 0
			for c, col in ipairs(opts.columns) do
				local fs = Theme.Text(row, "body", "text")
				fs:SetWidth(col.width - SP.s * 2)
				fs:SetJustifyH(col.align or "LEFT")
				fs:SetWordWrap(false)
				fs:SetPoint("LEFT", cx + SP.s, 0)
				row.cells[c] = fs
				cx = cx + col.width
			end
			row:SetScript("OnClick", function(self, button)
				if self.item and opts.onClick then opts.onClick(self.item, button) end
			end)
			row:SetScript("OnEnter", function(self)
				if not self.item then return end
				if opts.onClick then Motion.HoverIn(self.hl) end
				if opts.onEnter then opts.onEnter(self, self.item) end
			end)
			row:SetScript("OnLeave", function(self)
				Motion.HoverOut(self.hl)
				GameTooltip:Hide()
			end)
			if opts.decorate then opts.decorate(row) end
			self.rows[i] = row
		end
	end

	function list:Sort()
		local col = self.sortCol and opts.columns[self.sortCol]
		if col and col.sort then
			local desc = self.sortDesc
			table.sort(self.items, function(a, b)
				if desc then return col.sort(b, a) end
				return col.sort(a, b)
			end)
		end
		for i, hb in ipairs(self.headerButtons) do
			local on = i == self.sortCol and opts.columns[i].sort ~= nil
			hb.arrow:SetShown(on)
			hb.text:SetTextColor(Theme.RGB(on and "text" or "dim"))
			if on then
				if self.sortDesc then hb.arrow:SetTexCoord(0, 1, 1, 0) else hb.arrow:SetTexCoord(0, 1, 0, 1) end
			end
		end
		self:Draw()
	end

	-- Optional: isSelected(item) -> bool marks rows with a steady tint.
	function list:SetSelected(isSelected)
		self.isSelected = isSelected
		self:Draw()
	end

	-- Text shown when there are no items (nil = nothing).
	function list:SetEmptyText(text)
		self.emptyText = text
		self:Draw()
	end

	-- Loading: placeholder bars instead of rows until data arrives.
	function list:SetLoading(flag)
		self.loading = flag and true or false
		self:Draw()
	end

	function list:SetItems(items)
		self.items = items
		self:Sort()
	end

	function list:Draw()
		self:EnsureRows()
		local visible = self:RowCount()
		local maxOffset = math.max(0, #self.items - visible)
		if self.offset > maxOffset then self.offset = maxOffset end
		bar:SetMinMaxValues(0, maxOffset)
		bar:SetShown(maxOffset > 0)
		local loading = self.loading and #self.items == 0
		for i, row in ipairs(self.rows) do
			local item = (i <= visible) and self.items[self.offset + i] or nil
			row.item = item
			row.skeleton:SetShown(loading and i <= math.min(visible, 6))
			if item then
				for c, col in ipairs(opts.columns) do opts.setCell(row.cells[c], item, col) end
				if opts.update then opts.update(row, item) end
				row.sel:SetShown(self.isSelected ~= nil and self.isSelected(item) and true or false)
				for _, fs in ipairs(row.cells) do fs:Show() end
				row:Show()
			else
				for _, fs in ipairs(row.cells) do fs:Hide() end
				row.sel:Hide()
				row.hl:Hide()
				row:SetShown(loading and i <= 6)
				for _, w in ipairs(row.widgets) do w:Hide() end
			end
		end
		local empty = #self.items == 0 and not loading and self.emptyText
		self.message:SetText(empty or "")
		self.message:SetShown(empty and true or false)
	end

	list:SetScript("OnSizeChanged", function(self) self:Draw() end)
	return list
end

---------------------------------------------------------------------------
-- TextPanel: a scrollable block of rich text (|c colours, |T icons).
---------------------------------------------------------------------------
function W.TextPanel(parent)
	local panel = CreateFrame("ScrollFrame", nil, parent)
	local child = CreateFrame("Frame", nil, panel)
	child:SetSize(10, 10)
	panel:SetScrollChild(child)
	local fs = Theme.Text(child, "body", "text")
	fs:SetPoint("TOPLEFT")
	fs:SetJustifyV("TOP")
	fs:SetSpacing(3)
	panel.fs = fs
	local bar = ScrollBar(panel, function(v) panel:SetVerticalScroll(v) end)
	bar:SetPoint("TOPRIGHT", SP.m, 0)
	bar:SetPoint("BOTTOMRIGHT", SP.m, 0)
	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(self, delta)
		local _, max = bar:GetMinMaxValues()
		bar:SetValue(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 30)))
	end)
	function panel:SetText(text)
		local w = self:GetWidth()
		child:SetWidth(w)
		fs:SetWidth(w)
		fs:SetText(text)
		local h = fs:GetStringHeight() + SP.s
		child:SetHeight(h)
		local max = math.max(0, h - self:GetHeight())
		bar:SetMinMaxValues(0, max)
		bar:SetShown(max > 0)
		bar:SetValue(0)
	end
	return panel
end

---------------------------------------------------------------------------
-- Block: a section with an uppercase heading, an optional quiet action on
-- the right, a rule, and rows. Rows (all optional fields):
--   { label=, value=, tone=, labelTone=, indent=true, tip= }  key / value
--   { text=, tone= }                                         a sentence (wraps)
--   { sub= }                                                  a small sub-heading
--   { figure=, caption=, tone= }                              the one big number
--   { gap=true }                                              half a row of space
-- Values are right-aligned on one edge; labels are cut with "..." if a
-- value needs the room.
---------------------------------------------------------------------------
local ROW_TONE = { label = "dim", value = "text" }

function W.Block(parent, width, title, action)
	local b = CreateFrame("Frame", nil, parent)
	b:SetWidth(width)
	b.width = width
	b.heading = Theme.Text(b, "heading", "text")
	b.heading:SetPoint("TOPLEFT", 0, 0)
	b.heading:SetText((title or ""):upper())
	b.headH = title and (S.control) or 0
	b.heading:SetShown(title ~= nil)
	if title then
		b.heading:ClearAllPoints()
		b.heading:SetPoint("LEFT", b, "TOPLEFT", 0, -S.control / 2)
		local rule = Theme.Rule(b, "line")
		rule:SetPoint("TOPLEFT", 0, -S.control)
		rule:SetPoint("TOPRIGHT", 0, -S.control)
		b.headH = S.control + SP.s
	end
	if action then
		b.button = W.Button(b, action.text, nil, S.controlSmall, action.onClick, "quiet")
		b.button:SetPoint("RIGHT", b, "TOPRIGHT", 0, -S.control / 2)
		b.button.tooltip = action.tooltip
	end
	b.pool = {}

	local function cell(i)
		local r = b.pool[i]
		if not r then
			r = {
				label = Theme.Text(b, "body", "dim"),
				value = Theme.Text(b, "body", "text"),
				text = Theme.Text(b, "small", "dim"),
				figure = Theme.Text(b, "figure", "gold"),
			}
			r.label:SetWordWrap(false)
			r.value:SetJustifyH("RIGHT")
			r.value:SetWordWrap(false)
			r.text:SetJustifyV("TOP")
			r.text:SetSpacing(2)
			b.pool[i] = r
		end
		for _, fs in pairs(r) do fs:Hide(); fs:ClearAllPoints() end
		return r
	end

	-- Lay out rows; sets and returns the block's height.
	function b:SetRows(rows)
		self.rows = rows
		local y = self.headH
		for i, row in ipairs(rows) do
			local r = cell(i)
			if row.gap then
				y = y + S.specRow / 2
			elseif row.figure then
				r.figure:SetPoint("TOPLEFT", 0, -y)
				r.figure:SetText(row.figure)
				r.figure:SetTextColor(Theme.RGB(row.tone or "gold"))
				r.figure:Show()
				if row.caption then
					r.label:SetPoint("BOTTOMLEFT", r.figure, "BOTTOMRIGHT", SP.s, 3)
					r.label:SetPoint("RIGHT", self, "RIGHT", 0, 0)
					Theme.Font(r.label, "small", "dim")
					r.label:SetText(row.caption)
					r.label:Show()
				end
				y = y + Theme.SIZE.figure + SP.s
			elseif row.text or row.sub then
				Theme.Font(r.text, row.sub and "small" or "small", row.tone or "dim")
				r.text:SetPoint("TOPLEFT", row.indent and SP.m or 0, -y - (row.sub and SP.xs or 0))
				r.text:SetWidth(self.width - (row.indent and SP.m or 0))
				r.text:SetText(row.sub or row.text)
				r.text:Show()
				local h = r.text:GetStringHeight() or 0
				y = y + math.max(S.specRow, h + SP.xs) + (row.sub and SP.xs or 0)
			else
				local x = row.indent and SP.m or 0
				Theme.Font(r.value, "body", row.tone or ROW_TONE.value)
				r.value:SetPoint("TOPRIGHT", 0, -y)
				r.value:SetText(row.value or Theme.DASH)
				r.value:Show()
				Theme.Font(r.label, "body", row.labelTone or ROW_TONE.label)
				r.label:SetPoint("TOPLEFT", x, -y)
				r.label:SetPoint("RIGHT", r.value, "LEFT", -SP.s, 0)
				r.label:SetText(row.label or "")
				r.label:Show()
				y = y + S.specRow
			end
		end
		for i = #rows + 1, #self.pool do cell(i) end
		self:SetHeight(math.max(1, y))
		return y
	end
	return b
end

-- Plain text of block sections, for Copy and tests:
-- { { title=, rows={...} }, ... } -> "TITLE\n  label  value\n..."
function W.SheetText(sections)
	local L = {}
	for _, s in ipairs(sections) do
		if #L > 0 then L[#L + 1] = "" end
		if s.title then L[#L + 1] = s.title:upper() end
		for _, row in ipairs(s.rows or {}) do
			if row.figure then
				L[#L + 1] = "  " .. row.figure .. (row.caption and (" " .. row.caption) or "")
			elseif row.text or row.sub then
				L[#L + 1] = "  " .. (row.sub or row.text)
			elseif not row.gap then
				local value = row.value and Theme.Paint(row.tone, row.value) or "-"
				L[#L + 1] = "  " .. (row.indent and "  " or "") .. (row.label or "") .. "  " .. value
			end
		end
	end
	return table.concat(L, "\n")
end

---------------------------------------------------------------------------
-- Sheet: a scrolling column of Blocks. sheet:SetSections({ {title=, rows=}, ... })
---------------------------------------------------------------------------
function W.Sheet(parent, width)
	local sheet = CreateFrame("ScrollFrame", nil, parent)
	local child = CreateFrame("Frame", nil, sheet)
	child:SetSize(width, 10)
	sheet:SetScrollChild(child)
	sheet.blocks = {}
	local bar = ScrollBar(sheet, function(v) sheet:SetVerticalScroll(v) end)
	bar:SetPoint("TOPRIGHT", SP.m, 0)
	bar:SetPoint("BOTTOMRIGHT", SP.m, 0)
	sheet:EnableMouseWheel(true)
	sheet:SetScript("OnMouseWheel", function(self, delta)
		local _, max = bar:GetMinMaxValues()
		bar:SetValue(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 30)))
	end)
	function sheet:SetSections(sections)
		self.sections = sections
		local y = 0
		for i, s in ipairs(sections) do
			local blk = self.blocks[i]
			if not blk or blk.title ~= s.title then
				if blk then blk:Hide() end
				blk = W.Block(child, width, s.title)
				blk.title = s.title
				self.blocks[i] = blk
			end
			blk:ClearAllPoints()
			blk:SetPoint("TOPLEFT", 0, -y)
			blk:Show()
			y = y + blk:SetRows(s.rows or {}) + SP.xl
		end
		for i = #sections + 1, #self.blocks do self.blocks[i]:Hide() end
		child:SetHeight(math.max(1, y))
		local max = math.max(0, y - self:GetHeight())
		bar:SetMinMaxValues(0, max)
		bar:SetShown(max > 0)
		bar:SetValue(0)
		self:SetVerticalScroll(0)
	end
	return sheet
end
