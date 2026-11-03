-- Loads the addon's non-UI files (in TOC order) into a fresh namespace,
-- on top of the WoW stub. Returns SK, W.
local W = require("tests.helpers.wow")

local LIBS = {
	"Libs/LibStub/LibStub.lua",
	"Libs/LibSerialize/LibSerialize.lua",
	"Libs/LibDeflate/LibDeflate.lua",
}

local FILES = {
	"Core/Init.lua", "Core/Log.lua", "Core/Compat.lua", "Core/DB.lua", "Core/Identity.lua", "Core/Alts.lua",
	"Core/CraftIndex.lua", "Core/Export.lua", "Core/Feed.lua", "Core/Overview.lua",
	"Data/Professions.lua", "Data/Attunements.lua", "Data/Factions.lua", "Data/Enchants.lua",
	"Collect/Character.lua", "Collect/Talents.lua", "Collect/Professions.lua",
	"Collect/Reputation.lua", "Collect/Attunements.lua", "Collect/Profile.lua",
	"Sync/Codec.lua", "Sync/Merge.lua", "Sync/Sync.lua",
}

-- UI files in TOC order (the stubbed frames are enough for them to build).
local UI_FILES = {
	"UI/Theme.lua", "UI/Motion.lua", "UI/Widgets.lua", "UI/MainFrame.lua", "UI/OverviewTab.lua", "UI/RosterTab.lua",
	"UI/CharacterTab.lua", "UI/CraftersTab.lua", "UI/SettingsTab.lua", "UI/DebugWindow.lua",
	"UI/Minimap.lua", "UI/Tooltip.lua", "Commands.lua",
}

local function loadUI(SK)
	for _, f in ipairs(UI_FILES) do assert(loadfile(f))("ShortKings", SK) end
end

local function load()
	W.reset()
	_G.LibStub = nil
	for _, f in ipairs(LIBS) do assert(loadfile(f))() end
	local SK = {}
	for _, f in ipairs(FILES) do
		assert(loadfile(f))("ShortKings", SK)
	end
	-- What ADDON_LOADED would do.
	SK.DBM:Load({})
	return SK, W
end

-- Put a guild member into the roster AND the saved member list.
local function addMember(SK, name, guid, extra)
	W.member(name, guid, extra)
	SK.Identity:ReadRoster()
end

-- Capture everything Sync sends. Returns the list (decoded messages).
local function captureSends(SK)
	local sent = {}
	SK.Sync.transport = function(text, dist, target, prio)
		local msg = SK.Codec.Decode(text)
		sent[#sent + 1] = { msg = msg, dist = dist, target = target, prio = prio }
	end
	return sent
end

-- Build an encoded message as a peer would send it.
local function peerMessage(SK, t, fields, fromGUID, version)
	local msg = { t = t, p = SK.PROTOCOL, s = fromGUID, v = version or "0.1.0" }
	for k, v in pairs(fields or {}) do msg[k] = v end
	return SK.Codec.Encode(msg)
end

return {
	load = load, loadUI = loadUI, UI_FILES = UI_FILES, addMember = addMember, captureSends = captureSends, peerMessage = peerMessage, W = W }
