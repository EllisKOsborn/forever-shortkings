-- Widgets in the Short Kings design system (docs/DESIGN.md sections 5–12):
-- buttons (default, primary, ghost, small, icon), rail items, segments,
-- check boxes, a pop-up menu, a search box, a virtual list with sortable
-- columns, a scrollable text panel, cards, label/value lines and empty
-- states. Only core widget types (Frame, Button, Slider, EditBox,
-- ScrollFrame, CheckButton); no Blizzard templates.
local _, SK = ...

local W = {}
SK.Widgets = W
local Theme = SK.Theme

-- A full-size white wash texture on `frame` at `kind` (Theme.WASH), hidden.
local function wash(frame, kind, layer, sub)
	local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 2)
	t:SetAllPoints()
	Theme.Wash(t, kind)
	t:Hide()
	return t
end
W.WashTexture = wash

-- The 2 px accent bar used for "where you are" (rail, selected row, segment).
local function accentBar(frame, side)
	local t = frame:CreateTexture(nil, "ARTWORK", nil, 6)
	Theme.Solid(t, "accent")
	if side == "BOTTOM" then
		t:SetPoint("BOTTOMLEFT"); t:SetPoint("BOTTOMRIGHT"); t:SetHeight(2)
	else
		t:SetPoint("TOPLEFT"); t:SetPoint("BOTTOMLEFT"); t:SetWidth(2)
	end
	t:Hide()
	return t
end
W.AccentBar = accentBar

local function showTooltip(self, tip)
	if not tip then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(tip, 1, 1, 1, 1, true)
	GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Button. style: "default" (panelAlt + hairline), "primary" (accent fill,
-- one per screen), "ghost" (hairline only). Height 28 (22 = small).
-- Optional opts = { style =, icon = glyph name }.
---------------------------------------------------------------------------
function W.Button(parent, text, width, height, onClick, opts)
	opts = opts or {}
	local b = CreateFrame("Button", nil, parent)
	b.disabled, b.active, b.iconTex = false, false, false
	height = height or 28
	b:SetSize(width or 100, height)
	b.fill = b:CreateTexture(nil, "BACKGROUND", nil, 1)
	b.fill:SetAllPoints()
	b.hover = wash(b, "hover")
	b.press = wash(b, "pressed", "BACKGROUND", 3)
	Theme.Hairline(b)
	b.bar = accentBar(b, "BOTTOM")
	b.label = Theme.Text(b, height < 26 and "small" or "label", "text")
	b.label:SetPoint("CENTER")
	b.label:SetText(text)
	b.label:SetWordWrap(false)

	function b:SetIcon(name)
		if not self.iconTex then
			self.iconTex = self:CreateTexture(nil, "ARTWORK")
			self.iconTex:SetSize(13, 13)
			self.iconTex:SetPoint("RIGHT", self.label, "LEFT", -6, 0)
		end
		self.iconTex:SetTexture(Theme.Icon(name))
		self.label:SetPoint("CENTER", 9.5, 0)
		self:Paint()
	end

	-- Colours for the current style and state.
	function b:Paint()
		local primary = self.style == "primary"
		if primary then Theme.Solid(self.fill, "accent")
		elseif self.style == "ghost" then self.fill:SetColorTexture(0, 0, 0, 0)
		else Theme.Solid(self.fill, "panelAlt") end
		for _, t in ipairs(self.border) do t:SetShown(not primary) end
		local ink = primary and "onAccent" or "text"
		self.label:SetTextColor(Theme.RGB(ink))
		self.label:SetShadowOffset(primary and 0 or 1, primary and 0 or -1)
		if self.iconTex then self.iconTex:SetVertexColor(Theme.RGB(ink)) end
		self:SetAlpha(self.disabled and 0.5 or 1)
		self.bar:SetShown(self.active)
		if self.active then self.hover:Show() end
	end

	function b:SetStyle(style)
		self.style = style or "default"
		self:Paint()
	end

	b:SetScript("OnEnter", function(self)
		-- A disabled button still explains itself (disabledTooltip).
		if not self.disabled then
			self.hover:Show()
			if self.style ~= "primary" then Theme.SetBorderColor(self, nil, "strong") end
		end
		showTooltip(self, self.disabled and self.disabledTooltip or (not self.disabled and self.tooltip))
	end)
	b:SetScript("OnLeave", function(self)
		self.hover:SetShown(self.active)
		Theme.SetBorderColor(self, nil)
		GameTooltip:Hide()
	end)
	b:SetScript("OnMouseDown", function(self) if not self.disabled then self.press:Show() end end)
	b:SetScript("OnMouseUp", function(self) self.press:Hide() end)
	if onClick then b:SetScript("OnClick", function(self, ...) if not self.disabled then onClick(self, ...) end end) end
	function b:SetText(t) self.label:SetText(t) end
	function b:SetDisabled(flag)
		self.disabled = flag and true or false
		self:Paint()
	end
	-- "Selected" look (segments): wash + 2 px accent bar under the label.
	function b:SetActive(flag)
		self.active = flag and true or false
		self.hover:SetShown(self.active)
		self:Paint()
	end
	b.style = opts.style or "default"
	if opts.icon then b:SetIcon(opts.icon) else b:Paint() end
	return b
