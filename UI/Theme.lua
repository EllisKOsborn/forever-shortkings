-- Theme: every colour, font, size, spacing step, border and motion timing
-- the UI uses. Nothing visual is hard-coded anywhere else: other files ask
-- for a role ("dim", "heading", SPACE.m) and get the value from here.
--
-- The look: true black and gold (after the Lamborghini DESIGN.md reference
-- in docs/design/), the gnome's pink beard for selections and the crest,
-- and dynamite-spark orange only for alerts and sync status. See DESIGN.md.
local _, SK = ...

local Theme = {}
SK.Theme = Theme

---------------------------------------------------------------------------
-- Colours (0-1 RGBA)
---------------------------------------------------------------------------
Theme.COLOR = {
	-- Surfaces: depth comes from tone steps, not shadows or gradients.
	void      = { 0.000, 0.000, 0.000, 0.96 }, -- window ground
	surface   = { 0.067, 0.067, 0.067, 1 },    -- #111111 panels inside the window
	raised    = { 0.110, 0.110, 0.110, 1 },    -- #1C1C1C hover, controls
	pressed   = { 0.039, 0.039, 0.039, 1 },    -- #0A0A0A pressed controls
	rule      = { 0.086, 0.086, 0.086, 1 },    -- #161616 row rules
	line      = { 0.165, 0.165, 0.165, 1 },    -- #2A2A2A borders, dividers
	lineStrong = { 0.267, 0.267, 0.267, 1 },   -- #444444 control borders, scroll thumb
	-- Ink
	text      = { 0.961, 0.961, 0.961, 1 },    -- #F5F5F5 names, key numbers
	dim       = { 0.651, 0.651, 0.651, 1 },    -- #A6A6A6 labels, metadata (8.6:1 on black)
	faint     = { 0.439, 0.439, 0.439, 1 },    -- #707070 disabled only
	onGold    = { 0.000, 0.000, 0.000, 1 },    -- text on a gold button
	-- Accents
	gold      = { 1.000, 0.753, 0.000, 1 },    -- #FFC000 where you are, the one primary action, key figures
	goldLit   = { 1.000, 0.808, 0.243, 1 },    -- #FFCE3E gold hover
	goldDeep  = { 0.569, 0.451, 0.000, 1 },    -- #917300 gold pressed
	beard     = { 0.941, 0.420, 0.690, 1 },    -- #F06BB0 what you picked: selections, checks, the crest
	spark     = { 1.000, 0.416, 0.102, 1 },    -- #FF6A1A alerts and sync status only
	-- Meaning
	good      = { 0.298, 0.765, 0.541, 1 },    -- #4CC38A
	bad       = { 0.898, 0.282, 0.302, 1 },    -- #E5484D
	shadow    = { 0, 0, 0, 0.9 },              -- text shadow
}

-- Alphas used with a colour (a tint, a selected row).
Theme.ALPHA = {
	selected = 0.16, -- beard tint behind a selected row or chip
	hover = 1,
	disabledIcon = 0.35,
}

-- "RRGGBB" for |c escapes, derived from COLOR so the two never drift.
Theme.HEX = {}
for name, c in pairs(Theme.COLOR) do
	Theme.HEX[name] = string.format("%02X%02X%02X", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
		math.floor(c[3] * 255 + 0.5))
end

function Theme.RGB(name)
	local c = Theme.COLOR[name] or Theme.COLOR.text
	return c[1], c[2], c[3]
end

function Theme.RGBA(name, alpha)
	local c = Theme.COLOR[name] or Theme.COLOR.text
	return c[1], c[2], c[3], alpha or c[4]
end

-- "|cffRRGGBB" escape for inline coloured text.
function Theme.Code(name)
	return "|cff" .. (Theme.HEX[name] or name)
end

-- Wrap text in a colour (no-op for "text", which is the default ink).
function Theme.Paint(name, text)
	if not name or name == "text" then return text end
	return Theme.Code(name) .. text .. "|r"
end

-- Tooltip lines in theme colours.
function Theme.TipLine(tt, text, color, wrap)
	local r, g, b = Theme.RGB(color or "text")
	tt:AddLine(text, r, g, b, wrap)
end

