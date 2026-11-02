# Short Kings design system

Status: **proposal** (Phase A of the design refresh, 2 Nov 2026). Nothing here
is built yet. The mockups are in `docs/mockups/design-v2.html`, rendered to
`docs/images/v2/`. When the owner approves, Phase B builds it in slices (see
the end of this file).

Inspiration: the *ideas* in Polestar Guides' design notes (one accent, depth
by tone, hairlines, a spacing scale, contrast floors). Polestar is GPL-3.0;
no code, art, glyphs or text were taken from it. Everything here is our own.

Identity: **"Small in stature. Big in loot."** A gnome with a magenta beard
and lit dynamite. Polestar is night and gold; we are **plum and pink**, with
**ember** kept for the dynamite spark.

---

## 1. Principles

1. **One accent.** Pink (`accent`) marks only three things: what you can act
   on next (the primary button, focus), where you are (active rail item,
   selected row, selected segment), and the one fact that decides a choice.
   Everything else is neutral plum.
2. **Depth by tone, not shadow.** Each surface is one step lighter:
   rail → window → panel → card. Only the window casts a shadow. Panels,
   cards and buttons never glow.
3. **Hairlines, square corners.** Every edge is a 1 px white line at 10%,
   snapped to the pixel. No rounded corners (status marks from the game are
   the exception).
4. **Shared lines.** The header band, the toolbar band and the status line
   are the same height on every tab, so switching tabs never moves them.
5. **Readable first.** Nothing below 11 px. Text shadow always on. Contrast
   floors are checked by a script, not by eye.
6. **Never colour alone.** Every status has a shape or a word as well.
7. **Quiet motion.** Short fades only; the header spark is the one ambient
   loop, and *Reduce motion* turns it off.
8. **Calm empty states** that say what will appear and how to get it.

## 2. Tokens

The single source is `docs/design/tokens.json`. `UI/Theme.lua` will carry the
same values (Phase B adds a test that the two match).

### Colour

| Role | Token | Hex | Use |
|---|---|---|---|
| Accent | `accent` | `#F27BC4` | active rail item, selection bar, primary button, focus, current menu choice |
| Ink on accent | `onAccent` | `#1A0913` | label of the primary button |
| Rail | `sidebar` | `#140A11` | rail, status line, inputs (an inset look) |
| Window | `bg` | `#1C0E18` | the window ground, behind cards |
| Raised panel | `panel` | `#24121F` | toolbar band, lists, side panels, grouped settings |
| Controls, cards | `panelAlt` | `#2E1828` | buttons, menus, Overview cards |
| Header band top | `sky` | `#4A1E3C` | header band only |
| Text | `text` | `#FBF2F7` | names, values, titles |
| Secondary text | `textDim` | `#D8C2CF` | labels, column headers, descriptions |
| Muted text | `textMuted` | `#AE93A3` | timestamps, hints, "none" |
| Success | `success` | `#6BD999` | online with addon, attuned, ready, shared |
| Warning | `warning` | `#FABF4D` | online without addon, stale data, needs an update, missing enchant |
| Danger | `danger` | `#F57373` | not attuned, nobody has it |
| Brand magenta | `brand` | `#D94FA0` | header band wash and banner art only, never text |
| Ember | `ember` | `#FF7A1A` | the fuse line and sparks only, never text |

**White washes** (alpha over whatever is below; never a new hue):
hairline 10%, hover 6%, selected 9%, pressed 12%. Row zebra 2%.

**Subject colours** name things and stay exactly as the game shows them:
class colours, item quality colours, the game's ready-check marks. They are
not held to the floors (see §13).

Retired from the current theme: `leather`, `gold` (the double border goes),
`flame` (hover text becomes a wash instead). The old names keep working
until every file has moved over.

### Spacing

`4, 8, 12, 16, 24, 32`. Nothing else. Inside panels: 16. Window side insets:
24. Between cards: 16. Between buttons: 8. Between a control and its label: 8.

### Type

The game's font (it localises and feels native). Sizes:

