# Examples And Workflow Context

Load this reference only when demonstrating expected behavior, checking edge cases, or explaining where `/watch-ci` fits in the larger delivery loop.

## Example: Clean PR

```text
User: /watch-ci pr_number=142
Claude: [preflight: gh auth ok, branch fix/phase-1-mobile-scroll, PR #142 valid]
        [poll: all checks pass, no failures]
        [security-review (OMC security-reviewer): clean]
        [no auto-fix commits -> skip /review on auto-fix]
        [monitor reviewer agents, no actionable comments remain]
        [post comment, Verdict: Draft ready for user review]
        [outcome: docs/executions/.ci-runs/2026-04-22-pr-142-attempt-1.md]

        PR #142 - draft ready: 0 auto-fix commits, security-review clean,
        /review on auto-fix N/A, reviewer feedback incorporated.
        https://github.com/myorg/myrepo/pull/142
        Draft PR ready for your review; you decide when to mark ready.
```

## Example: Auto-Fix Then Draft Handoff

```text
User: /watch-ci pr_number=143
Claude: [attempt 1: poll, lint failure detected (eslint, 4 rules)]
        [classify: lint - auto-fix eligible]
        [dispatch eslint --fix subagent, commits, push]
        [outcome: attempt 1 file written]

        [attempt 2: poll, type failure detected (tsc, 1 error in src/auth.ts:42)]
        [signature differs from attempt 1 - progress]
        [classify: type - auto-fix eligible]
        [dispatch type-fix subagent, commits, push]
        [outcome: attempt 2 file written]

        [attempt 3: poll, all checks pass]
        [security-review (OMC security-reviewer) on PR diff: clean]
        [/review on auto-fix diff (2 commits): clean]
        [monitor reviewer agents, address nits and observations]
        [post comment, Verdict: Draft ready for user review]

        PR #143 - draft ready: 2 auto-fix commits, security-review clean,
        /review on auto-fix clean, reviewer feedback incorporated.
```

## Example: Out-Of-Scope Test Logic

```text
User: /watch-ci pr_number=144
Claude: [attempt 1: poll, test failure detected]
        [classify: test-logic (multi-line failure, asserts on timing)]
        [out-of-scope - halt]
        [post comment, Verdict: Changes requested]
        [outcome: attempt 1 file with halt reason]

        PR #144 - halted (out-of-scope): test-logic failure in
        tests/scheduler.test.ts. Logs: <run URL>.
        See PR comment for human action.
```

## Example: Draft PR Auto-Creation

```text
User: /watch-ci
Claude: [preflight: branch feat/phase-1-dark-mode, no PR exists]
        [find body: docs/executions/.pr-bodies/2026-04-22-pr-feat-phase-1-dark-mode.md]
        [gh pr create --draft succeeded -> PR #145]
        [proceeds to Step 1 with pr_number=145]

        PR #145 created for branch feat/phase-1-dark-mode. Watching CI.
```

## Larger Delivery Loop

```text
/repo-audit (optional)
     |
/design-plan (audit OR brief mode)
     |
/execute-phase ({refactor,fix,feat}/phase-* branches)
     |
/workflow-review (risk-sized independent review evidence)
     |
/post-mortem (writes retro citing NEW-NN)
     |
/workflow-finalize (describe-pr, draft PR, receive-review, watch-ci,
                    reconcile, draft handoff)
/watch-ci
     |
[human merge]

(on-demand side-car: /setup-worktree -> isolated checkout for human review or halt resolution)
```

`/watch-ci` is the closing skill in the post-PR-open chain. `/post-mortem` later reads `.ci-runs/` outcome files alongside `.phase-runs/` to attribute post-PR discoveries, such as flaky tests, deferred security findings, or dependency pins, as `NEW-NN` candidates for the next `/repo-audit`.

The audit-loop skills share ID vocabulary: `FIND-NN`, `REQ-NN`, `NEW-NN`, ticket slugs, phase numbers, and `docs/` artifact conventions. `/watch-ci` writes to GitHub through PR comments and reviewer replies only; it never submits approval, marks ready, merges, or enables auto-merge.
