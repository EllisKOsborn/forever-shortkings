# Changelog

## v0.2.2 (2 Nov 2026): first release, for launch day

The first downloadable release, and the version the guild starts with when
Forever launches on 4 Nov. It includes everything below (v0.1.0 to v0.2.1
were never released separately). **It hasn't been run in game yet:** it's
built against Blizzard's Forever 1.60.1 interface code and tested with a
simulated client. Please report problems with the `/sk debug` text.

New in this version:


- New **Overview** tab, first in the window: the guild at a glance in six
  cards, each with a button to the place where you can act on it.
  - **Guild**: members, roughly how many players, online, online with Short
    Kings, shared data, and levels by band.
  - **Raids**: days until 9 Dec; Barrow Deeps and Hyjal (no attunement,
    level 60 count); Onyxia attuned / not / unknown and amulets not in bags.
  - **Data health**: no data, older than a week, profession windows not
    opened, old addon versions.
  - **Professions**: characters per crafting profession, how many at 300,
    professions nobody has, gathering counts.
  - **Recipes**: total, crafters, and recipes only one character knows.
  - **Recent milestones**: level-ups, profession 75/150/225/300, Onyxia
    attunement and new recipes, with a **Grats** button that pre-fills guild
    chat. Worked out locally, kept on your computer only (last 50), never sent.
- The window opens on the Overview once, then remembers your last tab.
- Setting: **Record guild milestones (Overview)**.
- Roster: *Oldest first* view (used by the Data health card).
- Fixed: buttons are explicitly enabled when created (the test stub could
  treat a never-enabled button as disabled).

## v0.2.1 (included in v0.2.2)

Launch readiness, after reviewing the GPT, Manus and Perplexity plans
(`docs/PLAN-REVIEW.md`).

- **Attunements match Forever's first raid wave** (Blizzard's raid overview):
  Barrow Deeps and Hyjal Summit need **no attunement**; Onyxia's Lair needs
  the Drakefire Amulet quest **and** the amulet in your bags. Members with the
  quest done but the amulet banked get an orange "!" and "Drakefire Amulet not
  in bags". Molten Core, Blackwing Lair and Naxxramas are hidden until they're
  announced. The raid picker shows raid sizes.
- **`/sk debug` for launch day:** a "Live-client checks" block at the top
  (interface number, whether your character's GUID stays the same between
  logins, the addon-message sender format, whether the profession window
  lists unlearned recipes, whether the calendar works, error count), and the
  **last 10 Lua errors** caught in Short Kings code, so problems show up even
  without an error addon. One failing part no longer stops the rest.
- **Sync safety:** messages over 32 KB are refused before unpacking (a large
  crafter profile is about 11 KB), oversized messages are never sent, and
  each guildmate is limited to 60 messages a minute.
- **Sharing preview** in Settings: "What guildmates see from you", built from
  the same public copy that is sent, plus what is never shared and a reminder
  that copies already sent stay until replaced.
- **Old data is labelled:** data more than a week old shows in orange in the
  Roster's Data column, with "may be out of date" in the tooltip and on the
  Character tab. Crafters tooltips say when a crafter's recipes were recorded.
- **Copy as text** (for Discord): a **Copy** button on the Roster (the list
  as shown, including the raid view) and on the Crafters side panel. Plain
  text, no colour codes; notes are never included, and your own gear and
  talents are left out if you don't share them.
- The Roster counter says when a newer Short Kings is out ("Short Kings 0.2.2
  is out (you have 0.2.1)").
- Mockups updated (Copy buttons, raid sizes, Settings preview and the
  tooltip setting that was missing from the v0.2.0 picture).

## v0.2.0 (included in v0.2.2)

- New **Crafters** tab: search an item or recipe name (3+ letters), see one
  row per recipe with icon, quality-coloured name, profession and
  "N crafters (N online)". Click a result for the crafters, online first,
  with skill level, "alt of X" or "on <alt>", and a **Whisper** button.
  **Post to guild chat** pre-fills the chat box; you press Enter.
- **"Crafted by" on item tooltips**: "Short Kings: Bramble (online), Dabble
  +2 more". Setting: *Show guild crafters in item tooltips* (on by default).
- `/sk debug` reports the crafter index, the tooltip hook and name loading,
  and probes every new API.

## v0.1.2 (included in v0.2.2)

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

## v0.1.1 (included in v0.2.2)

- Roster: **status dots** (online with addon / without / offline), a **Ver**
  column with "needs an update", **alts grouped under their main**, public
  and officer **notes** in tooltips and search.
- Character: **missing-enchant markers**, an alts list, notes, and a
  **Make this my main** button.
- **Cooldowns** stay accurate without opening the profession window.
- **Privacy**: choose whether to share your gear/talents and your recipes.

## v0.1.0 (included in v0.2.2)

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
