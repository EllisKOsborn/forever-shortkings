-- Merge rules for incoming profiles. Pure functions, covered by tests.
--
--  1. The profile's character must be in the current guild roster.
--  2. Its timestamp may not be more than 5 minutes in the future.
--  3. Its hash must match its content.
--  4. Our own account's characters are never overwritten from outside.
--  5. Owner copy (sent by the character itself, or by an alt that the
--     character itself listed in its `family`): always beats a relayed copy;
--     replaces another owner copy if it is the same age or newer.
--  6. Relay copy: accepted only if strictly newer than what we have, and
--     never over an owner copy that is newer.
local _, SK = ...

local Merge = {}
SK.Merge = Merge

Merge.MAX_FUTURE = 300

-- Size limits for incoming profiles: well above anything the game can
-- produce, low enough that a crafted profile can't bloat saved data.
Merge.LIMITS = {
	str = 64,        -- names, class, race, version, guid
	text = 256,      -- profession, faction and talent tree names
	link = 1024,     -- one item link
	gear = 20,       -- slots
	profs = 12,      -- professions (primary + secondary)
	recipes = 1500,  -- recipes per profession
	cds = 600,       -- cooldown entries
	reps = 400,      -- reputations
	trees = 8,       -- talent trees
	nodes = 600,     -- talents
	att = 64,        -- attunement flags
	family = 60,     -- characters on one account
	depth = 6,       -- nesting of fields this version doesn't know about
}
local L = Merge.LIMITS

local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function optNum(v) return v == nil or finite(v) end
local function str(v, max) return type(v) == "string" and #v <= max end
local function optStr(v, max) return v == nil or str(v, max) end
local function optBool(v) return v == nil or type(v) == "boolean" end
local function optIcon(v) return v == nil or finite(v) or str(v, L.text) end

-- Every entry of table t passes fn(k, v), and there are at most max of them.
local function each(t, max, fn)
	if type(t) ~= "table" then return false end
	local n = 0
	for k, v in pairs(t) do
		n = n + 1
		if n > max or not fn(k, v) then return false end
	end
	return true
end

-- Release versions ("0.2.4", "v0.2.4-3-gabc123"), commit hashes and "dev".
-- Nothing else is shown or printed, so a message can't put arbitrary text
-- (links, colours, "download the fix at ...") in someone's chat window.
function Merge.IsVersion(v)
	return type(v) == "string" and #v <= 32 and v:match("^[%w][%w%.%-%+_]*$") ~= nil
end

-- One item link, and nothing else that could be clicked or shown as a link.
function Merge.IsItemLink(v)
	if not str(v, L.link) or not v:find("|Hitem:", 1, true) then return false end
	local _, links = v:gsub("|H", "")
	return links == 1
end

-- Fields this version doesn't know (from a newer version) are kept so the
-- hash still matches, but only plain values in shallow tables.
local function plain(v, depth)
	local t = type(v)
	if t == "string" then return #v <= L.link end
	if t == "number" then return finite(v) end
	if t == "boolean" then return true end
	if t ~= "table" or depth >= L.depth then return false end
	for k, x in pairs(v) do
		if not plain(k, depth + 1) or not plain(x, depth + 1) then return false end
	end
	return true
end

local isNum = function(k) return finite(k) end

