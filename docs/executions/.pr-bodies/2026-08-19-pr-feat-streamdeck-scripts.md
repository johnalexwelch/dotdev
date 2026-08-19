## What this PR does

Lands the four Stream Deck deck-invoked scripts from the Cowork design handoff into stowed `dotfiles/.local/bin/` (already on `$PATH`), completing the scripts slice that PR #178's README promised. The private data files that travelled with them (`meeting-docs.tsv` with 17 internal doc URLs, plus SETUP/DESIGN/HANDOFF docs dense with internal meeting names) were deliberately installed to untracked `~/.config/streamdeck/` and are NOT in this PR — this repo is public.

## User-facing changes

- `next-meeting.py` — `join` / `doc` / `both` / `debug`; reads Calendar.app via icalBuddy, opens the conference link and/or prep doc. One patch versus the handoff original: the title→doc map now reads untracked `~/.config/streamdeck/meeting-docs.tsv` (`MEETING_DOCS` env overrides) instead of a file next to the script, because the map holds internal titles/URLs
- `daily-planning.sh` — fires `/morning-triage` headless in the background, then opens Sunsama's planning view; writes status to `/tmp/streamdeck-agent-status`
- `pr-review-agent.sh` — reads the frontmost Chrome tab, runs a read-only `claude -p "/coding-a2a:workflow-review"` with a hard tool allowlist and budget cap, writes the review to `~/Documents/pr-reviews/`
- `agent-status.sh` — prints `idle|running|done|failed` for the Stateful Executor polling key; `--clear` resets

## How I implemented it

Copied the handoff scripts verbatim except the `MAP_FILE` patch in `next-meeting.py` (dead `SCRIPT_DIR` removed with it), ran `shfmt -w` to match the repo's pre-commit formatting, set exec bits. The scripts are env-driven: `DOJO_REPO_DIR`/`DOJO_NOTES_DIR` (added to `env.zsh` in #178) and `CAL_WORK`/`CAL_PERSONAL` (untracked `~/.streamdeck`, pending the Google calendar mirror).

## Review round 1 → fixes

The 4-lane review returned REQUEST_CHANGES across all lanes; every blocker is fixed in this round:

- **RCE (security F1, proven PoC):** all `notify()` helpers now pass text as `argv` to `osascript` — calendar-invite titles can no longer execute AppleScript/shell
- **Unconfined agent (security F2):** `daily-planning.sh` runs `/morning-triage` with `--disallowedTools "Bash,Write,Edit,NotebookEdit"` — prompt injection in email/Slack can shape the digest, not execute code
- **Dead env at deck-invoke time (logic L1, proven):** Stream Deck never sources `.zshrc`, so every script now loads untracked `~/.streamdeck` itself and pins `PATH`; fallbacks corrected to dirs that exist (`~/dojo`)
- **Wrong event picked on all-day days (logic L2, reproduced):** `pick_event` sorts `None`-start events last; all-day events no longer suppress the 20-minute lookahead
- **`CONF_RE` host-anchored (security F4 / logic L3):** `https://evil.tld/meet.google.com/x` no longer reaches `open`
- **Var-name collision (logic L4 / style F1):** `daily-planning.sh` uses `DOJO_REPO_DIR`; consumer-less `DOJO_NOTES_DIR` removed from env.zsh and README
- Also: status file moved to private `$TMPDIR` (F5/L9, documented single-slot), Sunsama keystroke gated on frontmost (L7), numeric-PR URL guard + slug slash check (L8), timeout/no-doc notifications (L6), same-line date+time parsing that skips the title line (L5), placeholder calendar names in the docstring (F3), README stale-pending note replaced and `MEETING_DOCS`/`ICALBUDDY` documented (L10/style), and `pr-review-count.sh` lands so key 15's README claim is backed (L10)
- **New:** `test/test-next-meeting.sh` — 7 hermetic cases over the format-independent layer (pick ordering, URL anchoring, map collision, personal masking, env loader), per the tests lane's proportionality call; the icalBuddy format fixture stays deferred until the mirror produces real output

## How to verify

- `python3 -m py_compile dotfiles/.local/bin/next-meeting.py` → clean
- `shellcheck dotfiles/.local/bin/*.sh` → clean; `shfmt -d` → no diff
- `dotfiles/.local/bin/agent-status.sh` → `idle`
- `dotfiles/.local/bin/next-meeting.py debug` → runs end-to-end; icalBuddy sections empty because the Google calendar mirror is not yet enabled (known pending human step from #178) — the parse path against real events is still unexercised and will be validated after mirror setup
- Independent review: 4-lane full profile (security/logic/tests/style, Opus); verdicts recorded per lane with final attestation at the PR head sha

## Changelog entry

feat(streamdeck): deck scripts in stowed ~/.local/bin

## References

- Follows PR #178 (config retirement + env vars); design record: `dotfiles/.config/streamdeck/README.md`
- No tracked issues referenced (issue discovery: none in commits or open issues)
- Provenance: describe-pr issue_only mode; graphify not available (no `graphify-out/graph.json`)
