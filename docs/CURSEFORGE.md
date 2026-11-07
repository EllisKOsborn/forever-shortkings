# Getting Short Kings onto CurseForge

The release workflow (`.github/workflows/release.yml`, BigWigs packager)
already uploads to CurseForge on every release, as a **WoW Forever** file,
once two things exist: a CurseForge **project ID** in `ShortKings.toc` and a
**CF_API_KEY** secret on GitHub. Steps 1 to 5 are yours (they need your
accounts); step 6 is mine.

## 1. Create the project (about 10 minutes)
1. Sign in at **authors.curseforge.com** (a CurseForge account; you can sign
   in with Google or Discord).
2. **Create project** → Game: **World of Warcraft** → Class: **Addons**.
3. Fill in:
   - **Name:** Short Kings (if it's taken, "Short Kings Guild Sync").
   - **Summary:** *Guild roster, gear, professions, recipes and cooldowns,
     shared over guild addon chat. Height is not a stat.*
   - **Description:** paste the text in the box below.
   - **Main category:** Guild. Extra: Professions, Data Export (optional).
   - **License:** MIT License.
   - **Logo:** `preview/img/crest-large.png` from the repo (512 × 512).
   - **Source:** GitHub, `https://github.com/elliskosborn/forever-shortkings`.
4. Save. Note the **Project ID** (on the project page, under *About Project*).

## 2. First file (needed for CurseForge's review)
New projects are reviewed by CurseForge before they go public (usually a day
or two). The review needs a file:
1. Download **`ShortKings-v0.3.0-forever.zip`** from the GitHub release
   (the real zip, not "Source code").
2. On the project: **Files → Upload file**. Game version: **WoW Forever
   1.60.1** (pick the Forever flavour). Release type: **Beta** (sync between
   two players hasn't been tested yet; switch to Release later).
   Changelog: copy the v0.3.0 section of `CHANGELOG.md`.

## 3. API token
authors.curseforge.com → your avatar → **API tokens** → generate one called
"GitHub". Copy it (you only see it once).

## 4. GitHub secret
GitHub repo → **Settings → Secrets and variables → Actions → New repository
secret**. Name: `CF_API_KEY`. Value: the token. Never paste it in chat or in a
file.

## 5. Tell me the Project ID
Just the number.

## 6. (Me) wire it up: done 7 Nov (project ID 1788068 in the TOC)
I add `## X-Curse-Project-ID: <number>` to `ShortKings.toc`. From the next
release on (publish it on GitHub as usual), the workflow uploads the same
zip to CurseForge automatically. Tags with "beta" in the name (e.g.
`v0.3.1-beta`) go up as Beta files; plain `vX.Y.Z` as Release.

## Things to know
- **Anyone can install it.** It works for any guild: data is kept per guild
  name and only shared over that guild's addon channel. The crest and
  "Short Kings" name stay ours.
- **Licences are fine for publishing:** our code is MIT, the bundled
  libraries are BSD/MIT/zlib (licence files included), Chakra Petch is OFL
  (licence file in `Media/Fonts/`), the crest is drawn by `tools/textures.js`.
- **WoWInterface** isn't possible yet (the packager has no Forever category
  there). **Wago** is possible later with a `WAGO_API_TOKEN` and
  `## X-Wago-ID`, same idea.

## Description to paste

```markdown
**Short Kings** is a guild addon for WoW Forever. Everyone in your guild who runs it can browse each other's gear, talents, professions, recipes, cooldowns, raid attunements and reputations in game. Data is shared only over your guild's addon channel: no website, no server, no uploads.

### What's inside
- **Overview:** who's around, raid readiness, data health, professions and recent milestones.
- **Roster:** the whole guild, sortable and searchable, with alts under their main and a raid-attunement view.
- **Character:** anyone's gear, talents, professions, cooldowns, attunements and reputations.
- **Crafters:** search an item and see who can make it (online first), with its reagents and how many you have. Whisper them or post the list to guild chat.
- **Professions:** every profession in the guild (including the ones nobody has), each profession's crafters and recipes, the cooldown board, specialisations and favourites.
- **Item tooltips:** "Crafted by" guild crafters.

### Privacy
Notes, officer notes, gold, bags and chat are never shared. You choose whether your gear and recipes are shared.

### Light and safe
Small, rate-limited messages; sync pauses in combat and instances. Everything received is checked before it's stored.

Type `/sk` or use the minimap button. Source and full feature list: https://github.com/elliskosborn/forever-shortkings
```
