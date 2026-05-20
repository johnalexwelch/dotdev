# Outage Risk Policy

Load this before building or dispatching an AFK backlog queue.

## Hard Exclusions

Do not dispatch these categories in unattended AFK mode. Mark `needs-human` unless the user explicitly approves that issue and provides a rollback plan:

- database migrations, schema rewrites, or destructive data changes
- auth, permissions, security boundaries, privacy, secrets, or payment flows
- production infrastructure, Terraform, Kubernetes, CI/CD deploy logic, feature flag defaults, or environment config
- broad data backfills, queue/job behavior changes, cache invalidation, or retry semantics
- changes that require force-push, rebase, destructive git, manual production actions, or external vendor coordination
- issues without clear acceptance criteria, verification commands, or a rollback path
- changes touching more than 15 files or more than 500 lines unless they are generated/format-only and explicitly reviewed

## Conditional AFK

These can run AFK only when the issue states the risk control:

- frontend/user-facing work: requires `user-journey-qa` PASS or explicit user waiver
- public API or persisted data behavior: requires compatibility notes and tests
- performance-sensitive code: requires baseline and post-change measurement
- background jobs or async state: requires idempotency/retry tests
- dependency changes: requires dependency/supply-chain review lane

## Required Queue Fields

Each queued issue must include:

- issue number and title
- priority
- dependency status
- AFK/HITL classification
- outage-risk classification: `low`, `medium`, `high`, or `excluded`
- verification command(s)
- rollback expectation
- reason it is safe for unattended execution

## Dispatch Rules

- Dispatch only `low` or explicitly approved `medium` risk items in AFK mode.
- Dispatch dependency chains sequentially, or use stacked development only when the parent PR has complete clean gates and the child PR targets the parent branch.
- Never dispatch issues that modify the same files or modules in parallel.
- Use a fresh `origin/staging` worktree per root issue. Stacked dependent issues must use a fresh worktree from the clean parent branch and record `STACKED_WORKTREE_GATE`.
- Require `WORKTREE_BASELINE_GATE`, `WORKFLOW_REVIEW_GATE`, and `WORKFLOW_FINALIZE_GATE` before marking any item successful.

## Halt Rules

Halt the issue and mark `needs-human` on:

- missing gate evidence
- missing rollback plan for non-low-risk work
- CI failure outside bounded auto-fix classes
- review finding requiring product/security judgment
- unresolved reviewer comment
- test runner unavailable
- app URL or Playwright unavailable for triggered user-journey QA
