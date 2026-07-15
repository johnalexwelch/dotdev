# Repository Delivery Policy

Load this before building or dispatching an AFK backlog queue.

## Policy

`run-backlog` supports two delivery modes:

| Mode | Repos | Allowed Final Action |
|------|-------|----------------------|
| `human-only` | Repositories listed under Protected Repositories below | Leave PRs draft or existing non-draft, do not mark ready, do not merge, do not enable auto-merge |
| `auto-merge-eligible` | All other repositories | After all required gates pass, mark PRs ready and enable GitHub auto-merge |

## Protected Repositories

Add repositories here as `owner/name` entries when they must remain human-release-only:

```text
# owner/repo
classdojo/astronomer
classdojo/iris
```

## Rules

- Resolve the current repository with `gh repo view --json nameWithOwner` before dispatch.
- If the repository matches a Protected Repositories entry, set `repo_delivery_policy: human-only`.
- If the repository does not match a Protected Repositories entry, set `repo_delivery_policy: auto-merge-eligible`.
- Unknown repository identity is a halt condition. Do not guess.
- Auto-merge eligibility does not bypass `references/outage-risk-policy.md`, `WORKTREE_BASELINE_GATE`, `WORKFLOW_REVIEW_GATE`, `WORKFLOW_FINALIZE_GATE`, CI, review-comment resolution, issue reconciliation, verification, or the Partial-Completion Contract.
- Auto-merge-eligible runs may mark PRs ready and enable GitHub auto-merge only after the finalization gate is complete and green.
- Auto-merge-eligible runs must prefer GitHub auto-merge over direct immediate merge. Direct merge is allowed only when the repo requires it and the user explicitly requested direct merge for that run.
- Human-only repos must never mark ready, approve, merge, enable auto-merge, force-push, rebase, or perform destructive git in an AFK run.
