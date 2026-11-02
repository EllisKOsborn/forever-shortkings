-- Export: plain text for "Copy as text" (pasting into Discord or a forum).
-- No colour codes, icons or links; notes and officer notes are never
-- included, and your own gear/talents are left out if you don't share them.
-- Pure functions (no WoW calls); tested.
local _, SK = ...

local Export = {}
SK.Export = Export

-- Remove WoW escape sequences: colours, icons, atlases; links keep their text.
function Export.Plain(text)
	if type(text) ~= "string" then return "" end
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
	text = text:gsub("||", "|")
	return text
end

local STATUS = { addon = "online", online = "online", offline = "offline" }
local ATT = { yes = "attuned", no = "not attuned", unknown = "unknown", none = "no attunement needed" }

-- Roster rows (from RosterTab.Rows / AttunementRows) as text, one per line.
-- opts = { title = "...", now = ts, hideOwnGear = bool, raidName = "..." }
function Export.Roster(rows, opts)
	opts = opts or {}
	local out = { opts.title or "Short Kings roster" }
	for _, r in ipairs(rows) do
		local parts = { Export.Plain(r.name) }
		if r.level and r.level > 0 then parts[#parts + 1] = "lvl " .. r.level end
		local gearHidden = r.hidden and r.hidden.gear or (r.isSelf and opts.hideOwnGear)
		if r.att then
			parts[#parts + 1] = ATT[r.att] .. (r.attNote and (" (" .. r.attNote .. ")") or "")
		end
		if r.spec and not gearHidden then parts[#parts + 1] = (r.mainTree and (r.mainTree .. " ") or "") .. r.spec end
		if r.profText and r.profText ~= "" then parts[#parts + 1] = r.profText end
		if r.ilvl and not gearHidden then parts[#parts + 1] = string.format("ilvl %.0f", r.ilvl) end
		parts[#parts + 1] = STATUS[r.status] or "offline"
		if r.alts and #r.alts > 0 then
			local names = {}
			for _, a in ipairs(r.alts) do names[#names + 1] = Export.Plain(a.name) end
			parts[#parts + 1] = "alts: " .. table.concat(names, ", ")
		elseif r.altOf then
			parts[#parts + 1] = "alt of " .. Export.Plain(r.altOf)
		end
		out[#out + 1] = "- " .. table.concat(parts, " · ")
	end
	if #rows == 0 then out[#out + 1] = "(nobody matches)" end
	return table.concat(out, "\n")
end

-- Crafters of one recipe as text.
function Export.Crafters(name, profession, crafters)
	local out = { Export.Plain(name) .. (profession and (" (" .. profession .. ")") or "") .. " can be made by:" }
	for _, c in ipairs(crafters) do
		local bits = {}
		if c.skill and c.skill > 0 then bits[#bits + 1] = "skill " .. c.skill end
		if c.via then bits[#bits + 1] = "online on " .. Export.Plain(c.viaName or "an alt")
		else bits[#bits + 1] = STATUS[c.status] or "offline" end
		if c.altOf then bits[#bits + 1] = "alt of " .. Export.Plain(c.altOf) end
		out[#out + 1] = "- " .. Export.Plain(c.name) .. " (" .. table.concat(bits, ", ") .. ")"
	end
	if #crafters == 0 then out[#out + 1] = "(nobody yet)" end
	return table.concat(out, "\n")
end
