# Short Royalty — addon plan (awaiting approval)

> Status: **v0.1 to v0.2.1 code complete (not yet tested in game).** Roadmap: section 7.
> Researched against Blizzard's own UI source for the Forever client,
> build **1.60.1.70532** (Gethe/wow-ui-source, `forever` branch), plus
> warcraft.wiki.gg's *Patch 1.60.1/API changes* page.
> Nothing here has been run in the game.

---

## 1. Changes to the original brief (pushback)

| # | You asked for | Problem | What I propose |
|---|---|---|---|
| 1 | A new repo `EllisKOsborn/short-kings-addon` | This session can only reach `elliskosborn/forever-shortkings`, which is empty and ready to use. | Use `forever-shortkings`. The in-game folder will still be called `ShortRoyalty`, because the release zip sets that, not the repo name. |
| 2 | Key characters by **Name-Realm** | Forever has **no realms**. Names are two-part (first name + surname) and unique across the region. The exact `sender` format in addon messages is not documented. | Key every character by its **player GUID**, which is stable and unique, and show the roster name. `/sr debug` prints the real formats so we can check them in game. |
| 3 | Data for **all characters on the account** | An addon can only read a character while you are logged in as it. | Each alt is recorded the first time you log in as it, and again on every later login. The window shows "last updated" for each one. |
| 4 | Every client sends a manifest of **every** character every few minutes | With 100 members that is 100 × 100 entries going round guild chat. It grows with the square of guild size and risks throttling. | Each client announces **only its own account's characters**. For members who are offline, a new arrival sends one query when it logs in, and a single peer (chosen with a random delay) offers to fill the gaps. Traffic grows in step with guild size. |
| 5 | "Which recipes **nobody** has" | That needs a list of every recipe that exists. Forever adds 600+ recipes, and no verified list has been published. | Build the list from what members see: when anyone opens a profession window, record **unlearned** recipes too, not only learned ones. "All recipes" = everything any member has seen. The list grows as people scan. Caveat: this depends on the Forever profession window showing unlearned recipes, which I'll check in game. |
| 6 | Reputations with "the major raid factions" | Forever adds new raids (Barrow Deeps, Hyjal Summit), so its factions may differ from Classic. Hard-coding Classic faction IDs would be guessing. | Record **every** faction the character can see. A short highlight list (`Data/Factions.lua`) marks each entry as *verified* or *TODO*. |
| 7 | Attunements table | Only the Onyxia attunement is confirmed for Forever. Raids open on 9 Dec, and Molten Core isn't in the first wave. | Fill in only the quest IDs I can check against two sources, and mark everything else **TODO**. No guessed IDs. |
| 8 | Pause in **raids and dungeons** | Battlegrounds and arenas are instances too, and Midnight's chat-lockdown rules can block addon messages at other times. | Pause in **every** instance type, in combat, and whenever `C_ChatInfo.InChatMessagingLockdown()` is true. Messages wait in a queue and send later. |
| 9 | Show trial members as "can't sync" | Other players can't see from outside that someone is on a trial. A trial member and a member without the addon look the same. | The roster shows **"No data (no addon / trial)"**. On a trial player's own screen, the addon shows a clear notice and turns sending off. |
| 10 | Crafters tab | Forever's Blizzard UI already includes Blizzard's own guild crafter lookup (`C_GuildInfo.QueryGuildMembersForRecipe`). | Keep our tab, because it works for offline members and can search by item name. `/sr debug` reports whether Blizzard's version is turned on. |
| 11 | Talents | Forever's talent window runs on the modern trait system (`C_Traits`), drawn as Classic-style trees. | Store points per tree (e.g. 31/20/0) plus the talent spell IDs and ranks, so anyone can see names and icons whatever their class. |

---

## 2. File layout

