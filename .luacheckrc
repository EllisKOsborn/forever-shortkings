-- luacheck configuration for Short Kings (WoW runs Lua 5.1).
std = "lua51"
max_line_length = 140
exclude_files = { "Libs/**", ".luarocks/**", ".release/**" }
ignore = {
	"212/self",   -- unused self (methods)
	"212/_.*",    -- unused arguments starting with _
	"211/_.*",
	"213/_.*",
	"432/self",   -- nested scripts reuse the name self
}

globals = {
	"ShortKingsDB", "ShortKings",
	"SLASH_SHORTKINGS1", "SLASH_SHORTKINGS2", "SlashCmdList", "UISpecialFrames",
}

read_globals = {
	-- Lua extensions in WoW
	"wipe", "date", "time", "strsplit", "strtrim", "tinsert", "tremove", "format",
	"issecretvalue", "canaccessvalue", "geterrorhandler", "hooksecurefunc",
	-- Libraries
	"LibStub",
	-- Frames & UI
	"CreateFrame", "UIParent", "GameTooltip", "Minimap", "DEFAULT_CHAT_FRAME", "GameFontNormal",
	"CreateColor", "BackdropTemplateMixin", "UIPanelCloseButton", "STANDARD_TEXT_FONT",
	"PlaySound", "SOUNDKIT", "IsShiftKeyDown", "IsControlKeyDown", "ChatEdit_InsertLink",
	"ChatFrame_SendTell", "ChatFrame_OpenChat", "ChatFrameUtil", "HandleModifiedItemClick", "GetCursorPosition",
	"RAID_CLASS_COLORS", "ITEM_QUALITY_COLORS", "Settings", "ToggleCalendar", "Calendar_Toggle",
	"FACTION_BAR_COLORS", "TooltipDataProcessor", "ItemRefTooltip", "unpack", "ColorPickerFrame", "SetPortraitTexture", "GetScreenWidth", "GetScreenHeight",
	-- C_ namespaces
	"C_Timer", "C_AddOns", "C_ChatInfo", "C_GuildInfo", "C_Club", "C_CreatureInfo", "C_Traits",
	"C_SpecializationInfo", "C_ClassTalents", "C_TradeSkillUI", "C_SkillInfo", "C_Reputation",
	"C_QuestLog", "C_Item", "C_Spell", "C_ClassColor", "C_Calendar", "C_PartyInfo", "Enum",
	-- Global API
	"GetAddOnMetadata", "GetServerTime", "GetTime", "GetBuildInfo", "IsTrialAccount",
	"IsVeteranTrialAccount", "IsRestrictedAccount", "GameLimitedMode_IsActive", "InCombatLockdown",
	"IsInInstance", "UnitGUID", "UnitFullName", "UnitName", "UnitClass", "UnitRace", "UnitLevel",
	"UnitFactionGroup", "IsInGuild", "GetGuildInfo", "GuildRoster", "GetNumGuildMembers",
	"GetGuildRosterInfo", "GetGuildRosterLastOnline", "GetGuildRosterShowOffline",
	"GetInventoryItemLink", "GetAverageItemLevel", "GetActiveTalentGroup", "GetNumTalentTabs",
	"GetTalentTabInfo", "GetNumTalents", "GetTalentInfo", "GetProfessions", "GetProfessionInfo",
	"GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillLine", "GetTradeSkillRecipeLink",
	"GetTradeSkillItemLink", "GetNumFactions", "GetFactionInfo", "IsQuestFlaggedCompleted",
	"GetItemIcon", "GetSpellInfo", "GetItemInfo", "GetItemQualityColor", "GetInventorySlotInfo",
	"CanViewOfficerNote", "GetItemInfoInstant", "GetSpellCooldown", "GetItemCount", "GetLocale",
}
