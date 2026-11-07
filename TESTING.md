# In-game test checklist

Nothing has been confirmed in game yet. Tick these off as you go and send
the `/sr debug` text when something looks wrong.

## Before you start

- [ ] Type `/dump select(4, GetBuildInfo())` in chat. It should print **16001**.
      If it prints a different number, tell me (the `## Interface:` line in
      `ShortRoyalty.toc` must match).
- [ ] On the character screen, **AddOns** lists *Short Royalty* and it isn't
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
14. [ ] `/sr debug` opens a report. **Please copy it and send it to me**:
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
        Short Royalty, yellow = online without it, grey = offline.
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
        Short Royalty): the header says "Asked for the latest data…", then
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
        bags, a chat link or the auction house). A line "Short Royalty: …"
        lists up to 3 crafters, online first, then "+N more".
47. [ ] Settings → untick **Show guild crafters in item tooltips**: the line
        disappears. Tick it again and it's back.
48. [ ] A guildmate turns off "Share my recipes": after their next update
        they're no longer listed in Crafters or on tooltips.
49. [ ] `/sr debug`, "== Crafters ==": the recipe and crafter counts look
        right, and "Item tooltip line: hooked=yes".

## v0.2.1 additions (launch readiness)

50. [ ] Raid picker lists Barrow Deeps (10), Hyjal Summit (20) and Onyxia's
        Lair (40) only. Barrow and Hyjal say "No attunement needed for this raid."
51. [ ] Onyxia: a character with the Drakefire Amulet in their bags shows
        *yes*. Put it in the bank, `/sr scan`: still *yes* but with an orange
        "!" and "Drakefire Amulet not in bags" in the tooltip.
52. [ ] `/sr debug`, "== Attunement quests ==": the line "Onyxia's Lair item
        16309" shows name="Drakefire Amulet" and resolves=yes.

53. [ ] `/sr debug` starts with **"Live-client checks"**. Copy the whole block
        to me. Log out and back in on the same character, run it again, and
        check it says "GUID stable between logins: yes so far (2 logins …)".
54. [ ] Open your profession window, then `/sr debug`: the "unlearned recipes"
        line now has an answer. Open the Calendar once, then `/sr debug`: the
        "Calendar" line shows how many guild events are listed.
55. [ ] If you ever see a Lua error, `/sr debug` lists it under
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

## Design refresh (branch `design/refresh`)

Compare with `preview/index.html` (open it in a browser). Take a screenshot
in game if anything looks different and send it.

67. [ ] **Title font:** "SHORT ROYALTY", the tab names and the section headings
        use the square-cut Chakra Petch font. If they look like the normal
        game font instead, run `/sr debug`: the line "Display font (Chakra
        Petch) loaded" says NO when the game refused the file.
68. [ ] **Body font:** names and numbers use a narrow, plain font (Arial
        Narrow). Names with accents (and Cyrillic/Korean/Chinese, if anyone
        has them) show letters, not boxes or blanks.
69. [ ] **Crest:** a gold crown over a pink beard at the top left, crisp,
        with no black or white box around it.
70. [ ] **Colours:** gold only on the active tab underline, the gold buttons
        (*Ask for latest*, *Post to guild chat*) and big numbers; pink on
        ticked boxes, picked filters and the selected crafter row; orange
        only on warnings (old data, missing enchants, "need an update") and
        the sync dot.
71. [ ] **Open/close:** clicking the minimap button fades the window in (it
        grows very slightly). The × button fades it out. `/sk` and Esc open
        and close it at once, with no animation.
72. [ ] **Tabs:** the gold underline glides to the tab you click and the
        page appears at once. Click tabs quickly one after another: the
        underline never jumps back before moving.
73. [ ] **Rows:** hovering a Roster row highlights it; clicking opens the
        character. The Online/Level/etc. header shows a small arrow on the
        sorted column, and clicking flips it.
74. [ ] **Sync dot:** while sync is on, the orange dot next to "Sync on"
        sends out a ring when a guildmate's data arrives (at most every 8 s).
        In combat or an instance the dot turns grey and the text says why.
