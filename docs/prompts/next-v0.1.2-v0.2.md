# Prompt: Short Kings v0.1.2 + v0.2 (guild requests)

Copy everything below the line into a new Claude Code chat on the
`forever-shortkings` repo.

---

You're continuing work on **Short Kings**, a World of Warcraft: Forever guild
addon in this repo. Before you change anything, read `CLAUDE.md` (project
rules, verified APIs, environment notes), then `PLAN.md` and
`docs/FEATURE-REVIEW.md`. I'm not a developer and I'm usually on my phone.
Explain what you did in plain language, keep replies short, and push back if
something here is a bad idea. Nothing has been tested in game yet, so don't
claim anything works in game.

Guild members asked for the features below. Build them in **two releases**,
committing as you go.

## Release v0.1.2: quick wins

### 1. Raid attunement filter on the Roster
- Add a **Raid** selector to the Roster toolbar: *All raids*, then each entry in
  `SK.Data.ATTUNEMENTS` (Onyxia's Lair, Molten Core, Blackwing Lair, Barrow
  Deeps, Hyjal Summit, Naxxramas).
  - Build it from core frames in `UI/Widgets.lua`, e.g. a small themed
    pop-up menu. Don't use Blizzard dropdown templates.
- When a raid is selected:
  - Add an **Attuned** column showing *✓ yes* (green), *✗ no* (red) or *? unknown* (grey).
    - The value comes from `profile.att[key]`.
    - "Unknown" covers no Short Kings data, the gear/talents being hidden,
      or the raid's quest IDs still being `todo`.
  - Add filter buttons: **All / Attuned / Not attuned / Unknown**.
  - Show a counter: "23 attuned · 9 not · 6 unknown".
  - Add a **"Max level only"** checkbox. Default it to on; max level is the
    highest level in the roster.
  - Attunement belongs to a character, so show **every character on its own
    row while a raid is selected**, even with "Group alts" on. Still show
    "alt of X" in the tooltip.
  - For raids whose status is `todo`, show a one-line note: "Attunement
    quests for this raid aren't known yet."
- Remember the selected raid and filter in `SK.DB.settings`.
- Put the logic in a pure, tested function, e.g.
  `RosterTab.AttunementRows(guild, raidKey, filter, maxLevelOnly)` plus the counts.
- `UI/Widgets.lua`'s `List` builds its columns once. Either always include an
  Attuned column and hide its text when no raid is selected, or rebuild the
  list. Choose and explain.

### 2. "Ask for latest" on the Character tab
- Add a button: **Ask for latest**.
  - Enabled only when the character, or one of their linked alts, is online
    *with* the addon. Use `RosterTab.Status` = `"addon"`.
  - Otherwise disabled, with the tooltip "Offline: showing their last known data".
- Clicking it sends an `RQ` by whisper for that character's GUID. Use the
  existing request path in `Sync/Sync.lua`; add a small public method such as
  `Sync:RequestFresh(guid)`.
  - Allow at most one request per target every 30 s.
- **On the receiving side:** an `RQ` for one of *our own* characters must
  first rebuild our profile, so the answer is fresh. Call
  `SK.Profile:BuildSelf()`, skip it in combat, and rate-limit it to once per 10 s.
- Show "Asked for the latest data…" and update the panel when the profile arrives
  (the `PROFILE_UPDATED` event already exists).

### 3. Faster updates
- Change `Sync.HELLO_DEBOUNCE` from 60 to **30** seconds.
- Update the README FAQ and the "Update speed" answer in `CLAUDE.md`:
  changes reach guildmates in about 30–60 seconds while they're online.

Tests for v0.1.2:
- attunement rows, counts and filters;
- `RequestFresh` rate limit;
- the owner rebuilds before answering;
- the new debounce value.

Then update `CHANGELOG.md` (v0.1.2), `TESTING.md` (new checks) and the README
"What's inside" (list everything new), and commit.

## Release v0.2.0: Crafters

