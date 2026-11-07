-- "Crafted by" on every item tooltip: guild members who can make the item,
-- online first, at most three names. Index lookups only (no scanning), so
-- it stays cheap. Turned off in Settings with "Show guild crafters in item
-- tooltips".
local _, SK = ...

local Tip = SK:NewModule("Tooltip")
Tip.hooked = false

function Tip.Add(tooltip, itemID)
	if not SK.DB or not SK.DB.settings.craftTooltips then return end
	if tooltip.IsEmbedded then return end
	local guild = SK.DBM:Guild()
	if not guild then return end
	local text = SK.CraftIndex.TooltipText(SK.CraftIndex:Get(true), itemID, guild, SK.Compat.Now(), 3)
	if text then
		SK.Theme.TipLine(tooltip, SK.Theme.Code("beard") .. "Short Royalty:|r " .. text, "text", true)
	end
end

function Tip:OnLogin()
	self.hooked = SK.Compat.HookItemTooltips(Tip.Add)
	if not self.hooked then SK:Debug("item tooltip hook not available on this client") end
end
