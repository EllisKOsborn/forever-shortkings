-- Widgets: themed buttons, tabs, check boxes, a search box, a virtual
-- (recycling) list with sortable columns, and a scrollable text panel.
-- Only core widget types are used (Frame, Button, Slider, EditBox,
-- ScrollFrame, CheckButton), no Blizzard templates except the close button.
local _, SK = ...

local W = {}
SK.Widgets = W
local Theme = SK.Theme

---------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------
function W.Button(parent, text, width, height, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 100, height or 22)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	Theme.Gradient(bg, "VERTICAL", "plumDark", "plumLift")
	Theme.Border(b, 1, false)
	b.label = Theme.Text(b, 12, "text")
	b.label:SetPoint("CENTER")
	b.label:SetText(text)
	b:SetScript("OnEnter", function(self)
		-- A disabled button still explains itself (disabledTooltip).
		local tip = self.disabled and self.disabledTooltip or (not self.disabled and self.tooltip)
		if not self.disabled then
			self.label:SetTextColor(Theme.RGB("flame"))
			Theme.SetBorderColor(self, "ember")
		end
		if tip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(tip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		if not self.active then self.label:SetTextColor(Theme.RGB(self.disabled and "muted" or "text")) end
		Theme.SetBorderColor(self, self.active and "ember" or "leather")
		GameTooltip:Hide()
	end)
	b:SetScript("OnMouseDown", function(self) self.label:SetPoint("CENTER", 1, -1) end)
	b:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
	if onClick then b:SetScript("OnClick", function(self, ...) if not self.disabled then onClick(self, ...) end end) end
	function b:SetText(t) self.label:SetText(t) end
	function b:SetDisabled(flag)
		self.disabled = flag
		self.label:SetTextColor(Theme.RGB(flag and "muted" or "text"))
	end
	return b
end

---------------------------------------------------------------------------
-- Tab (a button with an "active" state: ember underline, flame text)
---------------------------------------------------------------------------
function W.Tab(parent, text, onClick)
	local t = W.Button(parent, text, 110, 26, onClick)
	t.underline = t:CreateTexture(nil, "ARTWORK")
	t.underline:SetPoint("BOTTOMLEFT", 2, 2)
	t.underline:SetPoint("BOTTOMRIGHT", -2, 2)
	t.underline:SetHeight(2)
	Theme.Gradient(t.underline, "HORIZONTAL", "ember", "flame")
	t.underline:Hide()
	function t:SetActive(flag)
		self.active = flag
		self.underline:SetShown(flag)
		self.label:SetTextColor(Theme.RGB(flag and "flame" or "text"))
		Theme.SetBorderColor(self, flag and "ember" or "leather")
	end
	t:SetWidth(math.max(90, t.label:GetStringWidth() + 28))
	return t
end

---------------------------------------------------------------------------
-- Check box with label
---------------------------------------------------------------------------
function W.Check(parent, label, getter, setter)
	local c = CreateFrame("CheckButton", nil, parent)
	c:SetSize(18, 18)
	local box = c:CreateTexture(nil, "BACKGROUND")
	box:SetAllPoints()
	Theme.Solid(box, "plumDark")
	Theme.Border(c, 1, false)
	local tick = c:CreateTexture(nil, "ARTWORK")
	tick:SetPoint("TOPLEFT", 4, -4)
	tick:SetPoint("BOTTOMRIGHT", -4, 4)
	Theme.Gradient(tick, "VERTICAL", "ember", "flame")
	c:SetCheckedTexture(tick)
	c.label = Theme.Text(c, 12, "text")
	c.label:SetPoint("LEFT", c, "RIGHT", 8, 0)
	c.label:SetText(label)
	c:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
	c:SetScript("OnEnter", function(self) Theme.SetBorderColor(self, "ember") end)
	c:SetScript("OnLeave", function(self) Theme.SetBorderColor(self, "leather") end)
	function c:Refresh() self:SetChecked(getter() and true or false) end
	c:Refresh()
	return c
end

---------------------------------------------------------------------------
-- Menu: a button that opens a small themed pop-up list (no Blizzard
-- dropdown templates). opts = {
--   width = 150, items = function() return { {value=, text=}, ... } end,
--   get = function() return value end, set = function(value) end,
-- }
---------------------------------------------------------------------------
local openMenu

function W.Menu(parent, opts)
	local width = opts.width or 150
	local b = W.Button(parent, "", width, 22)
	local arrow = Theme.Text(b, 10, "muted")
	arrow:SetPoint("RIGHT", -6, 0)
	arrow:SetText("v")
	b.label:ClearAllPoints()
	b.label:SetPoint("LEFT", 8, 0)
	b.label:SetPoint("RIGHT", -16, 0)
	b.label:SetJustifyH("LEFT")
	b.label:SetWordWrap(false)

	local pop = CreateFrame("Frame", nil, b)
	pop:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
	pop:SetWidth(width)
	pop:SetFrameStrata("FULLSCREEN_DIALOG")
	pop:EnableMouse(true)
	Theme.Panel(pop, { thickness = 1, gold = false })
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
		for i, it in ipairs(items) do
			local e = pop.entries[i]
			if not e then
				e = CreateFrame("Button", nil, pop)
				e:SetHeight(20)
				e:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 20)
				e:SetPoint("TOPRIGHT", -2, -2 - (i - 1) * 20)
				local hl = e:CreateTexture(nil, "HIGHLIGHT")
				hl:SetAllPoints()
				Theme.Gradient(hl, "HORIZONTAL", "ember", "flame", 0.3, 0.05)
				e.text = Theme.Text(e, 12, "text")
				e.text:SetPoint("LEFT", 8, 0)
				e:SetScript("OnClick", function(self)
					b:Close()
					opts.set(self.value)
					b:Refresh()
				end)
				pop.entries[i] = e
			end
			e.value = it.value
			e.text:SetText(it.text)
			e.text:SetTextColor(Theme.RGB(it.value == current and "flame" or "text"))
			e:Show()
		end
		for i = #items + 1, #pop.entries do pop.entries[i]:Hide() end
		pop:SetHeight(#items * 20 + 4)
		pop:Show()
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
-- Search box
---------------------------------------------------------------------------
function W.SearchBox(parent, width, placeholder, onChange)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(width, 22)
	e:SetAutoFocus(false)
	e:SetMaxLetters(60)
	e:SetTextInsets(8, 8, 0, 0)
	Theme.Font(e, 12, "text")
	local bg = e:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	Theme.Solid(bg, "plumDark")
	Theme.Border(e, 1, false)
	local hint = Theme.Text(e, 12, "muted")
	hint:SetPoint("LEFT", 8, 0)
	hint:SetText(placeholder)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEditFocusGained", function(self) Theme.SetBorderColor(self, "ember") end)
	e:SetScript("OnEditFocusLost", function(self) Theme.SetBorderColor(self, "leather") end)
	e:SetScript("OnTextChanged", function(self)
		local text = self:GetText() or ""
		hint:SetShown(text == "")
		onChange(text)
	end)
	return e
end

---------------------------------------------------------------------------
-- Vertical scroll bar (core Slider) shared by List and TextPanel
---------------------------------------------------------------------------
local function ScrollBar(parent, onValue)
	local s = CreateFrame("Slider", nil, parent)
	s:SetOrientation("VERTICAL")
	s:SetWidth(10)
	s:SetMinMaxValues(0, 0)
	s:SetValueStep(1)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	local track = s:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	Theme.Solid(track, "plumDark", 0.9)
	s:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
	local thumb = s:GetThumbTexture()
	thumb:SetSize(10, 30)
	thumb:SetVertexColor(Theme.RGB("magenta"))
	s:SetScript("OnValueChanged", function(_, v) onValue(math.floor(v + 0.5)) end)
	return s
end

---------------------------------------------------------------------------
-- List: virtual rows + sortable header.
-- opts = {
--   columns = { { key=, title=, width=, align="LEFT", sort=function(a,b) } },
--   rowHeight = 20,
--   setCell = function(fontString, item, column) end,  -- fill a cell
--   onClick = function(item, button) end,
--   onEnter = function(row, item) end,                  -- optional tooltip
--   decorate = function(row) end,                       -- optional: add widgets to a new row
--   update = function(row, item) end,                   -- optional: after a row is filled
-- }
---------------------------------------------------------------------------
function W.List(parent, opts)
	local list = CreateFrame("Frame", nil, parent)
	list.opts = opts
	list.items, list.offset = {}, 0
	local rowH = opts.rowHeight or 20

	-- header
	local header = CreateFrame("Frame", nil, list)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT", -12, 0)
	header:SetHeight(22)
	local hbg = header:CreateTexture(nil, "BACKGROUND")
	hbg:SetAllPoints()
	Theme.Gradient(hbg, "VERTICAL", "plumDark", "magenta", 1, 0.35)
	list.header = header
	local x = 4
	list.headerButtons = {}
	for i, col in ipairs(opts.columns) do
		local hb = CreateFrame("Button", nil, header)
		hb:SetPoint("LEFT", x, 0)
		hb:SetSize(col.width, 22)
		hb.text = Theme.Text(hb, 12, "pink")
		hb.text:SetPoint(col.align or "LEFT", col.align == "RIGHT" and -4 or 4, 0)
		hb.text:SetText(col.title)
		if col.sort then
			hb:SetScript("OnClick", function()
				if list.sortCol == i then list.sortDesc = not list.sortDesc else list.sortCol, list.sortDesc = i, false end
				list:Sort()
			end)
			hb:SetScript("OnEnter", function(self) self.text:SetTextColor(Theme.RGB("flame")) end)
			hb:SetScript("OnLeave", function(self) self.text:SetTextColor(Theme.RGB("pink")) end)
		end
		list.headerButtons[i] = hb
		x = x + col.width
	end

	-- scroll bar
	local bar = ScrollBar(list, function(v) list.offset = v; list:Draw() end)
	bar:SetPoint("TOPRIGHT", 0, -22)
	bar:SetPoint("BOTTOMRIGHT")
	list.bar = bar

	list.rows = {}
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta)
		bar:SetValue(math.max(0, list.offset - delta * 3))
	end)

	function list:RowCount()
		return math.max(1, math.floor((self:GetHeight() - 22) / rowH))
	end

	function list:EnsureRows()
		local need = self:RowCount()
		for i = #self.rows + 1, need do
			local row = CreateFrame("Button", nil, self)
			row:SetHeight(rowH)
			row:SetPoint("TOPLEFT", 0, -22 - (i - 1) * rowH)
			row:SetPoint("TOPRIGHT", -12, -22 - (i - 1) * rowH)
			row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			local bg = row:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			Theme.Solid(bg, "plumLift", (i % 2 == 0) and 0.35 or 0.15)
			local hl = row:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints()
			Theme.Gradient(hl, "HORIZONTAL", "ember", "flame", 0.25, 0.05)
			row.sel = row:CreateTexture(nil, "BORDER")
			row.sel:SetAllPoints()
			Theme.Gradient(row.sel, "HORIZONTAL", "magenta", "plum", 0.45, 0.05)
			row.sel:Hide()
			row.cells = {}
			local cx = 4
			for c, col in ipairs(opts.columns) do
				local fs = Theme.Text(row, 12, "text")
				fs:SetWidth(col.width - 8)
				fs:SetJustifyH(col.align or "LEFT")
				fs:SetWordWrap(false)
				fs:SetPoint("LEFT", cx + 4, 0)
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
		self:Draw()
	end

	-- Optional: isSelected(item) -> bool marks rows with a steady highlight.
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
				row.sel:SetShown(self.isSelected ~= nil and self.isSelected(item) and true or false)
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
function W.TextPanel(parent)
	local panel = CreateFrame("ScrollFrame", nil, parent)
	local child = CreateFrame("Frame", nil, panel)
	child:SetSize(10, 10)
	panel:SetScrollChild(child)
	local fs = Theme.Text(child, 12, "text")
	fs:SetPoint("TOPLEFT")
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetSpacing(3)
	panel.fs = fs
	local bar = ScrollBar(panel, function(v) panel:SetVerticalScroll(v) end)
	bar:SetPoint("TOPRIGHT", 12, 0)
	bar:SetPoint("BOTTOMRIGHT", 12, 0)
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
