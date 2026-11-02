-- Character tab: paperdoll-style gear with real item tooltips, plus
-- talents, professions, cooldowns, reputations and attunements.
local _, SK = ...

local Char = SK:NewModule("CharacterTab")
local Theme, W, Compat = SK.Theme, SK.Widgets, SK.Compat

local SLOT_NAMES = {
	[1] = "Head", [2] = "Neck", [3] = "Shoulder", [15] = "Back", [5] = "Chest", [4] = "Shirt",
	[19] = "Tabard", [9] = "Wrist", [10] = "Hands", [6] = "Waist", [7] = "Legs", [8] = "Feet",
	[11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket",
	[16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged",
}
local INV_SLOT_KEYS = {
	[1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [15] = "BackSlot", [5] = "ChestSlot",
	[4] = "ShirtSlot", [19] = "TabardSlot", [9] = "WristSlot", [10] = "HandsSlot", [6] = "WaistSlot",
	[7] = "LegsSlot", [8] = "FeetSlot", [11] = "Finger0Slot", [12] = "Finger1Slot",
	[13] = "Trinket0Slot", [14] = "Trinket1Slot", [16] = "MainHandSlot", [17] = "SecondaryHandSlot",
	[18] = "RangedSlot",
}
local LEFT = { 1, 2, 3, 15, 5, 4, 19, 9 }
local RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14 }
local BOTTOM = { 16, 17, 18 }

-- A warning square before "missing enchants" (shape as well as colour).
local WARN_SQUARE = (function()
	local r, g, b = Theme.RGB("warning")
	return string.format("|T%s:8:8:0:0:8:8:0:8:0:8:%d:%d:%d|t", Theme.WHITE, r * 255, g * 255, b * 255)
end)()

local STANDING = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
local function standingName(r)
	return (_G["FACTION_STANDING_LABEL" .. tostring(r)]) or STANDING[r] or "?"
end

local function emptySlotTexture(slot)
	if GetInventorySlotInfo and INV_SLOT_KEYS[slot] then
		local ok, _, tex = pcall(GetInventorySlotInfo, INV_SLOT_KEYS[slot])
		if ok and tex then return tex end
	end
	return nil
end

local function qualityColor(link)
	local hex = type(link) == "string" and link:match("^|c(%x%x%x%x%x%x%x%x)")
	if hex then
		return tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
	end
	return nil
end

local function slotButton(parent, slot)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(36, 36)
	b.slot = slot
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	Theme.Solid(bg, "sidebar")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	Theme.Hairline(b) -- recoloured to the item's quality
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	Theme.Wash(hl, "hover")
	-- Missing-enchant marker: a 12 px warning square on the corner (a shape,
	-- not just a colour; the details also say "missing enchants").
	b.warn = b:CreateTexture(nil, "OVERLAY")
	b.warn:SetSize(12, 12)
	b.warn:SetPoint("TOPRIGHT", 3, 3)
	Theme.Solid(b.warn, "warning")
	b.warn:Hide()
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.link then
			GameTooltip:SetHyperlink(self.link)
			if self.missingEnchant then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine("Short Kings: no enchant on this item", Theme.RGB("warning"))
				GameTooltip:Show()
			end
		else
			GameTooltip:SetText(SLOT_NAMES[self.slot] or "Empty")
			GameTooltip:AddLine("Empty", Theme.RGB("textMuted"))
		end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self)
		if self.link and HandleModifiedItemClick then HandleModifiedItemClick(self.link) end
	end)
	function b:SetItem(link, missingEnchant)
		self.link = link
		self.missingEnchant = missingEnchant
		self.warn:SetShown(missingEnchant and true or false)
		local icon = link and Compat.ItemIcon(link)
		if icon then
			self.icon:SetTexture(icon)
			self.icon:SetDesaturated(false)
			self.icon:SetAlpha(1)
		else
			self.icon:SetTexture(emptySlotTexture(self.slot) or "Interface\\Buttons\\WHITE8X8")
			self.icon:SetAlpha(link and 1 or 0.35)
		end
		local r, g, bl = qualityColor(link)
		if r then
			for _, t in ipairs(self.border) do t:SetColorTexture(r, g, bl, 1) end
		else
			Theme.SetBorderColor(self, nil)
		end
	end
	return b
end