75. [ ] **Reduce motion:** Settings → tick **Reduce motion**: open/close,
        tabs, hover and the sync ring all happen instantly.
76. [ ] **Combat:** open the window, change tabs and close it in combat: no
        error, no "Interface action blocked" message.
77. [ ] **UI scale:** set the game's UI scale to the smallest and largest,
        and the addon's Window size to 70% and 130%: the window always fits
        on screen and nothing overlaps.
78. [ ] **Empty states:** a member with no data shows "No data synced yet"
        with an explanation (not an empty panel); searching the Roster for
        nonsense says "Nobody matches …"; Crafters with nothing picked
        explains what the panel is for.
79. [ ] **Other addons:** with ElvUI/Bagnon/DBM (or whatever you use) on,
        the window sits above the default UI, menus open on top, and item
        tooltips still show the "Short Royalty:" crafter line.

## v0.2.5 additions (security fixes)

80. [ ] `/sr debug`, "== Your data ==": **"Passes guildmates' safety check:
        yes"**. If it says no, copy the reason and send it: guildmates are
        refusing your data.
81. [ ] With a guildmate on v0.2.5 too: you still see each other's data
        update within a minute (the stricter checks didn't block real data).
        Then `/sr debug`, "== Sync ==": "Ignored senders this session: 0".
82. [ ] Same `/sr debug` block: note the "Loose name matches confirmed"
        number. 0 means sender names match the roster exactly (best case); a
        higher number means the game reports names differently and the
        first-name fallback is in use. Send it either way.

## v0.2.7 additions (profession checks)

83. [ ] Learn a crafting profession at a trainer if you don't have one.
        Open its window, tick **Show unlearned** in the window's filter if it
        exists, close and reopen the window, then `/sr debug`. Send the
        **"Profession checks for v0.3"** block.
84. [ ] Close the profession window and run `/sr debug` again. Send the two
        "Reagents" lines (this checks whether reagents can be read with the
        window closed).
85. [ ] If you have Engineering, Leatherworking or Blacksmithing, check the
        "Specialisations" lines: a specialisation you have says known=yes.
        Every line shows the game's name for the spell (tell me if a name
        looks wrong).
86. [ ] If you see Blueprints or camp objects in a profession window, check
        they appear under "Recipe categories" with their names.

## v0.3.0 additions (Professions)

87. [ ] **Professions** tab (after Crafters) shows every profession; ones
        nobody has say **nobody** in orange. Your own professions count.
88. [ ] Click **Alchemy** (or any profession someone has): crafters on the
        left with skill and "recipes recorded … ago"; recipes on the right
        with crafter counts. **All professions** goes back.