function Theme.TipDouble(tt, left, right, leftColor, rightColor)
	local r, g, b = Theme.RGB(leftColor or "text")
	local r2, g2, b2 = Theme.RGB(rightColor or "text")
	tt:AddDoubleLine(left, right, r, g, b, r2, g2, b2)
end

function Theme.Solid(tex, name, alpha)
	tex:SetColorTexture(Theme.RGBA(name, alpha))
end

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\ShortKings\\Media\\"
Theme.MEDIA = MEDIA

-- Display: Chakra Petch SemiBold (SIL OFL, bundled), uppercase, for the
-- window title, tabs, section headings and big figures only. Never for
-- names or anything a player typed (it has no Cyrillic or CJK).
-- Body: the game's own Arial Narrow, a plain grotesque that sits with the
-- display face; other locales keep the client's standard font.
Theme.FONT = {
	display = MEDIA .. "Fonts\\ChakraPetch-SemiBold.ttf",
	body = "Fonts\\ARIALN.TTF",
}
local LATIN = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true,
	ptBR = true, ruRU = true }

function Theme.BodyFont()
	if LATIN[SK.Compat.Locale()] then return Theme.FONT.body end
	return STANDARD_TEXT_FONT or Theme.FONT.body
end

-- Type scale. Five sizes do the work; nothing under 11.
Theme.SIZE = { micro = 11, small = 12, body = 13, title = 15, figure = 24 }

-- Roles: which face and size each kind of text uses.
Theme.TYPE = {
	brand   = { "display", 20 },            -- SHORT KINGS in the title bar
	tab     = { "display", 13 },            -- main navigation
	heading = { "display", 13 },            -- section headings (uppercase)
	figure  = { "display", 24 },            -- one key number per screen
	name    = { "body", 20 },               -- a character's name
	title   = { "body", 15 },               -- an item's name in the Crafters panel
	body    = { "body", 13 },
	small   = { "body", 12 },
	micro   = { "body", 11 },
}

Theme.displayFailed = false -- set if the bundled font can't be loaded (shown in /sk debug)

function Theme.Font(fs, role, color)
	local t = Theme.TYPE[role] or Theme.TYPE.body
	-- Body text uses the font families in Media/Fonts.xml (they fall back
	-- to Korean/Chinese fonts for names in those alphabets).
	local family = t[1] == "body" and _G["ShortKingsBody" .. t[2]]
	if family and fs.SetFontObject then
		fs:SetFontObject(family)
	-- SetFont returns false when the file can't be used; fall back to the
	-- game font so text never disappears. (nil = older client, no result.)
	elseif fs:SetFont(t[1] == "display" and Theme.FONT.display or Theme.BodyFont(), t[2], "") == false then
		if t[1] == "display" then Theme.displayFailed = true end
		fs:SetFont(STANDARD_TEXT_FONT or Theme.FONT.body, t[2], "")
	end
	if color then fs:SetTextColor(Theme.RGB(color)) end
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(Theme.RGBA("shadow"))
	return fs
end

