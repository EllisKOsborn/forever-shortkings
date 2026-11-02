# Changelog

## v0.1.2 (unreleased, not yet tested in game)

- Roster: a **Raid** picker (*All raids*, Onyxia's Lair, Molten Core,
  Blackwing Lair, Barrow Deeps, Hyjal Summit, Naxxramas). With a raid picked:
  an **Attuned** column (yes / no / unknown), **All / Attuned / Not attuned /
  Unknown** filter buttons, a counter ("23 attuned · 9 not · 6 unknown"), a
  **Max level only** box (on by default), one row per character, and
  "alt of X" in the tooltip. The choice is remembered.
- Character: **Ask for latest** asks the character (or their online alt)
  for fresh data. Works only while they're online with Short Kings, at most
  once every 30 s. The answering player's addon re-reads their character first.
- **Faster updates:** your changes are announced 30 s after they happen
  (was 60 s).
- Fixed "Updated now ago" on the Character tab (now "Updated just now").

## v0.1.1 (unreleased, not yet tested in game)

- Roster: **status dots** (online with addon / without / offline), a **Ver**
  column with "needs an update", **alts grouped under their main**, public
  and officer **notes** in tooltips and search.
- Character: **missing-enchant markers**, an alts list, notes, and a
  **Make this my main** button.
- **Cooldowns** stay accurate without opening the profession window.
- **Privacy**: choose whether to share your gear/talents and your recipes.

## v0.1.0 (unreleased, not yet tested in game)

- Collects, for every character you log in on: name, class, race, level,
  guild rank, talents (points per tree plus each talent), equipped gear with
  item links, average item level, professions and skill levels, known recipes
  (scanned when you open a profession window), profession cooldowns,
  reputations and attunements.
- Shares that data with guildmates who also have the addon
  (hash-then-fetch over the guild addon channel).
- Window (`/sk` or the minimap button) with **Roster**, **Character** and
  **Settings** tabs, in the Short Kings plum, magenta and ember colours.
- `/sk debug` gives a copyable report of what the addon can see on your client.
