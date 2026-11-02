-- Debug window: a copyable text box showing the /sk debug report.
-- The report is also saved in ShortKingsDB.lastReport so it can be read
-- from the SavedVariables file after logging out.
local _, SK = ...

local Debug = SK:NewModule("DebugWindow")
local Theme, W = SK.Theme, SK.Widgets

function Debug:Build()
	if self.frame then return self.frame end
	local f = CreateFrame("Frame", "ShortKingsDebugFrame", UIParent)
	f:SetSize(640, 460)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	Theme.Shadow(f)
	Theme.Panel(f, { tone = "bg" })
	tinsert(UISpecialFrames, "ShortKingsDebugFrame")

	-- Header band (same recipe as the main window, 56 px).
	local band = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	band:SetPoint("TOPLEFT")
	band:SetPoint("TOPRIGHT")
	band:SetHeight(56)
	Theme.Gradient(band, "VERTICAL", "bg", "sky")
	local glow = f:CreateTexture(nil, "BACKGROUND", nil, 2)
	glow:SetPoint("TOPLEFT")
	glow:SetSize(640 * 0.6, 56)
	Theme.Gradient(glow, "HORIZONTAL", "brand", "brand", 0.22, 0)
	local fuse = f:CreateTexture(nil, "ARTWORK")
	fuse:SetPoint("TOPLEFT", 0, -55)
	fuse:SetSize(640 * 0.4, 1)
	SK.Compat.PixelHeight(fuse, 1)
	Theme.Gradient(fuse, "HORIZONTAL", "ember", "warning", 0, 0.9)

	local title = Theme.Text(f, "title", "text")
	f.title = title
	title:SetPoint("TOPLEFT", 24, -12)
	title:SetText("Short Kings debug report")
	local hint = Theme.Text(f, "small", "textDim")
	hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	hint:SetText("Click the text, press Ctrl+A (Cmd+A on Mac) then Ctrl+C to copy it.")
	local close = W.IconButton(f, "close", 24, function() f:Hide() end, "Close (Esc)")
	close:SetPoint("TOPRIGHT", -12, -12)

	local box = CreateFrame("Frame", nil, f)
	box:SetPoint("TOPLEFT", 24, -72)
	box:SetPoint("BOTTOMRIGHT", -24, 60)
	Theme.Panel(box, { tone = "sidebar" })
	local scroll = CreateFrame("ScrollFrame", nil, box)
	scroll:SetPoint("TOPLEFT", 12, -12)
	scroll:SetPoint("BOTTOMRIGHT", -12, 12)
	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetWidth(568)
	Theme.Font(edit, "label", "textDim")
	edit:SetScript("OnEditFocusGained", function() Theme.SetBorderColor(box, "accent", 0.8) end)
	edit:SetScript("OnEditFocusLost", function() Theme.SetBorderColor(box, nil) end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
	edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(Debug.text or "") end end)
	scroll:SetScrollChild(edit)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, edit:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40)))
	end)
	f.edit = edit

	local refresh = W.Button(f, "Refresh", 90, 28, function() Debug:Open() end, { icon = "refresh" })
	W.FitWidth(refresh)
	f.refresh = refresh
	refresh:SetPoint("BOTTOMLEFT", 24, 16)
	local log = W.Button(f, "Show log", 90, 28, function() Debug:Open(true) end, { style = "ghost" })
	W.FitWidth(log)
	log:SetPoint("LEFT", refresh, "RIGHT", 8, 0)
	f.log = log
	f.saved = Theme.Text(f, "small", "textMuted")
	f.saved:SetPoint("BOTTOMRIGHT", -24, 26)
	f.saved:SetText("Also saved to your SavedVariables file")
	self.frame = f
	return f
end

function Debug:Open(withLog)
	local lines = SK.Commands.BuildReport()
	if withLog then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Log (oldest first) =="
		for _, l in ipairs(SK:GetLog()) do lines[#lines + 1] = l end
	end
	self.text = table.concat(lines, "\n")
	local f = self:Build()
	f.title:SetText("Short Kings debug report")
	f.refresh:Show()
	f.log:Show()
	f.saved:Show()
	f.edit:SetText(self.text)
	f.edit:SetCursorPosition(0)
	f:Show()
end

-- "Copy as text": the same copyable window with any plain text.
function Debug:ShowText(title, text)
	self.text = text
	local f = self:Build()
	f.title:SetText(title)
	f.refresh:Hide()
	f.log:Hide()
	f.saved:Hide()
	f.edit:SetText(text)
	f.edit:SetCursorPosition(0)
	f:Show()
	Theme.FadeIn(f)
	if f.edit.HighlightText then f.edit:SetFocus(); f.edit:HighlightText() end
end
