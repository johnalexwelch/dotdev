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
- Fetch remote refs with `git fetch origin --prune`.
- List worktrees with `git worktree list --porcelain`.
- List local branches with upstream/merge status.
- For referenced PRs/issues, inspect current GitHub state with `gh`.
- Read relevant handoff/finalization evidence when present.

### 2. Classify Each Item

Use these buckets:

- `safe-remove-worktree`: worktree branch merged, pushed, **clean (empty `git -C <path> status --porcelain`)**, no active PR needs it, **and no live process is cwd'd into it**. A merged branch does NOT override the clean requirement — uncommitted changes in a merged worktree still route to `needs-user-approval`.
- `safe-delete-local-branch`: branch merged to its intended base or remote no longer needs local copy. **Confirm merge via PR state (`gh pr view <n> --json state,mergedAt`), not git ancestry alone** — squash/rebase merges leave the branch looking unmerged to `git branch -d`. A branch whose PR is merged is safe to delete with `-D`; that is not "discarding unmerged work" and does not need the unmerged-work approval gate.
- `needs-user-approval`: dirty worktree, unpushed commits, unmerged branch, remote branch deletion, ticket closure, or PR closure.
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

### Safe Local Cleanup
- remove worktree: <path> (<branch>) because <evidence>
- delete local branch: <branch> because <evidence>

### Needs Approval
- <action> because <risk/evidence>

### Keep
- <item> because <reason>

### Follow-Ups
- <issue/comment to create or preserve>
```

### 5. Execute Approved Cleanup

Allowed commands after approval:

- `git worktree remove "<path>"` for clean approved worktrees.
- `git worktree prune` after worktree removals.
- `git branch -d "<branch>"` for merged approved local branches.
- `git branch -D "<branch>"` only when the user explicitly approves discarding unmerged local work.
- `git push origin --delete "<branch>"` only with explicit remote-deletion approval.

Do not use `git reset --hard`, force-push, or delete branches checked out in another worktree.

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
- ticket state matches PR disposition

Before classifying anything else as unused/removable (a dependency, tool, config, file), verify against the **running system** — installed runtime deps, live startup diagnostics/warnings, a `which`/runtime probe — not just a source grep. A repo/skills/config search is a proxy that misses host-loaded plugins, extensions, and npm modules; the authoritative signal is what the running program actually loads and warns about.

If any check is unclear, keep the item and ask.
