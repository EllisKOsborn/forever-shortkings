-- Crafters tab: "who can make this?". Search an item or recipe name, click
-- a result to see every guild crafter (online first) with a Whisper
-- button, and pre-fill guild chat with the list.
local _, SK = ...

local Crafters = SK:NewModule("CraftersTab")
local Theme, W, Compat = SK.Theme, SK.Widgets, SK.Compat
local CI = SK.CraftIndex
local S, SP = Theme.SIZES, Theme.SPACE

Crafters.RESULTS_W = 476
Crafters.SIDE_W = S.window[1] - 2 * SP.l - Crafters.RESULTS_W - SP.l
Crafters.REAGENTS_H = 3 * Theme.SIZE.small + 4 * Theme.SPACE.xs -- up to three lines of reagents

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

-- Results: 476 - 12 (scroll bar) = 464.
local RESULT_COLUMNS = {
	{ key = "name", title = "Item or recipe", width = 250 },
	{ key = "prof", title = "Profession", width = 100 },
	{ key = "count", title = "Crafters", width = 114, align = "RIGHT" },
}

-- Side panel list: 356 - 2 x 12 padding - 12 (scroll bar) = 320.
local CRAFTER_COLUMNS = {
	{ key = "name", title = "Crafter", width = 138 },
	{ key = "skill", title = "Skill", width = 44, align = "RIGHT" },
	{ key = "info", title = "", width = 74 },
	{ key = "btn", title = "", width = 64 },
}

local function star(on) return on and (Theme.Star("beard") .. " ") or "" end

local function setResultCell(fs, r, col)
	if col.key == "name" then
		fs:SetText(star(SK.Favourites.IsRecipe(r.recipeID)) .. icon(r) .. coloured(r, r.name))
	elseif col.key == "prof" then
		fs:SetText(Theme.Paint("dim", profName(r.skillLine)))
	elseif col.key == "count" then
		fs:SetText(r.online > 0 and (r.total .. Theme.Paint("dim", "  (" .. r.online .. " online)")) or tostring(r.total))
	end
end

local function setCrafterCell(fs, c, col)
	local C = Theme.Code
	if col.key == "name" then
		fs:SetText(SK.RosterTab.DOT[c.status] .. " " .. star(c.fav) .. Theme.ClassText(c.name, c.class))
	elseif col.key == "skill" then
		fs:SetText(c.skill > 0 and c.skill or Theme.DASH)
	elseif col.key == "info" then
		if c.via then fs:SetText(C("good") .. "on " .. (c.viaName or "alt") .. "|r")
		elseif c.altOf then fs:SetText(C("dim") .. "alt of " .. c.altOf .. "|r")
		else fs:SetText("") end
	else
		fs:SetText("")
	end
end

