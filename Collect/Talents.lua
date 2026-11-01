-- Talents. Forever draws Classic-style trees on top of the modern trait
-- system (C_Traits), as Blizzard's Camelot ClassTalentsFrame does. We store:
--   trees = { { n = tree name, p = points, i = icon }, ... }  (display order)
--   nodes = { [spellID] = rank }   spell IDs resolve to names/icons for anyone
local _, SK = ...

local Talents = SK:NewModule("Talents")
local Compat = SK.Compat

local function readTraits()
	local configID = Compat.ActiveTraitConfigID()
	if not configID then return nil, "no active talent config" end
	local config = C_Traits.GetConfigInfo(configID)
	if not config or not config.treeIDs or #config.treeIDs == 0 then return nil, "no talent trees" end

	local trees, nodes, total = {}, {}, 0
	for _, treeID in ipairs(config.treeIDs) do
		local groups, byGroup = {}, {}
		if C_Traits.GetGroupDisplayInfoByTreeID then
			local infos = C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}
			table.sort(infos, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
			for _, g in ipairs(infos) do
				local entry = { n = g.displayName, p = 0, i = g.icon }
				groups[#groups + 1] = entry
				byGroup[g.groupID] = entry
			end
		end
		for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
			local node = C_Traits.GetNodeInfo(configID, nodeID)
			local rank = node and (node.ranksPurchased or node.activeRank or node.currentRank) or 0
			if rank > 0 then
				total = total + rank
				for _, gid in ipairs(node.groupIDs or {}) do
					if byGroup[gid] then byGroup[gid].p = byGroup[gid].p + rank end
				end
				local entryID = node.activeEntry and node.activeEntry.entryID
				local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
				local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
				if def and def.spellID then nodes[def.spellID] = rank end
			end
		end
		for _, g in ipairs(groups) do trees[#trees + 1] = g end
	end
	if #trees == 0 then
		trees[1] = { n = config.name, p = total }
	end
	return { api = "traits", trees = trees, nodes = nodes }
end

-- Classic fallback. GetTalentTabInfo's return order changed between
-- clients: (name, icon, points) or (id, name, description, icon, points).
local function readClassic()
	local trees, nodes = {}, {}
	for tab = 1, GetNumTalentTabs() do
		local a, b, c, d, e = GetTalentTabInfo(tab)
		local name, icon, points
		if type(a) == "number" then
			name, icon, points = b, d, e
		else
			name, icon, points = a, b, c
		end
		trees[#trees + 1] = { n = name, p = tonumber(points) or 0, i = icon }
		if GetNumTalents and GetTalentInfo then
			for i = 1, GetNumTalents(tab) do
				local tname, _, _, _, rank = GetTalentInfo(tab, i)
				if tname and rank and rank > 0 then nodes[tname] = rank end
			end
		end
	end
	return { api = "classic", trees = trees, nodes = nodes }
end

function Talents.Read()
	local api = Compat.TalentAPI()
	local ok, result, why
	if api == "traits" then
		ok, result, why = pcall(readTraits)
	elseif api == "classic" then
		ok, result = pcall(readClassic)
	else
		return nil
	end
	if not ok then
		SK:Debug("talent read failed: %s", tostring(result))
		return nil
	end
	if not result and why then SK:Debug("talents: %s", why) end
	return result
end

-- "31/20/0" and the name of the tree with most points.
function Talents.Summary(t)
	if not t or not t.trees or #t.trees == 0 then return nil, nil end
	local parts, best = {}, nil
	for _, tree in ipairs(t.trees) do
		parts[#parts + 1] = tostring(tree.p or 0)
		if (tree.p or 0) > 0 and (not best or tree.p > best.p) then best = tree end
	end
	return table.concat(parts, "/"), best and best.n
end
