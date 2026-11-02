# Short Kings: project notes for Claude

Read this first in every session. Keep it current: if you change a decision,
the status or a convention, update this file in the same commit.

## What this is
A World of Warcraft: **Forever** addon for the guild **Short Kings**
(Alliance, PvE, about 50 members). Members browse each other's gear,
talents, professions, recipes, attunements and reputations in game. Data is
shared only over the guild **addon channel**: no website, no server, no uploads.

## The person you're working with
- **Not a developer**, often on their **phone**. Explain steps in plain
  language, keep replies short, and put long material in repo files.
- Wants you to **push back** on bad ideas and to **plan first** for big changes.
- Relays questions and requests from guild members.
- **Never claim anything works in game** until they confirm it. Everything so
  far is tested only against a stubbed WoW API.

## Platform facts (verified, keep using the same sources)
- Forever client **1.60.1, build 70532**, Mainline (12.x) UI with Midnight
  "secret value" restrictions. TOC game type `camelot` (alias `forever`).
- TOC **`## Interface: 16001`** (beta value, still to be confirmed in game).
  Single TOC with no suffix. The BigWigs packager detects it as Forever.
- **Source of truth for APIs:** Blizzard's UI source, `forever` branch of
  Gethe/wow-ui-source. Sparse-clone it and grep
  `Interface/AddOns/Blizzard_APIDocumentationGenerated/` plus the
  `*/Camelot/*` UI files:
  ```sh
  git clone --depth 1 --branch forever --filter=blob:none --sparse https://github.com/Gethe/wow-ui-source.git src
  cd src && git sparse-checkout set Interface/AddOns/Blizzard_APIDocumentationGenerated
  ```
  warcraft.wiki.gg's 1.60.1 API-change page was **wrong** about some
  removals (e.g. `C_SkillInfo.GetSkillLineInfo` still exists). Trust the
  source, not the wiki.
- Verified facts:
  - Item/spell names: `C_Item.GetItemNameByID`, `C_Item.RequestLoadItemDataByID`
    (event `ITEM_DATA_LOAD_RESULT` itemID, success), `C_Spell.GetSpellName`,
    `C_Spell.RequestLoadSpellData` (`SPELL_DATA_LOAD_RESULT`). Quality:
    `C_Item.GetItemQualityByID` + `C_Item.GetItemQualityColor`.
  - Item tooltips: `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)`
    (`Item` = 0); `data.id` is the item ID.
  - Chat box: `ChatFrameUtil.OpenChat(text)` (edit box parses a leading
    `/g `); whisper `ChatFrameUtil.SendTell(name)` (both in
    `Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua`). `ChatFrame_OpenChat`
    is only a fallback.
  - Professions use `C_TradeSkillUI`; the Classic `GetTradeSkillInfo` and
    `GetCraftInfo` are gone.
  - Talents are `C_Traits` trees.
  - The guild roster is `C_Club` plus legacy `GetGuildRosterInfo`.
  - `C_Calendar` exists, but `AddEvent` is restricted.
  - `SendChatMessage` is **restricted** (only send on a button press, or
    prefill the chat box instead).
  - Whisper with `ChatFrameUtil.SendTell` (`ChatFrame_SendTell` is gone).
  - `TooltipDataProcessor` exists.
  - `C_Spell.GetSpellCooldown` returns a table.
  - Trial accounts can't send addon messages.
- **Realmless:** characters have two-part names that are unique per region.
  Key everything by **player GUID**. The `sender` format in addon messages is
  unconfirmed, so `Core/Identity.lua` matches it several ways.
- Forever launches **4 Nov 2026** (written 2 Nov; update once the live client
  has been checked). Raids open 9 Dec: Barrow Deeps (10) and Hyjal Summit (20)
  need **no attunement**; Onyxia's Lair (40) needs the **Drakefire Amulet
  (item 16309) in your bags**, not equipped (Blizzard's raid overview, checked
  2 Nov). Molten Core, BWL and Naxxramas aren't in the first wave.

## Rules
- **`Core/Compat.lua` is the only file that calls client-specific APIs.**
  Detect each API at runtime and degrade gracefully.
- **Never guess IDs** (quests, factions, spells). Verify them against two
  sources or mark them `status = "todo"` in `Data/*.lua`.
- **Don't copy code** from other guild-sync addons (Perpetua has no licence).
  Reading their feature lists is fine. Credit sources in README.
- Pause sync in combat, in every instance type (party/raid/pvp/arena/scenario)
  and during `C_ChatInfo.InChatMessagingLockdown()`. All sends go through
  ChatThrottleLib via AceComm.
