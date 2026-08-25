---
name: cleanup-delivery
model: haiku
reasoning: medium
description: Use when cleaning up after merged, closed, abandoned, or superseded delivery work; when local branches, git worktrees, draft PRs, issue labels, or ticket state may be stale.
---

# Cleanup Delivery

## Purpose

Clean up delivery residue without losing work: tickets, PR state, local branches, worktrees, labels, and handoff artifacts.

## Contract

Consumes: PR/issue references, local git state, worktree list, delivery handoff/finalization evidence
Produces: cleanup plan, actions taken, remaining manual cleanup items
Requires: git; gh when touching GitHub state
Side effects: may remove local worktrees/branches, update issue labels, close or comment on issues with approval
Human gates: any destructive local deletion, remote branch deletion, issue closure/reopen, PR close, or follow-up issue creation

## When To Use

Use after:

- PR merged and human confirms cleanup is allowed
- PR closed without merge
- Worktree-based issue run completes or is abandoned
- Backlog run leaves many stale local branches or worktrees
- User asks to clean tickets, branches, worktrees, or stale delivery state

Do not use before final review/CI/reconciliation gates pass unless the work is explicitly abandoned.

## Core Rule

Never delete first. Inventory, classify, present the cleanup plan, then act only on approved items.

## Workflow

### 1. Gather State

- Confirm git repo and current branch.
- **Fetch and identify authoritative remotes**: Run `git fetch --prune` on all relevant remotes (e.g., `git fetch origin`, `git fetch personal`, or per `git remote -v`). Then identify which remote is the current authoritative source of truth for the primary branch — it may not be `origin` (e.g., in multi-account repos, `personal/main` may be ahead of `origin/main`). Report the authoritative remote/branch pair in the cleanup plan. This is essential because stale remote refs will classify items incorrectly.
- List worktrees with `git worktree list --porcelain`.
- List local branches with upstream/merge status.
- **Report primary checkout sync**: Check whether the primary branch (typically `main` or `master`) is behind, ahead of, or in sync with the identified authoritative remote branch. If behind or ahead, or if the working directory has untracked files, flag this in the final report as "primary checkout dirty state." This context is critical for understanding the cleanup baseline.
- For referenced PRs/issues, inspect current GitHub state with `gh`.
- Read relevant handoff/finalization evidence when present.

### 2. Classify Each Item

Use these buckets:

- `safe-remove-worktree`: worktree branch merged, pushed, **clean (empty `git -C <path> status --porcelain`)**, no active PR needs it, **and no live process is cwd'd into it**. A merged branch does NOT override the clean requirement — uncommitted changes in a merged worktree still route to `needs-user-approval`.
- `safe-delete-local-branch`: branch merged to its intended base or remote no longer needs local copy. **Confirm merge via PR state (`gh pr view <n> --json state,mergedAt`), not git ancestry alone** — squash/rebase merges leave the branch looking unmerged to `git branch -d`. A branch whose PR is merged is safe to delete with `-D`; that is not "discarding unmerged work" and does not need the unmerged-work approval gate.
- `handoff-only branch`: clean, pushed branch with no open PR, whose only purpose is to preserve a repo-local handoff or artifact (e.g., `codex/handoff-next-issue-*`). These require an explicit decision: **keep** (if the handoff is still in use), **open PR** (if it should enter review), or **delete** (if the handoff has been migrated to a global mirror or is superseded). Do not discard without deciding.
- `dirty-handoff-or-docs-drift`: worktree with untracked or uncommitted changes, but the dirty content is *only* handoff artifacts, documentation updates, or reflection notes — not active implementation. Distinguish from `dirty-active-implementation`. Requires decision: **preserve** (if the handoff should be kept for next session), **commit** (if it should land with the branch), or **explicitly abandon** (with reason why the handoff is obsolete).
- `needs-user-approval`: dirty active-implementation work, unpushed commits, unmerged branch, remote branch deletion, ticket closure, or PR closure.
- `keep`: active PR, unresolved review/CI, open issue still in progress, or unclear ownership.
- `follow-up-needed`: leftover work should become an issue before cleanup.

