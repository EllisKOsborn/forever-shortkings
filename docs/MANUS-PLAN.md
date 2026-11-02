# Manus Plan: Short Kings validation and next improvements

**Audience:** Claude reviewing or implementing this repository.
**Status:** Proposal for review; no implementation authorized by this document alone.
**Scope:** Follow-up to the repository and addon-ecosystem review. This plan does not claim that any current or proposed behavior has been tested in WoW.

## Direction

Short Kings already has a broad feature set in code, but it has not been validated in the live WoW Forever client. Validate the existing addon before adding more modules. Once the current data and sync paths work reliably, improve the addon’s trust, privacy clarity and usability rather than trying to reproduce every feature in larger guild suites.

Do **not** treat this document as approval to implement every stage. Review it with the user first, especially stages that change persisted data, the sync protocol, profile visibility or roadmap priorities.

## Guardrails

- `CLAUDE.md` remains the project’s primary instruction file. Preserve its API, privacy, sync, licensing, testing and release rules.
- `Core/Compat.lua` remains the only place for client-specific API calls. Verify Forever APIs against Blizzard’s Forever UI source; do not infer support from Retail or another Classic client.
- Do not copy code from other addons. Their feature descriptions may inform product decisions; Perpetua’s code is explicitly unlicensed in the current project notes.
- Never guess quest, faction, spell or recipe IDs. Verify them or leave them explicitly unknown/TODO.
- Do not describe mockups or stubbed tests as in-game validation. Only the user’s live-client test or an explicitly documented real-client run can establish that.
- Every implementation stage must include relevant Busted tests, clean `luacheck .`, and updates to `README.md`, `CHANGELOG.md` and `TESTING.md`. Update mockups when the UI changes.
- Do not push to `main`, create a PR, or publish a release unless the user asks.
- Avoid introducing a web service, external account, dashboard or automatic guild-chat reply. Those would change the project’s no-server, in-game-first promise and need explicit approval.

## Current context

The repository contains profile collection, sharing, roster and character views, alt grouping, a crafter index, item tooltip integration, sync diagnostics and a stubbed-client test suite. The current testing checklist says no features have yet been confirmed in-game. See [TESTING.md](TESTING.md), [PLAN.md](PLAN.md), [docs/FEATURE-REVIEW.md](docs/FEATURE-REVIEW.md) and [CLAUDE.md](CLAUDE.md).

The current roadmap already has a v0.3 calendar/raid milestone and a v0.2.x professions milestone. Do not silently reorder or delete those. First surface any conflict to the user. In particular, the first recommendation in this plan is validation of existing code, not implementation of a new tab.

## Stage 0 — Validate the existing alpha (highest priority)

**Goal:** Find live-client compatibility and data correctness issues before feature work.

1. Use the existing checklist in `TESTING.md` as the base. Confirm the live interface number and addon load status first.
2. Test the minimum end-to-end path with two addon users: collect one profile, announce it, request it, receive it, and display it. Repeat with a third client or later login to test offline relay/backfill.
3. Explicitly verify the open questions in `PLAN.md`: two-part sender-name format, roster name/GUID mapping, GUID stability across sessions, and actual profession recipe-list completeness.
4. Exercise sharing toggles and sync pausing in combat, instances and chat lockdown. Verify that received profiles reflect changed privacy choices and that retries do not create duplicate or excessive traffic.
5. Test one main and one alt, including the alt-online/crafter-whisper paths. Check how incomplete, stale and relayed records are represented.
6. Save the observed client build/interface and relevant `/sk debug` output with the user’s permission. Turn reproducible failures into focused tests using `tests/helpers/wow.lua` where feasible.

**Exit criteria:** The user confirms the addon loads on the intended live client; at least two clients exchange and display a profile; identity is stable for the tested cases; profession scanning is accurately characterized; no blocking Lua error remains in the exercised flows. Any unresolved API/data limitation is documented and shown as unknown instead of implied success.

**Implementation boundary:** Fix blockers discovered during this stage only. Do not combine validation fixes with a new feature. Keep any implementation small enough to review against one failure at a time.

## Stage 1 — Make profile data easier to interpret

**Goal:** Distinguish different reasons that a value is absent or unreliable. Reuse existing update timestamps, scan state, privacy flags and addon version before adding new sync fields.

Candidate UI and diagnostic improvements:

- In the relevant profile or roster tooltip, distinguish **not scanned**, **hidden by member**, **no Short Kings profile**, **stale cached profile**, **unsupported/unverified data**, and **known negative** where the code can establish that reason.
- Show a concise profile freshness/source indicator and profession scan completeness in the Character and Crafters views, not only in diagnostics.
- Add a compact “data health” section to Settings or the debug window that explains why useful fields are missing and offers the existing safe action (rescan, ask for latest, open profession window, or wait for the client API).
- Do not report “unsupported API” unless runtime detection actually establishes that; use “unknown” when the client cannot distinguish causes.

