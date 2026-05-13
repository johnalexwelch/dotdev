---
name: execute-phase
description: Execute one or more phases of a design-plan output. Reads a phase section from a plan, creates a per-phase git branch (stacked on prior phase), dispatches the phase's [auto] tasks to one or more general-purpose subagents with disjoint file scopes, runs a post-batch scope-verification subagent, dispatches a verification subagent against the phase's Verification text, commits on pass (with FIND-NN citations), and either auto-proceeds to the next phase or halts on verification fail / human gate / scope violation. Writes a structured outcome file to docs/executions/.phase-runs/ that /post-mortem and /describe-pr consume. Closes the audit → plan → execute → retro loop.
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
    description: If true, after successful commit and no pending [human] tasks, cut the next phase branch off current HEAD and recurse. Halt on verification fail, [human] gate, scope violation, or next-phase preflight error.
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
  - new git branch `<prefix>/phase-<N>-<slug>` (off current HEAD; prefix is `refactor/` for audit-mode plans, `fix/` for brief-mode bug plans, `feat/` for brief-mode feature plans)
  - git commits on that branch
---

## Contract

Consumes: design plan phase (docs/plans/), codebase, git state
Produces: committed code on phase branch, phase outcome file (docs/executions/.phase-runs/)
Requires: git, project build tools
Side effects: creates git branches, modifies files, creates commits, writes outcome files
Human gates: verification failure halts; [human]-tagged tasks in plan honored (never executed); scope violations halt

## Context

Typical workflows: audit-loop (after /design-plan, before /review)
Pairs well with: design-plan, review, post-mortem, setup-worktree

# /execute-phase — Dispatch Phases of a Design Plan

## Purpose

`/design-plan` produces a phased plan with `[auto]`/`[human]` markers,
falsifiable Verification, per-phase Rollback, and `FIND-NN`/`GAP-NN`
traceability. This skill executes those phases: creates a branch,
dispatches scoped subagents to do the `[auto]` work, verifies the
result against the phase's Verification text, commits with FIND
citations, and either stacks the next phase or halts. The outcome file
is the machine-readable record `/post-mortem` and `/describe-pr`
consume.

The skill enforces three invariants from the plan it's executing:

1. **`[human]` tasks are never executed.** They are surfaced to chat
   and to the outcome file; the chain halts until the user resolves
   them.
2. **Scope discipline across parallel subagents.** When `[auto]` tasks
   are dispatched across multiple subagents, each subagent receives a
   disjoint file scope; a post-batch verification subagent diffs
   actual changes against granted scopes and halts the phase on any
   out-of-scope write.
3. **Verification gates every commit.** The phase's Verification text
   is run by a separate subagent before commit. Fail → no commit,
   chain halts, Rollback is surfaced to the user as reference.

## Step 0: Preflight

- Confirm working tree is clean (`git status --porcelain`). If dirty,
  abort — the phase sync-gate requires a clean HEAD to branch from.
- Resolve `plan_path`:
  - If set, use it. Abort if the file doesn't exist.
  - Else pick the newest `docs/plans/*.md`. Abort with guidance if
    none exists ("run `/design-plan` first").
- Resolve `plan_slug`:
  - If set, use it verbatim.
  - Else derive from the plan filename stem:
    `2026-04-21-skills-updates-design.md` → `skills-updates` (strip
    leading `<YYYY-MM-DD>-`, strip trailing `-design` if present).
    If the stem collapses to empty, fall back to empty (no slug
    component in the outcome filename).
- Compute today's date as `<YYYY-MM-DD>`.
- Verify `phase` is a non-negative integer.
- Ensure `docs/executions/.phase-runs/` exists (`mkdir -p`).
- Check whether the plan uses `FIND-NN`, `REQ-NN`, `GAP-NN`, ticket
  slugs (e.g. `JIRA-123`, `#456`), or some other ID scheme for
  Addresses. All schemes are accepted — the orchestrator echoes
  whatever IDs are found verbatim into commit messages and the outcome
  file header. If no IDs are present at all, note a warning —
  commit messages will omit the parenthetical citation but the phase
  still runs.
