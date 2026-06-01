---
name: to-issues
description: Break a plan, spec, or PRD into independently-grabbable issues on the project issue tracker using tracer-bullet vertical slices. Use when user wants to convert a plan into issues, create implementation tickets, or break down work into issues.
---

## Contract

Consumes: plan, spec, PRD, decision log, or conversation context (may include issue reference)
Produces: GitHub issues as independently-grabbable vertical slices
Requires: gh
Side effects: creates issues on the project issue tracker
Human gates: slice breakdown presented for approval before publishing

## Context

Typical workflows: planning-to-execution (after /design-plan or /to-prd)
Pairs well with: decision-log, design-plan, to-prd, triage, setup-skills

# To Issues

Break a plan into independently-grabbable issues using vertical slices (tracer bullets).

This is a hard constraint: implementation issues must be vertical slices of app behavior, not horizontal layers. Reject or rewrite issue breakdowns that produce separate tickets for only schema, only backend routes, only UI shell, only tests, or only refactoring unless that ticket is a complete, independently verifiable behavior slice.

The issue tracker and triage label vocabulary should have been provided to you — run `/setup-skills` if not.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes an issue reference (issue number, URL, or path) as an argument, fetch it from the issue tracker and read its full body and comments. Read `docs/decision-log.md` or the repo's established equivalent when present so issue slices preserve why decisions were made.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Issue titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

### 3. Draft vertical slices

Break the plan into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be 'HITL' or 'AFK'. HITL slices require human interaction, such as an architectural decision or a design review. AFK slices can be implemented to a green draft PR without human interaction, but agents must not mark PRs ready, merge, enable auto-merge, or bypass review/finalization gates. Prefer AFK over HITL only when acceptance criteria, verification, dependencies, and outage risk are clear.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
- Horizontal work belongs inside a slice as implementation detail; it should not become its own issue unless it has standalone user-visible or system-verifiable behavior
</vertical-slice-rules>

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories this addresses (if the source material has them)
- **Outage risk**: low / medium / high / excluded
- **Verification**: required commands or user-journey QA
- **Module grill**: completed / not applicable / needed before publish
- **Decision log**: relevant entries linked / not applicable / missing

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?
- Are the correct slices marked as HITL and AFK?
- Are outage-risk classifications and rollback expectations correct?
- For module work, did the module grill answer the interface, seam, adapter, migration, and testing questions deeply enough?
- Are the relevant decision-log entries present so implementation agents can see alternatives and accepted tradeoffs?
- Are any proposed issues horizontal layer work? If yes, rewrite them before publishing.

Iterate until the user approves the breakdown.

### 5. Publish the issues to the issue tracker

For each approved slice, publish a new issue to the issue tracker. Use the issue body template below. Only apply `ready-for-agent` to AFK slices with clear acceptance criteria, dependencies satisfied or explicitly ordered, verification commands, rollback expectation, `low` or explicitly approved `medium` outage risk, and completed module grill evidence when the slice came from a module PRD. Publish HITL, high-risk, excluded, blocked, unclear, unverifiable, or ungrilled module slices with `needs-human` or `blocked` instead.

Publish issues in dependency order (blockers first) so you can reference real issue identifiers in the "Blocked by" field.

<issue-template>
## Parent

A reference to the parent issue on the issue tracker (if the source was an existing issue, otherwise omit this section).

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

Avoid specific file paths or code snippets — they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it here and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## AFK execution policy

- Type: AFK or HITL
- Outage risk: low, medium, high, or excluded
- Rollback expectation:
- Required verification:
- Module grill evidence: completed / not applicable, with link or summary
- Decision log: relevant entries linked / not applicable
- User-journey QA: required / not applicable, with reason
- Worktree policy: this issue must create its own fresh worktree from `origin/staging` before implementation starts and report `WORKTREE_BASELINE_GATE: origin/staging -> <branch> @ <worktree-path>`
- Review/finalize policy: PR handoff requires `WORKFLOW_REVIEW_GATE` with `review_profile`, `independent_review: true`, and `verdict: APPROVE`, plus a complete `WORKFLOW_FINALIZE_GATE`

## Blocked by

- A reference to the blocking ticket (if any)

Or "None - can start immediately" if no blockers.

</issue-template>

Do NOT close or modify any parent issue.