function Char:Build(page, tools)
	tools = tools or page
	-- Toolbar
	self.back = W.Button(tools, "Roster", 72, 28, function() SK.MainFrame:Select("roster") end,
		{ style = "ghost", icon = "chevronLeft" })
	W.FitWidth(self.back, 0)
	self.back:SetPoint("LEFT", 0, 0)
	self.mine = W.Button(tools, "Me", 56, 28, function() Char:ShowCharacter(nil) end, { style = "ghost" })
	self.mine:SetPoint("LEFT", self.back, "RIGHT", 8, 0)
	self.mine.tooltip = "Show your own character"
	self.whisper = W.Button(tools, "Whisper", 72, 28, function()
		local target = Char.guid and SK.Identity:WhisperTarget(Char.guid)
		if target then Compat.SendTell(target) end
	end, { icon = "whisper" })
	W.FitWidth(self.whisper)
	self.whisper:SetPoint("LEFT", self.mine, "RIGHT", 8, 0)
	self.askLatest = W.Button(tools, "Ask for latest", 110, 28, function()
		local guid = Char.shownGuid
		if not guid then return end
		local ok, why = SK.Sync:RequestFresh(guid)
		if ok then
			Char.asked[guid] = Compat.Now()
			SK.After(SK.Sync.FRESH_INTERVAL, function() Char:Refresh() end)
		elseif why == "wait" then
			SK:Print("Already asked. Give it a few seconds.")
		end
		Char:Refresh()
	end, { icon = "refresh" })
	W.FitWidth(self.askLatest)
	self.askLatest.tooltip = "Ask them (or their online alt) for their newest data"
	self.askLatest.disabledTooltip = "Offline: showing their last known data"
	self.askLatest:SetPoint("LEFT", self.whisper, "RIGHT", 8, 0)
	self.makeMain = W.Button(tools, "Make this my main", 140, 28, function()
		if Char.shownGuid then SK.Profile:SetMain(Char.shownGuid); Char:Refresh() end
	end)
	W.FitWidth(self.makeMain)
	self.makeMain.tooltip = "Your main is shown first when alts are grouped in the Roster."
	self.makeMain:SetPoint("LEFT", self.mine, "RIGHT", 8, 0)

	-- Who this is
	self.name = Theme.Text(page, "display", "text")
	self.name:SetPoint("TOPLEFT", 0, 0)
	self.info = Theme.Text(page, "body", "textDim")
	self.info:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -4)
	self.meta = Theme.Text(page, "small", "textMuted")
	self.meta:SetPoint("TOPLEFT", self.info, "BOTTOMLEFT", 0, -4)
	self.meta:SetPoint("RIGHT", page, "RIGHT", 0, 0)
	self.meta:SetJustifyH("LEFT")
	self.meta:SetWordWrap(false)

	-- Paper doll: 264 x 364 raised panel, 36 px slots 40 px apart.
	local doll = CreateFrame("Frame", nil, page)
	doll:SetPoint("TOPLEFT", 0, -64)
	doll:SetSize(264, 364)
	Theme.Panel(doll, { tone = "panel" })
	self.doll = doll
	self.slots = {}
	for i, slot in ipairs(LEFT) do
		local b = slotButton(doll, slot)
		b:SetPoint("TOPLEFT", 12, -12 - (i - 1) * 40)
		self.slots[slot] = b
	end
	for i, slot in ipairs(RIGHT) do
		local b = slotButton(doll, slot)
		b:SetPoint("TOPRIGHT", -12, -12 - (i - 1) * 40)
		self.slots[slot] = b
	end
	for i, slot in ipairs(BOTTOM) do
		local b = slotButton(doll, slot)
		b:SetPoint("TOPLEFT", 64 + (i - 1) * 48, -316)
		self.slots[slot] = b
	end
	self.ilvl = Theme.Text(doll, "hero", "text")
	self.ilvl:SetPoint("TOP", 0, -96)
	self.ilvlLabel = Theme.Text(doll, "small", "textDim")
	self.ilvlLabel:SetPoint("TOP", self.ilvl, "BOTTOM", 0, -4)
	self.ilvlLabel:SetText("average item level")
	self.specText = Theme.Text(doll, "body", "text")
	self.specText:SetPoint("TOP", self.ilvlLabel, "BOTTOM", 0, -18)
	self.specText:SetWidth(150)
	self.specText:SetSpacing(3)
	self.enchantText = Theme.Text(doll, "small", "warning")
	self.enchantText:SetPoint("TOP", self.specText, "BOTTOM", 0, -16)
	self.enchantText:SetWidth(150)

	-- Details in two 264 px columns.
	self.details = W.TextPanel(page, "body", 6)
	self.details:SetPoint("TOPLEFT", doll, "TOPRIGHT", 16, 0)
	self.details:SetSize(264, 364)
	self.details2 = W.TextPanel(page, "body", 6)
	self.details2:SetPoint("TOPLEFT", self.details, "TOPRIGHT", 16, 0)
	self.details2:SetPoint("BOTTOMRIGHT", -8, 0)

	self.empty = W.EmptyState(page, "character", 400)
	self.empty:SetPoint("TOP", 0, -140)
	self.empty:Hide()
