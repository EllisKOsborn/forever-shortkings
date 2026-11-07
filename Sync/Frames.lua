-- Frames: our own splitting of big messages into numbered pieces (protocol 2).
--
-- Why (7 Nov 2026, first two-player test): AceComm's multi-part messages
-- arrived corrupted between two players on different Forever servers
-- ("bad compression" on both sides), while every single message (up to 255
-- bytes, every byte value, GUILD and WHISPER, 20 in a row) arrived intact
-- and in order. So every piece we send is now one complete, self-describing
-- message, and the receiver puts the pieces back together by number, in any
-- order. A lost piece is reported by /sr debug instead of failing silently.
--
-- Wire format (each fits in one 255-byte addon message, never starts with
-- AceComm's control bytes 1-9):
--   "\030" .. data                                  whole message
--   "\031" .. id(2) .. seq(1) .. total(1) .. data   piece seq of total
-- id: 2 printable characters; seq/total: string.char(32 + n).
local _, SK = ...

local Frames = {}
SK.Frames = Frames

Frames.WHOLE = "\030"
Frames.PIECE = "\031"
Frames.HEADER = 5             -- marker + id(2) + seq + total
Frames.MAX_WHOLE = 250        -- longest message sent in one piece (with the marker: 251)
Frames.PIECE_DATA = 240       -- data bytes per piece
Frames.MAX_PIECES = math.ceil(32 * 1024 / 240) + 1 -- Codec.MAX_ENCODED / PIECE_DATA
Frames.TIMEOUT = 120          -- seconds without a new piece before giving up on a message
Frames.MAX_OPEN = 4           -- unfinished messages kept per sender

local ID_CHARS = 94 -- printable ASCII 33..126
local nextId = 0

local function idString(n)
	return string.char(33 + math.floor(n / ID_CHARS) % ID_CHARS, 33 + n % ID_CHARS)
end

-- Split an encoded message into wire strings. Pure (apart from the id counter).
function Frames.Split(text)
	if #text <= Frames.MAX_WHOLE then return { Frames.WHOLE .. text } end
	nextId = (nextId + 1) % (ID_CHARS * ID_CHARS)
	local id = idString(nextId)
	local total = math.ceil(#text / Frames.PIECE_DATA)
	local out = {}
	for seq = 1, total do
		local data = text:sub((seq - 1) * Frames.PIECE_DATA + 1, seq * Frames.PIECE_DATA)
		out[seq] = Frames.PIECE .. id .. string.char(32 + seq, 32 + total) .. data
	end
	return out
end

-- Receiving side. One per Sync; state per sender.
function Frames.NewAssembler()
	return { open = {}, stats = { pieces = 0, expired = 0, duplicates = 0, bad = 0 }, lastIncomplete = nil }
end

-- Drop unfinished messages older than TIMEOUT, remembering the latest for /sr debug.
function Frames.Expire(asm, now)
	for sender, list in pairs(asm.open) do
		for id, m in pairs(list) do
			if now - m.at > Frames.TIMEOUT then
				list[id] = nil
				asm.stats.expired = asm.stats.expired + 1
				local missing = {}
				for i = 1, m.total do if not m.parts[i] then missing[#missing + 1] = i end end
				asm.lastIncomplete = string.format("from %s: %d of %d pieces (missing %s)", tostring(sender),
					m.got, m.total, table.concat(missing, ","))
			end
		end
		if next(list) == nil then asm.open[sender] = nil end
	end
end

-- Feed one wire string. Returns the whole encoded message when it's complete,
-- or nil plus a reason ("piece", "bad frame", "old protocol", ...).
function Frames.Add(asm, sender, wire, now)
	if type(wire) ~= "string" or #wire < 2 then return nil, "bad frame" end
	local mark = wire:sub(1, 1)
	if mark == Frames.WHOLE then return wire:sub(2) end
	if mark ~= Frames.PIECE then return nil, "old protocol" end
	if #wire <= Frames.HEADER then asm.stats.bad = asm.stats.bad + 1 return nil, "bad frame" end
	local id = wire:sub(2, 3)
	local seq, total = wire:byte(4) - 32, wire:byte(5) - 32
	local data = wire:sub(Frames.HEADER + 1)
	if total < 2 or total > Frames.MAX_PIECES or seq < 1 or seq > total or #data > Frames.PIECE_DATA then
		asm.stats.bad = asm.stats.bad + 1
		return nil, "bad frame"
	end
	asm.stats.pieces = asm.stats.pieces + 1
	Frames.Expire(asm, now)
	local list = asm.open[sender]
	if not list then list = {}; asm.open[sender] = list end
	local m = list[id]
	if m and m.total ~= total then
		list[id] = nil -- a new message reusing the id: start again
		m = nil
	end
	if not m then
		-- Keep at most MAX_OPEN unfinished messages per sender (drop the oldest).
		local n, oldestId, oldestAt = 0, nil, math.huge
		for k, x in pairs(list) do
			n = n + 1
			if x.at < oldestAt then oldestId, oldestAt = k, x.at end
		end
		if n >= Frames.MAX_OPEN and oldestId then list[oldestId] = nil end
		m = { total = total, got = 0, parts = {}, at = now }
		list[id] = m
	end
	m.at = now -- last activity
	if m.parts[seq] then
		asm.stats.duplicates = asm.stats.duplicates + 1
		return nil, "duplicate"
	end
	m.parts[seq] = data
	m.got = m.got + 1
	if m.got < total then return nil, "piece" end
	list[id] = nil
	if next(list) == nil then asm.open[sender] = nil end
	return table.concat(m.parts, "", 1, total)
end
