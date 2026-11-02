# Prompt: Short Kings design refresh (a design system, then the UI)

Copy everything below the line into a new Claude Code chat on the
`forever-shortkings` repo. Best started **after the first in-game test round**
(PLAN.md section 10), so the refresh is built on code that works in game.

---

You're continuing work on **Short Kings**, a World of Warcraft: Forever guild
addon in this repo. This task is **design**: give the addon a polished,
consistent interface in the style of **Polestar** (another Forever addon),
but in our **pink** colours. Read `CLAUDE.md` first (rules, verified APIs),
then `PLAN.md` sections 7 and 10, `README.md` "What's inside", `UI/Theme.lua`,
`UI/Widgets.lua`, every `UI/*Tab.lua`, and `docs/mockups/ui-mockup.html`.

I'm not a developer and I'm usually on my phone. Explain in plain language,
keep replies short, show me pictures (mockups) before you change the addon,
and push back if something here is a bad idea. Don't claim anything works or
looks right in game until I've seen it there.

## 0. Use the design skills

I have **website-design skills** installed. Before designing anything, list
the skills available in this session and **load every design-related one**
(for example frontend design, UI/UX, design systems or accessibility skills).
Use them for:
- the design system document (hierarchy, spacing, type scale, colour roles,
  states, empty states, accessibility);
- the HTML mockups in `docs/mockups/` (they *are* web pages, so the skills
  apply directly);
- reviewing each tab before and after.

Then **translate** the result into WoW frames (section 3). Where a web
pattern can't be built in WoW, say so and pick the nearest thing that can.

## 1. The reference: Polestar (study it, don't copy it)

