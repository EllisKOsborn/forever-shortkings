-- Character tab: paperdoll-style gear with real item tooltips, plus
-- talents, professions, cooldowns, reputations and attunements.
local _, SK = ...

local Char = SK:NewModule("CharacterTab")
local Theme, W, Compat = SK.Theme, SK.Widgets, SK.Compat
local S, SP = Theme.SIZES, Theme.SPACE

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
	return Theme.RGB("line")
end

local function slotButton(parent, slot)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(S.slot, S.slot)
	b.slot = slot
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	Theme.Solid(bg, "pressed")
	local inset = Theme.BORDER.slot
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", inset, -inset)
	b.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	Theme.Border(b, "line", inset)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", inset, -inset)
	hl:SetPoint("BOTTOMRIGHT", -inset, inset)
	hl:SetColorTexture(Theme.RGBA("text", 0.12))
	-- Missing-enchant marker: a spark dot with "!" in the corner
	b.warn = b:CreateTexture(nil, "OVERLAY")
	b.warn:SetSize(14, 14)
	b.warn:SetPoint("TOPRIGHT", 3, 3)
	b.warn:SetTexture(Theme.TEX.dot)
	b.warn:SetVertexColor(Theme.RGB("spark"))
	b.warnText = Theme.Text(b, "micro", "onGold", "OVERLAY")
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
				Theme.TipLine(GameTooltip, "Short Kings: no enchant on this item", "spark")
				GameTooltip:Show()
			end
		else
			GameTooltip:SetText(SLOT_NAMES[self.slot] or "Empty")
			Theme.TipLine(GameTooltip, "Empty", "dim")
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
			self.icon:SetAlpha(link and 1 or Theme.ALPHA.disabledIcon)
		end
		local r, g, bl = qualityColor(link)
		Theme.SetBorderRGB(self, r, g, bl)
	end
	return b
end

-- The details area: two scrolling columns of sections.
Char.DOLL_W = 250
-- content width = doll + gap + column + (gap + scroll bar) + column + scroll bar
Char.DETAIL_COL_W = math.floor((S.window[1] - 2 * SP.l - Char.DOLL_W - SP.xl - (SP.xl + SP.m) - SP.m) / 2)