89. [ ] Filters: **Only one crafter** and **Favourites** change the recipe
        list. **Nobody knows** appears only if your window lists unlearned
        recipes (tell me if it's missing).
90. [ ] Click a recipe: the **Crafters** tab opens on it. Under the crafter
        list, **Needs:** shows its reagents with "(have N)" from your bags.
        Tell me if it says reagents aren't available for a recipe you know.
91. [ ] Right-click a recipe, then a crafter: both get a pink **star**.
        Crafters → **Favourites** chip lists only starred recipes.
        `/reload`: stars are still there.
92. [ ] **Cooldowns** (top of the Professions tab): if you or a guildmate
        has a cooldown recipe (a transmute, Mooncloth), it's listed with
        "Ready" or the time left, and "as of".
93. [ ] If you have Engineering, Leatherworking or Blacksmithing with a
        specialisation, it shows on your row (Professions → that profession)
        and on the board. Tell me if it's missing.
94. [ ] Level a crafting profession by 15+ points **without** opening its
        window, then `/reload`: about 90 s later chat says "Your … went from
        … to …" once. It doesn't repeat for three days. The same line shows
        on the Professions tab until you open that window.
        Settings → untick **Remind me to reopen profession windows**: no
        chat line.
95. [ ] With a guildmate on v0.2.6 or v0.2.7: you still see each other's
        data (the new specialisation field doesn't upset older versions).

96. [ ] Titles and tabs use the square **Chakra Petch** font (like the
        README pictures). `/sr debug`: "Display font (Chakra Petch) loaded:
        yes (N texts ok, 0 failed; font object present)". Send it if it says NO.
97. [ ] With Herbalism (or any gathering profession), open its window:
        Professions → Herbalism lists the camping recipes the window shows
        under **Nobody knows** (or **All** once learned).

## v0.3.1 (Short Royalty)

98. [ ] The window title, AddOns list and minimap tooltip say **Short Royalty**.
99. [ ] `/sr` and `/shortroyalty` open the window (`/sk` still does too).
100. [ ] Delete any old `ShortKings` folder first. Only **one** Short Royalty
        is listed under AddOns, the folder is `AddOns/ShortRoyalty/`, and the
        fonts and crest show (they load from the new folder path).
101. [ ] `/sr debug` → Guild shows key "Short Royalty-…", and the window opens
        with no Lua errors.

## v0.3.2 additions (every recipe, Getting started)

102. [ ] Professions → **All recipes**: type "mooncloth", then "camping", then
        "thorium bar". Results appear (names may fill in over a second or two)
        and "thorium bar" lists recipes that **use** it ("uses Thorium Bar").
103. [ ] Pick **Leatherworking** (or any profession) in the menu with the
        search empty: all of its recipes are listed. Tell me if you spot
        recipes that aren't in Forever (old or unused ones).
104. [ ] Click a recipe nobody knows: Crafters shows "Nobody in the guild
        knows this recipe yet" and **Needs:** with its materials, even with
        no profession window open.
105. [ ] **Wowhead** button: a window with the link opens, already selected;
        Ctrl+C (Cmd+C), paste it into your browser: it opens the right
        Wowhead Forever page.
106. [ ] On a new character (or after deleting the saved variables): chat
        says "Welcome to Short Royalty!" once; the Overview shows **Getting
        started**; the steps tick off as you open profession windows, the
        Character tab and Settings; **Hide** puts the milestones back.
107. [ ] `/sr debug`, "== Professions API ==": the "Recipe list" line shows
        about 2,250 recipes and "not on this client: 0" (or a small number).

## v0.3.3 (numbered pieces): needs two players, both on v0.3.3

108. [ ] Both open each other on the Character tab (or press **Ask for
        latest**): within a minute you see each other's gear, talents and
        professions. `/sr debug` → Sync: **accepted** is more than 0.
109. [ ] `/sr debug` → "Pieces": received is more than 0, **gave up 0**, malformed 0,
        and no "Last incomplete message" line. If there is one, send it to me.
110. [ ] Search the other person's recipe in **Crafters**: they're listed.

## v0.3.4 (crafter view, who has the addon)

111. [ ] Professions → open **Tailoring** (or any profession) → click a crafter:
        the right side shows only their recipes, with their name and skill
        above; the window stays on Professions. Click them again (or
        **Everyone**): everyone's recipes come back.
112. [ ] With a crafter picked, **Character** opens their character sheet. Go
        back to Professions: they're still picked.
113. [ ] Pick someone who keeps recipes private, or hasn't opened that window:
        the list says so instead of being blank.
114. [ ] Overview → Guild: **Have Short Royalty** + **Don't have it yet** add up
        to Members, and the names listed really don't have it.
115. [ ] **Without addon** opens the Roster with those members on top.

116. [ ] On a character with a profession whose window you haven't opened with
        the addon (or after `/run ShortRoyaltyDB.own=nil` and `/reload`): the
        orange bar shows under the tabs on every tab. **Open Tailoring** (or
        whichever) opens that profession window. Does it? Tell me if not.
117. [ ] After opening each one, the bar names the next, then disappears, and
        the window goes back to its normal height. In combat the button is
        greyed out.

## v0.3.5

118. [ ] Overview → point at **Don't have it yet** or the names under it: a
        tooltip lists everyone without the addon, two per line, online first.

## Known gaps in v0.1

- No Raids tab yet (v0.4).
- Onyxia's quest ID is the Classic one (6502, Alliance). Horde characters count only via the amulet in their bags.
- The title bar's ember animation comes in v0.4.
