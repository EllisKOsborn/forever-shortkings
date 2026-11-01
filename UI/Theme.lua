-- Theme: the Short Kings look, built from colours and gradients only.
-- (A gnome with a magenta beard and lit dynamite: fiery, cheeky, warm.)
local _, SK = ...

local Theme = {}
SK.Theme = Theme

Theme.HEX = {
	plumDark = "2A1220",  -- background bottom
	plum     = "3D1A2E",  -- background top
	plumLift = "4E2440",  -- raised surfaces (buttons, rows)
	magenta  = "D94FA0",  -- primary accent
	pink     = "F07ACB",  -- highlight / headings
	ember    = "FF7A1A",  -- active tab, hover border
	flame    = "FFC24A",  -- hover text, "new" badges
	leather  = "6B3E1E",  -- border
	gold     = "D4AF37",  -- thin edge on the border
	text     = "F5E6EE",
	muted    = "B89AAA",
	good     = "7CD67C",
	bad      = "E06060",
}

local cache = {}
function Theme.RGB(name)
	local c = cache[name]
	if not c then
		local hex = Theme.HEX[name] or name
		c = { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
		cache[name] = c
	end
	return c[1], c[2], c[3]
end

-- "|cffRRGGBB" escape for inline coloured text.
function Theme.Code(name)
	return "|cff" .. (Theme.HEX[name] or name)
end

function Theme.Color(name, alpha)
	local r, g, b = Theme.RGB(name)
	return CreateColor(r, g, b, alpha or 1)
end

-- Fill a texture with a two-colour gradient. `from` is the bottom (VERTICAL)
-- or the left (HORIZONTAL) colour.
function Theme.Gradient(tex, orientation, from, to, alphaFrom, alphaTo)
	tex:SetColorTexture(1, 1, 1, 1)
	tex:SetGradient(orientation, Theme.Color(from, alphaFrom), Theme.Color(to, alphaTo))
end

function Theme.Solid(tex, name, alpha)
	local r, g, b = Theme.RGB(name)
	tex:SetColorTexture(r, g, b, alpha or 1)
end

-- Leather border with a thin gold inner edge, drawn as plain textures so it
-- looks the same at every UI scale.
function Theme.Border(frame, thickness, inner)
	thickness = thickness or 3
	local function edge(layer, sub, color, inset, size)
		local t = {}
		for i = 1, 4 do
			t[i] = frame:CreateTexture(nil, layer, nil, sub)
			Theme.Solid(t[i], color)
		end
		t[1]:SetPoint("TOPLEFT", inset, -inset); t[1]:SetPoint("TOPRIGHT", -inset, -inset); t[1]:SetHeight(size)
		t[2]:SetPoint("BOTTOMLEFT", inset, inset); t[2]:SetPoint("BOTTOMRIGHT", -inset, inset); t[2]:SetHeight(size)
		t[3]:SetPoint("TOPLEFT", inset, -inset); t[3]:SetPoint("BOTTOMLEFT", inset, inset); t[3]:SetWidth(size)
		t[4]:SetPoint("TOPRIGHT", -inset, -inset); t[4]:SetPoint("BOTTOMRIGHT", -inset, inset); t[4]:SetWidth(size)
		return t
	end
	frame.border = edge("BORDER", 1, "leather", 0, thickness)
	if inner ~= false then
		frame.goldEdge = edge("BORDER", 2, "gold", thickness, 1)
	end
end

function Theme.SetBorderColor(frame, name)
	if not frame.border then return end
	for _, t in ipairs(frame.border) do Theme.Solid(t, name) end
end

-- Dark plum panel with border.
function Theme.Panel(frame, opts)
	opts = opts or {}
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	Theme.Gradient(bg, "VERTICAL", opts.from or "plumDark", opts.to or "plum")
	frame.bg = bg
	if opts.border ~= false then Theme.Border(frame, opts.thickness, opts.gold) end
	return frame
end

function Theme.Font(fs, size, color, flags)
	local font = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT
	fs:SetFont(font, size or 12, flags or "")
	if color then fs:SetTextColor(Theme.RGB(color)) end
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 0.8)
	return fs
end

function Theme.Text(parent, size, color, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	Theme.Font(fs, size, color or "text")
	return fs
end

function Theme.ClassText(name, classFile)
	local r, g, b = SK.Compat.ClassColor(classFile)
	return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name or "?")
end

-- "now", "5m", "3h", "2d"
function Theme.Ago(ts, now)
	if not ts then return "never" end
	now = now or SK.Compat.Now()
	local d = now - ts
	if d < 120 then return "now" end
	if d < 3600 then return math.floor(d / 60) .. "m" end
	if d < 86400 then return math.floor(d / 3600) .. "h" end
	return math.floor(d / 86400) .. "d"
end
