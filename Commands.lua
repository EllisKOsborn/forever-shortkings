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

-- Everything someone helping you needs to know, as plain lines.
function Commands.BuildReport()
	local L = {}
	local function add(fmt, ...) L[#L + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt end

	local b = Compat.BuildInfo()
	add("== Short Kings %s ==", SK.VERSION)
	add("Client: %s build %s (%s), interface %s", tostring(b.version), tostring(b.build), tostring(b.date), tostring(b.interface))
	add("Time: server %s, local %s", tostring(Compat.Now()), date and date("%Y-%m-%d %H:%M") or "?")

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
	add("Can send addon messages: %s %s", yesno(canSend), why and ("(" .. why .. ")") or "")

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
	add("Sent %d, received %d, accepted %d, rejected %d, dropped %d, queued %d, buffered %d",
		st.sent, st.received, st.accepted, st.rejected, st.dropped, #SK.Sync.queue, #SK.Sync.buffer)
	add("Last raw sender: %q   Last reject reason: %s", tostring(SK.Sync.lastSender), tostring(SK.Sync.lastReject))

	add("")
	add("== Your data ==")
	local own = SK.Profile:Own()
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
			#SK.Data.Enchants.Missing(own.gear, own.class), yesno(SK.DB.settings.share.gear),
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
		SK.MainFrame:Toggle()
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
