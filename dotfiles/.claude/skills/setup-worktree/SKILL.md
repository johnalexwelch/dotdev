---
name: setup-worktree
description: Create an isolated git worktree for a design-plan phase. Defaults the worktree path to `~/wt/<repo>/phase-<N>/` and the branch to `refactor/phase-<N>-<slug>` derived from the plan's §5 phase header. Auto-copies common config files (.env*, .envrc, .nvmrc, .python-version, .tool-versions) from the primary checkout. Used on-demand when an /execute-phase chain halts at a [human] gate and the user wants to finish the task in parallel with continued work on main, or to review a completed phase branch in isolation.
triggers:
  - "/setup-worktree"
  - "setup worktree"
  - "create worktree"
  - "isolated checkout"
persona: Staff Engineer setting up an isolated review checkout for a plan phase
inputs:
  - name: plan_path
    type: string
    default: ""
    description: Path to the design plan. If set with `phase`, derives the branch name from the plan's §5.<N> header and the worktree path from `~/wt/<repo>/phase-<N>/`. If empty and `branch` is set, uses `branch` directly.
  - name: phase
    type: integer
    default: 0
    description: Phase number to set up a worktree for. Requires `plan_path` (or falls back to newest `docs/plans/*.md`). If 0, both `branch` and `path` must be set explicitly.
  - name: branch
    type: string
    default: ""
    description: Branch name. If empty and `plan_path`/`phase` set, derive `refactor/phase-<N>-<plan-phase-slug>`. If the branch already exists, check it out in the new worktree; otherwise create it off the current HEAD.
  - name: path
    type: string
    default: ""
    description: Absolute path for the worktree. If empty, default to `~/wt/<repo>/phase-<N>/` when plan/phase derived, else `~/wt/<repo>/<branch-slug>/`.
  - name: setup_command
    type: string
    default: ""
    description: Optional setup command to run in the worktree after creation (`npm install`, `bun install`, `make setup`, `uv sync`, etc.). Skipped if empty.
reads:
  - docs/plans/<date>-design.md (when deriving branch from plan+phase)
  - git, current checkout (for branch existence + env file sources)
writes:
  - new worktree directory at <path>
  - new git branch (if `branch` doesn't already exist)
  - copied env/config files inside the worktree
---

## Contract

Consumes: plan phase number and/or branch name, repo state
Produces: isolated git worktree directory with copied env/config files
Requires: git
Side effects: creates worktree directory, creates git branch (if new), copies env/config files
Human gates: none

## Context

Typical workflows: on-demand side-car (when /execute-phase halts at [human] gate, or for isolated branch review)
Pairs well with: execute-phase, watch-ci, design-plan

# /setup-worktree — Isolated Checkout for a Plan Phase

## Purpose

`/execute-phase` defaults to branch-in-primary-checkout — fine for
clean auto-proceed chains, painful when a phase halts at a `[human]`
gate and the user wants to keep working on main while resolving the
gate in parallel. This skill creates a git worktree for the halted
phase branch (or any branch), copies the env/config files that new
checkouts usually need, and optionally runs a setup command. The
worktree is discardable — `git worktree remove <path>` when done.

This is a **standalone, on-demand side-car**. `/execute-phase` does
not invoke it automatically (see `2026-04-21-skills-updates-design.md`
§7 rationale — scope discipline is the isolation primitive;
filesystem isolation is human convenience).

## Step 0: Preflight

- Confirm a git repo.
- Resolve inputs into a concrete `(branch, path, setup_command)` triple:
  - **If `branch` and `path` both set:** use them.
  - **Else if `plan_path` and `phase` set** (most common caller from `/execute-phase` halt):
    - Open the plan, find `### §5.<N> Phase <N>`, extract the phase slug from the header text after `Phase <N> —` (lowercase, non-alphanum → `-`, trim, cap 40 chars — same derivation `/execute-phase` uses).
    - `branch = refactor/phase-<N>-<phase-slug>`
    - `path = ~/wt/<repo-dirname>/phase-<N>/` where `<repo-dirname>` is `basename $(git rev-parse --show-toplevel)`.
  - **Else if `plan_path` empty but `phase` non-zero:** fall back to newest `docs/plans/*.md` for `plan_path`, then derive as above.
  - **Else:** abort with a clear message: need either `(branch, path)` or `(plan_path, phase)` (or at least `phase` with a newest plan on disk).
- Verify `path` doesn't already exist. Abort if it does (would require `git worktree add --force`, which we won't do silently).
- Verify `branch` either exists (`git show-ref --verify --quiet refs/heads/<branch>`) or can be created (new name, no conflict).

