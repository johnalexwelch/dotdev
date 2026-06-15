---
name: execute-phase
model: sonnet
reasoning: medium
description: Execute one or more phases of a design-plan output for refactor-scale or migration work. Reads a phase section from a plan, creates a per-phase git branch, dispatches scoped [auto] tasks, verifies, commits on pass, and writes phase-run evidence. Do not use for normal issue-based product work; use workflow-build-one, execute-prd, or run-backlog after triage.
triggers:
  - "/execute-phase"
  - "execute phase"
  - "run phase"
  - "land phase"
persona: Staff Engineer orchestrating one phase of a design plan through scoped subagents with evidence-based verification
inputs:
  - name: plan_path
    type: string
    default: ""
    description: Path to the design-plan file. If empty, use the newest `docs/plans/*.md`.
  - name: plan_slug
    type: string
    default: ""
    description: Short slug identifying the plan (used in outcome filename and commit messages). If empty, derive from the plan filename stem by stripping the leading `<YYYY-MM-DD>-` and trailing `-design` suffix.
  - name: phase
    type: integer
    default: 0
    description: Phase number to execute (must match a `### §5.<N> Phase <N>` header in the plan's §5).
  - name: auto_proceed
    type: boolean
    default: true
    description: If true, after successful commit and no pending [human] tasks, cut the next phase branch off the prior phase commit inside the same origin/staging-based worktree and recurse. Halt on verification fail, [human] gate, scope violation, or next-phase preflight error.
  - name: dry_run
    type: boolean
    default: false
    description: If true, parse the phase and write an outcome file but dispatch no mutating subagent, create no branch, and make no commit. Used to validate plan parsing without side effects.
  - name: resume
    type: boolean
    default: false
    description: If true, attempt to resume a halted chain. Looks for an existing outcome file for `phase`; if it shows pending [human] tasks now marked resolved in the plan, re-run from the failed step. Best-effort; a fresh invocation is usually safer.
reads:
  - docs/plans/<date>-design.md (newest unless `plan_path` is set)
  - docs/executions/.phase-runs/<date>[-<plan-slug>]-phase-<prior>.md (when resuming or auto-proceeding, for provenance)
  - git log, git status, git branch (to establish HEAD and sync-gate state)
writes:
  - docs/executions/.phase-runs/<date>[-<plan-slug>]-phase-<N>.md
  - new git branch `<prefix>/phase-<N>-<slug>` (from `origin/staging` for first live phase, then stacked on the prior phase commit only when auto-proceeding in the same worktree)
  - git commits on that branch
---

## Contract

Consumes: design plan phase (docs/plans/), codebase, git state
Produces: committed code on phase branch, phase outcome file (docs/executions/.phase-runs/)
Requires: git
Side effects: creates git branches, modifies files, creates commits, writes outcome files
Human gates: verification failure halts; [human]-tagged tasks in plan honored (never executed); scope violations halt

Runtime note: subagent dispatch and project build/test tools are required for live execution and verification. They are discovered from the host agent and repo files or CI workflows. `dry_run=true` may run with `git` only because it dispatches no mutating workers and performs no verification gate.

## Context

Typical workflows: specialized phase-plan lane after `design-plan`, before `workflow-review` and `workflow-finalize`
Pairs well with: design-plan, review, post-mortem, setup-worktree

# /execute-phase — Dispatch Phases of a Design Plan

## Model selection

Dispatch `[auto]` implementation workers on **Sonnet** (`model: sonnet`) — mechanical implementation rarely needs a frontier model. Reserve **Opus** for planning, review, and synthesis. Escalate a single worker to Opus only for genuinely hard logic.


## Output discipline (during execution only)

While running the mechanical execution/implementation loop, compress **routine progress narration** to caveman style — drop articles, filler, and pleasantries; prefer `[thing] [action] [reason]. [next].` This cuts scroll and output tokens during the grind.

Snap back to **full prose** for anything that needs judgment: findings, scope violations, blockers, `NEEDS_HUMAN` gates, decisions/tradeoffs, and the final summary/handoff. The terseness is scoped to the loop — it ends when execution ends; do not carry it into the review or handoff that follows. See `caveman` for the full compression rules.


## Purpose

`/design-plan` produces a phased plan with `[auto]`/`[human]` markers,
falsifiable Verification, per-phase Rollback, and `FIND-NN`/`GAP-NN`
traceability. This skill executes those phases: creates a branch,
dispatches scoped subagents to do the `[auto]` work, verifies the
result against the phase's Verification text, commits with FIND
citations, and either stacks the next phase or halts. The outcome file
is the machine-readable record `/post-mortem` and `/describe-pr`
consume.

This is not the default product delivery path. Use it only when a human-
approved `design-plan` exists. Normal vertical issues created by
`to-issues` and approved by `triage` should be executed by
`workflow-build-one`, `execute-prd`, or `run-backlog`.

The skill enforces these invariants:

1. **`[human]` tasks are never executed.** Surface them to chat and
   to the outcome file, then halt until the user resolves them.
2. **Parallel work receives disjoint scopes.** Each `[auto]` cluster
   gets explicit file paths or globs; overlap serializes execution.
3. **Scope verification happens before verification.** A separate
   read-only check compares changed files against granted scopes and
   halts on any out-of-scope write.
4. **Verification gates every commit.** A separate verification pass
   evaluates the phase's Verification text before any commit is made.
5. **Trace IDs are preserved verbatim.** `FIND-NN`, `REQ-NN`,
   `GAP-NN`, ticket slugs, issue numbers, and mixed schemes are echoed
   into outcome files and commit messages without normalization.

## Reference Files

Load these files as needed for the active step:

- `references/phase-parsing.md` — preflight, plan selection, phase
  extraction, task partitioning, ID handling, and single-issue mode.
- `references/branch-naming.md` — plan slugs, branch prefixes, phase
  branch creation, stacked parentage, and commit message schema.
- `references/subagent-briefs.md` — `[auto]` cluster dispatch rules,
  worker prompt template, serial/parallel choice, and reporting shape.
- `references/scope-verification.md` — post-batch changed-file
  verification and scope violation behavior.
- `references/verification-gates.md` — `[human]` gates, verification
  subagent prompt, pass/fail/unverified semantics, and commit gate.
- `references/outcome-file-template.md` — outcome paths, markdown
  template, downstream consumption conventions, and follow-up format.
- `references/resume-and-auto-proceed.md` — halt reasons, resume
  behavior, auto-proceed recursion, user-facing summary, and downstream
  PR assumptions.
- `references/execution-profiles.md` — execution profiles, profile
  selection, tuning notes, and core-loop pairing.

## Core Flow

1. **Preflight and parse.** Confirm a clean working tree, verify the
   current worktree/branch was cut from `origin/staging`, resolve
   `plan_path`, `plan_slug`, date, phase number, target outcome file,
   ID scheme, branch prefix, and phase fields. See
   `references/phase-parsing.md` and `references/branch-naming.md`.
2. **Partition tasks.** Split ordered tasks into `[auto]`, `[human]`,
   and unknown tasks. Group `[auto]` tasks into clusters by overlapping
   file/module scope. Unknown tasks are warnings and are not executed.
3. **Create the phase branch.** For the first live phase, create
   `<prefix>/phase-<N>-<phase-slug>` from `origin/staging` in a fresh
   worktree. For chained auto-proceed phases, stack on the prior phase
   commit in that same worktree. For `dry_run`, skip branch creation
   and record that in the outcome file.
4. **Dispatch `[auto]` clusters.** Send each cluster to a
   `general-purpose` subagent with explicit scope, ordered verbatim
   tasks, no-`[human]` constraints, rollback reference, and required
   reporting. Parallelize only when scopes are disjoint.
5. **Verify scope.** Run a separate read-only scope check against
   `git status --porcelain` and `git diff --name-only HEAD`. Halt on
   any out-of-scope write.
6. **Surface `[human]` work.** Write every `[human]` task verbatim to
   `## Pending human` and chat. If any exist, halt with no commit and
   no auto-proceed.
7. **Verify behavior.** Dispatch a separate read-only verifier against
   the phase's Verification text. Halt on FAIL or load-bearing
   UNVERIFIED claims.
8. **Commit scoped changes.** On verification PASS, stage only the
   union of granted scopes and commit as
   `phase-<N>: <phase Goal> (addresses <ID list>)`, omitting the
   parenthetical when no IDs exist.
9. **Write the outcome file.** Record executed work, pending human
   tasks, verification, rollback, commits, scope violations, parse
   warnings, follow-ups, and chain state.
10. **Halt or auto-proceed.** Halt on blockers, `auto_proceed == false`,
    or end of plan. Otherwise recurse into `phase=N+1` from the phase
    commit.

## Partial-Completion Contract

Before any live phase exits, the executor MUST be in ONE of these three states. This is binding regardless of remaining token budget:

**A. Complete.** All changes committed and pushed to the remote branch.

**B. WIP-paused.** Current progress committed with a `wip:` prefix in the subject line, naming exactly what remains. Pushed.

**C. Rolled back.** `git reset --hard <baseline>` to leave the worktree clean.

Verification before exit: run `git status --short`. If ANY line shows `M` or `??` for a source file in the project tree, the contract is not satisfied. Commit or reset, then re-run `git status --short` until the worktree satisfies A, B, or C.

Record the chosen exit state, pushed commit or reset baseline, and final `git status --short` result in the phase-run outcome file. In `dry_run=true`, record `partial_completion: not_applicable_dry_run`.

## Operational Rules

- `dry_run == true` parses and writes an outcome file, but dispatches
  no mutating subagent, creates no branch, and makes no commit.
- Live runs must start in a fresh worktree cut from `origin/staging`.
  Do not execute phases from the primary checkout or a branch based on
  local `main`/`staging`.
- Existing target outcome file with `resume == false` is fatal. With
  `resume == true`, resume only from an existing outcome file. If no
  prior outcome exists, halt; a fresh invocation requires
  `resume=false` and normal preflight.
- Missing optional phase sections are parse warnings. Empty Tasks is
  fatal.
- Scope violations, failed `[auto]` tasks, pending `[human]` tasks,
  verification FAIL, and load-bearing UNVERIFIED claims all halt with
  no commit.
- Downstream PR work remains human-gated and should route through
  `/workflow-review` then `/workflow-finalize`; no skill should assume
  auto-merge without a human merge step.
