<p align="center">
  <img src="docs/images/banner.webp" alt="Short Kings: Small in stature. Big in loot." width="100%">
</p>

<p align="center">
  <a href="https://github.com/EllisKOsborn/forever-shortkings/actions/workflows/ci.yml"><img alt="Tests" src="https://github.com/EllisKOsborn/forever-shortkings/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="WoW Forever 1.60.1" src="https://img.shields.io/badge/WoW%20Forever-1.60.1%20%C2%B7%2016001-D94FA0?labelColor=2A1220">
  <img alt="Version" src="https://img.shields.io/badge/version-0.1.1%20alpha-FF7A1A?labelColor=2A1220">
  <img alt="Licence MIT" src="https://img.shields.io/badge/licence-MIT-FFC24A?labelColor=2A1220">
</p>

<p align="center">
  <b>The guild addon for the Short Kings of World of Warcraft: Forever.</b><br>
  See every member's gear, talents, professions and recipes in one window.<br>
  No website, no server, no uploads: it all travels over the guild's addon channel.
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#whats-inside">What's inside</a> ·
  <a href="#commands">Commands</a> ·
  <a href="#faq">FAQ</a> ·
  <a href="#roadmap">Roadmap</a>
</p>

> [!NOTE]
> **v0.1.1 is an alpha that hasn't been run in game yet.** It's built against
> Blizzard's own Forever 1.60.1 interface code and tested with a simulated WoW
> client. The pictures below are **mockups** drawn from the addon's real
> colours and layout. Item icons are placeholders; in game you see the real ones.

---

<a id="whats-inside"></a>

## 🧨 What's inside

| | What you get |
|---|---|
| 👥 **Roster** | The whole guild in one sortable, searchable list, with alts folded under mains |
| 🛡️ **Character** | Anyone's gear, talents, professions, cooldowns, attunements and reputations |
| ⚙️ **Settings** | Sync and privacy switches, window size, and a live status read-out |
| 🧨 **Everywhere** | `/sk`, a minimap button, reminders, and a copyable debug report |

### 👥 Roster
<p align="center"><img src="docs/images/roster.webp" alt="Roster tab mockup" width="100%"></p>

- **Every guild member**, including people without the addon.
- **Columns:**
  - **Name** in class colour, marked *(you)* for your characters, plus a **+2** when alts are folded in.
  - **Level** and **rank**.
  - **Spec**: main talent tree and points, e.g. *Holy 21/30/0*.
  - **Professions** with skill levels.
  - **Item level**.
  - **Online**: a coloured dot, then *Online*, *on alt* or how long ago they were last seen.
  - **Ver**: their Short Kings version, in orange when out of date.
  - **Data**: how fresh their profile is.
- **Status dots:** 🟩 online with Short Kings · 🟨 online without it · ⬜ offline.
- **Group alts** (on by default) folds each player's characters into one row, under the character they chose as their main.
- **Sort** by clicking any column. Online members come first.
- **Search** by name, profession, spec, class, rank, a word from their note, or an alt's name.
- **Counter** at the top: characters, how many have data, and how many need an addon update.
- **Hover a row** to see:
  - their online status;
  - all their professions, including Cooking, First Aid and Fishing;
  - missing enchants;
  - the public note, plus the officer note if you're an officer;
  - their alts, with each alt's online status;
  - their addon version.
- **Click a row** to open that character.

### 🛡️ Character
<p align="center"><img src="docs/images/character.webp" alt="Character tab mockup" width="100%"></p>

- **Buttons:** *< Roster*, *Me* (your own character), *Whisper* (opens a whisper to them), and *Make this my main* on your own alts.
- **Header:** name, level, race, class and guild rank. It also shows how old the data is and where it came from: *this account*, *from them*, or *relayed by a guildmate*.
- **Paperdoll** with all 19 slots, borders coloured by item quality.
  - Hover a slot for the **real item tooltip**.
  - **Shift-click** to link the item in chat.
  - **Ctrl-click** to preview it in the dressing room.
- **Average item level** and main talent tree in the middle of the paperdoll.
- **Missing enchants:** an orange **!** on the slot, a note in the tooltip, and a count such as "2 missing enchants".
- **Details** beside the paperdoll:
  - **Alts** (same player) and **notes**.
  - **Talents**: points in each tree.
  - **Professions**: skill level, number of known recipes, or *not scanned yet*.
  - **Cooldowns** (transmutes, Mooncloth and the like): time left, or *ready*.
  - **Attunements**: Onyxia, Molten Core, Blackwing Lair (*done* / *not done*), plus the new Forever raids, shown as unknown until their quests are confirmed.
  - **Reputations**: raid and crafting factions first, then every faction at Friendly or above.
- **Privacy:** if someone hides their gear or recipes, it says *hidden by this player* instead.