function Crafters:Build(page)
	self.query = ""
	self.search = W.SearchBox(page, 260, "Search an item or recipe", function(text)
		Crafters.query = text
		Crafters:Refresh()
	end)
	self.search:SetPoint("TOPLEFT", 0, 0)
	self.favOnly = false
	self.favChip = W.Chip(page, "Favourites", function()
		Crafters.favOnly = not Crafters.favOnly
		Crafters:Refresh()
	end)
	self.favChip:SetPoint("LEFT", self.search, "RIGHT", SP.s, 0)
	self.favChip.tooltip = "Only your starred recipes. Right-click a result to star it."
	self.status = Theme.Text(page, "small", "dim")
	self.status:SetPoint("LEFT", self.favChip, "RIGHT", SP.m, 0)
	self.status:SetPoint("RIGHT", page, "LEFT", Crafters.RESULTS_W, 0)
	self.status:SetWordWrap(false)

	self.results = W.List(page, {
		columns = RESULT_COLUMNS, setCell = setResultCell,
		onClick = function(r, button)
			if button == "RightButton" then SK.Favourites.ToggleRecipe(r.recipeID)
			else Crafters:Select(r.recipeID) end
		end,
		onEnter = function(row, r)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			if r.itemID > 0 and GameTooltip.SetItemByID then
				GameTooltip:SetItemByID(r.itemID)
			else
				GameTooltip:SetText(r.name)
			end
			Theme.TipLine(GameTooltip, "Click to see who can make it  ·  Right-click to " ..
				(SK.Favourites.IsRecipe(r.recipeID) and "unstar" or "star"), "gold")
			GameTooltip:Show()
		end,
	})
	self.results:SetPoint("TOPLEFT", 0, -(S.control + SP.m))
	self.results:SetPoint("BOTTOMLEFT")
	self.results:SetWidth(Crafters.RESULTS_W)
	self.hint = self.results.message

	-- Side panel: who can make the picked item. Keeps its frame when empty.
	local side = CreateFrame("Frame", nil, page)
	side:SetPoint("TOPLEFT", self.results, "TOPRIGHT", SP.l, 0)
	side:SetPoint("BOTTOMRIGHT")
	Theme.Panel(side, { bg = "surface", border = "line" })
	self.side = side
	self.title = Theme.Text(side, "title", "text")
	self.title:SetPoint("TOPLEFT", SP.m, -SP.m)
	self.title:SetPoint("TOPRIGHT", -SP.m, -SP.m)
	-- Long item names wrap to a second line rather than being cut off.
	self.title:SetWordWrap(true)
	if self.title.SetMaxLines then self.title:SetMaxLines(2) end
	self.sub = Theme.Text(side, "small", "dim")
	self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -SP.xs)
	self.crafters = W.List(side, {
		columns = CRAFTER_COLUMNS, setCell = setCrafterCell,
		decorate = function(row)
			row.whisper = W.Button(row, "Whisper", 60, S.controlSmall, function(b)
				if b.target then Compat.SendTell(SK.Identity:WhisperTarget(b.target)) end
			end)
			row.whisper:SetPoint("RIGHT", -SP.xxs, 0)
			row.widgets[#row.widgets + 1] = row.whisper
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
			if c.altOf then Theme.TipLine(GameTooltip, "alt of " .. c.altOf, "dim") end
			if c.via then Theme.TipLine(GameTooltip, "Online on " .. (c.viaName or "an alt"), "good") end
			if c.scanned then
				local stale = Theme.IsStale(c.scanned)
				Theme.TipLine(GameTooltip, "Recipes recorded " .. Theme.Ago(c.scanned) .. " ago" ..
					(stale and " (may be out of date)" or ""), stale and "spark" or "dim")
			end
			Theme.TipLine(GameTooltip, "Click to view character  ·  Right-click to " ..
				(c.fav and "unstar" or "star"), "gold")
			GameTooltip:Show()
		end,
		onClick = function(c, button)
			if button == "RightButton" then SK.Favourites.ToggleCrafter(c.guid)
			else SK.CharacterTab:ShowCharacter(c.guid) end
		end,
	})
	self.crafters:SetPoint("TOPLEFT", SP.m, -72)
	self.crafters:SetPoint("BOTTOMRIGHT", -SP.m, S.control + SP.m * 2 + Crafters.REAGENTS_H)
	-- Reagents (read from the game on this computer), above the buttons.
	self.reagents = Theme.Text(side, "small", "dim")
	self.reagents:SetPoint("BOTTOMLEFT", SP.m, S.control + SP.m * 2)
	self.reagents:SetPoint("RIGHT", -SP.m, 0)
	self.reagents:SetHeight(Crafters.REAGENTS_H - SP.s)
	self.reagents:SetJustifyV("TOP")
	self.reagents:SetWordWrap(true)
	self.favButton = W.Chip(side, "Star", function()
		if Crafters.selected then SK.Favourites.ToggleRecipe(Crafters.selected) end
	end)
	self.favButton:SetPoint("BOTTOMRIGHT", -SP.m, SP.m + 1)
	self.favButton.tooltip = "Starred recipes show under Favourites, here and on the Professions tab."
	self.post = W.Button(side, "Post to guild chat", nil, S.control, function() Crafters:PostToGuild() end, "primary")
	self.post:SetPoint("BOTTOMLEFT", SP.m, SP.m)
	self.copy = W.Button(side, "Copy", nil, S.control, function() Crafters:CopyText() end)
	self.copy:SetPoint("LEFT", self.post, "RIGHT", SP.s, 0)
	self.copy.tooltip = "Copy the crafter list as plain text (for Discord)."
	self.post.tooltip = "Types the list into your chat box. Press Enter to send it."
	self.empty = Theme.Text(side, "body", "dim")
	self.empty:SetPoint("TOPLEFT", SP.m, -SP.m)
	self.empty:SetPoint("RIGHT", -SP.m, 0)
	self.empty:SetJustifyV("TOP")
	self.empty:SetText("Pick an item on the left to see who in the guild can make it, who's online, and to whisper them.")

	SK:On("NAMES_LOADED", function()
		if page:IsShown() then Crafters:Refresh() end
	end)
	SK:On("CRAFT_INDEX_UPDATED", function()
		if page:IsShown() then Crafters:Refresh() end
	end)
	SK:On("FAVOURITES_CHANGED", function()
		if page:IsShown() then Crafters:Refresh() end
	end)
end

-- From the Professions tab: open this recipe here. A recipe nobody knows
-- yet (from the profession window's full list) still shows, with reagents.
function Crafters:ShowRecipe(recipeID, skillLine)
	self.selected, self.selectedSkill = recipeID, skillLine
	SK.MainFrame:Show("crafters")
	self:Refresh()
end

-- The picked recipe: from the index, or a known-to-nobody one.
function Crafters:Picked(index)
	if not self.selected then return nil end
	local r = index.recipes[self.selected]
	if r then return r end
	local guild = SK.DBM:Guild()
	local uni = guild and self.selectedSkill and guild.recipeUniverse[self.selectedSkill]
	if uni and uni[self.selected] ~= nil then
		local itemID = type(uni[self.selected]) == "number" and uni[self.selected] or 0
		return { recipeID = self.selected, itemID = itemID, skillLine = self.selectedSkill, crafters = {} }
	end
end

function Crafters:Select(recipeID)
	self.selected, self.selectedSkill = recipeID, nil
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
	local results, state, loading
	if self.favOnly then
		results, loading = CI.FavouriteResults(index, SK.Favourites.Recipes(), self.query)
		state = "fav"
	else
		results, state, loading = CI.Search(index, self.query, CI.MAX_RESULTS)
	end
	self.favChip:SetActive(self.favOnly)
	for _, r in ipairs(results) do
		local list = CI.Crafters(index, r.recipeID, guild, now)
		r.total, r.online = #list, CI.OnlineCount(list)
	end
	self.results:SetItems(results)
	self.results:SetSelected(function(r) return r.recipeID == Crafters.selected end)

	local C = Theme.Code
	if state == "fav" then
		self.results:SetEmptyText("No starred recipes" .. (self.query ~= "" and " match that" or "") ..
			". Right-click a result to star it.")
		self.status:SetText(Theme.Count(#results, "favourite"))
	elseif state == "empty" then
		self.results:SetEmptyText("Recipes appear after crafters open their profession window once.")
		self.status:SetText("")
	elseif state == "short" then
		CI.Prefetch(index)
		self.results:SetEmptyText("Type at least 3 letters, e.g. \"arcanite\", \"mooncloth\" or \"enchant boots\".")
		self.status:SetText(string.format("%d recipes from %d crafters", index.recipeCount, index.crafterCount))
	else
		self.results:SetEmptyText(loading > 0 and "Loading item names..." or "Nobody in the guild has that recipe yet.")
		local text = (#results >= CI.MAX_RESULTS) and (CI.MAX_RESULTS .. "+ results, type more to narrow it down")
			or (#results .. (#results == 1 and " result" or " results"))
		if loading > 0 then text = text .. "  ·  " .. C("spark") .. "loading " .. loading .. " names...|r" end
		self.status:SetText(text)
	end
	self.results:SetLoading(state ~= "empty" and state ~= "short" and loading > 0)

	local r = self:Picked(index)
	self.crafters:SetShown(r ~= nil)
	self.post:SetShown(r ~= nil and #r.crafters > 0)
	self.copy:SetShown(r ~= nil and #r.crafters > 0)
	self.reagents:SetShown(r ~= nil)
	self.favButton:SetShown(r ~= nil)
	self.empty:SetShown(r == nil)
	if not r then
		self.title:SetText("")
		self.sub:SetText("")
		return
	end
	local list = CI.Crafters(index, r.recipeID, guild, now)
	local fav = SK.Favourites.IsRecipe(r.recipeID)
	self.favButton:SetActive(fav)
	self.title:SetText(star(fav) .. icon(r) .. coloured(r, CI.NameOf(r) or "..."))
	self.sub:SetText(profName(r.skillLine) .. "  ·  " .. Crafters.CountText(#list, CI.OnlineCount(list)))
	self.crafters:SetItems(list)
	self.crafters:SetEmptyText("Nobody in the guild knows this recipe yet.")
	local reagents = SK.Reagents.Text(SK.Reagents.Lines(r.recipeID), Theme.Code)
	self.reagents:SetText(reagents and ("Needs: " .. reagents) or
		"Reagents show once you've opened this profession's window (they're read from your game).")
end

SK.MainFrame:AddTab("crafters", "Crafters", Crafters)
