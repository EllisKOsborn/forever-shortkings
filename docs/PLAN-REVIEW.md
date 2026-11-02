# Review of the GPT, Manus and Perplexity plans (2 Nov 2026)

Claude's review of [GPT-PLAN.md](GPT-PLAN.md), [MANUS-PLAN.md](MANUS-PLAN.md)
and [PERPLEXITY-PLAN.md](PERPLEXITY-PLAN.md), checked against the code
(v0.2.0), [CLAUDE.md](../CLAUDE.md), [PLAN.md](../PLAN.md), Blizzard's
Forever 1.60.1 UI source and Blizzard's raid overview. The three plans
remain the proposal record. **PLAN.md section 7 is the single agreed
roadmap**; this file explains how it was reconciled.

Labels: **Adopt** (as proposed) · **Adapt** (useful, different scope) ·
**Defer** (worth it, depends on something first) · **Reject**.

## 1. Where the three plans agree

| Theme | GPT | Manus | Perplexity | Verdict |
|---|---|---|---|---|
| Prove it in game before building more | Phase 0 gate | Stage 0 | P3 | **Adopt.** Nothing has run in game. New features wait for the first test round, except small fixes and test tooling |
| Be clear about missing, hidden, stale and unknown data | 4.1 data health, §7 states | Stage 1 | — | **Adapt** (v0.2.1 labels; full data-health card in the Overview) |
| Plain-text export | 4.8 | Stage 3 | P9 | **Adopt** (= PLAN D8, pulled forward) |
| Raids on Blizzard's calendar, with readiness | 4.3 | — | P11, P12 | **Adopt** (already planned as v0.3; readiness card folded in) |
| Craft requests | 4.2 D | deferred | P14 | **Defer** to after 9 Dec (needs a new message type) |
| No DKP, loot, website, AH or bank suite | §8 | defer list | not recommended | **Adopt** (matches PLAN "Not planned") |

## 2. Technical constraints that shape the order

1. **Untested client.** Sender name format, roster GUIDs, GUID stability,
   unlearned recipes and calendar availability are all unconfirmed. Any
   feature built on them risks rework.
2. **Protocol changes are expensive.** Every new field on the wire needs
   old-client tolerance and a test. `Merge.Validate` already ignores
   unknown profile fields, so *new profile fields* are cheap. *New message
   types* (status line, craft requests, addon-native events) are not.
3. **Midnight restrictions.** No aura or combat reads in instances;
   `SendChatMessage` is restricted; calendar invite reads are secret during
   chat lockdown. Anything that "posts" must pre-fill the chat box.
4. **IDs must be verified** (CLAUDE.md). This blocks the camp planner (P6)
   and the amulet step tracker (P10) until their spells and quests are confirmed.
5. **Size and privacy.** History, activity and feeds must stay local or be
   pruned. Nothing private goes on the wire.
6. **Forever only.** GPT's "Retail-aware architecture" isn't a goal. The guild
   plays Forever, and `Compat.lua` already isolates the client.

## 3. GPT-PLAN

| Item | Verdict | Reasoning |
|---|---|---|
| 4.1 Guild Overview dashboard | **Adapt** | Good idea, wrong time and size. Build a small **Overview** tab after the first test round (v0.2.3), from existing data only: population, data health, profession coverage, raid readiness, levelling feed. No scores. It isn't the default tab until it proves useful |
| 4.2 A Profession coverage | **Adapt** | Coverage summary goes in the Overview. The Professions tab follows after 9 Dec |
| 4.2 B Recipe coverage | **Adopt, partly built** | Search and crafter lookup shipped in v0.2.0. "Only one crafter" is derivable from `CraftIndex` → Overview. "Nobody has it" depends on whether unlearned recipes are visible (P3) |
| 4.2 C Cooldown board | **Defer** | Planned B4. Data is already collected; build it with the Professions tab |
| 4.2 D Crafting requests | **Defer** | New message type, state machine and spam limits. After v0.3 |
| 4.2 E Tooltips | **Done** | v0.2.0 |
| 4.3 Raid intelligence | **Adopt** | = v0.3 prompt. Add "duplicate sign-ups by the same player" (alts) and a readiness summary |
| 4.3 Templates | **Adapt** | Addons can't create events (`AddEvent` restricted). Keep a raid table (size, keywords) |
| 4.4 Progression history | **Adapt** | As Perplexity's P7: derived locally from profile changes, capped at 50 entries, never synced |
| 4.5 Reagent planner | **Defer** | Needs reagent data (B2), recorded at scan time |
| 4.6 Activity metrics | **Reject** (except data freshness) | "Addon-observed activity" for 50 friends reads like surveillance, and the roster already shows last online |
| 4.6 Onboarding view | **Adapt** | Becomes "needs setup" lines in the Overview's data health (no addon, profession not scanned) |
| 4.7 Knowledge centre | **Defer** | Low value now. Discord does this |
| 4.8 Announcements, exports | Exports **Adopt** (P9); announcements **Defer** |
| §7 Distinct data states | **Adopt** | v0.2.1 labels, then the Overview |
| §7 Retail validation | **Reject** | Forever only |

## 4. MANUS-PLAN