- **Derive branch prefix from plan mode.** Inspect the plan's §5
  Addresses lines and the plan filename slug. Default `refactor/` if
  the plan uses `FIND-NN` references (audit-mode). For brief-mode
  plans (no `FIND-NN`, only `REQ-NN` or ticket slugs), inspect the
  plan filename slug for bug-class keywords: `fix`, `bug`, `broken`,
  `error`, `crash`, `regression`. If any present → `fix/`. Otherwise
  brief-mode defaults to `feat/`. Override via `branch_prefix=<value>`
  param if the heuristic misfires.
- Check for an existing outcome file at
  `docs/executions/.phase-runs/<date>[-<plan-slug>]-phase-<N>.md`.
  If present and `resume == false`, abort: existing phase run detected.
  User must either pass `resume=true` or delete the outcome file.

## Step 1: Parse phase N

Read the plan. Locate `## §5 Execution plan`, then the phase header
matching `### §5.<N> Phase <N>` (heading levels 3 or 4 accepted).
Abort if not found; list the phase headers actually present.

Extract from the phase block:

- **Goal** — text under `**Goal:**`.
- **Tasks** — the enumerated list under `**Tasks:**`. Preserve order
  and verbatim text.
- **Addresses** — comma-separated IDs (or `n/a`).
- **Verification** — paragraph under `**Verification:**`.
- **Rollback** — paragraph under `**Rollback:**`.
- **Deletes** — list under `**Deletes:**` (or "none").

Compute the **phase slug** from the phase header: take the text after
`Phase <N> —`, lowercase it, replace non-alphanumeric runs with `-`,
trim trailing `-`, cap at 40 chars. This feeds the branch name
`<prefix>/phase-<N>-<slug>` (prefix derived in Step 0; default
`refactor/`).

Missing sections are warnings, not fatal — record them in
`## Plan parse warnings` and continue. Empty Tasks is fatal (the plan
was probably cut off mid-write).

## Step 2: Partition tasks

Walk the task list. For each entry:

- Starts with `[auto]` → `auto_tasks`.
- Starts with `[human]` → `human_tasks`.
- Any other leading token → `unknown_tasks` (warning; not executed).

Group `auto_tasks` into **clusters** — consecutive tasks that touch
the same surface area. Heuristic: tasks citing overlapping file
paths, glob patterns, or the same module go into one cluster.
Separate clusters get separate subagents in Step 3. When in doubt,
one cluster (serial is safe; parallel is speed).

## Step 3: Create the phase branch

On `dry_run == false` only:

- `git checkout -b <prefix>/phase-<N>-<phase-slug>` off the current
  HEAD (prefix derived in Step 0). The current HEAD is whatever the
  previous phase left checked out (auto-proceed stacks branches), or
  `main` for the first phase of the chain.
- Abort if the branch already exists (would indicate a prior attempt
  at this phase). User must rename or delete before re-invoking.
- Record the branch name and starting commit hash in the outcome
  file's `## Commits` block.

On `dry_run == true`: skip branch creation; note "branch creation
skipped (dry_run)" in the outcome file.

## Step 4: Dispatch `[auto]` clusters with scope-based isolation

For each cluster from Step 2, dispatch one `general-purpose` `Agent`
with this brief template:

> **Phase goal (context):** <phase Goal>
>
> **Your scope:** <explicit list of file paths or globs the cluster
> may read and modify>. Do not touch files outside this scope.
>
> **Ordered tasks (verbatim from the plan):**
> <numbered list of the cluster's `[auto]` task text>
>
> **Constraints:**
>
> - Do not execute any `[human]` task even if you encounter one in
>   context.
> - Prefer absolute-path invocations for commands whose output is
>   load-bearing evidence (`/bin/ls -la`, `/usr/bin/git`, etc.) —
>   tool-harness output truncation has been observed on bare `ls`.
> - Report back per task: status (done|failed), files touched
>   (absolute paths), exact command(s) run, notable output, any
>   deviation from the task text.
>
> **Rollback reference (if you hit a recoverable failure):** <phase
> Rollback text>. Do not invoke rollback silently; report and return.