- **Privacy:** notes and officer notes are never synced. Our own characters
  keep a **full** profile in `ShortKingsDB.own[guid]`, and only the
  **public** copy (`Profile.Public`, which respects the share toggles) goes
  into `guild.profiles` and onto the wire.
- Every change ships with:
  - busted tests;
  - a clean `luacheck .`;
  - updates to `README.md` ("What's inside" lists **everything**), `CHANGELOG.md` and `TESTING.md`;
  - updated mockups in `docs/mockups/` when the UI changes (`node docs/mockups/render.js <font>`).
- Commit as you go. Never create a PR unless asked. Push to your designated branch.
- **`main`** holds the released state (created 2 Nov 2026 with v0.2.0;
  v0.2.2 pushed 2 Nov). Push to `main` only when the user asks; the README's
  test badge tracks it.
- **Releases:** pushing a tag `vX.Y.Z` on `main` runs `.github/workflows/release.yml`
  (BigWigs packager): it builds `ShortKings-vX.Y.Z.zip` and a GitHub Release
  whose notes come from CHANGELOG.md (`.pkgmeta` manual-changelog). First
  release: **v0.2.2** (2 Nov 2026, the launch build). Tag only when the user asks.

## Layout
```
ShortKings.toc  embeds.xml  Commands.lua (/sk, /sk debug report)
Core/     Init (events, timers, modules), Log (+ error capture: SK:Safe,
          SK:RecordError), Compat, DB (SavedVariables, pruning), Identity
          (roster, sender→GUID, Status dots, GUID-stability check), Alts
          (mutual-link groups), CraftIndex (recipe/item → crafters, async
          names), Export (plain text for Copy), Feed (local milestones,
          never synced), Overview (numbers for the Overview tab)
Data/     Professions, Attunements (quest IDs), Factions, Enchants
Collect/  Character, Talents, Professions (recipe scan), Reputation,
          Attunements, Profile (full/public copies, cooldowns, main)
Sync/     Codec (LibSerialize stable → LibDeflate), Merge (rules), Sync (protocol)
UI/       Theme (colours/gradients only), Widgets (Button, Tab, Check, Menu,
          SearchBox, List, TextPanel), MainFrame, OverviewTab (first tab,
          six cards with deep links), RosterTab (+ raid filter, Oldest first),
          CharacterTab (+ Ask for latest), CraftersTab, SettingsTab,
          DebugWindow, Minimap, Tooltip ("Crafted by" line)
Libs/     vendored Ace3 bits, LibSerialize, LibDeflate; LDB + LibDBIcon via .pkgmeta
tests/    busted specs; tests/helpers/wow.lua is the stubbed WoW API
docs/     FEATURE-REVIEW.md, mockups/, images/, prompts/
```

## Sync protocol (prefix `ShortKings`, protocol 1)
| Msg | Channel | Purpose |
|---|---|---|
| `HI` | GUILD | Own account's characters `{g, u, h}`. Sent at login, every 10 min, and 30 s after changes (debounced) |
| `RQ` | WHISPER | Request profiles. Also "Ask for latest" (max 1 per target per 30 s); an RQ for the logged-in character rebuilds it first (not in combat, max every 10 s) |
| `PR` | WHISPER | One profile per message |
| `SQ` | GUILD | Once per session: what I hold |
| `SO` | GUILD | Backfill offer, random 2–8 s delay, suppressed if someone else offers first |

Merge rules (`Sync/Merge.lua`, tested):
- The character must be a guild member.
- Timestamps more than 5 min in the future are rejected.
- The hash must match the content.
- Our own characters are never overwritten.
- An owner copy beats any relay copy.
- A relay copy is accepted only if strictly newer.

Alts link only when **both** profiles list each other in `family`.

Input limits (v0.2.1): `Codec.MAX_ENCODED` 32 KB (worst-case profile ~11 KB),
max 60 incoming messages per sender per minute (`Sync.RATE_MAX`), and
oversized outgoing messages are recorded as errors, not sent.

## Dev environment notes (cloud sessions)
- Lua 5.1 tooling: `apt-get install lua5.1 liblua5.1-0-dev luarocks`, then
  `luarocks --lua-version=5.1 install busted luacheck`. GitHub *archive*
  downloads are blocked by the proxy: when a rock fails, `git clone` its
  repo at the tag and run `luarocks make <rockspec>` (lua-term and
  mediator_lua needed this).