end

-- Size a button to its label: 16 px each side, at least 72 wide (small: 10 px).
function W.FitWidth(b, min)
	local pad = b:GetHeight() < 26 and 20 or 32
	local w = b.label:GetStringWidth() + pad + (b.iconTex and 19 or 0)
	b:SetWidth(math.max(min or (b:GetHeight() < 26 and 0 or 72), math.ceil(w)))
	return b
end

---------------------------------------------------------------------------
-- Icon button: 24 px square, glyph 12 px in textDim, hover wash (close).
---------------------------------------------------------------------------
function W.IconButton(parent, icon, size, onClick, tooltip)
	local b = CreateFrame("Button", nil, parent)
	size = size or 24
	b:SetSize(size, size)
	b.hover = wash(b, "hover")
	b.glyph = Theme.Glyph(b, icon, math.floor(size / 2), "textDim")
	b.glyph:SetPoint("CENTER")
	b.tooltip = tooltip
	b:SetScript("OnEnter", function(self)
		self.hover:Show()
		self.glyph:SetVertexColor(Theme.RGB("text"))
		showTooltip(self, self.tooltip)
	end)
	b:SetScript("OnLeave", function(self)
		self.hover:Hide()
		self.glyph:SetVertexColor(Theme.RGB("textDim"))
		GameTooltip:Hide()
	end)
	if onClick then b:SetScript("OnClick", onClick) end
	return b
end

