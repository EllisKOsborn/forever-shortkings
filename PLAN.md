# Short Kings — addon plan (awaiting approval)

> Status: **v0.1 to v0.2.1 code complete (not yet tested in game).** Roadmap: section 7.
> Researched against Blizzard's own UI source for the Forever client,
> build **1.60.1.70532** (Gethe/wow-ui-source, `forever` branch), plus
> warcraft.wiki.gg's *Patch 1.60.1/API changes* page.
> Nothing here has been run in the game.

---

## 1. Changes to the original brief (pushback)

| # | You asked for | Problem | What I propose |
|---|---|---|---|
| 1 | A new repo `EllisKOsborn/short-kings-addon` | This session can only reach `elliskosborn/forever-shortkings`, which is empty and ready to use. | Use `forever-shortkings`. The in-game folder will still be called `ShortKings`, because the release zip sets that, not the repo name. |
| 2 | Key characters by **Name-Realm** | Forever has **no realms**. Names are two-part (first name + surname) and unique across the region. The exact `sender` format in addon messages is not documented. | Key every character by its **player GUID**, which is stable and unique, and show the roster name. `/sk debug` prints the real formats so we can check them in game. |
| 3 | Data for **all characters on the account** | An addon can only read a character while you are logged in as it. | Each alt is recorded the first time you log in as it, and again on every later login. The window shows "last updated" for each one. |
| 4 | Every client sends a manifest of **every** character every few minutes | With 100 members that is 100 × 100 entries going round guild chat. It grows with the square of guild size and risks throttling. | Each client announces **only its own account's characters**. For members who are offline, a new arrival sends one query when it logs in, and a single peer (chosen with a random delay) offers to fill the gaps. Traffic grows in step with guild size. |
| 5 | "Which recipes **nobody** has" | That needs a list of every recipe that exists. Forever adds 600+ recipes, and no verified list has been published. | Build the list from what members see: when anyone opens a profession window, record **unlearned** recipes too, not only learned ones. "All recipes" = everything any member has seen. The list grows as people scan. Caveat: this depends on the Forever profession window showing unlearned recipes, which I'll check in game. |
| 6 | Reputations with "the major raid factions" | Forever adds new raids (Barrow Deeps, Hyjal Summit), so its factions may differ from Classic. Hard-coding Classic faction IDs would be guessing. | Record **every** faction the character can see. A short highlight list (`Data/Factions.lua`) marks each entry as *verified* or *TODO*. |
| 7 | Attunements table | Only the Onyxia attunement is confirmed for Forever. Raids open on 9 Dec, and Molten Core isn't in the first wave. | Fill in only the quest IDs I can check against two sources, and mark everything else **TODO**. No guessed IDs. |
| 8 | Pause in **raids and dungeons** | Battlegrounds and arenas are instances too, and Midnight's chat-lockdown rules can block addon messages at other times. | Pause in **every** instance type, in combat, and whenever `C_ChatInfo.InChatMessagingLockdown()` is true. Messages wait in a queue and send later. |
| 9 | Show trial members as "can't sync" | Other players can't see from outside that someone is on a trial. A trial member and a member without the addon look the same. | The roster shows **"No data (no addon / trial)"**. On a trial player's own screen, the addon shows a clear notice and turns sending off. |
| 10 | Crafters tab | Forever's Blizzard UI already includes Blizzard's own guild crafter lookup (`C_GuildInfo.QueryGuildMembersForRecipe`). | Keep our tab, because it works for offline members and can search by item name. `/sk debug` reports whether Blizzard's version is turned on. |
| 11 | Talents | Forever's talent window runs on the modern trait system (`C_Traits`), drawn as Classic-style trees. | Store points per tree (e.g. 31/20/0) plus the talent spell IDs and ranks, so anyone can see names and icons whatever their class. |

---

## 2. File layout