## Step 1: Create the worktree

Single inlined command (no external `scripts/create_worktree.sh`):

- **If `branch` exists:**
  `git worktree add "<path>" "<branch>"` — checks out the existing branch in the new worktree.
- **If `branch` is new:**
  `git worktree add -b "<branch>" "<path>"` — creates the branch off the current HEAD.

If the command fails (path conflict, branch in use by another worktree, etc.): abort, report the error, do not attempt fallback logic. User fixes and re-invokes.

## Step 2: Copy env and config files

Auto-detect and copy each of the following from the primary checkout into `<path>`, if present (source-path is the repo root of the primary checkout, destination preserves the relative path):

- `.env`
- `.env.local`
- `.env.development` / `.env.production` / `.env.test` (any that exist)
- `.envrc`
- `.nvmrc`
- `.python-version`
- `.tool-versions`
- `.ruby-version`
- `.node-version`
- `.claude/settings.local.json` (if `.claude/` exists in destination, copy inside; else skip)

Use a glob loop: `for f in <list>; do [ -f "<repo>/$f" ] && cp "<repo>/$f" "<path>/$f" 2>/dev/null; done`. Each copy is best-effort; silently skip a file whose parent dir doesn't exist in the destination.

Report the list of files actually copied in the chat summary.

## Step 3: Run setup command (optional)

If `setup_command` is non-empty:

`cd "<path>" && <setup_command>`

Stream or capture the output. If the command exits non-zero, surface the error but do not tear down the worktree — the user likely wants to debug in place.

If `setup_command` is empty, skip silently.

## Step 4: Surface to user

Print to chat:

- One-line result: "Worktree created at `<path>` on branch `<branch>`."
- List of copied config files (or "no env/config files found").
- Setup command outcome if run (exit code + short tail of output).
- Next step if derived from a plan phase:
  - "To continue work on Phase <N>: `cd <path>` and resolve the pending `[human]` task(s) from `docs/executions/.phase-runs/<date>[-<plan-slug>]-phase-<N>.md`."
- Cleanup reminder: "When done: `git worktree remove <path>` (or `git worktree remove --force <path>` if dirty)."

## Output Format

Side effects (new worktree dir, new branch, copied files). No markdown output file — the worktree itself is the artifact. The skill reports status to chat only.

## Error Handling

| Failure | Behavior |
|---------|----------|
| Not in a git repo | Abort. |
| Insufficient inputs (no `branch`/`path`, no `plan_path`/`phase`) | Abort with guidance. |
| `plan_path` set but file missing | Abort with the path that was tried. |
| Phase N not found in plan | Abort. List phase headers present. |
| `path` already exists | Abort. User must choose another path or `git worktree remove` the existing one. |
| Branch conflict: `branch` is currently checked out elsewhere | Abort. Report the other worktree's path. User can either work there or remove it first. |
| `git worktree add` fails for another reason | Abort. Surface git's exact error message. |
| An env/config file exists in source but copy fails (permissions, etc.) | Warn per-file but continue with the rest. Report the failures in the summary. |
| `setup_command` exits non-zero | Surface the exit code and tail of output. Leave the worktree in place so the user can debug. |
| Repo has uncommitted changes on the current HEAD | Not fatal — worktree creation doesn't touch the primary checkout's working tree. Proceed. |

## Example Invocation

From a halted `/execute-phase` chain (Phase 2 blocked on a `[human]` task):

```
User: /setup-worktree phase=2
Claude: [preflight — newest plan: docs/plans/2026-04-20-design.md;
         phase 2 header: "Phase 2 — Skill scaffolding";
         derived branch: refactor/phase-2-skill-scaffolding;
         derived path: ~/wt/myrepo/phase-2/]
        [git worktree add ~/wt/myrepo/phase-2/ refactor/phase-2-skill-scaffolding]
        [copied .env, .nvmrc, .claude/settings.local.json]
        [no setup_command specified]

        Worktree created at ~/wt/myrepo/phase-2/
          on branch refactor/phase-2-skill-scaffolding.
        Copied: .env, .nvmrc, .claude/settings.local.json.
        Next: cd ~/wt/myrepo/phase-2/ and resolve the [human] task(s)
        from docs/executions/.phase-runs/2026-04-20-phase-2.md.
        When done: git worktree remove ~/wt/myrepo/phase-2/
```

