# Stream Deck

Device: **Stream Deck MK.2** (15 keys, 3×5). Layout designed in a Cowork
session (Aug 2026) around the actual calendar and agent workflows.

The Stream Deck app's own data (`~/Library/Application Support/com.elgato.StreamDeck/`)
is **not** stow-managed — profiles are built and maintained in the app.
This directory documents the design and tracks the plugin set
(`plugins.json`); plugins install by name from the Stream Deck app's
Marketplace pane. The previous profiles here targeted a prior employer's
stack and a 5-row device; they were removed from the tree (note: they remain
in git history, and this repo is public).

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

Deck-invoked scripts live in `~/.local/bin/` (stowed from
`dotfiles/.local/bin/`, on `$PATH`):

| Script | Does |
|---|---|
| `next-meeting.py` | `join` / `doc` / `both` / `debug` — reads icalBuddy, opens conference link and/or prep doc |
| `daily-planning.sh` | fires `/morning-triage` headless, opens Sunsama planning view; digest → `~/Documents/daily-briefs/` |
| `pr-review-agent.sh` | reads frontmost Chrome tab, runs a read-only PR review agent; review → `~/Documents/pr-reviews/` |
| `agent-status.sh` | prints agent state for the Stateful Executor polling key |
| `pr-review-count.sh` | prints the open review-requested PR count (key 15) |

> `next-meeting.py debug` has still never been run against real icalBuddy
> output — run it first after enabling the calendar mirror. The
> format-independent logic is covered by `test/test-next-meeting.sh`.

The two agent scripts share one status slot
(`$TMPDIR/streamdeck-agent-status`, read by `agent-status.sh`): last writer
wins, so one Stateful Executor key reflects whichever agent ran most
recently.

`meeting-docs.tsv` (meeting-title → prep-doc URL map) contains internal
meeting titles and doc URLs, and this repo is **public** — it stays
untracked. Place it at `~/.config/streamdeck/meeting-docs.tsv` (a
`.gitignore` entry guards the repo-side path against accidental commits).

## Environment variables

Stream Deck invokes scripts **without an interactive shell**, so `~/.zshrc`
exports never reach them. Each deck script that needs config therefore loads
untracked `~/.streamdeck` itself and pins its own `PATH`
(`agent-status.sh` needs neither — it only reads the status file); env.zsh
also sources `~/.streamdeck` so interactive shells agree.

Set in `~/.streamdeck` (host-specific, may reveal account addresses — never
commit; this repo is public):

- `CAL_WORK` / `CAL_PERSONAL` — icalBuddy calendar names, comma-separated.
- `DOJO_REPO_DIR` — dir the agent scripts `cd` into before running `claude`
  (defaults to `~/dojo`). Also exported by env.zsh for interactive use.
- `MEETING_DOCS` — optional override for the title→doc map path (defaults to
  `~/.config/streamdeck/meeting-docs.tsv`).
- `ICALBUDDY` — optional override for the icalBuddy binary path.

The agent scripts run `claude` with `--strict-mcp-config`, so user-scope MCP
servers (which include senders and code executors) never load under a deck
press. To give the triage digest its readers, create
`~/.config/streamdeck/triage-mcp.json` naming ONLY read-oriented MCP
servers — absent the file, the digest runs without MCP and degrades rather
than gaining tools.

## Calendar source

icalBuddy reads Calendar.app's local store. Google accounts get enabled as a
background mirror in **System Settings → Internet Accounts → Google →
Calendars**; Calendar.app itself is never opened. After enabling, list names
with `icalBuddy calendars` and write them to `~/.streamdeck`:

```sh
export CAL_WORK="<work calendar name>"
export CAL_PERSONAL="<personal calendar name>"
```

## Permissions (TCC)

Automation and Screen Recording panes populate **on demand** — trigger the
action once from the deck, approve the prompt, then the entry exists.
Only Accessibility can be pre-added via its `+` button.
