# Short Kings

*Small in stature. Big in loot.*

A World of Warcraft: **Forever** addon for the Short Kings guild (Alliance, PvE).
Everyone who installs it can browse every other member's gear, talents,
professions, known recipes, reputations and attunements in one window. Data is
shared through the guild's addon channel. There's no website, no server and
nothing is uploaded.

> **Status: v0.1, not yet tested in game.** It is built against Blizzard's
> Forever 1.60.1 interface code and unit-tested with a fake WoW API.

## Installing (for guildmates)

1. Download the latest `ShortKings-x.y.z.zip` from this repository's
   **Releases** page.
2. Unzip it. You get a folder called **`ShortKings`**.
3. Move that folder into your Forever AddOns folder:
   - **Windows:** `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
   - **Mac:** `/Applications/World of Warcraft/_forever_/Interface/AddOns/`

   Not sure where yours is? In the Battle.net app, select WoW Forever, click
   the gear ⚙ next to Play, then *Show in Explorer / Show in Finder*. Then
   open `Interface`, then `AddOns`. Create the `AddOns` folder if it's missing,
   spelled exactly like that.
4. Restart the game (or `/reload`). On the character screen, the
   **AddOns** button should list *Short Kings*.

The folder must be called `ShortKings` and sit directly inside `AddOns`, so
`AddOns/ShortKings/ShortKings.toc`. A folder inside a folder won't load.

Later we'll publish to CurseForge, and the CurseForge app will install and
update it for you.

## Using it

| Command | What it does |
|---|---|
| `/sk` | open or close the window (also the minimap button) |
| `/sk debug` | a copyable report of what the addon can see. Send this when something's wrong |
| `/sk log` | the same report plus the recent log |
| `/sk scan` | re-read your character now |
| `/sk sync` | share your data now and ask for anything missing |
| `/sk reset` | move the window back to the middle |

Open each of your **profession windows once**, so your recipes are recorded.
The addon reminds you which ones are missing. Log in on each alt once, too.

**Trial accounts** can't send addon messages, so they show up as
"no addon/trial" for everyone else.

## How sync works (short version)

- Each player announces a tiny fingerprint (hash and timestamp) of **their own**
  characters on the guild channel when they log in, and every 10 minutes.
- Anyone missing that data, or holding an older copy, asks for it by whisper.
- When you log in, one other member (picked at random) offers to fill in
  people who are offline.
- A character's own data always wins. A copy passed on by someone else can
  never overwrite a newer copy from the character themselves.
- Sync pauses in combat, in every instance (dungeons, raids, battlegrounds,
  arenas) and whenever the game blocks addon chat. Everything is rate-limited
  through ChatThrottleLib.
- Members who left the guild are deleted 30 days after they left.

The full design is in [PLAN.md](PLAN.md).

## For developers

```
luacheck .     # lint
busted         # unit tests (Lua 5.1, stubbed WoW API in tests/helpers)
```

- `Core/Compat.lua` is the only file that touches client-specific APIs.
- Releases: push a tag like `v0.1.0`. The **Release** workflow runs the
  BigWigs packager, which builds the zip and attaches it to a GitHub Release.
  For CurseForge, add the `CF_API_KEY` repository secret and an
  `## X-Curse-Project-ID:` line to `ShortKings.toc`.
- Every push also produces a **test build** (Actions → Tests → artifact
  `ShortKings-test-build`), which is never published anywhere.

## Credits

- No code was copied from other guild-sync addons. API facts come from
  [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes),
  Blizzard's own UI source (mirrored at
  [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), `forever`
  branch), and public notes in the
  [Everloot](https://github.com/Everloot/everloot/pull/49) and
  [bff-wow](https://github.com/Shtian/bff-wow/issues/3) projects.
- Libraries: Ace3 (AceComm, CallbackHandler, LibStub, ChatThrottleLib),
  LibSerialize by Ross Nichols, LibDeflate by Haoqian He, LibDataBroker,
  LibDBIcon. See [Libs/README.md](Libs/README.md).

Licence: MIT.
