-- Compat: the ONLY place that calls WoW APIs which differ between clients.
-- Every function checks that the API exists first, so a missing or renamed
-- function degrades a feature instead of throwing a Lua error.
--
-- Verified against Blizzard's UI source for WoW Forever 1.60.1 (70532).
-- Items marked "unverified" must be confirmed in game (see /sk debug).
local _, SK = ...

local Compat = {}
SK.Compat = Compat

local function has(ns, fn)
	local t = ns and _G[ns]
	if fn == nil then return type(_G[ns]) == "function" end
	return type(t) == "table" and type(t[fn]) == "function"
end
Compat.has = has

-- Midnight "secret values": never store or compare them.
function Compat.IsSecret(v)
	if issecretvalue then
		local ok, secret = pcall(issecretvalue, v)
		return ok and secret
	end
	return false
end

local function clean(v)
	if v == nil or Compat.IsSecret(v) then return nil end
	return v
end
Compat.clean = clean

---------------------------------------------------------------------------
-- Time, build, account
---------------------------------------------------------------------------
function Compat.Now()
	if GetServerTime then return GetServerTime() end
	return time()
end

function Compat.BuildInfo()
	if not GetBuildInfo then return {} end
	local version, build, date, interface = GetBuildInfo()
	return { version = version, build = build, date = date, interface = interface }
end

-- Trial / starter accounts cannot send addon messages on Forever.
function Compat.IsTrial()
	if IsTrialAccount and IsTrialAccount() then return true end
	if IsVeteranTrialAccount and IsVeteranTrialAccount() then return true end
	if GameLimitedMode_IsActive and GameLimitedMode_IsActive() then return true end
	return false
end

function Compat.CanSendAddonMessages()
	if Compat.IsTrial() then return false, "trial" end
	if has("C_ChatInfo", "AreOutgoingAddonChatMessagesRestricted")
		and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted() then
		return false, "restricted"
	end
	return true
end

function Compat.InCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

function Compat.InChatLockdown()
	if has("C_ChatInfo", "InChatMessagingLockdown") then
		return C_ChatInfo.InChatMessagingLockdown() and true or false
	end
	return false
end

-- Instance types where we pause sync. Housing ("neighborhood"/"interior")
-- is deliberately not paused.
local PAUSE_INSTANCE = { party = true, raid = true, pvp = true, arena = true, scenario = true }

function Compat.InInstance()
	if not IsInInstance then return false end
	local inInstance, kind = IsInInstance()
	return (inInstance and PAUSE_INSTANCE[kind or ""]) and true or false, kind
end

---------------------------------------------------------------------------
-- Player identity
---------------------------------------------------------------------------
function Compat.PlayerGUID()
	return clean(UnitGUID and UnitGUID("player"))
end

function Compat.PlayerFullName()
	local name, realm
	if UnitFullName then name, realm = UnitFullName("player") end
	if not name and UnitName then name = UnitName("player") end
	return clean(name), clean(realm)
end

function Compat.PlayerBasics()
	local _, classFile, classID = UnitClass("player")
	local _, raceFile = UnitRace("player")
	return {
		class = classFile,
		classID = classID,
		race = raceFile,
		level = UnitLevel("player"),
		faction = UnitFactionGroup and UnitFactionGroup("player") or nil,
	}
end

---------------------------------------------------------------------------
-- Guild
---------------------------------------------------------------------------
function Compat.IsInGuild()
	return IsInGuild and IsInGuild() or false
end

-- Returns guildName, rankName, rankIndex, realm
function Compat.GuildInfo()
	if not GetGuildInfo then return nil end
	return GetGuildInfo("player")
end

function Compat.RequestRoster()
	if has("C_GuildInfo", "GuildRoster") then
		C_GuildInfo.GuildRoster()
	elseif GuildRoster then
		GuildRoster()
	end
end