Polestar Guides (`github.com/fitzforge/polestar`, CurseForge "Polestar
Guides") is a Forever levelling-guide addon with an excellent interface.
Read its **`docs/DESIGN.md`** (on the `next` branch) and look at the README
screenshots (hub, guide window, lookup, dungeon journal).

**Licence:** Polestar is **GPL-3.0**; Short Kings is **MIT**. You may learn
from its *ideas* (principles, proportions, rules). **Do not copy its code,
generated media, glyphs, header art, wordmark or text**, and don't base
generated files on theirs. Credit Polestar as design inspiration in the README.

What makes Polestar look good (from its DESIGN.md, 2 Nov 2026):
- **One accent colour**, used only for what you can act on, where you are,
  and the one fact that decides a choice. Everything else is neutral.
- **Depth by tone, not shadows:** each surface is a step lighter (rail →
  window → panel → card). Only the window casts a shadow; panels, cards and
  buttons never glow.
- **1px hairline borders** snapped to the pixel; **square corners**.
- A fixed **spacing scale** (4, 8, 12, 16, 24, 32) and **shared lines**: every
  pane's header and tab band line up across the window.
- A strict **type scale**, nothing below 11px (hero 26, display 18, title 15,
  body 13, label 12, small 11), with a 1px text shadow.
- **Contrast floors:** primary text at least 7:1, everything else at least
  4.5:1, on every surface. Checked, not eyeballed.
- A **left rail** for sections, a **selection bar** (2px accent bar) on the one
  selected thing, hover = a faint white wash, selected = a slightly stronger wash.
- A distinctive **header band** (theirs: a starlit night sky) at the top of
  each window.
- One family of **icons drawn in code** (24-unit grid, tinted at runtime),
  "no Unicode stand-ins".
- Short, quiet **motion** (120–200 ms ease-out) and a **reduce motion** option.
- Calm **empty states** that tell you what to do next.

## 2. Short Kings in that style

Our identity stays: **"Small in stature. Big in loot."** A gnome with a
magenta beard and lit dynamite: warm, cheeky, a little fiery. Polestar is
calm night-and-gold; we're **plum-and-pink**, with **ember** kept for the
dynamite spark.

Starting palette (contrast already checked against every surface, see the
table; refine it, but keep the floors):

| Role | Token | Hex | Notes |
|---|---|---|---|
| Accent (Short Kings pink) | accent | `#F27BC4` | the ONE accent: active tab, selection bar, primary button, focus |
| Ink on accent | onAccent | `#1A0913` | 7.7:1 on the accent |
| Rail / sidebar | sidebar | `#140A11` | darkest |
| Window | bg | `#1C0E18` | |
| Raised panel | panel | `#24121F` | |
| Controls, cards | panelAlt | `#2E1828` | |
| Header band top | sky | `#4A1E3C` | titles only |
| Text | text | `#FBF2F7` | 15–18:1 |
| Secondary text | textDim | `#D8C2CF` | 8–12:1 |
| Muted text | textMuted | `#AE93A3` | 4.9–6.9:1 |
| Success | success | `#6BD999` | online with addon, attuned, ready |
| Warning | warning | `#FABF4D` | online without addon, stale data |
| Danger | danger | `#F57373` | not attuned, nobody has it |
| Brand magenta | brand | `#D94FA0` | wordmark and header band only |
| Ember (spark) | ember | `#FF7A1A` | the dynamite spark motif only, never for text |

Contrast of the starting palette (text on each surface, ratio : 1):

| | sidebar | bg | panel | panelAlt | sky |
|---|---|---|---|---|---|
| text | 17.7 | 17.0 | 16.2 | 15.0 | 12.4 |
| textDim | 11.6 | 11.1 | 10.6 | 9.8 | 8.1 |
| textMuted | 6.9 | 6.7 | 6.4 | 5.9 | 4.9 |
| accent | 7.8 | 7.5 | 7.1 | 6.6 | 5.5 |
| success | 11.1 | 10.7 | 10.2 | 9.4 | 7.8 |
| warning | 11.7 | 11.2 | 10.7 | 9.9 | 8.2 |
| danger | 7.0 | 6.7 | 6.4 | 5.9 | 4.9 |

Ideas to explore (mine, not Polestar's):
- **Header band:** plum-to-magenta with a few ember sparks along a fuse line
  instead of stars (this is where the planned "ember animation" lives; keep
  it subtle and off under reduce motion).
- **Left rail** with icons: Overview, Roster, Character, Crafters, Settings,
  with room for Raids and Professions later. Seven top tabs won't fit; a
  rail will.
- **Overview cards** in the new style: square, panelAlt ground, hairline,
  a title, one big number where it helps, and a ghost button.
- Class colours, item quality colours and status dots stay as the game uses
  them (they're "subject colours": they name things).
- Status should never rely on colour alone (we already use tick/cross
  atlases for attunement; do the same for online status).

## 3. WoW constraints (check every one against the Forever source)

- We build with core frames only: `Frame`, `Button`, `Texture`, `FontString`,
  `EditBox`, `ScrollFrame`, `Slider`, `CheckButton`. No Blizzard templates
  except the close button. No CSS: gradients via `SetGradient`, borders as
  thin textures (as `Theme.Border` does now).
- **Pixel-perfect hairlines:** check what Forever offers for pixel snapping
  (e.g. `PixelUtil`, `SetSnapToPixelGrid`, `SetTexelSnappingBias`) in
  Blizzard's Forever UI source before relying on it.
- **Motion:** `AnimationGroup` (alpha/translation) only; no per-row
  `OnUpdate`. Verify the animation API in the Forever source.
- **Fonts:** the default stays **the game's font** (it localises and feels
  native). An optional bundled font (e.g. Inter or Marcellus, both SIL OFL)
  is allowed only with its licence file in the addon and a Setting to switch.
- **Images:** today the rule is "colours and gradients only, no image files".
  A small set of icons, the header band and a window shadow may need
  textures (power-of-two TGA/BLP). If you want them, **ask me first**, and
  generate them from a script in the repo (like `docs/mockups/render.js`),
  not by hand and not from anyone else's art. Then update the rule in
  CLAUDE.md.
- **Window size:** today 860×560 at any UI scale. Propose a size that fits a
  1366×768 laptop at 100% UI scale; keep the window scale setting.
- **Readability:** nothing below 11px, contrast floors above, text shadow on.
- Keep `Core/Compat.lua` as the only file calling client APIs.

## 4. How to work (in this order, with my approval between phases)

### Phase A: design system and mockups (no addon code changes)
1. Write **`docs/DESIGN.md`**: principles, tokens (colours, spacing, type),
   surfaces, borders, header band, rail, tabs, buttons (default, primary,
   ghost, disabled), inputs, menus, lists and rows, cards, chips, tooltips,
   states (hover, selected, focus, disabled, empty, loading), icons, motion,
   accessibility and the contrast table. Include a small script that checks
   the contrast table (tests or `docs/mockups/`).
2. Redraw **every screen** in `docs/mockups/ui-mockup.html` in the new system:
   Overview, Roster (and raid view), Character, Crafters, Settings, the debug
   / copy window, the minimap button, and one item tooltip with the "Short
   Kings:" line. Add **two options for the window shell** (left rail vs top
   tabs) side by side so I can choose.
3. Render them (`node docs/mockups/render.js <marcellus.woff2>`) and send me
   the pictures. **Stop and wait for my decision.**

### Phase B: build it in slices (each with tests, lint and docs)
1. **Tokens and widgets:** `UI/Theme.lua` gets the new tokens (keep the old
   names working until every file is moved over); `UI/Widgets.lua` gets the
   new button, tab/rail, check, menu, search box, list rows, card, chip and
   empty state. Add a **Reduce motion** setting.
2. **Window shell:** header band, rail (or tabs), status line, close button.
3. **One tab per commit:** Overview, Roster, Character, Crafters, Settings,
   then the debug/copy window, minimap button and tooltip line.
4. After each slice: `busted --lua=lua5.1`, `luacheck .`, update the
   mockups and re-render, update README pictures and "What's inside",
   CHANGELOG and TESTING (add "does it look like the mockup?" checks).

## 5. Rules for this task
- **No behaviour changes.** Every feature, setting, button and tooltip in the
  README keeps working. If a redesign would drop something, ask me.
- Don't touch sync, collection or saved data, except new UI settings (with
  defaults in `Core/DB.lua`).
- Don't copy Polestar (GPL-3.0) code, art or text. Credit it as inspiration.
- Keep the guild's colours: plum and pink first, ember as a spark.
- The UI smoke tests must still build every tab; add tests for anything with
  logic (token lookup, contrast check, reduce-motion behaviour).

## Definition of done
- `docs/DESIGN.md` exists and the mockups match it.
- I approved the mockups before the Lua work started.
- `busted --lua=lua5.1` and `luacheck .` pass locally and in CI.
- README pictures, "What's inside", CHANGELOG, TESTING and CLAUDE.md are updated.
- Pushed to your designated branch, with no PR unless I ask.
- Finish with a plain-language summary, the before/after pictures, and what I
  should look at in game.
