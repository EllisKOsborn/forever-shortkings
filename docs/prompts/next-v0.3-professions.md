# Prompt: Short Kings v0.3 (Professions)

Copy everything below the line into a new Claude Code chat on the
`forever-shortkings` repo.

---

You're continuing work on **Short Kings**, a World of Warcraft: Forever guild
addon in this repo. I'm not a developer and I'm usually on my phone. Explain
things in plain language, keep replies short, push back on bad ideas, and
never claim something works in game until I've tested it.

**Read first:** `CLAUDE.md` (rules, verified APIs, facts confirmed in game),
`PLAN.md` sections 7 and 10, `docs/FEATURE-REVIEW.md` (B2–B6, D1, D4, D6),
`DESIGN.md` and `PRODUCT.md`.

**Check before you start:** `main` must include the **v0.2.6 hotfix** (commit
`c9385b3`, "successful sends were counted as errors"). If it doesn't, merge
branch `claude/short-kings-addon-hlf0t4` into your branch first and tell me.

## Why this, why now
The game is live. My guild says **professions are the most important part**
of the addon, so Professions moves ahead of Raids: **Professions = v0.3**,
**Raids = v0.4** (still before raids open on 9 Dec). Update PLAN.md,
CLAUDE.md and `docs/prompts/next-v0.4-raids.md` (rename it to `next-v0.4-raids.md`)
to match.

## What already exists (build on it, don't duplicate it)
- **Recipe scans:** opening a profession window records `recipes[skillLine] =
  {recipeID = itemID}` in each player's profile (`Collect/Professions.lua`),
  plus skill levels, cooldowns and a local "recipe universe" (every recipe the
  window lists, learned or not).
- **CraftIndex** (`Core/CraftIndex.lua`): recipe/item → crafters, async names.
- **Crafters tab** (search by item, crafter side panel, Whisper, Post to guild
  chat) and "Crafted by" item tooltips.
- **Overview:** a Professions card (coverage) and a Recipes card (single-crafter counts).
- Cooldowns (`cds`) are already synced; specialisations, reagents and
  favourites don't exist yet.

## Step 1: get the facts (before writing code)
1. Add `/sk debug` probes (`Commands.lua`, `Compat.PROBES`) for:
   - **Unlearned recipes:** does the profession window list them? The
     "Live-client checks" line exists but has never been answered.
   - **Reagents without the window:** does `C_TradeSkillUI.GetRecipeSchematic(recipeID, false)`
     return reagents (`reagentSlotSchematics`, item IDs, quantities) for a
     recipe when the window is closed, and for a recipe I don't know?
   - **Specialisations:** whether the candidate spell IDs below are known
     (`IsPlayerSpell` / `C_SpellBook`; verify the function names in the source).
   - **Forever's new profession content:** what the window shows for
     Blueprints and camp objects (category names), so we can decide whether a
     camp planner is possible. Record only what the client reports. Don't guess.
2. Give me exact in-game steps: learn a profession at a trainer, open its
   window, run `/sk debug`, and paste the result. Make it a short release
   (**v0.2.7**, probes only) if I need a download to do it.
3. Ask me **which 3 profession features the guild wants most**. Suggest a
   default order from the list below.
4. Write a short plan in `PLAN.md` (what goes in v0.3.0, what moves later)
   and **wait for my OK** before building.

## Step 2: v0.3.0 Professions (proposed; adjust after Step 1)
A new **Professions** tab, after Crafters, in the existing design system
(`UI/Theme.lua` tokens only; `tests/design_spec.lua` must stay green).

1. **Guild coverage board.** One row per profession, crafting first then
   gathering and secondary. Each row shows:
   - characters with it, how many at max skill, how many online now;
   - the highest skill;
   - the date of the most recent scan;
   - specialisations (from item 3).

   Professions nobody has are listed too. Click a row to open that profession.
