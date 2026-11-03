-- Debug window: a copyable text box showing the /sk debug report.
-- The report is also saved in ShortKingsDB.lastReport so it can be read
-- from the SavedVariables file after logging out.
local _, SK = ...

local Debug = SK:NewModule("DebugWindow")
local Theme, W = SK.Theme, SK.Widgets
local S, SP = Theme.SIZES, Theme.SPACE

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
	Theme.Panel(f, { bg = "void", border = "line" })
	tinsert(UISpecialFrames, "ShortKingsDebugFrame")

	local title = Theme.Text(f, "heading", "text")
	f.title = title
	title:SetPoint("TOPLEFT", SP.l, -SP.l)
	local hint = Theme.Text(f, "small", "dim")
	hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -SP.xs)
	hint:SetText("Click the text, press Ctrl+A (Cmd+A on Mac) then Ctrl+C (Cmd+C) to copy it.")
	local close = W.CloseButton(f, function() f:Hide() end)
	close:SetPoint("TOPRIGHT", -SP.s, -SP.s)

	local scroll = CreateFrame("ScrollFrame", nil, f)
	scroll:SetPoint("TOPLEFT", SP.l, -56)
	scroll:SetPoint("BOTTOMRIGHT", -SP.l, S.control + SP.l * 2)
	local bg = scroll:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	Theme.Solid(bg, "surface")
	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetWidth(600)
	edit:SetTextInsets(SP.s, SP.s, SP.s, SP.s)
	Theme.Font(edit, "small", "text")
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
	edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(Debug.text or "") end end)
	scroll:SetScrollChild(edit)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, edit:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40)))
	end)
	f.edit = edit

	local refresh = W.Button(f, "Refresh", nil, S.control, function() Debug:Open() end)
	f.refresh = refresh
	refresh:SetPoint("BOTTOMLEFT", SP.l, SP.l)
	local log = W.Button(f, "Show log", nil, S.control, function() Debug:Open(true) end)
	log:SetPoint("LEFT", refresh, "RIGHT", SP.s, 0)
	f.log = log
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
	f.title:SetText("SHORT KINGS DEBUG REPORT")
	f.refresh:Show()
	f.log:Show()
	f.edit:SetText(self.text)
	f.edit:SetCursorPosition(0)
	f:Show()
end

-- "Copy as text": the same copyable window with any plain text.
function Debug:ShowText(title, text)
	self.text = text
	local f = self:Build()
	f.title:SetText(title:upper())
	f.refresh:Hide()
	f.log:Hide()
	f.edit:SetText(text)
	f.edit:SetCursorPosition(0)
	f:Show()
	if f.edit.HighlightText then f.edit:SetFocus(); f.edit:HighlightText() end
end