local FIELDS = {
	guid = function(v) return type(v) == "string" and #v >= 3 and #v <= L.str end,
	updated = finite,
	hash = function(v) return str(v, L.str) end,
	v = finite,
	name = function(v) return optStr(v, L.str) end,
	realm = function(v) return optStr(v, L.str) end,
	class = function(v) return optStr(v, L.str) end,
	race = function(v) return optStr(v, L.str) end,
	faction = function(v) return optStr(v, L.str) end,
	main = function(v) return optStr(v, L.str) end,
	addon = function(v) return v == nil or Merge.IsVersion(v) end,
	level = optNum,
	ilvl = optNum,
	gear = function(v)
		return v == nil or each(v, L.gear, function(k, link)
			return isNum(k) and k >= 0 and k <= 19 and Merge.IsItemLink(link)
		end)
	end,
	talents = function(v)
		if v == nil then return true end
		if type(v) ~= "table" or not optStr(v.api, L.str) then return false end
		if v.trees ~= nil and not each(v.trees, L.trees, function(k, t)
			return isNum(k) and type(t) == "table" and optStr(t.n, L.text) and optNum(t.p) and optIcon(t.i)
		end) then return false end
		return v.nodes == nil or each(v.nodes, L.nodes, function(k, rank)
			return (isNum(k) or str(k, L.text)) and finite(rank)
		end)
	end,
	profs = function(v)
		return v == nil or each(v, L.profs, function(k, p)
			return isNum(k) and type(p) == "table" and optStr(p.name, L.text) and optNum(p.rank)
				and optNum(p.max) and optIcon(p.icon) and optBool(p.primary) and optNum(p.scanned)
		end)
	end,
	recipes = function(v)
		return v == nil or each(v, L.profs, function(k, list)
			return isNum(k) and each(list, L.recipes, function(id, item) return isNum(id) and finite(item) end)
		end)
	end,
	cds = function(v)
		return v == nil or each(v, L.cds, function(k, at) return isNum(k) and finite(at) end)
	end,
	reps = function(v)
		return v == nil or each(v, L.reps, function(k, r)
			return isNum(k) and type(r) == "table" and optStr(r.n, L.text) and optNum(r.r) and optNum(r.v)
		end)
	end,
	att = function(v)
		return v == nil or each(v, L.att, function(k, x) return str(k, L.str) and type(x) == "boolean" end)
	end,
	family = function(v)
		return v == nil or each(v, L.family, function(k, g) return isNum(k) and str(g, L.str) end)
	end,
	hidden = function(v)
		return v == nil or each(v, L.att, function(k, x) return str(k, L.str) and type(x) == "boolean" end)
	end,
}
Merge.FIELDS = FIELDS

local REQUIRED = { guid = "bad guid", updated = "bad timestamp", hash = "no hash", v = "no version" }

-- Full shape check of an incoming profile, so a malformed or crafted
-- message can never break the UI for whoever receives (and relays) it.
function Merge.Validate(p)
	if type(p) ~= "table" then return false, "not a table" end
	for k, why in pairs(REQUIRED) do
		if p[k] == nil or not FIELDS[k](p[k]) then return false, why end
	end
	for k, v in pairs(p) do
		local check = FIELDS[k]
		if check then
			if not check(v) then return false, "bad field " .. tostring(k) end
		elseif type(k) ~= "string" or #k > L.str or not plain(v, 1) then
			return false, "bad extra field"
		end
	end
	return true
end

function Merge.IsOwnerCopy(senderGUID, incoming, stored)
	if not senderGUID then return false end
	if senderGUID == incoming.guid then return true end
	-- Alt relationship counts only as stated by the character itself.
	if stored and stored.source == "owner" and type(stored.family) == "table" then
		for _, g in ipairs(stored.family) do
			if g == senderGUID then return true end
		end
	end
	return false
end

-- Returns accept, reason.
function Merge.Decide(stored, incoming, isOwner, now, isMember)
	if not isMember then return false, "not in guild" end
	if incoming.updated > now + Merge.MAX_FUTURE then return false, "future timestamp" end
	if SK.Profile.HashOf(incoming) ~= incoming.hash then return false, "hash mismatch" end
	if not stored then return true, "new" end
	if stored.source == "self" then return false, "our own character" end
	if stored.hash == incoming.hash then return false, "unchanged" end
	if isOwner then
		if stored.source ~= "owner" then return true, "owner beats relay" end
		if incoming.updated >= stored.updated then return true, "newer owner copy" end
		return false, "older owner copy"
	end
	if incoming.updated > stored.updated then return true, "newer relay" end
	return false, "relay not newer"
end