---------------------------------------------------------------------------
-- Rail item: 56 x 56, glyph 20 px with a small label under it.
-- Active: 9% wash, accent glyph and label, 2 px accent bar on the left edge.
---------------------------------------------------------------------------
function W.RailItem(parent, icon, label, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(56, 56)
	b.over, b.active = false, false
	b.hover = wash(b, "hover")
	b.sel = wash(b, "selected")
	b.bar = accentBar(b, "LEFT")
	b.bar:ClearAllPoints()
	b.bar:SetPoint("TOPLEFT", -4, 0)
	b.bar:SetPoint("BOTTOMLEFT", -4, 0)
	b.glyph = Theme.Glyph(b, icon, 20, "textDim")
	b.glyph:SetPoint("TOP", 0, -9)
	b.label = Theme.Text(b, "small", "textDim")
	b.label:SetPoint("TOP", 0, -34)
	b.label:SetText(label)
	local function paint(self)
		local c = self.active and "accent" or (self.over and "text" or "textDim")
		self.glyph:SetVertexColor(Theme.RGB(c))
		self.label:SetTextColor(Theme.RGB(c))
		self.sel:SetShown(self.active)
		self.bar:SetShown(self.active)
		self.hover:SetShown(self.over and not self.active)
	end
	b:SetScript("OnEnter", function(self) self.over = true; paint(self) end)
	b:SetScript("OnLeave", function(self) self.over = false; paint(self) end)
	if onClick then b:SetScript("OnClick", onClick) end
	function b:SetActive(flag)
		self.active = flag and true or false
		paint(self)
	end
	paint(b)
	return b
end

---------------------------------------------------------------------------
-- Segments: a row of joined 24 px choices; the chosen one gets a 9% wash
-- and a 2 px accent bar underneath. items = { {value=, text=}, ... }
---------------------------------------------------------------------------
function W.Segments(parent, items, get, set)
	local g = CreateFrame("Frame", nil, parent)
	g:SetHeight(24)
	g.buttons = {}
	local x = 0
	for i, it in ipairs(items) do
		local b = W.Button(g, it.text, 10, 24, function()
			set(it.value)
			g:Refresh()
		end, { style = "ghost" })
		b.label:SetFontObject(nil)
		Theme.Font(b.label, "label", "textDim")
		W.FitWidth(b, 0)
		b:SetWidth(b.label:GetStringWidth() + 24)
		b:SetPoint("LEFT", x, 0)
		b.value = it.value
		b.tooltip = it.tooltip
		-- Joined segments share one hairline between them.
		if i > 1 then b.border[3]:Hide() end
		x = x + b:GetWidth()
		g.buttons[i] = b
	end
	g:SetWidth(math.max(1, x))
	function g:Refresh()
		local current = get()
		for _, b in ipairs(self.buttons) do
			local on = b.value == current
			b:SetActive(on)
			b.label:SetTextColor(Theme.RGB(on and "text" or "textDim"))
		end
	end
	g:Refresh()
	return g
end

---------------------------------------------------------------------------
-- Check box with label: 14 px box; on = accent edge + 8 px accent square.
---------------------------------------------------------------------------
function W.Check(parent, label, getter, setter, size)
	local c = CreateFrame("CheckButton", nil, parent)
	c:SetSize(14, 14)
	c.over = false
	local box = c:CreateTexture(nil, "BACKGROUND")
	box:SetAllPoints()
	Theme.Solid(box, "sidebar")
	Theme.Hairline(c, nil, 0.22)
	local tick = c:CreateTexture(nil, "ARTWORK")
	tick:SetPoint("TOPLEFT", 3, -3)
	tick:SetPoint("BOTTOMRIGHT", -3, 3)
	Theme.Solid(tick, "accent")
	c:SetCheckedTexture(tick)
	c.label = Theme.Text(c, size or "body", "text")
	c.label:SetPoint("LEFT", c, "RIGHT", 8, 0)
	c.label:SetText(label)
	-- The label is part of the click area.
	if c.SetHitRectInsets then c:SetHitRectInsets(0, -(c.label:GetStringWidth() + 8), -4, -4) end
	local function edge(self)
		if self:GetChecked() then Theme.SetBorderColor(self, "accent")
		else Theme.SetBorderColor(self, nil, self.over and "strong" or 0.22) end
	end
	c:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false); edge(self) end)
	c:SetScript("OnEnter", function(self) self.over = true; edge(self); showTooltip(self, self.tooltip) end)
	c:SetScript("OnLeave", function(self) self.over = false; edge(self); GameTooltip:Hide() end)
	function c:Refresh()
		self:SetChecked(getter() and true or false)
		edge(self)
	end
	c:Refresh()
	return c
end

---------------------------------------------------------------------------
-- Menu: a 28 px button that opens a pop-up list (no Blizzard dropdowns).
-- opts = { width = 168, items = function() return { {value=, text=} or
-- {separator=true}, ... } end, get = function() end, set = function(v) end }
-- Pop-up: panel tone, 26 px rows, current choice = 6 px accent square.
---------------------------------------------------------------------------
local openMenu
local ROW_H, SEP_H = 26, 9

