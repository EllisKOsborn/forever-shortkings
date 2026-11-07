# Short Royalty on CurseForge

The release workflow (`.github/workflows/release.yml`, BigWigs packager)
uploads to CurseForge automatically on every release, as a **WoW Forever**
file, once two things exist: the CurseForge **project ID** in
`ShortRoyalty.toc` and a **CF_API_KEY** secret on GitHub.

**Where we are (7 Nov 2026):** the project was created on 6 Nov as
**Short Kings**, with the `ShortKings-v0.3.0-forever.zip` file. On 7 Nov the
guild and the addon became **Short Royalty**: the window, the AddOns list,
the folder (`ShortRoyalty`), the download (`ShortRoyalty-vX.Y.Z-forever.zip`)
and the slash command (`/sr`). Part A updates the project. Part B is the
one-time setup, for reference.

---

## Part A: update the existing project to Short Royalty (about 10 minutes)

### A1. Rename the project
authors.curseforge.com → **Projects** → your project → **Settings** (or
*Edit project*):
- **Name:** `Short Royalty` (if it's taken: "Short Royalty Guild Sync").
- **Summary:** *Guild roster, gear, professions, recipes and cooldowns,
  shared over guild addon chat. Height is not a stat.*
- **Description:** replace it with the text in [the box at the end](#description-to-paste).
- **Logo:** keep it. The crown-and-beard crest is still ours
  (`preview/img/crest-large.png`, 512 × 512, if you need it again).
- **Source:** GitHub, `https://github.com/elliskosborn/forever-shortkings` (unchanged).
- Save.

**The web address** (e.g. `curseforge.com/wow/addons/short-kings`) may stay
the same after a rename. That's fine: people find the addon by its name, and
the old address keeps working. If you want a new address, check the project
settings for a *slug* field. If there isn't one, CurseForge support can change it.

### A2. Upload the new file
1. When the **v0.3.1** release is published on GitHub, download
   **`ShortRoyalty-v0.3.1-forever.zip`** from its **Assets** (the real zip,
   not "Source code"):
   https://github.com/EllisKOsborn/forever-shortkings/releases/tag/v0.3.1
2. Project → **Files → Upload file**:
   - **Game version:** WoW Forever 1.60.1 (the Forever flavour).
   - **Release type:** **Beta** (sync between two players hasn't been
     tested yet; switch to Release later).
   - **Display name:** `Short Royalty v0.3.1`.
   - **Changelog:** copy the v0.3.1 section of `CHANGELOG.md` (it explains
     the new folder name).

### A3. Retire the old Short Kings file
Project → **Files** → the `ShortKings-v0.3.0` file → **Archive** it (or
delete it if it's still under review). This stops anyone installing the old
`ShortKings` folder. The old and new versions can't sync with each other,
and both would load side by side.

### A4. Turn on automatic uploads (if you haven't already)
- **API token and GitHub secret:** if you already created the token and
  added `CF_API_KEY` on GitHub yesterday (Part B, steps 3–4), nothing changes.
  The name change doesn't affect them.
- **Send me the Project ID** (just the number, from the project page under
  *About Project*). It **isn't in the addon yet**, so uploads aren't
  automatic yet. I'll add `## X-Curse-Project-ID: <number>` to
  `ShortRoyalty.toc`, and from the next release on, publishing on GitHub uploads
  to CurseForge too, and you can skip A2.

---

## Part B: one-time setup (done on 6 Nov, kept for reference)

1. **Create the project:** authors.curseforge.com → **Create project** →
   Game: World of Warcraft → Class: Addons. Name, summary, description,
   logo and source as in A1. Main category: **Guild** (extra: Professions,
   Data Export). Licence: **MIT License**. Note the **Project ID**.
2. **First file:** new projects are reviewed before they go public (usually a
   day or two) and need a file. Upload as in A2.
3. **API token:** authors.curseforge.com → your avatar → **API tokens** →
   generate one called "GitHub". Copy it (you only see it once).
4. **GitHub secret:** repo → **Settings → Secrets and variables → Actions →
   New repository secret**. Name: `CF_API_KEY`. Value: the token. Never paste
   it in chat or in a file.
5. **Tell me the Project ID.**
6. **(Me)** I add `## X-Curse-Project-ID: <number>` to `ShortRoyalty.toc`.
   From then on, every release published on GitHub also goes to CurseForge.
   Tags with "beta" in the name (e.g. `v0.3.2-beta`) go up as Beta files;
   plain `vX.Y.Z` as Release.

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

### Upgrading from Short Kings?
The addon was renamed. After updating, delete the old `ShortKings` folder from your AddOns folder if it's still there.

Type `/sr` (or `/shortroyalty`) or use the minimap button. Source and full feature list: https://github.com/elliskosborn/forever-shortkings
```
