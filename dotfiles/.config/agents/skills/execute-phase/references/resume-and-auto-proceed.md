# Resume And Auto-Proceed

## Halt Reasons

Halt on any of:

- Verification FAIL.
- Load-bearing UNVERIFIED verification claim.
- Pending `[human]` task in phase N.
- Scope violation.
- Failed `[auto]` task.
- `auto_proceed == false`.
- Phase N+1 does not exist.
- Phase N+1 parse or preflight fails.

On halt, write the outcome file and surface full chain state to chat:
committed phase branches, current HEAD, blocker reason, and where to
continue. Leave the halted phase branch checked out so the user can
resolve in place or hand off to `/setup-worktree`.

## Resume Behavior

With `resume == true`, attempt to resume a halted chain from the failed
or blocked step. Look for an existing outcome file for the phase. If
the outcome file shows pending `[human]` tasks that are now resolved in
the plan or chat, continue from the next blocked step.

Resume requires a prior outcome file. If `resume == true` and no prior
outcome file exists, halt. A fresh invocation requires `resume=false`
and a normal preflight from a workflow-base worktree.

## Auto-Proceed

On successful commit and no pending `[human]` tasks:

- If `auto_proceed == false`, halt cleanly after writing the outcome.
- If Phase N+1 does not exist, halt with success: plan complete.
- Otherwise, recurse into preflight with `phase = N+1`.
- The next phase branches from the current HEAD only inside the
  workflow-base phase worktree, where current HEAD is now the
  phase N commit. Do not auto-proceed from the primary checkout.
- The next outcome file references the prior phase's outcome file in
  its `## Commits` section as branch ancestry.

Skip auto-proceed for phases with non-obvious downstream impact such as
database migrations or production-affecting configuration by passing
`auto_proceed=false`, even if the plan has no `[human]` task.

## User-Facing Summary

Print to chat:

- One-sentence phase summary:
  `Phase <N> - <goal> - <K> auto done, <M> human pending, verification PASS|FAIL, <commit-count> commits.`
- If halted, the specific blocker: verification failure, human task
  list, scope violation, failed auto task, or next-phase preflight
  error.
- Pointer to the outcome file:
  `See docs/executions/.phase-runs/<date>[-<slug>]-phase-<N>.md`.
- If auto-proceeding: `Chaining to Phase <N+1>.`
- If all phases are done: `Plan complete.`

## Examples

Clean auto-proceed through several phases:

```text
User: /execute-phase plan_path=docs/plans/2026-04-20-design.md phase=0 auto_proceed=true
Claude: [Phase 0: preflight clean, no [auto] changes, no commit, chain to 1]
        [Phase 1: pilot canary - 2 auto done, verification PASS,
         commit abc123, chain to 2]
        [Phase 2: skill scaffolding - 6 auto across 2 clusters
         (parallel), no scope violations, verification PASS,
         commit def456, chain to 3]
        [Phase 3: encounters [human] task - CHAIN HALTS]

        Phase 3 - Replace legacy scripts - 4 auto done,
        2 human pending, verification not run (blocked on human).
        3 commits landed: phase-0..phase-2. Phase 3 branch open.

        Pending human (2):
          1. Confirm launchd plist deprecation window.
          2. Approve the delete of scripts/daily-briefing.js
             (1,234 lines).

        Resolve and re-invoke:
          /execute-phase phase=3 auto_proceed=true
```

Phase that hits a human gate:

```text
User: /execute-phase plan_path=/tmp/my-plan.md phase=2
Claude: [preflight clean, branch refactor/phase-2-add-webhook created,
         1 [auto] cluster dispatched, scope verified,
         [human] task detected before verification - halt, no commit]

        Phase 2 - Add webhook endpoint - 1 auto done,
        1 human pending, verification not run (blocked on human),
        no commit created.

        Pending human (1):
          1. Decide whether to include retry-after header on 429 responses.

        Resolve and resume Phase 2 with:
          /execute-phase phase=2 resume=true
        Proceed to Phase 3 only after Phase 2 records PASS and no
        pending human gate.
```

## Downstream PR Assumptions

After plan completion, the downstream loop is:

```text
/workflow-review
/post-mortem
/workflow-finalize (describe-pr, draft PR, receive-review, watch-ci,
                    reconcile, draft handoff)
[human merge]
```

Do not assume automatic PR creation, automatic readiness for merge, or
auto-merge. PR creation is treated as draft/manual downstream unless
the user explicitly asks otherwise. `/watch-ci` may poll CI and apply
bounded auto-fixes, but human merge remains the terminal gate.