| Stage | Verdict | Reasoning |
|---|---|---|
| 0 Validate the alpha | **Adopt** | Gate. TESTING.md plus the new `/sk debug` probes and error capture |
| 1 Clearer data states | **Adopt (small)** | Character tab: "relayed copy", "stale" (> 7 days) and "not scanned" labels. Debug: data-health lines |
| 2 Sharing preview | **Adopt** | Read-only, uses `Profile.Public` itself, so it can't drift from what's sent |
| 2 Delete my data from everyone | **Defer** | Can't be guaranteed (offline copies). Needs a protocol design and owner approval |
| 3 Export | **Adopt** | = P9 |
| 4 Legacy and guild goals | **Defer** | Needs evidence of what the client exposes (P16 as well) |

## 5. PERPLEXITY-PLAN

The decisions are also recorded in its section 7.

| Item | Verdict | Reasoning |
|---|---|---|
| P1 Attunement table | **Modify, adopt** | Verified: Blizzard's overview lists attunement only for Onyxia ("Drakefire Amulet is in your inventory. It does not need to be equipped"), and Icy Veins says Barrow Deeps and Hyjal have none. Amulet item 16309 is confirmed by warcraft.wiki.gg and Wowhead Forever. MC/BWL/Naxx are hidden from the picker (data kept). The amulet is checked with `C_Item.GetItemCount` (Forever docs; bags only by default) and shown alongside the quest, not instead of it |
| P2 CLAUDE.md tense | **Adopt** | |
| P3 Proof pass | **Adopt** | Calendar probes, GUID stability, sender and roster samples, unlearned-recipe count |
| P4 Error capture | **Adopt** | Last 10 errors in `/sk debug` |
| P5 Distribution | **Modify** | Packaging already exists. A small "update available" line in the Roster counter now; CurseForge/Wago need the owner's accounts |
| P6 Camp planner | **Defer** | Needs verified camp objects and spells. Revisit once the owner sees them in game |
| P7 Levelling feed | **Adopt** (v0.2.3) | Local only, no protocol change. Time-sensitive (5 weeks of levelling), but after the first test round |
| P8 Status line | **Defer** | First free text on the wire, plus a protocol change. Not before validation |
| P9 Copy for Discord | **Adopt** | v0.2.1 |
| P10 Amulet step tracker | **Modify, defer** | v0.2.1 has quest done + amulet in bags. Per-step tracking needs ~16 verified quest IDs (two sources each) |
| P11 Raid night card | **Merge into v0.3** | It's the line-up's readiness summary |
| P12 / P13 | **Adopt P12**, P13 only if P3 shows the calendar is unusable | |
| P14 Craft requests | **Defer** (after v0.3) | |
| P15 Lockout board | **Defer** | `GetSavedInstanceInfo` isn't verified yet |
| P16 Legacy viewer | **Defer** | Evidence needed |
| P17 API contract check in CI | **Adopt** (v0.2.2) | Cheap, catches renamed APIs |
| P18 Decompression cap | **Adopt** | Cap encoded size at 32 KB (a full crafter profile is ~4 KB) |
| P19 Per-sender rate limit | **Adopt** | Simple window counter, before decoding |
| P20 Stronger hash | **Reject** | The hash only detects changes; nothing secret is synced |

## 6. Answers to GPT §9

1. **Already in code or PLAN:** tooltips, crafter search, roster health
   (Ver, Data columns), raids (v0.3), exports (D8), craft requests (D1),
   cooldown board (B4), coverage (B5).
2. **New:** Overview tab, levelling feed, sharing preview, error capture,
   camp planner, status line, amulet tracker.
3. **No architecture change needed for:** Overview, feed, preview, export,
   probes, attunement fix (all reuse `Profile`, `CraftIndex`, `Identity`, `Alts`).
4. **Collected and shared:** basics, gear, ilvl, talents, professions,
   recipes, cooldowns, reputations, attunements, family, main, hidden flags.
5. **Derivable now:** population, addon users, stale and missing profiles,
   unscanned professions, crafters per profession, single-crafter recipes,
   attunement counts, level distribution.
6. **Need new collection or protocol:** amulet in bags (one profile field),
   status line and craft requests (protocol), history (local saved data).
7. **Feasibility:** all Forever. Retail is out of scope.
8. **Evidence still needed:** calendar usable, sender format, GUID
   stability, unlearned recipes, camp spells, Onyxia quest IDs.
9. **Cut:** activity metrics, Retail, stronger hash, knowledge wiki.
10. **Smallest useful first release:** v0.2.1 below.

## 7. Revised roadmap (copied into PLAN.md section 7)

| Release | When | Contents |
|---|---|---|
| **v0.2.1 launch readiness** | now (before 4 Nov) | P1 attunement fix + amulet check · P2 · P3 probes · P4 error capture · P18/P19 hardening · sharing preview · data-state labels · Copy as text · "update available" line |
| **Test gate** | 4–7 Nov | Owner runs TESTING.md and sends `/sk debug`. v0.2.2 = fixes only, plus P17 |
| **v0.2.3 Overview** | Nov | Overview tab: population, data health, profession coverage, single-crafter recipes, attunement summary, levelling feed (P7), deep links |
| **v0.3.0 / v0.3.1 Raids** | before 9 Dec | `docs/prompts/next-v0.3-raids.md`, plus readiness card (P11) and duplicate-alt check. P13 fallback only if the calendar fails |
| **v0.4 Professions** | Dec | Cooldown board (B4), specialisations (B3), reagents (B2), favourites (B6). Camps (P6) if verified |
| **v0.5 Coordination** | Jan | Craft requests (D1/P14), status line (P8), lockouts (P15) |
| Later | | Theme polish, legacy (P16), knowledge notes, history beyond the feed, CurseForge |
