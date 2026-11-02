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
	return Theme.RGB("leather")
end

local function slotButton(parent, slot)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(38, 38)
	b.slot = slot
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	Theme.Solid(bg, "plumDark")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 2, -2)
	b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	Theme.Border(b, 2, false)
	-- Missing-enchant marker: small ember corner with "!"
	b.warn = b:CreateTexture(nil, "OVERLAY")
	b.warn:SetSize(12, 12)
	b.warn:SetPoint("TOPRIGHT", -1, -1)
	Theme.Gradient(b.warn, "VERTICAL", "ember", "flame")
	b.warnText = Theme.Text(b, 10, "plumDark", "OVERLAY")
	b.warnText:SetPoint("CENTER", b.warn, "CENTER", 0, 0)
	b.warnText:SetText("!")
	b.warnText:SetShadowOffset(0, 0)
	b.warn:Hide(); b.warnText:Hide()
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.link then
			GameTooltip:SetHyperlink(self.link)
			if self.missingEnchant then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine("Short Kings: no enchant on this item", 1, 0.48, 0.1)
				GameTooltip:Show()
			end
		else
			GameTooltip:SetText(SLOT_NAMES[self.slot] or "Empty")
			GameTooltip:AddLine("Empty", 0.7, 0.6, 0.65)
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
		self.warnText:SetShown(missingEnchant and true or false)
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
		for _, t in ipairs(self.border) do t:SetColorTexture(r, g, bl, 1) end
	end
	return b
end

function Char:Build(page)
	-- Header
	self.back = W.Button(page, "< Roster", 80, 22, function() SK.MainFrame:Select("roster") end)
	self.back:SetPoint("TOPLEFT", 0, 0)
	self.mine = W.Button(page, "Me", 50, 22, function() Char:ShowCharacter(nil) end)
	self.mine:SetPoint("LEFT", self.back, "RIGHT", 6, 0)
	self.whisper = W.Button(page, "Whisper", 80, 22, function()
		local target = Char.guid and SK.Identity:WhisperTarget(Char.guid)
		if target then Compat.SendTell(target) end
	end)
	self.whisper:SetPoint("LEFT", self.mine, "RIGHT", 6, 0)
	self.askLatest = W.Button(page, "Ask for latest", 110, 22, function()
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
	end)
	self.askLatest.tooltip = "Ask them (or their online alt) for their newest data"
	self.askLatest.disabledTooltip = "Offline: showing their last known data"
	self.askLatest:SetPoint("LEFT", self.whisper, "RIGHT", 6, 0)
	self.makeMain = W.Button(page, "Make this my main", 140, 22, function()
		if Char.shownGuid then SK.Profile:SetMain(Char.shownGuid); Char:Refresh() end
	end)
	self.makeMain.tooltip = "Your main is shown first when alts are grouped in the Roster."
	self.makeMain:SetPoint("LEFT", self.mine, "RIGHT", 6, 0)

	self.name = Theme.Text(page, 18, "pink")
	self.name:SetPoint("TOPLEFT", 0, -32)
	self.info = Theme.Text(page, 12, "text")
	self.info:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -4)
	self.meta = Theme.Text(page, 11, "muted")
	self.meta:SetPoint("TOPLEFT", self.info, "BOTTOMLEFT", 0, -3)

	-- Paperdoll
	local doll = CreateFrame("Frame", nil, page)
	doll:SetPoint("TOPLEFT", 0, -92)
	doll:SetSize(250, 370)
	Theme.Panel(doll, { thickness = 2, from = "plumDark", to = "plumLift" })
	self.slots = {}
	for i, slot in ipairs(LEFT) do
		local b = slotButton(doll, slot)
		b:SetPoint("TOPLEFT", 10, -10 - (i - 1) * 42)
		self.slots[slot] = b
	end
	for i, slot in ipairs(RIGHT) do
		local b = slotButton(doll, slot)
		b:SetPoint("TOPRIGHT", -10, -10 - (i - 1) * 42)
		self.slots[slot] = b
	end
	for i, slot in ipairs(BOTTOM) do
		local b = slotButton(doll, slot)
		b:SetPoint("BOTTOM", (i - 2) * 46, 10)
		self.slots[slot] = b
	end
	self.ilvl = Theme.Text(doll, 20, "flame")
	self.ilvl:SetPoint("CENTER", 0, 40)
	self.ilvlLabel = Theme.Text(doll, 11, "muted")
	self.ilvlLabel:SetPoint("TOP", self.ilvl, "BOTTOM", 0, -2)
	self.ilvlLabel:SetText("average item level")
	self.specText = Theme.Text(doll, 12, "pink")
	self.specText:SetPoint("TOP", self.ilvlLabel, "BOTTOM", 0, -16)
	self.specText:SetWidth(150)
	self.enchantText = Theme.Text(doll, 11, "ember")
	self.enchantText:SetPoint("TOP", self.specText, "BOTTOM", 0, -14)
	self.enchantText:SetWidth(150)

	-- Details
	self.details = W.TextPanel(page)
	self.details:SetPoint("TOPLEFT", doll, "TOPRIGHT", 18, 0)
	self.details:SetPoint("BOTTOMRIGHT", -14, 0)
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