```
forever-shortkings/            (zipped as ShortKings/ by the packager)
├─ ShortKings.toc              ## Interface: 16001  (one TOC, no suffix)
├─ embeds.xml                  loads the libraries
├─ Libs/                       fetched by .pkgmeta externals (not committed)
├─ Core/
│  ├─ Init.lua                 namespace, version, event dispatcher
│  ├─ Compat.lua               the only file that calls WoW APIs that vary;
│  │                           detects what exists at runtime
│  ├─ Log.lua                  debug ring buffer (/sk debug)
│  ├─ DB.lua                   SavedVariables schema, migrations, pruning
│  └─ Identity.lua             GUID ↔ name, guild roster cache
├─ Collect/
│  ├─ Character.lua            basics, gear, item level
│  ├─ Talents.lua
│  ├─ Professions.lua          skills, recipe scan, cooldowns
│  ├─ Reputation.lua
│  └─ Attunements.lua
├─ Data/
│  ├─ Attunements.lua          quest IDs: verified or TODO
│  └─ Factions.lua             highlight list: verified or TODO
├─ Sync/
│  ├─ Codec.lua                LibSerialize → LibDeflate → addon-safe encode; hash
│  ├─ Protocol.lua             message types and checks
│  └─ Sync.lua                 scheduling, queue, merge rules
├─ UI/
│  ├─ Theme.lua                colours, gradients, ember effect
│  ├─ Widgets.lua              tabs, buttons, scroll lists
│  ├─ MainFrame.lua
│  ├─ RosterTab.lua  CharacterTab.lua  CraftersTab.lua  Tooltip.lua
│  ├─ ProfessionsTab.lua  SettingsTab.lua
│  └─ Minimap.lua              LibDBIcon
├─ Commands.lua                /sk, /sk debug, /sk scan, /sk reset
├─ tests/                      busted specs and a stubbed WoW API
├─ .luacheckrc  .busted  .pkgmeta
├─ .github/workflows/ci.yml       luacheck + busted on every push
├─ .github/workflows/release.yml  BigWigs packager on version tags
└─ README.md  CHANGELOG.md  LICENSE (MIT, unless you prefer another)
```

Libraries (all with permissive licences): LibStub, CallbackHandler-1.0,
AceComm-3.0 (+ ChatThrottleLib), LibSerialize, LibDeflate, LibDataBroker-1.1,
LibDBIcon-1.0. Ace3 comes from **trunk**, because the tagged release doesn't
list 16001 or include the 12.x lockdown fixes.

---

## 3. Data schema (`ShortKingsDB`, account-wide)

```lua
ShortKingsDB = {
  schema   = 1,
  settings = { sync = true, debug = false,
               minimap = { hide = false },
               window  = { point = "CENTER", x = 0, y = 0, scale = 1 } },
  account  = { [guid] = true },          -- characters seen on THIS account
  guilds   = {
    ["<guild name>"] = {
      members  = { [guid] = { name, class, level, rank, online,
                               lastSeen, leftAt } },      -- from the roster
      profiles = { [guid] = Profile },
      recipeUniverse = { [skillLineID] = { [recipeID] = outputItemID or 0 } },
    },
  },
}

Profile = {
  v = 1, guid, name, class, race, level,
  updated = <server time>, addon = "0.1.0", hash = <adler32>,
  source  = "owner" | "relay",          -- local bookkeeping only, never sent
  family  = { guid, ... },              -- alts this owner says are theirs
  gear    = { [slotID] = "item:..." },  -- item strings, tooltips work from these
  ilvl    = 0,
  talents = { trees = { { name, points, icon } },
              nodes = { [spellID] = rank } },
  profs   = { [skillLineID] = { name, rank, max, scanned = ts|nil } },
  recipes = { [skillLineID] = { recipeID, ... } },        -- learned only
  cds     = { [recipeID] = expiresAt },                   -- server time
  reps    = { [factionID] = { standing, value } },
  att     = { [attunementKey] = true|false },
}
```

Size estimate: a crafter with two professions comes to about 2–4 KB
after compression. That's roughly 10–20 addon messages, which go out at
BULK priority.

---

## 4. Sync protocol

Prefix `ShortKings`. Every message is a serialised table
`{ t = type, p = protocolVersion, ... }`. Clients ignore messages that
carry a newer major protocol version.

| Type | Channel | Sent when | Contents |
|---|---|---|---|
| `HI` | GUILD | login (+10–20 s jitter), every 10 min, 60 s after own data changes | my account's characters: `{guid, updated, hash}` |
| `RQ` | WHISPER | after a `HI`/`SO` shows something missing or stale | `{ want = {guid, ...} }` |
| `PR` | WHISPER | in reply to `RQ` | one profile per message |
| `SQ` | GUILD | once per session, ~60 s after login | `{guid, updated}` for every profile I hold |
| `SO` | GUILD | a peer has newer copies than the `SQ` listed; random 2–8 s delay, cancelled if someone else offers first | `{ holder, guids }` |

**Merge rules (enforced in `Sync.lua`, covered by tests):**
1. Drop any profile whose GUID isn't in the current guild roster. If the
   roster hasn't loaded yet, hold the message until it has.
2. Drop it if `updated` is more than 5 minutes in the future.
3. Drop it if the hash doesn't match the payload.
4. **Owner copy** (the sender *is* that character, or is listed in its
   `family` as last stated by the character itself): accept it if
   `updated >= stored.updated`.
