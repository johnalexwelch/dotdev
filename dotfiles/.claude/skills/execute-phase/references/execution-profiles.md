# Execution Profiles

Profiles control how code is written during execution. They do not
change phase structure, scope discipline, or verification gates.

| Profile | Behavior | When to use |
|---------|----------|-------------|
| **normal** | Standard development: clean code, reasonable tests, good commit messages. | Default for most work. |
| **caveman** | Simplest boring implementation. No abstractions, cleverness, or premature optimization. | Speed-first work, prototypes, or when the user says "just make it work". |
| **strict-tdd** | Every behavior change starts with a failing test. No implementation without a test. Red-green-refactor is enforced. | Bug fixes, behavior-critical features, or explicit TDD requests. |
| **prototype** | Throwaway code. No tests, docs, or polish. Prove the concept and discard. Mark code with `// PROTOTYPE - do not merge`. | Spikes, feasibility checks, demos. |
| **safe** | Smaller commits, more verification, conservative changes, and independently revertable steps. | Production-critical code, unfamiliar codebases, high-risk changes. |

## Profile Selection

Select profiles in this priority order:

1. Explicit user request, such as "use strict-tdd" or "caveman this".
2. Workflow context, such as `workflow-debug` requiring strict TDD for
   the fix step.
3. Issue labels, where `prototype` or `spike` select prototype mode.
4. Default: normal.

## Tuning Notes

- **Parallel vs. serial cluster dispatch:** parallelize clusters only
  when scopes are truly disjoint. Serialize when scopes overlap or a
  later cluster depends on an earlier cluster's output. In doubt,
  serialize.
- **Scope granularity:** grant exact paths where possible. Wide scopes
  hide violations.
- **Evidence commands:** prefer absolute-path command invocations when
  output is load-bearing evidence.
- **Worktree baseline:** live `/execute-phase` runs must start in an
  isolated worktree cut from `origin/staging`. If a phase halts at a
  `[human]` gate, continue resolving inside that worktree or use
  `/setup-worktree phase=<N>` to create a new origin/staging-based
  worktree.
- **`dry_run`:** run it before real phase execution when a plan is
  freshly written. It confirms parsing, Verification extraction, and
  outcome-file shape without branch creation, commits, or mutating
  subagents.

## Pairing With The Core Loop

```text
/repo-audit     -> docs/audits/<date>-repo-audit.md          (FIND-NN; optional)
     |
/design-plan    -> docs/plans/<date>[-<slug>]-design.md      ([auto]/[human]; audit or brief mode)
     |
/execute-phase  -> docs/executions/.phase-runs/<*>.md        (this skill)
     |             {refactor,fix,feat}/phase-<N>-<slug>
/workflow-review -> review synthesis with dispatch evidence  (fresh reviewer subagents)
     |
/post-mortem    -> docs/executions/<date>-post-mortem.md     (NEW-NN, drift)
     |
/workflow-finalize -> describe-pr, draft PR, receive-review,
                      watch-ci, reconcile, draft handoff
     |
[human merge]
```

On-demand sidecar: `/setup-worktree` creates an isolated checkout for
human review or gate resolution.

## Provenance

Ported from `~/Desktop/skills/implement-plan/SKILL.md`.

Dropped:

- `implementer-agent` subagent type, replaced by `general-purpose`.
- Ticket slugs and `.humanlayer/tasks/` paths as primary plan storage,
  replaced by `docs/plans/` and phase references.
- Inline reference templates, now bundled under `references/`.

Kept:

- No Claude attribution in commit messages. Commits use only the phase
  schema.

Added:

- Branch creation.
- Stacked auto-proceed.
- Scope-based parallel subagent isolation.
- Post-batch scope verification.
- Separate verification subagent per phase.
- `.phase-runs/` outcome file schema.
- `FIND-NN`/`REQ-NN`/`GAP-NN`/ticket-aware commits.
- `plan_slug` filename disambiguation.
