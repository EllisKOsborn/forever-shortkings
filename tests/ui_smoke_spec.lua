-- The UI cannot be tested for looks outside the game, but this proves every
-- UI file loads and every tab builds and refreshes without Lua errors.
local H = require("tests.helpers.load")

local UI_FILES = H.UI_FILES

describe("UI smoke test", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		for _, f in ipairs(UI_FILES) do assert(loadfile(f))("ShortKings", SK) end
		SK.Commands:OnInit()
		W.member("Pip", W.player.guid)
		W.member("Bob", "Player-1-B", { online = false, lastOnlineHours = 5 })
		W.professions = { { name = "Tailoring", rank = 300, max = 300, skillLine = 197 } }
		W.gear[1] = "|cffa335ee|Hitem:16914::::|h[Netherwind Crown]|h|r"
		W.talentNodes = { { id = 1, rank = 5, groups = { 2 }, spellID = 1001 } }
		W.factions = { { factionID = 529, name = "Argent Dawn", reaction = 7, currentStanding = 30000 } }
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		SK.Minimap:OnLogin()
	end)

	it("opens every tab", function()
		SK.Commands.Run("")
		assert.is_true(SK.MainFrame.frame:IsShown())
		for _, tab in ipairs(SK.MainFrame.tabs) do
			SK.MainFrame:Select(tab.key)
			assert.is_true(tab.built)
		end
		SK.CharacterTab:ShowCharacter("Player-1-B") -- member without data
		SK.CharacterTab:ShowCharacter(nil)          -- own character
		assert.equal("character", SK.MainFrame.current)
	end)

	it("builds the debug report", function()
		SK.Commands.Run("debug")
		local text = table.concat(SK.DB.lastReport, "\n")
		assert.truthy(text:find("Short Kings", 1, true))
		assert.truthy(text:find("Profession Tailoring", 1, true))
		SK.Commands.Run("log")
	end)

	it("roster rows filter and describe members", function()
		local rows = SK.RosterTab.Rows(SK.DBM:Guild(), W.now, "tail")
		assert.equal(1, #rows)
		assert.equal("Tail 300", rows[1].profText)
		assert.equal("Fire", rows[1].mainTree)
		local all = SK.RosterTab.Rows(SK.DBM:Guild(), W.now)
		assert.equal(2, #all)
	end)

	it("character details list the first-wave raids", function()
		local text = SK.CharacterTab.DetailText(SK.Profile:Own(), W.now)
		assert.truthy(text:find("Barrow Deeps  |cffAE93A3no attunement needed", 1, true))
		assert.truthy(text:find("Onyxia's Lair", 1, true))
		assert.is_nil(text:find("Molten Core", 1, true)) -- not in the first wave
		assert.truthy(text:find("Argent Dawn", 1, true))
		assert.truthy(text:find("Revered", 1, true))
	end)

	it("handles every slash command", function()
		for _, c in ipairs({ "scan", "sync", "reset", "help", "nonsense" }) do SK.Commands.Run(c) end
	end)
end)