5. **Relay copy**: accept it only if `updated > stored.updated`. A relay
   therefore can never overwrite a newer owner copy.

**Safety:** all sends go through ChatThrottleLib (BULK for profiles, NORMAL
for the rest). Sending pauses when `InCombatLockdown()`, `IsInInstance()`
or `C_ChatInfo.InChatMessagingLockdown()` is true. ChatThrottleLib drops
lockdown failures, so the addon keeps its own retry queue. Incoming data
is buffered during combat and processed afterwards. Trial accounts
(`IsTrialAccount` / `IsVeteranTrialAccount` / `IsRestrictedAccount`)
never send.

**Pruning:** a member who disappears from a *fully loaded*, non-empty
roster gets `leftAt = now`. Their data is deleted after 30 days, and the
timer clears if they rejoin.

---

## 5. APIs checked against Forever 1.60.1.70532

✅ = in Blizzard's generated API docs, or called by Blizzard's own Forever
UI code. ❓ = has to be confirmed in game; the addon checks for it at
runtime and copes if it's missing.

| Need | API | Status |
|---|---|---|
| Interface number | `select(4, GetBuildInfo())` → 16001 | ✅ (beta value; confirm on live) |
| Addon messages | `C_ChatInfo.SendAddonMessage` (returns a result enum), `RegisterAddonMessagePrefix`, `CHAT_MSG_ADDON` | ✅ |
| Lockdown | `C_ChatInfo.InChatMessagingLockdown`, `AreOutgoingAddonChatMessagesRestricted` | ✅ |
| Secret values | `issecretvalue`, `canaccessvalue` | ✅ (used as guards) |
| Trial | `IsTrialAccount`, `IsVeteranTrialAccount`, `IsRestrictedAccount` | ✅ |
| Professions list | `GetProfessions`, `GetProfessionInfo` | ✅ used by Forever's ProfessionsBook |
| Skill lines | `C_SkillInfo.GetNumSkillLines/GetSkillLineInfo` | ✅ used by Forever's SkillsFrame (the wiki listed these as removed; the 70532 source still has them) |
| Recipe list | `C_TradeSkillUI.GetFilteredRecipeIDs` ✅, `GetAllRecipeIDs` ❓ | not in the generated docs; Blizzard's UI calls `GetFilteredRecipeIDs` |
| Recipe info | `C_TradeSkillUI.GetRecipeInfo`, `GetRecipeOutputItemData`, `GetBaseProfessionInfo` | ✅ |
| Skip other people's windows | `C_TradeSkillUI.IsTradeSkillLinked/IsTradeSkillGuild/IsNPCCrafting` | ✅ used by Blizzard's UI |
| Cooldowns | `C_TradeSkillUI.GetRecipeCooldown` | ✅ used by Blizzard's UI (works only while the window is open) |
| Classic fallback | `GetTradeSkillInfo`, `GetCraftInfo`, … | ❌ not in this build; kept only as a defensive fallback |
| Talents | `C_SpecializationInfo.GetCombatConfigIDForSpecGroup`, `C_ClassTalents.GetActiveConfigID`, `C_Traits.GetConfigInfo/GetTreeNodes/GetNodeInfo/GetEntryInfo/GetDefinitionInfo/GetGroupDisplayInfoByTreeID` | ✅ used by Forever's ClassTalents frame |
| Gear | `GetInventoryItemLink`, `GetAverageItemLevel` | ✅ used by Forever's PaperDollFrame |
| Reputation | `C_Reputation.GetNumFactions/GetFactionDataByIndex/GetFactionDataByID` | ✅ |
| Quests | `C_QuestLog.IsQuestFlaggedCompleted` | ✅ |
| Guild roster | `C_GuildInfo.GuildRoster`, `GetNumGuildMembers`/`GetGuildRosterInfo` ❓, fallback `C_Club.GetGuildClubId/GetClubMembers/GetMemberInfo` ✅ | Forever's guild UI uses C_Club |
| Server time | `GetServerTime` | ✅ |

**Open questions only the game can answer** (all printed by `/sk debug`):
- What `sender` looks like in `CHAT_MSG_ADDON` with two-part names.
- Whether `GetGuildRosterInfo` still exists and returns GUIDs.
- Whether the profession window shows unlearned recipes.
- Whether player GUIDs stay the same across sessions. The wiki says only
  creature, pet and object GUIDs are obfuscated.
- The live TOC number after the 4 Nov launch.

---

## 6. Raid sign-ups (added 1 Nov)

**Recommendation: build on Blizzard's in-game calendar instead of making our own.**