| Name | px | Use |
|---|---|---|
| hero | 26 | the big number on an Overview card, item level on the paper doll |
| display | 18 | wordmark, character name |
| title | 15 | page title in the toolbar, card titles, side panel title |
| body | 13 | list rows, settings labels, detail text |
| label | 12 | buttons, inputs, column headers, card detail lines |
| small | 11 | rail labels, hints, status line, chips, timestamps |

Section headings (Character details, Settings groups) are label 12,
`textDim`, upper case with a little letter spacing, with a hairline under.
Numbers in columns are right aligned. The game font has no weights, so
hierarchy comes from size and colour only. A bundled font is **not**
proposed; if wanted later it must ship its OFL licence and a Setting.

## 3. Window

**936 × 600** at window scale 100%. At UI scale 1.0 the game's screen is 768
units tall, so this fits a 1366 × 768 laptop with 84 units to spare top and
bottom; the existing window scale buttons (70–130%) stay.

```
x: 0      64                                           936
   ┌──────┬──────────────────────────────────────────────┐ 0
   │emblem│ header band: wordmark, tagline, fuse, close  │
   │      ├──────────────────────────────────────────────┤ 64
   │ rail │ toolbar band: page title + this tab's tools  │
   │      ├──────────────────────────────────────────────┤ 112 (hairline)
   │      │ content (24 px side insets, 16 top/bottom)    │ 128
   │      │                                              │
   │      ├──────────────────────────────────────────────┤ 572 (hairline)
   │      │ status line: tab summary · sync state        │
   └──────┴──────────────────────────────────────────────┘ 600
```

Content box: x 88–912 (824 wide), y 128–556 (428 tall).

- **Shadow:** only the window. 1 px hairline outline plus a soft shadow made
  of four stacked translucent rectangles behind the frame (no image needed).
- **Drag:** the header band is the drag handle (as now). ESC closes.

### Shell options (owner to choose)

- **A. Left rail (recommended).** 64 px rail with icon + label. Seven
  sections fit with room to spare; the toolbar keeps the full width.
- **B. Top tabs.** A 40 px tab band under the header. Seven tabs just fit at
  936 px, but the content loses 40 px of height (Overview cards shrink).

## 4. Header band

64 px, across the window right of the rail.
- Ground: vertical gradient `sky` → `bg`, plus a `brand` wash from the left at
  22% fading to 0 at 60% width. Two textures with `SetGradient`.
- Wordmark "Short Kings" (display 18, `text`) at 24/13; tagline (small 11,
  `textDim`) under it. Only `text` and `textDim` sit on the band (contrast).
- **Fuse:** a 1 px line along the bottom edge, ember from transparent to 75%,
  ending in a warning-yellow tip at 46% width.
- **Sparks:** three 2–3 px squares at the tip, `warning` with an ember glow
  (a second, larger square at low alpha). They flicker with an alpha
  `AnimationGroup` (loop, 0.9–1.6 s, different per spark). Off under
  *Reduce motion* and stopped while the window is hidden.
- **Close:** 24 px square ghost button 12 px from the corner, an X glyph in
  `textDim`; hover wash. (Replaces the round red Blizzard button, which
  clashes. Fallback: the Blizzard close button.)

## 5. Rail

