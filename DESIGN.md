# Short Kings design system

The look of the in-game addon. Every value here lives in `UI/Theme.lua`;
this file says why. Started from the Lamborghini-inspired reference in
`docs/design/lamborghini-reference.md` (true black, gold, uppercase display
type) and blended with the guild's mascot: a gnome with a pink beard and
lit dynamite.

## Mode
Operate. People open the window to find a person, a crafter or a number in
a few seconds. Familiar patterns (tabs, lists, check boxes) stay familiar;
the brand lives in colour, type and a few precise details.

## Colour roles
| Role | Value | Used for | Never for |
|---|---|---|---|
| void | `#000000` at 96 % | window ground | |
| surface / raised / pressed | `#111111` / `#1C1C1C` / `#0A0A0A` | panels, hover, press | |
| rule / line / lineStrong | `#161616` / `#2A2A2A` / `#444444` | row rules, dividers, control borders | boxes around everything |
| text / dim / faint | `#F5F5F5` / `#A6A6A6` / `#707070` | names and key numbers / labels and meta / disabled and missing | |
| **gold** | `#FFC000` (lit `#FFCE3E`, deep `#917300`) | where you are (tab underline, focused search), the one primary button per screen, the one big figure | decoration, headings |
| **beard** | `#F06BB0` | what you picked: selected rows (16 % tint), chips, check boxes, "(you)", the crest | warnings |
| **spark** | `#FF6A1A` | alerts (old data, missing enchant, update available, errors) and the sync dot | anything else |
| good / bad | `#4CC38A` / `#E5484D` | attuned yes/no, ready, shared, "nobody" | |

Class colours and item-quality colours are the game's and are left alone.
No gradients, no glows. Depth is a tone step.

## Type
- **Display: Chakra Petch SemiBold** (SIL OFL, bundled), uppercase: the
  title (20), tabs (13), section headings (13), the one big figure (24).
  Its cut corners echo the reference's angled lettering and gnome
  engineering. Never for names or player text (no Cyrillic or CJK).
- **Body: Arial Narrow** (ships with the game) via `Media/Fonts.xml` font
  families with Blizzard's Korean, Chinese and Russian fallbacks: 13 body,
  12 small, 11 micro, 15 item title, 20 character name. Nothing under 11.
- WoW has no letter-spacing, so uppercase is kept to short words.

## Space and size
4-point scale: 2, 4, 8, 12, 16, 20, 32. Window 880 × 580, 16 margin,
title bar 52, tab bar 32. Rows 22 (row rules, no zebra), headers 24,
key/value rows 18, controls 24 (20 inside rows), every click area at least
24. Numbers right-aligned; a missing value is a dim dash.

## Components
Ghost button (outline), primary button (gold, black text), quiet link
(dim text, gold on hover), chip (beard when picked), check box (beard
fill), menu (drops from its button), search box (gold border when typing,
clear ×), list (quiet sentence-case header, sort arrow on the sorted column
only), block (uppercase heading, rule, key/value rows), sheet (scrolling
blocks). Every list and panel has an empty sentence that says why and what
to do; Crafters has loading bars; errors show in the title bar.

## Motion
AnimationGroups only; quadratic ease-out (WoW has no custom curves).
Window in 180 ms (fade + 97 → 100 % scale, centred), out 120 ms (fade);
tab underline glides 150 ms (in-out) and the page itself appears at once
(tabs are clicked too often for a fade); row hover fades in 80 ms and
vanishes at once; menus 150 ms from their button; sync ring 400 ms, at most
every 8 s. Interrupted animations continue from where they are. Keyboard
opens (`/sk`, Esc) are instant. **Reduce motion** turns everything off (the
owner asked for off, not gentler).

## Textures
`tools/textures.js` draws them; all power-of-two `.tga`: crest 64, arrow 16,
close 16, dot 16, ring 32. White glyphs are tinted in game.