Forever ships Blizzard's full calendar (`C_Calendar`, `Blizzard_Calendar`).
Its own code lets **any guild member create a "Guild Event"** (a sign-up
event). Only ranks with the "edit guild event" permission can create
"Guild Announcements". So **no custom roles are needed**: anyone can
already create a raid, and only the creator (or officers) can edit it.

Why build on it:
- Events live on Blizzard's servers. They're there when the creator is
  offline, and members **without the addon** can still sign up.
- No sync conflicts, and no one can fake, spam or delete other people's events.
- Addon code isn't allowed to create events (`C_Calendar.AddEvent` is
  flagged as restricted), so the **"New raid" button opens Blizzard's calendar**.

What our **Raids tab** adds:
- Upcoming guild sign-up events for the next 30 days.
- For each event, everyone who signed up: name (class colour), status
  (signed up / tentative / declined), **role**, **spec** (main talent tree
  + points, e.g. "Holy 31/20/0"), item level and attunement for that raid.
- Counts per role (e.g. "Tanks 2 · Healers 6 · DPS 18") and missing roles.
- **Role**: Blizzard's sign-up records no role. Each member picks
  Tank/Healer/DPS in our tab. The default comes from their talent tree
  (`Data/Roles.lua`), and the choice is shared as a small owner-only
  `RL` message `{eventID, guid, role, updated}`. Members without the
  addon show a greyed-out guess based on their spec.
- Sign-up / Tentative / Decline buttons, if the game lets addons press
  them. If it doesn't, the button opens Blizzard's calendar on that event.

Check in game: whether `eventID` is the same on every client; whether
sign-up calls are protected; and reading the sign-up list needs
`C_Calendar.OpenEvent`, so we only read it while Blizzard's calendar window
is closed, to avoid interfering with it.

**Refined 2 Nov (checked against the 1.60.1 calendar docs)** — the build
prompt is `docs/prompts/next-v0.3-raids.md`:
- Each sign-up (`CalendarEventInviteInfo`) includes the player's **GUID**,
  name, class, level and status, so line-ups key cleanly by GUID.