function W.Menu(parent, opts)
	local width = opts.width or 168
	local b = W.Button(parent, "", width, 28)
	local arrow = Theme.Glyph(b, "chevron", 9, "textDim")
	arrow:SetPoint("RIGHT", -10, 0)
	b.label:ClearAllPoints()
	b.label:SetPoint("LEFT", 12, 0)
	b.label:SetPoint("RIGHT", -26, 0)
	b.label:SetJustifyH("LEFT")

	local pop = CreateFrame("Frame", nil, b)
	pop:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
	pop:SetWidth(math.max(width, 176))
	pop:SetFrameStrata("FULLSCREEN_DIALOG")
	pop:EnableMouse(true)
	Theme.Panel(pop, { tone = "panel" })
	pop:Hide()
	pop.entries = {}
	b.pop = pop

	function b:Refresh()
		local current = opts.get()
		for _, it in ipairs(opts.items()) do
			if not it.separator and it.value == current then self:SetText(it.text) return end
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
		local y = -4
		for i, it in ipairs(items) do
			local e = pop.entries[i]
			if not e then
				e = CreateFrame("Button", nil, pop)
				local hl = e:CreateTexture(nil, "HIGHLIGHT")
				hl:SetAllPoints()
				Theme.Wash(hl, "hover")
				e.mark = e:CreateTexture(nil, "ARTWORK")
				e.mark:SetSize(6, 6)
				e.mark:SetPoint("LEFT", 12, 0)
				Theme.Solid(e.mark, "accent")
				e.text = Theme.Text(e, "label", "text")
				e.text:SetPoint("LEFT", 28, 0)
				e.line = e:CreateTexture(nil, "ARTWORK")
				e.line:SetPoint("LEFT", 8, 0)
				e.line:SetPoint("RIGHT", -8, 0)
				e.line:SetHeight(1)
				Theme.Wash(e.line, "hairline")
				e:SetScript("OnClick", function(self)
					if self.separator then return end
					b:Close()
					opts.set(self.value)
					b:Refresh()
				end)
				pop.entries[i] = e
			end
			local h = it.separator and SEP_H or ROW_H
			e:ClearAllPoints()
			e:SetPoint("TOPLEFT", 1, y)
			e:SetPoint("TOPRIGHT", -1, y)
			e:SetHeight(h)
			y = y - h
			e.separator = it.separator and true or false
			e.value = it.value
			e.text:SetText(it.text or "")
			e.text:SetShown(not e.separator)
			e.line:SetShown(e.separator)
			e.mark:SetShown(not e.separator and it.value == current)
			e:EnableMouse(not e.separator)
			e:Show()
		end
		for i = #items + 1, #pop.entries do pop.entries[i]:Hide() end
		pop:SetHeight(-y + 4)
		pop:Show()
		Theme.FadeIn(pop)
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
-- Search box: 28 px, inset (sidebar) ground, magnifier glyph, placeholder
-- in textMuted; focus turns the hairline accent.
---------------------------------------------------------------------------
function W.SearchBox(parent, width, placeholder, onChange)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(width, 28)
	e:SetAutoFocus(false)
	e:SetMaxLetters(60)
	e:SetTextInsets(30, 8, 0, 0)
	Theme.Font(e, "label", "text")
	local bg = e:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	Theme.Solid(bg, "sidebar")
	Theme.Hairline(e)
	local glass = Theme.Glyph(e, "search", 12, "textMuted")
	glass:SetPoint("LEFT", 9, 0)
	local hint = Theme.Text(e, "label", "textMuted")
	hint:SetPoint("LEFT", 30, 0)
	hint:SetPoint("RIGHT", -8, 0)
	hint:SetJustifyH("LEFT")
	hint:SetWordWrap(false)
	hint:SetText(placeholder)
	e.hint = hint
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEditFocusGained", function(self) Theme.SetBorderColor(self, "accent", 0.8) end)
	e:SetScript("OnEditFocusLost", function(self) Theme.SetBorderColor(self, nil) end)
	e:SetScript("OnTextChanged", function(self)
		local text = self:GetText() or ""
		hint:SetShown(text == "")
		onChange(text)
	end)
	return e
end