- Run `busted --lua=lua5.1` and `luacheck .`. CI (`.github/workflows/ci.yml`)
  runs both and builds a test zip artifact.
- Mockups: Playwright and Chromium are preinstalled. The stand-in font is
  Marcellus from fonts.gstatic.com (don't commit the font).

## Status (2 Nov 2026)
- v0.1 to v0.2.2 are code complete, **not tested in game**. See CHANGELOG.md.
  v0.2.2 = the Overview dashboard (owner asked for it before the test gate).
  (`docs/prompts/next-v0.1.2-v0.2.md` is done; v0.2.1 = launch readiness
  from `docs/PLAN-REVIEW.md`.)
- Roadmap and future plans: `PLAN.md` section 7. Background and reasoning:
  `docs/FEATURE-REVIEW.md`.
- Outside proposals (`docs/GPT-PLAN.md`, `docs/MANUS-PLAN.md`,
  `docs/PERPLEXITY-PLAN.md`) were reviewed on 2 Nov: verdicts in
  `docs/PLAN-REVIEW.md`, agreed order in **PLAN.md section 7** (the single
  roadmap). Don't build from the proposal files directly.
- **Next:** PLAN.md **section 10, "Once Forever is live"**: the in-game test
  gate (TESTING.md, `/sk debug` "Live-client checks"), its decision table,
  v0.2.3 fixes only, a first tagged release, and **v0.3 Raids** before 9 Dec
  (`docs/prompts/next-v0.3-raids.md`). Professions tab is v0.4.
- Calendar facts (1.60.1 docs): invites carry `guid`; no role field; only
  `AddEvent` is `HasRestrictions`; `GetDayEvent`/`EventGetInvite` are secret
  during chat lockdown; `C_PartyInfo.InviteUnit` and `ConvertToRaid` exist.
- Decisions in v0.1.2/v0.2.0:
  - Roster raid mode uses a **second List** with its own columns (Attuned
    replaces Professions and Ver) instead of rebuilding the List widget.
  - Attunement shows "unknown" when the player hides gear/talents.
  - Attuned marks use the ready-check atlases (`UI-LFG-ReadyMark` etc.):
    the game font has no ✓/✗ glyphs.
  - CraftIndex lives in `Core/` (no UI); `Identity.Status` moved there from
    RosterTab so Sync and CraftIndex can use it.
  - Names: `C_Item.GetItemNameByID` / `C_Spell.GetSpellName`, with
    `RequestLoad*` + `ITEM_DATA_LOAD_RESULT` / `SPELL_DATA_LOAD_RESULT`
    (event approach, not the Item mixin), at most 200 requests per search.
  - "Post to guild chat" uses `ChatFrameUtil.OpenChat("/g …")`; never
    `SendChatMessage`.
- Decisions in v0.2.2:
  - Overview numbers come from `Core/Overview.lua` (pure); attunement logic
    lives in `Collect/Attunements.lua` (`Att.StateOf`), shared by Roster,
    Character and Overview.
  - Milestones (`Core/Feed.lua`) are derived from old vs new profile copies
    in `Sync` (PR accepted) and `Profile:Commit`; first copy = no events;
    stored in `ShortKingsDB.feed` (max 50), never sent.
  - The window opens on the Overview once (`settings.overviewShown`), then
    the last tab.

## Waiting on the user (remind them when relevant)
Full post-launch checklist: PLAN.md section 10.
1. Confirm the Mac AddOns folder (Battle.net → Forever → ⚙ → Show in Finder).
   Expected: `/Applications/World of Warcraft/_forever_/Interface/AddOns`.
2. In game, run `/dump select(4, GetBuildInfo())` (expect 16001).
3. Install a test build, send the `/sk debug` text, and work through `TESTING.md`.
4. Onyxia attunement: whether any Horde members exist (Horde chain differs), and
   in-game check that the Drakefire Amulet check works.

## Answers already given to the guild (stay consistent)
- **Alts:** linked automatically once each alt has logged in with the addon
  (same guild). "Make this my main" is optional.
- **Recipes:** the full recipe list per profession is recorded and synced
  (refreshed when the profession window is opened). Since v0.2.0 the
  Crafters tab searches it by item name and item tooltips list crafters.
- **Update speed:** comes from players' own games, not Blizzard's armory.
  Since v0.1.2, changes reach guildmates in about 30–60 seconds while
  they're online ("Ask for latest" on the Character tab gets it sooner).
  Offline members show their last state. Paused in instances and combat.
  Recipes refresh when the profession window is opened.
