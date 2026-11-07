-- Menus show W.MENU_ROWS rows and scroll with the mouse wheel (v0.4.0).
local H = require("tests.helpers.load")

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
