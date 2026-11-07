# Changelog

## v0.3.5 (7 Nov 2026)

- **Overview: the full list of who doesn't have Short Royalty.** "and 4 more"
  wasn't much use. Now point at **Don't have it yet** (or the names under it)
  and a tooltip lists everyone, two names per line, online first. Very large
  lists stop at 60 names; **Without addon** shows the rest in the Roster.
- Releases now publish themselves: once a new version is on `main`, GitHub
  builds the zip, makes the release and uploads it to CurseForge.

## v0.3.4 (7 Nov 2026): one crafter's recipes, who has the addon, profession reminder

- **Hard-to-miss profession reminder.** Until you've opened each of your
  crafting profession windows once, an orange bar sits under the tabs on
  every tab ("Your guild can't see your recipes yet. Open your Alchemy and
  Tailoring windows once.") with a gold **Open Alchemy** button that opens
  the window for you. It moves on to the next profession, and goes away by
  itself when they're all done. The button is off in combat. No bar if you
  chose not to share recipes. The login chat line now points to it.
- **Professions: click a crafter to see their recipes.** In one profession
  (say Tailoring), clicking a name used to jump to the Character tab. Now it
  shows only that person's recipes on the right, with their name and skill
  above. **Only they know** lists the recipes nobody else in the guild has.
  A **Character** button opens their character sheet; **Everyone** (or
  clicking the name again) shows the whole guild's recipes again. An empty
  list says why (private recipes, or the window never opened with the addon).
- **Overview: who has Short Royalty.** The Guild section now says how many
  members **have Short Royalty** and how many **don't have it yet**, and lists
  the first ten who don't (online first, with a dot, so you can ask them
  now). **Without addon** opens the Roster with all of them on top. "Have it"
  means we've heard from them or have their data; trial accounts can't send,
  so they count as not having it.
- "Online now" also says how many of those online run the addon. Data health
  now flags members who **have the addon but whose data hasn't reached you**
  (the case to report), instead of repeating the "don't have it" count.
- Roster: the Version column sorts members without the addon first; hovering
  someone without data says whether they have the addon or not.
- Getting started's "Get guildmates to install it" counts everyone who has
  it, not just who's online right now.

## v0.3.3 (7 Nov 2026): guildmates can see each other

**Everyone has to update.** v0.3.3 can't exchange data with v0.3.2 or
earlier (its messages are packaged differently), and `/sr debug` says so if a
guildmate is still on an old version.

- **Fixed: nobody could see anyone else's data.** In the first test between
  two players (7 Nov), every profile arrived broken ("bad compression") and was
  thrown away. Small messages worked, so the Roster showed people, but never
  their gear, talents or recipes. Big messages were split by the message
  library (AceComm), and those split messages didn't survive the trip between
  two players. Tests in game proved the chat itself is fine: every single
  message arrived complete and in order. So Short Royalty now splits big
  messages **itself** into numbered pieces, each a complete message of its own,
  and rebuilds them by number in whatever order they arrive.
- If a piece ever goes missing, `/sr debug` now names the sender and the
  missing piece ("Last incomplete message: from Aura Guardian: 4 of 5 pieces
  (missing 3)"), instead of the vague "bad compression".
- `/sr debug` also counts pieces received, messages waiting, ones given up on,
  duplicates and malformed pieces.
## v0.3.2 (7 Nov 2026): every recipe, search, Getting started, CurseForge

- **Every recipe in the game.** Professions → **All recipes** lists all
  ~2,250 profession recipes in Forever, learned or not. Search by name, by
  the profession window's group ("camping") or by a material ("thorium bar"
  shows everything that uses it), or pick a profession to see them all. The
  list comes from the game's own data for the Forever build (via
  wago.tools); names come from your game.
- **Nobody knows** on each profession now lists every recipe nobody in the
  guild has learned, not only what your own window showed.
- **Reagents everywhere:** shown even with the profession window closed and
  for recipes nobody knows.
- **Wowhead link** for any recipe (Crafters panel), to copy into your browser.
- **Getting started** checklist on the Overview for new players, and a
  welcome line the first time Short Royalty loads.
- **On CurseForge** from this version (project 1788068).
- Fix: item names the game can't load are no longer asked for again and
  again (they could slow down searches).

## v0.3.1 (7 Nov 2026): Short Royalty

