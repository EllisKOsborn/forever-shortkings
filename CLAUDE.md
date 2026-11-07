# Short Royalty: project notes for Claude

Read this first in every session. Keep it current: if you change a decision,
the status or a convention, update this file in the same commit.

## Names (7 Nov 2026)
- The guild and the addon are now **Short Royalty** (was "Short Kings"). Use
  that name everywhere a person can read it: titles, chat, tooltips, docs.
- **Technical names were renamed too (v0.3.1)**, because the addon hadn't
  been rolled out yet (no saved data to lose): folder and TOC
  `ShortRoyalty/ShortRoyalty.toc`, SavedVariables `ShortRoyaltyDB`, addon
  message prefix `ShortRoyalty`, frame names, media paths
  `Interface\AddOns\ShortRoyalty\Media\`, release zip
  `ShortRoyalty-vX.Y.Z-forever.zip` (`.pkgmeta` package-as). Releases up to
  v0.3.0 were `ShortKings`; v0.3.1 can't talk to them (different prefix).
  Still unchanged: the Lua namespace variable `SK` (invisible) and the repo
  name `forever-shortkings` (only the owner can rename it on GitHub).
  **From now on** the folder, SavedVariables and prefix are fixed: changing
  them after rollout would wipe saved data or split the guild.
- Slash commands: `/sr`, `/shortroyalty`, and `/sk` (kept, short).
- The CHANGELOG's past entries and the outside proposal files keep the old
  name (they're history).

## What this is
A World of Warcraft: **Forever** addon for the guild **Short Royalty**
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
- Forever client **1.60.1** (live build **70790** at launch; the API source
  matches it), Mainline (12.x) UI with Midnight "secret value"
  restrictions. TOC game type `camelot` (alias `forever`).
- TOC **`## Interface: 16001`**: **confirmed in game** on 5 Nov 2026.
  Single TOC with no suffix. The BigWigs packager detects it as Forever.
