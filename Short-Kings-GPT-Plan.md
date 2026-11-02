# Short Kings — GPT Product Review & Development Proposal

> **Purpose:** Product and development proposal prepared after reviewing the Short Kings repository and the WoW Retail / WoW Forever addon landscape.
> **Audience:** Claude (repository reviewer and implementation partner) and the project owner.
> **Status:** Proposal for critical review — not an approved implementation specification.

**Important:** This document contains product ideas and competitive observations, not verified API specifications. Validate every feature against the current repository, the actual WoW Forever client and Retail separately. Do not assume a Retail API or feature is available in Forever.

---

## 1. Executive summary

Short Kings should aim to become a **guild intelligence and preparation addon**, rather than another broad guild-administration suite.

Its differentiator should be the way it connects information it already collects:

- Guild members and their characters.
- Character progression, gear, talents, professions and recipes.
- Guild-wide crafting capability.
- Raid readiness and composition.
- Guild coordination and shared knowledge.

The central experience should be a **Guild Overview** that turns this data into useful, actionable information. It should help members and officers answer:

- What capabilities does our guild have?
- Who can craft a particular item?
- Which recipes or profession capabilities are missing?
- Are we prepared for the next raid?
- Which character profiles are incomplete or stale?
- What needs attention from members or officers?

### Recommended product pillars

1. **Guild Intelligence** — members, characters, activity, progression and data health.
2. **Profession Intelligence** — profession coverage, recipes, crafters, cooldowns and crafting workflows.
3. **Raid Intelligence** — composition, signups, readiness and preparation.
4. **Guild Coordination** — requests, events, announcements and shared knowledge.

All four pillars should draw from a coherent shared data model and feed the Guild Overview.

**Core recommendation:** Prioritise making existing data more useful before significantly expanding data collection or the sync protocol. Prefer features that connect existing systems over isolated features that add another tab.

---

## 2. Existing project context and constraints

The current repository is the source of truth for implementation status. This proposal must not overwrite or contradict it without investigation.

The existing architecture includes:

- Core — initialisation, compatibility, identity, saved data, alt handling and craft indexing.
- Collect — character, profile, talent, profession, reputation and attunement collection.
- Sync — peer-to-peer guild communication, requests, transfers, relaying and merge logic.
- Data — game-specific data tables.
- UI — roster, character, crafter and settings interfaces.
- tests — automated tests and simulated game API coverage.
- docs and root documentation — design, development and implementation notes.

Existing design decisions to preserve unless a concrete problem is found:

- Keep the addon self-contained; no mandatory external server.
- Preserve the decentralised peer-to-peer guild data model.
- Keep owner-authoritative profile data and sensible stale-data handling.
- Keep private/local profile information separate from information explicitly shared with the guild.
- Keep game API differences behind the compatibility layer (currently Core/Compat.lua or its successor).
- Reuse and extend the existing sync protocol instead of introducing parallel messaging systems.
- Keep data collection event-driven and respectful of client restrictions, combat, instance and chat messaging lockdowns.
- Maintain SavedVariables schema migrations and backwards compatibility.
- Do not invent or assume API behaviour, quest IDs, recipe IDs, cooldowns or item data.

### Critical current-state gate

Previous project documentation described v0.2.0 as code-complete but not yet validated in the actual game. Confirm the current status before planning new feature implementation.

**Real-client validation takes precedence over feature expansion.** Simulated tests cannot prove that the addon behaves correctly in a live Forever or Retail client.

---

## 3. Product direction and positioning

### Proposed positioning

> Short Kings is a guild intelligence and preparation addon. It gives guild members and officers a shared, useful picture of their characters, capabilities and readiness — without depending on an external service.

### Product principles

1. **Actionable, not merely descriptive.** Data should help users make a decision or take an action.
2. **Connected, not fragmented.** Roster, profiles, professions and raids should use the same underlying character data.
3. **Trustworthy data.** Clearly distinguish current, stale, missing, hidden, unknown and unverified information.
4. **Respect player privacy.** Sharing remains explicit and configurable; local/private data must not leak through UI, exports or sync.
5. **Offline-aware.** Show when information was last updated and avoid implying old peer-relayed data is live.
6. **Lightweight.** Avoid unnecessary polling, chat spam, expensive scans, excessive saved data or large UI rebuilds.
7. **Forever-first validation, Retail-aware architecture.** Do not compromise Forever to chase feature parity. Where Retail is supported, isolate differences and validate both clients independently.
8. **Useful to ordinary members and officers.** Do not turn the product into an officer-only administration panel.