The guild is now **Short Royalty**, and so is the addon. Works alongside
guildmates on **this version only**: the sync channel was renamed too,
so earlier test builds (`ShortKings`) and this one don't see each other.

- **New name everywhere you can read it:** the window title, the AddOns
  list, chat messages, tooltips, the minimap button, `/sk debug`, README and
  pictures.
- **Saved data follows future guild renames.** Guild data is stored under
  the guild's name, so a rename would start everyone from an empty roster.
  Now, when most of an old guild's members are in your new roster, its data
  moves over automatically. A different guild's data is never taken.
- Slash commands: **`/sr`** and **`/shortroyalty`** (`/sk` still works).
- **The addon folder is now `ShortRoyalty`** and the download is
  **`ShortRoyalty-vX.Y.Z-forever.zip`**. If you tried an earlier test build,
  **delete the old `ShortKings` folder** from AddOns. Its saved settings don't
  carry over (nobody had real data yet), and it can't sync with this version.

## v0.3.0 (6 Nov 2026): Professions

A new **Professions** tab, after Crafters. Works alongside guildmates on
v0.2.5 and later (no new message types).

- **Guild board:** every profession, crafting first, then gathering, then
  secondary, including the ones nobody has. Characters, how many at 300,
  online now, top skill, when recipes were last recorded, and
  specialisations. Click a row to open that profession.
- **One profession:** its crafters (status, alt of, skill, specialisation,
  how old their recipe list is, orange after a week, Whisper) and its
  recipes with crafter counts. Filters: All, Only one crafter, Favourites,
  and Nobody knows (only when the game's window lists unlearned recipes).
  Click a recipe to open it in Crafters.
- **Cooldown board:** everyone's profession cooldowns, ready first, with
  how long ago we last heard from that player (orange after a day).
- **Specialisations** from the original game (Engineering, Leatherworking,
  Blacksmithing), read from your spellbook. A spell only counts when the
  game's own name for it matches, so nobody gets a wrong label. Shared as a
  small new field that older versions simply ignore.
- **Reagents** in the Crafters panel and recipe tooltips, with how many you
  have in your bags. Read from your own game and kept on your computer;
  never sent.
- **Favourites:** right-click a recipe or crafter to star it. A Favourites
  filter in Crafters and Professions. Saved on your computer only.
- **Gathering professions can have recipes** in Forever (Herbalism's
  camping items, for example), so they're recorded, searchable and listed
  like any other profession.
- **Title font fix:** the Chakra Petch titles could fall back to the game
  font (seen in an in-game report). The font is now loaded with the addon,
  and `/sk debug` says how many texts got it.
- **Reminder to reopen a profession window** when your skill has gone up 15
  or more since you last opened it: on the tab, and in chat at most once
  every three days. Can be turned off in Settings.

## v0.2.7 (5 Nov 2026): profession checks

Nothing changes in how the addon works. `/sk debug` gets a new block,
**"Profession checks for v0.3"**, that records what the game shows before
the Professions tab is built:

- whether the profession window lists recipes you haven't learned (and
  whether its "show unlearned" filter is on);
- the window's recipe categories by name, with a few examples each (to see
  how Forever's Blueprints and camp objects appear);
- the reagents the game reports for a recipe you know and one you don't,
  with the window open and closed;
- whether you know each original-game specialisation (Gnomish/Goblin,
  Dragonscale/Elemental/Tribal, Armorsmith/Weaponsmith and the master
  smiths), and the game's own name for each spell ID.

## v0.2.6 (5 Nov 2026): hotfix

- **False "send errors" fixed.** v0.2.5 counted every *successful* send as an
  error (the message libraries report "sent: true", not Blizzard's result
  number), so after 5 sends it would have shown "Sending to guildmates is
  failing". Messages were going out fine; only the counting was wrong.
  Seen in the owner's `/sk debug` ("Send errors: 3, last: true").

## v0.2.5 (5 Nov 2026): launch-day fixes and security fixes

**Launch-day fixes** from the first in-game test (5 Nov 2026, build 70790):

- **Sync was switched off by mistake.** Blizzard's "addon chat restricted"
  check says *restricted* on normal Forever realms (Blizzard only uses it for
  an esports tool), so v0.2.2–v0.2.4 never sent anything. A real test send to
  the guild worked, so Short Kings now only blocks trial accounts and trusts
  each send's own result instead. If sends keep failing, it says so once in
  chat, and `/sk debug` shows the error.