end

Char.asked = {}    -- guid -> when we pressed "Ask for latest" (cleared by the answer)
Char.answered = {} -- guid -> when the answer arrived

SK:On("PROFILE_ANSWERED", function(guid)
	if Char.asked[guid] then
		Char.asked[guid] = nil
		Char.answered[guid] = Compat.Now()
		if guid == Char.shownGuid then Char:Refresh() end
	end
end)

-- Status line for "Ask for latest". Pure; tested.
function Char.AskStatus(askedAt, answeredAt, now, timeout)
	if askedAt then
		if now - askedAt < timeout then return "Asked for the latest data…" end
		return "No answer yet: showing their last known data"
	end
	if answeredAt and now - answeredAt < 60 then return "Got their latest data" end
	return nil
end

-- With no data at all, a calm empty state replaces the doll and details.
function Char:ShowEmpty(on)
	self.empty:SetShown(on)
	self.empty:Set("No Short Kings data yet", "They may not have the addon, or be on a trial account (trials can't sync).")
	for _, r in ipairs({ self.details, self.details2 }) do r:SetShown(not on) end
	self.doll:SetShown(not on)
end

function Char:ShowCharacter(guid)
	self.guid = guid
	SK.MainFrame:Show("character")
end

-- Detail sections: { title=, lines={...}, column=1|2 }. Pure-ish; uses
-- only the profile (and spell names for cooldowns).
function Char.DetailSections(p, now, extra)
	local C = Theme.Code
	extra = extra or {}
	local out = {}
	local function section(title, column)
		local s = { title = title, lines = {}, column = column }
		out[#out + 1] = s
		return s.lines
	end
	local function pair(label, value) return label .. "  " .. (value or "") end

	if extra.alts and #extra.alts > 0 then
		local L = section(extra.isMain and "Alts" or "Same player", 1)
		for _, a in ipairs(extra.alts) do
			L[#L + 1] = Theme.ClassText(a.name, a.class) .. (a.isMain and (C("textMuted") .. "  (main)|r") or "")
		end
	end
	if (extra.note and extra.note ~= "") or (extra.officerNote and extra.officerNote ~= "") then
		local L = section("Notes", 1)
		if extra.note and extra.note ~= "" then L[#L + 1] = C("textDim") .. extra.note .. "|r" end
		if extra.officerNote and extra.officerNote ~= "" then
			L[#L + 1] = C("warning") .. "Officer: |r" .. extra.officerNote
		end
	end
	local hidden = p.hidden or {}
	-- Talents
	local T = section("Talents", 1)
	if hidden.gear then
		T[#T + 1] = C("textMuted") .. "hidden by this player|r"
	elseif p.talents and p.talents.trees then
		for _, t in ipairs(p.talents.trees) do
			T[#T + 1] = pair(C("textDim") .. (t.n or "?") .. "|r", tostring(t.p or 0))
		end
	else
		T[#T + 1] = C("textMuted") .. "not available|r"
	end
	-- Cooldowns
	local cds = {}
	for id, expires in pairs(p.cds or {}) do cds[#cds + 1] = { id = id, at = expires } end
	if #cds > 0 then
		local L = section("Cooldowns", 1)
		table.sort(cds, function(a, b) return a.at < b.at end)
		for _, cd in ipairs(cds) do
			local left = cd.at - now
			local name = Compat.SpellName(cd.id) or ("Recipe " .. cd.id)
			local when = left <= 0 and ("|A:UI-LFG-ReadyMark:12:12|a " .. C("success") .. "ready|r") or
				string.format("%s%dh %dm|r", C("textDim"), math.floor(left / 3600), math.floor(left % 3600 / 60))
			L[#L + 1] = pair(name, when)
		end
	end
	-- Professions
	local P = section("Professions", 2)
	local profs = {}
	for skillLine, pr in pairs(p.profs or {}) do profs[#profs + 1] = { id = skillLine, pr = pr } end
	table.sort(profs, function(a, b) return (a.pr.name or "") < (b.pr.name or "") end)
	if #profs == 0 then P[#P + 1] = C("textMuted") .. "none|r" end
	for _, e in ipairs(profs) do
		local pr = e.pr
		local recipes = p.recipes and p.recipes[e.id]
		local note
		if SK.Data.GATHERING[e.id] then
			note = ""
		elseif hidden.recipes then
			note = "  " .. C("textMuted") .. "recipes hidden|r"
		elseif pr.scanned then
			note = string.format("  %s%d recipes|r", C("textMuted"), SK.Count(recipes))
		else
			note = "  " .. C("warning") .. "not scanned yet|r"
		end
		P[#P + 1] = string.format("%s  %d/%d%s", pr.name or "?", pr.rank or 0, pr.max or 0, note)
	end
	-- Attunements (first raid wave only; see Data/Attunements.lua)
	local A = section("Attunements", 2)
	for _, a in ipairs(SK.Data.ShownAttunements()) do
		local state, note = SK.RosterTab.AttunementOf(p, a)
		local mark
		if state == "none" then mark = C("textMuted") .. "no attunement needed|r"
		elseif state == "yes" then mark = "|A:UI-LFG-ReadyMark:12:12|a " .. C("success") .. "done|r"
		elseif state == "no" then mark = "|A:UI-LFG-DeclineMark:12:12|a " .. C("danger") .. "not done|r"
		else mark = "|A:UI-LFG-PendingMark:12:12|a " .. C("textMuted") .. (a.status == "todo" and "unknown (TODO)" or "unknown") .. "|r" end
		if note then mark = mark .. "\n" .. C("warning") .. note .. "|r" end
		A[#A + 1] = pair(a.name, mark)
	end
	-- Reputation: highlight list first, then everything else they have.
	local R = section("Reputation", 2)
	local shown = {}
	for _, f in ipairs(SK.Data.FACTIONS) do
		local r = p.reps and p.reps[f.id]
		if r then
			shown[f.id] = true
			R[#R + 1] = pair(r.n or f.name, C("textDim") .. standingName(r.r) .. "|r")
		end
	end
	local others = {}
	for id, r in pairs(p.reps or {}) do
		if not shown[id] and (r.r or 0) >= 5 then others[#others + 1] = r end
	end
	table.sort(others, function(a, b) return (a.n or "") < (b.n or "") end)
	for _, r in ipairs(others) do
		R[#R + 1] = pair(C("textDim") .. (r.n or "?") .. "|r", C("textMuted") .. standingName(r.r) .. "|r")
	end
	if not p.reps or SK.Count(p.reps) == 0 then R[#R + 1] = C("textMuted") .. "none recorded|r" end
	return out
end

-- Sections as text: column 1, column 2, or both (column nil).
function Char.DetailText(p, now, extra, column)
	local parts = {}
	for _, sec in ipairs(Char.DetailSections(p, now, extra)) do
		if not column or sec.column == column then
			parts[#parts + 1] = Theme.Code("textDim") .. string.upper(sec.title) .. "|r\n" .. table.concat(sec.lines, "\n")
		end
	end
	return table.concat(parts, "\n\n")
end

-- Alts of `guid` (mutually confirmed), for the details panel.
local function altsOf(guild, guid)
	local profiles = {}
	for g, p in pairs(guild.profiles) do profiles[g] = p end
	local groupOf = SK.Alts.Groups(profiles, function(g) return SK.Identity:IsMember(g) end)
	local group = groupOf[guid]
	if not group or #group.members < 2 then return nil, true end
	local list = {}
	for _, g in ipairs(group.members) do
		if g ~= guid then
			local m, p = guild.members[g], profiles[g]
			list[#list + 1] = { name = (m and m.name) or (p and p.name) or "?", class = (m and m.class) or (p and p.class),
				isMain = g == group.main }
		end
	end
	return list, group.main == guid
end

function Char:Refresh()
	if not self.slots then return end
	local guild = SK.DBM:Guild()
	local guid = self.guid or Compat.PlayerGUID()
	self.shownGuid = guid
	local p = guild and SK.Profile:Get(guid, guild)
	local m = guild and guid and guild.members[guid]
	local now = Compat.Now()
	local mine = guid and SK.DB.account[guid] or false
	self.whisper:SetShown(not mine and guid ~= nil)
	self.askLatest:SetShown(not mine and guid ~= nil)
	if not mine and guid then
		self.askLatest:SetDisabled(SK.Sync:FreshSource(guid, now) == nil)
	end
	local ask = guid and Char.AskStatus(Char.asked[guid], Char.answered[guid], now, SK.Sync.FRESH_INTERVAL)
	if ask and Char.asked[guid] and now - Char.asked[guid] >= SK.Sync.FRESH_INTERVAL then Char.asked[guid] = nil end
	local askText = ask and ("  ·  " .. Theme.Code("accent") .. ask .. "|r") or ""
	self.makeMain:SetShown(mine and SK.DB.settings.main ~= guid)

	if not p then
		self.name:SetText(m and Theme.ClassText(m.name, m.class) or "No character")
		self.info:SetText(m and ("Level " .. (m.level or "?") .. " · " .. (m.rank or "")) or "")
		self.meta:SetText("No Short Kings data yet" .. askText)
		for _, b in pairs(self.slots) do b:SetItem(nil) end
		self.ilvl:SetText("")
		self.specText:SetText("")
		self.enchantText:SetText("")
		self.details:SetText("")
		self.details2:SetText("")
		self:ShowEmpty(true)
		SK.MainFrame:SetStatus("character", "")
		return
	end
	self:ShowEmpty(false)

	local name = (m and m.name) or p.name
	self.name:SetText(Theme.ClassText(name, p.class))
	local race = p.race and (p.race:gsub("(%l)(%u)", "%1 %2")) or ""
	self.info:SetText(string.format("Level %s %s %s%s", p.level or "?", race,
		(p.class or ""):sub(1, 1) .. (p.class or ""):sub(2):lower(),
		m and m.rank and ("  ·  " .. m.rank) or ""))
	local source = p.source == "self" and "this account" or (p.source == "owner" and "from them" or "relayed by a guildmate")
	local ago = Theme.Ago(p.updated, now)
	ago = ago == "now" and "just now" or (ago .. " ago")
	local stale = (not mine and Theme.IsStale(p.updated, now)) and ("  ·  " .. Theme.Code("warning") .. "may be out of date|r") or ""
	self.meta:SetText(string.format("Updated %s (%s)  ·  Short Kings %s", ago, source, p.addon or "?") .. stale .. askText)

	local hidden = p.hidden or {}
	local missing = {}
	for _, slot in ipairs(SK.Data.Enchants.Missing(p.gear, p.class)) do missing[slot] = true end
	for slot, b in pairs(self.slots) do b:SetItem(p.gear and p.gear[slot], missing[slot]) end
	if hidden.gear then
		self.ilvl:SetText("")
		self.specText:SetText(Theme.Code("textMuted") .. "Gear and talents\nhidden by this player|r")
		self.enchantText:SetText("")
	else
		self.ilvl:SetText(p.ilvl and string.format("%.1f", p.ilvl) or "?")
		local spec, main = SK.Talents.Summary(p.talents)
		self.specText:SetText(spec and ((main or "") .. "\n" .. Theme.Code("textDim") .. spec .. "|r") or "")
		local n = SK.Count(missing)
		self.enchantText:SetText(n > 0 and string.format("%s %d missing enchant%s", WARN_SQUARE, n, n == 1 and "" or "s") or "")
	end

	local alts, isMain = altsOf(guild, guid)
	local extra = { alts = alts, isMain = isMain, note = m and m.note, officerNote = m and m.officerNote }
	self.details:SetText(Char.DetailText(p, now, extra, 1))
	self.details2:SetText(Char.DetailText(p, now, extra, 2))
	local share = p.hidden or {}
	SK.MainFrame:SetStatus("character", (share.gear and "Gear and talents private" or "Gear and talents shared")
		.. "  ·  " .. (share.recipes and "recipes private" or "recipes shared"))
end

SK.MainFrame:AddTab("character", "Character", Char)
