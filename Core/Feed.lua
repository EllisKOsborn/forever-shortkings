-- Feed: "Recent milestones" for the Overview (levels, profession skill,
-- attunements, new recipes).
--
-- Worked out locally whenever a profile is replaced by a newer one (from a
-- guildmate, or our own rebuild), by comparing the old and new copies. It is
-- stored only in ShortKingsDB.feed and NEVER sent: every client builds its
-- own, so there is no protocol change. The first copy we ever see of a
-- character produces nothing, so a fresh install doesn't announce everyone.
local _, SK = ...

local Feed = SK:NewModule("Feed")

Feed.MAX = 50
Feed.LEVELS = { 10, 20, 30, 40, 50, 60 }
Feed.SKILLS = { 75, 150, 225, 300 }

-- Highest milestone crossed going from a to b (a < m <= b), or nil.
local function crossed(list, a, b)
	if type(a) ~= "number" or type(b) ~= "number" then return nil end
	local best
	for _, m in ipairs(list) do
		if a < m and b >= m then best = m end
	end
	return best
end

local function profName(skillLine, pr)
	if pr and type(pr.name) == "string" then return pr.name end
	local d = SK.Data.PROFESSIONS[skillLine]
	return d and d.key or "a profession"
end

-- Events between two copies of one character's profile. Pure; tested.
-- Returns { { kind, text, grats }, ... } where text has no name in it
-- ("reached level 60") and grats is the congratulation wording ("60").
function Feed.Diff(old, new)
	local out = {}
	if type(old) ~= "table" or type(new) ~= "table" then return out end
	local lvl = crossed(Feed.LEVELS, old.level, new.level)
	if lvl then out[#out + 1] = { kind = "level", text = "reached level " .. lvl, grats = "level " .. lvl } end

	if type(old.profs) == "table" and type(new.profs) == "table" then
		local ids = {}
		for id in pairs(new.profs) do ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local o, n = old.profs[id], new.profs[id]
			local m = o and n and crossed(Feed.SKILLS, o.rank, n.rank)
			if m then
				local name = profName(id, n)
				out[#out + 1] = { kind = "skill", text = "reached " .. name .. " " .. m, grats = name .. " " .. m }
			end
		end
	end

	for _, a in ipairs(SK.Data.ShownAttunements()) do
		if a.status ~= "none" and type(new.att) == "table" and new.att[a.key] == true
			and type(old.att) == "table" and old.att[a.key] == false then
			out[#out + 1] = { kind = "attune", text = "is attuned to " .. a.name, grats = a.name .. " attunement" }
		end
	end

	-- New recipes, only where the old copy already had a scan of that
	-- profession (a first scan isn't "learning" anything).
	if type(old.recipes) == "table" and type(new.recipes) == "table" then
		local ids = {}
		for id in pairs(new.recipes) do ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local o, n = old.recipes[id], new.recipes[id]
			if type(o) == "table" and type(n) == "table" then
				local count = 0
				for r in pairs(n) do
					if o[r] == nil then count = count + 1 end
				end
				if count > 0 then
					local name = profName(id, new.profs and new.profs[id])
					out[#out + 1] = { kind = "recipe", text = string.format("learned %d new %s recipe%s", count, name,
						count == 1 and "" or "s") }
				end
			end
		end
	end
	return out
end

-- Record the events for one character. `now` is server time.
function Feed:Note(guid, old, new, now)
	if not SK.DB or SK.DB.settings.feed == false or not guid then return 0 end
	local events = Feed.Diff(old, new)
	if #events == 0 then return 0 end
	local list = SK.DB.feed
	for _, e in ipairs(events) do
		local dup = false
		for _, x in ipairs(list) do
			if x.guid == guid and x.text == e.text then dup = true; break end
		end
		if not dup then
			table.insert(list, 1, { at = now, guid = guid, kind = e.kind, text = e.text, grats = e.grats })
		end
	end
	while #list > Feed.MAX do table.remove(list) end
	SK:Fire("FEED_UPDATED")
	return #events
end

-- Entries for current guild members, newest first, with their names.
function Feed.Entries(guild, limit)
	local out = {}
	for _, e in ipairs(SK.DB.feed or {}) do
		local m = guild and guild.members[e.guid]
		if m and not m.leftAt then
			out[#out + 1] = { at = e.at, guid = e.guid, kind = e.kind, text = e.text, grats = e.grats,
				name = m.name, class = m.class }
			if limit and #out >= limit then break end
		end
	end
	return out
end

-- "Grats Bramble on level 60!" for guild chat (pre-filled, never sent).
function Feed.GratsText(entry)
	local first = (entry.name or "?"):match("^(%S+)") or entry.name
	return "Grats " .. first .. " on " .. (entry.grats or entry.text) .. "!"
end
