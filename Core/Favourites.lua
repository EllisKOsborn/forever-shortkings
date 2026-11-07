-- Favourites (B6): starred recipes and crafters. Saved on this computer
-- only (ShortRoyaltyDB.favourites), never sent to anyone.
local _, SK = ...

local Fav = SK:NewModule("Favourites")

local function store()
	local f = SK.DB.favourites
	f.recipes, f.crafters = f.recipes or {}, f.crafters or {}
	return f
end

function Fav.IsRecipe(recipeID) return recipeID ~= nil and store().recipes[recipeID] == true end
function Fav.IsCrafter(guid) return guid ~= nil and store().crafters[guid] == true end

local function toggle(t, key)
	if key == nil then return false end
	t[key] = (not t[key]) and true or nil
	SK:Fire("FAVOURITES_CHANGED")
	return t[key] == true
end

function Fav.ToggleRecipe(recipeID) return toggle(store().recipes, recipeID) end
function Fav.ToggleCrafter(guid) return toggle(store().crafters, guid) end

function Fav.Recipes() return store().recipes end
