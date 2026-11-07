-- Onboarding: a welcome line the first time Short Kings loads, and the
-- "Getting started" checklist on the Overview. Steps tick themselves off
-- from what the addon can see; the card goes away once everything is done
-- or the player hides it (settings.onboarding.hidden).
local _, SK = ...

local Onb = SK:NewModule("Onboarding")

Onb.WELCOME_DELAY = 12 -- seconds after login

-- Pure. Returns steps, allDone. Each step: { key, text, detail, done, optional }.
--   own: our full profile (or nil), seen: settings.seen, main: settings.main,
--   withAddon / members: guild counts (Core/Overview).
function Onb.Steps(own, seen, main, withAddon, members)
	seen = seen or {}
	local steps = {}
	local function add(key, text, done, detail, optional)
		steps[#steps + 1] = { key = key, text = text, done = done and true or false, detail = detail, optional = optional }
	end

	local missing = SK.Professions.Unscanned(own)
	local hasProfs = own and own.profs and next(own.profs) ~= nil
	add("profs", "Open your profession windows once", own ~= nil and #missing == 0,
		#missing > 0 and table.concat(missing, ", ") or (hasProfs and nil or "none learned yet"))
	add("character", "Check your Character tab", seen.character)
	add("settings", "Choose what you share (Settings)", seen.settings)
	if own and own.family and #own.family > 0 then
		add("main", "On an alt? Mark your main", main ~= nil, nil, true)
	end
	local others = math.max(0, (withAddon or 0) - 1)
	add("guild", "Get guildmates to install it", others > 0,
		string.format("%d of %d have it", withAddon or 0, members or 0))

	local allDone = true
	for _, s in ipairs(steps) do
		if not s.done and not s.optional then allDone = false end
	end
	return steps, allDone
end

function Onb.Visible(allDone)
	local o = SK.DB.settings.onboarding
	return not (o and o.hidden) and not allDone
end

function Onb.Hide()
	SK.DB.settings.onboarding.hidden = true
	SK:Fire("ONBOARDING_CHANGED")
end

-- Remember which tabs the player has looked at (for the checklist).
function Onb.Seen(key)
	local seen = SK.DB.settings.seen
	if not seen[key] then
		seen[key] = true
		SK:Fire("ONBOARDING_CHANGED")
	end
end

function Onb:Welcome()
	if SK.DB.settings.welcomed then return false end
	SK.DB.settings.welcomed = true
	SK:Print("Welcome to Short Kings! Type /sk (or click the minimap button) to open it.")
	SK:Print("The Overview has a short \"Getting started\" list: start by opening each of your profession windows once.")
	return true
end

function Onb:OnLogin()
	SK.After(Onb.WELCOME_DELAY, function() Onb:Welcome() end)
end
