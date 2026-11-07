-- Guild renamed "Sweaty Pumpers" -> "Short Royalty" (7 Nov 2026): saved
-- guild data must follow the guild to its new name.
local H = require("tests.helpers.load")

describe("Guild rename", function()
	local SK, W
	before_each(function()
		SK, W = H.load()
		W.guild = { name = "Sweaty Pumpers" }
		for i = 1, 10 do W.member("M" .. i, "Player-1-" .. i) end
		W.member("Pocus Hocus", W.player.guid)
		SK.Identity:ReadRoster()
		SK.Profile:BuildSelf()
		SK.DBM:Guild().profiles["Player-1-3"] = { guid = "Player-1-3", updated = W.now }
	end)

	it("keeps members and profiles under the new name", function()
		W.guild = { name = "Short Royalty" }
		SK.Identity:ReadRoster()
		assert.equal("Short Royalty", SK.guildKey)
		local g = SK.DBM:Guild()
		assert.equal(11, SK.Count(g.members))
		assert.is_not_nil(g.profiles["Player-1-3"])
		assert.is_not_nil(g.profiles[W.player.guid])
		assert.equal("Sweaty Pumpers", g.renamedFrom)
		assert.is_nil(SK.DB.guilds["Sweaty Pumpers"])
		assert.equal("Sweaty Pumpers", SK.Identity.renamedFrom)
	end)

	it("does not take over a different guild's data", function()
		-- We leave and join an unrelated guild with different members.
		W.guild = { name = "Other Guild" }
		W.roster = {}
		for i = 20, 30 do W.member("N" .. i, "Player-1-" .. i) end
		W.member("Pocus Hocus", W.player.guid)
		SK.Identity:ReadRoster()
		assert.is_not_nil(SK.DB.guilds["Sweaty Pumpers"])
		assert.equal(12, SK.Count(SK.DBM:Guild().members))
		assert.is_nil(SK.DBM:Guild().renamedFrom)
	end)

	it("never overwrites data already stored under the new name", function()
		SK.DB.guilds["Short Royalty"] = { members = { ["Player-9-9"] = { name = "X" } }, profiles = {}, recipeUniverse = {} }
		W.guild = { name = "Short Royalty" }
		SK.Identity:ReadRoster()
		assert.is_not_nil(SK.DB.guilds["Sweaty Pumpers"])
		assert.is_not_nil(SK.DBM:Guild().members["Player-9-9"])
	end)

	it("shows the new name to players but keeps the technical names", function()
		local toc = io.open("ShortRoyalty.toc"):read("*a")
		assert.truthy(toc:find("## Title: |cffD94FA0Short Royalty|r", 1, true))
		assert.truthy(toc:find("## SavedVariables: ShortRoyaltyDB", 1, true))
		assert.equal("ShortRoyalty", SK.PREFIX)
		assert.truthy(SK.CHAT_PREFIX:find("Short Royalty", 1, true))
	end)

	it("uses the ShortRoyalty folder everywhere the game loads files from", function()
		for _, f in ipairs({ "ShortRoyalty.toc", "embeds.xml", "Media/Fonts.xml", "UI/Theme.lua", ".pkgmeta" }) do
			local text = io.open(f):read("*a")
			assert.is_nil(text:find("ShortKings", 1, true), f .. " still mentions ShortKings")
		end
		-- every media path in Fonts.xml points at a file that exists in this folder
		local xml = io.open("Media/Fonts.xml"):read("*a")
		local n = 0
		for path in xml:gmatch('Interface\\AddOns\\ShortRoyalty\\([^"]+)"') do
			n = n + 1
			local local_path = path:gsub("\\", "/")
			assert.is_not_nil(io.open(local_path), "missing " .. local_path)
		end
		assert.is_true(n > 0)
		assert.truthy(io.open(".pkgmeta"):read("*a"):find("package-as: ShortRoyalty", 1, true))
	end)
end)
