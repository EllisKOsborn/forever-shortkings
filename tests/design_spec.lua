-- Design system (docs/DESIGN.md): tokens, contrast floors, glyph files and
-- Reduce motion. Looks can't be tested here, but the rules behind them can.
local H = require("tests.helpers.load")

local function readFile(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

describe("design system", function()
	local SK, W, Theme
	before_each(function()
		SK, W = H.load()
		assert(loadfile("UI/Theme.lua"))("ShortKings", SK)
		Theme = SK.Theme
	end)

	it("uses exactly the colours in docs/design/tokens.json", function()
		local json = assert(readFile("docs/design/tokens.json"))
		local block = json:match('"color"%s*:%s*(%b{})')
		local n = 0
		for name, hex in block:gmatch('"(%w+)"%s*:%s*"(%x%x%x%x%x%x)"') do
			assert.equal(hex:upper(), Theme.HEX[name], name)
			n = n + 1
		end
		assert.equal(n, SK.Count(Theme.HEX))
		local wash = json:match('"wash"%s*:%s*(%b{})')
		for name, v in wash:gmatch('"(%w+)"%s*:%s*([%d%.]+)') do
			assert.equal(tonumber(v), Theme.WASH[name], name)
		end
	end)

	it("only uses design tokens (the old v0.2 colour names are gone)", function()
		local OLD = { "pink", "flame", "muted", "good", "bad", "plum", "plumDark", "plumLift", "magenta", "leather", "gold" }
		local files = { "UI/Theme.lua", "UI/Widgets.lua", "UI/MainFrame.lua", "UI/OverviewTab.lua", "UI/RosterTab.lua",
			"UI/CharacterTab.lua", "UI/CraftersTab.lua", "UI/SettingsTab.lua", "UI/DebugWindow.lua", "UI/Minimap.lua",
			"UI/Tooltip.lua", "Commands.lua" }
		for _, f in ipairs(files) do
			local src = assert(readFile(f))
			for _, name in ipairs(OLD) do
				assert.is_nil(src:find('"' .. name .. '"', 1, true), f .. " uses " .. name)
			end
		end
		assert.equal("123456", Theme.Hex("123456"))
		assert.equal("|cff" .. Theme.HEX.success, Theme.Code("success"))
	end)

	it("meets the contrast floors on every surface text can sit on", function()
		local ALL = { "text", "textDim", "textMuted", "accent", "success", "warning", "danger" }
		local surfaces = {
			{ { Theme.RGB("sidebar") }, ALL }, { { Theme.RGB("bg") }, ALL }, { { Theme.RGB("panel") }, ALL },
			{ { Theme.Washed("panel", Theme.WASH.hover) }, ALL },
			{ { Theme.Washed("panel", Theme.WASH.selected) }, ALL },
			{ { Theme.RGB("panelAlt") }, ALL },
			{ { Theme.Washed("panelAlt", Theme.WASH.pressed) }, { "text", "textDim" } },
			{ { Theme.RGB("sky") }, ALL },
		}
		for _, s in ipairs(surfaces) do
			for _, ink in ipairs(s[2]) do
				local floor = ink == "text" and Theme.FLOORS.primary or Theme.FLOORS.other
				assert.is_true(Theme.Contrast(ink, s[1]) >= floor, ink)
			end
		end
		assert.is_true(Theme.Contrast("onAccent", "accent") >= 7)
		-- Sanity: the formula itself (white on black is 21:1).
		assert.near(21, Theme.Contrast({ 1, 1, 1 }, { 0, 0, 0 }), 1e-9)
	end)

	it("ships every glyph as a 32x32 32-bit TGA", function()
		for name in pairs(Theme.ICONS) do
			local data = readFile("Media/Icons/" .. name .. ".tga")
			assert.truthy(data, name)
			assert.equal(18 + 32 * 32 * 4, #data, name)
			assert.equal(2, data:byte(3))           -- uncompressed true colour
			assert.equal(32, data:byte(13))         -- width
			assert.equal(32, data:byte(15))         -- height
			assert.equal(32, data:byte(17))         -- bits per pixel
		end
		assert.truthy(Theme.Icon("roster"):find("Media\\Icons\\roster.tga", 1, true))
		assert.has_error(function() Theme.Icon("nope") end)
	end)

	it("re-snaps every hairline when the scale changes", function()
		local frame = W.stub()
		Theme.Hairline(frame)
		Theme.Edge(frame, "TOP")
		assert.is_true(Theme.RefreshPixels() >= 5)
	end)

	it("marks status by shape as well as colour", function()
		assert.truthy(Theme.StatusMark("addon"):find("WHITE8X8:8:8", 1, true))
		assert.truthy(Theme.StatusMark("online"):find("statusHollow", 1, true))
		assert.truthy(Theme.StatusMark("offline"):find("WHITE8X8:2:8", 1, true))
	end)

	it("skips fades when Reduce motion is on", function()
		local played = 0
		local frame = W.stub()
		frame.CreateAnimationGroup = function()
			local ag = W.stub()
			ag.Play = function() played = played + 1 end
			return ag
		end
		assert.is_false(SK.DB.settings.reduceMotion)
		assert.is_true(Theme.FadeIn(frame))
		assert.equal(1, played)
		SK.DB.settings.reduceMotion = true
		assert.is_false(Theme.FadeIn(frame))
		assert.equal(1, played)
	end)
end)