function Char:Build(page)
	-- Header: back link, then actions on the right (the primary one in gold).
	self.back = W.Button(page, "Back to roster", nil, S.control, function() SK.MainFrame:Select("roster") end, "quiet")
	self.back:SetPoint("TOPLEFT", -SP.s, 0)
	self.mine = W.Button(page, "My character", nil, S.control, function() Char:ShowCharacter(nil) end, "quiet")
	self.mine:SetPoint("LEFT", self.back, "RIGHT", 0, 0)
	self.askLatest = W.Button(page, "Ask for latest", nil, S.control, function()
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
	end, "primary")
	self.askLatest.tooltip = "Ask them (or their online alt) for their newest data"
	self.askLatest.disabledTooltip = "Offline: showing their last known data"
	self.askLatest:SetPoint("TOPRIGHT", 0, 0)
	self.whisper = W.Button(page, "Whisper", nil, S.control, function()
		local target = Char.guid and SK.Identity:WhisperTarget(Char.guid)
		if target then Compat.SendTell(target) end
	end)
	self.whisper:SetPoint("RIGHT", self.askLatest, "LEFT", -SP.s, 0)
	self.makeMain = W.Button(page, "Make this my main", nil, S.control, function()
		if Char.shownGuid then SK.Profile:SetMain(Char.shownGuid); Char:Refresh() end
	end)
	self.makeMain.tooltip = "Your main is shown first when alts are grouped in the Roster."
	self.makeMain:SetPoint("TOPRIGHT", 0, 0)

	self.name = Theme.Text(page, "name", "text")
	self.name:SetPoint("TOPLEFT", 0, -(S.control + SP.m))
	self.name:SetPoint("RIGHT", 0, 0)
	self.name:SetWordWrap(false)
	self.info = Theme.Text(page, "body", "text")
	self.info:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -SP.xs)
	self.meta = Theme.Text(page, "small", "dim")
	self.meta:SetPoint("TOPLEFT", self.info, "BOTTOMLEFT", 0, -SP.xxs)
	self.meta:SetPoint("RIGHT", 0, 0)
	self.meta:SetWordWrap(false)

	-- Paperdoll: slots around a centre that carries the one key figure.
	local top = S.control + SP.m + 60
	local doll = CreateFrame("Frame", nil, page)
	doll:SetPoint("TOPLEFT", 0, -top)
	doll:SetPoint("BOTTOMLEFT", 0, 0)
	doll:SetWidth(Char.DOLL_W)
	Theme.Panel(doll, { bg = "surface", border = "line" })
	self.doll = doll
	local pitch = S.slot + SP.xs
	self.slots = {}
	for i, slot in ipairs(LEFT) do
		local b = slotButton(doll, slot)
		b:SetPoint("TOPLEFT", SP.s + 2, -SP.s - 2 - (i - 1) * pitch)
		self.slots[slot] = b
	end
	for i, slot in ipairs(RIGHT) do
		local b = slotButton(doll, slot)
		b:SetPoint("TOPRIGHT", -SP.s - 2, -SP.s - 2 - (i - 1) * pitch)
		self.slots[slot] = b
	end
	for i, slot in ipairs(BOTTOM) do
		local b = slotButton(doll, slot)
		b:SetPoint("BOTTOM", (i - 2) * (S.slot + SP.s), SP.s + 2)
		self.slots[slot] = b
	end
	self.ilvl = Theme.Text(doll, "figure", "gold")
	self.ilvl:SetPoint("CENTER", 0, 56)
	self.ilvl:SetJustifyH("CENTER")
	self.ilvlLabel = Theme.Text(doll, "micro", "dim")
	self.ilvlLabel:SetPoint("TOP", self.ilvl, "BOTTOM", 0, -SP.xxs)
	self.ilvlLabel:SetText("average item level")
	self.specText = Theme.Text(doll, "body", "text")
	self.specText:SetPoint("TOP", self.ilvlLabel, "BOTTOM", 0, -SP.l)
	self.specText:SetWidth(140)
	self.specText:SetJustifyH("CENTER")
	self.enchantText = Theme.Text(doll, "small", "spark")
	self.enchantText:SetPoint("TOP", self.specText, "BOTTOM", 0, -SP.m)
	self.enchantText:SetWidth(140)
	self.enchantText:SetJustifyH("CENTER")

	-- Details: two columns of sections.
	self.colA = W.Sheet(page, Char.DETAIL_COL_W)
	self.colA:SetPoint("TOPLEFT", doll, "TOPRIGHT", SP.xl, 0)
	self.colA:SetPoint("BOTTOM", doll, "BOTTOM", 0, 0)
	self.colA:SetWidth(Char.DETAIL_COL_W)
	self.colB = W.Sheet(page, Char.DETAIL_COL_W)
	self.colB:SetPoint("TOPLEFT", self.colA, "TOPRIGHT", SP.xl + SP.m, 0)
	self.colB:SetPoint("BOTTOM", doll, "BOTTOM", 0, 0)
	self.colB:SetWidth(Char.DETAIL_COL_W)
	self.empty = Theme.Text(page, "body", "dim")
	self.empty:SetPoint("TOPLEFT", doll, "TOPRIGHT", SP.xl, 0)
	self.empty:SetPoint("RIGHT", 0, 0)
	self.empty:SetJustifyV("TOP")
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