### ⚙️ Settings
<details>
<summary>Show the Settings tab</summary>
<p align="center"><img src="docs/images/settings.webp" alt="Settings tab mockup" width="100%"></p>
</details>

- **Share and receive guild data**: turns sync on or off entirely.
- **Share my gear and talents** / **Share my recipes and cooldowns**: privacy switches.
- **Show minimap button**, and **debug logging** in chat.
- **Window size**: 70% to 130%.
- **Buttons:** *Rescan my character*, *Sync now*, *Reset window position*, *Debug report*.
- **Live status:**
  - version and guild;
  - whether sync is running or paused, and why (combat, instance, …);
  - whether this account may send;
  - message counts;
  - when your data last updated;
  - which profession windows you still need to open.

### 🧨 Everywhere
- **Open it** with `/sk` (or `/shortkings`) or the **minimap button**.
  - Left-click opens the window.
  - Right-click opens Settings.
  - Drag the button to move it around the minimap.
- **The window** can be dragged by its title bar and remembers its place and size. **Esc** closes it, and the title bar shows your guild and whether sync is on.
- **Automatic collection.** Every character you log in on is recorded:
  - gear and item level, talents and reputations;
  - professions, recipes (when you open the profession window) and cooldowns;
  - attunements;
  - your other characters.

  It refreshes whenever something changes.
- **Chat reminders:** which profession windows you still need to open, when a guildmate has a newer Short Kings, and a notice if a trial account can't share data.
- **`/sk debug`** opens a copyable report of what the addon can see. Send it when something looks wrong. `/sk log` adds the recent activity log.

### 🔒 Under the hood
- **Your own data always wins.** A copy passed on by someone else can never overwrite a newer copy from the character themselves.
- **Light on the network.** Only small fingerprints are broadcast, and full profiles are whispered to whoever needs them. Everything is rate-limited, so nobody gets disconnected.
- **Stays out of your way.** Sync pauses in combat, in dungeons, raids, battlegrounds and arenas, and whenever the game locks addon chat. Big recipe lists are read a little at a time, so there are no hitches.
- **Private by default where it matters.** Notes and officer notes are never sent, nor are gold, bags or chat. You choose whether gear and recipes are shared.
- **Fair to everyone.** Members without the addon still appear in the roster. Trial accounts can still see their own data.
- **Tidies up.** Members who leave the guild are forgotten 30 days later.

---

<a id="install"></a>

## 📦 Install

