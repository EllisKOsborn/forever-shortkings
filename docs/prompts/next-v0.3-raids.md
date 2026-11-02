# Prompt: Short Kings v0.3 (Raids, on Blizzard's guild calendar)

Copy everything below the line into a new Claude Code chat on the
`forever-shortkings` repo. **Start only after the first in-game test round**
(TESTING.md and a `/sk debug` report), because this builds on sync, the
roster and attunements working for real.

---

You're continuing work on **Short Kings**, a World of Warcraft: Forever guild
addon in this repo. Before you change anything, read `CLAUDE.md` (project
rules, verified APIs, environment notes), then `PLAN.md` section 6 (the Raids
design and why) and section 7. I'm not a developer and I'm usually on my phone.
Explain what you did in plain language, keep replies short, and push back if
something here is a bad idea. Don't claim anything works in game until I say so.

Raids open on **9 Dec 2026**: Barrow Deeps (10), Hyjal Summit (20),
Onyxia's Lair (40). Build this in **two releases** so the read-only part can
ship first. Commit as you go.

## Ground rules (from PLAN.md section 6, checked against the Forever source)
- Events live in **Blizzard's calendar**. We never create our own events.
  `C_Calendar.AddEvent` is `HasRestrictions`, so the **New raid** button only
  opens Blizzard's calendar (`ToggleCalendar` / `Calendar_Toggle`, verify the name).
- Sign-up lists come from Blizzard's servers, so **no sync is needed for
  sign-ups**, and members without the addon still count.
- Reading a sign-up list needs `C_Calendar.OpenEvent`, which shares state with
  Blizzard's calendar window. Only read **while that window is closed**, one
  event at a time (`CALENDAR_OPEN_EVENT`, then `GetNumInvites` /
  `EventGetInvite`, then `CloseEvent`), and stop if the player opens the calendar.
- `C_Calendar.GetDayEvent` and `EventGetInvite` are marked
  `SecretInChatMessagingLockdown`. Read them only outside lockdown, combat and
  instances, and pass every value through `Compat.clean`.
- All calendar, party and role calls go in `Core/Compat.lua`, are checked
  against the Forever source (`CalendarDocumentation.lua`,
  `CalendarConstantsDocumentation.lua`, `PartyInfoDocumentation.lua`,
  `Blizzard_Calendar/Mainline` + `Camelot`), and are added to `Compat.PROBES`.

## Release v0.3.0: Raids tab (read-only)

### 1. Event list
- New tab **Raids**, after Crafters.
- Upcoming guild events for the next 30 days whose `eventType` is
  `Enum.CalendarEventType.Raid` (0), from `C_Calendar.GetNumGuildEvents` /
  `GetGuildEventInfo` (fields: `eventID`, date and time, `title`,
  `eventType`, `inviteStatus`).
- Each row: day and time (local), title, the matched raid and its size,
  my status, and "18 signed · 3 tentative".
- **Match an event to a raid** by keywords in its title. Add `keywords`
  (e.g. "ony", "onyxia", "barrow", "hyjal") to the entries in
  `Data/Attunements.lua`, which already hold each raid's name, size and
  attunement (only the first-wave raids are shown).
  Let anyone override the match from a small menu (saved locally per `eventID`).
- Refresh on `CALENDAR_UPDATE_GUILD_EVENTS`, `CALENDAR_UPDATE_EVENT_LIST`
  and when the tab opens. Call `C_Calendar.OpenCalendar()` once first if the
  list is empty.

### 2. Line-up for one event
- Click an event to read its sign-up list (see the ground rules).
  `CalendarEventInviteInfo` gives `name`, `level`, `classFilename`,
  `inviteStatus`, `guid` and `modStatus`. **Key by `guid`.**
- Columns:
  - status (Signed up, Tentative, Confirmed, Standby, Declined, Invited;
    the `Enum.CalendarStatus` values);
  - name in class colour, and "alt of X" where it applies;
  - **role** (see 3);
  - spec, e.g. "Holy 31/20/0";
  - item level;
  - **attunement** for the matched raid (reuse `RosterTab.AttunementOf`:
    Barrow Deeps and Hyjal need none; Onyxia shows the amulet warning).
- Top line: "Tanks 2 · Healers 6 · DPS 18 · 26 / 40". Flag a missing role
  ("No healers yet") and show "Not attuned: 3" for the matched raid.
