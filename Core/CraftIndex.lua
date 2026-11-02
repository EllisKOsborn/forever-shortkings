-- CraftIndex: "who can make this?" for the Crafters tab and item tooltips.
--
-- Built from every member's recipes (profile.recipes[skillLine] =
-- { [recipeID] = itemID }, itemID 0 = no item, e.g. enchants):
--   index.recipes[recipeID] = { recipeID, itemID, skillLine, crafters = { guid, ... } }
--   index.byItem[itemID]    = { recipeID, ... }
-- Profiles with hidden recipes are skipped. Our own characters use the full
-- copy (SK.Profile:Get), so you always see your own recipes.
--
-- The index is built lazily (first use) and rebuilt, debounced, when
-- profiles change. Names load asynchronously in WoW, so they are cached for
-- the session and NAMES_LOADED fires (debounced) as they arrive.
local _, SK = ...

local CI = SK:NewModule("CraftIndex")
local Compat = SK.Compat

CI.REBUILD_DELAY = 2      -- seconds after the last profile change
CI.MAX_RESULTS = 200
CI.MIN_QUERY = 3
CI.REQUESTS_PER_SEARCH = 200 -- name loads asked for per search (the rest follow as names arrive)

CI.index = nil
CI.dirty = true

---------------------------------------------------------------------------
-- Building (pure)
---------------------------------------------------------------------------
-- getProfile(guid) -> profile or nil; isMember(guid) -> bool.
function CI.Build(guild, getProfile, isMember)
	local index = { recipes = {}, byItem = {}, skill = {}, scanned = {}, profNames = {}, crafterCount = 0, recipeCount = 0 }
	if not guild then return index end
	for guid, m in pairs(guild.members) do
		local p = not m.leftAt and isMember(guid) and getProfile(guid)
		if p and type(p.recipes) == "table" and not (p.hidden and p.hidden.recipes) then
			local any = false
			for skillLine, list in pairs(p.recipes) do
				if type(list) == "table" then
					local prof = p.profs and p.profs[skillLine]
					index.skill[guid] = index.skill[guid] or {}
					index.skill[guid][skillLine] = prof and prof.rank or 0
					index.scanned[guid] = index.scanned[guid] or {}
					index.scanned[guid][skillLine] = prof and prof.scanned
					if prof and type(prof.name) == "string" then index.profNames[skillLine] = prof.name end
					for recipeID, itemID in pairs(list) do
						if type(recipeID) == "number" then
							itemID = (type(itemID) == "number" and itemID > 0) and itemID or 0
							local r = index.recipes[recipeID]
							if not r then
								r = { recipeID = recipeID, itemID = itemID, skillLine = skillLine, crafters = {} }
								index.recipes[recipeID] = r
								index.recipeCount = index.recipeCount + 1
								if itemID > 0 then
									local list2 = index.byItem[itemID] or {}
									list2[#list2 + 1] = recipeID
									index.byItem[itemID] = list2
								end
							elseif r.itemID == 0 and itemID > 0 then
								r.itemID = itemID
								local list2 = index.byItem[itemID] or {}
								list2[#list2 + 1] = recipeID
								index.byItem[itemID] = list2
							end
							r.crafters[#r.crafters + 1] = guid
							any = true
						end
					end
				end
			end
			if any then index.crafterCount = index.crafterCount + 1 end
		end
	end
	for _, r in pairs(index.recipes) do table.sort(r.crafters) end
	index.groupOf = SK.Alts.Groups(guild.profiles, isMember)
	return index
end

function CI:Rebuild()
	local guild = SK.DBM:Guild()
	self.index = CI.Build(guild, function(g) return SK.Profile:Get(g, guild) end,
		function(g) return SK.Identity:IsMember(g) end)
	self.dirty = false
	SK:Fire("CRAFT_INDEX_UPDATED")
	return self.index
end

-- The current index. With `allowStale` (tooltips), an out-of-date index is
-- used as is; the debounced rebuild follows shortly.
function CI:Get(allowStale)
	if not self.index or (self.dirty and not allowStale) then return self:Rebuild() end
	return self.index
end

function CI:Invalidate()
	self.dirty = true
	if self.index then
		SK:Debounce("craftindex", CI.REBUILD_DELAY, function()
			if CI.dirty then CI:Rebuild() end
		end)
	end
end

SK:On("PROFILE_UPDATED", function() CI:Invalidate() end)
SK:On("SELF_UPDATED", function() CI:Invalidate() end)
SK:On("ROSTER_UPDATED", function() CI:Invalidate() end)

-- Profession name as the crafters' own clients reported it.
function CI.ProfessionName(index, skillLine)
	local n = index.profNames[skillLine]
	if n then return n end
	local d = SK.Data.PROFESSIONS[skillLine]
	return d and d.key or ("Profession " .. tostring(skillLine))
end

---------------------------------------------------------------------------
-- Names (async, cached for the session)
---------------------------------------------------------------------------
CI.itemNames, CI.spellNames = {}, {}
CI.pendingItems, CI.pendingSpells = {}, {}
local budget = math.huge

local function itemName(id)
	local n = CI.itemNames[id]
	if n then return n end
	n = Compat.ItemName(id)
	if n then CI.itemNames[id] = n; return n end
	if not CI.pendingItems[id] and budget > 0 then
		budget = budget - 1
		CI.pendingItems[id] = true
		Compat.RequestItem(id)
	end
	return nil
end

local function spellName(id)
	local n = CI.spellNames[id]
	if n then return n end
	n = Compat.SpellName(id)
	if n then CI.spellNames[id] = n; return n end
	if not CI.pendingSpells[id] and budget > 0 then
		budget = budget - 1
		CI.pendingSpells[id] = true
		Compat.RequestSpell(id)
	end
	return nil
end
CI.ItemName, CI.SpellName = itemName, spellName

-- Display name: the item's, or the recipe (spell) name for enchants.
function CI.NameOf(r)
	if r.itemID > 0 then return itemName(r.itemID) or spellName(r.recipeID) end
	return spellName(r.recipeID)
end

local function namesArrived()
	SK:Debounce("craftnames", 0.5, function() SK:Fire("NAMES_LOADED") end)
end

function CI:OnItemLoaded(itemID, success)
	if not self.pendingItems[itemID] then return end
	self.pendingItems[itemID] = nil
	if success ~= false then
		local n = Compat.ItemName(itemID)
		if n then self.itemNames[itemID] = n end
	end
	namesArrived()
end

function CI:OnSpellLoaded(spellID, success)
	if not self.pendingSpells[spellID] then return end
	self.pendingSpells[spellID] = nil
	if success ~= false then
		local n = Compat.SpellName(spellID)
		if n then self.spellNames[spellID] = n end
	end
	namesArrived()
end

SK:RegisterEvent("ITEM_DATA_LOAD_RESULT", function(_, id, ok) CI:OnItemLoaded(id, ok) end)
SK:RegisterEvent("SPELL_DATA_LOAD_RESULT", function(_, id, ok) CI:OnSpellLoaded(id, ok) end)

-- Start loading names before the first search (one batch; the rest follow
-- with later searches as NAMES_LOADED refreshes the tab).
function CI.Prefetch(index)
	budget = CI.REQUESTS_PER_SEARCH
	for recipeID, r in pairs(index.recipes) do
		if budget <= 0 then break end
		if r.itemID > 0 then itemName(r.itemID) end
		spellName(recipeID)
	end
	budget = math.huge
end

---------------------------------------------------------------------------
-- Search
---------------------------------------------------------------------------
-- Case-insensitive match on the item name or the recipe (spell) name.
-- Returns results (sorted by name, at most MAX_RESULTS), status, loading:
--   status "short" = fewer than MIN_QUERY letters, "empty" = nobody has
--   scanned a profession yet, "ok" otherwise. `loading` counts recipes whose
--   names haven't arrived yet (they may match once they do).
function CI.Search(index, query, limit)
	limit = limit or CI.MAX_RESULTS
	query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if index.recipeCount == 0 then return {}, "empty", 0 end
	if #query < CI.MIN_QUERY then return {}, "short", 0 end
	budget = CI.REQUESTS_PER_SEARCH
	local results, loading = {}, 0
	for recipeID, r in pairs(index.recipes) do
		local iname = r.itemID > 0 and itemName(r.itemID) or nil
		local sname = spellName(recipeID)
		if not iname and not sname then
			loading = loading + 1
		elseif (iname and iname:lower():find(query, 1, true)) or (sname and sname:lower():find(query, 1, true)) then
			results[#results + 1] = { recipeID = recipeID, itemID = r.itemID, skillLine = r.skillLine,
				name = iname or sname, recipe = r }
		end
	end
	budget = math.huge
	table.sort(results, function(a, b)
		if a.name ~= b.name then return a.name < b.name end
		return a.recipeID < b.recipeID
	end)
	for i = #results, limit + 1, -1 do results[i] = nil end
	return results, "ok", loading
end

---------------------------------------------------------------------------
-- Crafters of a recipe or an item, best-reachable first
---------------------------------------------------------------------------
local STATUS_RANK = { addon = 3, online = 2, offline = 1 }

-- One crafter's display info. A crafter who is offline but has a linked alt
-- online is reachable through that alt (`via`).
local function crafterInfo(index, guild, guid, skillLine, now)
	local m = guild.members[guid] or {}
	local p = guild.profiles[guid]
	local status = SK.Identity.Status(m, SK.DB.account[guid] and m.online, now)
	local info = { guid = guid, name = m.name or (p and p.name) or "?", class = m.class or (p and p.class),
		status = status, skill = index.skill[guid] and index.skill[guid][skillLine] or 0,
		scanned = index.scanned and index.scanned[guid] and index.scanned[guid][skillLine],
		whisper = status ~= "offline" and guid or nil }
	local g = index.groupOf and index.groupOf[guid]
	if g and #g.members > 1 then
		if g.main ~= guid then
			local mm = guild.members[g.main]
			info.altOf = mm and mm.name
		end
		for _, other in ipairs(g.members) do
			if other ~= guid then
				local om = guild.members[other]
				local st = SK.Identity.Status(om, SK.DB.account[other] and om and om.online, now)
				if STATUS_RANK[st] > STATUS_RANK[info.status] then
					info.status, info.via, info.viaName, info.whisper = st, other, om.name, other
				end
			end
		end
	end
	return info
end

local function sortCrafters(list)
	table.sort(list, function(a, b)
		if a.status ~= b.status then return STATUS_RANK[a.status] > STATUS_RANK[b.status] end
		if a.skill ~= b.skill then return a.skill > b.skill end
		return a.name:lower() < b.name:lower()
	end)
	return list
end

function CI.Crafters(index, recipeID, guild, now)
	local r = index.recipes[recipeID]
	local out = {}
	if not r or not guild then return out end
	now = now or Compat.Now()
	for _, guid in ipairs(r.crafters) do
		out[#out + 1] = crafterInfo(index, guild, guid, r.skillLine, now)
	end
	return sortCrafters(out)
end

-- Everyone who can make an item, through any recipe (deduplicated).
function CI.ItemCrafters(index, itemID, guild, now)
	local ids = index.byItem[itemID]
	local out, seen = {}, {}
	if not ids or not guild then return out end
	now = now or Compat.Now()
	for _, recipeID in ipairs(ids) do
		local r = index.recipes[recipeID]
		for _, guid in ipairs(r.crafters) do
			if not seen[guid] then
				seen[guid] = true
				out[#out + 1] = crafterInfo(index, guild, guid, r.skillLine, now)
			end
		end
	end
	return sortCrafters(out)
end

function CI.OnlineCount(crafters)
	local n = 0
	for _, c in ipairs(crafters) do
		if c.status ~= "offline" then n = n + 1 end
	end
	return n
end

-- "Bramble (online), Dabble +2 more" for item tooltips, or nil.
function CI.TooltipText(index, itemID, guild, now, maxNames)
	maxNames = maxNames or 3
	local crafters = CI.ItemCrafters(index, itemID, guild, now)
	if #crafters == 0 then return nil end
	local parts = {}
	for i = 1, math.min(maxNames, #crafters) do
		local c = crafters[i]
		local tag = ""
		if c.status ~= "offline" then tag = c.via and " (alt online)" or " (online)" end
		parts[i] = c.name .. tag
	end
	local text = table.concat(parts, ", ")
	if #crafters > maxNames then text = text .. " +" .. (#crafters - maxNames) .. " more" end
	return text, crafters
end

-- "[Item] can be made by: A, B, C" for guild chat, kept under the 255
-- character chat limit. Online crafters come first.
function CI.ChatText(label, crafters, maxLen)
	maxLen = maxLen or 255
	local text = label .. " can be made by: "
	local shown = 0
	for i, c in ipairs(crafters) do
		local piece = (i > 1 and ", " or "") .. c.name
		local rest = #crafters - i
		local tail = rest > 0 and (" +" .. rest .. " more") or ""
		if #text + #piece + #tail > maxLen then
			return text .. " +" .. (#crafters - shown) .. " more"
		end
		text = text .. piece
		shown = i
	end
	return text
end
