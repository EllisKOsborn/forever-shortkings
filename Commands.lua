-- Slash commands: /sk and /shortkings
--   /sk            open or close the window
--   /sk debug      show what the addon sees on this client (copyable)
--   /sk log        the debug report plus the recent log
--   /sk scan       rescan your character now
--   /sk sync       announce your data and ask for missing profiles
--   /sk reset      put the window back in the middle of the screen
--   /sk help       list commands
local _, SK = ...

local Commands = SK:NewModule("Commands")
local Compat = SK.Compat

local function yesno(v)
	if v == nil then return "n/a" end
	return v and "yes" or "no"
end

local function safe(fn, ...)
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then return "error: " .. tostring(a) end
	return a, b, c, d
end

-- Facts we need before building v0.3 Professions (docs/prompts/next-v0.3-professions.md, Step 1).
local function reagentLine(label, recipeID)
	if not recipeID then return label .. ": no recipe to test (open a profession window first)" end
	local s, why = Compat.RecipeSchematic(recipeID)
	if not s then return string.format("%s: recipe %d: no reagents (%s)", label, recipeID, tostring(why)) end
	local parts = {}
	for _, r in ipairs(s.reagents) do
		local id = r.itemID or r.currencyID
		local nm = r.itemID and Compat.ItemName(r.itemID) or nil
		parts[#parts + 1] = string.format("%sx %s%s%s", tostring(r.qty), r.currencyID and "currency " or "",
			tostring(id), nm and (" " .. nm) or "")
		if #parts >= 8 then break end
	end
	return string.format("%s: recipe %d %q makes %s (x%s-%s), %d reagent slots: %s", label, recipeID,
		tostring(s.name), tostring(s.output), tostring(s.min), tostring(s.max), #s.reagents,
		#parts > 0 and table.concat(parts, ", ") or "none")
end

function Commands.ProfessionProbes()
	local L = {}
	local function add(fmt, ...) L[#L + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt end
	local Prof = SK.Professions
	local ls = Prof.lastScan
	local showL, showU = Compat.RecipeFilters()
	add("Profession window open now: %s   Filters: show learned=%s, show unlearned=%s",
		yesno(Prof.windowOpen and true or false), yesno(showL), yesno(showU))
	if ls then
		add("Last scan: %s, %d learned of %d listed (unlearned listed: %s)", tostring(ls.name), ls.learned,
			ls.total, ls.total > ls.learned and "YES" or "no")
		local cats = {}
		for id, c in pairs(ls.cats or {}) do cats[#cats + 1] = { id = id, c = c } end
		table.sort(cats, function(a, b) return a.id < b.id end)
		add("Recipe categories in that window: %d", #cats)
		for i, e in ipairs(cats) do
			if i > 40 then add("  ... %d more", #cats - 40) break end
			local name, parent = Compat.CategoryInfo(e.id)
			local parentName = parent and Compat.CategoryInfo(parent)
			add("  category %s %q%s: %d listed, %d learned, e.g. %s", tostring(e.id), tostring(name),
				parentName and (" in " .. string.format("%q", parentName)) or "", e.c.total, e.c.learned,
				table.concat(e.c.names, "; "))
		end
	else
		add("Last scan: none this session. Open a profession window, then /sk debug again.")
	end
	-- A learned recipe: from this session's scan, or from your saved recipes.
	local learned = ls and ls.sampleLearned
	if not learned then
		local own = SK.Profile:Own()
		for _, list in pairs(own and own.recipes or {}) do
			learned = next(list)
			if learned then break end
		end
	end
	add(reagentLine("Reagents, a recipe you know", learned))
	add(reagentLine("Reagents, a recipe you don't know", ls and ls.sampleUnlearned))
	add("Specialisations (spell known? / client's name for that ID):")
	local profs = {}
	for skillLine in pairs(SK.Data.SPECIALISATIONS) do profs[#profs + 1] = skillLine end
	table.sort(profs)
	for _, skillLine in ipairs(profs) do
		for _, spec in ipairs(SK.Data.SPECIALISATIONS[skillLine]) do
			local known, how = Compat.IsSpellKnown(spec.spell)
			add("  %s %d (%s): known=%s via %s, client name=%q", SK.Data.ProfessionShort(skillLine), spec.spell,
				spec.name, yesno(known), tostring(how), tostring(safe(Compat.SpellName, spec.spell)))
		end
	end
	return L
end

-- Everything someone helping you needs to know, as plain lines.
function Commands.BuildReport()
	local L = {}
	local function add(fmt, ...) L[#L + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt end

	local b = Compat.BuildInfo()
	add("== Short Kings %s ==", SK.VERSION)
	add("Client: %s build %s (%s), interface %s", tostring(b.version), tostring(b.build), tostring(b.date), tostring(b.interface))
	add("Time: server %s, local %s", tostring(Compat.Now()), date and date("%Y-%m-%d %H:%M") or "?")

	add("")
	add("== Live-client checks (please send this part) ==")
	add("Interface number: %s (ShortKings.toc says 16001)", tostring(b.interface))
	local seenName = SK.Identity.LoginKey()
	local seen = seenName and SK.DB.seenGuids[seenName]
	if not seen then
		add("GUID stable between logins: not known yet (first login seen)")
	elseif seen.changedFrom then
		add("GUID stable between logins: NO, %s changed from %s to %s", seenName, seen.changedFrom, seen.guid)
	else
		add("GUID stable between logins: yes so far (%d logins as %s)", seen.logins, seenName)
	end
	add("Addon message sender format: %q   Roster name sample: %q", tostring(SK.Sync.lastSender),
		tostring(SK.Identity.rosterSample))
	local lastScan = SK.Professions.lastScan
	if lastScan then
		add("Profession window lists unlearned recipes: %s (%s: %d learned, %d listed)",
			lastScan.total > lastScan.learned and "yes" or "no (or all learned)", tostring(lastScan.name),
			lastScan.learned, lastScan.total)
	else
		add("Profession window lists unlearned recipes: open a profession window, then run /sk debug again")
	end
	local calPresent, calEvents = Compat.CalendarStatus()
	add("Calendar: C_Calendar present=%s, guild events listed=%s, AddEvent present=%s (open the calendar once; 0 is normal before that)",
		yesno(calPresent), tostring(calEvents), yesno(Compat.has("C_Calendar", "AddEvent")))
	add("Display font (Chakra Petch) loaded: %s   Body font: %s   Reduce motion: %s",
		SK.Theme and (SK.Theme.displayFailed and "NO, using the game font" or "yes (or window not opened yet)") or "n/a",
		SK.Theme and tostring(SK.Theme.BodyFont()) or "n/a", yesno(SK.DB.settings.reduceMotion))
	add("Recent Lua errors caught: %d (details at the end)", #SK.errors)

	add("")
	add("== Profession checks for v0.3 (please send this part too) ==")
	for _, line in ipairs(Commands.ProfessionProbes()) do add("%s", line) end

	add("")
	add("== Player ==")
	local name, realm = Compat.PlayerFullName()
	add("GUID: %s", tostring(Compat.PlayerGUID()))
	add("UnitFullName: name=%q realm=%q", tostring(name), tostring(realm))
	local basics = Compat.PlayerBasics()
	add("Class %s, race %s, level %s, faction %s", tostring(basics.class), tostring(basics.race),
		tostring(basics.level), tostring(basics.faction))
	add("Trial: IsTrialAccount=%s IsVeteranTrialAccount=%s GameLimitedMode=%s",
		yesno(IsTrialAccount and IsTrialAccount()), yesno(IsVeteranTrialAccount and IsVeteranTrialAccount()),
		yesno(GameLimitedMode_IsActive and GameLimitedMode_IsActive()))
	local canSend, why = Compat.CanSendAddonMessages()
	add("Can send addon messages: %s %s   (Blizzard's 'restricted' flag: %s, ignored)", yesno(canSend),
		why and ("(" .. why .. ")") or "", yesno(Compat.AddonChatFlag()))
	add("Send errors: %d   last: %s", SK.Sync.stats.sendErrors or 0, tostring(SK.Sync.lastSendError))

	add("")
	add("== Guild ==")
	add("In guild: %s, name %q, key %q", yesno(Compat.IsInGuild()), tostring(SK.guildName), tostring(SK.guildKey))
	add("Roster: source=%s loaded=%s sample name=%q", tostring(SK.Identity.rosterSource),
		yesno(SK.Identity.loaded), tostring(SK.Identity.rosterSample))
	add("Can view officer notes: %s", yesno(Compat.CanViewOfficerNote()))
	local guild = SK.DBM:Guild()
	if guild then
		local active, left, withData = 0, 0, 0
		for guid, m in pairs(guild.members) do
			if m.leftAt then left = left + 1 else active = active + 1 end
			if guild.profiles[guid] then withData = withData + 1 end
		end
		add("Members: %d active, %d left (pruned after 30 days), %d with data", active, left, withData)
	end

	add("")
	add("== Sync ==")
	local paused, pwhy = SK.Sync:IsPaused()
	local inInst, kind = Compat.InInstance()
	add("Enabled: %s  Paused: %s %s", yesno(SK.DB.settings.sync), yesno(paused), pwhy and ("(" .. pwhy .. ")") or "")
	add("Combat: %s  Instance: %s (%s)  Chat lockdown: %s", yesno(Compat.InCombat()), yesno(inInst),
		tostring(kind), yesno(Compat.InChatLockdown()))
	local st = SK.Sync.stats
	add("Sent %d, received %d, accepted %d, rejected %d, dropped %d, rate-limited %d, queued %d, buffered %d",
		st.sent, st.received, st.accepted, st.rejected, st.dropped, st.limited, #SK.Sync.queue, #SK.Sync.buffer)
	add("Ignored senders this session: %d (%d messages)   Loose name matches confirmed: %d",
		SK.Count(SK.Sync.blocked), st.blocked, SK.Count(SK.Identity.confirmed))
	add("Last raw sender: %q   Last reject reason: %s", tostring(SK.Sync.lastSender), tostring(SK.Sync.lastReject))

	add("")
	add("== Your data ==")
	local own = SK.Profile:Own()
	local shared = own and SK.DBM:Guild() and SK.DBM:Guild().profiles[own.guid]
	if shared then
		-- Guildmates run this same check on what we send; "no" means they'd drop it.
		local valid, problem = SK.Merge.Validate(shared)
		add("Passes guildmates' safety check: %s%s", yesno(valid), valid and "" or (" (" .. tostring(problem) .. ")"))
	end
	if own then
		add("Hash %s, updated %s, %d gear slots, ilvl %s", tostring(own.hash), tostring(own.updated),
			SK.Count(own.gear), tostring(own.ilvl))
		local spec, main = SK.Talents.Summary(own.talents)
		add("Talents (%s API): %s %s, %d talents", Compat.TalentAPI(), tostring(main), tostring(spec),
			own.talents and SK.Count(own.talents.nodes) or 0)
		add("Talent config ID: %s", tostring(safe(Compat.ActiveTraitConfigID)))
		for skillLine, p in pairs(own.profs or {}) do
			add("Profession %s (%d): %d/%d, scanned %s, %d recipes", tostring(p.name), skillLine, p.rank or 0,
				p.max or 0, p.scanned and "yes" or "NO", SK.Count(own.recipes and own.recipes[skillLine]))
		end
		add("Cooldowns: %d (%d tracked recipes)  Reputations: %d", SK.Count(own.cds),
			SK.Count(SK.DB.cooldownSpells[own.guid]), SK.Count(own.reps))
		add("Missing enchants: %d   Sharing: gear=%s recipes=%s   Main: %s",
			#SK.Data.Enchants.Missing(own.gear, own.class, own.level), yesno(SK.DB.settings.share.gear),
			yesno(SK.DB.settings.share.recipes), tostring(SK.DB.settings.main))
		add("Family (alts on this account in the guild): %d", own.family and #own.family or 0)
	else
		add("No profile yet (needs a guild and a loaded roster).")
	end

	add("")
	add("== Professions API ==")
	add("Trade skill API: %s", Compat.TradeSkillAPI())
	local ls = SK.Professions.lastScan
	if ls then
		add("Last scan: %s, %d learned of %d listed, full list API: %s", tostring(ls.name), ls.learned, ls.total, yesno(ls.complete))
	else
		add("Last scan: none this session (open a profession window)")
	end
	if Compat.has("C_TradeSkillUI", "IsGuildTradeSkillsEnabled") then
		add("Blizzard guild crafters lookup enabled: %s", yesno(safe(C_TradeSkillUI.IsGuildTradeSkillsEnabled)))
	end

	add("")
	add("== Crafters ==")
	local idx = SK.CraftIndex:Get()
	add("Index: %d recipes from %d crafters, %d items", idx.recipeCount, idx.crafterCount, SK.Count(idx.byItem))
	add("Item tooltip line: hooked=%s, setting=%s", yesno(SK.Tooltip.hooked), yesno(SK.DB.settings.craftTooltips))
	add("Names cached: %d items, %d spells; waiting for %d items, %d spells", SK.Count(SK.CraftIndex.itemNames),
		SK.Count(SK.CraftIndex.spellNames), SK.Count(SK.CraftIndex.pendingItems), SK.Count(SK.CraftIndex.pendingSpells))

	add("")
	add("== Attunement quests ==")
	for _, a in ipairs(SK.Data.ATTUNEMENTS) do
		for _, q in ipairs(a.quests) do
			local title = safe(Compat.QuestTitle, q)
			add("%s quest %d: done=%s, known to this client=%s (%s)", a.name, q, yesno(Compat.IsQuestDone(q)),
				yesno(title ~= nil and title ~= ""), tostring(title))
		end
		if #a.quests == 0 then
			add("%s: %s", a.name, a.status == "none" and "no attunement needed" or "TODO (no quest IDs yet)")
		end
		if a.item then
			local itemName = safe(Compat.ItemName, a.item)
			add("%s item %d: name=%q (resolves=%s), in bags=%s", a.name, a.item, tostring(itemName),
				yesno(itemName ~= nil), tostring(safe(Compat.ItemCountInBags, a.item)))
		end
	end

	add("")
	add("== APIs on this client ==")
	local missing = {}
	for _, probe in ipairs(Compat.ProbeAll()) do
		if not probe[2] then missing[#missing + 1] = probe[1] end
	end
	add("%d checked, %d missing", #Compat.PROBES, #missing)
	for _, m in ipairs(missing) do add("  missing: %s", m) end
	add("Minimap button: %s", tostring(SK.Minimap.mode))

	add("")
	add("== Recent errors (newest first) ==")
	if #SK.errors == 0 then add("none") end
	for _, e in ipairs(SK.errors) do
		add("[%s] %s (x%d, %s): %s", e.at, e.where, e.count, tostring(e.version), e.msg)
	end

	SK.DB.lastReport = L
	return L
end

local HELP = {
	"/sk - open or close the window",
	"/sk debug - what the addon sees (copyable)",
	"/sk log - debug report plus recent log",
	"/sk scan - rescan your character",
	"/sk sync - share your data now",
	"/sk reset - centre the window",
}

function Commands.Run(msg)
	local cmd = (msg or ""):lower():match("^%s*(%S*)")
	if cmd == "" then
		SK.MainFrame:Toggle(true) -- typed, so no animation
	elseif cmd == "debug" then
		SK.DebugWindow:Open(false)
	elseif cmd == "log" then
		SK.DebugWindow:Open(true)
	elseif cmd == "scan" then
		SK.Profile:BuildSelf()
		SK:Print("Character rescanned.")
	elseif cmd == "sync" then
		SK.Sync:SendHello()
		SK.Sync:SendQuery()
		SK:Print("Sync requested.")
	elseif cmd == "reset" then
		SK.MainFrame:ResetPosition()
	else
		for _, line in ipairs(HELP) do SK:Print(line) end
	end
end

function Commands:OnInit()
	SLASH_SHORTKINGS1 = "/sk"
	SLASH_SHORTKINGS2 = "/shortkings"
	SlashCmdList.SHORTKINGS = Commands.Run
end