### 4. Crafters tab: "who can make this?"
- Add a new tab **Crafters**, placed after Character.
- **Search box:** type part of an item or recipe name ("arcanite", "mooncloth",
  "enchant boots"). Results show one row per recipe:
  - item icon;
  - name in quality colour (or the spell name for enchants);
  - profession;
  - crafter count, e.g. "3 crafters (1 online)".
- **Click a result** to open a side panel listing the crafters, online first.
  Each crafter row shows:
  - status dot;
  - name in class colour;
  - skill level;
  - "alt of X" where it applies;
  - a **Whisper** button.

  Use `ChatFrameUtil.SendTell` via Compat, falling back to `ChatFrame_SendTell`.
- A **"Post to guild chat"** button **pre-fills the chat box** with
  "[Item] can be made by: A, B, C". The player presses Enter themselves.
  - Don't call `SendChatMessage` directly: it's restricted on Forever.
  - Verify the chat-box open function in Blizzard's Forever source.
- **Data:** each profile's `recipes[skillLine] = { [recipeID] = itemID }`
  (itemID 0 = no item, e.g. enchants). Skip profiles with
  `hidden.recipes`. For our own characters, use `SK.Profile:Get`.
- **Index:** build one lazily when the tab opens and rebuild it (debounced)
  on `PROFILE_UPDATED` and `SELF_UPDATED`:
  - `recipeID → { itemID, skillLine, crafters = {guid…} }`;
  - `itemID → { recipeID… }`.
  - Put it in a new non-UI module, e.g. `Collect/CraftIndex.lua` or
    `Core/CraftIndex.lua`, with tests.
- **Names load asynchronously in WoW.**
  - Resolve spell names with `C_Spell.GetSpellName`. Call
    `C_Spell.RequestLoadSpellData` if a name is nil.
  - Resolve item names with `C_Item.GetItemNameByID` or `Item:CreateFromItemID`
    + `ContinueOnItemLoad`.
  - Cache names for the session and refresh the result list (debounced) as
    names arrive.
  - **Verify every one of these functions in Blizzard's Forever source** before
    using it, and add them to `Compat.PROBES`.
- Search is case-insensitive and matches names only. Show "Type at least 3
  letters" for shorter input. Cap the list at 200 results.
- If nobody has scanned a profession yet, show a hint: "Recipes appear after
  crafters open their profession window once."

### 5. "Crafted by" on every item tooltip
- Use `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)`
  (exists on Forever; confirm the exact Enum name in the source).
- Add a line such as "Short Kings: Bramble (online), Dabble +2 more".
  - Use the index's `itemID → recipes → crafters` lookup.
  - List online crafters first, at most 3 names.
- Add a setting: **"Show guild crafters in item tooltips"** (default on).
- Keep it cheap: index lookups only, no scanning in the tooltip.

### 6. UI and docs
- Mockups:
  - add a Crafters scene to `docs/mockups/ui-mockup.html`;
  - add the Raid filter to the Roster scene;
  - re-render with `node docs/mockups/render.js <marcellus.woff2>`;
  - add `docs/images/crafters.webp` to the README.
- Update:
  - README "What's inside": list *everything* the new tab and filter do, plus the tooltip line;
  - the FAQ answer about recipes;
  - CHANGELOG (v0.2.0);
  - TESTING.md (new checks);
  - PLAN.md (mark these done; the rest of v0.2 — the Professions tab and B2–B6 — stays planned);
  - CLAUDE.md status.

## Out of scope for this task
- The Professions tab (coverage, cooldown board, specialisations, reagents)
- The Raids/calendar tab
- Anything in PLAN.md "Later"

## Definition of done
- `busted --lua=lua5.1` and `luacheck .` pass locally and in CI.
- Every new WoW API is checked against the Forever source and probed in
  `/sk debug`.
- Docs and mockups are updated. Commits are pushed to your designated branch,
  with no PR unless I ask.
- Finish with a short plain-language summary, the new `TESTING.md` items, and
  anything I need to check in game.