---

## 4. Proposed feature programme

These are proposals for Claude to evaluate, not instructions to implement every item. Inspect existing code and roadmap entries, identify overlaps, and recommend what should be extended, deferred, simplified or rejected.

### 4.1 Guild Overview / Guild Intelligence Dashboard

**Priority: Very high — proposed central experience**

Introduce a Guild Overview as the default landing view, or first major tab if that better fits the existing UI.

It should answer: **How is our guild looking, and what needs attention?**

Potential cards and panels:

- **Guild population:** member count, online count, known addon users and members with no available data.
- **Character progression:** level distribution and other meaningful progression summaries supported by the game.
- **Profession coverage:** number of known crafters per profession, skill band and verified specialisation where supported.
- **Recipe coverage:** recipes known by the guild, recipes seen but not learned by any known member, and recipes with only one known crafter.
- **Raid readiness:** attunement/readiness summaries where data is verified and relevant.
- **Data health:** missing profiles, stale profiles, incomplete profession scans and addon version mismatch.
- **Upcoming events:** upcoming guild events if/when an event system exists.
- **Attention required:** actionable items such as stale profiles, missing data or gaps in profession coverage.

Example insights:
- “8 character profiles have not been refreshed recently.”
- “No known guild member has Engineering.”
- “This recipe is known by only one guild member.”
- “4 characters have an unknown attunement status.”
- “3 members have not completed a profession scan.”

Requirements:
- Do not imply addon-observed activity equals actual playtime or total game activity.
- Show source and age of data where useful.
- Treat unknown as unknown, not false or incomplete by default.
- Do not expose officer-only or private information to ordinary members.
- Avoid arbitrary scores or judgemental labels such as “bad member”.
- Dashboard metrics must be derived from real data and explain their coverage.
- Prefer cards that deep-link to the relevant roster/profile/profession/raid view.

### 4.2 Profession Intelligence

**Priority: Very high — build on existing Crafters and profession collection**

Expand the current crafter lookup into a connected guild profession system.

**A. Profession coverage**
- Members and characters with each profession.
- Skill level and known specialisation, where available.
- Main/alt grouping.
- Online status and last profile update.
- Clear unknown/hidden/not-scanned states.

**B. Recipe coverage**
- Searchable guild-wide recipe directory.
- Find crafters for a recipe or craftable item.
- Show how many known guild members have the recipe.
- Identify recipes known by only one member.
- Identify recipes seen by the guild but not learned by any currently indexed member, only if the client exposes reliable unlearned-recipe data.
- Recipe favourites or frequently used recipes.

**C. Cooldown board**
- List profession cooldowns that the client can reliably identify.
- Show character, crafter, readiness and next available time.
- Clearly indicate timestamp and freshness of source data.
- Do not infer cooldown availability from an old profile.

**D. Crafting requests**
- A member can request an item or recipe.
- Capture quantity, optional note and whether materials are supplied.
- Show status: open, claimed/accepted, in progress, completed or cancelled.
- Let a crafter claim or decline a request.
- Let the requester mark a request complete.
- Provide a way to contact the crafter (e.g. whisper) without sending messages automatically.

**E. Crafting tooltip integration**
- Retain or improve existing crafter tooltip functionality.
- Show useful guild availability without cluttering default item tooltips.
- Respect privacy and data freshness.

**Competitive context:** Retail addon Ultimate Profession Master is a strong reference for profession and recipe discovery. Short Kings should not blindly recreate its entire feature set. Its opportunity is to connect crafting information to guild identities, requests, availability and wider guild intelligence.

### 4.3 Raid Intelligence and Readiness

**Priority: Very high — build on planned Raids functionality**

The goal should be more than a calendar. Help raid leaders understand whether a group is viable and prepared.

**Raid/event overview**
- Event date and time.
- Signup states such as confirmed, tentative and declined.
- Character selected for the event.
- Main/alt identity.
- Role preference where available.
- Notes and relevant readiness indicators.

