# Session Reflection: wayfinder #74 resolve — shell-wrapper friction
**Date**: 2026-07-13
**Goal**: Resume `/wayfinder` work-mode in dotdev, resolve one frontier ticket (#74, token/context efficiency).

## What Went Well
- Clean resume: read wayfinder procedure + map #68 + live frontier query in parallel, oriented in one round.
- Correctly picked the **AFK** ticket (#74) over the two HITL tickets (#72/#75) and never stood in for the human — respected the wayfinder human-gate rule.
- **Behavior-based verification** of FIND-26 instead of trusting the audit's labels: inspected each package's README, found the "cache-optimizer ↔ pix-optimizer" pair was a *name-based false positive* (input-cache vs output-verbosity). That's the genuine research value of the ticket.
- Full resolution chain executed without prompting: comment → close → map Decisions-so-far → decision-log mirror → scoped commit → handoff. Did not sweep the pre-existing `settings.json` drift into the commit.

## What Went Wrong / Friction
- **rtk/hypa shell wrapper mangled multi-statement bash 3 times** (~4 wasted tool calls): a `for` loop threw `syntax error near unexpected token 'done'`; `VAR="$HOME/..."` inline assignments expanded empty; another loop was split into per-word processes. Root cause: the auto-rewriter tokenizes each segment and breaks loops / same-line assignments.
- **rtk rendered markdown files as JSON** when read via `cat`/`sed` (decision-log, research asset, map body), forcing a switch to the `read` tool mid-task.
- Minor: "reload" was ambiguous; asked rather than guessed (correct call, but the one-word input carried no context).

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | (none — no work redirect this session) | — | — |

## Lessons
1. **For anything beyond a single simple command, write a `.sh` file and run `bash file.sh`.** The rtk/hypa wrapper reliably breaks `for`/`while` loops and same-line `VAR=...` assignments. Reaching for a script file *first* would have saved 4 calls.
2. **Read file *contents* with the `read` tool, never `cat`/`sed` through the wrapper** — rtk reshapes markdown/tables into JSON.
3. **Verify audit claims by behavior, not by their labels.** FIND-26's second pair dissolved on inspection; the finding's own framing ("suspected") invited this.

## Proposed Improvements
- [ ] None require a skill edit. The dominant friction (shell-wrapper breakage) is owned by the `rtk`/`hypa`/`pix-optimizer` pi packages' auto-rewrite behavior, **not** by any `.claude/skills/` file — and it is orthogonal to the token-efficiency work just shipped. (priority: low)
- [ ] Optional, if a shell-usage guidance doc exists or is wanted: add one line — "multi-statement bash (loops, inline `VAR=`): write a script file and run it; use the `read` tool for file contents." Flag only; not proposing to author a new skill for a personal reflex. (priority: low)

_No skill/CLAUDE.md edits proposed. Nothing to sync._
