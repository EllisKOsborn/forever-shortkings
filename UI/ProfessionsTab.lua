-- Professions tab (v0.3): the guild's coverage board, one profession at a
-- time (crafters and recipes), and the cooldown board. Numbers come from
-- Core/ProfBoard.lua; clicking a recipe opens it in the Crafters tab.
local _, SK = ...

local Prof = SK:NewModule("ProfessionsTab")
local Theme, W, Compat = SK.Theme, SK.Widgets, SK.Compat
local PB, CI, Fav = SK.ProfBoard, SK.CraftIndex, SK.Favourites
local S, SP = Theme.SIZES, Theme.SPACE

Prof.CRAFTERS_W = 440
Prof.RECIPES_W = S.window[1] - 2 * SP.l - Prof.CRAFTERS_W - SP.l

local VIEWS = { { "board", "Guild" }, { "cooldowns", "Cooldowns" } }
local RECIPE_FILTERS = {
	{ "all", "All" }, { "one", "Only one crafter" }, { "fav", "Favourites" }, { "nobody", "Nobody knows" },
}

local function dot(status) return SK.RosterTab.DOT[status] or SK.RosterTab.DOT.offline end

local function recordedText(ts, now)
	if not ts then return Theme.DASH end
	local ago = Theme.Ago(ts, now)
	local text = ago == "now" and ago or (ago .. " ago")
	if Theme.IsStale(ts, now) then return Theme.Paint("spark", text) end
	return Theme.Paint("dim", text)
end