Dispatch clusters in **parallel** (one message with multiple `Agent`
tool calls) when clusters have disjoint scopes. Serialize when
scopes overlap or when one cluster depends on another's output.

Collect all subagent reports. On any task marked `failed`: do not
dispatch later clusters. Surface the failure, write the outcome
file, exit non-zero.

## Step 5: Post-batch scope verification

After `[auto]` clusters complete, dispatch one short `general-purpose`
subagent to verify scope discipline:

> Run `git status --porcelain` and `git diff --name-only HEAD`.
> Compare the changed-files set against the granted scopes of each
> cluster that just ran (inlined below). Report:
>
> - Any file present in the diff but NOT covered by any cluster's
>   granted scope → **scope violation**. Quote the file path and
>   which cluster's scope it leaked from (if attributable).
> - Any cluster whose granted scope saw zero writes → note only
>   (not a failure).
> Do not modify anything. Return a structured report.
>
> Granted scopes:
>
> - Cluster 1: <paths/globs>
> - Cluster 2: <paths/globs>
> - ...

The orchestrator — not the working subagent — runs these diff commands
itself via the verification subagent, so `ls`-style output truncation
at the subagent boundary can't cause false negatives (see §Tuning).

Any scope violation: halt. Write outcome file with
`## Scope violations` populated. Do not commit.

## Step 6: Surface `[human]` tasks

Write every `[human]` task to `## Pending human` in the outcome file,
in original order, verbatim. Print the list to chat with header:
"Phase <N> has <K> pending `[human]` task(s):". Never execute them,
including under `dry_run`.

If any `[human]` task exists, the phase is **blocked**. No commit, no
auto-proceed. User must resolve in chat or in a worktree (run
`/setup-worktree phase=<N>` for an isolated checkout).

## Step 7: Verification subagent

If no scope violations, no failed `[auto]` tasks, and no pending
`[human]` tasks: dispatch one `general-purpose` subagent with the
phase's Verification text as the brief:

> Verify the following claim against the current working tree. Each
> sentence is a falsifiable check — produce a PASS/FAIL per claim
> with evidence (file reads, command outputs, counts). Do not
> modify anything.
>
> **Verification text (from plan §5.<N>):**
> <verbatim Verification paragraph>
>
> Return a structured report: overall PASS/FAIL, per-claim breakdown,
> and any claim you could not definitively verify (UNVERIFIED).

On FAIL: do not commit. Halt. Write the outcome file with the
verification subagent's report embedded. Quote the phase's Rollback
text to the user as reference. Exit non-zero.

On PASS: proceed to commit.

