# Perplexity Plan: review and (maybe) implement

Written 2 Nov 2026 by Perplexity Computer at the owner's request, after a review of
this repo, Blizzard's Forever 1.60.1 UI source and the public pages of the other
Forever and Retail guild addons. The owner asked Claude to **review** this and
**implement what makes sense**.

## How to use this document (read first)

- This is a set of **proposals, not orders**. The owner wants you to push back.
  For each item, decide **Accept / Modify / Reject** and record it in
  [section 7](#7-review-log) with one line of reasoning before you build anything.
- Read `CLAUDE.md` and `PLAN.md` first. Every rule there still applies:
  `Compat.lua` is the only file that calls client APIs, **never guess an ID**,
  tests + clean `luacheck .` + README / CHANGELOG / TESTING updates (and mockups
  if the UI changes) with every change, and never claim anything works in game
  until the owner confirms.
- The owner is not a developer and is usually on a phone. Explain what you did
  in plain language and keep replies short.
- **Plan first** for anything marked M or larger: write a short design note in
  `PLAN.md` before coding.
- Facts below come from sources linked in [section 8](#8-sources). Where I could
  not verify something, it is marked **VERIFY** and you must not hard-code it.
- Effort: S = a day or less, M = a few days, L = a week or more.

## 0. Context that changes priorities

- **Launch is 4 Nov 2026 and raids open 9 Dec**, so there are five weeks of
  levelling first. The current roadmap puts raids before levelling-phase
  features. Section 6 proposes a different order.
- **Nothing has run in game.** The test stub is written by the same author as the
  code, so it can only confirm our own assumptions. Proof in game beats any new
  feature.
- **The other addons are broader than us.** Guild OS, Guild Muster, ForeverGuild+
  and Guilded all have more features. Our edge is: no website, no companion app,
  strong privacy, and tailored to one guild of about 50. Prefer ideas that lean on
  that over feature parity.
- `docs/FEATURE-REVIEW.md` (1 Nov) is out of date: it lists 8 addons; at least 8
  more are live for Forever (see section 8).

## 1. Corrections to existing data (do these first)

### P1. Fix the attunement table (S)
**Why:** Blizzard's raid overview says Barrow Deeps (10) and Hyjal Summit (20) have
no attunement, and Onyxia's Lair (40) requires the **Drakefire Amulet in the
player's inventory** (not equipped). Wowhead agrees on "no attunement" for the
first two. Today the repo shows Barrow and Hyjal as grey "unknown" and checks only
a quest flag for Onyxia.

**Proposed changes**
- `Data/Attunements.lua`: mark `barrow` and `hyjal` as `status = "none"`
  ("No attunement needed"). Roster raid mode must treat them as everyone-attuned
  and show a neutral label instead of grey ticks.
- Hide `mc`, `bwl` and `naxx` from the raid picker until Blizzard announces them
  (keep the data).
- Onyxia: keep the quest check (6502, Alliance final step, already in the file) and
  **add an item check** for the amulet. **VERIFY** the amulet's item ID against two
  sources (Wowhead Forever and one other) before adding it. Report "quest done" and
  "amulet in bags" separately; only the character themselves can check their own
  bags, so the owner copy carries it in the profile.
- Update `docs/FEATURE-REVIEW.md`: Gargul now has a Forever build (v8.0.1-forever,
  v8.0.2 fixes Forever names), so the "use Gargul for loot" decision stands.

**Acceptance:** tests for "none" status and for the amulet flag; the Roster raid
picker lists only Barrow, Hyjal and Onyxia; README "What's inside" and
CHANGELOG updated; `/sk debug` prints whether the amulet item ID resolved.

### P2. Fix tense and stale status in CLAUDE.md (S)
`CLAUDE.md` says "Launch was 4 Nov 2026" while the repo was written before launch.
Change it to a dated statement ("launches 4 Nov 2026; update after the live client
is checked") so a future session does not assume live-client facts were verified.

## 2. De-risk before building more (week of launch)

### P3. In-game proof pass (S, needs the owner)
Extend `/sk debug` with the probes that decide the plan, then ask the owner to run
it on the live client and paste the output:
- `select(4, GetBuildInfo())` (expect 16001) and the CHAT_MSG_ADDON sender format.
- Whether player GUIDs are stable between sessions.
- Whether `GetGuildRosterInfo` exists and returns GUIDs.
- **Calendar probes** (new): is `C_Calendar` present; does the Blizzard calendar
  open; does `C_Calendar.GetNumGuildEvents` return a number; is
  `C_Calendar.AddEvent` restricted as documented.
- Whether the profession window lists unlearned recipes.

**Why now:** the Raids tab (v0.3) is built entirely on the Blizzard calendar being
usable. The calendar code ships in the Forever UI (with Forever-specific filter
data), but no Blizzard announcement says it is enabled, and one third-party guide
says no in-game calendar is announced. A five-minute probe decides whether v0.3 is
calendar-based (current plan) or addon-native (P13).

### P4. Built-in error capture (S)
**Why:** if a member has no BugSack, a Lua error in our code is invisible to them
and to the owner. `Init.lua`'s `callAll` already wraps module hooks in `pcall`.

**Proposed:** keep the last ~10 errors (message, module, hook, time, addon version)
in memory and append them to the `/sk debug` and `/sk log` report. Add a
"Copy report" button in the Debug window (already copyable text). No network, no
saving to disk beyond what exists.

**Acceptance:** a spec that forces a module hook to throw and checks the report
contains it; luacheck clean.

### P5. Distribution and update nudges (S-M)
**Why:** an addon that only works between people who have it fails when half the
guild runs an old build. The release workflow and `.pkgmeta` already exist, but
CurseForge is the last roadmap item.

**Proposed**
- Move the CurseForge (Forever file) and Wago release **earlier** (today
  CurseForge lists a Forever game version, 1.60.1; a third-party guide says WowUp
  has beta support).
- In-game: a one-line banner on the Roster ("Short Kings 0.2.1 is out. You have
  0.2.0") using the version data already received. Already have the Ver column; this
  makes it visible without looking.
- Install steps in README must match whatever the CurseForge/WowUp route is.

**Needs the owner:** CurseForge and Wago accounts and project approval. Do not
create accounts or upload anything yourself; prepare the packaging and ask.

## 3. Levelling-phase features (4 Nov to 9 Dec)

### P6. Camp Planner (M, Forever-only)
**Why:** Blizzard's [campfire post](http://worldofwarcraft.blizzard.com/en-us/news/24301516)
describes the Camping system: Cooking creates a Basic Campfire; it supports up to
three profession-made objects, one per nearby player; effects last about an hour and
are exclusive with the matching class buffs. Most professions have objects at skill
**20, 140 and 300**. None of the guild addons I read mention camp coordination, and
we already collect profession and skill data.

**Proposed**
- New tab or Professions sub-view **Camps**: for each profession, which camp object
  tier a guildmate can contribute (from skill 20/140/300), who is online, and a
  suggested "best three" combination from online members (distinct professions,
  highest-value buffs first). Show the Cooking skill that sets campfire capacity.
- A **button that prefills guild chat** (`ChatFrameUtil.OpenChat("/g ...")`, never
  `SendChatMessage`), e.g. "Camp at <zone>: Sharpening Wheel + Incense Candle, need
  one more". Zone from the player's current map; coordinates only if the API
  allows it (**VERIFY**).
- Start with the skill-tier proxy. Move to the exact learned camp-object spells only
  after the owner's `/sk debug` shows how they appear in the spellbook.

**VERIFY before coding:** the object names/effects per profession (from Blizzard's
table, not a fan site), the spell IDs, and whether an object is "known" by recipe,
trainer purchase or quest. Do not list objects by name until verified.

**Acceptance:** `Data/Camps.lua` with `status` per entry (`verified` / `todo`),
pure-function tests for the "best three" picker, UI smoke spec, README/CHANGELOG/
TESTING entries, a mockup.

### P7. Levelling feed and Race to 60 (S-M)
**Why:** the guild is levelling for five weeks. When a profile arrives we already
hold the previous one, so we can detect changes at no network cost. Guild Muster has
a Race to 60 and a "Grats!" button; the feed adds recipes and professions.

**Proposed**
- On profile merge, compute events from old vs new: crossed level 20/40/60;
  first of each class at 60; profession reached 75/150/225/300; new notable recipe.
  Store the last ~50 locally (`ShortKingsDB`), **never sent over the wire**: each
  client derives its own feed, so there is no new protocol.
- Roster header "Recent" strip with a **Grats!** button that prefills `/g`.
- Setting to turn the feed off. No popups by default.

**Edge cases to test:** first profile ever received (no previous: emit nothing, so a
fresh install does not announce 50 people), restored data after a reset, relay
copies arriving out of order, guild members who left.

### P8. Status line (S-M)
**Why:** replaces a full group finder with something tiny. Guild Muster,
ForeverGuild+ and Pandy all have guild-first group finders, so there is demand, but
we do not need their size.

**Proposed:** one short free-text-ish field chosen from presets plus custom text
(max ~40 characters), e.g. "LFG: BRD, tank", "Camping at Redridge", "Crafting, DM
me", "Need help: elite quest". Carry it in the **existing `HI` message** (protocol
change: bump the protocol number, keep backward compatibility with older versions
that ignore the field). Expire it after a time-to-live (e.g. 60 minutes) so stale
statuses do not linger. Show as a Roster column and in the tooltip.

**Rules:** sanitise on receive (length, control characters, escape codes `|`),
because this is the first free text on the wire; rate-limit changes; never use it
for anything but display.

### P9. Copy for Discord (S)
Pull `D8` forward. "Copy as text" buttons on Roster (filtered view), Crafters
results, and later the raid line-up and a weekly digest. Output plain text that
pastes cleanly into Discord (no WoW colour codes or textures). Use the existing
copyable text window.

## 4. Raid-season features (before 9 Dec)

### P10. Drakefire Amulet tracker (M)
**Why:** Onyxia is a 40-player raid for a guild of about 50 and every player needs
the amulet. [Blizzard describes the Alliance chain](https://worldofwarcraft.blizzard.com/en-us/news/24303009/world-of-warcraft-forever-raid-overview-locations-raid-sizes-and-attunement)
as ten stages (Dragonkin Menace, six "The True Masters" quests, Marshal Windsor,
Abandoned Hope, A Crumpled Up Note, A Shred of Hope, Jail Break!, Stormwind
Rendezvous, The Great Masquerade, The Dragon's Eye) ending with the Upper Blackrock
Spire quest. Other addons show only yes/no attunement (from what I read).

**Proposed:** per member, store the **current step** in the profile; a Raids/Attune
view groups members by step ("5 at Blackrock Depths steps, 2 need UBRS") so officers
can organise group runs for the elite quests. Alliance only to start (confirm with
the owner whether any Horde members exist).

**VERIFY:** every quest ID against two sources (Wowhead Forever plus one other)
and that Forever uses the Classic IDs. The repo rule stands: unknown IDs stay
`status = "todo"`. Only 6501 (The Dragon's Eye) and 6502 (Drakefire Amulet)
appeared in my research; I did not verify the rest.

**Profile size:** one small integer per member; no protocol change beyond a new
profile field (bump profile version, tolerate missing field on old clients).

### P11. Raid Night card (M)
**Why:** consumable and buff checks are out (Midnight blocks reading auras in
raids, and Party Buff Tracker Forever covers it). A card built only from **synced
data** avoids that limit.

**Proposed:** for a chosen event (v0.3) or raid: signed-up count by role, item
level, missing-enchant count, amulet for Onyxia, and camp coverage (P6) for the
roster. A **Copy summary** button (P9).

### P12. v0.3 Raids on the Blizzard calendar (existing plan)
Keep `docs/prompts/next-v0.3-raids.md` as is **if P3 shows the calendar works**.
Otherwise use P13.

### P13. Addon-native events as a fallback (M-L, only if P3 fails)
Build an "event source" interface behind the Raids tab with two backends: Blizzard
calendar (v0.3) and a synced event list: any member posts a raid, sign-ups travel on
the guild channel, officers can pin or cancel, ids are `guid + counter`. The UI
stays the same. Plan this in `PLAN.md` before coding; it needs a new message type,
merge rules and a spam limit. `PLAN.md` section 6 lists why this is the weaker
option, which is why it is a fallback.

## 5. Later and hardening

| # | Idea | Note |
|---|---|---|
| P14 | **Craft requests** with reagent totals (D1 + D6) | Move above the Professions tab. Guild Muster's "Ask to craft" and Retail's crafting orders set the expectation. New synced message type |
| P15 | **Lockout board** ("saved to which raid, free for alt runs") | Guild Muster has it. **VERIFY** `GetSavedInstanceInfo` works in Forever |
| P16 | **Legacy tree viewer** | Guild Muster shows it. Only if the API allows a reliable read (**VERIFY**) |
| P17 | **API contract check in CI** | Add a CI job that sparse-clones the `forever` branch of Gethe/wow-ui-source (command in `CLAUDE.md`) and checks every API name used in `Compat.lua` against `Blizzard_APIDocumentationGenerated`, plus the `SecretArguments` / `SecretReturns` flags. By hand, 50 of 54 `C_*` calls were documented; the 4 missing are the known `C_TradeSkillUI` ones. Make the exceptions an explicit allow-list |
| P18 | **Decompression cap** in `Codec.Decode` | `MAX_ENCODED` limits compressed size (96 KB) but LibDeflate has no output limit, so a crafted message could expand hugely. Senders must be guildmates, so low risk; consider a much smaller compressed cap and a time budget |
| P19 | **Per-sender rate limit** on incoming messages | Same low-risk class as P18 |
| P20 | **Stronger hash** | Adler32 detects change only. Only matters if you ever sync something sensitive |

## 6. Suggested order

1. **2-3 Nov (before launch):** P1, P2, P4, P5 (prepare packaging).
2. **4-5 Nov:** P3 on the live client with the owner; run `TESTING.md`.
3. **Weeks 1-3:** P7, P8, P9, then P6.
4. **Weeks 3-5:** P10, then v0.3 (P12, or P13 if the calendar fails) with P11.
5. **After 9 Dec:** P14-P20 and the Professions tab.

## Explicitly not recommended (agree with existing "not planned")
Loot council / DKP / soft reserves (use Gargul), consumable and buff checks,
officer kick/promote tools, a website or companion app, and a Retail port.

## 7. Review log

Fill this in as you go. One row per item.

| Item | Decision (Accept / Modify / Reject) | Reason | Status |
|---|---|---|---|
| P1 | Modify | Verified (Blizzard overview + Icy Veins; item 16309 via wiki.gg + Wowhead Forever). Amulet shown alongside the quest, not replacing it | v0.2.1 |
| P2 | Accept | Dated wording | v0.2.1 |
| P3 | Accept | Calendar, GUID stability, sender and unlearned-recipe probes | v0.2.1 (owner runs it) |
| P4 | Accept | Last 10 errors in the report | v0.2.1 |
| P5 | Modify | "Update available" line now; store releases need the owner's accounts | v0.2.1 (line) |
| P6 | Reject for now (defer) | Camp objects and spells unverified | after verification |
| P7 | Accept | Local only, after the first test round | v0.2.3 |
| P8 | Reject for now (defer) | Free text on the wire + protocol change before validation | v0.5 |
| P9 | Accept | = PLAN D8 | v0.2.1 |
| P10 | Modify | Quest + amulet now; per-step tracker needs verified quest IDs | partly v0.2.1 |
| P11 | Modify | Merged into the v0.3 line-up | v0.3 |
| P12 / P13 | Accept P12; P13 only if P3 shows the calendar is unusable | | v0.3 |
| P14-P20 | P14 defer, P15 defer, P16 defer, P17 accept (v0.2.2), P18 accept, P19 accept, P20 reject | See docs/PLAN-REVIEW.md | |

## 8. Sources

- Blizzard, [Forever Raid Overview: locations, raid sizes and attunement](https://worldofwarcraft.blizzard.com/en-us/news/24303009/world-of-warcraft-forever-raid-overview-locations-raid-sizes-and-attunement)
- [Wowhead: Forever raids overview](https://www.wowhead.com/forever/guide/raids-overview-hub-dates-locations)
- Blizzard, [Gather Around the Campfire in World of Warcraft: Forever](http://worldofwarcraft.blizzard.com/en-us/news/24301516)
- [Gethe/wow-ui-source, `forever` branch](https://github.com/Gethe/wow-ui-source/tree/forever) (API docs)
- Addons: [Guild OS](https://www.curseforge.com/wow/addons/guild-os),
  [Guild Muster](https://www.curseforge.com/wow/addons/guild-muster),
  [ForeverGuild+](https://www.curseforge.com/wow/addons/foreverguildplus),
  [Guilded](https://www.curseforge.com/wow/addons/guilded),
  [Perpetua](https://github.com/Damndionic/Perpetua),
  [Ultimate Profession Master](https://www.curseforge.com/wow/addons/togprofessionmaster),
  [Gargul](https://www.curseforge.com/wow/addons/gargul),
  [Guild Paragon](https://addons.wago.io/addons/guild-paragon),
  [Pandy Guild Management](https://www.reddit.com/r/WowUI/comments/1xf28ou/addon_pandy_guild_management_guild_management/),
  [FlockSync](https://github.com/GearDuckDev/FlockSync),
  [Guild Roster Manager](https://www.curseforge.com/wow/addons/guild-roster-manager)
- Third party (lower trust): [WoW Forever Tier List: guild tools](https://wowforevertierlist.com/guilds/tools),
  [wow4ever.quest addon install guide](https://wow4ever.quest/en/addons)
