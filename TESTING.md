# In-game test checklist

Nothing has been confirmed in game yet. Tick these off as you go and send
the `/sk debug` text when something looks wrong.

## Before you start

- [ ] Type `/dump select(4, GetBuildInfo())` in chat. It should print **16001**.
      If it prints a different number, tell me (the `## Interface:` line in
      `ShortKings.toc` must match).
- [ ] On the character screen, **AddOns** lists *Short Kings* and it isn't
      marked "out of date". (If it is, tick "Load out of date AddOns" for now.)

## v0.1 — on your own

1. [ ] Log in. Within a minute, chat should show no red Lua errors. (To show
       errors, type `/console scriptErrors 1` once.)
2. [ ] `/sk` opens the window; `/sk` again closes it; **Esc** closes it.
3. [ ] Drag the window by its title bar, `/reload`, and it stays where you left it.
4. [ ] Settings → Window size buttons resize the window, and the size is remembered.
5. [ ] The minimap button shows. Left-click toggles the window, right-click
       opens Settings. Untick "Show minimap button" and it disappears.
6. [ ] **Roster**: every guild member is listed with class colours, level and
       rank. Online people show "Online". Clicking a column header sorts.
       Typing in the search box filters.
7. [ ] **Character** (click yourself, or "Me"): gear icons in the right slots.
       Hovering shows the normal item tooltip, and Shift-click links the item in chat.
8. [ ] Average item level matches your character sheet.
9. [ ] Talents show your trees with points (e.g. Arcane 31). Compare with your talent window.
10. [ ] Professions show the right skill levels. Each crafting profession says
        "not scanned yet" until you open it.
11. [ ] Open a profession window, wait 2 seconds and close it. That profession now shows
        "N recipes". Does N match the number of recipes you know?
12. [ ] If you have a cooldown (e.g. a transmute), it appears under **Cooldowns**.
13. [ ] Reputation lists your factions with the right standing.
14. [ ] `/sk debug` opens a report. **Please copy it and send it to me**:
        - "UnitFullName" and "Roster sample name" show how Forever writes names.
        - "missing:" lines show which APIs don't exist.
        - "Attunement quests … known to this client" shows whether the
          Classic quest IDs exist in Forever.
15. [ ] Log in on an alt, then back: the Roster shows both as "(you)".

## v0.1 — with a guildmate (both have the addon)

16. [ ] Within about a minute of you both being online, each of you appears in
        the other's Roster with a **Data** age (not "no addon/trial").
17. [ ] Click them: their gear, talents and professions show, with
        "(from them)" in the header line.
18. [ ] Change a piece of gear. About a minute later their view of you updates.
19. [ ] Go into a dungeon: the title bar says "sync paused: instance (party)".
        Leave, and it resumes.
20. [ ] A third member who logs in later sees both of you, even while one of
        you is offline ("relayed by a guildmate").
21. [ ] Nobody gets disconnected, and chat shows no "No player named …" spam.

## v0.1.x additions

22. [ ] **Status dots** in the Roster's Online column: green = online with
        Short Kings, yellow = online without it, grey = offline.
23. [ ] **Group alts** (ticked by default): log in on two characters at least
        once each. They show as one row, "+1", with the alt in the tooltip.
        Untick it and both show separately.
24. [ ] Character tab → **Make this my main** on an alt. The Roster then lists
        that character first.
25. [ ] **Notes**: a member's public note shows in the Roster tooltip and on
        the Character tab. If you're an officer, the officer note shows too.
        Search finds words in notes.
26. [ ] **Ver** column shows each member's addon version. Older ones are
        orange, and the counter says "N need an update".
27. [ ] **Missing enchants**: take an unenchanted item (e.g. new boots). Its
        slot gets a small orange "!" corner, its tooltip says "no enchant",
        and the paperdoll says "1 missing enchant".
28. [ ] **Cooldowns**: do a transmute (or another cooldown craft), `/reload`
        without opening Alchemy, and the cooldown still counts down correctly.
29. [ ] **Privacy**: Settings → untick "Share my gear and talents". A
        guildmate now sees "hidden by this player" on your character, while
        you still see your own gear. Tick it again and it comes back.

## Known gaps in v0.1

- No Crafters, Professions or Raids tabs yet (v0.2 and v0.3).
- Attunement IDs are Classic IDs, and the new Forever raids are TODO.
- The title bar's ember animation comes in v0.4.