**Composition view**
- Visual role distribution (tank, healer, damage roles as appropriate).
- Class distribution.
- Raid capacity and gaps.
- Identify duplicate signups or conflicting character choices.
- Allow raid leaders to assign or adjust roles where appropriate.

**Readiness view**
- Attunement state where relevant and verified.
- Gear/item-level summary only where the game provides reliable values.
- Missing enchantments only where item and enchant data are verified.
- Character profile freshness and missing data.
- Profession capabilities relevant to the event, if useful.
- Clear distinction between “not ready”, “unknown” and “not scanned”.

**Templates**
- Save raid templates or expected role distributions.
- Reuse event settings for recurring raids.
- Avoid hardcoding a single raid size or composition.

**Reminders**
- Optional local reminders or addon notifications if technically and UX-appropriate.
- Do not promise notifications while a player is offline unless a reliable external mechanism exists.

Restrictions:
- Validate what the Forever client actually exposes.
- Do not promise automated combat, aura, buff, encounter or performance analysis where secret-value restrictions or API limitations make it unreliable.
- Do not infer a player's willingness or availability from online status.
- Make readiness configurable by content and guild expectations.

### 4.4 Character Progression and History

**Priority: Medium — valuable differentiator, but data-retention cost must be considered**

Current profiles are primarily snapshots. Consider introducing a concise history of meaningful changes:

- Level milestones.
- Gear/item-level changes.
- Profession skill milestones.
- New recipes learned.
- Reputation milestones.
- Attunement completion.
- Main/alt relationship changes where relevant.

A character history could show dated events such as reaching level 60, completing a raid attunement, learning a notable recipe, reaching a profession milestone, or a profile refresh with a gear change.

Requirements:
- Store meaningful deltas rather than duplicating full snapshots.
- Add retention limits and pruning.
- Consider SavedVariables growth across a large guild.
- Avoid collecting or sharing more history than necessary.
- Respect privacy controls and allow users to opt out of sharing relevant history.
- Do not present an incomplete addon-observed timeline as a complete record of character activity.

### 4.5 Crafting and Reagent Planner

**Priority: Medium — build only after recipe data is trustworthy**

A workflow that starts with a desired craft and helps the guild fulfil it:

1. Search for/select an item or recipe.
2. Identify guild members who can craft it.
3. Display required reagents where recipe data is available and verified.
4. Allow the requester to enter quantities and materials already owned.
5. Calculate outstanding reagent quantities.
6. Identify other known guild crafters or suppliers where data exists.
7. Produce a consolidated shopping/reagent list.
8. Optionally connect the plan to a crafting request.

Potential later enhancement: combine multiple recipe requirements into one consolidated reagent list.

Requirements:
- Never fabricate recipe reagent data.
- Account for recipe rank/quality/optional reagents only if relevant to the client and supported.
- Be clear whether quantities are exact or estimates.
- Avoid auction house integration unless there is a compelling, technically viable reason.

### 4.6 Guild Activity and Member Engagement

**Priority: Medium — useful for officers, but easy to misrepresent**

Potential officer-facing metrics:
- Addon-observed active members over 7/30/90 days.
- Returning players observed by the addon.
- Members whose profiles have not been refreshed recently.
- Raid participation if a reliable signup/attendance system exists.
- Character progression snapshots.
- New members and departures, if the addon can reliably observe them.

**Onboarding view for new members**
- New guild members.
- Their known characters and professions.
- Main character if identified.
- Profile completeness.
- Whether Short Kings is installed and has shared data.
- Suggested setup steps.

Requirements:
- Clearly label metrics as addon-observed.
- Never claim to know total playtime or activity while the addon is not running.
- Avoid surveillance-like functionality.
- Keep sensitive officer observations private.
- Do not create public rankings that shame or expose players.

### 4.7 Guild Knowledge Centre

**Priority: Low — defer until core intelligence is strong**

A lightweight shared area for guild information:
- Raid strategies and boss notes.
- Guild rules and expectations.
- Profession and attunement guides.
- Important NPCs and locations.
- Guild announcements.
- Useful links or short text guides.

Start with simple officer-managed notes or announcements distributed through existing sync. Do not build a full wiki engine or rich document editor unless real guild usage justifies it.