---------------------------------------------------------------------------
-- Scroll bar: a 6 px strip with a 2 px white thumb (4 px on hover).
---------------------------------------------------------------------------
local function ScrollBar(parent, onValue)
	local s = CreateFrame("Slider", nil, parent)
	s:SetOrientation("VERTICAL")
	s:SetWidth(6)
	s:SetMinMaxValues(0, 0)
	s:SetValueStep(1)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	s:SetThumbTexture(Theme.WHITE)
	local thumb = s:GetThumbTexture()
	thumb:SetSize(2, 30)
	thumb:SetVertexColor(1, 1, 1, 0.28)
	s:SetScript("OnEnter", function() thumb:SetWidth(4); thumb:SetVertexColor(1, 1, 1, 0.45) end)
	s:SetScript("OnLeave", function() thumb:SetWidth(2); thumb:SetVertexColor(1, 1, 1, 0.28) end)
	s:SetScript("OnValueChanged", function(_, v) onValue(math.floor(v + 0.5)) end)
	return s
end

---------------------------------------------------------------------------
-- List: virtual rows + sortable header.
-- opts = {
--   columns = { { key=, title=, width=, align="LEFT", sort=function(a,b) } },
--   rowHeight = 22,
--   ground = true,       -- panel fill + hairline (false inside cards)
--   header = true,       -- false hides the header row
--   setCell = function(fontString, item, column) end,  -- fill a cell
--   onClick = function(item, button) end,
--   onEnter = function(row, item) end,                  -- optional tooltip
--   decorate = function(row) end,                       -- optional: add widgets to a new row
--   update = function(row, item) end,                   -- optional: after a row is filled
-- }
---------------------------------------------------------------------------
local HEADER_H = 24

local function sortedTitle(col, on, desc)
	if not on then return col.title end
	return col.title .. " " .. Theme.InlineIcon(desc and "chevronUp" or "chevron", 9, "text")
end

