-- Short Royalty: namespace, version, events, timers and module lifecycle.
local ADDON_NAME, SK = ...

SK.ADDON_NAME = ADDON_NAME
SK.PREFIX = "ShortKings" -- addon message prefix (max 16 chars)
SK.PROTOCOL = 1          -- bump when the sync format changes incompatibly
SK.SCHEMA = 1            -- bump when the SavedVariables layout changes
SK.TAGLINE = "Height is not a stat." -- also in ShortKings.toc (Notes), README, preview

do
	local v
	local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if getMeta then v = getMeta(ADDON_NAME, "Version") end
	if not v or v == "" or v:find("@", 1, true) then v = "dev" end
	SK.VERSION = v
end

---------------------------------------------------------------------------
-- WoW events
---------------------------------------------------------------------------
local eventHandlers = {}
local eventFrame = CreateFrame("Frame")
SK.eventFrame = eventFrame

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = eventHandlers[event]
	if not list then return end
	for i = 1, #list do
		-- One failing handler must not stop the others (errors are recorded).
		SK:Safe(event, list[i], event, ...)
	end
end)

-- SK:RegisterEvent("PLAYER_LOGIN", fn). Several handlers per event are fine.
function SK:RegisterEvent(event, fn)
	local list = eventHandlers[event]
	if not list then
		list = {}
		eventHandlers[event] = list
		-- Some events do not exist on every client; never let that break loading.
		local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
		if not ok and SK.Debug then SK:Debug("event %s not available", event) end
	end
	list[#list + 1] = fn
end

---------------------------------------------------------------------------
-- Internal messages (module to module)
---------------------------------------------------------------------------
local messageHandlers = {}

function SK:On(message, fn)
	local list = messageHandlers[message]
	if not list then
		list = {}
		messageHandlers[message] = list
	end
	list[#list + 1] = fn
end

function SK:Fire(message, ...)
	local list = messageHandlers[message]
	if not list then return end
	for i = 1, #list do
		SK:Safe(message, list[i], ...)
	end
end

---------------------------------------------------------------------------
-- Timers
---------------------------------------------------------------------------
function SK.After(seconds, fn)
	C_Timer.After(seconds, fn)
end

function SK.NewTicker(seconds, fn)
	return C_Timer.NewTicker(seconds, fn)
end

-- Run fn once, `delay` seconds after the LAST call with this key.
local debounceGen = {}
function SK:Debounce(key, delay, fn)
	local gen = (debounceGen[key] or 0) + 1
	debounceGen[key] = gen
	C_Timer.After(delay, function()
		if debounceGen[key] == gen then
			fn()
		end
	end)
end

---------------------------------------------------------------------------
-- Modules: SK:NewModule("Name") returns a table. Optional hooks:
--   module:OnInit()   after SavedVariables are ready (ADDON_LOADED)
--   module:OnLogin()  at PLAYER_LOGIN
---------------------------------------------------------------------------
SK.modules = {}
local moduleOrder = {}

function SK:NewModule(name)
	local m = SK.modules[name]
	if m then return m end
	m = { name = name }
	SK.modules[name] = m
	SK[name] = m
	moduleOrder[#moduleOrder + 1] = m
	return m
end

local function callAll(hook)
	for i = 1, #moduleOrder do
		local m = moduleOrder[i]
		if m[hook] then
			SK:Safe(m.name .. ":" .. hook, m[hook], m)
		end
	end
end
SK._callAll = callAll -- exposed for tests

SK:RegisterEvent("ADDON_LOADED", function(_, name)
	if name ~= ADDON_NAME then return end
	callAll("OnInit")
end)

SK:RegisterEvent("PLAYER_LOGIN", function()
	callAll("OnLogin")
end)

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
function SK.Count(t)
	local n = 0
	if t then
		for _ in pairs(t) do n = n + 1 end
	end
	return n
end

function SK.CopyTable(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = SK.CopyTable(v) end
	return out
end

-- Fill missing keys of `t` from `defaults` (deep).
function SK.ApplyDefaults(t, defaults)
	for k, v in pairs(defaults) do
		if type(v) == "table" then
			if type(t[k]) ~= "table" then t[k] = {} end
			SK.ApplyDefaults(t[k], v)
		elseif t[k] == nil then
			t[k] = v
		end
	end
	return t
end

_G.ShortKings = SK -- handy for /dump ShortKings in game