### 4.8 Additional coordination features

Consider, but do not prioritise ahead of the core pillars:
- Guild announcements.
- Event reminders.
- Member onboarding checklist.
- Discord-friendly text exports.
- Useful roster/profile exports.
- Officer-only notes and tools, with clear permissions.
- Simple request/response workflows beyond crafting if a concrete need emerges.

---

## 5. Competitive research and lessons

The original review considered the following addons as references. Treat these as research leads, not proof that every listed feature is current, available in Forever, or implemented exactly as described. Verify current project pages, supported game versions and actual feature sets before relying on them.

### Retail references

| Addon | Area worth studying | Potential lesson |
|---|---|---|
| Guild Roster Manager (GRM) | Guild administration, member history, main/alt management | Member lifecycle and history patterns |
| Ultimate Profession Master (UPM) | Recipe directory, profession discovery, cooldowns, crafting | Deeper profession workflows |
| Guild Paragon | Dashboard, member analytics, officer workflows | Actionable overview and information hierarchy |

- GRM: https://www.curseforge.com/wow/addons/guild-roster-manager
- UPM: https://www.curseforge.com/wow/addons/togprofessionmaster
- Guild Paragon: https://addons.wago.io/addons/guild-paragon

### WoW Forever references

| Addon | Area worth studying | Potential lesson |
|---|---|---|
| ForeverGuild+ | Guild suite, profiles, crafting, raid and loot workflows | Direct competitor; identify feature overlap and gaps |
| Guild Muster | Events, signups, loot, guild coordination | Event UX and dashboard prioritisation |
| GuildOS | Cross-version guild management and analytics | Compatibility and broader guild intelligence |
| Perpetua | Profiles, gear, talents, professions, attunements and sync | Closest conceptual comparison; study data model and UX |

- ForeverGuild+: https://www.curseforge.com/wow/addons/foreverguildplus
- Guild Muster: https://www.curseforge.com/wow/addons/guild-muster
- GuildOS: https://www.curseforge.com/wow/addons/guild-os
- Perpetua: https://github.com/Damndionic/Perpetua

### Competitive strategy

Do not try to win by matching every feature in every competitor.

The recommended differentiation is **joined-up guild intelligence**:
- Character data informs profession availability.
- Profession data informs crafting requests and raid preparation.
- Raid signups connect to character readiness.
- Data freshness and completeness inform the dashboard.
- The dashboard directs users to the next useful action.

Prefer a small number of polished, connected workflows over a large number of shallow tabs.

---

## 6. Recommended phased roadmap

Phases are ordered by dependency and product value, not guaranteed release dates. Claude should revise the order after reviewing the actual code, current PLAN.md, open TODOs and test coverage.

### Phase 0 — Validate and stabilise existing product

**Gate: do this before major feature expansion.**

- Confirm current release/version and what has changed since the original v0.2.0 plan.
- Run all automated tests and linters.
- Test the addon in the actual WoW Forever client.
- Test install, upgrade and SavedVariables migration.
- Test with multiple guild members and realistic guild size.
- Validate sync under reconnects, partial transfers, stale relays and simultaneous profile updates.
- Validate privacy boundaries and owner-authoritative merging.
- Test UI interactions and performance with a populated dataset.
- Confirm every collector and UI element handles missing/unknown data.
- Record verified API behaviour and reproduce bugs.

**Exit criteria:** A documented, reproducible baseline with known issues and a reliable test process.

### Phase 1 — Guild Intelligence foundation

- Design Guild Overview information architecture.
- Define metrics and their exact data sources.
- Add data freshness/completeness states consistently.
- Add deep links from dashboard cards to relevant views.
- Build profession coverage summaries from existing data.
- Avoid new sync messages unless the data model genuinely requires them.

**Exit criteria:** The dashboard provides useful, accurate information using existing shared data.

### Phase 2 — Profession Intelligence

- Refine profession coverage and search.
- Improve recipe directory and crafter discovery.
- Add recipe coverage gaps only where the scan model supports reliable conclusions.
- Add cooldown tracking where APIs and collection timing support it.
- Introduce crafting requests as a small, well-defined workflow.
- Improve item tooltip integration.
- Add tests for permissions, stale data, offline crafters and request state transitions.