- **Missing-enchant warnings only at max level (60).** Levelling gear is no
  longer flagged.
- Confirmed in game: interface 16001, your character's ID stays the same
  between logins, and addon messages name the sender "First Surname" (the
  same as the guild roster).

**Security fixes** from a security review (`docs/SECURITY-REVIEW.md`). Works
alongside guildmates on v0.2.2 to v0.2.4: the protocol is unchanged, this
version is just stricter about what it accepts.

- **One bad profile can no longer break the addon for the guild.** Every
  field of an incoming profile is checked (types, sizes, counts); anything
  malformed is refused instead of saved and passed on.
- **No impersonation by first name.** A whisper whose sender only matches a
  member by first name is accepted only once that sender has been seen on
  the guild channel this session.
- **No zip bombs.** Messages from people who can't be guild members, or on
  channels we never use, are dropped before decoding; anything that
  decompresses to over 256 KB is refused; after 3 bad messages a sender is
  ignored until `/reload`.
- **No made-up chat text.** The "newer version" notice and the Version
  column only show real version numbers from verified members.
- Gear entries must be a single item link; profession names are plain text
  in the pre-typed "Grats" message; the rate-limit table forgets idle senders.
- `/sk debug` shows whether your own data passes guildmates' check, and how
  many senders were ignored.
- Build: GitHub Actions pinned to exact commits, LibDataBroker pinned to a
  commit, and the test workflow has a read-only token.

## v0.2.4 (3 Nov 2026): new tagline

- New tagline: **Height is not a stat.** (in the title bar, the minimap
  tooltip and the AddOns list). Nothing else changed since v0.2.3; still
  not run in game yet.

## v0.2.3 (3 Nov 2026): the new look

A new look for every window. Nothing about sync, saved data or features
changed, so it works alongside guildmates still on v0.2.2. **It hasn't been
run in game yet:** if anything looks wrong, send the `/sk debug` text (and a
screenshot if you can). Settings → **Reduce motion** turns the animations off.

- **Black and gold.** True black surfaces, gold for the active tab, the one
  main button on a screen and key numbers; the gnome's **pink beard** for
  whatever you pick (selected rows, filters, check boxes) and the new crest;
  **dynamite orange only for alerts and sync status** (old data, missing
  enchants, updates, the sync dot). No gradients.
- **One theme file.** `UI/Theme.lua` holds every colour (0–1 RGBA), font,
  size, spacing step, border and motion timing; a test fails if a colour is
  hard-coded anywhere else.
- **Type.** Chakra Petch (free, SIL OFL, bundled) for the title, tabs and
  section headings; the game's Arial Narrow for everything else, with the
  same Korean, Chinese and Russian fallbacks Blizzard uses, so names in any
  alphabet show. If the bundled font can't load, the game font is used and
  `/sk debug` says so.
- **Overview** is now three columns set like a spec sheet instead of six
  equal boxes; the raid countdown is the one big number.
- **Character** details are sections in two columns (talents, professions,
  cooldowns / attunements, reputation) instead of one long text block.
- **Lists:** quiet headers with a sort arrow, right-aligned numbers, a dash
  for missing values, round status dots, row hover, and a sentence when a
  list is empty ("Nobody matches …", "You're not in a guild …").
- **Crafters:** loading placeholders while item names arrive; long item
  names wrap instead of being cut off; the side panel keeps its frame and
  explains itself when nothing is picked.
- **Motion** (AnimationGroups only, 80–180 ms): the window fades and grows
  in, the gold underline glides between tabs, rows highlight on hover, menus
  drop from their button, and the sync dot sends out a ring when new data
  arrives (at most every 8 s). Clicking again mid-animation carries on from
  where it was instead of starting over. Opening with `/sk` or closing with
  Esc stays instant. New setting: **Reduce motion**.
- **Hit areas:** small buttons (Grats, Whisper, chips, check boxes with
  their labels) have click areas of at least 24 px.
- **Fits the screen:** the window shrinks itself if your UI scale and screen
  size would push it off the edge.
- Title bar: crest, sync status with a dot, and a Lua-error count when
  something went wrong (hover for what to do). Own close button.
- `preview/index.html`: a browser mock-up of every window with full, empty,
  loading, error and worst-case data, plus a before/after view.
- Fixed while stress-testing: "1 characters"-style plurals; the status dot
  could drift left when the status text was cut off; the Settings window-size
  buttons ran into the status column.

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
