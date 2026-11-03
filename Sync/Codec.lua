-- Codec: table <-> addon-channel-safe string, and content hashes.
--   LibSerialize (stable key order) -> LibDeflate -> EncodeForWoWAddonChannel
local _, SK = ...

local Codec = {}
SK.Codec = Codec

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

-- Stable output means the same table always gives the same string, so a
-- hash computed by the owner can be re-checked by everyone else.
local STABLE = { stable = true }

-- Refuse anything bigger than this, before decompressing. A worst-case
-- profile (four professions of 450 recipes, 150 reputations) encodes to
-- about 11 KB, so 32 KB leaves room while limiting how much a malformed
-- message could expand to (LibDeflate has no output limit).
Codec.MAX_ENCODED = 32 * 1024
-- And refuse anything that decompresses to more than this. A crafted 32 KB
-- message can expand to about 13 MB; a worst-case real profile serialises
-- to well under 64 KB (tested), so 256 KB is generous.
Codec.MAX_DECODED = 256 * 1024

function Codec.Serialize(t)
	return LibSerialize:SerializeEx(STABLE, t)
end

function Codec.Encode(t)
	local s = Codec.Serialize(t)
	local compressed = LibDeflate:CompressDeflate(s, { level = 6 })
	return LibDeflate:EncodeForWoWAddonChannel(compressed)
end

function Codec.Decode(str)
	if type(str) ~= "string" or #str == 0 then return nil, "empty" end
	if #str > Codec.MAX_ENCODED then return nil, "too large" end
	local compressed = LibDeflate:DecodeForWoWAddonChannel(str)
	if not compressed then return nil, "bad encoding" end
	local s = LibDeflate:DecompressDeflate(compressed)
	if not s then return nil, "bad compression" end
	if #s > Codec.MAX_DECODED then return nil, "too large decoded" end
	local ok, t = LibSerialize:Deserialize(s)
	if not ok or type(t) ~= "table" then return nil, "bad data" end
	return t
end

-- 8 hex characters. Used to detect changes, not as a security measure.
function Codec.Hash(t)
	return string.format("%08x", LibDeflate:Adler32(Codec.Serialize(t)))
end
