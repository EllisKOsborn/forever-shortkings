# Short Royalty on CurseForge

**Status (7 Nov 2026): automatic uploads work.** Project **1788068** is in
`ShortRoyalty.toc` (`## X-Curse-Project-ID`) and the `CF_API_KEY` secret is set
on GitHub. When v0.3.2 was published, the release workflow uploaded
`ShortRoyalty-v0.3.2-forever.zip` to CurseForge by itself ("Success!" in the
Release log). **From now on: publish a release on GitHub, and it goes to
CurseForge too.** You don't upload files by hand any more.

Plain tags (`v0.3.3`) go up as **Release** files. A tag with "beta" in it
(`v0.3.3-beta`) goes up as **Beta**.

---

## What's left for you on CurseForge (about 10 minutes, once)

The project was created on 6 Nov as **Short Kings**. On 7 Nov the guild and
the addon became **Short Royalty**.

### 1. Rename the project
authors.curseforge.com → **Projects** → the project → **Settings** (or
*Edit project*):
- **Name:** `Short Royalty` (if it's taken: "Short Royalty Guild Sync").
- **Summary:** *Guild roster, gear, professions, recipes and cooldowns,
  shared over guild addon chat. Height is not a stat.*
- **Description:** replace it with the text in [the box at the end](#description-to-paste).
- **Logo:** keep it. The crown-and-beard crest is still ours
  (`preview/img/crest-large.png`, 512 × 512, if you need it again).
- Save.

The web address (e.g. `…/wow/addons/short-kings`) may stay the same after a
rename, and old links keep working. If you want a new address and there's no
*slug* field in the settings, CurseForge support can change it.

### 2. Archive the files that shouldn't be installed
Project → **Files**:
- **`ShortKings-v0.3.0`**: archive it (old folder name; it can't sync with anything newer).
- **`ShortRoyalty-v0.3.2`**: archive it **once v0.3.3 is up**. v0.3.2 and
  earlier can't share profiles between players (fixed in v0.3.3), and they
  can't talk to v0.3.3 either.

Archived files stay listed for the record, but the CurseForge app won't install them.

### 3. Optional: Beta until the guild has tested sync
Uploads currently go up as **Release**. Until two players have confirmed in
game that they see each other's data (TESTING.md 108–110), you can tell me
to tag the next one `-beta` instead.

---

## Reference: how it was set up (6–7 Nov)
1. Project created at authors.curseforge.com (World of Warcraft → Addons,
   category Guild, MIT licence, source on GitHub).
2. API token (authors.curseforge.com → avatar → **API tokens**) saved as the
   GitHub secret **`CF_API_KEY`** (repo → Settings → Secrets and variables →
   Actions). Never paste it in chat or in a file.
3. Project ID **1788068** added to `ShortRoyalty.toc`.
4. `.github/workflows/release.yml` (BigWigs packager) builds the zip on each
   published release and uploads it to GitHub and CurseForge, as a
   **WoW Forever 1.60.1** file.

## Things to know
- **Anyone can install it.** It works for any guild: data is kept per guild
  and only shared over that guild's addon channel. The crest and the
  "Short Royalty" name stay ours.
- **Licences are fine for publishing:** our code is MIT, the bundled
  libraries are BSD/MIT/zlib (licence files included), Chakra Petch is OFL
  (licence file in `Media/Fonts/`), and the crest is drawn by `tools/textures.js`.
- **CurseForge app users** who installed the old Short Kings file get the
  new `ShortRoyalty` folder when they update. If an old `ShortKings` folder is
  left behind in AddOns, delete it.
- **WoWInterface** isn't possible yet (the packager has no Forever category
  there). **Wago** is possible later with a `WAGO_API_TOKEN` and
  `## X-Wago-ID`, the same way.

## Description to paste

```markdown
**Short Royalty** is a guild addon for WoW Forever. Everyone in your guild who runs it can browse each other's gear, talents, professions, recipes, cooldowns, raid attunements and reputations in game. Data is shared only over your guild's addon channel: no website, no server, no uploads.

### What's inside
- **Overview:** who's around, raid readiness, data health, professions and recent milestones, plus a Getting started checklist.
- **Roster:** the whole guild, sortable and searchable, with alts under their main and a raid-attunement view.
- **Character:** anyone's gear, talents, professions, cooldowns, attunements and reputations.
- **Crafters:** search an item and see who can make it (online first), with its reagents and how many you have. Whisper them or post the list to guild chat.
- **Professions:** every profession in the guild (including the ones nobody has), each profession's crafters and recipes, every recipe in the game with search, the cooldown board, specialisations and favourites.
- **Item tooltips:** "Crafted by" guild crafters.

### Privacy
Notes, officer notes, gold, bags and chat are never shared. You choose whether your gear and recipes are shared.

### Light and safe
Small, rate-limited messages; sync pauses in combat and instances. Everything received is checked before it's stored.

### Everyone in the guild needs the same version
Guildmates on different versions may not see each other's data. When the addon says a newer version is out, please update.

### Upgrading from Short Kings?
The addon was renamed. After updating, delete the old `ShortKings` folder from your AddOns folder if it's still there.

Type `/sr` (or `/shortroyalty`) or use the minimap button. Source and full feature list: https://github.com/elliskosborn/forever-shortkings
```
