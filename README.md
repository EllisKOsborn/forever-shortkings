<p align="center">
  <img src="docs/images/banner.png" alt="Short Royalty: Height is not a stat." width="100%">
</p>

<p align="center">
  <a href="https://github.com/EllisKOsborn/forever-shortkings/actions/workflows/ci.yml"><img alt="Tests" src="https://github.com/EllisKOsborn/forever-shortkings/actions/workflows/ci.yml/badge.svg?branch=main"></a>
  <img alt="WoW Forever 1.60.1" src="https://img.shields.io/badge/WoW%20Forever-1.60.1%20%C2%B7%2016001-FFC000?labelColor=000000">
  <img alt="Version" src="https://img.shields.io/badge/version-0.3.0%20alpha-F06BB0?labelColor=000000">
  <img alt="Licence MIT" src="https://img.shields.io/badge/licence-MIT-FF6A1A?labelColor=000000">
</p>

<p align="center">
  <b>The guild addon for the Short Royalty of World of Warcraft: Forever.</b><br>
  Everyone's gear, talents, professions, recipes and raid readiness in one window.<br>
  No website, no server, no uploads: it all travels over the guild's addon channel.
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#whats-inside">What's inside</a> ·
  <a href="#commands">Commands</a> ·
  <a href="#faq">FAQ</a> ·
  <a href="#roadmap">Roadmap</a> ·
  <a href="#the-look">The look</a>
</p>

> [!NOTE]
> **Not run in game yet.** Short Royalty is built against Blizzard's own Forever
> 1.60.1 interface code and tested against a simulated WoW client. The
> pictures here are drawn by the [browser preview](preview/index.html) from
> the addon's real colours, fonts and layout. Item icons are placeholders;
> in game you see the real ones.

---

<a id="whats-inside"></a>

## 🧨 What's inside

| | What you get |
|---|---|
| 🏰 **Overview** | The guild at a glance: who's around, raid readiness, data health, professions, recipes and recent milestones |
| 👥 **Roster** | The whole guild in one sortable, searchable list, with alts folded under mains and a raid-attunement view |
| 🛡️ **Character** | Anyone's gear, talents, professions, cooldowns, attunements and reputations |
| ⚒️ **Crafters** | Search an item or recipe and see who in the guild can make it, online first, with its reagents and your bag counts |
| 🧪 **Professions** | Every profession in the guild, each profession's crafters and recipes, everyone's cooldowns, specialisations and favourites |
| ⚙️ **Settings** | Sharing and privacy switches, display options, window size, tools and a live status read-out |
| 🧨 **Everywhere** | `/sr`, a minimap button, "Crafted by" lines on item tooltips, chat reminders and a copyable debug report |

### 🏰 Overview
<p align="center"><img src="docs/images/overview.png" alt="Overview tab" width="100%"></p>

The first tab: six sections in three columns, set like a spec sheet. Each
section has a link to the place where you can act on it.

- **Guild**: members, players (alts counted once), online now, running Short Royalty, shared their data, and levels in bands (60, 50–59, 40–49, 1–39). *Open roster*.
- **Raids**: the one big number, days until raids open on 9 Dec. Barrow Deeps (10) and Hyjal Summit (20) need no attunement, so it counts your level 60s. Onyxia's Lair (40) shows attuned / not attuned / unknown, and how many have the quest done but the Drakefire Amulet out of their bags. *Onyxia list*.
- **Data health**: members without Short Royalty data, profiles older than a week, profession windows never opened, and anyone on an old Short Royalty (you included). "All good" when there's nothing to fix. *Oldest first* opens the Roster with missing and oldest data on top.
- **Professions**: characters per crafting profession, how many are at 300 (or the best so far), **nobody** in red where the guild has a gap, and one line for gathering. *Find a crafter*.
- **Recipes**: recipes the guild knows, from how many crafters, and how many **only one character** knows, with examples, so you can see where there's no backup. *Search recipes*.
- **Recent milestones**: level-ups (every 10 levels), profession 75/150/225/300, Onyxia attunement and new recipes. Hover for when, click to open the character, **Grats** types "Grats Bramble on level 60!" into guild chat (you press Enter).

The line above the columns shows your guild, members and who's online.
Milestones are worked out by **your own addon** and kept on your computer
only (the last 50); nothing extra is sent. Turn them off in Settings.

