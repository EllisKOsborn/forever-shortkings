-- Accounts (v0.3.6): which guild characters without Short Royalty are really
-- alts of someone who has it. The game doesn't tell addons which characters
-- share an account, so three clues are used, strongest first:
--   "bnet"  the same Battle.net account (only where the game shares it)
--   "claim" the player marked it "This is my alt" (profile.claims)
--   "note"  its guild note (or officer note) names exactly one guildmate
--           who has the addon ("Bob's alt", "alt - Bob")
-- Only used for the Overview/Roster wording ("alt of Bob" instead of
-- "doesn't have it"). Nothing here is sent anywhere.
local _, SK = ...

local Accounts = {}
SK.Accounts = Accounts

Accounts.HOW = { bnet = "same Battle.net account", claim = "they said so", note = "guild note" }
Accounts.MIN_NAME = 3 -- shorter first names are too likely to match ordinary words in notes

local function firstName(name)
	return type(name) == "string" and (name:match("^(%S+)") or name):lower() or nil
end

-- Words of a note, lower case: "Bob's alt!" -> { bob = true, s = true, alt = true }
function Accounts.Words(text)
	local out = {}
	if type(text) ~= "string" then return out end
	for w in text:lower():gsub("[%p%c]", " "):gmatch("%S+") do out[w] = true end
	return out
end

-- Pure; tested.
--   members:  guild.members
--   hasAddon: fn(guid) -> bool
--   profiles: fn(guid) -> profile or nil (for claims)
--   ids:      { [guid] = Battle.net account id } (may be empty)
-- Returns { [altGuid] = { owner = guid, how = "bnet"|"claim"|"note" } }.
function Accounts.Links(members, hasAddon, profiles, ids)
	ids = ids or {}
	local users, byAccount, byFirst = {}, {}, {}
	for guid, m in pairs(members) do
		if not m.leftAt and hasAddon(guid) then
			users[#users + 1] = guid
			if ids[guid] then byAccount[ids[guid]] = byAccount[ids[guid]] or guid end
			local f = firstName(m.name)
			if f and #f >= Accounts.MIN_NAME then
				byFirst[f] = (byFirst[f] == nil) and guid or false -- false: two users share it
			end
		end
	end
	table.sort(users)
	local claimed = {}
	for _, owner in ipairs(users) do
		local p = profiles(owner)
		for _, g in ipairs(type(p) == "table" and type(p.claims) == "table" and p.claims or {}) do
			if type(g) == "string" and not claimed[g] then claimed[g] = owner end
		end
	end

	local links = {}
	for guid, m in pairs(members) do
		if not m.leftAt and not hasAddon(guid) then
			local owner, how
			if ids[guid] and byAccount[ids[guid]] then
				owner, how = byAccount[ids[guid]], "bnet"
			elseif claimed[guid] then
				owner, how = claimed[guid], "claim"
			else
				local words = Accounts.Words((m.note or "") .. " " .. (m.officerNote or ""))
				local found
				for w in pairs(words) do
					local g = byFirst[w]
					if g and g ~= guid then
						if found and found ~= g then found = false; break end
						found = g
					end
				end
				if found then owner, how = found, "note" end
			end
			if owner then links[guid] = { owner = owner, how = how } end
		end
	end
	return links
end

-- The same, from saved data and the game (Battle.net ids cached for a minute).
Accounts.CACHE_FOR = 60
function Accounts.Current(guild, now)
	if not guild then return {} end
	now = now or SK.Compat.Now()
	local c = Accounts.cache
	if not c or c.guild ~= guild or now - c.at > Accounts.CACHE_FOR then
		local guids = {}
		for guid, m in pairs(guild.members) do if not m.leftAt then guids[#guids + 1] = guid end end
		local ids, n = SK.Compat.AccountIDs(guids)
		c = { guild = guild, at = now, ids = ids, count = n }
		Accounts.cache = c
	end
	return Accounts.Links(guild.members,
		function(g) return SK.Identity.HasAddon(g, guild.members[g], SK.Profile:Get(g, guild)) end,
		function(g) return SK.Profile:Get(g, guild) end, c.ids)
end
