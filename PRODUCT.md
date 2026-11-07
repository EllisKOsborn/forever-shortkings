# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

(Closest value. The real surface is an in-game World of Warcraft: Forever
addon built from Lua frames, textures and FontStrings. The only web surface
is `preview/index.html`, a mock-up of the in-game windows.)

## Stack
WoW Forever client 1.60.1 (`## Interface: 16001`, Mainline 12.x UI).
Lua 5.1 frames, no Blizzard templates except the close button. All colours,
fonts, sizes and spacing live in `UI/Theme.lua`. Tests: busted against a
stubbed WoW API (`tests/helpers/wow.lua`).

## Users
About 50 members of the guild Short Royalty (Alliance, PvE). Primary user:
**everyone, casually** (confirmed 3 Nov 2026): members opening the window
in town or between pulls to look up a guildmate's gear, find who can craft
an item, or check who's online. Speed of finding a name matters most.
Officers and raid leads use the same screens for attunement checks.

## Product Purpose
Browse each other's gear, talents, professions, recipes, attunements and
reputations in game. Data is shared only over the guild addon channel.
Success: a member finds the person or crafter they want in a few seconds.

## Positioning
Built for one guild, with its own name, joke and mascot; data stays in the
game (no website, no uploads).

## Operating Context
Opened from a minimap button or `/sk` alongside the default WoW UI and
other addons (ElvUI, Bagnon, DBM and so on). Often used at small UI scales
and on laptops; sometimes opened in combat (sync pauses then).

## Capabilities and Constraints
- Windows: main window (Overview, Roster, Character, Crafters, Settings),
  a copy/debug window, minimap button, item-tooltip line.
- Only fonts that ship with the game or the addon render. Textures must be
  .tga/.blp, power-of-two sizes.
- Motion only through AnimationGroups (alpha, translation, scale, rotation).
- SavedVariables (`ShortRoyaltyDB`) must stay compatible.

## Brand Commitments
- Name **Short Royalty**, tagline "Height is not a stat." (chosen 3 Nov 2026; replaced "Small in stature. Big in loot.")
- Mascot: a gnome with a **pink beard** holding **lit dynamite**.
- No real crest artwork exists; a simple shape-drawn crest is fine
  (confirmed 3 Nov 2026). Never fabricate mascot art.
- Owner's chosen palette direction: true black and gold (Lamborghini
  DESIGN.md reference), pink beard as a secondary accent, dynamite-spark
  orange reserved for alerts and sync status.
- A bundled free OFL display font for titles only is approved; body text
  stays in the game font.

## Evidence on Hand
Mock-ups and screenshots of the previous look: `docs/mockups/`,
`docs/images/`. No guild artwork, no screenshots from the live client yet.

## Product Principles
1. Find a person fast: names and status first, detail on demand.
2. Honest data: always say how old data is and why it might be missing.
3. Privacy by default: notes never synced, share toggles respected.
4. Feel like part of WoW, not a web page pasted on top.
5. Never get in the way in combat.

## Accessibility & Inclusion
Readable at small UI scales; colour is never the only signal (status dots
carry text in tooltips); a Reduce motion setting turns animation off.
