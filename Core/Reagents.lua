-- Reagents (B2): what a recipe needs, read from the game on this computer
-- (C_TradeSkillUI.GetRecipeSchematic via Compat) and cached in
-- ShortRoyaltyDB.reagents. Reagents are game data, not player data, so they
-- are never added to synced profiles. The cache is cleared when the game
-- build changes.
local _, SK = ...

local R = SK:NewModule("Reagents")
local Compat = SK.Compat

R.MAX_SHOWN = 8 -- reagent slots shown per recipe

local function cache()
	local db = SK.DB.reagents
	local build = Compat.BuildInfo().build
	if db.build ~= build then
		db.build, db.list = build, {}
	end
	db.list = db.list or {}
	return db.list
end

-- Compact stored form: { o = outputItemID, r = { { i = itemID | c = currencyID, q = qty } } }
local function pack(s)
	local out = { o = s.output, r = {} }
	for _, x in ipairs(s.reagents) do
		if (x.itemID or x.currencyID) and x.qty and x.qty > 0 then
			out.r[#out.r + 1] = { i = x.itemID, c = (not x.itemID) and x.currencyID or nil, q = x.qty }
		end
	end
	return out
end

-- Reads (once) and caches. Returns the packed entry or nil if the game
-- gave nothing for this recipe.
function R.Learn(recipeID)
	if type(recipeID) ~= "number" then return nil end
	local list = cache()
	if list[recipeID] then return list[recipeID] end
	local s = Compat.RecipeSchematic(recipeID)
	if not s or #s.reagents == 0 then return nil end
	local packed = pack(s)
	if #packed.r == 0 then return nil end
	list[recipeID] = packed
	return packed
end

R.Get = R.Learn

-- The bundled game data (Data/Recipes.lua) when the game itself gives
-- nothing (the window is closed, or another profession).
local function bundled(recipeID)
	local list = SK.RecipeDB and SK.RecipeDB.Reagents(recipeID) or {}
	if #list == 0 then return nil end
	local out = { r = {} }
	for _, x in ipairs(list) do out.r[#out.r + 1] = { i = x.itemID, q = x.qty } end
	return out
end

-- { { itemID, currencyID, qty, name, have, icon } } or nil.
-- `have` is the count in your bags (nil when the game can't tell).
function R.Lines(recipeID)
	local entry = R.Learn(recipeID) or bundled(recipeID)
	if not entry then return nil end
	local out = {}
	for i, x in ipairs(entry.r) do
		if i > R.MAX_SHOWN then break end
		out[#out + 1] = {
			itemID = x.i, currencyID = x.c, qty = x.q,
			name = x.i and SK.CraftIndex.ItemName(x.i) or nil,
			have = x.i and Compat.ItemCountInBags(x.i) or nil,
			icon = x.i and Compat.ItemIcon(x.i) or nil,
		}
	end
	return out
end

-- One line of text: "2 Iron Bar (have 3), 1 Coal (have 0)". Colours are
-- theme codes passed in so this stays testable without the UI.
function R.Text(lines, code)
	if not lines or #lines == 0 then return nil end
	local close = code and "|r" or ""
	code = code or function() return "" end
	local parts = {}
	for _, l in ipairs(lines) do
		local icon = l.icon and ("|T" .. l.icon .. ":14:14:0:0:64:64:5:59:5:59|t ") or ""
		local name = l.name or (l.currencyID and "currency" or "...")
		local piece = icon .. l.qty .. " " .. name
		if l.have then
			piece = piece .. " " .. code(l.have >= l.qty and "good" or "dim") .. "(have " .. l.have .. ")" .. close
		end
		parts[#parts + 1] = piece
	end
	return table.concat(parts, ",  ")
end
