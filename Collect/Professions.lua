-- Professions: skill levels (always) and known recipes (scanned when the
-- player opens their own profession window).
local _, SK = ...

local Prof = SK:NewModule("Professions")
local Compat = SK.Compat

Prof.CHUNK = 50          -- recipes processed per frame
Prof.lastScan = nil      -- summary for /sr debug

-- Specialisations (B3) the player knows for a profession, as spell IDs.
-- An ID counts only when it is confirmed (status "ok" in Data/Professions)
-- or this client's own name for the spell matches the expected name, so a
-- wrong ID can never label anyone. Returns a list or nil.
function Prof.ReadSpecs(skillLine)
	local list = SK.Data.SPECIALISATIONS[skillLine]
	if not list then return nil end
	local out = {}
	for _, spec in ipairs(list) do
		if Compat.IsSpellKnown(spec.spell) then
			local ok = spec.status == "ok" or Compat.SpellName(spec.spell) == spec.name
			if ok then out[#out + 1] = spec.spell end
		end
	end
	return #out > 0 and out or nil
end

function Prof.ReadSkills()
	local profs = Compat.ReadProfessions()
	for skillLine, p in pairs(profs) do
		p.specs = Prof.ReadSpecs(skillLine)
	end
	return profs
end

---------------------------------------------------------------------------
-- Scanning
---------------------------------------------------------------------------
local scanning = false
local retries = 0

-- Process recipe IDs in chunks so a big profession never causes a hitch.
-- `done(result)` gets { learned = {[id]=itemID|0}, universe = {...}, cds = {[id]=seconds},
-- cats = {[categoryID]={total, learned, names}} } (cats: /sr debug only, never stored or sent)
Prof.CATEGORY_SAMPLES = 3
function Prof.ProcessRecipes(ids, done, runNow)
	local result = { learned = {}, universe = {}, cds = {}, cats = {} }
	local i = 1
	local function step()
		local last = math.min(i + Prof.CHUNK - 1, #ids)
		for n = i, last do
			local id = ids[n]
			local info = Compat.RecipeInfo(id)
			if info then
				local itemID = info.itemID or 0
				result.universe[id] = itemID
				local cat = result.cats[info.categoryID or 0]
				if not cat then
					cat = { total = 0, learned = 0, names = {} }
					result.cats[info.categoryID or 0] = cat
				end
				cat.total = cat.total + 1
				if info.learned then cat.learned = cat.learned + 1 end
				if SK.Reagents then SK.Reagents.Learn(id) end
				if #cat.names < Prof.CATEGORY_SAMPLES and info.name then cat.names[#cat.names + 1] = info.name end
				if info.learned then result.sampleLearned = result.sampleLearned or id
				else result.sampleUnlearned = result.sampleUnlearned or id end
				if info.learned then
					result.learned[id] = itemID
					local cd = Compat.RecipeCooldown(id)
					if cd then result.cds[id] = cd end
				end
			end
		end
		i = last + 1
		if i <= #ids then
			if runNow then step() else SK.After(0, step) end
		else
			done(result)
		end
	end
	if #ids == 0 then done(result) else step() end
end

local function scanModern()
	local T = C_TradeSkillUI
	if T.IsDataSourceChanging and T.IsDataSourceChanging() then return "retry" end
	if not Compat.IsOwnTradeSkill() then return "not own" end
	local skillLine, name, rank, max = Compat.OpenProfession()
	if not skillLine then return "retry" end
	local ids, complete = Compat.RecipeIDs()
	if #ids == 0 then return "retry" end
	scanning = true
	Prof.ProcessRecipes(ids, function(result)
		scanning = false
		result.skillLine, result.name, result.rank, result.max = skillLine, name, rank, max
		result.complete = complete
		Prof:StoreScan(result)
	end)
	return "started"
end

-- Classic fallback (not present in Forever 1.60.1, kept for safety).
local function scanClassic()
	local name, rank, max = GetTradeSkillLine()
	if not name or name == "UNKNOWN" then return "retry" end
	local skillLine
	for id, p in pairs(Compat.ReadProfessions()) do
		if p.name == name then skillLine = id end
	end
	if not skillLine then return "unknown profession" end
	local result = { learned = {}, universe = {}, cds = {}, skillLine = skillLine,
		name = name, rank = rank, max = max, complete = true }
	for i = 1, GetNumTradeSkills() do
		local _, kind = GetTradeSkillInfo(i)
		if kind ~= "header" and kind ~= "subheader" then
			local link = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
			local spellID = link and tonumber(link:match("enchant:(%d+)"))
			local itemID = Compat.ItemIDFromLink(GetTradeSkillItemLink and GetTradeSkillItemLink(i)) or 0
			if spellID then
				result.learned[spellID] = itemID
				result.universe[spellID] = itemID
			end
		end
	end
	Prof:StoreScan(result)
	return "started"
end

function Prof:Scan()
	if scanning then return end
	local api = Compat.TradeSkillAPI()
	local ok, status
	if api == "modern" then
		ok, status = pcall(scanModern)
	elseif api == "classic" then
		ok, status = pcall(scanClassic)
	else
		status = "no trade skill API"
	end
	if ok == false then
		scanning = false
		SK:RecordError("recipe scan", status)
		return
	end
	if status == "retry" and retries < 5 then
		retries = retries + 1
		SK:Debounce("tradeskill", 1, function() Prof:Scan() end)
	elseif status ~= "started" then
		SK:Debug("recipe scan skipped: %s", tostring(status))
	end
	if status == "started" then retries = 0 end
end

-- Save a finished scan into our own profile and the guild recipe list.
function Prof:StoreScan(result)
	local now = Compat.Now()
	local nLearned = SK.Count(result.learned)
	Prof.lastScan = { skillLine = result.skillLine, name = result.name, learned = nLearned,
		total = SK.Count(result.universe), complete = result.complete, at = now,
		cats = result.cats or {}, sampleLearned = result.sampleLearned, sampleUnlearned = result.sampleUnlearned }
	SK:Debug("scanned %s: %d learned of %d (complete list: %s)", tostring(result.name),
		nLearned, Prof.lastScan.total, tostring(result.complete))
	local cds = {}
	for id, seconds in pairs(result.cds) do cds[id] = now + math.floor(seconds) end
	Prof.SetScanRank(Compat.PlayerGUID(), result.skillLine, result.rank)
	SK.Profile:SetScan(result.skillLine, {
		name = result.name, rank = result.rank, max = result.max,
		learned = result.learned, universe = result.universe, cds = cds, at = now,
	})
end

---------------------------------------------------------------------------
-- Reminders
---------------------------------------------------------------------------
-- Crafting professions whose recipes have never been scanned.
function Prof.Unscanned(profile)
	local out = {}
	if not profile or not profile.profs then return out end
	for skillLine, p in pairs(profile.profs) do
		if not SK.Data.GATHERING[skillLine] and not p.scanned then
			out[#out + 1] = p.name or tostring(skillLine)
		end
	end
	table.sort(out)
	return out
end

---------------------------------------------------------------------------
-- Freshness nudges: "your Tailoring went from 240 to 262 since you last
-- opened it". Kept rare on purpose: only after a real gain (NUDGE_POINTS),
-- at most one chat line per session and per NUDGE_EVERY, and never if the
-- player turned it off. The Professions tab shows the same text quietly.
---------------------------------------------------------------------------
Prof.NUDGE_POINTS = 15         -- skill points gained since the last scan
Prof.NUDGE_EVERY = 3 * 86400   -- at most one chat reminder every 3 days
Prof.NUDGE_DELAY = 90          -- seconds after login

function Prof.SetScanRank(guid, skillLine, rank)
	if not guid or not skillLine or type(rank) ~= "number" or rank <= 0 then return end
	SK.DB.scanRank[guid] = SK.DB.scanRank[guid] or {}
	SK.DB.scanRank[guid][skillLine] = rank
end

-- Pure: { { skillLine, name, from, to } } for scanned crafting professions
-- that gained at least NUDGE_POINTS since their scan.
function Prof.Nudges(profile, ranks)
	local out = {}
	if not profile or type(profile.profs) ~= "table" then return out end
	ranks = ranks or {}
	for skillLine, p in pairs(profile.profs) do
		local from = ranks[skillLine]
		if p.scanned and not SK.Data.GATHERING[skillLine] and from and (p.rank or 0) - from >= Prof.NUDGE_POINTS then
			out[#out + 1] = { skillLine = skillLine, name = p.name or tostring(skillLine), from = from, to = p.rank }
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- Older data has no rank for its last scan: start counting from today.
function Prof.FillScanRanks(profile)
	if not profile or type(profile.profs) ~= "table" then return end
	local ranks = SK.DB.scanRank[profile.guid] or {}
	for skillLine, p in pairs(profile.profs) do
		if p.scanned and ranks[skillLine] == nil then Prof.SetScanRank(profile.guid, skillLine, p.rank) end
	end
end

function Prof.NudgeText(list)
	local parts = {}
	for _, n in ipairs(list) do
		parts[#parts + 1] = string.format("%s went from %d to %d", n.name, n.from, n.to)
	end
	if #parts == 0 then return nil end
	return "Your " .. table.concat(parts, ", ") .. " since you last opened " .. (#parts == 1 and "it" or "them")
		.. ". Open the window" .. (#parts == 1 and "" or "s") .. " to update your recipes."
end

function Prof.CurrentNudges()
	local own = SK.Profile:Own()
	if not own then return {} end
	Prof.FillScanRanks(own)
	return Prof.Nudges(own, SK.DB.scanRank[own.guid])
end

-- Chat reminder. Returns true if it printed.
function Prof:Nudge(now)
	now = now or Compat.Now()
	if self.nudged or not SK.DB.settings.profNudges then return false end
	if SK.DB.nudgedAt and now - SK.DB.nudgedAt < Prof.NUDGE_EVERY then return false end
	local text = Prof.NudgeText(Prof.CurrentNudges())
	if not text then return false end
	self.nudged = true
	SK.DB.nudgedAt = now
	SK:Print("%s", text)
	return true
end

function Prof:Remind()
	local own = SK.Profile:Own()
	local missing = Prof.Unscanned(own)
	if #missing > 0 then
		SK:Print("Open your %s window once so the guild can see your recipes.",
			table.concat(missing, ", "))
	end
end

function Prof:OnLogin()
	local function queue()
		SK:Debounce("tradeskill", 1, function() Prof:Scan() end)
	end
	SK:RegisterEvent("TRADE_SKILL_SHOW", function() retries = 0; Prof.windowOpen = true; queue() end)
	SK:RegisterEvent("TRADE_SKILL_CLOSE", function() Prof.windowOpen = false end)
	SK:RegisterEvent("TRADE_SKILL_LIST_UPDATE", queue)
	SK:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED", queue)
	SK:RegisterEvent("NEW_RECIPE_LEARNED", queue)
	SK.After(45, function() Prof:Remind() end)
	SK.After(Prof.NUDGE_DELAY, function() Prof:Nudge() end)
end
