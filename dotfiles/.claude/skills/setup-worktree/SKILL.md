---
name: setup-worktree
description: Create an isolated git worktree from `origin/staging` for a design-plan phase, issue, or workflow run. Defaults the worktree path to `~/wt/<repo>/phase-<N>/` and creates a new branch derived from the plan phase or explicit branch input. Auto-copies common config files (.env*, .envrc, .nvmrc, .python-version, .tool-versions). Used before workflow execution and on-demand when a workflow halts at a human gate.
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
    description: Branch name. If empty and `plan_path`/`phase` set, derive `refactor/phase-<N>-<plan-phase-slug>`. New branches are created from `origin/staging`; existing branches are allowed only when explicitly reviewing or resuming that branch.
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

## Deprecation Status

Status: standalone use deprecated. This skill remains loadable only because `workflow-build-one, workflow-debug, run-backlog, or workflow-finalize human-gate sidecar` may invoke it as an implementation helper.

- Workflow owner: `workflow-build-one, workflow-debug, run-backlog, or workflow-finalize human-gate sidecar`
- Reason: Worktree setup is a sidecar/helper, not an execution workflow.
- Date: 2026-05-21


## Contract

Consumes: plan phase number and/or branch name, repo state
Produces: isolated git worktree directory with copied env/config files
Requires: git
Side effects: creates worktree directory, creates git branch (if new), copies env/config files
Human gates: none

## Context

Typical workflows: on-demand side-car (when /execute-phase or /workflow-finalize halts at a human gate, for isolated branch review, or for workflow-autonomous-backlog issue execution)
Pairs well with: execute-phase, workflow-finalize, watch-ci, design-plan, workflow-autonomous-backlog, run-backlog

# /setup-worktree — Isolated Checkout for a Plan Phase

## Purpose

Workflows that mutate code should start in a fresh isolated worktree
cut from `origin/staging`. This skill creates that worktree, copies the
env/config files that new checkouts usually need, and optionally runs a
setup command. The worktree is discardable — `git worktree remove
<path>` when done.

This is both the standard worktree creation helper for workflows and a
standalone, on-demand side-car for halted human gates.

## Step 0: Preflight

- Confirm a git repo.
- Run `git fetch origin --prune` before reasoning about branches.
- Verify `origin/staging` exists. If not, halt and ask the user which remote base should replace it.
- Resolve inputs into a concrete `(branch, path, setup_command)` triple:
  - **If `branch` and `path` both set:** use them.
  - **Else if `plan_path` and `phase` set** (most common caller from `/execute-phase` halt):
    - Open the plan, find `### §5.<N> Phase <N>`, extract the phase slug from the header text after `Phase <N> —` (lowercase, non-alphanum → `-`, trim, cap 40 chars — same derivation `/execute-phase` uses).
    - `branch = refactor/phase-<N>-<phase-slug>`
    - `path = ~/wt/<repo-dirname>/phase-<N>/` where `<repo-dirname>` is `basename $(git rev-parse --show-toplevel)`.
  - **Else if `plan_path` empty but `phase` non-zero:** fall back to newest `docs/plans/*.md` for `plan_path`, then derive as above.
  - **Else:** abort with a clear message: need either `(branch, path)` or `(plan_path, phase)` (or at least `phase` with a newest plan on disk).
- Verify `path` doesn't already exist. Abort if it does (would require `git worktree add --force`, which we won't do silently).
- Verify `branch` can be created as a new local branch from `origin/staging`. If it already exists, halt unless the user explicitly requested branch review/resume mode.
- Before checking out an existing branch for explicit review/resume mode, verify it has `WORKTREE_BASELINE_GATE` evidence or ancestry from `origin/staging`. Otherwise halt and recreate the work in a fresh origin/staging-based worktree.

## Step 1: Create the worktree

Single inlined command (no external `scripts/create_worktree.sh`):

- **Normal workflow mode:**
  `git worktree add -b "<branch>" "<path>" origin/staging` — creates a fresh branch from `origin/staging`.
- **Explicit review/resume mode only:**
  `git worktree add "<path>" "<branch>"` — checks out the existing branch in the new worktree.

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

Use a glob loop: `for f in <list>; do [ -f "<repo>/$f" ] && cp "<repo>/$f" "<path>/$f" 2>/dev/null; done`. Record each copied file and each skipped file whose parent directory is missing; do not silently omit expected setup files.

Report the list of files actually copied in the chat summary.

## Step 3: Run setup command (optional)

If `setup_command` is non-empty:

`cd "<path>" && <setup_command>`

Stream or capture the output. If the command exits non-zero, surface the error but do not tear down the worktree — the user likely wants to debug in place.

If `setup_command` is empty, record `setup_command: not provided` in the summary.

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
        [git fetch origin --prune]
        [git worktree add -b refactor/phase-2-skill-scaffolding ~/wt/myrepo/phase-2/ origin/staging]
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
Claude: [git fetch origin --prune]
        [git worktree add -b fix/flaky-test ~/wt/myrepo/flaky origin/staging]
        [copied .env.local, .nvmrc]
        [bun install: exit 0, 312 packages installed]

        Worktree at ~/wt/myrepo/flaky on fix/flaky-test.
        Setup: bun install succeeded (312 packages).
```

## Tuning notes

- **No primary-checkout resolution.** Resolve halted work inside the
  origin/staging-based phase worktree. If the halt happened in the
  primary checkout, stop and recreate the work in a fresh worktree
  before making further changes.

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
/workflow-review (specialist subagents with dispatch evidence)
     ↓
/post-mortem (NEW-NN, drift)
     ↓
/workflow-finalize (describe-pr, draft PR, receive-review, watch-ci,
                    reconcile, draft handoff)
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
