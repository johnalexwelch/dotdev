# Stream Deck

Device: **Stream Deck MK.2** (15 keys, 3×5). Layout designed in a Cowork
session (Aug 2026) around the actual calendar and agent workflows.

The Stream Deck app's own data (`~/Library/Application Support/com.elgato.StreamDeck/`)
is **not** stow-managed — profiles are built and maintained in the app.
This directory documents the design and tracks the plugin set
(`plugins.json`). The previous profiles here targeted a prior employer's
stack and a 5-row device; they were removed — git history is the archive.

## Design principles (decided, don't re-litigate)

- **One press is never irreversible.** Keys are read-only or draft-producing;
  anything with side effects goes behind a Multi Action Switch (arm, then fire).
  Stream Deck has no native long-press.
- **No text-editing commands.** Keyboard owns the buffer (Vim); the deck owns
  everything outside it.
- **Deck-only hotkeys use the hyperkey** (`Ctrl+Opt+Cmd+Shift+<key>`) — fingers
  never press them, so don't spend good chords.
- **Mute:** two free official plugins (Elgato Meeting Controls for Meet, Elgato
  Zoom plugin), same key position, backend swapped by per-app Smart Profiles.
  MuteDeck only if profile switching proves laggy.
- **Agents: status over launching.** Stateful Executor polls agent state
  (`idle`/`running`/`done`/`failed`); launch keys are context-aware and read-only.
- **Key 15 = live PR review count** — ambient hidden state beats a dismissed
  notification.

## Scripts

Deck-invoked scripts live in `dotfiles/.local/bin/` (stowed onto `$PATH`):

| Script | Does |
|---|---|
| `next-meeting.py` | `join` / `doc` / `both` / `debug` — reads icalBuddy, opens conference link and/or prep doc |
| `meeting-docs.tsv` | meeting-title → prep-doc URL map (data file, sits next to the script) |
| `daily-planning.sh` | fires `/morning-triage` headless, opens Sunsama planning view |
| `pr-review-agent.sh` | reads frontmost Chrome tab, runs a read-only PR review agent |
| `agent-status.sh` | prints agent state for the Stateful Executor polling key |

> **Pending:** the script files were authored in the Cowork session and still
> need to be exported from it into `dotfiles/.local/bin/`. Run
> `next-meeting.py debug` first — its icalBuddy parsing was never run against
> real output.

## Calendar source

icalBuddy reads Calendar.app's local store. Google accounts get enabled as a
background mirror in **System Settings → Internet Accounts → Google →
Calendars**; Calendar.app itself is never opened. After enabling, fill
`CAL_WORK` / `CAL_PERSONAL` in `dotfiles/.config/zsh/configs/env.zsh` using
names from `icalBuddy calendars`.

## Permissions (TCC)

Automation and Screen Recording panes populate **on demand** — trigger the
action once from the deck, approve the prompt, then the entry exists.
Only Accessibility can be pre-added via its `+` button.