function W.List(parent, opts)
	local list = CreateFrame("Frame", nil, parent)
	list.opts = opts
	list.items, list.offset = {}, 0
	local rowH = opts.rowHeight or 22
	local headH = opts.header == false and 0 or HEADER_H
	if opts.ground ~= false then Theme.Panel(list, { tone = "panel" }) end

	-- header
	local header = CreateFrame("Frame", nil, list)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(math.max(1, headH - 1))
	header:SetShown(headH > 0)
	if headH > 0 then Theme.Edge(header, "BOTTOM") end
	list.header = header
	local x = 8
	list.headerButtons = {}
	for i, col in ipairs(opts.columns) do
		local hb = CreateFrame("Button", nil, header)
		hb:SetPoint("LEFT", x, 0)
		hb:SetSize(col.width, HEADER_H - 1)
		hb.text = Theme.Text(hb, "label", "textDim")
		hb.text:SetPoint(col.align or "LEFT", col.align == "RIGHT" and -8 or 0, 0)
		hb.text:SetText(col.title)
		if col.sort then
			hb:SetScript("OnClick", function()
				if list.sortCol == i then list.sortDesc = not list.sortDesc else list.sortCol, list.sortDesc = i, false end
				list:Sort()
			end)
			hb:SetScript("OnEnter", function(self) self.text:SetTextColor(Theme.RGB("text")) end)
			hb:SetScript("OnLeave", function(self)
				self.text:SetTextColor(Theme.RGB(list.sortCol == i and "text" or "textDim"))
			end)
		end
		list.headerButtons[i] = hb
		x = x + col.width
	end

	-- scroll bar
	local bar = ScrollBar(list, function(v) list.offset = v; list:Draw() end)
	bar:SetPoint("TOPRIGHT", -2, -headH - 2)
	bar:SetPoint("BOTTOMRIGHT", -2, 2)
	list.bar = bar

	list.rows = {}
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta)
		bar:SetValue(math.max(0, list.offset - delta * 3))
	end)

	function list:RowCount()
		return math.max(1, math.floor((self:GetHeight() - headH - 2) / rowH))
	end

	function list:EnsureRows()
		local need = self:RowCount()
		for i = #self.rows + 1, need do
			local row = CreateFrame("Button", nil, self)
			row:SetHeight(rowH)
			row:SetPoint("TOPLEFT", 1, -headH - (i - 1) * rowH)
			row:SetPoint("TOPRIGHT", -9, -headH - (i - 1) * rowH)
			row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			if i % 2 == 0 then
				local z = row:CreateTexture(nil, "BACKGROUND")
				z:SetAllPoints()
				Theme.Wash(z, "zebra")
			end
			local hl = row:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints()
			Theme.Wash(hl, "hover")
			row.sel = wash(row, "selected", "BORDER", 1)
			row.selBar = accentBar(row, "LEFT")
			row.cells = {}
			local cx = 8
			for c, col in ipairs(opts.columns) do
				local fs = Theme.Text(row, "body", "text")
				fs:SetWidth(col.width - 8)
				fs:SetJustifyH(col.align or "LEFT")
				fs:SetWordWrap(false)
				fs:SetPoint("LEFT", cx, 0)
				row.cells[c] = fs
				cx = cx + col.width
			end
			row:SetScript("OnClick", function(self, button)
				if self.item and opts.onClick then opts.onClick(self.item, button) end
			end)
			row:SetScript("OnEnter", function(self)
				if self.item and opts.onEnter then opts.onEnter(self, self.item) end
			end)
			row:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
			local on = self.sortCol == i
			hb.text:SetText(sortedTitle(opts.columns[i], on, self.sortDesc))
			hb.text:SetTextColor(Theme.RGB(on and "text" or "textDim"))
		end
		self:Draw()
	end

	-- Optional: isSelected(item) -> bool marks rows with the selected look.
	function list:SetSelected(isSelected)
		self.isSelected = isSelected
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
		for i, row in ipairs(self.rows) do
			local item = (i <= visible) and self.items[self.offset + i] or nil
			row.item = item
			if item then
				for c, col in ipairs(opts.columns) do opts.setCell(row.cells[c], item, col) end
				if opts.update then opts.update(row, item) end
				local sel = self.isSelected ~= nil and self.isSelected(item) and true or false
				row.sel:SetShown(sel)
				row.selBar:SetShown(sel)
				row:Show()
			else
				row:Hide()
			end
		end
	end

	list:SetScript("OnSizeChanged", function(self) self:Draw() end)
	return list
end

---------------------------------------------------------------------------
-- TextPanel: a scrollable block of rich text (|c colours, |T icons).
---------------------------------------------------------------------------
function W.TextPanel(parent, size, spacing)
	local panel = CreateFrame("ScrollFrame", nil, parent)
	local child = CreateFrame("Frame", nil, panel)
	child:SetSize(10, 10)
	panel:SetScrollChild(child)
	local fs = Theme.Text(child, size or "body", "text")
	fs:SetPoint("TOPLEFT")
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetSpacing(spacing or 5)
	panel.fs = fs
	local bar = ScrollBar(panel, function(v) panel:SetVerticalScroll(v) end)
	bar:SetPoint("TOPRIGHT", 8, 0)
	bar:SetPoint("BOTTOMRIGHT", 8, 0)
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
		local h = fs:GetStringHeight() + 8
		child:SetHeight(h)
		local max = math.max(0, h - self:GetHeight())
		bar:SetMinMaxValues(0, max)
		bar:SetShown(max > 0)
		bar:SetValue(0)
	end
	return panel
end

