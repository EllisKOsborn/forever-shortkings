-- Chat output and a small debug ring buffer (shown by /sr debug).
local _, SK = ...

local MAX_LINES = 300
local lines = {}
local head = 0

SK.CHAT_PREFIX = "|cffD94FA0Short Royalty|r: "

function SK:Print(fmt, ...)
	local msg = select("#", ...) > 0 and string.format(fmt, ...) or tostring(fmt)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(SK.CHAT_PREFIX .. msg)
	else
		print(SK.CHAT_PREFIX .. msg)
	end
end

local function stamp()
	if date then return date("%H:%M:%S") end
	return tostring(GetTime and GetTime() or 0)
end

-- Always recorded (cheap); printed to chat only when debug logging is on.
function SK:Debug(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)
	if not ok then msg = tostring(fmt) end
	head = head % MAX_LINES + 1
	lines[head] = stamp() .. " " .. msg
	local settings = SK.DB and SK.DB.settings
	if settings and settings.debug then
		SK:Print("|cff999999[debug]|r %s", msg)
	end
end

-- Oldest first.
function SK:GetLog()
	local out = {}
	local n = #lines
	if n == 0 then return out end
	local start = (n < MAX_LINES) and 1 or (head % MAX_LINES + 1)
	for i = 0, n - 1 do
		local idx = (start + i - 1) % n + 1
		out[#out + 1] = lines[idx]
	end
	return out
end

---------------------------------------------------------------------------
-- Error capture: the last few Lua errors caught in our own code, so they
-- show in /sr debug even for players without an error-display addon.
-- Memory only (lost on /reload); nothing is sent anywhere.
---------------------------------------------------------------------------
SK.MAX_ERRORS = 10
SK.errors = {}

function SK:RecordError(where, err)
	local list = SK.errors
	local msg = tostring(err)
	for _, e in ipairs(list) do
		if e.where == where and e.msg == msg then
			e.count, e.at = e.count + 1, stamp()
			return e
		end
	end
	local e = { where = tostring(where), msg = msg, at = stamp(), count = 1, version = SK.VERSION }
	table.insert(list, 1, e)
	while #list > SK.MAX_ERRORS do table.remove(list) end
	SK:Debug("error in %s: %s", e.where, msg)
	return e
end

-- Run fn(...) safely: record and report an error instead of breaking the
-- caller. Also passes it to the game's error handler (BugSack, or Blizzard's
-- "Lua error" window when script errors are on).
function SK:Safe(where, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		SK:RecordError(where, err)
		local handler = geterrorhandler and geterrorhandler()
		if handler then handler(err) end
	end
	return ok, err
end

function SK:ClearLog()
	wipe(lines)
	head = 0
end
