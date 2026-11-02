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
	return tex and ("|T" .. tex .. ":18:18:0:0:64:64:5:59:5:59|t  ") or ""
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
	{ key = "name", title = "Item or recipe", width = 200 },
	{ key = "prof", title = "Profession", width = 96 },
	{ key = "count", title = "Crafters", width = 87 },
}

local CRAFTER_COLUMNS = {
	{ key = "name", title = "Crafter", width = 176 },
	{ key = "skill", title = "Skill", width = 40, align = "RIGHT" },
	{ key = "info", title = "", width = 104 },
	{ key = "btn", title = "", width = 60 },
}

local function setResultCell(fs, r, col)
	if col.key == "name" then
		fs:SetText(icon(r) .. coloured(r, r.name))
	elseif col.key == "prof" then
		fs:SetText(Theme.Code("textDim") .. profName(r.skillLine) .. "|r")
	elseif col.key == "count" then
		fs:SetText(Theme.Code("textDim") .. r.total .. (r.online > 0 and (" (" .. r.online .. " online)") or "") .. "|r")
	end
end

local function setCrafterCell(fs, c, col)
	local C = Theme.Code
	if col.key == "name" then
		fs:SetText(SK.RosterTab.DOT[c.status] .. " " .. Theme.ClassText(c.name, c.class))
	elseif col.key == "skill" then
		fs:SetText(c.skill > 0 and c.skill or "")
	elseif col.key == "info" then
		if c.via then fs:SetText(C("textDim") .. "on " .. (c.viaName or "alt") .. "|r")
		elseif c.altOf then fs:SetText(C("textMuted") .. "alt of " .. c.altOf .. "|r")
		else fs:SetText("") end
	else
		fs:SetText("")
	end
end

function Crafters:Build(page, tools)
	tools = tools or page
	self.query = ""
	self.search = W.SearchBox(tools, 280, "Search an item or recipe…", function(text)
		Crafters.query = text
		Crafters:Refresh()
	end)
	self.search:SetPoint("LEFT", 0, 0)
	self.status = Theme.Text(tools, "label", "textDim")
	self.status:SetPoint("LEFT", self.search, "RIGHT", 16, 0)

	self.results = W.List(page, {
		columns = RESULT_COLUMNS, rowHeight = 22, setCell = setResultCell,
		onClick = function(r) Crafters:Select(r.recipeID) end,
		onEnter = function(row, r)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			if r.itemID > 0 and GameTooltip.SetItemByID then
				GameTooltip:SetItemByID(r.itemID)
			else
				GameTooltip:SetText(r.name)
			end
			GameTooltip:AddLine("Click to see who can make it", Theme.RGB("accent"))
			GameTooltip:Show()
		end,
	})
	self.results:SetPoint("TOPLEFT", 0, 0)
	self.results:SetPoint("BOTTOMLEFT")
	self.results:SetWidth(400)
	-- Empty state over the results (before a search, nothing found, loading).
	self.resultsEmpty = W.EmptyState(self.results, "search", 340)
	self.resultsEmpty:SetPoint("TOP", 0, -96)
	self.hint = self.resultsEmpty.text

	-- Side panel: the selected recipe and who can make it.
	local side = CreateFrame("Frame", nil, page)
	side:SetPoint("TOPLEFT", self.results, "TOPRIGHT", 16, 0)
	side:SetPoint("BOTTOMRIGHT")
	Theme.Panel(side, { tone = "panel" })
	self.side = side
	self.title = Theme.Text(side, "title", "text")
	self.title:SetPoint("TOPLEFT", 16, -14)
	self.title:SetPoint("TOPRIGHT", -16, -14)
	self.title:SetJustifyH("LEFT")
	self.title:SetWordWrap(false)
	self.sub = Theme.Text(side, "small", "textDim")
	self.sub:SetPoint("TOPLEFT", 42, -38)
	self.crafters = W.List(side, {
		columns = CRAFTER_COLUMNS, rowHeight = 32, setCell = setCrafterCell, ground = false, header = false,
		decorate = function(row)
			row.whisper = W.Button(row, "Whisper", 60, 22, function(b)
				if b.target then Compat.SendTell(SK.Identity:WhisperTarget(b.target)) end
			end)
			row.whisper:SetPoint("RIGHT", -4, 0)
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
			if c.altOf then GameTooltip:AddLine("alt of " .. c.altOf, Theme.RGB("textMuted")) end
			if c.via then GameTooltip:AddLine("Online on " .. (c.viaName or "an alt"), Theme.RGB("success")) end
			if c.scanned then
				local stale = Theme.IsStale(c.scanned)
				GameTooltip:AddLine("Recipes recorded " .. Theme.Ago(c.scanned) .. " ago" ..
					(stale and " (may be out of date)" or ""), Theme.RGB(stale and "warning" or "textMuted"))
			end
			GameTooltip:AddLine("Click to view character", Theme.RGB("accent"))
			GameTooltip:Show()
		end,
		onClick = function(c) SK.CharacterTab:ShowCharacter(c.guid) end,
	})
	self.crafters:SetPoint("TOPLEFT", 0, -60)
	self.crafters:SetPoint("BOTTOMRIGHT", 0, 60)
	self.crafterLine = Theme.Edge(self.crafters, "TOP")
	self.post = W.Button(side, "Post to guild chat", 150, 28, function() Crafters:PostToGuild() end, { style = "primary" })
	W.FitWidth(self.post)
	self.post:SetPoint("BOTTOMLEFT", 16, 16)
	self.copy = W.Button(side, "Copy", 84, 28, function() Crafters:CopyText() end, { style = "ghost", icon = "copy" })
	self.copy:SetPoint("LEFT", self.post, "RIGHT", 8, 0)
	self.copy.tooltip = "Copy the crafter list as plain text (for Discord)."
	self.post.tooltip = "Types the list into your chat box. Press Enter to send it."
	self.empty = W.EmptyState(side, "crafters", 300)
	self.empty:SetPoint("TOP", 0, -140)
	self.empty:Set("Who can make it?", "Click a result to see who can make it.")

	SK:On("NAMES_LOADED", function()
		if page:IsShown() then Crafters:Refresh() end
	end)
	SK:On("CRAFT_INDEX_UPDATED", function()
		if page:IsShown() then Crafters:Refresh() end
	end)
	SK.MainFrame:SetStatus("crafters", "Recipes refresh when a crafter opens their profession window")
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
	local E = self.resultsEmpty
	if state == "empty" then
		E:Set("No recipes yet", "Recipes appear after crafters open their profession window once.", "inbox")
		self.status:SetText("")
	elseif state == "short" then
		CI.Prefetch(index)
		E:Set("Find a crafter", "Type at least 3 letters, e.g. \"arcanite\", \"mooncloth\" or \"enchant boots\".", "search")
		self.status:SetText(string.format("%d recipes from %d crafters", index.recipeCount, index.crafterCount))
	else
		if loading > 0 then E:Set("Loading item names…", "Names arrive from the server in a moment.", "search")
		else E:Set("Nobody has it yet", "Nobody in the guild has that recipe yet.", "search") end
		local text = (#results >= CI.MAX_RESULTS) and (CI.MAX_RESULTS .. "+ results, type more to narrow it down")
			or (#results .. (#results == 1 and " result" or " results"))
		if loading > 0 then text = text .. "  ·  " .. C("warning") .. "loading " .. loading .. " names…|r" end
		self.status:SetText(text)
	end
	E:SetShown(#results == 0)

	local r = self.selected and index.recipes[self.selected]
	self.crafters:SetShown(r ~= nil)
	self.sub:SetShown(r ~= nil)
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
