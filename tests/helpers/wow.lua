-- A small, controllable stand-in for the WoW client API. Only what the
-- non-UI code needs. Tests change `W` (the world) and call W.advance().
local W = {}

local function noop() end

function W.reset()
	W.now = 1800000000
	W.timers = {}
	W.player = { guid = "Player-1-0000000A", name = "Pip", realm = nil, class = "MAGE",
		race = "Gnome", level = 60, faction = "Alliance" }
	W.guild = { name = "Short Kings" }
	W.roster = {}            -- { {name=, guid=, rank=, rankIndex=, level=, class=, online=} }
	W.showOffline = true
	W.combat = false
	W.instance = nil         -- nil or "raid"/"party"/...
	W.lockdown = false
	W.trial = false
	W.gear = {}
	W.quests = {}            -- [questID] = true
	W.professions = {}       -- list of {name, icon, rank, max, skillLine}
	W.tradeskill = nil       -- { skillLine, name, rank, max, recipes = {[id]={learned=, itemID=, cd=}}, linked=bool }
	W.factions = {}          -- list of FactionData
	W.prints = {}

	_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
	_G.date = os.date
	_G.time = function() return W.now end
	_G.GetTime = function() return W.now end
	_G.GetServerTime = function() return W.now end
	_G.print = function(...) W.prints[#W.prints + 1] = table.concat({ ... }, " ") end
	_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) W.prints[#W.prints + 1] = m end }
	_G.geterrorhandler = function() return function(e) error(e, 0) end end
	_G.Enum = { SendAddonMessageResult = { Success = 0, AddOnMessageLockdown = 11 },
		ClubMemberPresence = { Unknown = 0, Online = 1, Offline = 3 } }

	_G.CreateFrame = function()
		local f = { events = {} }
		function f:RegisterEvent(e) self.events[e] = true end
		function f:UnregisterEvent(e) self.events[e] = nil end
		function f:SetScript(name, fn) self[name] = fn end
		return setmetatable(f, { __index = function() return noop end })
	end

	_G.C_Timer = {
		After = function(sec, fn) W.timers[#W.timers + 1] = { at = W.now + sec, fn = fn } end,
		NewTicker = function(sec, fn)
			local t = { cancelled = false }
			local function tick()
				if t.cancelled then return end
				fn()
				W.timers[#W.timers + 1] = { at = W.now + sec, fn = tick }
			end
			W.timers[#W.timers + 1] = { at = W.now + sec, fn = tick }
			function t:Cancel() self.cancelled = true end
			return t
		end,
	}

	_G.C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end }
	_G.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
	_G.UnitGUID = function(u) if u == "player" then return W.player.guid end end
	_G.UnitFullName = function(u) if u == "player" then return W.player.name, W.player.realm end end
	_G.UnitName = function(u) if u == "player" then return W.player.name end end
	_G.UnitClass = function() return W.player.class, W.player.class, 8 end
	_G.UnitRace = function() return W.player.race, W.player.race end
	_G.UnitLevel = function() return W.player.level end
	_G.UnitFactionGroup = function() return W.player.faction end
	_G.InCombatLockdown = function() return W.combat end
	_G.IsInInstance = function() return W.instance ~= nil, W.instance or "none" end
	_G.IsTrialAccount = function() return W.trial end
	_G.IsVeteranTrialAccount = function() return false end
	_G.C_ChatInfo = {
		InChatMessagingLockdown = function() return W.lockdown end,
		AreOutgoingAddonChatMessagesRestricted = function() return false end,
		RegisterAddonMessagePrefix = noop,
	}

	_G.IsInGuild = function() return W.guild ~= nil end
	_G.GetGuildInfo = function() if W.guild then return W.guild.name, "Member", 3, nil end end
	_G.C_GuildInfo = { GuildRoster = noop }
	_G.GetGuildRosterShowOffline = function() return W.showOffline end
	_G.GetNumGuildMembers = function() return #W.roster end
	_G.GetGuildRosterInfo = function(i)
		local e = W.roster[i]
		if not e then return nil end
		return e.name, e.rank or "Member", e.rankIndex or 3, e.level or 60, "Mage", "Zone", "", "",
			e.online and true or false, 0, e.class or "MAGE", 0, 0, false, false, 0, e.guid
	end
	_G.GetGuildRosterLastOnline = function(i)
		local e = W.roster[i]
		if e and e.lastOnlineHours then return 0, 0, 0, e.lastOnlineHours end
	end

	_G.GetInventoryItemLink = function(_, slot) return W.gear[slot] end
	_G.GetAverageItemLevel = function() return 61.04, 60.96 end

	_G.C_QuestLog = {
		IsQuestFlaggedCompleted = function(id) return W.quests[id] == true end,
		GetTitleForQuestID = function() return nil end,
	}

	_G.GetProfessions = function()
		local idx = {}
		for i = 1, #W.professions do idx[i] = i end
		return idx[1], idx[2], idx[3], idx[4], idx[5]
	end
	_G.GetProfessionInfo = function(i)
		local p = W.professions[i]
		return p.name, p.icon or 1, p.rank, p.max, 0, 0, p.skillLine
	end
	_G.C_SkillInfo = nil

	_G.C_TradeSkillUI = {
		GetBaseProfessionInfo = function()
			local t = W.tradeskill
			return t and { professionID = t.skillLine, professionName = t.name, skillLevel = t.rank, maxSkillLevel = t.max }
		end,
		GetFilteredRecipeIDs = function()
			local ids = {}
			if W.tradeskill then for id in pairs(W.tradeskill.recipes) do ids[#ids + 1] = id end end
			table.sort(ids)
			return ids
		end,
		GetRecipeInfo = function(id)
			local r = W.tradeskill and W.tradeskill.recipes[id]
			return r and { recipeID = id, name = "Recipe " .. id, learned = r.learned }
		end,
		GetRecipeOutputItemData = function(id)
			local r = W.tradeskill and W.tradeskill.recipes[id]
			return { itemID = r and r.itemID }
		end,
		GetRecipeCooldown = function(id)
			local r = W.tradeskill and W.tradeskill.recipes[id]
			return r and r.cd
		end,
		IsTradeSkillLinked = function() return W.tradeskill and W.tradeskill.linked or false end,
		IsTradeSkillGuild = function() return false end,
		IsNPCCrafting = function() return false end,
	}

	_G.C_Reputation = {
		GetNumFactions = function() return #W.factions end,
		GetFactionDataByIndex = function(i) return W.factions[i] end,
		GetFactionDataByID = function(id)
			for _, f in ipairs(W.factions) do if f.factionID == id then return f end end
		end,
	}

	-- Talents: one tree config with three groups (Classic-style trees).
	W.talentNodes = {}       -- list of { id, rank, groups = {groupID}, spellID }
	_G.C_SpecializationInfo = {
		GetActiveSpecGroup = function() return 1 end,
		GetCombatConfigIDForSpecGroup = function() return 77 end,
	}
	_G.C_Traits = {
		GetConfigInfo = function() return { ID = 77, name = "Mage", treeIDs = { 900 } } end,
		GetGroupDisplayInfoByTreeID = function()
			return {
				{ groupID = 3, displayName = "Frost", icon = 3, orderIndex = 3 },
				{ groupID = 1, displayName = "Arcane", icon = 1, orderIndex = 1 },
				{ groupID = 2, displayName = "Fire", icon = 2, orderIndex = 2 },
			}
		end,
		GetTreeNodes = function()
			local ids = {}
			for i, n in ipairs(W.talentNodes) do ids[i] = n.id end
			return ids
		end,
		GetNodeInfo = function(_, nodeID)
			for _, n in ipairs(W.talentNodes) do
				if n.id == nodeID then
					return { ID = nodeID, activeRank = n.rank, groupIDs = n.groups,
						activeEntry = { entryID = nodeID * 10, rank = n.rank } }
				end
			end
		end,
		GetEntryInfo = function(_, entryID) return { definitionID = entryID * 10 } end,
		GetDefinitionInfo = function(defID)
			for _, n in ipairs(W.talentNodes) do
				if n.id * 100 == defID then return { spellID = n.spellID } end
			end
		end,
	}
end

-- Run timers that are due, advancing the clock.
function W.advance(seconds)
	local target = W.now + seconds
	while true do
		local nextIdx, nextAt
		for i, t in ipairs(W.timers) do
			if t.at <= target and (not nextAt or t.at < nextAt) then nextIdx, nextAt = i, t.at end
		end
		if not nextIdx then break end
		local t = table.remove(W.timers, nextIdx)
		W.now = math.max(W.now, t.at)
		t.fn()
	end
	W.now = target
end

function W.member(name, guid, extra)
	local e = { name = name, guid = guid, online = true }
	for k, v in pairs(extra or {}) do e[k] = v end
	W.roster[#W.roster + 1] = e
	return e
end

return W