**Likely files:** `UI/CharacterTab.lua`, `UI/CraftersTab.lua`, `UI/RosterTab.lua`, `UI/SettingsTab.lua`, `Commands.lua`, and their existing tests. Add or change `Core/Compat.lua` only for verified client-specific API behavior.

**Acceptance criteria:** Each new state has a clear, non-misleading label; hidden data remains hidden; cached data remains available where appropriate; no new profile data is broadcast unless justified; tests cover each state and UI rendering. Update screenshots/mockups if visible layout changes.

## Stage 2 — Clarify sharing and privacy controls

**Goal:** Help players understand what the addon shares and what privacy settings do, without promising control over copies that are already cached on peers.

First implement a read-only **sharing preview** using the existing profile/public projection. It should show categories shared or withheld (for example gear/talents and recipes/cooldowns), when the owner profile was last updated, and whether sync is currently enabled/paused. Reuse existing `Profile.Public` behavior rather than duplicating the rules in the UI.

Before implementing any “delete my data from everyone” or withdrawal feature, design the protocol semantics and review them with the user. Offline peers can retain old copies; a local toggle cannot guarantee erasure from every client. If a tombstone or deletion message is considered, specify protocol versioning, relay behavior, expiration, rejoin behavior, stale-client behavior, and how an owner can re-share later. Do not claim global deletion unless it can be demonstrated.

**Likely files:** `Collect/Profile.lua`, `UI/SettingsTab.lua`, `Sync/Sync.lua`, `Sync/Merge.lua`, `tests/identity_db_spec.lua`, `tests/sync_spec.lua`, and UI tests. Only the preview is in scope until protocol design has approval.

**Acceptance criteria:** The preview matches the actual outgoing public profile for every privacy-toggle combination; local full profile remains intact; notes/officer notes remain excluded; tests confirm no hidden category leaks through direct sends or relays. Any later protocol change gets backward-compatibility tests and explicit user approval before implementation.

## Stage 3 — User-triggered export

**Goal:** Make the in-game data useful in guild coordination outside the addon while retaining the no-server promise.

Start with one user-triggered, copyable plain-text export, selected by the user from roster, crafters or a raid lineup. Do not implement automatic uploads, a website, or automatic chat posting. Before choosing CSV or a longer export format, inspect the Forever client’s available copy/paste mechanism and test it in game. Keep exported fields intentionally limited; do not include officer notes, private profile categories or personal identifiers beyond the chosen character names without a clear user-facing choice.

**Acceptance criteria:** The user sees a preview or clear destination before copying; no text is sent to chat automatically; private fields are excluded; line lengths and formatting work in the actual chat/edit-box interface; tests cover escaping, empty values and privacy-filtered data.

**Roadmap note:** The existing `PLAN.md` already lists plain-text export as D8. Treat this stage as refining and validating that item, not a new competing roadmap entry.

## Stage 4 — Explore one Forever-native guild-goal feature

**Goal:** Investigate a focused Forever-specific use case rather than building another general guild suite.

Explore a small **guild goals/Legacy journey** view only after the current profile/sync path is stable. Begin with a feasibility investigation: determine which Legacy milestones, account progress or related goals are actually exposed to addons on the target Forever build. Use the official client source/API docs; add no guessed IDs and no unsupported completion claims.

If objective state can be read reliably, prototype one small opt-in milestone category. If it cannot, a player-maintained goal may be considered only if it is clearly labeled self-reported and does not imply automatic verification. Reuse the account/alt model where appropriate, but do not silently store account-level data in a character profile without a schema decision.

Before implementation, compare the smallest useful slice with existing Forever addons and explain why it adds value to Short Kings specifically. Agree scope with the user; this is exploratory, not committed roadmap work.

**Acceptance criteria for a prototype:** One narrowly scoped goal, an explicit source label (observed or self-reported), privacy/default-sharing decision documented, tests for missing/unknown states, and a mockup reviewed before broad UI implementation.

## Explicitly defer

- A broad “all guild features” suite, officer administration, loot council/DKP, an Auction House profit engine, a website/dashboard, Discord integration, and automatic guild-chat responses.
- Full request-board/contribution/leaderboard functionality until the user chooses it over existing roadmap work. Crafting requests are already covered by other Forever addons and are present as a later idea in `PLAN.md`; any proposal should identify a specific Short Kings advantage rather than clone their feature lists.
- New sync message types, new persistent fields or schema migrations before live validation and a written compatibility/rollback plan.
- Cosmetic animation work ahead of correctness, accessibility and data clarity.

## Working method for Claude

For each stage, begin by reporting the files and behavior you expect to change. If implementation is requested, do one stage at a time. Keep unrelated refactors out. Inspect current code before editing, add tests alongside behavior changes, run `busted --lua=lua5.1` and `luacheck .`, then update all required docs. Report exactly what was tested and what still needs the user’s in-game confirmation. Ask before changing protocol semantics, profile-sharing defaults, persisted data formats, the published roadmap or release branch.