local function whisperButton(row)
	row.whisper = W.Button(row, "Whisper", 60, S.controlSmall, function(b)
		if b.target then Compat.SendTell(SK.Identity:WhisperTarget(b.target)) end
	end)
	row.whisper:SetPoint("RIGHT", -SP.xxs, 0)
	row.whisper.disabledTooltip = "Offline"
	row.widgets[#row.widgets + 1] = row.whisper
end

local function updateWhisper(row, c)
	row.whisper.target = c.whisper
	row.whisper:SetDisabled(c.whisper == nil)
	row.whisper:SetShown(not SK.DB.account[c.guid])
end

---------------------------------------------------------------------------
-- Columns (each list: its width minus the 12 px scroll bar)
---------------------------------------------------------------------------
-- Board: 848 - 12 = 836.
local BOARD_COLUMNS = {
	{ key = "name", title = "Profession", width = 170 },
	{ key = "chars", title = "Characters", width = 88, align = "RIGHT" },
	{ key = "atMax", title = "At " .. SK.Data.SKILL_CAP, width = 70, align = "RIGHT" },
	{ key = "online", title = "Online", width = 70, align = "RIGHT" },
	{ key = "top", title = "Top skill", width = 80, align = "RIGHT" },
	{ key = "scan", title = "Latest recipes", width = 112, align = "RIGHT" },
	{ key = "specs", title = "Specialisations", width = 246 },
}

-- Crafters: 440 - 12 = 428.
local CRAFTER_COLUMNS = {
	{ key = "name", title = "Character", width = 152 },
	{ key = "skill", title = "Skill", width = 50, align = "RIGHT" },
	{ key = "spec", title = "Speciality", width = 92 },
	{ key = "scan", title = "Recipes", width = 70, align = "RIGHT" },
	{ key = "btn", title = "", width = 64 },
}

-- Recipes: 392 - 12 = 380.
local RECIPE_COLUMNS = {
	{ key = "name", title = "Recipe", width = 290 },
	{ key = "count", title = "Crafters", width = 90, align = "RIGHT" },
}

-- Cooldowns: 836.
local COOLDOWN_COLUMNS = {
	{ key = "name", title = "Cooldown", width = 270 },
	{ key = "who", title = "Crafter", width = 190 },
	{ key = "left", title = "Ready in", width = 110, align = "RIGHT" },
	{ key = "asof", title = "As of", width = 140, align = "RIGHT" },
	{ key = "btn", title = "", width = 126 },
}

local function setBoardCell(fs, r, col)
	local k = col.key
	if k == "name" then
		fs:SetText(r.chars > 0 and r.name or Theme.Paint("dim", r.name))
	elseif k == "chars" then
		fs:SetText(r.chars > 0 and r.chars or Theme.Paint("spark", "nobody"))
	elseif k == "atMax" then
		fs:SetText(r.chars > 0 and r.atMax or Theme.DASH)
	elseif k == "online" then
		fs:SetText(r.online > 0 and Theme.Paint("good", r.online) or (r.chars > 0 and Theme.Paint("dim", 0) or Theme.DASH))
	elseif k == "top" then
		fs:SetText(r.top > 0 and r.top or Theme.DASH)
	elseif k == "scan" then
		fs:SetText(recordedText(r.lastScan, Prof.now))
	elseif k == "specs" then
		local t = PB.SpecText(r.specs)
		fs:SetText(t ~= "" and Theme.Paint("dim", t) or "")
	end
end

local function setCrafterCell(fs, c, col)
	local k = col.key
	if k == "name" then
		local star = c.fav and (Theme.Star("beard") .. " ") or ""
		local extra = c.via and Theme.Paint("good", "  on " .. (c.viaName or "alt"))
			or (c.altOf and Theme.Paint("dim", "  alt of " .. c.altOf)) or ""
		fs:SetText(dot(c.status) .. " " .. star .. Theme.ClassText(c.name, c.class) .. extra)
	elseif k == "skill" then
		fs:SetText(c.skill > 0 and c.skill or Theme.DASH)
	elseif k == "spec" then
		fs:SetText(#c.specs > 0 and Theme.Paint("dim", table.concat(c.specs, ", ")) or "")
	elseif k == "scan" then
		if c.hidden then fs:SetText(Theme.Paint("dim", "private"))
		elseif SK.Data.GATHERING[Prof.skillLine] then fs:SetText("")
		else fs:SetText(recordedText(c.scanned, Prof.now)) end
	else
		fs:SetText("")
	end
end

local function recipeIcon(r)
	local tex = r.itemID > 0 and Compat.ItemIcon(r.itemID) or Compat.SpellIcon(r.recipeID)
	return tex and ("|T" .. tex .. ":14:14:0:0:64:64:5:59:5:59|t ") or ""
end

local function setRecipeCell(fs, r, col)
	if col.key == "name" then
		local hex = r.itemID > 0 and Compat.ItemQualityHex(r.itemID)
		local name = hex and ("|c" .. hex .. r.name .. "|r") or r.name
		fs:SetText((r.fav and (Theme.Star("beard") .. " ") or "") .. recipeIcon(r) .. name)
	else
		if r.count == 0 then fs:SetText(Theme.Paint("spark", "nobody"))
		elseif r.count == 1 then fs:SetText(Theme.Paint("spark", "1"))
		else fs:SetText(r.count) end
	end
end

local function setCooldownCell(fs, r, col)
	local k = col.key
	if k == "name" then
		fs:SetText(CI.SpellName(r.recipeID) or ("Recipe " .. r.recipeID))
	elseif k == "who" then
		fs:SetText(dot(r.status) .. " " .. Theme.ClassText(r.name, r.class))
	elseif k == "left" then
		fs:SetText(r.ready and Theme.Paint("good", "Ready") or PB.TimeLeft(r.left))
	elseif k == "asof" then
		if not r.asOf then fs:SetText(Theme.DASH)
		else
			local ago = Theme.Ago(r.asOf, Prof.now)
			local t = (r.guid == Compat.PlayerGUID() or ago == "now") and "now" or (ago .. " ago")
			fs:SetText(Theme.Paint(r.stale and "spark" or "dim", t))
		end
	else
		fs:SetText("")
	end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function Prof:Build(page)
	self.page = page
	self.filter = "all"
	local settings = SK.DB.settings

	-- Toolbar: Guild / Cooldowns, or a back button in the profession view.
	self.viewChips = {}
	local prev
	for _, v in ipairs(VIEWS) do
		local c = W.Chip(page, v[2], function()
			settings.profView = v[1]
			Prof.skillLine = nil
			Prof:Refresh()
		end)
		c.value = v[1]
		if prev then c:SetPoint("LEFT", prev, "RIGHT", SP.xs, 0) else c:SetPoint("TOPLEFT", 0, -1) end
		self.viewChips[#self.viewChips + 1] = c
		prev = c
	end
	self.back = W.Button(page, "All professions", nil, S.control, function()
		Prof.skillLine = nil
		Prof:Refresh()
	end)
	self.back:SetPoint("TOPLEFT", 0, 0)
	self.heading = Theme.Text(page, "title", "text")
	self.heading:SetPoint("LEFT", self.back, "RIGHT", SP.m, 0)
	self.status = Theme.Text(page, "small", "dim")
	self.status:SetPoint("TOPRIGHT", 0, -SP.xs)
	self.status:SetPoint("LEFT", page, "LEFT", 240, 0)
	self.status:SetJustifyH("RIGHT")
	self.status:SetWordWrap(false)

	local top = -(S.control + SP.m)
	-- The reminder line ("your Tailoring went up"), only when there is one.
	self.nudge = Theme.Text(page, "small", "spark")
	self.nudge:SetPoint("TOPLEFT", 0, top)
	self.nudge:SetPoint("RIGHT", page, "RIGHT", 0, 0)
	self.nudge:SetWordWrap(true)

	self.board = W.List(page, {
		columns = BOARD_COLUMNS, setCell = setBoardCell,
		onClick = function(r) Prof:Open(r.skillLine) end,
		onEnter = function(row, r)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:AddLine(r.name)
			if r.chars == 0 then
				Theme.TipLine(GameTooltip, "Nobody in the guild has this profession yet.", "spark")
			else
				Theme.TipLine(GameTooltip, Theme.Count(r.chars, "character") .. ", " .. r.online .. " online", "dim")
			end
			Theme.TipLine(GameTooltip, "Click to see crafters and recipes", "gold")
			GameTooltip:Show()
		end,
	})
	self.board:SetPoint("TOPLEFT", 0, top)
	self.board:SetPoint("BOTTOMRIGHT")

	self.cooldowns = W.List(page, {
		columns = COOLDOWN_COLUMNS, setCell = setCooldownCell,
		decorate = whisperButton, update = updateWhisper,
		onEnter = function(row, r)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:AddLine(CI.SpellName(r.recipeID) or ("Recipe " .. r.recipeID))
			Theme.TipLine(GameTooltip, Theme.ClassText(r.name, r.class))
			Theme.TipLine(GameTooltip, "A cooldown only updates while its owner is online.", "dim", true)
			if r.stale then
				Theme.TipLine(GameTooltip, "We last heard from them " .. (r.asOf and (Theme.Ago(r.asOf) .. " ago") or
					"a while ago") .. ": it may be ready already.", "spark", true)
			end
			GameTooltip:Show()
		end,
		onClick = function(r) SK.CharacterTab:ShowCharacter(r.guid) end,
	})
	self.cooldowns:SetPoint("TOPLEFT", 0, top)
	self.cooldowns:SetPoint("BOTTOMRIGHT")

	-- One profession: crafters on the left, recipes on the right.
	self.crafters = W.List(page, {
		columns = CRAFTER_COLUMNS, setCell = setCrafterCell,
		decorate = whisperButton, update = updateWhisper,
		onEnter = function(row, c)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:AddLine(Theme.ClassText(c.name, c.class))
			if c.altOf then Theme.TipLine(GameTooltip, "alt of " .. c.altOf, "dim") end
			if c.via then Theme.TipLine(GameTooltip, "Online on " .. (c.viaName or "an alt"), "good") end
			if c.max and c.max > 0 then Theme.TipLine(GameTooltip, "Skill " .. c.skill .. " / " .. c.max, "dim") end
			if #c.specs > 0 then Theme.TipLine(GameTooltip, table.concat(c.specs, ", "), "text") end
			if c.hidden then
				Theme.TipLine(GameTooltip, "Keeps their recipes private", "dim")
			elseif c.scanned then
				local stale = Theme.IsStale(c.scanned)
				Theme.TipLine(GameTooltip, "Recipes recorded " .. Theme.Ago(c.scanned) .. " ago" ..
					(stale and " (may be out of date)" or ""), stale and "spark" or "dim")
			elseif not SK.Data.GATHERING[Prof.skillLine] then
				Theme.TipLine(GameTooltip, "Hasn't opened this profession window with the addon yet", "dim", true)
			end
			Theme.TipLine(GameTooltip, "Click to view character  ·  Right-click to " ..
				(c.fav and "unstar" or "star"), "gold")
			GameTooltip:Show()
		end,
		onClick = function(c, button)
			if button == "RightButton" then
				Fav.ToggleCrafter(c.guid)
			else
				SK.CharacterTab:ShowCharacter(c.guid)
			end
		end,
	})
	self.crafters:SetPoint("TOPLEFT", 0, top)
	self.crafters:SetPoint("BOTTOMLEFT")
	self.crafters:SetWidth(Prof.CRAFTERS_W)

	local right = CreateFrame("Frame", nil, page)
	right:SetPoint("TOPLEFT", self.crafters, "TOPRIGHT", SP.l, 0)
	right:SetPoint("BOTTOMRIGHT")
	self.right = right
	self.filterChips = {}
	prev = nil
	for _, f in ipairs(RECIPE_FILTERS) do
		local c = W.Chip(right, f[2], function()
			Prof.filter = f[1]
			Prof:Refresh()
		end)
		c.value = f[1]
		if prev then c:SetPoint("LEFT", prev, "RIGHT", SP.xs, 0) else c:SetPoint("TOPLEFT", 0, -1) end
		self.filterChips[#self.filterChips + 1] = c
		prev = c
	end
	self.filterChips[4].tooltip = "Recipes the profession window lists that nobody in the guild has learned."
	self.recipes = W.List(right, {
		columns = RECIPE_COLUMNS, setCell = setRecipeCell,
		onEnter = function(row, r)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			if r.itemID > 0 and GameTooltip.SetItemByID then GameTooltip:SetItemByID(r.itemID)
			else GameTooltip:SetText(r.name) end
			local reagents = SK.Reagents.Text(SK.Reagents.Lines(r.recipeID), Theme.Code)
			if reagents then Theme.TipLine(GameTooltip, "Needs: " .. reagents, "dim", true) end
			Theme.TipLine(GameTooltip, "Click to see who can make it  ·  Right-click to " ..
				(r.fav and "unstar" or "star"), "gold")
			GameTooltip:Show()
		end,
		onClick = function(r, button)
			if button == "RightButton" then
				Fav.ToggleRecipe(r.recipeID)
			else
				SK.CraftersTab:ShowRecipe(r.recipeID, r.skillLine)
			end
		end,
	})
	self.recipes:SetPoint("TOPLEFT", 0, -(S.controlSmall + SP.s + 2))
	self.recipes:SetPoint("BOTTOMRIGHT")

	local function refreshIfShown() if page:IsShown() then Prof:Refresh() end end
	SK:On("NAMES_LOADED", refreshIfShown)
	SK:On("CRAFT_INDEX_UPDATED", refreshIfShown)
	SK:On("FAVOURITES_CHANGED", refreshIfShown)
end

function Prof:Open(skillLine)
	self.skillLine = skillLine
	self.filter = "all"
	self:Refresh()
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
function Prof:Refresh()
	if not self.board then return end
	local ctx = PB.Context()
	self.now = ctx.now
	local view = SK.DB.settings.profView == "cooldowns" and "cooldowns" or "board"
	local one = self.skillLine ~= nil
	for _, c in ipairs(self.viewChips) do
		c:SetShown(not one)
		c:SetActive(c.value == view)
	end
	self.back:SetShown(one)
	self.heading:SetShown(one)
	self.board:SetShown(not one and view == "board")
	self.cooldowns:SetShown(not one and view == "cooldowns")
	self.crafters:SetShown(one)
	self.right:SetShown(one)

	-- Reminder line (shown even when chat reminders are off).
	local nudge = SK.Professions.NudgeText(SK.Professions.CurrentNudges())
	self.nudge:SetText(nudge or "")
	self.nudge:SetShown(nudge ~= nil and not one)
	local shift = nudge and not one and (self.nudge:GetStringHeight() or 0) + SP.s or 0
	local top = -(S.control + SP.m) - shift
	self.board:SetPoint("TOPLEFT", 0, top)
	self.cooldowns:SetPoint("TOPLEFT", 0, top)

	if one then return self:RefreshOne(ctx) end
	if view == "cooldowns" then
		local rows = PB.Cooldowns(ctx)
		local ready = 0
		for _, r in ipairs(rows) do if r.ready then ready = ready + 1 end end
		self.cooldowns:SetItems(rows)
		self.cooldowns:SetEmptyText("No profession cooldowns yet. They appear once someone with a cooldown " ..
			"recipe (a transmute, Mooncloth...) opens their profession window with the addon.")
		self.status:SetText(#rows > 0 and (ready .. " ready  ·  " .. Theme.Count(#rows, "cooldown")) or "")
	else
		local rows = PB.Coverage(ctx)
		local missing = 0
		for _, r in ipairs(rows) do if r.chars == 0 then missing = missing + 1 end end
		self.board:SetItems(rows)
		self.status:SetText(missing > 0 and (Theme.Count(missing, "profession") .. " nobody has") or
			"Every profession is covered")
	end
end

function Prof:RefreshOne(ctx)
	local skillLine = self.skillLine
	self.heading:SetText(PB.ProfessionName(ctx, skillLine))
	local crafters = PB.Crafters(ctx, skillLine)
	self.crafters:SetItems(crafters)
	self.crafters:SetEmptyText("Nobody in the guild has this profession yet.")

	local unknown = #PB.Unknown(ctx, skillLine) > 0
	if self.filter == "nobody" and not unknown then self.filter = "all" end
	for _, c in ipairs(self.filterChips) do
		c:SetActive(c.value == self.filter)
		if c.value == "nobody" then c:SetShown(unknown) end
	end
	local rows, loading = PB.Recipes(ctx, skillLine, self.filter)
	self.recipes:SetItems(rows)
	self.recipes:SetLoading(loading > 0 and #rows == 0)
	local gathering = SK.Data.GATHERING[skillLine]
	local empty = {
		all = gathering and "Gathering professions have no recipes." or
			"No recipes yet. They appear after crafters open their profession window once.",
		one = "No recipe has just one crafter.",
		fav = "No starred recipes. Right-click a recipe to star it.",
		nobody = "Everything the profession window lists is known by someone.",
	}
	self.recipes:SetEmptyText(empty[self.filter])
	local online = 0
	for _, c in ipairs(crafters) do if c.status ~= "offline" then online = online + 1 end end
	self.status:SetText(Theme.Count(#crafters, "character") .. ", " .. online .. " online  ·  " ..
		Theme.Count(#rows, "recipe"))
end

SK.MainFrame:AddTab("professions", "Professions", Prof)
