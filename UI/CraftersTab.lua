-- Crafters tab: "who can make this?". Search an item or recipe name, click
-- a result to see every guild crafter (online first) with a Whisper
-- button, and pre-fill guild chat with the list.
local _, SK = ...

local Crafters = SK:NewModule("CraftersTab")
local Theme, W, Compat = SK.Theme, SK.Widgets, SK.Compat
local CI = SK.CraftIndex

local function profName(skillLine) return CI.ProfessionName(CI:Get(true), skillLine) end

local function icon(r)
	local tex = r.itemID > 0 and Compat.ItemIcon(r.itemID) or Compat.SpellIcon(r.recipeID)
	return tex and ("|T" .. tex .. ":14:14:0:0:64:64:5:59:5:59|t ") or ""
end

-- Name in item-quality colour (enchants: the spell name in plain text).
local function coloured(r, name)
	local hex = r.itemID > 0 and Compat.ItemQualityHex(r.itemID)
	if hex then return "|c" .. hex .. name .. "|r" end
	return name
end

-- "3 crafters (1 online)"
function Crafters.CountText(total, online)
	local text = total .. (total == 1 and " crafter" or " crafters")
	if online > 0 then text = text .. " (" .. online .. " online)" end
	return text
end

local RESULT_COLUMNS = {
	{ key = "name", title = "Item or recipe", width = 232 },
	{ key = "prof", title = "Profession", width = 96 },
	{ key = "count", title = "Crafters", width = 126 },
}

local CRAFTER_COLUMNS = {
	{ key = "name", title = "Crafter", width = 146 },
	{ key = "skill", title = "Skill", width = 40, align = "RIGHT" },
	{ key = "info", title = "", width = 84 },
	{ key = "btn", title = "", width = 58 },
}

local function setResultCell(fs, r, col)
	if col.key == "name" then
		fs:SetText(icon(r) .. coloured(r, r.name))
	elseif col.key == "prof" then
		fs:SetText(Theme.Code("muted") .. profName(r.skillLine) .. "|r")
	elseif col.key == "count" then
		fs:SetText(Crafters.CountText(r.total, r.online))
	end
end

local function setCrafterCell(fs, c, col)
	local C = Theme.Code
	if col.key == "name" then
		fs:SetText(SK.RosterTab.DOT[c.status] .. " " .. Theme.ClassText(c.name, c.class))
	elseif col.key == "skill" then
		fs:SetText(c.skill > 0 and c.skill or "")
	elseif col.key == "info" then
		if c.via then fs:SetText(C("good") .. "on " .. (c.viaName or "alt") .. "|r")
		elseif c.altOf then fs:SetText(C("muted") .. "alt of " .. c.altOf .. "|r")
		else fs:SetText("") end
	else
		fs:SetText("")
	end
end

function Crafters:Build(page)
	self.query = ""
	self.search = W.SearchBox(page, 240, "Search an item or recipe...", function(text)
		Crafters.query = text
		Crafters:Refresh()
	end)
	self.search:SetPoint("TOPLEFT", 0, 0)
	self.status = Theme.Text(page, 12, "muted")
	self.status:SetPoint("LEFT", self.search, "RIGHT", 14, 0)

	self.results = W.List(page, {
		columns = RESULT_COLUMNS, rowHeight = 20, setCell = setResultCell,
		onClick = function(r) Crafters:Select(r.recipeID) end,
		onEnter = function(row, r)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			if r.itemID > 0 and GameTooltip.SetItemByID then
				GameTooltip:SetItemByID(r.itemID)
			else
				GameTooltip:SetText(r.name)
			end
			GameTooltip:AddLine("Click to see who can make it", 1, 0.76, 0.29)
			GameTooltip:Show()
		end,
	})
	self.results:SetPoint("TOPLEFT", 0, -30)
	self.results:SetPoint("BOTTOMLEFT")
	self.results:SetWidth(470)
	self.hint = Theme.Text(page, 12, "muted")
	self.hint:SetPoint("TOPLEFT", self.results, "TOPLEFT", 8, -34)
	self.hint:SetWidth(440)
	self.hint:SetJustifyH("LEFT")

	-- Side panel
	local side = CreateFrame("Frame", nil, page)
	side:SetPoint("TOPLEFT", self.results, "TOPRIGHT", 12, 0)
	side:SetPoint("BOTTOMRIGHT")
	Theme.Panel(side, { thickness = 1, gold = false, from = "plumDark", to = "plumLift" })
	self.side = side
	self.title = Theme.Text(side, 14, "pink")
	self.title:SetPoint("TOPLEFT", 10, -10)
	self.title:SetPoint("TOPRIGHT", -10, -10)
	self.title:SetJustifyH("LEFT")
	self.title:SetWordWrap(false)
	self.sub = Theme.Text(side, 11, "muted")
	self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
	self.crafters = W.List(side, {
		columns = CRAFTER_COLUMNS, rowHeight = 22, setCell = setCrafterCell,
		decorate = function(row)
			row.whisper = W.Button(row, "Whisper", 54, 18, function(b)
				if b.target then Compat.SendTell(SK.Identity:WhisperTarget(b.target)) end
			end)
			row.whisper:SetPoint("RIGHT", -2, 0)
			row.whisper.disabledTooltip = "Offline"
		end,
		update = function(row, c)
			row.whisper.target = c.whisper
			row.whisper:SetDisabled(c.whisper == nil)
			row.whisper:SetShown(not SK.DB.account[c.guid])
		end,
		onEnter = function(row, c)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:AddLine(Theme.ClassText(c.name, c.class))
			if c.altOf then GameTooltip:AddLine("alt of " .. c.altOf, 0.72, 0.6, 0.67) end
			if c.via then GameTooltip:AddLine("Online on " .. (c.viaName or "an alt"), 0.49, 0.84, 0.49) end
			if c.scanned then
				local stale = Theme.IsStale(c.scanned)
				GameTooltip:AddLine("Recipes recorded " .. Theme.Ago(c.scanned) .. " ago" ..
					(stale and " (may be out of date)" or ""), stale and 1 or 0.72, stale and 0.48 or 0.6, stale and 0.1 or 0.67)
			end
			GameTooltip:AddLine("Click to view character", 1, 0.76, 0.29)
			GameTooltip:Show()
		end,
		onClick = function(c) SK.CharacterTab:ShowCharacter(c.guid) end,
	})
	self.crafters:SetPoint("TOPLEFT", 6, -52)
	self.crafters:SetPoint("BOTTOMRIGHT", -6, 40)
	self.post = W.Button(side, "Post to guild chat", 150, 24, function() Crafters:PostToGuild() end)
	self.post:SetPoint("BOTTOMLEFT", 8, 8)
	self.copy = W.Button(side, "Copy", 56, 24, function() Crafters:CopyText() end)
	self.copy:SetPoint("LEFT", self.post, "RIGHT", 8, 0)
	self.copy.tooltip = "Copy the crafter list as plain text (for Discord)."
	self.post.tooltip = "Types the list into your chat box. Press Enter to send it."
	self.empty = Theme.Text(side, 12, "muted")
	self.empty:SetPoint("CENTER")
	self.empty:SetWidth(300)
	self.empty:SetText("Click a result to see who can make it.")

	SK:On("NAMES_LOADED", function()
		if page:IsShown() then Crafters:Refresh() end
	end)
	SK:On("CRAFT_INDEX_UPDATED", function()
		if page:IsShown() then Crafters:Refresh() end
	end)