On UNVERIFIED (some claims couldn't be checked): treat as PASS if
every falsifiable claim passed AND unverified claims are clearly
informational (e.g. "tests pass"); treat as FAIL if an unverified
claim is load-bearing. When in doubt, halt and surface for user call.

## Step 8: Commit

On verification PASS:

- Stage files touched by the `[auto]` clusters: `git add -A` scoped
  to the union of granted scopes. Never `git add` paths outside the
  granted scopes (scope verification already caught them; this is
  belt-and-suspenders).
- Commit with message:

  ```
  phase-<N>: <phase Goal> (addresses <ID list>)
  ```

  IDs are echoed verbatim from the phase's Addresses line — `FIND-NN`,
  `REQ-NN`, `GAP-NN`, ticket slugs (`JIRA-123`, `#456`), or any
  combination. No scheme-specific normalization. Examples:
  - `phase-2: Port /execute-phase to production (addresses GAP-01)`
  - `phase-1: Fix mobile scroll on profile page (addresses REQ-01)`
  - `phase-3: Add dark-mode toggle (addresses ENG-456, REQ-02)`
  If Addresses is `n/a` or absent, omit the parenthetical.
- Record commit hash and full message in `## Commits`.

## Step 9: Auto-proceed or halt

**Halt on any of:**

- Verification FAIL.
- Pending `[human]` task in phase N.
- Scope violation.
- Failed `[auto]` task.
- `auto_proceed == false`.
- Phase N+1 doesn't exist in the plan, or Phase N+1 Step 1 parse
  fails.

**On halt:** write outcome file, surface full chain state to chat
(list of committed phase branches, current HEAD, blocker reason),
exit. The halted phase's branch is left checked out so the user
can resolve in place or hand off to `/setup-worktree`.

**On auto-proceed:** the next phase branches off the current HEAD
(which is now the phase N commit). Recurse into Step 0 with
`phase = N+1`. Each successive outcome file references the prior
phase's outcome file in its `## Commits` section as the branch
ancestry.

## Step 10: Write outcome file

Save to
`docs/executions/.phase-runs/<date>[-<plan-slug>]-phase-<N>.md`
using this structure:

```
# Phase <N> — <phase Goal>

**Plan:** <relative path to plan>
**Plan slug:** <plan_slug> (or "—" if none)
**Date:** <YYYY-MM-DD>
**Goal:** <goal text>
**Addresses:** <ID list from plan>
**Mode:** live | dry_run
**Branch:** <prefix>/phase-<N>-<phase-slug>
**Parent:** <starting commit short-hash> (<prior phase branch name or "main">)

## Executed
<For each [auto] task:
  - **Task <i>** [cluster <C>]: <verbatim task text>
  - Status: done | pending (dry_run) | failed
  - Files touched: <absolute paths from subagent report>
  - Subagent command(s): <as reported>
  - Notes: <brief; include verification evidence if relevant>>

## Pending human
<For each [human] task: verbatim text, numbered. If none, "None.">

## Verification
<Overall: PASS | FAIL | UNVERIFIED>
<Verbatim Verification text from plan, followed by per-claim
breakdown from the verification subagent.>

## Rollback (reference)
<Verbatim Rollback text from plan.>

## Commits
<For each commit on the phase branch:
  - <short-hash> <subject line>
  - Changed files: <paths>>

## Scope violations
<For each out-of-scope write (or "None."):
  - Path: <absolute path>
  - Attributed to cluster: <N>
  - Cluster's granted scope: <what it was supposed to touch>>

## Plan parse warnings
<Anything parsed oddly. If none, "None.">

## Follow-ups
<NEW-NN candidates surfaced during execution. For each:
  - **NEW-NN — <short title>**
  - Severity: low | medium | high
  - Source: <commit|subagent report|observation>
  - Recommendation: promote to FIND-NN in next /repo-audit | fix
    inline | defer.
Feeds forward into /post-mortem.>

## Chain state
<For each phase in the current auto-proceed chain:
  - Phase N: status (done|halted|not-started), branch, HEAD hash>
```

## Step 11: Surface to user

Print to chat:

- One-sentence phase summary: "Phase <N> — <goal> — <K> auto done,
  <M> human pending, verification PASS|FAIL, <commit-count> commits."
- If halted: the specific blocker (verification fail detail, human
  task list, or scope violation list).
- Pointer: `See docs/executions/.phase-runs/<date>[-<slug>]-phase-<N>.md`.
- If auto-proceeding: "Chaining to Phase <N+1>."
- If all phases done: "Plan complete. Next: `/review` (workspace
  reviewer subagent on the diff), then `/post-mortem` (writes retro
  citing `NEW-NN` discoveries), then `/describe-pr` (PR body cites
  retro), then `/watch-ci` (post-PR-open: polls CI, applies bounded
  auto-fixes, runs `/security-review`, submits Approve when clean)."

