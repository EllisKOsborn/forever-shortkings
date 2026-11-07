-- luacheck: globals C_GuildInfo
-- v0.4.0: officers link alts for anyone ("Alt of..." on the Character tab),
-- shared through their profile; the newest link wins; "Not an alt" overrules
-- a guess from a guild note. Display only.
local H = require("tests.helpers.load")

local function profile(SK, guid, fields)
	local p = { v = 1, guid = guid, name = guid, updated = 1, gear = {} }
	for k, v in pairs(fields or {}) do p[k] = v end
	p.hash = SK.Profile.HashOf(p)
	return p
end

describe("Officer alt links", function()
	local SK, W, guild
	local OFF, ANN, BOB, ALT, NOTE = "P-OFF", "P-ANN", "P-BOB", "P-ALT", "P-NOTE"
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pocus Hocus", W.player.guid)
		W.member("Offi Cer", OFF)
		W.member("Ann Smith", ANN)
		W.member("Bob Jones", BOB)
		W.member("Mystery Alt", ALT, { online = false })
		W.member("Notey", NOTE, { online = false, note = "ann's alt" })
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		guild = SK.DBM:Guild()
		guild.profiles[ANN] = profile(SK, ANN)
		guild.profiles[BOB] = profile(SK, BOB)
	end)

	local function links() return SK.Accounts.Current(guild, W.now) end

	it("an officer's link moves a character out of 'not seen yet'", function()
		assert.is_nil(links()[ALT])
		guild.profiles[OFF] = profile(SK, OFF, { officer = true, links = { { a = ALT, m = ANN, t = 100 } } })
		SK.Accounts.cache = nil
		assert.same({ owner = ANN, how = "officer" }, links()[ALT])
		local o = SK.Overview.Build(guild, W.now)
		for _, w in ipairs(o.without) do assert.is_not.equal(ALT, w.guid) end
	end)

	it("ignores links from someone who doesn't say they're an officer", function()
		guild.profiles[OFF] = profile(SK, OFF, { links = { { a = ALT, m = ANN, t = 100 } } })
		assert.is_nil(links()[ALT])
	end)

	it("the newest link wins, and 'not an alt' overrules a guild-note guess", function()
		assert.same({ owner = ANN, how = "note" }, links()[NOTE])
		guild.profiles[OFF] = profile(SK, OFF, { officer = true, links = {
			{ a = ALT, m = ANN, t = 100 }, { a = NOTE, m = "", t = 100 } } })
		guild.officerLinks[ALT] = { m = BOB, t = 200 } -- our own, newer
		local l = links()
		assert.same({ owner = BOB, how = "officer" }, l[ALT])
		assert.is_nil(l[NOTE])
	end)

	it("an officer's own links go into their profile and pass guildmates' check", function()
		_G.C_GuildInfo = _G.C_GuildInfo or {}
		local before = C_GuildInfo.CanEditOfficerNote
		C_GuildInfo.CanEditOfficerNote = function() return true end
		SK.Profile:SetOfficerLink(ALT, ANN)
		SK.Profile:SetOfficerLink(NOTE, false)
		local pub = guild.profiles[W.player.guid]
		assert.is_true(pub.officer)
		assert.equal(2, #pub.links)
		assert.is_true((SK.Merge.Validate(pub)))
		-- older versions accept both as plain extra fields
		local f1, f2 = SK.Merge.FIELDS.officer, SK.Merge.FIELDS.links
		SK.Merge.FIELDS.officer, SK.Merge.FIELDS.links = nil, nil
		assert.is_true((SK.Merge.Validate(pub)))
		SK.Merge.FIELDS.officer, SK.Merge.FIELDS.links = f1, f2
		SK.Profile:SetOfficerLink(ALT, nil)
		assert.is_nil(guild.officerLinks[ALT])
		C_GuildInfo.CanEditOfficerNote = before
	end)

	it("refuses malformed links", function()
		local base = { v = 1, guid = "X-1", updated = 1, hash = "h", officer = true }
		base.links = { { a = "P-1", m = 5, t = 1 } }
		assert.is_false((SK.Merge.Validate(base)))
		base.links = nil
		base.officer = "yes"
		assert.is_false((SK.Merge.Validate(base)))
	end)

	it("the Character tab shows 'Alt of...' to officers only, listing people who have the addon", function()
		_G.C_GuildInfo = _G.C_GuildInfo or {}
		local before = C_GuildInfo.CanEditOfficerNote
		C_GuildInfo.CanEditOfficerNote = function() return false end
		SK.MainFrame:Show("character")
		local tab = SK.CharacterTab
		tab:ShowCharacter(ALT)
		assert.is_false(tab.officerAlt:IsShown())
		C_GuildInfo.CanEditOfficerNote = function() return true end
		tab:Refresh()
		assert.is_true(tab.officerAlt:IsShown())
		local texts = {}
		for _, it in ipairs(SK.CharacterTab.OfficerItems(ALT)) do texts[#texts + 1] = it.text end
		assert.same({ "Alt of: not set", "Not an alt", "Alt of Ann Smith", "Alt of Bob Jones", "Alt of Pocus Hocus" }, texts)
		tab.officerAlt:Choose(BOB)
		assert.equal(BOB, guild.officerLinks[ALT].m)
		assert.same({ owner = BOB, how = "officer" }, links()[ALT])
		C_GuildInfo.CanEditOfficerNote = before
		assert.equal(0, #SK.errors)
	end)
end)

describe("Menus scroll", function()
	it("shows a limited number of rows and scrolls with the wheel", function()
		local SK = H.load()
		H.loadUI(SK)
		local items = {}
		for i = 1, 30 do items[i] = { value = i, text = "Item " .. i } end
		local m = SK.Widgets.Menu(UIParent, { items = function() return items end, get = function() return 1 end,
			set = function() end })
		m:Open()
		local shown = 0
		for _, e in ipairs(m.pop.entries) do if e:IsShown() then shown = shown + 1 end end
		assert.equal(SK.Widgets.MENU_ROWS, shown)
		assert.equal(1, m.pop.entries[1].value)
		m.pop:GetScript("OnMouseWheel")(m.pop, -1)
		assert.equal(4, m.pop.entries[1].value)
		for _ = 1, 20 do m.pop:GetScript("OnMouseWheel")(m.pop, -1) end
		assert.equal(30 - SK.Widgets.MENU_ROWS + 1, m.pop.entries[1].value) -- stops at the end
	end)
end)