---------------------------------------------------------------------------
-- Lines: label/value pairs, 20 px apart, value right-aligned (cards,
-- Settings status). SetLines({ {left, right}, "a full-width line", ... }).
---------------------------------------------------------------------------
function W.Lines(parent, size, lineH)
	local f = CreateFrame("Frame", nil, parent)
	f.lineH = lineH or 20
	f.size = size or "label"
	f.pool = {}
	function f:SetLines(lines)
		for i, l in ipairs(lines) do
			local p = self.pool[i]
			if not p then
				p = { l = Theme.Text(self, self.size, "textDim"), r = Theme.Text(self, self.size, "text") }
				p.l:SetPoint("TOPLEFT", 0, -(i - 1) * self.lineH)
				p.l:SetJustifyH("LEFT")
				p.l:SetWordWrap(false)
				p.r:SetPoint("TOPRIGHT", 0, -(i - 1) * self.lineH)
				p.r:SetJustifyH("RIGHT")
				p.r:SetWordWrap(false)
				self.pool[i] = p
			end
			if type(l) == "table" then
				p.l:SetText(l[1] or "")
				p.r:SetText(l[2] or "")
				p.l:SetPoint("RIGHT", p.r, "LEFT", -8, 0)
			else
				p.l:SetText(l)
				p.r:SetText("")
				p.l:SetPoint("RIGHT", self, "RIGHT", 0, 0)
			end
			p.l:Show(); p.r:Show()
		end
		for i = #lines + 1, #self.pool do self.pool[i].l:Hide(); self.pool[i].r:Hide() end
	end
	return f
end

---------------------------------------------------------------------------
-- Card (Overview): panelAlt + hairline, 16 px padding, title 15, optional
-- big number (hero 26) with a caption, and one ghost button at the bottom.
---------------------------------------------------------------------------
function W.Card(parent, w, h, title)
	local c = CreateFrame("Frame", nil, parent)
	c:SetSize(w, h)
	Theme.Panel(c, { tone = "panelAlt" })
	c.title = Theme.Text(c, "title", "text")
	c.title:SetPoint("TOPLEFT", 16, -14)
	c.title:SetText(title)
	c.big = Theme.Text(c, "hero", "text")
	c.big:SetPoint("TOPLEFT", 16, -40)
	c.caption = Theme.Text(c, "small", "textDim")
	c.caption:SetPoint("TOPLEFT", 16, -72)
	c.caption:SetPoint("RIGHT", -16, 0)
	c.caption:SetJustifyH("LEFT")
	c.caption:SetWordWrap(false)
	function c:SetBig(big, caption, color)
		self.big:SetText(big or "")
		self.big:SetTextColor(Theme.RGB(color or "text"))
		self.caption:SetText(caption or "")
	end
	function c:SetButton(text, onClick, tooltip)
		local b = W.Button(self, text, 72, 28, onClick, { style = "ghost" })
		W.FitWidth(b)
		b:SetPoint("BOTTOMLEFT", 16, 16)
		b.tooltip = tooltip
		self.button = b
		return b
	end
	return c
end

---------------------------------------------------------------------------
-- Empty state: a 32 px glyph, a title and one line saying what to do next.
---------------------------------------------------------------------------
function W.EmptyState(parent, icon, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width or 300, 100)
	f.glyph = Theme.Glyph(f, icon, 32, "textMuted")
	f.glyph:SetPoint("TOP")
	f.title = Theme.Text(f, "title", "text")
	f.title:SetPoint("TOP", f.glyph, "BOTTOM", 0, -12)
	f.text = Theme.Text(f, "body", "textDim")
	f.text:SetPoint("TOP", f.title, "BOTTOM", 0, -6)
	f.text:SetWidth(width or 300)
	f.text:SetJustifyH("CENTER")
	function f:Set(title, text, icon2)
		self.title:SetText(title or "")
		self.text:SetText(text or "")
		if icon2 then self.glyph:SetTexture(Theme.Icon(icon2)) end
	end
	return f
end

---------------------------------------------------------------------------
-- Chip: a small outlined word in one status colour (18 px).
---------------------------------------------------------------------------
function W.Chip(parent, text, color)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(18)
	Theme.Hairline(f, color or "textMuted")
	f.text = Theme.Text(f, "small", color or "textMuted")
	f.text:SetPoint("CENTER")
	function f:Set(t, c)
		self.text:SetText(t)
		self.text:SetTextColor(Theme.RGB(c or "textMuted"))
		Theme.SetBorderColor(self, c or "textMuted")
		self:SetWidth(math.ceil(self.text:GetStringWidth()) + 12)
	end
	f:Set(text, color)
	return f
end