## Artifact Output

When issue context is available (issue number known), write phase outcomes to:

```
docs/tasks/{issue-number}-{slug}/phase-{N}-outcome.md
```

When no issue context (executing from a plan without linked issue), fall back to:

```
docs/executions/.phase-runs/{date}-phase-{N}.md
```

The issue slug is derived from the issue title: lowercase, spaces to hyphens, max 40 chars.
Example: issue #42 "Add user authentication" → `docs/tasks/42-add-user-authentication/phase-1-outcome.md`

## Output Format

Standard markdown at
`docs/executions/.phase-runs/<date>[-<plan-slug>]-phase-<N>.md`,
structured per Step 10. The outcome file is the artifact downstream
skills (`/post-mortem`, `/describe-pr`) consume. Never modify a prior
phase's outcome file — chain state is appended in the new phase's
outcome.

## Error Handling

| Failure | Behavior |
|---------|----------|
| Working tree dirty at Step 0 | Abort. User must commit or stash before starting. |
| `plan_path` empty and no `docs/plans/*.md` | Abort. Tell user to run `/design-plan` first or pass `plan_path`. |
| `plan_path` set but file missing | Abort with the path that was tried. |
| Phase N header not found in `## §5` | Abort. List phase headers present. |
| Plan has any ID scheme (`FIND-NN`, `REQ-NN`, `GAP-NN`, ticket slugs) | Echo verbatim into commit messages and outcome file. No scheme-specific validation. |
| Plan has no IDs at all in Addresses lines | Degraded — proceed; commit message omits the parenthetical citation; warn in outcome file. |
| Branch prefix heuristic misfires (e.g. `feat/` chosen for what's really a fix) | User can override via `branch_prefix=fix` (or `refactor`, `feat`) on the next invocation. Branch already created can be renamed manually. |
| Existing outcome file at target path and `resume == false` | Abort. User must delete or pass `resume=true`. |
| Empty `Tasks` block | Fatal — plan was cut off mid-write. Abort. |
| Branch `refactor/phase-<N>-<slug>` already exists | Abort. Prior attempt exists. User renames or deletes. |
| `[auto]` subagent fails a task | No later cluster dispatches. Outcome file records the failure. Chain halts. No commit. |
| Scope violation detected | Halt. `## Scope violations` populated. No commit. User resolves (revert out-of-scope writes or explicitly expand scope in plan). |
| `[human]` task present | Phase blocked. Outcome file lists in `## Pending human`. No commit. No auto-proceed. |
| Verification FAIL | No commit. Halt. Rollback text surfaced. |
| Verification UNVERIFIED load-bearing claim | Halt and surface for user judgment. Do not silently pass. |
| `dry_run == true` | No branch, no commit, no mutation. Outcome file still written with tasks marked `pending (dry_run)`. |
| Phase N+1 doesn't exist (expected end-of-plan) | Halt with success: "Plan complete." |
| Phase N+1 preflight fails mid-chain | Halt. Phase N commit stands. User fixes Phase N+1 and re-invokes with `phase=<N+1>`. |
| `resume == true` with no prior outcome file | Degrade to a fresh invocation with a note. |

## Example Invocation

Clean auto-proceed through several phases:

```
User: /execute-phase plan_path=docs/plans/2026-04-20-design.md phase=0 auto_proceed=true
Claude: [Phase 0: preflight clean, no [auto] changes, no commit, chain to 1]
        [Phase 1: pilot canary — 2 auto done, verification PASS,
         commit abc123, chain to 2]
        [Phase 2: skill scaffolding — 6 auto across 2 clusters
         (parallel), no scope violations, verification PASS,
         commit def456, chain to 3]
        [Phase 3: encounters [human] task — CHAIN HALTS]

        Phase 3 — Replace legacy scripts — 4 auto done,
        2 human pending, verification not run (blocked on human).
        3 commits landed: phase-0..phase-2. Phase 3 branch open.

        Pending human (2):
          1. Confirm launchd plist deprecation window.
          2. Approve the delete of scripts/daily-briefing.js
             (1,234 lines).

        Resolve and re-invoke:
          /execute-phase phase=3 auto_proceed=true
```

Phase-that-hits-a-human-gate:

```
User: /execute-phase plan_path=/tmp/my-plan.md phase=2
Claude: [preflight clean, branch refactor/phase-2-add-webhook created,
         1 [auto] cluster dispatched, scope verified,
         verification PASS, commit 7ab8cd, halt for [human]]

        Phase 2 — Add webhook endpoint — 1 auto done,
        1 human pending, verification PASS, commit 7ab8cd.

        Pending human (1):
          1. Decide whether to include retry-after header on 429 responses.

        Resolve and continue with:
          /execute-phase phase=3
        (or /setup-worktree phase=2 to finish the human task
         in an isolated checkout)
```

## Execution Profiles

Profiles control HOW code is written during execution — they do not change the phase structure or verification gates.

| Profile | Behavior | When to use |
|---------|----------|-------------|
| **normal** | Standard development. Clean code, reasonable tests, good commit messages. | Default for most work |
| **caveman** | Simplest boring implementation. No abstractions, no cleverness, no premature optimization. Make it work with the most obvious approach. | When speed matters more than elegance; prototyping; when the user says "just make it work" |
| **strict-tdd** | Every behavior change starts with a failing test. No implementation without a test. Red-green-refactor strictly enforced. | Bug fixes (mandatory), behavior-critical features, when user requests TDD |
| **prototype** | Throwaway code. No tests, no docs, no polish. Prove the concept works, then discard. Mark with `// PROTOTYPE - do not merge` comments. | Spike/exploration, feasibility check, demo |
| **safe** | Smaller commits, more verification steps, conservative changes. Each commit is independently revertable. Extra test runs between changes. | Production-critical code, unfamiliar codebase, high-risk changes |

## Profile Selection

Profiles are selected by (in priority order):

1. Explicit user request ("use strict-tdd", "caveman this")
2. Workflow context (workflow-debug always uses strict-tdd for the fix step)
3. Issue labels (`prototype`, `spike` → prototype profile)
4. Default: normal

## Single-Issue Execution

execute-phase supports both plan-phase execution and single-issue execution:

**Plan-phase mode** (original): reads a phase from a design plan, creates branch, executes tasks
**Single-issue mode**: reads a GitHub issue directly, creates branch from issue number, executes against acceptance criteria

Single-issue mode is invoked by workflow-build-one when there's no design plan — just a ready issue with clear acceptance criteria.

## Tuning notes

- **Parallel vs. serial cluster dispatch.** When clusters have truly
  disjoint scopes, dispatch them in one message with multiple Agent
  tool calls (the `/repo-audit` 13-agent pattern). When scopes
  overlap or a later cluster needs an earlier cluster's output,
  serialize. In doubt, serialize — correctness beats speed.

- **Scope granularity.** Err toward tight scopes. A cluster that
  needs to touch `src/foo.ts` should be granted exactly that path,
  not `src/`. Scope-verification then produces useful signal. Wide
  scopes mask scope-discipline breaks.

- **Evidence commands and subagent output truncation.** Observed in
  Phase 1 of the skills-updates plan: a subagent's bare `ls -la` call
  got its long-format columns stripped by the tool-harness output
  pipeline; absolute-path invocation (`/bin/ls -la`) worked. The
  scope-verification subagent (Step 5) re-runs `git status
  --porcelain` itself rather than trusting cluster-subagent quoted
  listings — that's the reason. Prompts for `[auto]` clusters
  include an instruction to prefer absolute-path invocations as a
  secondary defense.

- **When to use `/setup-worktree`.** `/execute-phase` defaults to
  branch-in-primary-checkout. If a phase halts at a `[human]` gate
  and the user wants to keep working on main while resolving the
  gate in parallel, run `/setup-worktree phase=<N>` to get an
  isolated checkout of the halted phase branch. Don't auto-create
  worktrees — scope discipline (§7 of the source plan) is the
  isolation primitive; filesystem isolation is human-convenience.

- **When to skip auto-proceed.** For any phase with non-obvious
  downstream impact (database migrations, prod-affecting config),
  pass `auto_proceed=false` even if the plan has no `[human]` task.
  Forces a manual gate.

- **`dry_run` is cheap.** Run it before any real phase execution
  when the plan is freshly written. Confirms parsing, Verification
  extraction, and outcome-file shape without side effects.

- **Outcome filename includes `plan_slug`.** When multiple plans are
  in flight (rare but happens — skills-updates plan + a feature plan
  on the same day), the slug disambiguates the outcome file.
  Filename schema: `<date>-<plan-slug>-phase-<N>.md`, falling back
  to `<date>-phase-<N>.md` when slug is empty. `/post-mortem` and
  `/describe-pr` tolerate both forms.

- **Commit message schema is load-bearing.** `phase-<N>: <Goal>
  (addresses <IDs>)` is parsed by `/post-mortem`, `/describe-pr`, and
  `/watch-ci` to attribute work to plan phases and any ID scheme.
  IDs in the parenthetical are echoed verbatim (`FIND-NN`, `REQ-NN`,
  `GAP-NN`, ticket slugs all valid). Do not reword without updating
  those skills.

- **Branch prefix scaling.** `refactor/` for audit-mode plans
  (anchored on `FIND-NN`), `fix/` for brief-mode bug plans (slug
  contains a bug-class keyword), `feat/` for everything else in
  brief-mode. `/post-mortem`, `/describe-pr`, and `/watch-ci`
  glob `{refactor,fix,feat}/phase-*` when walking the branch stack.

- **First-phase parent.** Phase 0 branches off `main`; Phase N+1
  branches off phase N's HEAD. A user who wants a different base
  should check out the desired base before the first
  `/execute-phase` call.

- **Ported from** `~/Desktop/skills/implement-plan/SKILL.md`. Drops:
  `implementer-agent` subagent type (→ `general-purpose`), ticket
  slugs and `.humanlayer/tasks/` paths (→ `docs/plans/` +
  `FIND-NN`), `{SKILLBASE}/references/` template files (inlined),
  the no-Claude-attribution commit rule (kept — commits use the
  phase-schema only, no cosign). Adds: branch creation, stacked
  auto-proceed, scope-based parallel subagent isolation with
  post-batch verification, separate verification subagent per phase,
  `.phase-runs/` outcome file schema, FIND-NN-aware commits,
  `plan_slug` filename disambiguation.

## Pairing with the core loop

```
/repo-audit     →  docs/audits/<date>-repo-audit.md          (FIND-NN; optional —
     ↓                                                        brief-mode skips this)
/design-plan    →  docs/plans/<date>[-<slug>]-design.md      ([auto]/[human]; audit OR brief mode)
     ↓
/execute-phase  →  docs/executions/.phase-runs/<*>.md        (this skill;
     ↓             {refactor,fix,feat}/phase-<N>-<slug>        prefix from plan mode)
/review         →  inline reviewer comments (workspace)      (in-loop, fresh subagent)
     ↓
/post-mortem    →  docs/executions/<date>-post-mortem.md     (NEW-NN, drift)
     ↓
/describe-pr    →  PR body / docs/executions/.pr-bodies/*.md (cites NEW-NN from retro)
     ↓
[human gh pr create]
     ↓
/watch-ci       →  docs/executions/.ci-runs/*.md             (poll, classify, auto-fix,
                                                              /security-review always,
                                                              /review on auto-fix diff,
                                                              approve when clean)
     ↓
[human merge]

(on-demand side-car: /setup-worktree  →  isolated checkout for human review)
```
