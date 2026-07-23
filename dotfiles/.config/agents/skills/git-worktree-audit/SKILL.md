---
name: git-worktree-audit
model: haiku
reasoning: medium
description: Use when asked to audit or clean up local git branches and worktrees across many repos on a machine — "audit branches", "clean up worktrees", "prune stale worktrees", branch/worktree sprawl. Read-only survey first, destructive actions only after explicit per-item approval.
---

# Git Worktree Audit

## Purpose

Audit and safely clean up local git branch + worktree sprawl across all repos on a
machine. Two phases: a read-only survey that produces a categorized report, then
destructive cleanup only after explicit per-item human approval. The safe pass is
lossless by construction (`git branch -d`, `git worktree prune`); force-deletes are
never automatic.

## Contract

Consumes: project roots discovered under `~` (do not hardcode — the set drifts), live git state per repo, `herdr workspace list` (or equivalent) when tool-managed worktrees are present
Produces: a per-repo categorized report (safe-deletable, `: gone]` upstream-deleted, on-disk worktrees) then, on approval, the executed deletions with post-verification
Requires: git; `herdr` only if `.herdr/worktrees/*` are present; `gh` only if resolving "gone but merged" via PR state
Side effects: phase 1 none; phase 2 deletes branches/worktrees after approval
Human gates: every force-delete (`git branch -D`, `git worktree remove --force`); the safe pass (`-d`, `prune`) needs no gate because it cannot lose reachable work

## Context

Typical workflows: standalone (periodic machine hygiene, run on request)
Pairs well with: cleanup-delivery (per-delivery residue), herdr (open workspaces)

## Hard rules (learned the expensive way)

- **Script-file any bash control flow.** This environment's shell wrapper reliably
  mangles inline `for`/`if`/`while` in the command string (splits loops, empties
  same-line `VAR=` assignments). Write the loop to a `.sh` file and `bash file.sh`.
- **Never grep the working tree for git metadata.** Use `git branch -vv`,
  `git for-each-ref`, `git worktree list` — a bare `grep`/`find` inside a repo hits
  vendored deps (venvs, node_modules, lockfiles) and drowns the signal.
- **Never bare `find ~`.** Home is huge (iCloud, caches) and will get OOM-killed
  (exit 137). Scope to known project roots discovered via `ls ~`.
- **`herdr worktree remove` only targets currently-open workspace IDs.** For any
  closed/orphaned worktree, plain `git worktree remove` is correct.

## Steps

### 1. Discover repos and worktrees (read-only)

Read project roots from `ls ~` (e.g. `~/projects`, `~/dojo`, `~/wt`, `~/dotdev`,
`~/jarvis` — don't hardcode). Enumerate real repos (`.git` is a directory) vs
worktree links (`.git` is a file) with a scoped `find <roots> -maxdepth 4 -name .git`.

### 2. Per-repo survey (read-only)

For each real repo, gather: `git worktree list`, `git branch -vv` (upstream +
`: gone]` markers), `git status --porcelain`. Categorize each branch/worktree as:
safe-deletable, upstream-gone, dirty/uncommitted, or currently-checked-out.

### 3. Zero-risk prune

`git worktree prune -v` per repo — only clears registry entries whose directory is
already gone. No approval needed.

### 4. Safe branch pass

For every local branch not currently checked out, attempt `git branch -d` (never
`-D` in this pass). `-d` refuses unless the branch is merged into HEAD or its
upstream, so this pass is provably lossless — no per-branch merge-checking required.

### 5. Report + gate

Report remaining `: gone]` branches (upstream deleted) and worktree dirs still on
disk, per repo. Do **not** auto-force-delete: squash-merge / PR-closed states are
indistinguishable from truly-abandoned work without checking GitHub. Surface for
explicit per-item approval.

### 6. Cross-check tool-managed worktrees

Before touching any `.herdr/worktrees/*` (or other tool-managed dir), run
`herdr workspace list`. Treat a worktree as orphaned only if it is NOT a currently
open workspace/pane.

### 7. Execute approved force-deletes

On approval: `git branch -D` confirmed-gone branches, `git worktree remove --force`
confirmed-stale worktrees. Re-verify with `git worktree list` / `git branch -vv`.

## Success criteria

`git worktree prune` clean, no `: gone]` branch deleted without explicit sign-off,
no worktree directory left orphaned from the registry.
