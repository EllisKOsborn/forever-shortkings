-- Alts: groups characters that belong to the same player.
--
-- A link between two characters counts only when BOTH characters' own
-- profiles list each other in `family` (both were logged in on the same
-- account), so nobody can claim someone else as their alt. The main is the
-- character the player marked as main (`main` field); otherwise the
-- highest level, then highest item level.
local _, SK = ...

local Alts = {}
SK.Alts = Alts

local function contains(list, value)
	if type(list) ~= "table" then return false end
	for _, v in ipairs(list) do
		if v == value then return true end
	end
	return false
end

-- profiles: guid -> profile; isMember(guid) -> bool.
-- Returns groupOf (guid -> group), groups (list). A group is
-- { main = guid, members = { guid, ... } } with the main first.
function Alts.Groups(profiles, isMember)
	local parent = {}
	local function find(x)
		while parent[x] ~= x do
			parent[x] = parent[parent[x]]
			x = parent[x]
		end
		return x
	end
	for guid in pairs(profiles) do
		if isMember(guid) then parent[guid] = guid end
	end
	for guid, p in pairs(profiles) do
		if parent[guid] and type(p.family) == "table" then
			for _, other in ipairs(p.family) do
				local q = profiles[other]
				if parent[other] and q and contains(q.family, guid) then
					local a, b = find(guid), find(other)
					if a ~= b then parent[b] = a end
				end
			end
		end
	end

	local byRoot = {}
	for guid in pairs(parent) do
		local root = find(guid)
		byRoot[root] = byRoot[root] or { members = {} }
		table.insert(byRoot[root].members, guid)
	end

	local groupOf, groups = {}, {}
	for _, group in pairs(byRoot) do
		local votes, best = {}, nil
		for _, g in ipairs(group.members) do
			local m = profiles[g].main
			if m and contains(group.members, m) then votes[m] = (votes[m] or 0) + 1 end
		end
		for g, n in pairs(votes) do
			if not best or n > votes[best] or (n == votes[best] and g < best) then best = g end
		end
		if not best then
			for _, g in ipairs(group.members) do
				local p, b = profiles[g], best and profiles[best]
				if not b or (p.level or 0) > (b.level or 0)
					or ((p.level or 0) == (b.level or 0) and (p.ilvl or 0) > (b.ilvl or 0))
					or ((p.level or 0) == (b.level or 0) and (p.ilvl or 0) == (b.ilvl or 0) and g < best) then
					best = g
				end
			end
		end
		group.main = best
		table.sort(group.members, function(a, b)
			if a == best then return true end
			if b == best then return false end
			return a < b
		end)
		groups[#groups + 1] = group
		for _, g in ipairs(group.members) do groupOf[g] = group end
	end
	return groupOf, groups
end
