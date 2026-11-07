# Security review (3 Nov 2026)

What could someone do to Short Royalty users, on purpose? This covers the
addon code, the sync protocol and how release zips are built. Every attack
below was tried against the stubbed WoW API (`tests/security_spec.lua`).
**None of it has been checked in game yet.**

## The short version

- **No one can run code on your computer or in your game through this
  addon.** Nothing it receives is ever run as code: no `loadstring`,
  `RunScript` or similar anywhere. WoW addons also can't touch files, the
  internet or your account, and can't send chat for you.
- **Nothing private leaks.** Notes, officer notes, gold, bags and chat are
  never sent (checked again: only `guild.profiles` copies go on the wire,
  and the `/sk debug` report and "Copy as text" don't include notes).
- What **was** possible: annoy or mislead people. Before this review,
  someone could break the addon's windows for the whole guild with one
  crafted message, pretend to be a guild member, freeze people's game, or
  put misleading text in their chat. Those are fixed (v0.2.5, below).
- What **is still** possible: a guild member who wants to cause trouble
  can make up profiles for members who are offline. There's no fix short of
  cryptographic signatures, which WoW's Lua can't do sensibly. See "Accepted
  risks".

## Who could attack

1. **A stranger** (any player in the region). Anyone can whisper an addon
   message to anyone, so strangers can reach the addon.
2. **A guild member** running a modified copy of the addon. Only members can
   send on the guild channel.
3. **Whoever controls the build**: GitHub Actions and the libraries the
   release zip downloads. Whatever ends up in the zip runs in everyone's game.

## Found and fixed

| # | Severity | Problem | Fix |
|---|---|---|---|
| 1 | **High** | **One bad profile broke the windows for the whole guild.** Only the top level of a profile was checked. A member could send, say, talent trees as text: the Roster tab crashed for everyone who received it, it was saved, and it was passed on to others by the backfill. | `Merge.Validate` now checks every field's type, size and count (e.g. ≤ 1,500 recipes per profession, ≤ 64-character names, real numbers only). Anything off is refused. Fields from newer versions are still allowed if they're plain values. |
| 2 | **High** | **A stranger could pretend to be a member.** If a sender's name didn't match the roster exactly, the addon fell back to matching the first word. First names aren't unique in Forever, so a stranger called "Bob Jones" could whisper a fake profile as our "Bob Smith" and have it treated as Bob's own. | A first-word match is accepted only on the guild channel (where only members can send) and remembered for the session; a whisper with a first-word match is accepted only from a sender already confirmed that way. Exact roster matches work as before. |
| 3 | Medium | **Freezing someone's game.** A 32 KB message can decompress to about 13 MB (a "zip bomb"), taking around a second of CPU each, 60 times a minute, and it was decoded **before** checking who sent it, so even strangers could do it. A bomb profile would also be saved, bloating SavedVariables. | Messages are dropped before decoding unless the sender could be a guild member, and only guild and whisper channels are accepted. Anything that decompresses to over 256 KB is refused (a worst-case real profile is under a quarter of that). After 3 bad messages, a sender is ignored until `/reload`. |
| 4 | Medium | **Misleading text in chat.** The "a guildmate has a newer version" notice printed the version text as sent, and before checking the sender. A stranger could make your chat say "Short Royalty 9.9 … get the fix at evil-site". | Version text must look like a version (`0.2.4`, `v0.2.4-3-gabc123`, `dev`), at most 32 characters, and the notice only appears for verified guild members. The same check applies to the Version column. |
| 5 | Low | **Fake links on the paper doll.** Gear entries were passed straight to the item tooltip and shift-click. | A gear entry must be exactly one item link. |
| 6 | Low | **Odd text in "Grats" messages.** Profession names from other players went into the pre-typed guild-chat text with links and colours intact. | Stripped to plain text (40 characters max) first. You still see the text and press Enter yourself. |
| 7 | Low | The rate-limit table remembered every sender forever. | Idle senders are forgotten. |
| 8 | Medium | **Build pipeline.** GitHub Actions used movable tags (`@v2`), and LibDataBroker was fetched from whatever its (unmaintained) repo's latest commit is. If either were taken over, a release zip could include someone else's code. The test workflow also had more permissions than it needs. | Actions pinned to exact commits; LibDataBroker pinned to the commit we already ship; the test workflow's token is read-only. |

`/sk debug` now shows **"Passes guildmates' safety check: yes"** (if it ever
says no, guildmates are refusing your data, and the reason is shown) and how
many senders were ignored this session.

## Accepted risks (can't be fixed, or not worth it)

- **Guild members can make up data about members who are offline.** A
  modified addon can send a fake "relayed" copy of anyone's profile (fake
  gear, fake attunement). Merge rules already limit this: the real owner's
  copy always wins as soon as they log in, and our own characters are never
  overwritten. Signing profiles would need public-key cryptography in Lua
  and a way to share keys, which is out of proportion for a 50-person guild.
  If someone does this, `/sk debug` and the Roster's "updated" times help
  spot it; remove them from the guild.
- **A guild member can still cost you about 3 seconds of CPU per session**
  (three bad messages before they're ignored).
- **LibDBIcon** is still fetched from the WowAce trunk when the zip is built
  (pinning needs a WowAce tag name, which couldn't be checked from here). It's
  the standard source most addons use.
- **Names with colour codes.** Faction, talent and profession names from
  other players can contain WoW colour/icon codes and show coloured in the
  Character tab. Harmless (FontStrings can't be clicked), so left alone.

## Checked and fine

- **Spoofed sender GUIDs:** a message's claimed GUID is only believed when
  the name the game reports agrees.
- **Overwriting your own characters:** impossible; `SK.DB.account` entries
  are skipped before any merge.
- **Future timestamps:** more than 5 minutes ahead is refused.
- **Flooding:** 60 messages per sender per minute; outgoing replies are
  de-duplicated per requester; requests are capped at 60 profiles.
- **Chat:** the addon never sends chat. "Post to guild chat" and "Grats" only
  pre-type text; you press Enter.
- **Vendored libraries** are byte-for-byte the upstream files (checked 3 Nov):
  LibSerialize v1.2.3, LibDeflate (upstream main, 1.0.2), and AceComm,
  ChatThrottleLib, CallbackHandler and LibStub from Ace3. LibSerialize's
  deserializer only builds plain values and tables.

## For future changes

- Any new profile field needs an entry in `Merge.FIELDS`, or it falls under
  the "plain extra field" rule and the UI must treat it as untrusted.
- Anything shown from another player's data is untrusted text. Never pass it
  to `loadstring`, `SetHyperlink` (unless it passed `Merge.IsItemLink`), or
  chat without stripping it.
- Keep `tests/security_spec.lua` green; add a case for every new message type.