local function hoursAgo(years, months, days, hours)
	return ((years or 0) * 365 + (months or 0) * 30 + (days or 0)) * 24 + (hours or 0)
end

local function readLegacyRoster()
	if not (GetNumGuildMembers and GetGuildRosterInfo) then return nil end
	local total = GetNumGuildMembers()
	if not total or total == 0 then return nil end
	local out = {}
	for i = 1, total do
		local name, rankName, rankIndex, level, _, _, _, _, online, _, classFile,
			_, _, _, _, _, guid = GetGuildRosterInfo(i)
		name, guid = clean(name), clean(guid)
		if name and guid then
			local entry = {
				name = name, guid = guid, rank = clean(rankName), rankIndex = clean(rankIndex),
				level = clean(level), class = clean(classFile), online = clean(online) and true or false,
			}
			if not entry.online and GetGuildRosterLastOnline then
				local y, m, d, h = GetGuildRosterLastOnline(i)
				if y or m or d or h then entry.lastOnlineHours = hoursAgo(y, m, d, h) end
			end
			out[#out + 1] = entry
		end
	end
	return out, total
end

local function classFileFromID(classID)
	if classID and has("C_CreatureInfo", "GetClassInfo") then
		local info = C_CreatureInfo.GetClassInfo(classID)
		return info and info.classFile
	end
end

local function readClubRoster()
	if not (has("C_Club", "GetGuildClubId") and has("C_Club", "GetClubMembers") and has("C_Club", "GetMemberInfo")) then
		return nil
	end
	local clubId = C_Club.GetGuildClubId()
	if not clubId then return nil end
	local ids = C_Club.GetClubMembers(clubId)
	if not ids or #ids == 0 then return nil end
	local out = {}
	local OFFLINE = Enum and Enum.ClubMemberPresence and Enum.ClubMemberPresence.Offline or 3
	local UNKNOWN = Enum and Enum.ClubMemberPresence and Enum.ClubMemberPresence.Unknown or 0
	for _, memberId in ipairs(ids) do
		local info = C_Club.GetMemberInfo(clubId, memberId)
		local name, guid = info and clean(info.name), info and clean(info.guid)
		if name and guid then
			local presence = clean(info.presence)
			local entry = {
				name = name, guid = guid, rank = clean(info.guildRank),
				rankIndex = info.guildRankOrder and (info.guildRankOrder - 1) or nil,
				level = clean(info.level), class = classFileFromID(clean(info.classID)),
				online = presence ~= nil and presence ~= OFFLINE and presence ~= UNKNOWN,
			}
			if not entry.online and info.lastOnlineYear then
				entry.lastOnlineHours = hoursAgo(info.lastOnlineYear, info.lastOnlineMonth,
					info.lastOnlineDay, info.lastOnlineHour)
			end
			out[#out + 1] = entry
		end
	end
	return out, #ids
end

-- Returns list, complete, source. `complete` means we believe offline
-- members are included (needed before we mark anyone as "left").
function Compat.ReadRoster()
	local list, total = readLegacyRoster()
	if list and #list > 0 then
		local complete = #list >= total
		if GetGuildRosterShowOffline and not GetGuildRosterShowOffline() then
			complete = false
		end
		if complete then return list, true, "legacy" end
	end
	local clubList = readClubRoster()
	if clubList and #clubList > 0 then
		return clubList, true, "club"
	end
	if list and #list > 0 then return list, false, "legacy" end
	return {}, false, "none"
end

---------------------------------------------------------------------------
-- Gear
---------------------------------------------------------------------------
-- 1 Head ... 19 Tabard. 0 (ammo) is skipped.
Compat.GEAR_SLOTS = { 1, 2, 3, 15, 5, 4, 19, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

function Compat.ReadGear()
	local gear = {}
	if not GetInventoryItemLink then return gear end
	for _, slot in ipairs(Compat.GEAR_SLOTS) do
		local link = clean(GetInventoryItemLink("player", slot))
		if link then gear[slot] = link end
	end
	return gear
end

function Compat.AverageItemLevel()
	if not GetAverageItemLevel then return nil end
	local overall, equipped = GetAverageItemLevel()
	local v = clean(equipped) or clean(overall)
	if v then return math.floor(v * 10 + 0.5) / 10 end
end

---------------------------------------------------------------------------
-- Talents
---------------------------------------------------------------------------
function Compat.TalentAPI()
	if has("C_Traits", "GetConfigInfo") and has("C_Traits", "GetTreeNodes") and has("C_Traits", "GetNodeInfo") then
		return "traits"
	elseif GetNumTalentTabs and GetTalentTabInfo then
		return "classic"
	end
	return "none"
end

function Compat.ActiveTraitConfigID()
	if has("C_SpecializationInfo", "GetCombatConfigIDForSpecGroup") then
		local group = 1
		if has("C_SpecializationInfo", "GetActiveSpecGroup") then
			group = C_SpecializationInfo.GetActiveSpecGroup() or 1
		elseif GetActiveTalentGroup then
			group = GetActiveTalentGroup() or 1
		end
		local id = C_SpecializationInfo.GetCombatConfigIDForSpecGroup(group)
		if id then return id end
	end
	if has("C_ClassTalents", "GetActiveConfigID") then
		return C_ClassTalents.GetActiveConfigID()
	end
end

---------------------------------------------------------------------------
-- Professions
---------------------------------------------------------------------------
-- Returns { [skillLineID] = { name, rank, max, icon, primary } }
function Compat.ReadProfessions()
	local out = {}
	if GetProfessions and GetProfessionInfo then
		-- Forever's ProfessionsBook reads: prof1, prof2, firstAid, fishing, cooking
		-- (Mainline's third value is archaeology). Only the first two are primary.
		local p1, p2, s1, s2, s3, s4 = GetProfessions()
		local slots = { { p1, true }, { p2, true }, { s1, false }, { s2, false }, { s3, false }, { s4, false } }
		for _, s in ipairs(slots) do
			local index = s[1]
			if index then
				local name, icon, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
				if skillLine and name then
					out[skillLine] = { name = name, rank = rank or 0, max = maxRank or 0, icon = icon, primary = s[2] }
				end
			end
		end
	end
	-- Fill gaps / zero ranks from the skill list (used by Forever's SkillsFrame).
	if has("C_SkillInfo", "GetNumSkillLines") and has("C_SkillInfo", "GetSkillLineInfo") then
		local known = SK.Data and SK.Data.PROFESSIONS or {}
		for i = 1, C_SkillInfo.GetNumSkillLines() do
			local info = C_SkillInfo.GetSkillLineInfo(i)
			if info and not info.isHeader and known[info.skillID] then
				local p = out[info.skillID]
				if not p then
					p = { name = info.name, primary = known[info.skillID].primary }
					out[info.skillID] = p
				end
				if (p.rank or 0) == 0 then
					p.rank, p.max = info.rank, info.maxRank
				end
			end
		end
	end
	return out
end

-- "modern" (C_TradeSkillUI), "classic" (GetTradeSkillInfo) or "none"
function Compat.TradeSkillAPI()
	if has("C_TradeSkillUI", "GetBaseProfessionInfo") and has("C_TradeSkillUI", "GetRecipeInfo")
		and (has("C_TradeSkillUI", "GetAllRecipeIDs") or has("C_TradeSkillUI", "GetFilteredRecipeIDs")) then
		return "modern"
	elseif GetNumTradeSkills and GetTradeSkillInfo then
		return "classic"
	end
	return "none"
end

-- True when the open profession window shows OUR recipes (not a linked,
-- guild or NPC window).
function Compat.IsOwnTradeSkill()
	local T = C_TradeSkillUI
	if not T then return true end
	if T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return false end
	if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return false end
	if T.IsTradeSkillGuildMember and T.IsTradeSkillGuildMember() then return false end
	if T.IsNPCCrafting and T.IsNPCCrafting() then return false end
	if T.IsRuneforging and T.IsRuneforging() then return false end
	return true
end

-- Returns skillLineID, name, rank, max for the open window (modern API).
function Compat.OpenProfession()
	local info = C_TradeSkillUI.GetBaseProfessionInfo()
	if not info or not info.professionID then return nil end
	local rank, max = info.skillLevel, info.maxSkillLevel
	if (rank or 0) == 0 and has("C_TradeSkillUI", "GetChildProfessionInfo") then
		local child = C_TradeSkillUI.GetChildProfessionInfo()
		if child then rank, max = child.skillLevel, child.maxSkillLevel end
	end
	return info.professionID, info.professionName, rank, max
end

-- Returns list of recipe IDs and whether it is the complete list.
function Compat.RecipeIDs()
	if has("C_TradeSkillUI", "GetAllRecipeIDs") then
		return C_TradeSkillUI.GetAllRecipeIDs() or {}, true
	end
	return C_TradeSkillUI.GetFilteredRecipeIDs() or {}, false
end

function Compat.RecipeInfo(recipeID)
	local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
	if not info then return nil end
	local itemID
	if has("C_TradeSkillUI", "GetRecipeOutputItemData") then
		local ok, out = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
		if ok and out then itemID = out.itemID end
	end
	return { learned = info.learned and true or false, name = info.name, itemID = itemID }
end

-- Seconds remaining, or nil.
function Compat.RecipeCooldown(recipeID)
	if not has("C_TradeSkillUI", "GetRecipeCooldown") then return nil end
	local ok, cd = pcall(C_TradeSkillUI.GetRecipeCooldown, recipeID)
	if ok and type(cd) == "number" and cd > 0 then return cd end
end

---------------------------------------------------------------------------
-- Reputation
---------------------------------------------------------------------------
-- Returns { [factionID] = { n = name, r = reaction, v = standing } }
function Compat.ReadReputations(extraIDs)
	local out = {}
	local function add(d)
		if d and d.factionID and d.factionID > 0 and (not d.isHeader or d.isHeaderWithRep) then
			out[d.factionID] = { n = d.name, r = d.reaction, v = d.currentStanding }
		end
	end
	if has("C_Reputation", "GetNumFactions") and has("C_Reputation", "GetFactionDataByIndex") then
		for i = 1, C_Reputation.GetNumFactions() do
			add(C_Reputation.GetFactionDataByIndex(i))
		end
		if extraIDs and has("C_Reputation", "GetFactionDataByID") then
			for _, id in ipairs(extraIDs) do
				if not out[id] then add(C_Reputation.GetFactionDataByID(id)) end
			end
		end
	elseif GetNumFactions and GetFactionInfo then
		for i = 1, GetNumFactions() do
			local name, _, standingID, _, _, barValue, _, _, isHeader, _, hasRep, _, _, factionID = GetFactionInfo(i)
			add({ factionID = factionID, name = name, reaction = standingID, currentStanding = barValue,
				isHeader = isHeader, isHeaderWithRep = hasRep })
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------
function Compat.IsQuestDone(questID)
	if has("C_QuestLog", "IsQuestFlaggedCompleted") then
		return C_QuestLog.IsQuestFlaggedCompleted(questID) and true or false
	elseif IsQuestFlaggedCompleted then
		return IsQuestFlaggedCompleted(questID) and true or false
	end
	return nil
end

-- Does this quest ID exist in this client's data? (nil = unknown yet)
function Compat.QuestTitle(questID)
	if has("C_QuestLog", "GetTitleForQuestID") then
		return C_QuestLog.GetTitleForQuestID(questID)
	end
end

---------------------------------------------------------------------------
-- Items / spells (for display)
---------------------------------------------------------------------------
function Compat.ItemIDFromLink(link)
	if type(link) ~= "string" then return nil end
	local id = link:match("item:(%d+)")
	return id and tonumber(id)
end

function Compat.ItemIcon(itemIDOrLink)
	local id = type(itemIDOrLink) == "number" and itemIDOrLink or Compat.ItemIDFromLink(itemIDOrLink)
	if not id then return nil end
	if has("C_Item", "GetItemIconByID") then return C_Item.GetItemIconByID(id) end
	if GetItemIcon then return GetItemIcon(id) end
end

function Compat.SpellName(spellID)
	if has("C_Spell", "GetSpellName") then return C_Spell.GetSpellName(spellID) end
	if has("C_Spell", "GetSpellInfo") then
		local info = C_Spell.GetSpellInfo(spellID)
		return info and info.name
	end
	if GetSpellInfo then return (GetSpellInfo(spellID)) end
end

function Compat.ClassColor(classFile)
	local c
	if has("C_ClassColor", "GetClassColor") and classFile then c = C_ClassColor.GetClassColor(classFile) end
	if not c and RAID_CLASS_COLORS and classFile then c = RAID_CLASS_COLORS[classFile] end
	if c then return c.r, c.g, c.b end
	return 0.8, 0.8, 0.8
end

---------------------------------------------------------------------------
-- Report for /sk debug: which APIs this client actually has.
---------------------------------------------------------------------------
Compat.PROBES = {
	"C_ChatInfo.SendAddonMessage", "C_ChatInfo.InChatMessagingLockdown",
	"C_ChatInfo.AreOutgoingAddonChatMessagesRestricted",
	"IsTrialAccount", "IsVeteranTrialAccount", "GameLimitedMode_IsActive", "issecretvalue",
	"GetNumGuildMembers", "GetGuildRosterInfo", "GetGuildRosterLastOnline", "C_GuildInfo.GuildRoster",
	"C_Club.GetGuildClubId", "C_Club.GetClubMembers",
	"GetInventoryItemLink", "GetAverageItemLevel",
	"C_Traits.GetConfigInfo", "C_Traits.GetTreeNodes", "C_Traits.GetGroupDisplayInfoByTreeID",
	"C_SpecializationInfo.GetCombatConfigIDForSpecGroup", "C_ClassTalents.GetActiveConfigID",
	"GetNumTalentTabs", "GetTalentTabInfo",
	"GetProfessions", "GetProfessionInfo", "C_SkillInfo.GetSkillLineInfo",
	"C_TradeSkillUI.GetBaseProfessionInfo", "C_TradeSkillUI.GetAllRecipeIDs",
	"C_TradeSkillUI.GetFilteredRecipeIDs", "C_TradeSkillUI.GetRecipeInfo",
	"C_TradeSkillUI.GetRecipeOutputItemData", "C_TradeSkillUI.GetRecipeCooldown",
	"C_TradeSkillUI.IsTradeSkillLinked", "C_TradeSkillUI.IsGuildTradeSkillsEnabled",
	"GetNumTradeSkills", "GetTradeSkillInfo", "GetCraftInfo",
	"C_Reputation.GetFactionDataByIndex", "C_Reputation.GetFactionDataByID", "GetFactionInfo",
	"C_QuestLog.IsQuestFlaggedCompleted", "C_QuestLog.GetTitleForQuestID",
	"C_Calendar.GetNumDayEvents", "C_Calendar.EventSignUp", "C_Calendar.OpenEvent",
	"C_Item.GetItemIconByID", "C_Spell.GetSpellName",
}

function Compat.ProbeAll()
	local out = {}
	for _, path in ipairs(Compat.PROBES) do
		local ns, fn = path:match("^([^.]+)%.(.+)$")
		out[#out + 1] = { path, ns and has(ns, fn) or has(path) }
	end
	return out
end
