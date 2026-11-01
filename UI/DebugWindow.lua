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
	Theme.Panel(f)
	tinsert(UISpecialFrames, "ShortKingsDebugFrame")

	local title = Theme.Text(f, 16, "pink")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText("Short Kings debug report")
	local hint = Theme.Text(f, 11, "muted")
	hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	hint:SetText("Click the text, press Ctrl+A (Cmd+A on Mac) then Ctrl+C to copy it.")
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

	local scroll = CreateFrame("ScrollFrame", nil, f)
	scroll:SetPoint("TOPLEFT", 14, -50)
	scroll:SetPoint("BOTTOMRIGHT", -14, 44)
	local bg = scroll:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	Theme.Solid(bg, "plumDark", 0.8)
	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetWidth(600)
	Theme.Font(edit, 11, "text")
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
	edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(Debug.text or "") end end)
	scroll:SetScrollChild(edit)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, edit:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40)))
	end)
	f.edit = edit

	local refresh = W.Button(f, "Refresh", 90, 22, function() Debug:Open() end)
	refresh:SetPoint("BOTTOMLEFT", 14, 12)
	local log = W.Button(f, "Show log", 90, 22, function() Debug:Open(true) end)
	log:SetPoint("LEFT", refresh, "RIGHT", 8, 0)
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
	f.edit:SetText(self.text)
	f.edit:SetCursorPosition(0)
	f:Show()
end