2. **One profession.**
   - **Crafters list:** status dot, name ("alt of X"), skill, specialisation,
     "recipes recorded 3d ago", Whisper.
   - **Recipe list:** known in the guild, with crafter counts. Filters: All /
     Only one crafter / Favourites, plus *Nobody knows* if Step 1 confirms the
     window lists unlearned recipes.
   - Clicking a recipe reuses the Crafters side panel.
3. **Specialisations (B3).** The original game had only these:
   - Engineering: Gnomish / Goblin
   - Leatherworking: Dragonscale / Elemental / Tribal
   - Blacksmithing: Armorsmith / Weaponsmith (plus axe/hammer/sword masters)

   Alchemy and Tailoring specialisations came in The Burning Crusade, so
   **don't add them** unless the Forever client shows them. Spell IDs must be
   verified against two sources **and** the in-game probe, or kept as
   `status = "todo"`. Detect them at scan time (owner side) and add a small
   `spec` field per profession to the profile. Add it to `Merge.FIELDS`
   (`tests/security_spec.lua`) and keep older versions compatible.
4. **Cooldown board (B4).** Everyone's profession cooldowns: ready first, then
   time left. Show the recipe name, crafter and status, with Whisper. Say
   when the data is old (a cooldown only updates while its owner is online).
5. **Reagents (B2).**
   - Show a recipe's reagents (icon, name, quantity) in the Crafters side panel
     and the profession view.
   - Prefer reading them **locally** (`GetRecipeSchematic`) and caching them
     in SavedVariables. Reagents are game data, not player data, so **don't
     add them to synced profiles** unless Step 1 shows local reading is
     impossible. In that case, propose a design to me first; sync size matters
     (`Codec.MAX_ENCODED` is 32 KB).
   - Optional: "you have 3 / need 5" from your bags (`Compat`, `GetItemCount`).
6. **Favourites (B6):** star recipes and crafters. Saved locally, never sent.
   Add a Favourites filter in Crafters and Professions.
7. **Freshness nudges:** "Your Tailoring went from 240 to 262 since you last
   opened it. Open the window to update your recipes" (chat once per session,
   and on the tab). On the profession view, a crafter whose recipes are over
   7 days old shows that in orange.
8. Item tooltips: add the crafter's specialisation if it matters for that item
   (only if verified).

Keep the protocol compatible with guildmates on v0.2.5+. No new message types
in v0.3.0.

## Later (only if I say so after v0.3.0)
- **v0.3.1 Craft requests (D1):** "Ask to craft" from the Crafters/Professions
  views. The crafter gets a request with reagent totals and can accept or
  decline. This needs a new message type: follow the security rules in
  CLAUDE.md and `docs/SECURITY-REVIEW.md` (validate everything, rate limits,
  plain text only).
- Shopping list / reagent totals across several recipes (D6).
- Camp planner (P6), once Step 1 shows the data.
- "Where to get it" for missing recipes (D4), only with a verified data source.

## Rules that always apply (details in CLAUDE.md)
- Only `Core/Compat.lua` calls game APIs, after checking each one exists in
  Blizzard's Forever source (Gethe/wow-ui-source, `forever` branch: the
  `Blizzard_APIDocumentationGenerated` and `Blizzard_Professions*` folders).
- Never guess IDs. Received data is untrusted. Notes are never synced. Respect
  `hidden.recipes` (privacy) everywhere.
- Every change ships with:
  - busted tests (`busted --lua=lua5.1`) and a clean `luacheck .`;
  - README "What's inside" (list everything), CHANGELOG, TESTING.md (new in-game checks);
  - the browser preview and README pictures updated when the UI changes (see CLAUDE.md "Design refresh");
  - CLAUDE.md status.
- Commit as you go and push to your designated branch. No PR unless I ask.
  **Don't push to `main` or tag a release until I say so.**

## Definition of done
- Step 1 facts recorded in CLAUDE.md, and the plan in PLAN.md approved by me.
- v0.3.0 built, tested, documented and pushed. A short plain-language summary
  for me, with the TESTING.md items I should check in game and what to send back.
