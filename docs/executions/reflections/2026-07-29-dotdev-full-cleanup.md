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

- [x] `cleanup-delivery/SKILL.md` — **DONE**: added **liveness triage** to the safety check (proc is "active" only if `ppid≠1` + recent etime/CPU + open *write* handles; else reap).
- [x] `cleanup-delivery/SKILL.md` — **DONE**: added **orphaned agent-daemon sweep** step (`pgrep -f 'ast-grep lsp|mcp|playwright|context7'` at `ppid=1`).
- [x] `git-guardrails/SKILL.md` — **DONE**: extended multi-account section with the `GH_TOKEN=$(gh auth token --user <owner>) gh pr create/merge` pattern + `--admin` ruleset override; corrected the plan's `gh auth switch` (skill discourages it as a keyring race — token pinning preferred). habits.md already carries the reflex bullet.
- [x] `docs/agents/habits.md` — **DONE**: added hypa-compound-command + macOS bash 3.2 (`declare -A`) note.
- [ ] **New finding (issue candidate)** — observational-memory auto-commits to PR-protected `main`, so reflections can never reach origin and pile up locally. Options: OM targets a dedicated branch, or a periodic "land reflections via PR" job. (priority: med-high)
