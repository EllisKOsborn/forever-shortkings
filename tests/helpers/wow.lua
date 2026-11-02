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

	-- Widget stub: Create* returns another stub, Get* returns 0, Is* false,
	-- everything else is a no-op. Enough to smoke-test that UI code builds.
	local function stub()
		local f = { events = {}, scripts = {}, shown = false }
		function f:RegisterEvent(e) self.events[e] = true end
		function f:UnregisterEvent(e) self.events[e] = nil end
		function f:SetScript(name, fn) self.scripts[name] = fn end
		function f:GetScript(name) return self.scripts[name] end
		function f:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
		function f:Hide() self.shown = false end
		function f:SetShown(v) if v then self:Show() else self:Hide() end end
		function f:IsShown() return self.shown end
		function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
		function f:GetMinMaxValues() return 0, 0 end
		function f:GetFont() return "Fonts\\FRIZQT__.TTF", 12 end
		function f:GetText() return self.text or "" end
		function f:SetText(t) self.text = t end
		return setmetatable(f, { __index = function(_, k)
			if type(k) ~= "string" then return nil end
			if k:find("^Create") or k:find("^Get.*Texture$") then return function() return stub() end end
			if k:find("^Get") then return function() return 0 end end
			if k:find("^Is") then return function() return false end end
			return noop
		end })
	end
	W.stub = stub
	W.frames = {}
	_G.CreateFrame = function()
		local f = stub()
		W.frames[#W.frames + 1] = f
		return f
	end
	_G.UIParent = stub()
	_G.Minimap = stub()
	_G.GameTooltip = stub()
	_G.GameFontNormal = stub()
	_G.UISpecialFrames = {}
	_G.tinsert = table.insert
	_G.SlashCmdList = {}
	_G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
	_G.GetCursorPosition = function() return 0, 0 end

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
	W.officer = false
	_G.C_GuildInfo = { GuildRoster = noop, CanViewOfficerNote = function() return W.officer end }
	_G.GetGuildRosterShowOffline = function() return W.showOffline end
	_G.GetNumGuildMembers = function() return #W.roster end
	_G.GetGuildRosterInfo = function(i)
		local e = W.roster[i]
		if not e then return nil end
		return e.name, e.rank or "Member", e.rankIndex or 3, e.level or 60, "Mage", "Zone", e.note or "", e.officerNote or "",
			e.online and true or false, 0, e.class or "MAGE", 0, 0, false, false, 0, e.guid
	end
	_G.GetGuildRosterLastOnline = function(i)
		local e = W.roster[i]
		if e and e.lastOnlineHours then return 0, 0, 0, e.lastOnlineHours end
	end

	_G.GetInventoryItemLink = function(_, slot) return W.gear[slot] end
	_G.GetAverageItemLevel = function() return 61.04, 60.96 end

	-- Items: itemID -> { equipLoc, classID, subClassID }
	W.items = {}
	_G.C_Item = {
		GetItemInfoInstant = function(id)
			local i = W.items[id] or { "INVTYPE_HEAD", 4, 4 }
			return id, "Armor", "Plate", i[1], 1, i[2], i[3]
		end,
		GetItemIconByID = function() return 134400 end,
	}
	-- Item names load asynchronously: W.itemNames[id] = name exists on the
	-- "server"; W.itemCached[id] says whether the client has it yet.
	-- RequestLoadItemDataByID caches it and fires ITEM_DATA_LOAD_RESULT 0.2 s later.
	W.itemNames, W.itemCached, W.itemQuality = {}, {}, {}
	W.requestedItems = {}
	W.bags = {}              -- [itemID] = count in bags
	_G.C_Item.GetItemCount = function(id, includeBank) return (not includeBank and W.bags[id]) or 0 end
	_G.C_Item.GetItemNameByID = function(id) return W.itemCached[id] and W.itemNames[id] or nil end
	_G.C_Item.GetItemQualityByID = function(id) return W.itemCached[id] and (W.itemQuality[id] or 3) or nil end
	_G.C_Item.GetItemQualityColor = function() return 0, 0.44, 0.87, "ff0070dd" end
	_G.C_Item.GetItemInfo = function(id)
		if not W.itemCached[id] then return nil end
		local n = W.itemNames[id]
		return n, "|cff0070dd|Hitem:" .. id .. "::::::::60:::::|h[" .. n .. "]|h|r"
	end
	_G.C_Item.RequestLoadItemDataByID = function(id)
		W.requestedItems[#W.requestedItems + 1] = id
		C_Timer.After(0.2, function()
			if W.itemNames[id] then W.itemCached[id] = true end
			W.fire("ITEM_DATA_LOAD_RESULT", id, W.itemNames[id] ~= nil)
		end)
	end
	-- Spell names: W.spellNames[id] (default "Spell <id>"); W.spellUncached[id]
	-- makes GetSpellName return nil until RequestLoadSpellData.
	W.spellNames, W.spellUncached = {}, {}
	W.tooltipHooks = {}
	_G.TooltipDataProcessor = {
		AddTooltipPostCall = function(kind, fn) W.tooltipHooks[#W.tooltipHooks + 1] = { kind, fn } end,
	}
	_G.Enum.TooltipDataType = { Item = 0, Spell = 1 }
	W.chat = {}
	_G.ChatFrameUtil = {
		SendTell = function(name) W.chat[#W.chat + 1] = { "tell", name } end,
		OpenChat = function(text) W.chat[#W.chat + 1] = { "open", text } end,
	}

	-- Spell cooldowns: spellID -> { start, duration } (GetTime clock = W.now)
	W.spellCD = {}
	_G.C_Spell = {
		GetSpellCooldown = function(id)
			local c = W.spellCD[id] or { 0, 0 }
			return { startTime = c[1], duration = c[2], isEnabled = true, isActive = c[2] > 0, modRate = 1 }
		end,
		GetSpellName = function(id)
			if W.spellUncached[id] then return nil end
			return W.spellNames[id] or ("Spell " .. id)
		end,
		RequestLoadSpellData = function(id)
			C_Timer.After(0.2, function()
				W.spellUncached[id] = nil
				W.fire("SPELL_DATA_LOAD_RESULT", id, true)
			end)
		end,
		GetSpellTexture = function() return 136240 end,
		GetSpellLink = function(id) return "|cff71d5ff|Hspell:" .. id .. "|h[" .. (W.spellNames[id] or ("Spell " .. id)) .. "]|h|r" end,
	}

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

-- Deliver a WoW event to every frame that registered it.
function W.fire(event, ...)
	for _, f in ipairs(W.frames) do
		if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
	end
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
