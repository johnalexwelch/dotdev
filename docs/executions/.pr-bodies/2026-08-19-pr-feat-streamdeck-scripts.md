## What this PR does

Lands the five Stream Deck deck-invoked scripts into stowed `dotfiles/.local/bin/` (already on `$PATH`) — the four from the Cowork design handoff, hardened per review, plus `pr-review-count.sh` to back the key-15 design. The private data files that travelled with the handoff (`meeting-docs.tsv` with 17 internal doc URLs, plus SETUP/DESIGN/HANDOFF docs dense with internal meeting names) were deliberately installed to untracked `~/.config/streamdeck/` and are NOT in this PR — this repo is public.

## User-facing changes

- `next-meeting.py` — `join` / `doc` / `both` / `debug`; reads Calendar.app via icalBuddy, opens the conference link and/or prep doc. Title→doc map reads untracked `~/.config/streamdeck/meeting-docs.tsv` (`MEETING_DOCS` overrides)
- `daily-planning.sh` — fires `/morning-triage` headless in the background (fail-closed confinement — see hardening below), then opens Sunsama's planning view; digest → `~/Documents/daily-briefs/`
- `pr-review-agent.sh` — reads the frontmost Chrome tab, runs a read-only `claude -p "/coding-a2a:workflow-review"` with a hard tool allowlist and budget cap; review → `~/Documents/pr-reviews/`
- `agent-status.sh` — prints `idle|running|done|failed` for the Stateful Executor polling key; `--clear` resets
- `pr-review-count.sh` — open review-requested PR count for key 15, routed deterministically to the work account via `DOJO_REPO_DIR`
- `test/test-next-meeting.sh` — 8 hermetic cases over `next-meeting.py`'s format-independent layer

## How I implemented it

Started from the handoff scripts, then reworked them through two review rounds (4-lane full profile, Opus). Key deltas from the handoff originals:

- **RCE closed (security, proven PoC):** every `notify()` passes text as `argv` to `osascript` — a calendar-invite title interpolated into AppleScript source was arbitrary code execution
- **Agent confinement, fail-closed (security round 2 — a deny-list alone left ~40 user-scope MCP servers auto-approved, senders and code executors included, probed under the exact flags):** both agent scripts run `claude` with `--strict-mcp-config`, so user-scope MCP servers never load under a deck press; `daily-planning.sh` additionally denies built-in `Bash,Write,Edit,NotebookEdit` and loads readers only from operator-authored `~/.config/streamdeck/triage-mcp.json` when present; `pr-review-agent.sh` keeps its explicit allowlist
- **Deck-invoke env (logic, proven):** Stream Deck never sources `.zshrc`, so config-needing scripts source untracked `~/.streamdeck` themselves and pin `PATH`; `next-meeting.py` parses the same file (quoted/bare values, trailing comments, 4-key whitelist, env wins); fallbacks point at dirs that exist (`~/dojo`)
- **Event picking:** `None`-start events sort last; all-day events are filtered from `running` (they suppressed the 20-minute lookahead); start comes only from a line carrying both date and time, so neither a "09:30" in the title nor "agenda 09:00" in the notes fabricates one
- **URL anchoring:** `CONF_RE` host-anchored like `DOC_RE` (`https://evil.tld/meet.google.com/x` no longer reaches `open`); numeric-PR guard + slug slash check in `pr-review-agent.sh`
- **Misc hardening:** status file in private `$TMPDIR` (documented single slot), Sunsama keystroke gated on frontmost app, timeout/no-doc notifications, placeholder calendar names in the docstring, `~/.streamdeck` sourced before `set -u`
- **Docs reconciled:** `DOJO_NOTES_DIR` removed from env.zsh + README (zero consumers); README documents `MEETING_DOCS`/`ICALBUDDY`, the `~/.streamdeck` self-loading contract, per-script output dirs, and drops the stale "pending" note

## How to verify

- `bash test/run-tests.sh` → all suites green, including the 8 `test-next-meeting.sh` cases (pick ordering both list orders, `CONF_RE`/`DOC_RE` anchoring incl. suffix attacks, map collision `"<> tom"` vs `"Custom Report Review"`, personal-title masking, title-time and notes-time not becoming starts, `~/.streamdeck` loader incl. trailing comments)
- `pre-commit run --from-ref origin/main --to-ref HEAD` → clean (shellcheck, repo-args shfmt, markdownlint, secret scanners)
- `python3 -m py_compile dotfiles/.local/bin/next-meeting.py` → clean
- Smoke: `agent-status.sh` → `idle`; `pr-review-count.sh` → live count (routing fix took it from a false 0 to the real number); `next-meeting.py debug` → runs end-to-end, icalBuddy sections empty until the calendar mirror is enabled — the real-output parse path remains unexercised until that human step, stated in the README
- Independent review: 4-lane full profile, two REQUEST_CHANGES rounds fixed red-first where testable; each lane's final attestation is at the PR head sha

## Changelog entry

feat(streamdeck): deck scripts in stowed ~/.local/bin

## References

- Follows PR #178 (config retirement + env vars); design record: `dotfiles/.config/streamdeck/README.md`
- No tracked issues referenced (issue discovery: none in commits or open issues)
- Provenance: describe-pr issue_only mode; graphify not available (no `graphify-out/graph.json`)
