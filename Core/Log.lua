-- Chat output and a small debug ring buffer (shown by /sk debug).
local _, SK = ...

local MAX_LINES = 300
local lines = {}
local head = 0

SK.CHAT_PREFIX = "|cffD94FA0Short Kings|r: "

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

function SK:ClearLog()
	wipe(lines)
	head = 0
end