64 px wide, `sidebar` ground, hairline on its right edge.
- Emblem cell at the top (the game's dynamite icon `INV_Misc_Bomb_04`, 36 px).
- Items 56 × 56 from y 76, 4 px apart: glyph 20 px, label small 11 below.
- States: rest `textDim`; hover wash 6% and `text`; **active** wash 9%,
  `accent` glyph and label, a 2 px `accent` bar on the rail's left edge.
- Order: Overview, Roster, Character, Crafters, (Raids v0.3), (Professions
  v0.4), Settings. Future sections appear only when built.

## 6. Toolbar band and status line

- **Toolbar band:** 48 px, `panel`, hairline below. Page title (title 15) at
  x 24, then the tab's controls from x 104–124, all 28 px tall at y 10. Right-
  aligned tools (Copy) end 24 px from the edge.
- **Status line:** 28 px, `sidebar`, hairline above, small 11 `textDim`. Left:
  this tab's summary (the old counter lines move here, e.g. "18 characters ·
  13 with data · 1 needs an update"). Right: sync state with its status shape
  ("■ Short Kings · sync on" / "sync paused: in combat").

## 7. Controls

| Control | Size | Rest | Hover | Other states |
|---|---|---|---|---|
| Button (default) | 28 tall, min 72 wide, 16 side padding | `panelAlt`, hairline, label 12 `text` | + 6% wash, hairline 20% | pressed 12% wash; disabled 50% alpha (still shows its tooltip) |
| Button (primary) | same | `accent` fill, `onAccent` label | lighter accent `#F591CF` | **one per screen** at most |
| Button (ghost) | same | no fill, hairline | 6% wash | used for links (Overview cards, Me, ‹ Roster) |
| Button (small) | 22 tall, 10 padding, small 11 | as default | as default | Whisper in rows, Grats |
| Icon button | 24 square, glyph 12 | no fill | 6% wash | close |
| Search box | 28 tall | `sidebar` fill, hairline, magnifier glyph at 9, placeholder `textMuted` | — | **focus:** hairline turns `accent` 80% |
| Menu | 28 tall | as button, chevron glyph at right | as button | pop-up 176 wide, `panel`, 26 px rows, 9 px separators, current choice marked by a 6 px accent square, hover 6% |
| Check box | 14 square | `sidebar`, hairline 22% | — | on: accent edge + 8 px accent square inside |
| Segments | 24 tall, 12 padding | hairline group, `textDim` | 6% wash | selected: 9% wash, `text`, 2 px accent bar under |
| Chip | 18 tall, 6 padding, small 11 | 1 px outline + text in one status colour | — | stale, not scanned, relayed, needs update, shared/private, nobody |
| Scroll bar | 6 px strip | 2 px thumb, white 28% | 4 px | min 24 tall |

Tooltips everywhere stay the **game's own** `GameTooltip` frame; we only
choose line colours (title `accent`, hints `textMuted`, actions `accent`).

## 8. Lists and rows

- List container: `panel`, hairline outline.
- Header row 24 px: label 12 `textDim`, the sorted column in `text` with ▾/▴,
  hairline under.
- Rows **22 px**, body 13, 8 px left padding. Zebra 2% white on even rows.
- Hover 6% wash. **Selected** 9% wash plus a 2 px `accent` bar on the left.
- Names in class colour; secondary cells (rank, profession, spec numbers) in
  `textDim`/`textMuted`.
- Online column: shape + word (see §11).
- Side panels (Crafters detail): `panel`, title 15 in item quality colour,
  sub line small `textDim`, rows 32 px with a small Whisper button.

## 9. Cards (Overview)

3 × 2 grid of **264 × 206**, 16 px gaps (fills the 824 × 428 content box
exactly). `panelAlt`, hairline, 16 px padding.
- Title 15 at the top.
- Optional **big number** (hero 26) with a small `textDim` caption under it.
  Only where a single number answers the card's question (Guild 47, Raids
  "37 days", Data health 9, Recipes 1,284).
- Detail lines label 12, `textDim` with values in `text`, right aligned.
- One **ghost** button at the bottom left (the deep link).
- Milestone rows 22 px with a small ghost "Grats" button at the right.

## 10. Character tab

- Name display 18 in class colour, info line body `textDim`, meta small
  `textMuted`.
- Paper doll on a `panel` 264 × 364: 36 px slots, 4 px apart, slot outline
  = item quality colour (subject colour), missing enchant = a 12 px `warning`
  square on the corner (shape, not just colour), plus the "2 missing
  enchants" line. Average item level hero 26 in the middle.
- Details in **two 264 px columns** (Alts, Notes, Talents, Cooldowns |
  Professions, Attunements, Reputation) so most profiles fit without
  scrolling. If a profile is taller, the right area scrolls as one.

