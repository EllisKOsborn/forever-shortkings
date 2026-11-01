-- Merge rules for incoming profiles. Pure functions, covered by tests.
--
--  1. The profile's character must be in the current guild roster.
--  2. Its timestamp may not be more than 5 minutes in the future.
--  3. Its hash must match its content.
--  4. Our own account's characters are never overwritten from outside.
--  5. Owner copy (sent by the character itself, or by an alt that the
--     character itself listed in its `family`): always beats a relayed copy;
--     replaces another owner copy if it is the same age or newer.
--  6. Relay copy: accepted only if strictly newer than what we have, and
--     never over an owner copy that is newer.
local _, SK = ...

local Merge = {}
SK.Merge = Merge

Merge.MAX_FUTURE = 300

local TABLE_FIELDS = { gear = true, talents = true, profs = true, recipes = true,
	cds = true, reps = true, att = true, family = true }

-- Basic shape check so a malformed message can never break the UI.
function Merge.Validate(p)
	if type(p) ~= "table" then return false, "not a table" end
	if type(p.guid) ~= "string" or #p.guid < 3 or #p.guid > 64 then return false, "bad guid" end
	if type(p.updated) ~= "number" then return false, "bad timestamp" end
	if type(p.hash) ~= "string" then return false, "no hash" end
	if type(p.v) ~= "number" then return false, "no version" end
	for k in pairs(TABLE_FIELDS) do
		if p[k] ~= nil and type(p[k]) ~= "table" then return false, "bad field " .. k end
	end
	for _, k in ipairs({ "name", "class", "race", "addon" }) do
		if p[k] ~= nil and type(p[k]) ~= "string" then return false, "bad field " .. k end
	end
	return true
end

function Merge.IsOwnerCopy(senderGUID, incoming, stored)
	if not senderGUID then return false end
	if senderGUID == incoming.guid then return true end
	-- Alt relationship counts only as stated by the character itself.
	if stored and stored.source == "owner" and type(stored.family) == "table" then
		for _, g in ipairs(stored.family) do
			if g == senderGUID then return true end
		end
	end
	return false
end

-- Returns accept, reason.
function Merge.Decide(stored, incoming, isOwner, now, isMember)
	if not isMember then return false, "not in guild" end
	if incoming.updated > now + Merge.MAX_FUTURE then return false, "future timestamp" end
	if SK.Profile.HashOf(incoming) ~= incoming.hash then return false, "hash mismatch" end
	if not stored then return true, "new" end
	if stored.source == "self" then return false, "our own character" end
	if stored.hash == incoming.hash then return false, "unchanged" end
	if isOwner then
		if stored.source ~= "owner" then return true, "owner beats relay" end
		if incoming.updated >= stored.updated then return true, "newer owner copy" end
		return false, "older owner copy"
	end
	if incoming.updated > stored.updated then return true, "newer relay" end
	return false, "relay not newer"
end