- **Readiness card** (Perplexity P11, merged here): item level range,
  missing-enchant count, data older than a week, and the same player signed up
  on two characters. Add a **Copy** button using `SK.Export` (v0.2.1).
- Members without Short Kings show what the calendar gives (name, class,
  level, status), with role, spec, ilvl and attunement greyed as unknown.
- Cache the last read list per `eventID` for the session, and show "read
  2m ago" so nobody waits on every click.

### 3. Roles
- **Push back on PLAN.md's per-event `RL` message:** use a **main role and a
  second role in the profile** instead (`profile.roles = { main, second }`).
  That needs no new message type, works offline, and covers most cases.
  A per-event override can come later if the guild asks.
- Settings: "My raid roles", with Tank / Healer / DPS for the main role
  and None / Tank / Healer / DPS for the second, per character.
- Default before a choice: a guess from class and main talent tree
  (`Data/Roles.lua`, keyed by class file and tree **order index**, not by
  localised tree name). Mark the guesses `status = "todo"` until checked in
  game, and show them greyed with "(guess)".
- Bump `Profile.VERSION` only if old clients would reject the new field
  (they shouldn't: `Merge.Validate` ignores unknown fields; confirm with a test).

Tests for v0.3.0: event filtering and raid matching; reading invites
(stub `C_Calendar` and its events in `tests/helpers/wow.lua`); role defaults
and counts; line-up rows for members with and without data; never calling
`OpenEvent` while Blizzard's calendar is shown; secret values ignored.

Then update `CHANGELOG.md` (v0.3.0), `TESTING.md`, the README "What's inside"
(list everything), the FAQ ("How do I sign up?"), and mockups (a Raids scene,
`docs/images/raids.webp`). Commit.

## Release v0.3.1: actions and reminders

### 4. Sign up from our tab
- Buttons: **Sign up / Tentative / Decline** for the selected event.
  Use `C_Calendar.EventSignUp` / `EventTentative` / `EventDecline` (guild
  sign-up events) or `EventAvailable` / `EventDecline` (invitations); check
  which applies from `C_Calendar.GetEventInfo().inviteType`/`calendarType`.
  These are not flagged `HasRestrictions` in the 1.60.1 docs, but **only call
  them from a button press**.
- If a call fails or the status doesn't change within 5 s, say so and offer
  **Open calendar** instead.

### 5. Reminders (C3)
- 15 minutes before an event you're signed up for (Signed up, Confirmed or
  Tentative), print a chat line and show a small themed pop-up with the raid,
  start time and an **Open Raids tab** button. Setting: "Raid reminders"
  (default on), plus minutes before (5 / 15 / 30).
- Only events read in this session. No sound unless the player opts in.

### 6. Invite everyone signed up (C4)
- Raid leader or assistant only, and only on button presses.
- **Invite signed up** invites Signed up + Confirmed members who are online
  and not already in the group, using `C_PartyInfo.InviteUnit` (the docs list
  `RequiresValidInviteTarget`, not restrictions). Convert to a raid first with
  `C_PartyInfo.ConvertToRaid` when the group would pass 5.
- Midnight may require one hardware click per invite. If so, invite the
  next person on each click and show "Invite next (12 left)". Check in game
  and design for both.

Tests for v0.3.1: reminder timing and settings; invite list (online,
signed up, not in group); one-invite-per-click fallback; sign-up buttons call
the right API for each event kind.

Then CHANGELOG (v0.3.1), TESTING, README, PLAN (mark C1–C5 done or note what
changed), CLAUDE.md status. Commit and push.

## Out of scope
- Creating or editing events from the addon (restricted; Blizzard's calendar does it).
- Addon-only events, DKP, loot, attendance history (D2), per-event role messages.
- The Professions tab (v0.2.x).

## Definition of done
- `busted --lua=lua5.1` and `luacheck .` pass locally and in CI.
- Every new WoW API is checked against the Forever source and probed in `/sk debug`.
- Docs and mockups are updated, commits are pushed to your designated branch,
  and there's no PR unless I ask.
- Finish with a short plain-language summary, the new TESTING.md items, and
  what I need to check in game (especially: sign-up calls, OpenEvent while
  the calendar is closed, invite clicks, and whether `eventID` is the same on
  every client).