## 11. Status, marks and chips (never colour alone)

| Meaning | Shape | Colour | Word |
|---|---|---|---|
| Online with Short Kings | filled 8 px square | `success` | "Online" |
| Online without the addon | hollow 8 px square (1.5 px edge) | `warning` | "Online" |
| On an alt | filled square | `success` | "on alt" |
| Offline | 8 × 2 dash | `textMuted` | "5h", "2d" |
| Attuned / not / unknown | game atlases `UI-LFG-ReadyMark`, `UI-LFG-DeclineMark`, `UI-LFG-PendingMark` | game | "yes" / "no" / "unknown" |
| Data state | chip | warning/muted | "stale", "not scanned", "relayed" |

All shapes are plain colour textures, no image files.

## 12. Empty and loading states

Centred in the area they replace: a 32 px glyph in `textMuted`, a title 15
line in `text` saying what this place is for, one body line in `textDim`
saying what to do next. Examples:
- Crafters before a search: "Find a crafter" / "Type at least 3 letters,
  e.g. "arcanite" or "enchant boots"."
- Milestones: "No milestones yet" / "Level-ups, profession milestones and
  attunements show here as your addon sees them."
- Character with no data: "No Short Kings data yet" / "They may not have the
  addon, or be on a trial account (trials can't sync)."

Loading (names still arriving from the server) keeps the row and shows
"loading…" in `textMuted`; no spinners.

## 13. Accessibility and contrast

Floors: **primary text ≥ 7:1, everything else ≥ 4.5:1** on every surface it
can sit on, including hover and selected rows. Checked by
`node docs/design/contrast.js` (fails the run if a floor breaks or the
mockup's colours drift from `tokens.json`; CI runs it).

Rules the check enforces: list states live on `panel`; on pressed buttons
and on the header band only `text` and `textDim` are allowed.

<!-- generated by: node docs/design/contrast.js --markdown -->
| ink | sidebar | bg | panel | panel+hover | panel+selected | panelAlt | panelAlt+pressed | sky | band (hot end) |
|---|---|---|---|---|---|---|---|---|---|
| text (≥7) | 17.7 | 17.0 | 16.2 | 13.9 | 12.7 | 15.0 | 10.4 | 12.4 | 9.4 |
| textDim (≥4.5) | 11.6 | 11.1 | 10.6 | 9.1 | 8.3 | 9.8 | 6.8 | 8.1 | 6.1 |
| textMuted (≥4.5) | 6.9 | 6.7 | 6.4 | 5.4 | 5.0 | 5.9 | – | 4.9 | – |
| accent (≥4.5) | 7.8 | 7.5 | 7.1 | 6.1 | 5.6 | 6.6 | – | 5.5 | – |
| success (≥4.5) | 11.1 | 10.7 | 10.2 | 8.7 | 8.0 | 9.4 | – | 7.8 | – |
| warning (≥4.5) | 11.7 | 11.2 | 10.7 | 9.2 | 8.4 | 9.9 | – | 8.2 | – |
| danger (≥4.5) | 7.0 | 6.7 | 6.4 | 5.5 | 5.0 | 5.9 | – | 4.9 | – |

- onAccent on accent: 7.7 (floor 7)
- accent selection bar / focus edge on panelAlt: 6.6 (non-text, floor 3)

The first pass of these tokens failed in four places (a 10% selected wash
and a 30% magenta band pulled muted, pink and red text under 4.5); the
washes were cut to 9%/12% and the band to 22%.

**Known exception, subject colours.** On `panel`, rare blue `#0070DD` (3.7),
epic purple `#A335EE` (3.6) and shaman blue (3.7) are under 4.5. They are
the game's own colours and players read them as names, so we keep them.
If guildmates find them hard to read in game, the fix is to lift only these
three by about 15% lightness inside our lists (tooltips stay untouched).

Other accessibility points: focus is visible (accent edge on the search
box); disabled buttons keep their explaining tooltip; nothing relies on
hover alone; Reduce motion is a real setting.

## 14. Icons

One family of **rail glyphs**: 24-unit grid, 2.25 stroke, square caps,
drawn white and tinted at runtime (Overview, Roster, Character, Crafters,
Settings; later Raids, Professions; plus search, chevron, copy, whisper,
refresh, close). The mockup draws them in SVG.

WoW can't draw a diagonal or curved line from colour textures alone, so
glyphs need **image files**: 32 × 32 white TGAs, generated by a script in the
repo from the same SVG paths (our own drawings, no one else's art). Today's
rule is "no image files", so this needs the owner's yes. Without it:
- the rail shows **labels only** (no glyphs), and
- the close button, menu chevron and search magnifier fall back to the game's
  own atlases/textures.

Item, class and emblem icons are the game's own textures.

## 15. Motion

Verified in Blizzard's Forever UI source (`forever` branch,
`SimpleAnimatableObjectAPIDocumentation.lua`, `SimpleAnimAPIDocumentation.lua`,
`SimpleAnimAlphaAPIDocumentation.lua`, `SimpleAnimTranslationAPIDocumentation.lua`):
`CreateAnimationGroup`, `Alpha:SetFromAlpha/SetToAlpha`,
`Translation:SetOffset`, `Anim:SetDuration`, `Anim:SetSmoothing`,
`SetStartDelay`.

| What | How | Time |
|---|---|---|
| Tab change | page fades in from 0 → 1 | 120 ms, smoothing OUT |
| Menu open | pop-up fades in | 120 ms |
| Window open | fade in | 120 ms |
| Header sparks | alpha loop per spark, bounce | 0.9–1.6 s |

No per-row animation and no `OnUpdate` scripts. **Reduce motion:** the sparks
stop (shown still), fades are skipped. New setting, default off, stored as
`settings.reduceMotion` in `Core/DB.lua`.

## 16. Pixel-perfect lines

Verified in the Forever source (`Blizzard_SharedXML/PixelUtil.lua`,
`SimpleTextureBaseAPIDocumentation.lua`): `PixelUtil.SetHeight/SetWidth/
SetSize/SetPoint` (with a minimum pixel count),
`PixelUtil.GetNearestPixelSize`, and `Texture:SetSnapToPixelGrid(false)` +
`SetTexelSnappingBias(0)` (as `NineSlice.lua` does). Hairlines are 1 physical
pixel via `PixelUtil.SetHeight(tex, 1, 1)`, re-applied on
`UI_SCALE_CHANGED` and when the window scale changes. Both are called only
through `Core/Compat.lua`, with a plain `SetHeight(1)` fallback.

## 17. WoW mapping (what each piece is built from)

| Piece | Built from |
|---|---|
| Grounds, washes, hairlines, status shapes, sparks, shadow | `Texture:SetColorTexture` |
| Header band | two textures with `SetGradient` |
| Text | `FontString`, game font, 1 px shadow |
| Buttons, rail items, segments, rows | `Button` with textures |
| Check box | `CheckButton` |
| Search | `EditBox` |
| Lists, detail columns | `ScrollFrame` (recycled rows, as now) |
| Scroll bar | `Slider` |
| Glyphs | 32 px TGA, `SetVertexColor` tint (needs approval, §14) |
| Close | our icon button (fallback `UIPanelCloseButton`) |

## 18. Phase B plan (after approval)

1. Tokens and widgets: new tokens in `UI/Theme.lua` (old names kept),
   new widgets in `UI/Widgets.lua`, Reduce motion setting, tests for token
   lookup, the contrast rule in Lua and reduce-motion behaviour.
2. Window shell: band, rail (or tabs), toolbar, status line, close.
3. One tab per commit: Overview, Roster, Character, Crafters, Settings,
   then the debug window, minimap tooltip and tooltip line.
4. After each: busted, luacheck, re-render, README pictures, CHANGELOG,
   TESTING ("does it look like the mockup?").
