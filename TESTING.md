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

## v0.1.2 additions

30. [ ] **Raid picker** (Roster toolbar, next to the search box): pick
        *Onyxia's Lair*. An **Attuned** column appears with a green tick
        *yes*, red cross *no* or grey *unknown*. (Do the icons show? If you
        see empty boxes, tell me.)
31. [ ] With a raid picked, alts get their own rows, and hovering an alt says
        "alt of <main>". "Group alts" is hidden while a raid is picked.
32. [ ] **All / Attuned / Not attuned / Unknown** buttons filter the list, and
        the counter ("N attuned · N not · N unknown") matches what you see.
33. [ ] **Max level only (60)** is ticked by default and hides lower
        characters. Untick it and they come back.
34. [ ] Pick *Barrow Deeps*: everyone is *unknown* and the line says
        "Attunement quests for this raid aren't known yet."
35. [ ] `/reload`: the raid and filter you picked are still selected.
        Pick *All raids* to get the normal Roster back.
36. [ ] **Ask for latest** (Character tab, on a guildmate who is online with
        Short Kings): the header says "Asked for the latest data…", then
        "Got their latest data" a few seconds later. Pressing it again
        within 30 s says "Already asked".
37. [ ] On someone who is offline, the button is greyed out and its tooltip
        says "Offline: showing their last known data". If their alt is online
        with the addon, the button works and the alt answers.
38. [ ] **Faster updates:** change a piece of gear. A guildmate sees it in
        about 30–60 seconds.

## v0.2.0 additions (Crafters)

39. [ ] A **Crafters** tab sits between Character and Settings. With nobody
        scanned yet it says "Recipes appear after crafters open their
        profession window once."
40. [ ] Open one of your profession windows, then type 3+ letters of
        something you can make (e.g. "bolt", "potion"). Results show the
        icon, the name in the item's colour, the profession and
        "N crafters". With 1–2 letters it asks for at least 3.
41. [ ] The first search may say "loading N names…" for a few seconds,
        then fill in. Tell me if names never appear.
42. [ ] Enchanting recipes show by recipe name ("Enchant Boots - …").
        Search "enchant boots".
43. [ ] Click a result: the right side lists crafters, online first, with
        skill levels. **Whisper** opens a whisper to them in the chat box.
        It's greyed out for offline crafters, and your own characters have
        no Whisper button.
44. [ ] A crafter whose alt is online shows "on <alt name>", and Whisper goes
        to the alt.
45. [ ] **Post to guild chat**: the chat box opens on the **Guild** channel
        with "[Item] can be made by: …" already typed, and the item link
        is clickable. Nothing is sent until you press Enter. (Tell me if it
        opens on Say instead of Guild, or shows a Lua error.)
46. [ ] **Tooltips**: hover an item someone in the guild can make (in your
        bags, a chat link or the auction house). A line "Short Kings: …"
        lists up to 3 crafters, online first, then "+N more".
47. [ ] Settings → untick **Show guild crafters in item tooltips**: the line
        disappears. Tick it again and it's back.
48. [ ] A guildmate turns off "Share my recipes": after their next update
        they're no longer listed in Crafters or on tooltips.
49. [ ] `/sk debug`, "== Crafters ==": the recipe and crafter counts look
        right, and "Item tooltip line: hooked=yes".

## v0.2.1 additions (launch readiness)

50. [ ] Raid picker lists Barrow Deeps (10), Hyjal Summit (20) and Onyxia's
        Lair (40) only. Barrow and Hyjal say "No attunement needed for this raid."
51. [ ] Onyxia: a character with the Drakefire Amulet in their bags shows
        *yes*. Put it in the bank, `/sk scan`: still *yes* but with an orange
        "!" and "Drakefire Amulet not in bags" in the tooltip.
52. [ ] `/sk debug`, "== Attunement quests ==": the line "Onyxia's Lair item
        16309" shows name="Drakefire Amulet" and resolves=yes.

53. [ ] `/sk debug` starts with **"Live-client checks"**. Copy the whole block
        to me. Log out and back in on the same character, run it again, and
        check it says "GUID stable between logins: yes so far (2 logins …)".
54. [ ] Open your profession window, then `/sk debug`: the "unlearned recipes"
        line now has an answer. Open the Calendar once, then `/sk debug`: the
        "Calendar" line shows how many guild events are listed.
55. [ ] If you ever see a Lua error, `/sk debug` lists it under
        "Recent errors". Send me that part too.

56. [ ] Settings → **What guildmates see from you**: untick "Share my gear and
        talents" and the list changes to "private" for gear and talents.
        Tick it again.
57. [ ] A guildmate whose data is more than a week old shows an orange age in
        the Roster's Data column and "may be out of date" on their Character tab.

58. [ ] Roster → **Copy**: a window opens with the list as plain text,
        already selected. Ctrl+C (Cmd+C), paste into Discord: no colour codes,
        no notes. Try it with a raid picked too.
59. [ ] Crafters → pick a result → **Copy**: the crafter list as plain text.

## v0.2.2 additions (Overview)

60. [ ] `/sk` opens on the **Overview** the first time. Switch to another tab,
        close and reopen: it remembers that tab.
61. [ ] **Guild** card numbers match the Roster: members, online, and the
        level bands.
62. [ ] **Raids** card: days until 9 Dec look right; Onyxia counts match the
        Roster with Onyxia picked (button **Onyxia list** takes you there).
63. [ ] **Data health**: **Oldest first** opens the Roster with people
        without data at the top, then the oldest data.
64. [ ] **Professions**: counts look right; a profession nobody has shows
        "nobody" in red. **Recipes**: "only one character knows" lists real
        recipes.
65. [ ] **Recent milestones**: when a guildmate with the addon levels up (or
        reaches 75/150/225/300 in a profession), a line appears within a
        minute or two. **Grats** types "Grats <name> on level N!" into guild
        chat without sending it.
66. [ ] Settings → untick **Record guild milestones**: no new lines appear.

## Known gaps in v0.1

- No Professions or Raids tabs yet (rest of v0.2, and v0.3).
- Onyxia's quest ID is the Classic one (6502, Alliance). Horde characters count only via the amulet in their bags.
- The title bar's ember animation comes in v0.4.
