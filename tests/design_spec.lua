-- v0.2.3 design refresh: the theme is the only source of visual values,
-- the window fits small screens, states read right, motion can be turned
-- off, and a big guild with silly names still builds.
local H = require("tests.helpers.load")

local UI_FILES = H.UI_FILES

describe("Theme", function()
	local SK
	before_each(function()
		SK = H.load()
		H.loadUI(SK)
	end)

	it("holds every colour as 0-1 RGBA, with matching hex codes", function()
		for name, c in pairs(SK.Theme.COLOR) do
			assert.equal(4, #c, name)
			for i = 1, 4 do assert.is_true(c[i] >= 0 and c[i] <= 1, name) end
			assert.equal(6, #SK.Theme.HEX[name], name)
		end
		assert.equal("FFC000", SK.Theme.HEX.gold)
		assert.equal("000000", SK.Theme.HEX.void)
	end)

	it("has a font, size and colour for every text role", function()
		for role, t in pairs(SK.Theme.TYPE) do
			assert.truthy(SK.Theme.FONT[t[1]], role)
			assert.is_true(t[2] >= 11, role .. " is at least 11 px")
		end
	end)

	it("paints text only when a colour is asked for", function()
		assert.equal("x", SK.Theme.Paint("text", "x"))
		assert.equal("|cffFF6A1Ax|r", SK.Theme.Paint("spark", "x"))
		assert.truthy(SK.Theme.Dot("good"):find("dot:8:8", 1, true))
	end)

	it("keeps UI motion short (only the sync ring, a status signal, runs past 250 ms)", function()
		for k, v in pairs(SK.Theme.MOTION) do
			if k ~= "pulse" and k ~= "pulseEvery" and k ~= "openScale" then assert.is_true(v <= 0.25, k) end
		end
		assert.is_true(SK.Theme.MOTION.pulse <= 0.45)
		assert.is_true(SK.Theme.MOTION.close < SK.Theme.MOTION.open) -- exits are faster
	end)

	it("counts with the right plural", function()
		assert.equal("1 member", SK.Theme.Count(1, "member"))
		assert.equal("0 members", SK.Theme.Count(0, "member"))
		assert.equal("151 characters", SK.Theme.Count(151, "character"))
	end)

	it("uses the body font family (with CJK fallbacks) when the client has loaded it", function()
		local used
		_G.ShortKingsBody13 = {}
		local fs = { SetFontObject = function(_, f) used = f end, SetFont = function() error("raw font used") end,
			SetTextColor = function() end, SetShadowOffset = function() end, SetShadowColor = function() end }
		SK.Theme.Font(fs, "body")
		assert.equal(_G.ShortKingsBody13, used)
		_G.ShortKingsBody13 = nil
	end)

	it("falls back to the game font if the bundled font can't load", function()
		local calls = {}
		local fs = { SetFont = function(_, file) calls[#calls + 1] = file; return #calls > 1 end,
			SetTextColor = function() end, SetShadowOffset = function() end, SetShadowColor = function() end }
		SK.Theme.Font(fs, "heading", "text")
		assert.equal(2, #calls)
		assert.truthy(calls[1]:find("ChakraPetch", 1, true))
		assert.is_true(SK.Theme.displayFailed)
	end)

	it("uses the preloaded display font object, and checks it really took", function()
		local file = "Interface\\AddOns\\ShortKings\\Media\\Fonts\\ChakraPetch-SemiBold.ttf"
		_G.ShortKingsDisplay13 = {}
		local used
		local fs = { SetFontObject = function(_, f) used = f end, GetFont = function() return file, 13 end,
			SetFont = function() error("raw font used") end,
			SetTextColor = function() end, SetShadowOffset = function() end, SetShadowColor = function() end }
		SK.Theme.Font(fs, "heading")
		assert.equal(_G.ShortKingsDisplay13, used)
		assert.is_false(SK.Theme.displayFailed)
		assert.equal(1, SK.Theme.displayStats.ok)
		-- the object exists but the file didn't load: game font, and it's reported
		local fell
		fs.GetFont = function() return nil end
		fs.SetFont = function(_, f) fell = f; return f ~= SK.Theme.FONT.display end
		SK.Theme.Font(fs, "heading")
		assert.is_true(SK.Theme.displayFailed)
		assert.equal(1, SK.Theme.displayStats.failed)
		assert.is_false(fell:find("ChakraPetch", 1, true) ~= nil)
		_G.ShortKingsDisplay13 = nil
	end)
end)

describe("Nothing visual is hard-coded outside the theme", function()
	it("UI files use theme roles, not colour numbers or hex codes", function()
		for _, file in ipairs(UI_FILES) do
			if file ~= "UI/Theme.lua" and file ~= "Commands.lua" then
				local src = assert(io.open(file)):read("*a")
				-- |cffRRGGBB escapes (item links in comments aside)
				for hex in src:gmatch("|cff(%x%x%x%x%x%x)") do
					error(file .. " has a hard-coded colour |cff" .. hex)
				end
				assert.is_nil(src:find("SetTextColor%(%s*[%d%.]"), file .. " sets a literal text colour")
				assert.is_nil(src:find("SetVertexColor%(%s*[%d%.]"), file .. " sets a literal vertex colour")
				assert.is_nil(src:find("SetColorTexture%(%s*[%d%.]+%s*,%s*[%d%.]+%s*,%s*[%d%.]+%s*,%s*[1-9%.]"),
					file .. " sets a literal visible colour")
				assert.is_nil(src:find("AddLine%([^\n]-,%s*[%d%.]+%s*,%s*[%d%.]+"), file .. " has a literal tooltip colour")
				assert.is_nil(src:find("UIPanelCloseButton", 1, true), file .. " uses the Blizzard close button")
			end
		end
	end)
end)

describe("Main window", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pip", W.player.guid)
		SK.Identity:ReadRoster()
	end)

	it("shrinks to fit small screens and big UI scales", function()
		local F = SK.MainFrame.FitScale
		assert.equal(1, F(1, 1920, 1080))
		assert.equal(1.3, F(1.3, 2560, 1440))              -- room to spare
		assert.is_true(F(1.3, 1024, 668) * 580 <= 668)      -- 1024x768 at UI scale 1.15
		assert.is_true(F(1, 800, 600) * 880 <= 800)         -- tiny window mode
		assert.equal(0.5, F(1, 100, 100))                   -- never vanishes
		assert.equal(1, F(1, 5120, 1440))                   -- ultrawide: no change
	end)

	it("says what sync is doing and counts errors", function()
		assert.equal("Short Royalty  ·  Sync on", SK.MainFrame.StatusText("Short Royalty", false))
		assert.equal("No guild  ·  Sync paused: combat", SK.MainFrame.StatusText(nil, true, "combat"))
		assert.truthy(SK.MainFrame.StatusText("G", false, nil, 2):find("2 errors", 1, true))
	end)

	it("opens in combat without errors (nothing protected is touched)", function()
		W.combat = true
		SK.MainFrame:Open("roster")
		SK.MainFrame:Select("character")
		SK.MainFrame:Select("settings")
		SK.MainFrame:Close(true)
		assert.is_false(SK.MainFrame.frame:IsShown())
		assert.equal(0, #SK.errors)
	end)

	it("/sk opens instantly, and Reduce motion turns every animation off", function()
		assert.is_false(SK.DB.settings.reduceMotion)
		assert.is_true(SK.Motion.Enabled())
		SK.DB.settings.reduceMotion = true
		assert.is_false(SK.Motion.Enabled())
		SK.Commands.Run("")
		assert.is_true(SK.MainFrame.frame:IsShown())
		SK.MainFrame:Close()                               -- no animation: hides at once
		assert.is_false(SK.MainFrame.frame:IsShown())
	end)
end)

describe("States", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
	end)

	it("empty roster and character texts say why and what to do", function()
		assert.truthy(SK.RosterTab.EmptyText(false):find("not in a guild", 1, true))
		assert.truthy(SK.RosterTab.EmptyText(true, "zz"):find("Nobody matches \"zz\"", 1, true))
		assert.truthy(SK.RosterTab.EmptyText(true, ""):find("hasn't loaded", 1, true))
		assert.truthy(SK.CharacterTab.EmptyText(true):find("No data synced yet", 1, true))
		assert.truthy(SK.CharacterTab.EmptyText(false):find("Pick someone", 1, true))
	end)

	it("a member with no data shows the empty state, not a blank panel", function()
		W.member("Pip", W.player.guid)
		W.member("Bob", "Player-1-B", { online = false })
		SK.Identity:ReadRoster()
		SK.CharacterTab:ShowCharacter("Player-1-B")
		assert.truthy(SK.CharacterTab.meta:GetText():find("No data synced yet", 1, true))
		assert.is_true(SK.CharacterTab.empty:IsShown())
		assert.is_false(SK.CharacterTab.colA:IsShown())
	end)

	it("the Overview works with no guild at all", function()
		W.guild = nil
		SK.MainFrame:Show("overview")
		assert.truthy(SK.OverviewTab.header:GetText():find("No guild", 1, true))
	end)

	it("sheet text keeps labels, values and colours", function()
		local text = SK.Widgets.SheetText({ { title = "Raids", rows = {
			{ label = "Onyxia", value = "3 attuned", tone = "good" }, { text = "note" }, { gap = true }, { label = "x" } } } })
		assert.equal("RAIDS\n  Onyxia  " .. SK.Theme.Code("good") .. "3 attuned|r\n  note\n  x  -", text)
	end)
end)

describe("Stress: a 150-member guild with awkward names", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
	end)

	it("builds every tab and sorts every column", function()
		W.member("Pip", W.player.guid)
		local names = { "Sir-Reginald-Bartholomew-Fizzlebang-the-Unreasonably-Tall",
			"Ääröö", "Пётр", "X", "WWWWWWWWWWWWWWWWWWWWWWWW", "名前" }
		for i = 1, 150 do
			W.member(names[i % #names + 1] .. i, "Player-1-" .. i, { online = i % 3 == 0, level = i % 60 + 1 })
		end
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		SK.MainFrame:Show("roster")
		local rows = SK.RosterTab.Rows(SK.DBM:Guild(), W.now)
		assert.equal(151, #rows)
		for i in ipairs(SK.RosterTab.list.opts.columns) do
			SK.RosterTab.list.sortCol = i
			SK.RosterTab.list:Sort()
		end
		for _, tab in ipairs(SK.MainFrame.tabs) do SK.MainFrame:Select(tab.key) end
		SK.CharacterTab:ShowCharacter("Player-1-1")
		local o = SK.Overview.Build(SK.DBM:Guild(), W.now)
		assert.equal(151, o.members)
		assert.equal(0, #SK.errors)
	end)
end)
