-- Minimap button: LibDBIcon when the packager included it, otherwise a
-- simple built-in button that can be dragged around the minimap.
local _, SK = ...

local MM = SK:NewModule("Minimap")
local Theme = SK.Theme

MM.ICON = "Interface\\Icons\\INV_Misc_Bomb_04"

local function onClick(_, button)
	if button == "RightButton" then
		SK.MainFrame:Show("settings")
	else
		SK.MainFrame:Toggle()
	end
end

local function onTooltip(tt)
	Theme.TipLine(tt, "Short Kings", "gold")
	Theme.TipLine(tt, "Small in stature. Big in loot.", "dim")
	Theme.TipLine(tt, "Left-click: open / close", "text")
	Theme.TipLine(tt, "Right-click: settings", "text")
end

-- Built-in fallback button.
local function createFallback(settings)
	local b = CreateFrame("Button", "ShortKingsMinimapButton", Minimap)
	b:SetSize(32, 32)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")
	icon:SetTexture(MM.ICON)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local ring = b:CreateTexture(nil, "OVERLAY")
	ring:SetSize(54, 54)
	ring:SetPoint("TOPLEFT")
	ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local function place()
		local angle = math.rad(settings.minimapPos or 210)
		local radius = (Minimap:GetWidth() / 2) + 6
		b:ClearAllPoints()
		b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
	end
	b:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			settings.minimapPos = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
			place()
		end)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		onTooltip(GameTooltip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	place()
	return b
end

function MM:OnLogin()
	local settings = SK.DB.settings.minimap
	local LDB = LibStub("LibDataBroker-1.1", true)
	local DBIcon = LibStub("LibDBIcon-1.0", true)
	if LDB and DBIcon then
		local obj = LDB:NewDataObject("ShortKings", {
			type = "launcher", text = "Short Kings", icon = MM.ICON,
			OnClick = onClick, OnTooltipShow = onTooltip,
		})
		DBIcon:Register("ShortKings", obj, settings)
		self.lib = DBIcon
		self.mode = "LibDBIcon"
	else
		self.button = createFallback(settings)
		self.button:SetShown(not settings.hide)
		self.mode = "built-in"
	end
end

function MM:SetShown(show)
	local settings = SK.DB.settings.minimap
	settings.hide = not show
	if self.lib then
		if show then self.lib:Show("ShortKings") else self.lib:Hide("ShortKings") end
	elseif self.button then
		self.button:SetShown(show)
	end
end