- Blizzard's statuses are Invited, Available, Declined, Confirmed, Out,
  Standby, Signed up, Not signed up and Tentative. There is **no "late"**
  status and **no role** field. "Bench" = Standby (set by the event's moderators).
- Roles: a **main and second role in the profile** instead of a per-event
  `RL` message. It needs no new protocol and works when people are offline.
  Per-event overrides can come later.
- Only `AddEvent` is flagged `HasRestrictions`. The sign-up calls
  (`EventSignUp`, `EventTentative`, `EventDecline`, `EventAvailable`) are
  not, but are still only called from button presses.
- `GetDayEvent` and `EventGetInvite` return secret values during chat
  lockdown, so read them only when sync isn't paused.
- Raid templates (C5) become a raid table (name, size, title keywords)
  used to match events to raids, since the addon can't create events.
- Two releases: **v0.3.0** read-only (events, line-up, roles, counts,
  attunement) and **v0.3.1** actions (sign-up buttons, reminders, invite all).

*Alternative, not recommended:* addon-only events. Anyone could create
them with no roles, but members without the addon can't see them,
someone has to be online to share them, and they're easy to spam.

## 7. Milestones and future plans

Item IDs (A1, B1 …) refer to [docs/FEATURE-REVIEW.md](docs/FEATURE-REVIEW.md),
which explains where each idea came from.

### Done (awaiting in-game test)
- **v0.1**: collection, sync, Roster/Character/Settings tabs, `/sk`,
  `/sk debug`, minimap button, theme, tests, CI, packager.
- **v0.1.1**:
  - A1 status dots (online with addon / without / offline)
  - A2 alts grouped under their main (mutually confirmed), "Make this my main"
  - A3 public and officer notes (officer only where allowed, never synced)
  - A4 addon version column and "needs an update"
  - A5 missing-enchant markers
  - A6 cooldowns refreshed from the spell API
  - A7 privacy toggles (share gear/talents, share recipes)
- **v0.1.2** (guild requests):
  - raid attunement filter on the Roster (Attuned column, filters, counter, max level only)
  - "Ask for latest" on the Character tab (RQ by whisper; the owner rebuilds first)
  - faster updates (`HI` 30 s after a change instead of 60 s)
- **v0.2.0**:
  - Crafters tab: search a recipe or item, see who can make it, Whisper, post to guild chat (B7)
  - B1 "Crafted by" lines on every item tooltip (`TooltipDataProcessor`)

### Agreed roadmap (revised 2 Nov 2026 after the GPT, Manus and Perplexity reviews)

How each proposal was judged: [docs/PLAN-REVIEW.md](docs/PLAN-REVIEW.md). This
section is the single source of truth for order and status.

- **v0.2.1 launch readiness** — ✅ code complete 2 Nov. No new message types:
  - attunement fix: Barrow Deeps and Hyjal need none; Onyxia quest **and**
    Drakefire Amulet in bags; MC/BWL/Naxx hidden from the picker
  - `/sk debug`: last errors, calendar probes, GUID stability, unlearned recipes
  - sync hardening: 32 KB message cap, per-sender rate limit
  - sharing preview in Settings; clearer "relayed / stale / not scanned" labels
  - Copy as text (Roster, Crafters) for Discord (D8)
  - "update available" in the Roster counter
- **v0.2.2 Overview** — ✅ code complete 2 Nov (moved ahead of the test gate
  at the owner's request; read-only, no protocol change): Overview tab with
  Guild, Raids, Data health, Professions (B5 coverage), Recipes
  (single-crafter) and Recent milestones (P7, local only, never synced).
- **Test gate** (4–7 Nov): owner runs TESTING.md; **v0.2.3** = fixes only,
  plus an API contract check in CI (P17).
- **v0.3 Raids** (before 9 Dec): `docs/prompts/next-v0.3-raids.md`, plus a
  readiness card (P11) and a duplicate-alt sign-up check. Addon-native events
  (P13) only if the calendar turns out to be unusable.
- **v0.4 Professions** (Dec): cooldown board (B4), specialisations (B3),
  reagents (B2), favourites (B6); camp planner (P6) once its data is verified.
- **v0.5 Coordination** (Jan): craft requests (D1), status line (P8),
  lockout board (P15).
- **v0.6 Polish:** ember animation, long spec names, two-column Character tab.

### Later (in rough priority order)
(D1 craft requests moved to v0.5; D8 export moved to v0.2.1.)
- Per-step Onyxia attunement tracker (P10), once its quest IDs are verified
- Legacy/guild goals (P16, Manus stage 4), if the client exposes them
- Officer announcements and short guild notes (GPT 4.7, kept small)
- D2 raid attendance from the raid group (30/60/90 days)
- D6 shopping list and reagent totals
- D5 guild bank snapshot viewer (only if the guild uses the bank)
- D3 loot history of epic drops. Check Midnight restrictions on loot events
  in raids first, and consider recommending Gargul instead
- D7 `!sk <item>` guild-chat lookup for members without the addon. Only if
  Forever allows automatic guild-chat replies (`SendChatMessage` is restricted)
- D4 missing recipes with where to get them (needs a recipe-source table)
- D9 guild fun events (raffles, fishing derby, contests)
- CurseForge release

### Not planned (and why)
Loot council, DKP and soft reserves (use Gargul); consumable and world-buff
checks (Party Buff Tracker Forever, and Midnight blocks reading auras in
raids); officer kick/promote scripts (GRM); replacing Blizzard's guild window
(taint risk); website or Discord sync (against the brief); layers, bounties,
blacklists and group finder (not useful for a PvE guild of 50); addon-observed
activity metrics (feel like surveillance, and the roster already shows last
online); a Retail version (the guild plays Forever); a stronger hash (nothing
secret is synced).

## 8. Decisions so far

- Licence: **MIT**.
- Guild size about **50**, so sync timings assume 50 online at most
  (`HI` every 10 min = ~5 small guild messages a minute in total).
- Libraries: LibStub, CallbackHandler, AceComm + ChatThrottleLib (Ace3
  trunk, BSD), LibSerialize (MIT) and LibDeflate (zlib) are **committed in
  `Libs/`**, with their licence files, so tests use the real code. LibDataBroker
  and LibDBIcon are pulled in by the packager (`.pkgmeta` externals). Without
  them the addon falls back to its own simple minimap button.
- Mac AddOns path: **still to confirm** (Battle.net → Forever → ⚙ → Show in Finder).

## 10. Waiting on you (next time you're at the Mac)

1. Confirm the AddOns folder path (Battle.net → Forever → ⚙ → Show in Finder).
2. In game: `/dump select(4, GetBuildInfo())` and tell me the number.
3. Install a test build, run `/sk debug`, and send me the text.
4. Work through [TESTING.md](TESTING.md).

## 9. Credits / licence

No code copied from other guild-sync addons (Perpetua, ForeverArtisan and
others were not read for code). API facts come from warcraft.wiki.gg,
Blizzard's UI source as mirrored by Gethe/wow-ui-source, and public notes in
the Everloot and bff-wow GitHub issues and PRs. These are credited in
README.md.