function Char:ShowCharacter(guid)
	self.guid = guid
	SK.MainFrame:Show("character")
end

local function section(lines, title)
	lines[#lines + 1] = ""
	lines[#lines + 1] = Theme.Code("pink") .. title .. "|r"
end

-- Text for the details panel. Pure-ish; uses only the profile.
function Char.DetailText(p, now, extra)
	local lines = {}
	local C = Theme.Code
	extra = extra or {}
	if extra.alts and #extra.alts > 0 then
		section(lines, extra.isMain and "Alts" or "Same player")
		for _, a in ipairs(extra.alts) do
			lines[#lines + 1] = "  " .. Theme.ClassText(a.name, a.class) .. (a.isMain and (C("flame") .. "  (main)|r") or "")
		end
	end
	if (extra.note and extra.note ~= "") or (extra.officerNote and extra.officerNote ~= "") then
		section(lines, "Notes")
		if extra.note and extra.note ~= "" then lines[#lines + 1] = "  " .. extra.note end
		if extra.officerNote and extra.officerNote ~= "" then
			lines[#lines + 1] = "  " .. C("flame") .. "Officer: |r" .. extra.officerNote
		end
	end
	local hidden = p.hidden or {}
	-- Talents
	section(lines, "Talents")
	if hidden.gear then
		lines[#lines + 1] = C("muted") .. "  hidden by this player|r"
	elseif p.talents and p.talents.trees then
		for _, t in ipairs(p.talents.trees) do
			lines[#lines + 1] = string.format("  %s  %s%d|r", t.n or "?", C("flame"), t.p or 0)
		end
	else
		lines[#lines + 1] = C("muted") .. "  not available|r"
	end
	-- Professions
	section(lines, "Professions")
	local profs = {}
	for skillLine, pr in pairs(p.profs or {}) do profs[#profs + 1] = { id = skillLine, pr = pr } end
	table.sort(profs, function(a, b) return (a.pr.name or "") < (b.pr.name or "") end)
	if #profs == 0 then lines[#lines + 1] = C("muted") .. "  none|r" end
	for _, e in ipairs(profs) do
		local pr = e.pr
		local recipes = p.recipes and p.recipes[e.id]
		local note
		if SK.Data.GATHERING[e.id] then
			note = ""
		elseif hidden.recipes then
			note = "  " .. C("muted") .. "recipes hidden|r"
		elseif pr.scanned then
			note = string.format("  %s%d recipes|r", C("muted"), SK.Count(recipes))
		else
			note = "  " .. C("ember") .. "not scanned yet|r"
		end
		lines[#lines + 1] = string.format("  %s  %d/%d%s", pr.name or "?", pr.rank or 0, pr.max or 0, note)
	end
	-- Cooldowns
	local cds = {}
	for id, expires in pairs(p.cds or {}) do cds[#cds + 1] = { id = id, at = expires } end
	if #cds > 0 then
		section(lines, "Cooldowns")
		table.sort(cds, function(a, b) return a.at < b.at end)
		for _, cd in ipairs(cds) do
			local left = cd.at - now
			local name = Compat.SpellName(cd.id) or ("Recipe " .. cd.id)
			local when = left <= 0 and (C("good") .. "ready|r") or
				string.format("%s%dh %dm|r", C("flame"), math.floor(left / 3600), math.floor(left % 3600 / 60))
			lines[#lines + 1] = "  " .. name .. "  " .. when
		end
	end
	-- Attunements
	section(lines, "Attunements")
	for _, a in ipairs(SK.Data.ATTUNEMENTS) do
		local v = p.att and p.att[a.key]
		local mark
		if v == true then mark = C("good") .. "done|r"
		elseif v == false then mark = C("bad") .. "not done|r"
		else mark = C("muted") .. (a.status == "todo" and "unknown (TODO)" or "unknown") .. "|r" end
		lines[#lines + 1] = "  " .. a.name .. "  " .. mark
	end
	-- Reputation: highlight list first, then everything else they have.
	section(lines, "Reputation")
	local shown = {}
	for _, f in ipairs(SK.Data.FACTIONS) do
		local r = p.reps and p.reps[f.id]
		if r then
			shown[f.id] = true
			lines[#lines + 1] = string.format("  %s  %s%s|r", r.n or f.name, C("flame"), standingName(r.r))
		end
	end
	local others = {}
	for id, r in pairs(p.reps or {}) do
		if not shown[id] and (r.r or 0) >= 5 then others[#others + 1] = r end
	end
	table.sort(others, function(a, b) return (a.n or "") < (b.n or "") end)
	for _, r in ipairs(others) do
		lines[#lines + 1] = string.format("  %s  %s%s|r", r.n or "?", C("muted"), standingName(r.r))
	end
	if not p.reps or SK.Count(p.reps) == 0 then lines[#lines + 1] = C("muted") .. "  none recorded|r" end
	table.remove(lines, 1)
	return table.concat(lines, "\n")
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
	local askText = ask and ("  ·  " .. Theme.Code("flame") .. ask .. "|r") or ""
	self.makeMain:SetShown(mine and SK.DB.settings.main ~= guid)

	if not p then
		self.name:SetText(m and Theme.ClassText(m.name, m.class) or "No character")
		self.info:SetText(m and ("Level " .. (m.level or "?") .. " · " .. (m.rank or "")) or "")
		self.meta:SetText("No Short Kings data yet: they may not have the addon, or be on a trial account (trials can't sync)."
			.. askText)
		for _, b in pairs(self.slots) do b:SetItem(nil) end
		self.ilvl:SetText("")
		self.specText:SetText("")
		self.enchantText:SetText("")
		self.details:SetText("")
		return
	end

	local name = (m and m.name) or p.name
	self.name:SetText(Theme.ClassText(name, p.class))
	local race = p.race and (p.race:gsub("(%l)(%u)", "%1 %2")) or ""
	self.info:SetText(string.format("Level %s %s %s%s", p.level or "?", race,
		(p.class or ""):sub(1, 1) .. (p.class or ""):sub(2):lower(),
		m and m.rank and ("  ·  " .. m.rank) or ""))
	local source = p.source == "self" and "this account" or (p.source == "owner" and "from them" or "relayed by a guildmate")
	local ago = Theme.Ago(p.updated, now)
	ago = ago == "now" and "just now" or (ago .. " ago")
	self.meta:SetText(string.format("Updated %s (%s)  ·  Short Kings %s", ago, source, p.addon or "?") .. askText)

	local hidden = p.hidden or {}
	local missing = {}
	for _, slot in ipairs(SK.Data.Enchants.Missing(p.gear, p.class)) do missing[slot] = true end
	for slot, b in pairs(self.slots) do b:SetItem(p.gear and p.gear[slot], missing[slot]) end
	if hidden.gear then
		self.ilvl:SetText("")
		self.specText:SetText(Theme.Code("muted") .. "Gear and talents\nhidden by this player|r")
		self.enchantText:SetText("")
	else
		self.ilvl:SetText(p.ilvl and string.format("%.1f", p.ilvl) or "?")
		local spec, main = SK.Talents.Summary(p.talents)
		self.specText:SetText(spec and ((main or "") .. "\n" .. spec) or "")
		local n = SK.Count(missing)
		self.enchantText:SetText(n > 0 and string.format("%d missing enchant%s", n, n == 1 and "" or "s") or "")
	end

	local alts, isMain = altsOf(guild, guid)
	self.details:SetText(Char.DetailText(p, now, {
		alts = alts, isMain = isMain, note = m and m.note, officerNote = m and m.officerNote,
	}))
end

SK.MainFrame:AddTab("character", "Character", Char)