Explicit branch + path + setup command:

```
User: /setup-worktree branch=fix/flaky-test path=~/wt/myrepo/flaky setup_command="bun install"
Claude: [git worktree add -b fix/flaky-test ~/wt/myrepo/flaky]
        [copied .env.local, .nvmrc]
        [bun install: exit 0, 312 packages installed]

        Worktree at ~/wt/myrepo/flaky on fix/flaky-test.
        Setup: bun install succeeded (312 packages).
```

## Tuning notes

- **On-demand only.** `/execute-phase` does not invoke this
  automatically. Scope discipline (§7 of the skills-updates plan) is
  the isolation primitive; filesystem isolation via this skill is
  human convenience for resolving `[human]` gates in parallel with
  continued main-branch work. When `/execute-phase` halts at a
  `[human]` gate, the user's options are: (a) resolve in place on the
  halted phase branch in the primary checkout; (b) run
  `/setup-worktree phase=<N>` to resolve in an isolated checkout.

- **Env-file scope.** The copy list is deliberately conservative —
  only files almost every project treats as environment setup. Do not
  copy secrets like `.aws/credentials` or global config like
  `~/.gitconfig`; those belong in the shell environment, not the
  worktree.

- **Copy, don't symlink.** Symlinks can cause surprising behavior
  when the worktree is later removed (dangling links) or when the
  primary `.env` is edited mid-phase. Flat copy is safer and
  explicit.

- **Default path convention.** `~/wt/<repo>/phase-<N>/` when
  derived from a plan; `~/wt/<repo>/<branch-slug>/` otherwise. User
  can override with an explicit `path` input. Colocating worktrees
  under `~/wt/` makes them easy to list (`ls ~/wt/`) and
  bulk-cleanup.

- **Re-running after `git worktree remove`.** Safe — this skill
  aborts if `path` exists but happily re-creates it after removal.
  No stale metadata survives.

- **Not a replacement for the primary checkout.** This worktree is
  for one branch at a time. Don't try to jump between branches
  inside it — that defeats the isolation purpose. Tear it down and
  create a new one for a different branch.

- **Ported from** `~/Desktop/skills/setup-worktree/SKILL.md`. Drops:
  the `scripts/create_worktree.sh` script-first fallback (inlined
  `git worktree add` unconditionally), `.humanlayer/tasks/<eng-XXXX>/`
  Linear-ticket flow (→ `plan_path` + `phase` derivation or explicit
  `branch`/`path`), `linear get-issue` integration, the interactive
  confirmation prompt (skill is now non-interactive — inputs are the
  contract). Adds: plan-phase → branch/path derivation matching
  `/execute-phase` conventions, expanded env-file detection list
  (beyond source's `.env*` glob), structured error-handling table.

## Pairing with the core loop

`/setup-worktree` is the side-car, not a core-loop member. Core loop:

```
/repo-audit (optional — brief-mode skips this)
     ↓
/design-plan (audit-mode OR brief-mode)
     ↓
/execute-phase ({refactor,fix,feat}/phase-* branches)
     ↓
/review (workspace reviewer subagent, in-loop)
     ↓
/post-mortem (NEW-NN, drift)
     ↓
/describe-pr (cites NEW-NN)
     ↓
[human gh pr create]
     ↓
/watch-ci (poll, auto-fix, /security-review, approve when clean)
     ↓
[human merge]
```

When `/execute-phase` halts at a `[human]` gate, users optionally
invoke `/setup-worktree phase=<N>` to resolve the gate in an isolated
checkout, then re-invoke `/execute-phase phase=<N>` (either in the
worktree or after merging the worktree branch into the primary
checkout's HEAD) to resume the chain. `/setup-worktree` is also
useful for reviewing a completed phase branch in parallel with
continued work on main, or for resolving CI failures from
`/watch-ci` in isolation when the auto-fix loop halts.