### 3. Reconcile Tickets

Invoke `reconcile-issues` when GitHub issue or PR state is involved.

Automated without extra approval:

- Remove stale `in-progress` label when no PR is open.
- Add `stale` label to issues with no activity over 30 days.
- Prune aged global handoff mirrors (dated filenames, low-risk text copies):
  - `find ~/.chorus/handoffs -name '*.md' -mtime +30 -delete`
  - `find ~/.chorus/handoffs/_ephemeral -name '*.md' -mtime +7 -delete`
  Repo copies under `docs/executions/handoffs/` are left untouched (they commit with the branch).

Requires approval:

- Close or reopen issues.
- Close PRs.
- Remove `ready-for-agent`.
- Create follow-up issues.
- Delete remote branches.

### 4. Present Cleanup Plan

Before acting, show:

```markdown
## Cleanup Plan

### Authoritative Remote
- **Primary branch**: <branch> → **authoritative source**: <remote>/<branch> (ahead/behind/in-sync)

### Primary Checkout State
- **Sync**: behind/ahead/in-sync with <remote>/<branch>
- **Dirty files**: <untracked/uncommitted files, if any>
- **Reconcile action** (if behind and clean): offer `git fetch && git reset --hard <remote>/<branch>`

### Safe Local Cleanup
- remove worktree: <path> (<branch>) because <evidence>
- delete local branch: <branch> because <evidence>

### Handoff-Only Branches
- keep: <branch> because <handoff reason>
- delete: <branch> because <handoff superseded/migrated>
- open PR: <branch> because <ready for review>

### Handoff / Docs Drift
- preserve: <worktree path> (<branch>) because <handoff/docs content>
- commit: <worktree path> (<branch>) because <content belongs in tree>
- abandon: <worktree path> (<branch>) because <reason>

### Needs Approval
- <action> because <risk/evidence>

### Keep
- <item> because <reason>

### Follow-Ups
- <issue/comment to create or preserve>

---

## Approval Required

**Before execution, you must confirm**:
> I approve the cleanup plan above: removing the listed worktrees/branches and closing the listed items. I will not touch: <remote branches>, <dirty worktrees>, <unresolved tickets>.

State explicitly what will be left untouched; this prevents silent misunderstanding of scope.

### 4.5. Reconcile Stale Primary (if applicable)

When primary checkout is behind authoritative remote AND clean (no uncommitted changes):

1. Report the state (Step 4 already does this)
2. Offer reconcile ACTION: `git stash -u && git fetch origin && git reset --hard origin/<branch> && git stash pop` (safety-patches any uncommitted changes first)
3. Gate on user approval before executing — never auto-reset

If the primary has uncommitted changes that conflict with the remote, route to `needs-user-approval` instead of offering the reconcile action.

### 5. Execute Approved Cleanup

**Self-cwd guard (before any `worktree remove`):** if the current working directory is `<path>` or a descendant of it, `cd` to the primary checkout / repo root first. Removing a worktree out from under *this* session's cwd breaks the shell even when no other process is anchored there.

**Re-verify immediately before each destructive action when a concurrent session was detected during Gather State.** State drifts: a branch merged/deleted, a worktree touched, or a PR reopened between plan and execution. Right before each removal/deletion, re-check just that item (`git status --porcelain <path>`, `git branch -vv | grep <branch>`, `gh pr view <n> --json state,mergeStateStatus`) — the plan from Step 4 is stale the moment another agent commits. Skip only when no concurrent session was observed.

Allowed commands after approval:

- `git worktree remove "<path>"` for clean approved worktrees (only after the self-cwd guard).
- `git worktree prune` after worktree removals.
- `git branch -d "<branch>"` for merged approved local branches.
- `git branch -D "<branch>"` only when the user explicitly approves discarding unmerged local work. Prefer one branch per command — `git branch -D a b c` deletes the branches it can, then exits non-zero on the first failure, so a batch can partially succeed while looking like it failed. Delete individually (or re-check state) when the exit code is non-zero.
- `git push origin --delete "<branch>"` only with explicit remote-deletion approval.

Do not use `git reset --hard`, force-push, or delete branches checked out in another worktree.

**Draft-PR merge preflight:** if cleanup involves merging a PR that is still a draft, run `gh pr ready <n>` first — `gh pr merge` fails on a draft. Confirm the merge is approved and gates pass before marking ready.

### 6. Final Report

Report:

- worktrees removed
- branches deleted
- tickets/labels/comments changed
- items kept and why
- follow-up issues created or still needed
- any cleanup skipped because it was risky or ambiguous

## Safety Checks

Before deleting a worktree or branch, verify:

- worktree is clean or the user explicitly approved discarding changes
- commits are merged, pushed, or intentionally abandoned (for merge, trust PR state over git ancestry — squash/rebase merges defeat git's merged detection)
- no open PR depends on the branch
- branch is not the current branch and not checked out in another worktree
- worktree has no uncommitted changes (`git -C <path> status --porcelain` is empty) — a merged/pushed branch does NOT waive this; uncommitted work in a merged worktree is still unsaved work
- no live process is anchored to the worktree (a running command, monitor, or agent session whose cwd is under `<path>`) — removing a worktree out from under an active process silently drops its uncommitted edits and breaks that process
  - **Liveness triage (presence ≠ liveness):** a process cwd'd in the path is only *active* when ALL hold — parent is not launchd (`ppid≠1`, i.e. not orphaned/reparented), it has recent `etime` / nonzero `%cpu`, AND it holds open *write* handles under the path (`lsof -a -p <pid> -d ^cwd | grep <path> | grep REG`). A days-idle process, an orphan (`ppid=1`), or a read-only indexer holding zero write handles is stale/leaked — safe to reap, not a concurrency blocker. Do not classify a worktree as "in use" on cwd match alone.
- **this session's cwd is not under `<path>`** — if it is, `cd` to the primary checkout before remove (see Step 5 self-cwd guard)
- ticket state matches PR disposition

### Orphaned agent-daemon sweep

Closed agent/IDE sessions routinely leak language-server and MCP daemons that reparent to launchd. Sweep them as part of cleanup:

```sh
# leaked pi-lens LSP + MCP daemons: cwd'd nowhere useful, parent = launchd (ppid 1)
for pid in $(pgrep -f 'ast-grep lsp|mcp|playwright|context7'); do
  [ "$(ps -p $pid -o ppid= | tr -d ' ')" = 1 ] && kill "$pid"   # orphan → safe to reap
done
```

Observed leaks: `ast-grep lsp` (pi-lens baselines, ran for days), `playwright`/`context7` npx MCP children. An orphan (`ppid=1`) holding no active parent is always safe to kill; a daemon with a live agent parent is not — check `ppid` first.

Before classifying anything else as unused/removable (a dependency, tool, config, file), verify against the **running system** — installed runtime deps, live startup diagnostics/warnings, a `which`/runtime probe — not just a source grep. A repo/skills/config search is a proxy that misses host-loaded plugins, extensions, and npm modules; the authoritative signal is what the running program actually loads and warns about.

### Canonicalization / path-layout cleanup

When the task is symlink removal, path canonicalization, or "make X the source of truth," inventory before deleting:

```markdown
## Symlink + Duplicate-Path Drift Report
- Symlinks under repo: <path> -> <target> (keep|replace|delete)
- Duplicate canonical mirrors (same content, two paths): <a> vs <b> (which is canonical?)
- Post-removal coupling check: any remaining refs to the retired path?
```

A symlink removal is incomplete until duplicate-path drift is checked and resolved. Prefer eliminating indirection when the user asked for a source of truth.

If any check is unclear, keep the item and ask.
