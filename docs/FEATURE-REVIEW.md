# Feature review: what other guild addons do (1 Nov 2026)

We reviewed the **feature lists** of comparable addons. No code was read or
copied. The goal: find features worth adding to Short Kings now, later, or not at all.

## Addons reviewed

| Addon | Game | What it is | Licence |
|---|---|---|---|
| [Perpetua](https://github.com/Damndionic/Perpetua) | Forever | Guild addon for one guild: roster, profiles, attunements, crafters, loot, calendar (linked to their website) | none stated (treat as all rights reserved) |
| [Guild Muster](https://www.curseforge.com/wow/addons/guild-muster) | Forever | Full guild suite: raids and sign-ups, events, loot, crafting requests, bank shop, group finder, officer tools | n/a |
| [ForeverGuild+](https://www.curseforge.com/wow/addons/foreverguildplus) | Forever | Full guild suite: roster roles, sign-ups, attendance, loot history, craft requests, bank viewer, layers | n/a |
| [Ultimate Profession Master](https://www.curseforge.com/wow/addons/togprofessionmaster) | Classic → Forever | The deepest profession tool: crafter browser, missing recipes, cooldown board, shopping lists, tooltips | n/a |
| [GuildCrafts](https://www.curseforge.com/wow/addons/guildcrafts) | Classic | Guild recipe book: search, tooltips, `!gc` guild-chat lookup, status dots | n/a |
| [Guild Roster Manager](https://www.wowinterface.com/downloads/info24623-GuildRosterManager.html) | All | Officer roster tool: alts/mains, join dates, promotion history | n/a |
| [Gargul](https://www.curseforge.com/wow/addons/gargul) | Classic, Retail | Loot master: soft reserves, wishlists, rolls (Forever support unconfirmed) | n/a |
| [Party Buff Tracker Forever](https://www.curseforge.com/wow/addons/party-buff-tracker-forever) | Forever | Raid readiness: food, flasks, buffs, durability | n/a |

**What this means for us:** Perpetua is the closest match to Short Kings,
and Guild Muster and ForeverGuild+ already cover nearly everything a guild
might want. Short Kings' strengths are that it's **ours** (our name, our
look, MIT, no website) and **focused**. So we should add features that
build on the data we already collect, and leave loot and officer admin to
dedicated addons.

## Recommendations

Effort: **S** = an evening, **M** = a few days, **L** = a week or more.

### A. Add now (v0.1.x, small, uses data we already have)

| # | Feature | Seen in | Why | Effort | Notes |
|---|---|---|---|---|---|
| A1 | **Status dots**: green = online with addon, yellow = online without, grey = offline | GuildCrafts | You can tell at a glance who can be whispered or who'll sync | S | Roster `Online` column |
| A2 | **Alts grouped under their main** (Roster toggle, "Alts:" line on the Character tab) | Perpetua, GRM, UPM | We already store `family`. Crafters can be reached via whoever is online | S | Only links a character has confirmed itself, so nobody can falsely claim an alt |
| A3 | **Public note** in the Roster tooltip, **officer note** for officers | Perpetua | Free data from the roster | S | Never sent over sync. Read locally, and only where the game allows |
| A4 | **Addon version column** and "who's out of date" | Guild Muster | Helps the rollout, and lets you see who still needs to update | S | We already receive versions |
| A5 | **Missing-enchant markers** on the Character paperdoll | ForeverGuild+ (enchant audit) | Raid prep. The enchant ID is already in the item links we store | S | Classic enchantable slots only; a simple yes/no, no enchant names needed |
| A6 | **Accurate cooldowns** read at login, not only when the profession window is open | UPM, GuildCrafts | Transmute and cloth timers stay correct | S | Uses the spell cooldown API. Needs checking in game |
| A7 | **Privacy toggle**: "share my recipes / gear" | Guild Muster | Some players don't want their gear shared. It's cheap to respect | S | Off = we send only the basics |

### B. Fold into v0.2 (Crafters and Professions, already planned)

| # | Feature | Seen in | Effort | Notes |
|---|---|---|---|---|
| B1 | **"Crafted by" on every item tooltip** (guild crafters, online first) | GuildCrafts, UPM | S–M | Forever has `TooltipDataProcessor` (checked in Blizzard's source) |
| B2 | **Reagents** for a recipe in the Crafters tab | GuildCrafts, UPM | S | Recorded during the owner's scan (`GetRecipeSchematic`) |
| B3 | **Specialisations** (Transmute/Elixir/Potion master, Gnomish/Goblin, Dragonscale/Elemental/Tribal, Armor/Weaponsmith) | UPM, GuildCrafts | S | Inferred from known spells. IDs must be verified, not guessed |
| B4 | **Guild cooldown board** (who can transmute or make Mooncloth now) | UPM | S | In the Professions tab |
| B5 | **Coverage gaps**: professions or specs nobody has | UPM | S | Already the plan's "recipes nobody has" |
| B6 | **Favourite recipes and crafters** | GuildCrafts | S | Saved per player, not synced |
| B7 | **Post crafter list to guild chat** button | GuildCrafts | S | You press it yourself, so chat restrictions don't apply |

### C. Fold into v0.3 (Raids, on Blizzard's calendar)

| # | Feature | Seen in | Effort |
|---|---|---|---|
| C1 | Sign-up **status** (signed / tentative / late / bench / can't) plus **main and second role** | Guild Muster, ForeverGuild+ | M |
| C2 | **Line-up view**: counts by role and class, and who lacks the attunement for that raid | ForeverGuild+, Guild Muster | M |
| C3 | **Raid reminders** (chat or pop-up 15 min before) | Guild Muster, ForeverGuild+ | S |
| C4 | **"Invite everyone signed up"** button for the raid leader | Guild Muster, ForeverGuild+ | S (`C_PartyInfo.InviteUnit` exists; you press the button) |
| C5 | **Raid templates** with sizes: Barrow Deeps 10, Hyjal Summit 20, Onyxia 40 | Guild Muster | S |

### D. Later versions (worth it, but bigger)

| # | Feature | Seen in | Effort | Why later |
|---|---|---|---|---|
| D1 | **Craft requests**: "ask to craft", the crafter accepts and gets reagent totals | Guild Muster, ForeverGuild+ | M | Needs a new synced message type and a request list |
| D2 | **Attendance** recorded from the raid group (30/60/90 days) | ForeverGuild+, Barrens-chat addon | M | Officers like it; needs raid-roster snapshots |
| D3 | **Loot history** of epic drops | Perpetua, ForeverGuild+ | M–L | Reading loot inside raids may hit Midnight's "secret" restrictions, so it must be checked in game. **Consider Gargul instead** |
| D4 | **Missing recipes with where to get them** | UPM | L | Needs a recipe-source database for Forever's 2,200 recipes. We'd use only what members have seen |
| D5 | **Guild bank snapshot** viewer | ForeverGuild+ | M | Only if the guild uses the bank. The guild bank API exists |
| D6 | **Shopping list / reagent totals** | UPM, Perpetua | M | Useful with D1 |
| D7 | **`!sk <item>` guild-chat lookup** for members without the addon | GuildCrafts | M | Forever marks `SendChatMessage` as *restricted*; automatic replies may be blocked. Test in game first |
| D8 | **Copy/export** of roster, crafters or a raid line-up as text (for Discord) | Perpetua, ForeverGuild+ | S | Copy-paste only, no website |
| D9 | **Guild fun events** (raffles, fishing derby, contests) | Guild Muster | M | Good for guild identity, but not core |

### E. Recommend *not* building

| Feature | Reason |
|---|---|
| Loot council / DKP / soft reserves | Gargul and RCLootCouncil do this well. Reinventing it risks loot disputes |
| Consumable / world-buff readiness checks | Party Buff Tracker Forever exists. Reading buffs in raids runs into Midnight's secret-value limits |
| Officer kick/promote scripts, join-date history | Officer-only, needs protected actions; GRM covers it |
| Replacing Blizzard's guild window or guild chat | High risk of taint (blocking Blizzard's own actions) for little gain |
| Website or Discord sync | Excluded by the brief (no website, no server) |
| Layer detection, PvP bounties, blacklists | Not useful for a PvE guild |
| Group finder | Small value for a guild of 50. Guild chat already does this |

## Risks noticed during the review

- **Overlap:** if guildmates also run Perpetua, Guild Muster or ForeverGuild+,
  there's no conflict (different message prefixes), but it's double the
  traffic. Fine at 50 members.
- **Midnight restrictions:** anything that reads combat, loot or auras inside
  instances may be blocked. Short Kings deliberately reads only
  out-of-combat data.
- **Chat automation:** `SendChatMessage` is restricted in Forever, so every
  "post to chat" feature must be triggered by a button press.
