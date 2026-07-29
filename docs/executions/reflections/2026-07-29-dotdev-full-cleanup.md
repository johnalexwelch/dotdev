# Session Reflection: dotdev full cleanup + startup/MCP tuning

**Date**: 2026-07-29
**Goal**: Speed up pi startup, fix recurring dirty-repo friction, then fully clean dotdev (worktrees, stashes, local commits) without losing work.

## What Went Well
- **Never-delete-first discipline**: every destructive step went inventory → classify → present plan → approve → execute (cleanup-delivery followed faithfully).
- **Ground-truth over proxy**: verified liveness with `lsof`/`ps`/`gh pr` state instead of assuming — trusted PR merge state over `git` ancestry for squash-merged branches, and checked `origin/staging..HEAD` unique-commit counts before deleting unpushed branches (both came back `0`, so nothing was lost).
- **Recoverable operations**: stashed stray WIP instead of `reset --hard`; salvaged calm-valley handoff docs before removing its worktree; archived worktrees before `rm`.
- **Re-verify before acting**: killed the "phantom" pi only after confirming 4-day idle + `ppid=1`; killed orphaned ast-grep LSPs only after confirming reparent to launchd.

## What Went Wrong / Friction
- **Built bandaids before finding the native affordance**: shipped `piwt` (zsh fn) + a zoxide-opener patch to force worktree isolation — then discovered herdr already has native `new_worktree` (`prefix+shift+g`). Both commits were reverted. Classic ponytail rung-3 miss (native platform feature existed).
- **hypa shell wrapper mangled compound commands twice**: inline `for` loops / semicolons hit `syntax error near unexpected token` and `hypa: ... process 'do'`. Lost two tool calls before switching to script files.
- **macOS bash 3.2 has no `declare -A`**: an associative-array script silently collapsed to one key, producing 7× duplicate output before I caught it.
- **Misclassified idle/orphaned procs as "active sessions"** twice — corrected by the user both times.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | Revealed they start work via herdr's native "new" → piwt/zoxide were solving the wrong layer | Built a fix before identifying the actual entry point / native affordance | ponytail + `docs/agents/habits.md` |
| 2 | "the deep-dive shouldnt be running. i closed that" | Classified an orphaned `ast-grep lsp` (ppid=1) as a live session | `cleanup-delivery` |
| 3 | "im not running them... no other pi sessions" | Flagged a 4-day-idle pi + Cursor LSPs as blocking-live without checking age/parent/write-handles first | `cleanup-delivery` |

## Lessons
1. **Presence ≠ liveness**: a process cwd'd in a repo is not an active session. Verify parent (`ppid≠1`), `etime`, open *write* handles, and CPU before treating it as a concurrency blocker. All three "blockers" this session were stale/orphaned.
2. **Native affordance before bandaid**: check whether the tool already does it (`herdr new_worktree`) before writing wrapper scripts. Reverting is cheaper if you check first.
3. **Protected-main + auto-commit = a leak**: observational-memory commits straight to local `main`, but `main` is PR-protected (`GH013: Changes must be made through a pull request`). Reflections can *never* fast-forward to origin → 21 commits silently accumulated locally.
4. **Multi-account gh is a create-time gate**: `gh pr create` failed `must be a collaborator` until `gh auth switch` to the repo-owning account; had to restore the prior active account after.
5. **In this env, batch shell = script file**: the hypa wrapper breaks inline loops/heredocs; write `/tmp/x.sh` and run `bash /tmp/x.sh`.

## Proposed Improvements
- [ ] `cleanup-delivery/SKILL.md` — in the concurrency/liveness safety check, add an explicit **liveness triage**: a proc is only "active" if `ppid≠1` **and** recent `etime`/nonzero CPU **and** holds open *write* handles under the path; otherwise treat as orphaned/idle and safe to reap. (priority: high — caused 2 corrections)
- [ ] `cleanup-delivery/SKILL.md` — add an **orphaned agent-daemon sweep** step: `pgrep -f 'ast-grep lsp|mcp'` filtered to `ppid=1` are leaked pi-lens/MCP daemons safe to kill. Recurred this session (ast-grep) and earlier (playwright/context7). (priority: med)
- [ ] `git-guardrails` (multi-account section, PR #111) — before `gh pr create`/`gh pr merge` on a personal-account repo, `gh auth switch --user <owner>` then restore the prior active account. (priority: high — PR #143 blocked until switch)
- [ ] `docs/agents/habits.md` — env note: pi's hypa shell wrapper mangles inline compound bash (`;`, `for`, heredocs); write a script file and run `bash /tmp/x.sh`. Also: macOS ships bash 3.2 — no `declare -A`; use portable `name|path` line loops. (priority: high — cost 3 tool calls)
- [ ] **New finding (issue candidate)** — observational-memory auto-commits to PR-protected `main`, so reflections can never reach origin and pile up locally. Options: OM targets a dedicated branch, or a periodic "land reflections via PR" job. (priority: med-high)