```
forever-shortkings/            (zipped as ShortRoyalty/ by the packager)
├─ ShortRoyalty.toc              ## Interface: 16001  (one TOC, no suffix)
├─ embeds.xml                  loads the libraries
├─ Libs/                       fetched by .pkgmeta externals (not committed)
├─ Core/
│  ├─ Init.lua                 namespace, version, event dispatcher
│  ├─ Compat.lua               the only file that calls WoW APIs that vary;
│  │                           detects what exists at runtime
│  ├─ Log.lua                  debug ring buffer (/sr debug)
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
├─ Commands.lua                /sk, /sr debug, /sr scan, /sr reset
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

## 3. Data schema (`ShortRoyaltyDB`, account-wide)

```lua
ShortRoyaltyDB = {
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

Prefix `ShortRoyalty`. Every message is a serialised table
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

**Open questions only the game can answer** (all printed by `/sr debug`):
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
prompt is `docs/prompts/next-v0.4-raids.md`:
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
  `/sr debug`, minimap button, theme, tests, CI, packager.
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
  - `/sr debug`: last errors, calendar probes, GUID stability, unlearned recipes
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
- **Reordered 5 Nov (owner): the guild says professions matter most.**
  **v0.3 Professions** comes first (`docs/prompts/next-v0.3-professions.md`):
  coverage board, one-profession view, specialisations (original-game ones
  only), cooldown board, reagents, favourites, freshness nudges. Craft
  requests (D1) are an optional v0.3.1.
- **v0.4 Raids** (still before 9 Dec): `docs/prompts/next-v0.4-raids.md`, plus a
  readiness card (P11) and a duplicate-alt sign-up check. Addon-native events
  (P13) only if the calendar turns out to be unusable.
- ~~v0.4 Professions~~: moved to v0.3 (see above); camp planner (P6) still
  waits for verified data.
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
- CurseForge release: **in progress (6 Nov)**, steps in `docs/CURSEFORGE.md`

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

## 9. Credits / licence

No code copied from other guild-sync addons (Perpetua, ForeverArtisan and
others were not read for code). API facts come from warcraft.wiki.gg,
Blizzard's UI source as mirrored by Gethe/wow-ui-source, and public notes in
the Everloot and bff-wow GitHub issues and PRs. These are credited in
README.md.

## 10. Once Forever is live (from 4 Nov 2026)

Everything up to v0.2.2 is built but has only run against a simulated
client. This is the order of work once the game is live. Nothing new gets
built until steps 1 to 3 are done.

### Step 1: first evening on your own (about 30 minutes)
1. Download **ShortRoyalty-v0.2.2.zip** from the GitHub **Releases** page
   (under *Assets*). Unzip it so you have `AddOns/ShortRoyalty/ShortRoyalty.toc`
   (path in the README's Install section). Share the same link with the guild.
2. Character screen → **AddOns**: Short Royalty is listed and not "out of date"
   (if it is, tick *Load out of date AddOns* and tell me).
3. In game, type `/console scriptErrors 1` once so Lua errors show.
4. Type `/dump select(4, GetBuildInfo())` and note the number (expect 16001).
5. Open each of your **profession windows** once, and open the **Calendar** once.
6. Type `/sr debug`, copy everything and send it to me. The parts that matter
   most are **"Live-client checks"**, any **"missing:"** lines and
   **"Recent errors"**.
7. Log out and back in on the same character, then `/sr debug` again (checks
   that your character's ID stays the same).
8. Work through TESTING.md items 1–15 and 22–29 (on your own), plus 50–66.

### Step 2: with one guildmate who also has the addon
TESTING.md items 16–21, 30–49: you see each other's data, Ask for latest,
Crafters and tooltips, Copy, the Overview's numbers and milestones.

### Step 3: what your report decides

| Check (from `/sr debug`) | If it's fine | If not |
|---|---|---|
| Interface number is 16001 | nothing to do | change `## Interface:` in `ShortRoyalty.toc`, new build |
| No Lua errors | carry on | fix them first (v0.2.3) |
| "missing:" API lines | carry on | replace or drop what uses them (v0.2.3) |
| You and a guildmate see each other's data | carry on | fix sync before anything else (sender format, roster names) |
| GUID stable between logins | carry on | stop and redesign how characters are identified |
| Profession window lists unlearned recipes | "recipes nobody has" goes into v0.3 | drop that idea; keep coverage and single-crafter counts |
| Calendar present and guild events listed | build v0.4 Raids on Blizzard's calendar | plan addon-only raid events instead (Perplexity P13) before building |
| Drakefire Amulet line resolves | carry on | fix the amulet check |

### Step 4: build queue after the test
1. **v0.2.3: fixes only** from steps 1–3, plus an automatic check in CI that
   every game function we use still exists in Blizzard's Forever code (P17).
2. **Release v0.2.3** with the fixes (v0.2.2, released 2 Nov, is the launch
   build). When you have CurseForge or Wago accounts, releases can go there
   too (P5); I prepare it, you do the upload.
3. **v0.3 Professions** (moved first on 5 Nov: the guild says professions
   matter most). Built 5 Nov (v0.3.0), waiting for the in-game test. Plan:
   section 11. Prompt:
   `docs/prompts/next-v0.3-professions.md`.
4. **v0.4.0 Raids, read-only** (target: before raids open on 9 Dec): raid
   events from the calendar, who signed up with role, spec, item level and
   attunement, role counts, readiness card, Copy. Prompt:
   `docs/prompts/next-v0.4-raids.md`.
5. **v0.4.1 Raids actions:** Sign up / Tentative / Decline buttons, a
   reminder before raids, and "invite everyone signed up" for the raid leader.
6. **v0.5 Coordination** (January): craft requests, a short status line,
   lockout board.

### Step 5: things the guild can find out in game (they unblock later ideas)
- **Onyxia attunement quest IDs** for each step (Wowhead Forever pages show
  them): unlocks the step-by-step attunement tracker (P10).
- **Camping objects**: which professions make which camp objects, at what
  skill, and how they're learned: unlocks the camp planner (P6).
- **Raid lockouts**: whether `/dump GetNumSavedInstances()` returns a number
  after a dungeon (it isn't in the 1.60.1 docs): decides the lockout board (P15).
- **Horde members**: if there are any, their Onyxia chain is different.
- What players ask for in the first two weeks. Real requests beat any plan.

## 11. v0.3 Professions plan (5 Nov 2026, **approved**: "do all of them")

The owner approved all six features on 5 Nov, before the v0.2.7 answers,
and asked that the "reopen" reminders are rare. So v0.3.0 is built to
check each unknown at runtime and hide what the game doesn't support:
"Nobody knows" appears only if the window lists unlearned recipes;
reagents show only if the game returns them; a specialisation counts only
if the game's own spell name matches. Once the v0.2.7 answers arrive,
record them in CLAUDE.md and adjust (e.g. set confirmed spec IDs to
`status = "ok"`).

### Step 1 facts (v0.2.7 probes; answers go into CLAUDE.md)
| Question | Probe line in `/sr debug` | If yes | If no |
|---|---|---|---|
| Window lists unlearned recipes? | "Last scan: … (unlearned listed: YES)" + the "show unlearned" filter | add the *Nobody knows* filter | drop it; keep single-crafter counts |
| Reagents readable with the window **closed**, and for unknown recipes? | "Reagents, a recipe you know / don't know" | read locally, cache in SavedVariables, never synced | readable only while open: cache what each player's own scan sees, still local; propose sync design only if even that fails |
| Specialisation spells known? | "Specialisations" (known=, client name=) | IDs become `status = "ok"`; `spec` field per profession | keep `todo`, no spec column |
| Blueprints / camp objects in the window? | "Recipe categories" (names + examples) | camp planner (P6) becomes possible later | stays parked |

Verified in Forever's API source (5 Nov): `C_TradeSkillUI.GetRecipeSchematic`
(recipeSpellID, isRecraft) → `reagentSlotSchematics[].reagents[].itemID` and
`quantityRequired`; `GetShowLearned`/`GetShowUnlearned`;
`C_SpellBook.IsSpellKnown`. `GetCategoryInfo` is not in the generated docs
but Forever's own `Blizzard_Professions.lua` calls it, so it is probed, not
assumed. Specialisation spell IDs agree on wowhead.com/classic and
classicdb.ch (two sources); the game still has to confirm them.

### Answers so far (owner's v0.2.7 report, 5 Nov, level 1 character with no profession)
- All probed APIs exist in game; the window filter defaults to "show unlearned = no".
- Specialisations: all 10 IDs have the right names in game → confirmed (`status = "ok"`).
- 6 Nov (Herbalism 4/75): **unlearned recipes are listed** (Nobody knows
  works); **Herbalism has a "Camping" category** (Seed Hybridizer,
  Greenhouse, Incense Candle), so gathering professions have recipes;
  reagents come back for an unlearned recipe with the window open; category
  names work. The bundled display font failed to load (fixed in v0.3.0 by
  preloading it, to be confirmed).
- Still open: reagents with the window closed; `IsSpellKnown` for a spec owner.
- **v0.3.1 (7 Nov, owner asked):** every recipe in the game, bundled from the
  game's own data tables via wago.tools (`tools/recipes.js` → `Data/Recipes.lua`,
  IDs only), search by name / group / material, Wowhead links, Getting started.
  This replaced the "share each window's list over sync" idea (no protocol change).
  Wowhead itself isn't used as a data source (its terms forbid copying it).
  Later from the same data: where each recipe comes from (trainer / item).
- **Camp planner (P6) is now possible**: the camping recipes, their
  categories and reagents are all readable. Candidate for v0.3.x/v0.5,
  only if the owner asks.

### Proposed default order (owner to confirm the guild's top 3)
1. **Guild coverage board + one-profession view** (crafters with skill and
   "recorded 3d ago", recipe list with crafter counts, filters). Builds on
   data everyone already sends; biggest everyday use.
2. **Reagents** in the Crafters side panel and profession view (local, plus
   "you have 3 / need 5" from your bags).
3. **Cooldown board** (who can transmute / make cloth now). `cds` already syncs.
4. Favourites (stars, local only).
5. Specialisations (only once the probe confirms the IDs).
6. Freshness nudges ("Tailoring went from 240 to 262, open the window").

### What went into v0.3.0 (built 5 Nov, not released)
- All six above. No new message types; guildmates on v0.2.5+ keep working.
  New profile field `profs[skillLine].specs` (list of up to 4 spell IDs,
  checked in `Merge.FIELDS`; older versions ignore it). Favourites,
  reagents and nudge state are local only.
- Reminders: +15 skill since the last scan; chat at most once per session
  and once every 3 days; Settings toggle; also shown on the tab.
- Not done: tooltip specialisation lines (item 8 of the prompt), because
  which item needs which specialisation isn't verified data.
- **v0.3.1 (only if asked):** craft requests (D1, a new message type).
- **Later:** shopping list (D6), camp planner (P6) if the categories show
  camp objects, "where to get it" (D4) only with a verified data source.

## 12. Roadmap review (7 Nov 2026, after v0.3.6)

Where we are: professions (v0.3.x) are done and the sync fix is out. The guild
is **levelling** (owner level 15; 27 members, 8 sharing data), and raids
open on **9 Dec**. The owner asked what to build next.

### Recommended now
| # | What | Why now | Size | Notes |
|---|---|---|---|---|
| 1 | **Raids tab, read-only (v0.4.0)** | The 9 Dec deadline; needs time for in-game testing | L | `docs/prompts/next-v0.4-raids.md`: calendar events, who signed up with spec, role, ilvl, attunement, role counts, readiness card. Nothing new on the wire except a main/second role in the profile |
| 2 | **API safety check in CI (P17)** | Agreed on 2 Nov, never built. A Forever patch that renames an API would break things silently | S | CI compares every API the addon calls against Blizzard's Forever source |
| 3 | **Levelling buddies** (new) | The guild is levelling *now*; data is already there (roster level, zone, online) | S | Overview card: "Online near your level (±3)": name, level, zone, Whisper and **Invite** (button press only; `C_PartyInfo.InviteUnit`). No new sync |
| 4 | **"Ask them to install" button** (new) | Adoption is the real bottleneck (8 of 27 share data) | S | Next to "Not seen with the addon yet": pre-types a guild-chat line with the CurseForge link; you press Enter (never sent automatically) |
| 5 | **Craft requests (D1)** | Professions are the guild's top priority; the natural next step | M | "Ask to craft" in Crafters; the crafter gets a request list with reagent totals and marks it done. New message type, owner-only |
| 6 | **Shopping list (D6)** | Builds on reagents and favourites | S–M | Pick recipes and quantities, see total reagents and "have / need" from your bags. Local only |
| 7 | **Automatic "my alts"** | Only if the owner's Warband currency test lists alts | S | `C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters` → automatic claims |

### Keep for later (unchanged reasons)
Raid actions (sign-up buttons, invite everyone; v0.4.1, after v0.4.0 is
tested); lockout board (P15, needs raids and a verified API); status line
(P8, first free text on the wire); attendance (D2); Onyxia step tracker
(P10, needs verified quest IDs); camp planner (P6, needs verified data);
guild bank viewer (D5); loot history (D3, prefer Gargul); `!sr` chat
lookups (D7, `SendChatMessage` is restricted).

### Not planned
Same list as section 7, plus: no automatic alt detection beyond the
player's own account (addons can't see other players' accounts; confirmed by
research on 7 Nov).