### 👥 Roster
<p align="center"><img src="docs/images/roster.png" alt="Roster tab" width="100%"></p>

- **Every guild member**, including people without the addon.
- **Columns:** **Name** in class colour (*(you)* in pink on your characters, **+2** when alts are folded in), **Level**, **Rank**, **Spec** (main tree and points), **Professions**, **iLvl**, **Online** (a dot, then *online*, *on alt* or how long ago), **Version** (orange when out of date) and **Data** (how fresh their profile is; orange after a week).
- **Status dots:** 🟢 online with Short Royalty · ⚪ online without it · ⚫ offline.
- **Sort** by clicking a column (an arrow marks the sorted one). Online members come first.
- **Search** by name, profession, spec, class, rank, a word from their note, or an alt's name. A search with no matches says so.
- **Group alts** (on by default) shows each player once, under their main.
- **Counter**: characters, how many have data, how many need an update, and whether a newer Short Royalty is out.
- **Copy** gives the list exactly as shown, as plain text for Discord. Notes are never included.
- **Hover a row** for online status, every profession, missing enchants, the public note (and officer note if you're an officer), their alts and their addon version. **Click** to open the character.

**Raid view.** Pick a raid from the menu (Barrow Deeps, Hyjal Summit or
Onyxia's Lair, Forever's first wave) to see who's attuned:

<p align="center"><img src="docs/images/attunement.png" alt="Roster with Onyxia's Lair picked: Attuned column and filters" width="100%"></p>

- Barrow Deeps and Hyjal Summit need no attunement, so they just say so.
- For Onyxia, an **Attuned** column: *yes* (quest done, or the amulet in their bags), *no*, or *unknown* (no data, or gear hidden). An orange **!** means the quest is done but the amulet isn't in their bags, and you need it there to enter.
- Filters **All / Attuned / Not attuned / Unknown**, a count such as "23 attuned · 9 not · 6 unknown", and **Max level only** (on by default).
- Every character gets its own row, alts included, with "alt of X" in the tooltip. Your choices are remembered.

### 🛡️ Character
<p align="center"><img src="docs/images/character.png" alt="Character tab" width="100%"></p>

- **Top:** *Back to roster*, *My character*, *Whisper* and the gold **Ask for latest** button (or *Make this my main* on your own alts).
- **Ask for latest** asks them (or their online alt) for their newest data. It works while they're online with Short Royalty, at most every 30 seconds; otherwise it's greyed out and says why.
- **Header:** name in class colour, level, race, class and rank, plus how old the data is and where it came from (*this account*, *from them*, *relayed by a guildmate*). Old data says *may be out of date*.
- **Paperdoll:** all 19 slots with item-quality borders. Hover for the **real item tooltip**, Shift-click to link it, Ctrl-click for the dressing room. The middle shows **average item level** in gold, the main talent tree, and how many enchants are missing (an orange **!** marks each slot).
- **Details** in two columns:
  - **Alts** and **notes**; **talents** per tree; **professions** with skill, recipe count or *not scanned yet*; **cooldowns** (transmutes, Mooncloth: time left or *ready*).
  - **Attunements** for the first raid wave (with the amulet warning) and **reputations**: raid and crafting factions first, then everything at Friendly or above.
- **Privacy:** hidden gear or recipes say *hidden by this player*.
- **No data yet?** The panel says so and explains why, instead of showing empty boxes.

### ⚒️ Crafters
<p align="center"><img src="docs/images/crafters.png" alt="Crafters tab" width="100%"></p>

- **Search** at least 3 letters of an item or recipe: "arcanite", "mooncloth", "enchant boots".
- **Results** (up to 200): the item's icon, its name in quality colour, the profession, and how many crafters there are (and how many online). Hover for the real item tooltip; click to pick it.
- **Side panel:** every crafter, online first, then by skill, with a status dot, their skill, *on Gillybean* when they're on an alt (Whisper goes there) or *alt of X*, and a **Whisper** button. Long item names wrap rather than being cut off.
- **Post to guild chat** (gold) types "[Item] can be made by: A, B, C" into your chat box; you press Enter. **Copy** gives the list as plain text.
- **Reagents** under the crafter list: icon, name, how many, and how many you have in your bags (green when you have enough). Read from your own game, so they show once you've opened that profession's window; never sent to anyone.
- **Favourites:** right-click a result or a crafter to star it (a pink star). The **Favourites** chip lists only starred recipes; starred crafters come first among the same status. Saved on your computer only.
- Recipes come from each crafter's last visit to their profession window. While item names load from the game, placeholder rows show where results will appear.

### 🧪 Professions
<p align="center"><img src="docs/images/professions.png" alt="Professions tab, guild board" width="100%"></p>

- **Guild board:** one row per profession (crafting first, then gathering, then Cooking, First Aid and Fishing), including ones **nobody** has. Characters, how many are at 300, how many online, the top skill, when recipes were last recorded (orange after a week) and specialisations. Click a row to open that profession.
- **A reminder line** when your skill has gone up 15 or more since you last opened that profession's window ("Your Tailoring went from 240 to 262…"). In chat it says it at most once every three days; you can turn that off in Settings.

<p align="center"><img src="docs/images/professions-one.png" alt="One profession" width="100%"></p>

- **Gathering professions too:** in Forever, Herbalism and others have recipes (camping items like the Seed Hybridizer); they're recorded and listed like crafting ones.
- **One profession:** everyone with it (status dot, star, *alt of X*, skill, specialisation, "recipes recorded 3d ago" in orange after a week, **Whisper**) and every recipe known in the guild with its crafter count (a lone crafter in orange). Filters: **All**, **Only one crafter**, **Favourites**, and **Nobody knows** (recipes the game's window lists that nobody has learned, shown only once the game has listed some). Hover a recipe for its reagents; click to open it in Crafters; right-click to star it.

<p align="center"><img src="docs/images/cooldowns.png" alt="Cooldown board" width="100%"></p>

- **Cooldowns:** everyone's profession cooldowns (transmutes, Mooncloth…), ready first, then soonest. Shows who, how long, and **as of** when we last heard from them (orange after a day: a cooldown only updates while its owner is online). **Whisper** when they're on.
- **Specialisations** (Gnomish/Goblin Engineer, Dragonscale/Elemental/Tribal Leatherworking, Armorsmith/Weaponsmith and the master smiths) are read from your spellbook. A spell only counts when the game's own name for it matches, so a wrong ID can never mislabel anyone.

### ⚙️ Settings
<p align="center"><img src="docs/images/settings.png" alt="Settings tab" width="100%"></p>

- **Sharing:** *Share and receive guild data* (sync on or off), *Share my gear and talents*, *Share my recipes and cooldowns*.
- **Display:** *Show guild crafters in item tooltips*, *Record guild milestones*, *Remind me to reopen profession windows*, *Show minimap button*, **Reduce motion**, *Debug logging in chat*.
- **Window size:** 70% to 130%.
- **Tools:** *Rescan my character*, *Sync now*, *Reset window position*, *Debug report*.
- **Status:** version, guild, whether sync is running or paused (and why), whether you may send, message counts, Lua errors caught, when your data last updated, and which profession windows you still need to open.
- **What guildmates see from you:** a read-only list of exactly what you share, what stays private, and what's never shared.

### 🧨 Everywhere
- **Open it** with `/sr` (or `/shortroyalty`, `/sk`) or the **minimap button**: left-click opens the window, right-click opens Settings, drag to move it.
- **The window** opens on the Overview the first time, then on your last tab. Drag it by the title bar; it remembers where you left it. **Esc** closes it. The title bar shows the crest, your guild and the sync status.
- **Automatic collection** on every character you play: gear, item level, talents, reputations, professions, recipes (when you open the profession window), cooldowns, attunements and your other characters.
- **"Crafted by" on item tooltips:** hover any item to see "Short Royalty: Bramble (online), Dabble +2 more". Online crafters first, at most three names.
- **Chat reminders** for profession windows still to open (and, rarely, ones to reopen after your skill went up), a newer Short Royalty, and trial accounts that can't share.
- **`/sr debug`** opens a copyable report of what the addon can see, starting with the live-client checks and the profession checks for v0.3 (unlearned recipes, recipe categories, reagents, specialisations), and ending with the last Lua errors it caught. **Send it when something looks wrong.**

### 🔒 Under the hood
- **Your own data always wins.** A copy relayed by someone else never overwrites a newer copy from the character themselves.
- **Light on the network.** Only small fingerprints are broadcast; full profiles are whispered to whoever needs them, rate-limited so nobody is disconnected.
- **Careful with what it receives.** Nothing received is ever run as code. Messages from people outside the guild aren't even opened; oversized ones (over 32 KB, or over 256 KB unpacked) are refused; every field of every profile is checked before it's stored; a stranger can't pass themselves off as a guildmate who shares their first name; and no guildmate can flood you (60 messages a minute each, and senders of repeated bad messages are ignored until `/reload`). Details: [docs/SECURITY-REVIEW.md](docs/SECURITY-REVIEW.md).
- **Built from pinned sources.** The release zip is built by GitHub Actions pinned to exact commits, and the bundled libraries are byte-for-byte the upstream files.
- **Stays out of your way.** Sync pauses in combat, in every kind of instance and whenever the game locks addon chat. The window is safe to open in combat.
- **Private where it matters.** Notes, officer notes, gold, bags and chat are never sent. You choose whether gear and recipes are shared.
- **Tidies up.** Members who leave are forgotten 30 days later.

---

<a id="install"></a>

## 📦 Install

1. Download **`ShortRoyalty-vX.Y.Z-forever.zip`** from
   [**Releases**](https://github.com/EllisKOsborn/forever-shortkings/releases)
   (the first file under *Assets*).

   > [!WARNING]
   > **Not "Source code (zip)".** GitHub adds those links to every release.
   > They unzip to a folder like `forever-shortkings-0.2.4` and are missing
   > two libraries. Renaming that folder doesn't fix it.
2. Unzip it. You get a folder called **`ShortRoyalty`**. (Tried an early
   test build called `ShortKings`? Delete that old folder.)
3. Move that folder into your Forever **AddOns** folder:

   🍎 **Mac**
   ```
   /Applications/World of Warcraft/_forever_/Interface/AddOns/
   ```
   🪟 **Windows**
   ```
   C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\
   ```

4. Restart the game. *Short Royalty* is listed under **AddOns** on the character screen.

> [!TIP]
> **Can't find the folder?** In the Battle.net app, pick **WoW Forever**,
> click the **⚙** next to Play, then **Show in Finder** (Mac) or **Show in
> Explorer** (Windows). Open `Interface`, then `AddOns`. If there's no
> `AddOns` folder, create one, spelled exactly like that.

> [!IMPORTANT]
> The result must be `AddOns/ShortRoyalty/ShortRoyalty.toc`. A `ShortRoyalty`
> folder inside another `ShortRoyalty` folder won't load.

**First time in game:** open each of your **profession windows once** so your
recipes are recorded (the addon reminds you), and log in on each **alt** once.

---

<a id="commands"></a>

## ⌨️ Commands

| Type this | To |
|---|---|
| `/sr` | open or close the window (the minimap button does the same) |
| `/sr debug` | get a copyable report of what the addon can see. **Send this when something's wrong** |
| `/sr log` | the same report plus the recent log |
| `/sr scan` | re-read your character now |
| `/sr sync` | share your data now and ask for anything missing |
| `/sr reset` | put the window back in the middle of the screen |

`/shortroyalty` and `/sk` work too, if another addon already uses `/sr`.

---

<a id="faq"></a>

## ❓ FAQ

<details>
<summary><b>Someone shows no data. Why?</b></summary>

They don't have Short Royalty, haven't logged in since installing it, or are on
a **trial account** (trial accounts can't send addon messages). From the
outside the addon can't tell these apart, so it says all three.
</details>

<details>
<summary><b>My alt is missing, or isn't grouped under my main.</b></summary>

The game only lets an addon read the character you're logged in as, so log in
on each alt once. Alts are linked only when **both** characters have done
that (so nobody can claim someone else as their alt). To choose which one is
shown first, open it on the Character tab and press **Make this my main**.
</details>

<details>
<summary><b>Can I keep my gear or recipes private?</b></summary>

Yes. In **Settings**, untick *Share my gear and talents* or *Share my recipes
and cooldowns*. Guildmates then see "hidden by this player"; you still see
your own. Name, level and profession levels are always shared, as the guild
roster shows them anyway. Notes and officer notes are never sent.
</details>

<details>
<summary><b>My recipes aren't showing.</b></summary>

Open that profession's window once. Until then the Character tab says "not
scanned yet". After that your full recipe list is shared, you appear in
**Crafters**, and your name shows on tooltips of items you can make. Open it
again after learning new recipes.
</details>

<details>
<summary><b>How quickly do changes show up for guildmates?</b></summary>

The data comes from players' own games, not Blizzard's armory. While you're
both online, a change reaches guildmates in about **30–60 seconds**; **Ask for
latest** gets it sooner. Offline members show what they had when they last
played. Nothing is sent in combat or instances, so changes made there arrive
once you're out.
</details>

<details>
<summary><b>The animations bother me.</b></summary>

Settings → tick **Reduce motion**. Everything then happens instantly.
</details>

<details>
<summary><b>The titles look like the normal game font.</b></summary>

The game may have refused the bundled font. Nothing breaks: Short Royalty falls
back to the game font. Type `/sr debug` and send the text so we can check.
</details>

<details>
<summary><b>It says "out of date" on the AddOns screen.</b></summary>

Tick **Load out of date AddOns** for now and tell an officer. The addon needs
a new interface number for the latest patch.
</details>

<details>
<summary><b>Will it get me disconnected or slow my game down?</b></summary>

It shouldn't. Messages are small, compressed and rate-limited through
ChatThrottleLib, nothing is sent in combat or instances, and recipe scans are
spread over several frames.
</details>

<details>
<summary><b>How does syncing actually work?</b></summary>

```mermaid
sequenceDiagram
    participant You
    participant Guild as Guild channel
    participant Bob
    You->>Guild: HI: my characters (hash + timestamp)
    Bob->>Bob: compare with what I have
    Bob->>You: RQ (whisper): please send Pip's profile
    You->>Bob: PR (whisper): Pip's profile, compressed
    Note over You,Bob: On login, one random member also offers<br/>copies of anyone who is offline (SQ / SO)
```

The full design, data format and merge rules are in [PLAN.md](PLAN.md).
</details>

---

<a id="roadmap"></a>

## 🗺️ Roadmap

- [x] **v0.1**: data collection, guild sync, Roster, Character and Settings tabs, `/sr debug`
- [x] **v0.1.1**: status dots, alts under mains, notes, version column, missing-enchant markers, cooldowns, privacy switches
- [x] **v0.1.2**: raid attunement view, "Ask for latest", faster updates (30–60 s)
- [x] **v0.2.0**: **Crafters** tab and "Crafted by" on item tooltips
- [x] **v0.2.1**: launch readiness: Forever's real raid attunements, live-client checks, sync safety limits, sharing preview, Copy as text
- [x] **v0.2.2**: **Overview** dashboard with milestones and Grats
- [x] **v0.2.3**: the **new look**: black and gold, pink-beard crest, Chakra Petch titles, motion with Reduce motion, empty and loading states ([before and after](#the-look))
- [x] **v0.2.4**: new tagline, *Height is not a stat.*
- [x] **v0.2.5**: first in-game test (5 Nov): sync switched back on, enchant check at level 60, security fixes
- [x] **v0.2.6**: hotfix, no more false "send errors"
- [x] **v0.2.7**: `/sr debug` profession checks (what the game shows, before v0.3 is built)
- [x] **v0.3.0 Professions**: guild coverage, crafters and recipes per profession, cooldown board, specialisations, reagents, favourites, reminders
- [ ] **In-game test round** with guildmates (TESTING.md), then fixes
- [ ] **v0.4**: **Raids**, built on the guild calendar: sign-ups, roles, line-up with attunement and readiness, reminders, invite-all (before raids open on 9 Dec)
- [ ] **v0.5**: craft requests, a short status line, lockout board
- [ ] **Later**: raid attendance, shopping lists, guild bank viewer and more in the [plan](PLAN.md#later-in-rough-priority-order)
- [ ] CurseForge release

Testing it in game? Work through [TESTING.md](TESTING.md). The plan for launch
week is in [PLAN.md section 10](PLAN.md#10-once-forever-is-live-from-4-nov-2026).

---

<a id="the-look"></a>

## 👑 The look

<p align="center"><img src="docs/images/before-after.png" alt="The Overview tab before and after the redesign" width="100%"></p>

Black and gold, the way WoW's own UI likes it, with the mascot on top: a gnome
with a **pink beard** and **lit dynamite**.

<p align="center"><img src="docs/images/palette.png" alt="Colour roles: black, surface, gold, beard pink, dynamite, text, good, bad" width="100%"></p>

- **Every colour has one job.** Gold shows where you are and the one main
  button on a screen. Pink shows what you've picked. Dynamite orange appears
  only on alerts (old data, a missing enchant, an update) and the sync dot.
  Green and red mean yes and no.
- **Clear type.** Square-cut **Chakra Petch** for the title, tabs and
  headings; the game's own **Arial Narrow** for names and numbers, with
  Blizzard's Russian, Korean and Chinese fallbacks so every name shows.
- **Quick, quiet motion.** The window fades in, the gold underline glides
  between tabs, rows light up under the mouse, menus drop from their button,
  and the sync dot sends out a ring when new data arrives. All of it is
  under a fifth of a second, picks up where it was if you click again, and
  turns off with **Reduce motion**. Opening with `/sk` and closing with Esc
  are always instant.
- **Honest states.** Lists explain themselves when they're empty ("Nobody
  matches…", "You're not in a guild…"), item names show placeholders while
  they load, missing values are a dash, and Lua errors are counted in the
  title bar.
- **Fits your screen.** The window shrinks itself if your UI scale and
  screen size would push it off the edge.

The full design system is in [DESIGN.md](DESIGN.md).

---

<details>
<summary><b>🛠️ For developers</b></summary>

```sh
luacheck .                      # lint
busted                          # unit tests: Lua 5.1, stubbed WoW API in tests/helpers/
node tools/preview-tokens.js    # copy UI/Theme.lua's values into the browser preview
node docs/mockups/render.js     # regenerate the README pictures from preview/index.html
node tools/textures.js          # redraw the crest and icons (power-of-two .tga)
```

Open [`preview/index.html`](preview/index.html) in a browser to click through
every window with full, empty, loading, error and worst-case data, or to see
any tab before and after the redesign.

| Folder | What lives there |
|---|---|
| `Core/` | start-up, events, saved data, guild roster, alts, the crafter index, Overview numbers, milestones, text export; `Compat.lua` is the **only** file that touches client-specific APIs |
| `Collect/` | reads gear, talents, professions, recipes, reputation and attunements |
| `Sync/` | encoding (LibSerialize + LibDeflate), merge rules, the HI/RQ/PR/SQ/SO protocol |
| `UI/` | `Theme.lua` (**every** colour, font, size, spacing step and motion timing; a test fails if one is hard-coded elsewhere), `Motion.lua`, widgets, tabs, the item-tooltip line |
| `Media/` | Chakra Petch (SIL OFL), Arial Narrow font families, the crest and four small icons |
| `Data/` | profession, attunement and faction tables (IDs verified or marked TODO, never guessed) |
| `preview/`, `tools/`, `docs/` | the browser preview, the texture and token scripts, mock-up renderer and design notes |

**Releasing:** push a tag like `v0.2.3` on `main`. The *Release* workflow runs
the BigWigs packager, builds `ShortRoyalty-0.2.3.zip` and attaches it to a GitHub
Release with notes from CHANGELOG.md. Every push also produces an unpublished
**test build** (Actions → Tests → `ShortRoyalty-test-build`).

**Design:** [DESIGN.md](DESIGN.md) (the system), [PRODUCT.md](PRODUCT.md) (who it's for),
[docs/design/lamborghini-reference.md](docs/design/lamborghini-reference.md) (the starting reference).
</details>

## 🙏 Credits

No code was copied from other guild-sync addons. API facts come from
Blizzard's own UI source (mirrored at
[Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), `forever`
branch), [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes),
and public notes in the [Everloot](https://github.com/Everloot/everloot/pull/49)
and [bff-wow](https://github.com/Shtian/bff-wow/issues/3) projects.

Libraries: Ace3 (AceComm, CallbackHandler, LibStub, ChatThrottleLib),
[LibSerialize](https://github.com/rossnichols/LibSerialize) by Ross Nichols,
[LibDeflate](https://github.com/SafeteeWoW/LibDeflate) by Haoqian He,
LibDataBroker and LibDBIcon. Licences are in [Libs/README.md](Libs/README.md).

Titles use [Chakra Petch](https://fonts.google.com/specimen/Chakra+Petch) by
Cadson Demak (SIL Open Font License 1.1, bundled in `Media/Fonts/` with its
licence). The black-and-gold direction started from the Lamborghini-inspired
DESIGN.md by [getdesign](https://www.npmjs.com/package/getdesign). The crest
is drawn from simple shapes by `tools/textures.js`.

Released under the [MIT licence](LICENSE). Made with 💖 and 🧨 by the Short Royalty.