function Theme.Text(parent, role, color, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	Theme.Font(fs, role, color or "text")
	fs:SetJustifyH("LEFT")
	return fs
end

---------------------------------------------------------------------------
-- Spacing, sizes, borders
---------------------------------------------------------------------------
-- One 4-point scale. Tight inside a group, generous between groups.
Theme.SPACE = { xxs = 2, xs = 4, s = 8, m = 12, l = 16, xl = 20, xxl = 32 }

Theme.SIZES = {
	window = { 880, 580 },
	titleBar = 52,
	tabBar = 32,
	pad = 16,           -- window inner margin
	control = 24,       -- buttons, search box, menu
	controlSmall = 20,  -- buttons inside list rows
	minHit = 24,        -- smallest click area; smaller controls widen their hit box
	check = 16,
	row = 22,           -- list row pitch
	header = 24,        -- list header height
	specRow = 18,       -- key/value row pitch in sections
	scrollbar = 4,      -- visible thumb width (the hit area is 12)
	crest = 30,
	slot = 38,          -- paperdoll item slot
	underline = 2,      -- active tab marker
}

Theme.BORDER = { hairline = 1, slot = 2 }

---------------------------------------------------------------------------
-- Textures (all power-of-two .tga, drawn by tools/textures.js)
---------------------------------------------------------------------------
Theme.TEX = {
	white = "Interface\\Buttons\\WHITE8X8",
	crest = MEDIA .. "Textures\\crest",
	arrow = MEDIA .. "Textures\\arrow",
	close = MEDIA .. "Textures\\close",
	dot = MEDIA .. "Textures\\dot",
	ring = MEDIA .. "Textures\\ring",
}

-- Inline round dot ("|T...|t") in a theme colour, for text.
function Theme.Dot(name, size)
	local r, g, b = Theme.RGB(name)
	size = size or 8
	return string.format("|T%s:%d:%d:0:0:16:16:0:16:0:16:%d:%d:%d|t", Theme.TEX.dot, size, size,
		math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

---------------------------------------------------------------------------
-- Motion (seconds). Quick and quiet; all of it off with "Reduce motion".
---------------------------------------------------------------------------
Theme.MOTION = {
	open = 0.18,      -- window in
	close = 0.12,     -- window out (exits are faster than entrances)
	page = 0.15,      -- tab content fade
	slide = 0.20,     -- active-tab underline glide
	hover = 0.10,     -- row highlight fade-in (fade-out is instant)
	pulse = 0.45,     -- sync ring
	openScale = 0.97, -- window grows from 97 % to 100 %
}

---------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------
-- 1px border drawn as four textures (crisp at every UI scale). The
-- textures are remembered here, keyed by frame.
local borders = setmetatable({}, { __mode = "k" })

function Theme.Border(frame, color, size, layer)
	size = size or Theme.BORDER.hairline
	local t = {}
	for i = 1, 4 do
		t[i] = frame:CreateTexture(nil, layer or "BORDER")
		Theme.Solid(t[i], color or "line")
	end
	t[1]:SetPoint("TOPLEFT"); t[1]:SetPoint("TOPRIGHT"); t[1]:SetHeight(size)
	t[2]:SetPoint("BOTTOMLEFT"); t[2]:SetPoint("BOTTOMRIGHT"); t[2]:SetHeight(size)
	t[3]:SetPoint("TOPLEFT"); t[3]:SetPoint("BOTTOMLEFT"); t[3]:SetWidth(size)
	t[4]:SetPoint("TOPRIGHT"); t[4]:SetPoint("BOTTOMRIGHT"); t[4]:SetWidth(size)
	borders[frame] = t
	return t
end

function Theme.SetBorderColor(frame, name, alpha)
	for _, t in ipairs(borders[frame] or {}) do Theme.Solid(t, name, alpha) end
end

-- Border in an arbitrary colour (item quality on a gear slot).
function Theme.SetBorderRGB(frame, r, g, b)
	for _, t in ipairs(borders[frame] or {}) do t:SetColorTexture(r, g, b, 1) end
end

-- A flat panel: background tone plus an optional 1px border.
function Theme.Panel(frame, opts)
	opts = opts or {}
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	Theme.Solid(bg, opts.bg or "surface")
	frame.bg = bg
	if opts.border ~= false then Theme.Border(frame, opts.border or "line") end
	return frame
end

-- A horizontal 1px rule.
function Theme.Rule(parent, color, layer)
	local t = parent:CreateTexture(nil, layer or "BORDER")
	Theme.Solid(t, color or "line")
	t:SetHeight(Theme.BORDER.hairline)
	return t
end

-- "1 member", "3 members" (irregular plurals pass `many`).
function Theme.Count(n, one, many)
	n = n or 0
	return n .. " " .. (n == 1 and one or (many or (one .. "s")))
end

function Theme.ClassText(name, classFile)
	local r, g, b = SK.Compat.ClassColor(classFile)
	return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name or "?")
end

-- A missing value: a dim dash, never an empty gap or a zero.
Theme.DASH = "|cff" .. Theme.HEX.faint .. "-|r"

Theme.STALE_AFTER = 7 * 86400 -- data older than this is labelled "may be out of date"

function Theme.IsStale(ts, now)
	return ts ~= nil and (now or SK.Compat.Now()) - ts > Theme.STALE_AFTER
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
