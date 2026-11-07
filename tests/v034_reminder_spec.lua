-- luacheck: globals C_TradeSkillUI OpenProfessionUIToSkillLine
-- v0.3.4: an orange bar on every tab until your profession windows have been
-- opened once, with a button that opens the next one.
local H = require("tests.helpers.load")

describe("v0.3.4 profession reminder bar", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		H.loadUI(SK)
		W.member("Pip", W.player.guid)
		W.professions = {
			{ name = "Tailoring", rank = 120, max = 150, skillLine = 197 },
			{ name = "Alchemy", rank = 80, max = 150, skillLine = 171 },
			{ name = "Herbalism", rank = 90, max = 150, skillLine = 182 },
		}
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
	end)

	it("names every crafting profession not opened yet (gathering doesn't count)", function()
		local b = SK.Professions.Banner(SK.Profile:Own(), SK.DB.settings.share)
		assert.equal("Your guild can't see your recipes yet. Open your Alchemy and Tailoring windows once.", b.text)
		assert.equal(171, b.next.skillLine)
		assert.equal(2, b.count)
		SK.Profile:Own().profs[171].scanned = W.now
		b = SK.Professions.Banner(SK.Profile:Own(), SK.DB.settings.share)
		assert.equal("Your guild can't see your recipes yet. Open your Tailoring window once.", b.text)
		SK.Profile:Own().profs[197].scanned = W.now
		assert.is_nil(SK.Professions.Banner(SK.Profile:Own(), SK.DB.settings.share))
	end)

	it("doesn't nag when you chose not to share recipes, or have no professions", function()
		assert.is_nil(SK.Professions.Banner(SK.Profile:Own(), { recipes = false }))
		assert.is_nil(SK.Professions.Banner(nil, {}))
		assert.is_nil(SK.Professions.Banner({ profs = {} }, {}))
	end)

	it("shows on every tab and makes the window taller instead of moving the tabs' contents", function()
		SK.MainFrame:Show("overview")
		local f = SK.MainFrame.frame
		assert.is_true(f.banner:IsShown())
		assert.truthy(f.banner.text:GetText():find("Alchemy and Tailoring", 1, true))
		assert.equal("Open Alchemy", f.banner.button.label:GetText())
		assert.equal(SK.Theme.SIZES.banner + SK.Theme.SPACE.m, SK.MainFrame.bannerH) -- the window grows by this
		SK.MainFrame:Select("roster")
		assert.is_true(f.banner:IsShown())
		-- once both windows have been opened, it goes and the window shrinks back
		SK.Profile:Own().profs[171].scanned = W.now
		SK.Profile:Own().profs[197].scanned = W.now
		SK.MainFrame:Refresh()
		assert.is_false(f.banner:IsShown())
		assert.equal(0, SK.MainFrame.bannerH)
		assert.equal(0, #SK.errors)
	end)

	it("the button opens that profession window, using Blizzard's own function when there is one", function()
		local opened
		_G.OpenProfessionUIToSkillLine = function(id) opened = id end
		SK.MainFrame:Show("overview")
		local button = SK.MainFrame.frame.banner.button
		button:GetScript("OnClick")(button)
		assert.equal(171, opened)
		_G.OpenProfessionUIToSkillLine = nil
		C_TradeSkillUI.OpenTradeSkill = function(id) opened = "api " .. id; return true end
		assert.is_true(SK.Compat.ShowProfession(197))
		assert.equal("api 197", opened)
	end)

	it("not in combat, and says so", function()
		C_TradeSkillUI.OpenTradeSkill = function() error("must not be called in combat") end
		W.combat = true
		SK.MainFrame:Show("overview")
		assert.is_true(SK.MainFrame.frame.banner.button.disabled)
		local ok, why = SK.Compat.ShowProfession(171)
		assert.is_false(ok)
		assert.equal("combat", why)
		W.combat = false
	end)

	it("hides the button when the client can't open profession windows", function()
		C_TradeSkillUI.OpenTradeSkill = nil
		_G.OpenProfessionUIToSkillLine = nil
		SK.MainFrame:Show("overview")
		assert.is_true(SK.MainFrame.frame.banner:IsShown())
		assert.is_false(SK.MainFrame.frame.banner.button:IsShown())
	end)

	it("the window still fits small screens with the bar showing", function()
		local F = SK.MainFrame.FitScale
		local extra = SK.Theme.SIZES.banner + SK.Theme.SPACE.m
		assert.is_true(F(1.3, 1024, 668, extra) * (580 + extra) <= 668)
	end)
end)