- **Confirmed in game on 5 Nov 2026** (owner's first `/sr debug`):
  - `SendAddonMessage(..., "GUILD")` returns **0 (Success)** and arrives,
    even though `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()` returns
    **true**. That flag only gates Blizzard's esports CooldownBroadcaster.
    **Never use it to block sending**: trust the send result (v0.2.5).
  - Our AceComm callback gets **`true`/`false`** ("did it send"), not
    Blizzard's numeric `SendAddonMessageResult`: ChatThrottleLib passes
    `(arg, didSend, code)` and AceComm forwards only `didSend`.
    `Sync.SendOutcome` handles both (v0.2.6 fix: v0.2.5 counted `true` as an error).
  - Addon-message sender = **"First Surname"** with a space, exactly like the
    roster name. `UnitFullName("player")` returns the surname as the *realm*
    (`"Pocus", "Hocus"`). `GetGuildInfo`'s realm is an internal name
    (`CAMWOWEU5Realm3PvE`).
  - Player GUIDs (`Player-6937-…`) stay the same between logins.
  - The real release zip is `ShortRoyalty-vX.Y.Z-forever.zip`. The owner first
    installed GitHub's "Source code (zip)" by mistake (version "dev",
    LibDataBroker and LibDBIcon missing).
  - `C_QuestLog.GetTitleForQuestID` returns nil for uncached quests (it isn't
    proof that a quest is missing). Item 16309 (Drakefire Amulet) resolves.
  - The guild is called **"Short Royalty"** (renamed 7 Nov 2026; it was
    "Sweaty Pumpers" at launch because "Short Kings" was taken). Data is keyed
    per guild name; `DBM.AdoptRenamedGuild` carries a renamed guild's data
    over to the new key (v0.3.1).
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
  - **Confirmed in game 5 Nov (owner's v0.2.7 `/sr debug`, level 1, no
    profession yet):** every profession API we probe exists on the client
    (`GetRecipeSchematic`, `GetCategoryInfo`, `GetCategories`,
    `GetShowLearned`/`GetShowUnlearned`, `GetAllRecipeIDs`,
    `GetFilteredRecipeIDs`, `GetRecipeCooldown`, `C_SpellBook.IsSpellKnown`,
    `IsPlayerSpell`); only the Classic `GetNumTalentTabs`, `GetTalentTabInfo`,
    `GetNumTradeSkills`, `GetTradeSkillInfo`, `GetCraftInfo`, `GetFactionInfo`
    are missing. The window's filter defaults to **show unlearned = no**. All
    10 specialisation spell IDs resolve to the expected names → `status = "ok"`.
    Only 1 of 19 members had the addon, so no sync between players has
    happened yet.
  - **Confirmed in game 6 Nov (second v0.2.7 report, Herbalism 4/75):**
    - The window **lists unlearned recipes** (`GetAllRecipeIDs`: 0 learned,
      3 listed) even with "show unlearned" off, so "Nobody knows" works.
    - **Gathering professions have recipes in Forever**: Herbalism has a
      category **"Camping"** (id 2716, parent "Herbalism"): Seed Hybridizer
      (recipe 1263070 → item 279947), Greenhouse, Incense Candle. So never
      assume `Data.GATHERING` means "no recipes".
    - `GetCategoryInfo` works (name + parent).
    - `GetRecipeSchematic` returns reagents **for an unlearned recipe with the
      window open** (Seed Hybridizer: 4× 13465, 1× 8925, 2× 14047).
    - The display font was reported **"NO, using the game font"** (first
      SetFont with the bundled .ttf failed). v0.3.0 preloads it as XML Font
      objects (`ShortRoyaltyDisplay13/20/24` in `Media/Fonts.xml`) and checks
      `GetFont()`; unconfirmed whether that fixes it.
    - Still unknown: reagents with the window **closed**, reagents for a
      learned recipe, `IsSpellKnown` for a spec owner. Drakefire Amulet name
      was nil in both reports (uncached; it resolved on 5 Nov).
  - Profession APIs (from the source, 5 Nov):
    `C_TradeSkillUI.GetRecipeSchematic(recipeSpellID, isRecraft)` →
    `reagentSlotSchematics[i].reagents[j].itemID|currencyID`,
    `.quantityRequired`, `.required`; `GetShowLearned`/`GetShowUnlearned`;
    `GetRecipeInfo` has `categoryID`. `GetCategoryInfo`/`GetCategories`,
    `GetAllRecipeIDs`, `GetFilteredRecipeIDs` are **not** in the generated
    docs (Blizzard's Forever UI calls `GetCategoryInfo`), so probe them.
    Known spells: `C_SpellBook.IsSpellKnown(spellID)` (global
    `IsPlayerSpell` not in the docs, but present in game). Specialisation
    spell IDs (`Data/Professions.lua` `SPECIALISATIONS`) match on wowhead
    classic, classicdb.ch and the client's own names.
  - The guild roster is `C_Club` plus legacy `GetGuildRosterInfo`.
  - `C_Calendar` exists, but `AddEvent` is restricted.
  - `SendChatMessage` is **restricted** (only send on a button press, or
    prefill the chat box instead).
  - Whisper with `ChatFrameUtil.SendTell` (`ChatFrame_SendTell` is gone).
  - `TooltipDataProcessor` exists.
  - `C_Spell.GetSpellCooldown` returns a table.
  - Trial accounts can't send addon messages.
- **Confirmed in game 7 Nov (owner's v0.3.6 `/sr debug`, build 70862):** no
  Lua errors; own profile passes the safety check; a guildmate's message
  arrived ("Slay Qween"). `Compat.AccountIDs` found Battle.net accounts for
  **3 of 27** members: the game only fills them for some (most likely your
  Battle.net friends), so "bnet" alt links are a bonus; "This is my alt" and
  guild notes do most of the work. "Sent 0" in that report = taken in the
  first 10–20 s after login (the first HI waits that long); recheck if it
  stays 0.
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
- **Security** (`docs/SECURITY-REVIEW.md`, 3 Nov): everything received is
  untrusted. New profile fields need a check in `Merge.FIELDS`; never run,
  link or chat received text unchecked; keep `tests/security_spec.lua` green.
  Loose (first-name) sender matches count only on GUILD, or by whisper from a
  sender confirmed on GUILD this session. GitHub Actions are pinned to commit
  SHAs (update the SHA and the `# vN` comment together).
- **Privacy:** notes and officer notes are never synced. Our own characters
  keep a **full** profile in `ShortRoyaltyDB.own[guid]`, and only the
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
- **Releases are automatic since v0.3.5:** every push to `main` runs
  `.github/workflows/release.yml`; if CHANGELOG.md's top heading is a dated
  version (`## v0.3.6 (8 Nov 2026)`) with no GitHub release yet, it tags that
  commit and starts itself again on the tag (`gh workflow run --ref <tag>`;
  the packager skips a tagged branch push, and GITHUB_TOKEN tag pushes don't
  start workflows, but workflow_dispatch does), which builds the zip, GitHub
  Release and CurseForge upload. A heading containing "not released" (keep
  using `## vX.Y.Z (not released yet)` on the working branch) or an existing
  release does nothing. So **before pushing to `main`, date the
  top CHANGELOG heading**, bump the README badge, and never push a dated
  heading to `main` that the owner hasn't asked to release. The owner no
  longer publishes on the website. Earlier: pushing a tag `vX.Y.Z` on `main` runs `.github/workflows/release.yml`
  (BigWigs packager): it builds `ShortRoyalty-vX.Y.Z.zip` and a GitHub Release
  whose notes come from CHANGELOG.md (`.pkgmeta` manual-changelog). First
  release: **v0.2.2** (2 Nov 2026, the launch build); **v0.2.3** (3 Nov, the new
  look); **v0.2.4** (3 Nov, tagline "Height is not a stat."); **v0.2.5** (5 Nov,
  launch-day fixes: sync no longer blocked by the misleading flag, enchant
  check at max level, plus the security fixes); **v0.2.6** (5 Nov, hotfix: successful
  sends were counted as errors; the owner publishes it on the website because
  tag pushes from cloud sessions drop); **v0.2.7** (5 Nov, `/sr debug`
  profession checks only, for v0.3 Step 1); **v0.3.0** (6 Nov, the Professions
  tab, reagents, favourites, specialisations, reminders); **v0.3.1** (7 Nov,
  renamed to Short Royalty, technical names included; first zip named
  `ShortRoyalty-…`); **v0.3.2** (7 Nov, every recipe from wago.tools
  data, search, Wowhead links, Getting started; first release for CurseForge,
  project **1788068**); **v0.3.3** (7 Nov, sync fix: our own numbered
  pieces, protocol 2; can't talk to v0.3.2 or earlier); **v0.3.4** (7 Nov,
  crafter's recipes in Professions, who has the addon on the Overview, orange
  profession reminder bar with an Open button); **v0.3.5** (7 Nov, full
  "doesn't have the addon" list on hover; first automatic release); **v0.3.6**
  (7 Nov, old versions / alts / never-online-together no longer listed as
  "doesn't have it"). Tag only when
  the user asks.

## Layout
```
ShortRoyalty.toc  embeds.xml  Commands.lua (/sk, /sr debug report)
Core/     Init (events, timers, modules), Log (+ error capture: SK:Safe,
          SK:RecordError), Compat, DB (SavedVariables, pruning), Identity
          (roster, sender→GUID, Status dots, GUID-stability check), Alts
          (mutual-link groups), CraftIndex (recipe/item → crafters, async
          names), Favourites (local stars), Reagents (GetRecipeSchematic
          cache, local), ProfBoard (numbers for the Professions tab),
          RecipeDB (every recipe + search), Onboarding (Getting started),
          Export (plain text for Copy), Feed (local milestones,
          never synced), Accounts (which addon-less characters are alts
          of users), Overview (numbers for the Overview tab), Raids
          (calendar events, line-ups, roles, readiness; reader)
Data/     Professions, Recipes (GENERATED by tools/recipes.js), Attunements
          (quest IDs, raid title keywords), Roles (role guesses), Factions, Enchants
Collect/  Character, Talents, Professions (recipe scan), Reputation,
          Attunements, Profile (full/public copies, cooldowns, main)
Sync/     Codec (LibSerialize stable → LibDeflate), Merge (rules), Sync (protocol)
UI/       Theme (EVERY colour/font/size/spacing/motion value), Motion
          (AnimationGroups, Reduce motion), Widgets (Button, CloseButton,
          Tab, Chip, Check, Menu, SearchBox, List, TextPanel, Block, Sheet),
          MainFrame, OverviewTab (first tab, three spec-sheet columns),
          RosterTab (+ raid filter, Oldest first), CharacterTab (+ Ask for
          latest), CraftersTab (+ reagents, Favourites chip), RaidsTab
          (calendar raids, line-up, My roles), ProfessionsTab
          (board / one profession / cooldowns), SettingsTab, DebugWindow,
          Minimap, Tooltip
Media/    Fonts.xml (Arial Narrow families + CJK fallback), Fonts/ (Chakra
          Petch, OFL), Textures/ (crest, arrow, close, dot, ring, star .tga)
preview/  browser mock-up of every window (theme.css/js generated)
tools/    textures.js (draws Media/Textures), preview-tokens.js, recipes.js
          (Data/Recipes.lua from wago.tools)
Libs/     vendored Ace3 bits, LibSerialize, LibDeflate; LDB + LibDBIcon via .pkgmeta
tests/    busted specs; tests/helpers/wow.lua is the stubbed WoW API
docs/     FEATURE-REVIEW.md, SECURITY-REVIEW.md, mockups/render.js, images/ (+ before/), prompts/,
          design/ (Lamborghini reference); DESIGN.md + PRODUCT.md at the root
```

## Sync protocol (prefix `ShortRoyalty`, protocol 2)

**Transport (protocol 2, v0.3.3):** every encoded message goes out through
`Sync/Frames.lua`: up to 250 bytes as one message (`"\030" .. data`), longer
ones as numbered pieces (`"\031" .. id(2) .. seq .. total .. data`, 240
data bytes each), so **AceComm never splits anything**. The receiver rebuilds
by number in any order, gives up after 120 s without a new piece (reported in
/sr debug as "Last incomplete message"), keeps at most 4 unfinished messages
per sender, and drops strangers before storing pieces. The 60-per-minute
limit counts whole messages; raw pieces have their own cap (1500).
Why: on 7 Nov the first two-player test (owner + Aura, different server IDs
6937/6855) lost every profile to "bad compression", although in-game tests
showed single addon messages arrive intact (all byte values, 255 bytes,
GUILD and WHISPER, 20 in a row in order). AceComm/ChatThrottleLib reassemble
correctly in simulation, so the multi-part messages broke in transit between
players. **Don't go back to AceComm multi-part messages.**
| Msg | Channel | Purpose |
|---|---|---|
| `HI` | GUILD | Own account's characters `{g, u, h}`. Sent at login, every 10 min, and 30 s after changes (debounced) |
| `RQ` | WHISPER | Request profiles. Also "Ask for latest" (max 1 per target per 30 s); an RQ for the logged-in character rebuilds it first (not in combat, max every 10 s) |
| `PR` | WHISPER | One profile per message |
| `SQ` | GUILD | Once per session: what I hold, and (`a`, v0.3.6) who I know runs the addon |
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
oversized outgoing messages are recorded as errors, not sent. v0.2.5 adds
`Codec.MAX_DECODED` 256 KB, `Merge.LIMITS` per field, only GUILD/WHISPER
accepted, strangers dropped before decoding, and `Sync.MAX_STRIKES` (3 bad
messages → sender ignored for the session).

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

## Status (7 Nov 2026)
- **v0.3.1 (Short Royalty rename)** on `main` 7 Nov (the owner publishes the
  release): new name everywhere, technical names too (folder, SavedVariables,
  prefix, zip `ShortRoyalty-vX.Y.Z-forever.zip`), `DBM.AdoptRenamedGuild`
  (saved guild data follows future renames), `/sr` + `/shortroyalty` + `/sk`.
- v0.3.0 Professions released 6 Nov (see CHANGELOG).
- **v0.3.2** (7 Nov): every recipe, search, Getting started, CurseForge
  (project 1788068). Two Claude sessions worked on `main` the same morning:
  always `git fetch origin main` and merge before pushing to `main`.
- **v0.2.5 released 5 Nov**: the first build after an in-game test (owner,
  solo: loads, GUID stable, interface 16001, a test send worked). It
  includes the security fixes from `docs/SECURITY-REVIEW.md`. Sync between
  two players has **not** been tested yet (v0.2.2–v0.2.4 never sent
  anything because of the flag bug).
  v0.2.2 = the Overview dashboard (owner asked for it before the test gate).
  (`docs/prompts/next-v0.1.2-v0.2.md` is done; v0.2.1 = launch readiness
  from `docs/PLAN-REVIEW.md`.)
- Roadmap and future plans: `PLAN.md` section 7. Background and reasoning:
  `docs/FEATURE-REVIEW.md`.
- Outside proposals (`docs/GPT-PLAN.md`, `docs/MANUS-PLAN.md`,
  `docs/PERPLEXITY-PLAN.md`) were reviewed on 2 Nov: verdicts in
  `docs/PLAN-REVIEW.md`, agreed order in **PLAN.md section 7** (the single
  roadmap). Don't build from the proposal files directly.
- **Next (5 Nov):** **v0.3 Professions**: `docs/prompts/next-v0.3-professions.md`
  (the guild says professions matter most; Raids moves to v0.4, still before
  9 Dec). v0.2.6 hotfix is on `main` (5 Nov); the owner publishes the release.
  **v0.2.7** (probes only: `/sr debug` block "Profession checks for v0.3",
  `Commands.ProfessionProbes`) is on `main`; the tag push dropped, so the
  owner publishes the release on the website. **v0.3.0 Professions is built**
  on `claude/affectionate-archimedes-tirbrl` (owner said "do all of them";
  reminders must stay rare). **Released as v0.3.0 on 6 Nov** at the owner's
  request (on `main`; tag push may drop, the owner publishes on the website).
  Not tested in game yet: TESTING 87–97, and reagents with the window closed.
  The owner says the titles **look fine in game** even though v0.2.7's
  /sr debug reported the display font as failed (the check may have been a
  false alarm; v0.3.0's debug line counts it per text).
  **CurseForge:** project ID **1788068** is in the TOC (`X-Curse-Project-ID`);
  the release workflow uploads when the `CF_API_KEY` GitHub secret exists
  (owner's job, `docs/CURSEFORGE.md`). **v0.3.2 released 7 Nov** (on `main`,
  built on top of the v0.3.1 rename from another session): every recipe in the
  game from wago.tools data, All recipes search, Wowhead links, Getting
  started, CurseForge ID. Not tested in game: TESTING 87–107.
- **v0.3.3 (sync fix, 7 Nov)**, from branch `claude/short-kings-addon-hlf0t4`,
  built on `main` after v0.3.2: our own numbered pieces (`Sync/Frames.lua`,
  protocol 2) because AceComm multi-part messages arrived corrupted between
  two players (see "Sync protocol" below). Released v0.3.2 and earlier can't
  share profiles between players at all; v0.3.3 can't talk to them either.
  On `main` 7 Nov (the owner publishes the release; it uploads to CurseForge
  automatically). TESTING 108–110.
- **v0.3.4 (on `main` 7 Nov; the owner publishes the release)**, from `claude/short-kings-addon-hlf0t4`,
  owner's request: clicking a crafter in one profession shows **their**
  recipes (`ProfessionsTab:PickCrafter`, `ProfBoard.Recipes(ctx, line,
  filter, crafterGUID)`), with **Character** and **Everyone** buttons; the
  Overview's Guild section counts who has Short Royalty and lists up to 10
  who don't (`Overview.Build` → `hasAddon`, `without`, `addonNoData`;
  `Identity.HasAddon` = own account, a version heard (HI), or any profile).
  *Without addon* = `RosterTab:ShowWithoutAddon` (Version column sorts
  no-addon first). Also the orange **profession reminder bar** (owner picked
  "banner on every tab" + "open it for me" from a list of options):
  `Professions.Banner(own, share)` (pure), `MainFrame:UpdateBanner` (the
  window grows by `SIZES.banner + SP.m` so tab layouts don't move),
  `Compat.ShowProfession(skillLine)` → Blizzard's `OpenProfessionUIToSkillLine`
  (Blizzard_Professions bootstrap) or `C_TradeSkillUI.OpenTradeSkill`, neither
  restricted in the forever source; not in combat. Unconfirmed in game.
  TESTING 111–117. (`Compat.OpenProfession` is the old *read which window is
  open* function; don't confuse them.)
- **v0.3.4 published 7 Nov** by the owner (GitHub release with the zip).
- **v0.3.5 (on `main` 7 Nov, released automatically)**: Block rows take `tip = function(tooltip)`
  (an invisible hover frame per row, `W.Block`); the Overview's "Don't have it
  yet" row and its names use `OverviewTab.WithoutTip` (all names, two per
  line, capped at `TIP_NAMES` 60). TESTING 118.
- **v0.3.6 (on `main` 7 Nov, released automatically)**: fewer false "doesn't have it" (owner:
  "it's all of those reasons, fix all"):
  - old protocol (`\133…`, v0.3.2 and earlier) from an exact roster name →
    `m.oldAddon` (local): counts as having it, Roster "old", Overview outdated;
  - alts: `Core/Accounts.lua` (`Links` pure, `Current` caches Battle.net ids
    60 s) links an addon-less character to a user by **bnet** (same
    `bnetAccountId` from C_Club member info, or `C_BattleNet.GetAccountInfoByGUID`
    for friends: `Compat.AccountIDs`; unknown whether the game fills it for
    guildmates, /sr debug reports the count), **claim** (profile field
    `claims`, from "This is my alt" on the Character tab, `SK.DB.myAlts`,
    validated in `Merge.FIELDS`; older versions accept it as a plain extra
    field), or **note** (note/officer note names exactly one user's first
    name, ≥ 3 letters). Overview `altsOf` + "Alts of players who have it"
    row; Roster Version "alt". Display only, never sent;
  - relay: SQ and SO carry `a` = GUIDs known to run the addon
    (`Sync.KnownUsers`); receivers set `m.addonRelay` (no version, so relays
    can't fake "newer version" notices). An SQ with `a` gets an SO even with
    no profiles to offer (`g = {}`, which doesn't use the accept-one slot).
  TESTING 119–123.
- **v0.4.0 Raids, read-only (built 7 Nov, not on `main`; the owner said
  "don't release yet")**. It also carries the v0.3.7 wording change (that
  version was never released, its CHANGELOG entry is folded into v0.4.0).
  Built from `docs/prompts/next-v0.4-raids.md` with these decisions:
  - `Compat` calendar layer: `GuildEvents`, `CalendarNow`
    (`C_DateAndTime.GetCurrentCalendarTime`), `CalendarOpenEvent(ev)`
    (`SetAbsMonth` to now, then find the event's index on its day with
    `GetNumDayEvents`/`GetDayEvent` by eventID, then `OpenEvent(offset, day,
    index)`), `CalendarInvites`, `CalendarCloseEvent`, `CalendarShown`
    (`CalendarFrame`), `ToggleCalendar` (Blizzard_Calendar bootstrap). All
    verified in the forever source; `CalendarStatus` enum 0–8, event type
    Raid = 0.
  - `Core/Raids.lua`: pure `Match` (whole-word title keywords from
    `Data/Attunements.lua`, or the player's pick in `SK.DB.raidPick`),
    `Upcoming` (raid type, 6 h ago to 30 days ahead), `LineUp` (role from
    `profile.roles` or `Data.GuessRole`; counts; readiness incl. duplicates
    via `Alts.Groups`), `Text` (Copy). `Raids:Read` only when
    `Raids.Blocked()` is nil (calendar window closed, not combat, not chat
    lockdown), one at a time, 5 s timeout, cache per eventID for the session.
  - Roles: **on the Raids tab** ("My roles", two menus) rather than
    Settings (Settings' column is full). Per character in `SK.DB.roles`,
    shared as `profile.roles = { main, second }` (validated in
    `Merge.FIELDS`; older versions accept it as a plain extra field). Role
    guesses (`Data/Roles.lua`) are by class and tree ORDER, `status = "todo"`.
  - `W.Menu:Choose(value)` added (tests and code).
  - Not yet: sign-up buttons, reminders, invite everyone (v0.4.1, after the
    in-game test). TESTING 125–131.
- **v0.3.7 (folded into v0.4.0, never released)**: wording only. The owner asked whether
  to remove alt features; advice was no (removing them wouldn't fix the
  per-character gap and would lose roster grouping and "on alt" whispers).
  "Don't have it yet" → **"Not seen with the addon yet"**, button "Not seen
  yet". Pending: owner's in-game test of the Warband currency API
  (`C_CurrencyInfo.RequestCurrencyDataForAccountCharacters` +
  `FetchCurrencyDataFromAccountCharacters(currencyID)` → characterGUID/name of
  the player's own characters holding an account-transferable currency;
  Forever loads Blizzard_CurrencyTransfer). If it lists alts, build automatic
  "my alts" claims on it. TESTING 124.
- **CurseForge uploads are automatic** (checked 7 Nov: the v0.3.2 Release run
  logged "Uploading ShortRoyalty-v0.3.2-forever.zip (1.60.1 release) …
  Success!"). Owner still renames the project from "Short Kings" and archives
  the old files (`docs/CURSEFORGE.md`).
  Plan and what was left out: **PLAN.md section 11**.
- Earlier plan: PLAN.md **section 10, "Once Forever is live"**: the in-game test
  gate (TESTING.md, `/sr debug` "Live-client checks"), its decision table,
  fixes only (now **v0.2.5**: v0.2.3 = new look, v0.2.4 = tagline). Raids is now
  **v0.4** before 9 Dec (`docs/prompts/next-v0.4-raids.md`); Professions is v0.3.
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
- Decisions in v0.3.0:
  - Specialisation detection: known (`C_SpellBook.IsSpellKnown`) **and**
    (`status = "ok"` or the client's spell name equals the Data name). Synced
    as `profs[skillLine].specs` (spell IDs); display only for IDs in
    `SK.Data.SPEC_BY_SPELL`.
  - Reagents are local only (`ShortRoyaltyDB.reagents`, keyed by game build),
    learned during scans and on demand. Never in profiles.
  - Favourites: `ShortRoyaltyDB.favourites` (local). Right-click to star.
  - Nudges: `Professions.NUDGE_POINTS` 15, `NUDGE_EVERY` 3 days, once per
    session, `settings.profNudges`; scan ranks in `ShortRoyaltyDB.scanRank`.
  - "At 300" uses `SK.Data.SKILL_CAP` (original-game cap; confirm in game).
  - Clicking a recipe in Professions opens it in Crafters
    (`CraftersTab:ShowRecipe`), including recipes nobody knows.
- Decisions in v0.3.2 (built as "v0.3.1" before the rename took that number):
  - Recipe list: `node tools/recipes.js [build]` downloads SkillLineAbility,
    TradeSkillCategory, SpellEffect (Effect 24 = create item) and SpellReagents
    CSVs from wago.tools (product `wowf` = Forever) and writes
    `Data/Recipes.lua` (IDs, category, item, reagents; **no names**).
    Categories named Season of Discovery / PROTOTYPE / [DNT] are excluded.
    Rerun it after a Forever patch. Verified against the owner's game: Seed
    Hybridizer's reagents match exactly.
  - **Don't scrape Wowhead** (terms forbid it); link to it instead:
    `https://www.wowhead.com/forever/item=<id>` or `/spell=<id>` (path
    checked 7 Nov).
  - `Compat.SpellExists` (`C_Spell.DoesSpellExist`) hides recipes the client
    lacks. Name loads are budgeted (`CI.SetBudget`, 200 per search); names the
    game can't load are not re-requested (`CI.failedItems`).
  - Getting started: `Core/Onboarding.lua` (pure `Steps`), shown in the
    Overview's milestones slot; `settings.seen[tab]`, `settings.onboarding.hidden`,
    `settings.welcomed`.
- Decisions in v0.2.2:
  - Overview numbers come from `Core/Overview.lua` (pure); attunement logic
    lives in `Collect/Attunements.lua` (`Att.StateOf`), shared by Roster,
    Character and Overview.
  - Milestones (`Core/Feed.lua`) are derived from old vs new profile copies
    in `Sync` (PR accepted) and `Profile:Commit`; first copy = no events;
    stored in `ShortRoyaltyDB.feed` (max 50), never sent.
  - The window opens on the Overview once (`settings.overviewShown`), then
    the last tab.

## Design refresh (merged into `main` and released as v0.2.3, 3 Nov 2026)
- Built on branch `design/refresh`, merged into `main` and tagged **v0.2.3**
  when the owner asked (they chose to release before the in-game test).
  Untested in game: fixes from the test round go into **v0.2.5**.
- Visual rules live in `DESIGN.md`. Nothing visual is hard-coded outside
  `UI/Theme.lua` (`tests/design_spec.lua` enforces it). Colours: gold = where
  you are / one primary action / key figure; beard pink = selections and the
  crest; spark orange = alerts and sync status only.
- Widgets keep no ad-hoc fields read before they're set: the test stub
  returns a function for any unknown field, so state lives in plain tables
  (Theme's border map, Motion's group map) or is initialised at creation.
- After changing Theme.lua: `node tools/preview-tokens.js`, then
  `node docs/mockups/render.js` (Chrome headless or Playwright → PNG). The
  README pictures (incl. before-after.png and palette.png) come from it;
  the old pictures live in `docs/images/before/`.
- Local test tools on the owner's Mac were built in a session scratch folder
  (not persistent); rebuild with lua.org 5.1.5 + LuaRocks if needed.

## Waiting on the user (remind them when relevant)
Full post-launch checklist: PLAN.md section 10.
Done on 5 Nov: interface 16001 confirmed, the addon loads, GUID stable,
a test send worked. The Mac AddOns path is still not confirmed by name
(the owner installed successfully).
1. Install the **v0.2.5** release (the real `-forever.zip`), send `/sr debug`,
   and work through `TESTING.md` (on their own, then with one guildmate).
2. ~~The final guild name~~: done, **Short Royalty** (7 Nov). Saved data
   carries over automatically (v0.3.1).
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