1. Download the latest **`ShortKings-x.y.z.zip`** from
   [**Releases**](https://github.com/EllisKOsborn/forever-shortkings/releases).
2. Unzip it. You'll get a folder called **`ShortKings`**.
3. Move that folder into your Forever **AddOns** folder:

   🍎 **Mac**
   ```
   /Applications/World of Warcraft/_forever_/Interface/AddOns/
   ```
   🪟 **Windows**
   ```
   C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\
   ```

4. Restart the game. *Short Kings* should be listed under **AddOns** on the character screen.

> [!TIP]
> **Can't find the folder?** In the Battle.net app, pick **WoW Forever**,
> click the **⚙** next to Play, then **Show in Explorer** (Windows) or
> **Show in Finder** (Mac). Open `Interface`, then `AddOns`. If there's no
> `AddOns` folder, create one, spelled exactly like that.

> [!IMPORTANT]
> The result must be `AddOns/ShortKings/ShortKings.toc`. A `ShortKings`
> folder inside another `ShortKings` folder won't load.

**First time in game:**
- Open each of your **profession windows once** so your recipes are recorded. The addon reminds you which ones are left.
- Log in on each **alt** once, too.

---

<a id="commands"></a>

## ⌨️ Commands

| Type this | To |
|---|---|
| `/sk` | open or close the window (the minimap button does the same) |
| `/sk debug` | get a copyable report of what the addon can see. **Send this when something's wrong** |
| `/sk log` | get the same report plus the recent log |
| `/sk scan` | re-read your character right now |
| `/sk sync` | share your data now and ask for anything missing |
| `/sk reset` | put the window back in the middle of the screen |

`/shortkings` works too, if another addon already uses `/sk`.

---

<a id="faq"></a>

## ❓ FAQ

<details>
<summary><b>Someone shows "no addon/trial". Why?</b></summary>

They don't have Short Kings installed, haven't logged in since installing it,
or are on a **trial account**. Trial accounts can't send addon messages, so
their data can't reach anyone. From the outside, the addon can't tell these
cases apart.
</details>

<details>
<summary><b>My alt is missing.</b></summary>

The game only lets an addon read the character you're logged in as. Log in on
the alt once and it will be saved and shared.
</details>

<details>
<summary><b>My alt isn't grouped under my main.</b></summary>

Log in on **both** characters at least once with the addon. Alts are only
linked when each character confirms the other (so nobody can claim someone
else as their alt). To choose which one is shown first, open that character
on the Character tab and press **Make this my main**.
</details>

<details>
<summary><b>Can I keep my gear or recipes private?</b></summary>

Yes. In **Settings**, untick *Share my gear and talents* or *Share my recipes
and cooldowns*. Guildmates then see "hidden by this player"; you still see
your own. Your name, level and profession levels are always shared, as the
guild roster already shows them. Notes and officer notes are never sent.
</details>

<details>
<summary><b>My recipes aren't showing.</b></summary>

Open that profession's window once. Recipes are read from the profession
window, so the Character tab says "not scanned yet" until you do.
</details>

<details>
<summary><b>It says "out of date" on the AddOns screen.</b></summary>

Tick **Load out of date AddOns** for now, and tell an officer. The addon
needs a new interface number for the latest game patch.
</details>

<details>
<summary><b>Will it get me disconnected or slow my game down?</b></summary>

It shouldn't. Messages are small, compressed and rate-limited through
ChatThrottleLib, and nothing is sent during combat or inside instances.
Recipe scans are spread over several frames.
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

- [x] **v0.1**: data collection, guild sync, Roster, Character and Settings tabs, `/sk debug`
- [x] **v0.1.1**: online/addon status dots, alts under mains, notes, version column, missing-enchant markers, accurate cooldowns, privacy toggles
- [ ] **v0.2**: **Crafters** (search an item, see who can make it, Whisper) and **Professions** (coverage, cooldown board, recipes nobody has), plus "Crafted by" on item tooltips
- [ ] **v0.3**: **Raids**, built on Blizzard's guild calendar: sign-up status, roles, line-up with attunement check, reminders, invite-all
- [ ] **v0.4**: theme polish (ember sparks on the title bar), attunement and faction tables confirmed for Forever
- [ ] **Later**: craft requests, export to text, raid attendance, shopping lists, guild bank viewer, and more in the [plan](PLAN.md#later-in-rough-priority-order)
- [ ] CurseForge release

Testing it in game? Work through the checklist in [TESTING.md](TESTING.md).

---

<details>
<summary><b>🛠️ For developers</b></summary>

```sh
luacheck .    # lint
busted        # unit tests: Lua 5.1, stubbed WoW API in tests/helpers/
node docs/mockups/render.js [font.woff2]   # regenerate the README pictures
```

| Folder | What lives there |
|---|---|
| `Core/` | start-up, events, saved data, guild roster; `Compat.lua` is the **only** file that touches client-specific APIs |
| `Collect/` | reads gear, talents, professions, recipes, reputation and attunements |
| `Sync/` | encoding (LibSerialize + LibDeflate), merge rules, the HI/RQ/PR/SQ/SO protocol |
| `UI/` | theme, widgets and tabs (colours and gradients only, no image files) |
| `Data/` | profession, attunement and faction tables (IDs are verified or marked TODO, never guessed) |

**Releasing:** push a tag like `v0.1.0`. The *Release* workflow runs the
BigWigs packager, which builds `ShortKings-0.1.0.zip` and attaches it to a
GitHub Release. For CurseForge, add a `CF_API_KEY` repository secret and an
`## X-Curse-Project-ID:` line to `ShortKings.toc`. Every push also produces
an unpublished **test build** (Actions → Tests → `ShortKings-test-build`).

**Theme palette** (from `UI/Theme.lua`):

| Plum dark | Plum | Magenta | Hot pink | Ember | Flame | Leather | Gold |
|---|---|---|---|---|---|---|---|
| `#2A1220` | `#3D1A2E` | `#D94FA0` | `#F07ACB` | `#FF7A1A` | `#FFC24A` | `#6B3E1E` | `#D4AF37` |
</details>

## 🙏 Credits

No code was copied from other guild-sync addons. API facts come from
[warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes),
Blizzard's own UI source (mirrored at
[Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), `forever`
branch), and public notes in the
[Everloot](https://github.com/Everloot/everloot/pull/49) and
[bff-wow](https://github.com/Shtian/bff-wow/issues/3) projects.

Libraries: Ace3 (AceComm, CallbackHandler, LibStub, ChatThrottleLib),
[LibSerialize](https://github.com/rossnichols/LibSerialize) by Ross Nichols,
[LibDeflate](https://github.com/SafeteeWoW/LibDeflate) by Haoqian He,
LibDataBroker and LibDBIcon. Licences are listed in [Libs/README.md](Libs/README.md).
The README mockups use [Marcellus](https://fonts.google.com/specimen/Marcellus)
(SIL OFL) as a stand-in for the game's font.

Released under the [MIT licence](LICENSE). Made with 💖 and 🧨 by the Short Kings.