end

function Crafters:Select(recipeID)
	self.selected = recipeID
	self:Refresh()
end

function Crafters:PostToGuild()
	local index = CI:Get()
	local r = self.selected and index.recipes[self.selected]
	if not r then return end
	local guild = SK.DBM:Guild()
	local list = CI.Crafters(index, r.recipeID, guild, Compat.Now())
	local label = (r.itemID > 0 and Compat.ItemLink(r.itemID)) or Compat.SpellLink(r.recipeID)
		or ("[" .. (CI.NameOf(r) or "?") .. "]")
	if not Compat.OpenChat("/g " .. CI.ChatText(label, list, 240)) then
		SK:Print("Couldn't open the chat box on this client.")
	end
end

function Crafters:CopyText()
	local index = CI:Get()
	local r = self.selected and index.recipes[self.selected]
	if not r then return end
	local list = CI.Crafters(index, r.recipeID, SK.DBM:Guild(), Compat.Now())
	local text = SK.Export.Crafters(CI.NameOf(r) or "?", profName(r.skillLine), list)
	SK.DebugWindow:ShowText("Copy as text", text)
	return text
end

function Crafters:Refresh()
	if not self.results then return end
	local index = CI:Get()
	local guild = SK.DBM:Guild()
	local now = Compat.Now()
	local results, state, loading = CI.Search(index, self.query, CI.MAX_RESULTS)
	for _, r in ipairs(results) do
		local list = CI.Crafters(index, r.recipeID, guild, now)
		r.total, r.online = #list, CI.OnlineCount(list)
	end
	self.results:SetItems(results)
	self.results:SetSelected(function(r) return r.recipeID == Crafters.selected end)

	local C = Theme.Code
	if state == "empty" then
		self.hint:SetText("Recipes appear after crafters open their profession window once.")
		self.status:SetText("")
	elseif state == "short" then
		CI.Prefetch(index)
		self.hint:SetText("Type at least 3 letters, e.g. \"arcanite\", \"mooncloth\" or \"enchant boots\".")
		self.status:SetText(string.format("%d recipes from %d crafters", index.recipeCount, index.crafterCount))
	else
		self.hint:SetText(#results == 0 and (loading > 0 and "Loading item names…" or "Nobody in the guild has that recipe yet.") or "")
		local text = (#results >= CI.MAX_RESULTS) and (CI.MAX_RESULTS .. "+ results, type more to narrow it down")
			or (#results .. (#results == 1 and " result" or " results"))
		if loading > 0 then text = text .. "  ·  " .. C("flame") .. "loading " .. loading .. " names…|r" end
		self.status:SetText(text)
	end

	local r = self.selected and index.recipes[self.selected]
	self.crafters:SetShown(r ~= nil)
	self.post:SetShown(r ~= nil)
	self.copy:SetShown(r ~= nil)
	self.empty:SetShown(r == nil)
	if not r then
		self.title:SetText("")
		self.sub:SetText("")
		return
	end
	local list = CI.Crafters(index, r.recipeID, guild, now)
	self.title:SetText(icon(r) .. coloured(r, CI.NameOf(r) or "…"))
	self.sub:SetText(profName(r.skillLine) .. "  ·  " .. Crafters.CountText(#list, CI.OnlineCount(list)))
	self.crafters:SetItems(list)
end

SK.MainFrame:AddTab("crafters", "Crafters", Crafters)