**Exit criteria:** A member can reliably find a guild crafter and create/complete a request without manual coordination overhead.

### Phase 3 — Raid Intelligence

- Implement or refine planned Raids tab.
- Add event signups and character selection.
- Add role and composition views.
- Connect raid members to character profiles and readiness data.
- Add templates and recurring event support if justified.
- Add permission handling for raid leader/officer actions.

**Exit criteria:** A raid leader can review signups, composition and known readiness gaps in one workflow.

### Phase 4 — Progression and guild operations

- Add concise character progression history.
- Add retention and pruning.
- Add addon-observed activity summaries.
- Add new-member onboarding.
- Add officer-facing analytics only where data is reliable and privacy-safe.

**Exit criteria:** Historical and engagement features provide real value without excessive data growth or misleading activity claims.

### Phase 5 — Reagent planning and knowledge

- Build reagent planning on verified recipe data.
- Add consolidated shopping lists.
- Add lightweight guild announcements/knowledge notes.
- Consider exports and external integrations based on actual usage.

**Exit criteria:** These features are used by the guild and do not destabilise the core addon.

---

## 7. Technical and architectural guidance

Claude should inspect the actual code and propose concrete changes rather than assuming all of these are needed.

### Data model and quality
- Establish consistent metadata for updatedAt, source, owner, visibility, completeness and schema version where appropriate.
- Model states distinctly: known, unknown, not scanned, hidden/private, unavailable and stale.
- Avoid using nil, false and empty arrays interchangeably.
- Ensure peer-relayed data retains original ownership and source timestamps.
- Ensure stale data cannot overwrite fresher owner-authoritative data.
- Define retention and pruning before introducing history or activity records.

### Synchronisation
- Reuse the existing protocol and transfer mechanisms.
- Assess payload growth before adding fields to frequently broadcast manifests.
- Prefer on-demand transfer for larger datasets such as history or knowledge content.
- Keep message sizes and send frequency within client limits.
- Handle partial, duplicate, out-of-order and interrupted transfers.
- Preserve compatibility/version negotiation.
- Ensure private data is never included in public sync payloads.
- Do not add a new sync message until data ownership and distribution requirements are documented.

### Compatibility
- Keep client-specific API calls in the compatibility layer.
- Validate Forever and Retail separately.
- Detect optional API availability at runtime.
- Do not rely on build numbers alone where feature detection is safer.
- Respect secret-value restrictions, combat lockdown and chat messaging lockdown.
- Do not use unsupported APIs or infer unavailable data.
- Keep game-specific data tables versioned and evidence-based.

### UI and usability
- Preserve the existing Short Kings visual identity unless usability testing shows a reason to change it.
- Use a consistent visual hierarchy for status, freshness and warnings.
- Avoid overloading the dashboard with every possible metric.
- Provide search, filters and sensible empty states.
- Make navigation from summary to detail straightforward.
- Keep officer-only actions visibly distinct and permission-checked.
- Ensure the UI remains usable with large guild rosters and recipe lists.
- Avoid expensive full-frame rebuilds for small data changes.

### Security, privacy and permissions
- Treat guild channel messages and received data as untrusted input.
- Validate message schemas, sizes, identifiers and state transitions.
- Keep user-controlled privacy settings authoritative.
- Avoid sharing private notes, personal history or local-only profile data.
- Ensure officer-only data is not visible through alternate UI paths, tooltips, exports or sync payloads.
- Make new sharing behaviour explicit and documented.

### Tests and quality

Add or extend tests for:
- Data freshness and merge precedence.
- Missing/unknown/private states.
- Schema migrations.
- Sync interruptions and duplicate messages.
- Permission checks.
- Large guild datasets.
- Recipe coverage and cooldown state.
- Craft request state transitions.
- Raid signup and composition calculations.
- Retention and history pruning.
- Compatibility fallbacks.

Automated tests are necessary but not sufficient. Maintain a manual in-game validation checklist for both supported clients.

---

## 8. Features to avoid or defer

Do not expand the project indiscriminately. Unless new evidence justifies them, defer:

- Full DKP/EPGP/loot council replacement.
- Auction house replacement or full economy suite.
- Full guild bank replacement.
- Automated combat analysis or performance scoring.
- Complex recruitment automation.
- A mandatory external website, database or server.
- Full group finder replacement.
- Full wiki/document editor.

These add considerable scope and are not central to the proposed product identity.

---

## 9. Decisions Claude should make during review

Before implementation, produce a concise review answering:

1. Which proposals already exist in code or PLAN.md?
2. Which proposals are genuinely new?
3. Which existing modules can support them without architectural changes?
4. What data is already collected, shared and stored?
5. Which proposed metrics can be derived from existing data?
6. Which require new collection, sync payloads or SavedVariables schema?
7. Which are feasible in Forever, Retail, both, or neither?
8. What client API evidence is needed before implementation?
9. What should be cut, deferred or simplified?
10. What is the smallest useful first release that delivers the new product direction?

Challenge this proposal where it conflicts with the code, technical constraints, actual game behaviour or project priorities.

---

## 10. Instructions for Claude — review and implementation workflow

Read this document together with CLAUDE.md, PLAN.md, README.md, CHANGELOG.md, current source code, tests and relevant docs. Do not treat this file as a replacement for those documents.

### Step 1 — Repository-grounded review
- Inspect the current branch and working tree.
- Read the current implementation, not just documentation.
- Identify what has changed since this proposal was written.
- Map each proposal to existing modules, data structures and UI.
- Verify competitor claims and current game compatibility where relevant.
- Check current WoW Forever and Retail API constraints against authoritative/current sources.
- Identify contradictions, duplication, risks and dependencies.

### Step 2 — Produce a recommendation

Label every proposal:
- **Adopt** — valuable and technically justified.
- **Adapt** — useful but needs a different scope or design.
- **Defer** — worthwhile but dependent on more important work.
- **Reject** — low value, redundant or technically unsuitable.

For each adopted/adapted item, include:
- User problem solved.
- Proposed user experience.
- Existing modules to reuse.
- New modules/data structures required.
- SavedVariables and sync implications.
- Privacy/permission implications.
- Forever/Retail compatibility.
- Tests and in-game validation.
- Dependencies and acceptance criteria.

### Step 3 — Reconcile the roadmap
- Update or propose updates to PLAN.md so there is one clear source of truth for implementation status and sequencing.
- Do not leave two conflicting roadmaps.
- Keep GPT-PLAN.md as the product proposal and review record; keep PLAN.md as the agreed implementation roadmap.
- Preserve completed work and existing project decisions unless there is a clear reason to change them.

### Step 4 — Implement incrementally
- Prioritise Phase 0 validation and critical fixes.
- Implement one coherent feature slice at a time.
- Do not attempt the entire programme in one large change.
- Add tests alongside each feature.
- Keep compatibility and privacy boundaries intact.
- Update CHANGELOG.md and relevant documentation.
- Report changed files, tests run, test results and anything requiring in-game verification.
- Do not claim in-game validation unless it has actually been performed.
- If a feature depends on unverified Forever APIs, document the verification requirement rather than guessing.

### Step 5 — Keep the owner informed

At each meaningful milestone, provide:
- What was reviewed or implemented.
- Why the approach was chosen.
- What changed.
- Tests and validation completed.
- Known limitations.
- The next recommended step.

Do not silently make broad product decisions or remove existing functionality. Explain material trade-offs and flag decisions requiring owner input.

---

## 11. Definition of success

Short Kings is succeeding when a guild member can:
- Find the right character and understand whether its profile is current.
- Find a guild member who can craft a requested item.
- Understand what profession and recipe capabilities the guild has.
- Coordinate a simple craft request.
- See useful guild information without manually inspecting every character.

An officer or raid leader can:
- Understand the guild's known character and profession coverage.
- Identify missing or stale information.
- Review raid signups and composition.
- Understand known readiness gaps without misleading assumptions.
- Coordinate members using the same shared data.

The addon remains:
- Reliable in the actual supported game client(s).
- Lightweight and respectful of WoW API restrictions.
- Decentralised, with no mandatory external service.
- Privacy-conscious and transparent about data freshness.
- Maintainable, tested and documented.

**The ultimate product goal:** Short Kings should make the guild collectively more capable by making its existing people, characters and knowledge easier to discover and coordinate.