-- Sections for the details columns (pure-ish; uses only the profile).
-- Returns a list of { title=, rows=, col = 1 | 2 }.
function Char.DetailSections(p, now, extra)
	local out = {}
	extra = extra or {}
	local function section(title, col)
		local s = { title = title, rows = {}, col = col }
		out[#out + 1] = s
		return s.rows
	end
	if extra.alts and #extra.alts > 0 then
		local rows = section(extra.isMain and "Alts" or "Same player", 1)
		for _, a in ipairs(extra.alts) do
			rows[#rows + 1] = { label = Theme.ClassText(a.name, a.class), value = a.isMain and "main" or "", tone = "beard" }
		end
	end
	if (extra.note and extra.note ~= "") or (extra.officerNote and extra.officerNote ~= "") then
		local rows = section("Notes", 1)
		if extra.note and extra.note ~= "" then rows[#rows + 1] = { text = extra.note, tone = "text" } end
		if extra.officerNote and extra.officerNote ~= "" then
			rows[#rows + 1] = { text = Theme.Paint("dim", "Officer: ") .. extra.officerNote, tone = "text" }
		end
	end
	local hidden = p.hidden or {}
	-- Talents
	local rows = section("Talents", 1)
	if hidden.gear then
		rows[#rows + 1] = { text = "hidden by this player" }
	elseif p.talents and p.talents.trees then
		for _, t in ipairs(p.talents.trees) do
			rows[#rows + 1] = { label = t.n or "?", value = tostring(t.p or 0) }
		end
	else
		rows[#rows + 1] = { text = "not available" }
	end
	-- Professions
	rows = section("Professions", 1)
	local profs = {}
	for skillLine, pr in pairs(p.profs or {}) do profs[#profs + 1] = { id = skillLine, pr = pr } end
	table.sort(profs, function(a, b) return (a.pr.name or "") < (b.pr.name or "") end)
	if #profs == 0 then rows[#rows + 1] = { text = "none" } end
	for _, e in ipairs(profs) do
		local pr = e.pr
		local recipes = p.recipes and p.recipes[e.id]
		local note
		if SK.Data.GATHERING[e.id] then
			note = nil
		elseif hidden.recipes then
			note = Theme.Paint("dim", "recipes hidden")
		elseif pr.scanned then
			note = Theme.Paint("dim", SK.Count(recipes) .. " recipes")
		else
			note = Theme.Paint("spark", "not scanned yet")
		end
		rows[#rows + 1] = { label = pr.name or "?", labelTone = "text",
			value = (note and (note .. "   ") or "") .. string.format("%d/%d", pr.rank or 0, pr.max or 0) }
	end
	-- Cooldowns
	local cds = {}
	for id, expires in pairs(p.cds or {}) do cds[#cds + 1] = { id = id, at = expires } end
	if #cds > 0 then
		rows = section("Cooldowns", 1)
		table.sort(cds, function(a, b) return a.at < b.at end)
		for _, cd in ipairs(cds) do
			local left = cd.at - now
			local name = Compat.SpellName(cd.id) or ("Recipe " .. cd.id)
			if left <= 0 then
				rows[#rows + 1] = { label = name, value = "ready", tone = "good" }
			else
				rows[#rows + 1] = { label = name, value = string.format("%dh %dm", math.floor(left / 3600), math.floor(left % 3600 / 60)) }
			end
		end
	end
	-- Attunements (first raid wave only; see Data/Attunements.lua)
	rows = section("Attunements", 2)
	for _, a in ipairs(SK.Data.ShownAttunements()) do
		local state, note = SK.RosterTab.AttunementOf(p, a)
		local value, tone
		if state == "none" then value, tone = "no attunement needed", "dim"
		elseif state == "yes" then value, tone = "done", "good"
		elseif state == "no" then value, tone = "not done", "bad"
		else value, tone = (a.status == "todo" and "unknown (TODO)" or "unknown"), "dim" end
		rows[#rows + 1] = { label = a.name, labelTone = "text", value = value, tone = tone }
		if note then rows[#rows + 1] = { text = note, tone = "spark", indent = true } end
	end
	-- Reputation: highlight list first, then everything else they have.
	rows = section("Reputation", 2)
	local shown = {}
	for _, f in ipairs(SK.Data.FACTIONS) do
		local r = p.reps and p.reps[f.id]
		if r then
			shown[f.id] = true
			rows[#rows + 1] = { label = r.n or f.name, labelTone = "text", value = standingName(r.r) }
		end
	end
	local others = {}
	for id, r in pairs(p.reps or {}) do
		if not shown[id] and (r.r or 0) >= 5 then others[#others + 1] = r end
	end
	table.sort(others, function(a, b) return (a.n or "") < (b.n or "") end)
	for _, r in ipairs(others) do
		rows[#rows + 1] = { label = r.n or "?", value = standingName(r.r), tone = "dim" }
	end
	if not p.reps or SK.Count(p.reps) == 0 then rows[#rows + 1] = { text = "none recorded" } end
	return out
end

-- Plain text of the details (tests, Copy).
function Char.DetailText(p, now, extra)
	return W.SheetText(Char.DetailSections(p, now, extra))
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
	local askText = ask and ("  ·  " .. Theme.Paint("spark", ask)) or ""
	self.makeMain:SetShown(mine and SK.DB.settings.main ~= guid)

	if not p then
		self.name:SetText(m and Theme.ClassText(m.name, m.class) or "No character")
		self.info:SetText(m and ("Level " .. (m.level or "?") .. " · " .. (m.rank or "")) or "")
		self.meta:SetText("No data synced yet" .. askText)
		for _, b in pairs(self.slots) do b:SetItem(nil) end
		self.ilvl:SetText(Theme.DASH)
		self.specText:SetText("")
		self.enchantText:SetText("")
		self.colA:Hide()
		self.colB:Hide()
		self.empty:SetText(Char.EmptyText(m ~= nil))
		self.empty:Show()
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
	local stale = (not mine and Theme.IsStale(p.updated, now)) and ("  ·  " .. Theme.Paint("spark", "may be out of date")) or ""
	self.meta:SetText(string.format("Updated %s (%s)  ·  Short Kings %s", ago, source, p.addon or "?") .. stale .. askText)

	local hidden = p.hidden or {}
	local missing = {}
	for _, slot in ipairs(SK.Data.Enchants.Missing(p.gear, p.class)) do missing[slot] = true end
	for slot, b in pairs(self.slots) do b:SetItem(p.gear and p.gear[slot], missing[slot]) end
	if hidden.gear then
		self.ilvl:SetText("")
		self.specText:SetText(Theme.Paint("dim", "Gear and talents\nhidden by this player"))
		self.enchantText:SetText("")
	else
		self.ilvl:SetText(p.ilvl and string.format("%.1f", p.ilvl) or "?")
		local spec, main = SK.Talents.Summary(p.talents)
		self.specText:SetText(spec and ((main or "") .. "\n" .. spec) or "")
		local n = SK.Count(missing)
		self.enchantText:SetText(n > 0 and string.format("%d missing enchant%s", n, n == 1 and "" or "s") or "")
	end

	local alts, isMain = altsOf(guild, guid)
	local sections = Char.DetailSections(p, now, {
		alts = alts, isMain = isMain, note = m and m.note, officerNote = m and m.officerNote,
	})
	local a, b = {}, {}
	for _, sec in ipairs(sections) do
		if sec.col == 2 then b[#b + 1] = sec else a[#a + 1] = sec end
	end
	self.empty:Hide()
	self.colA:Show()
	self.colB:Show()
	self.colA:SetSections(a)
	self.colB:SetSections(b)
end

-- What the details area says when there's no profile. Pure; tested.
function Char.EmptyText(isMember)
	if not isMember then return "Pick someone on the Roster to see their gear, talents and professions." end
	return "No data synced yet. They may not have Short Kings, or they're on a trial account (trials can't sync)."
		.. " Their profile appears here the next time they log in with it."
end

SK.MainFrame:AddTab("character", "Character", Char)
