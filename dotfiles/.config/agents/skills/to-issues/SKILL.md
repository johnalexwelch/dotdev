---
name: to-issues
layer: orchestrator
model: sonnet
reasoning: high
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
Pairs well with: decision-log, design-plan, to-prd, triage, setup-skills, implement

## References

- [Issue Dependency Audit](references/issue-dependency-audit.md)

# To Issues

Break a plan into independently-grabbable issues using vertical slices (tracer bullets).

This is a hard constraint: implementation issues must be vertical slices of app behavior, not horizontal layers. Reject or rewrite issue breakdowns that produce separate tickets for only schema, only backend routes, only UI shell, only tests, or only refactoring unless that ticket is a complete, independently verifiable behavior slice.

The issue tracker and triage label vocabulary should have been provided to you — run `/setup-skills` if not.

## Process

### 0. Roadmap gate (required)

Before drafting slices, verify there is an approved roadmap artifact covering this PRD/plan scope (normally from `workflow-roadmap`).

Required evidence:

- roadmap artifact path (typically `docs/roadmaps/YYYY-MM-DD-<topic>-roadmap.md`)
- explicit user approval (or explicit user waiver)
- milestone order that this issue breakdown can map to

If missing, stale, or not aligned to the current scope, halt and return to `workflow-roadmap` before publishing issues.

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes an issue reference (issue number, URL, or path) as an argument, fetch it from the issue tracker and read its full body and comments. Read `docs/decision-log.md` or the repo's established equivalent when present so issue slices preserve why decisions were made.

### 1.5. Graphify knowledge graph gate (conditional, before codebase exploration)

Before exploring the codebase, check for an existing knowledge graph. If `graphify-out/graph.json` exists, run one focused `graphify query` for slice-scope context (module boundaries, dependency structure relevant to the PR/plan scope) and incorporate it into your codebase understanding. Record `graphify: queried` in your response. If no graph exists, record `graphify: not_available_with_reason: <reason>` (e.g. `not_yet_generated`). Do not rebuild the graph — that is explicit `/graphify` work.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Issue titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

### 3. Draft vertical slices

Break the plan into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be `HITL` or `AFK`. HITL slices require human interaction before or during implementation, such as an architectural decision, external access, manual implementation, or a design decision that cannot be safely delegated. AFK slices can be implemented to a green draft PR without human interaction, but agents must not mark PRs ready, merge, enable auto-merge, or bypass review/finalization gates.

Distinguish **maintainer/operator gates** (types 1–3 in `_docs/human-gate-taxonomy.md`) from **reviewer validation** (type 4). Maintainer-gated slices require user/operator approval before merge; reviewer-validated slices do not block AFK when reviewers approve via `workflow-review`. Use `Maintainer/operator gate: required` for architectural, product, secret, or runtime decisions; use `Reviewer validation: required` when an agent may implement and validate but an independent non-authoring review must approve the PR before it can be considered complete. Reviewer-validation-only AFK issues must include `Reviewer validation steps`, but must not receive the `needs-human-review` label unless a separate maintainer/operator gate is also required.

Prefer AFK over HITL only when acceptance criteria, verification, dependencies, outage risk, and any required reviewer validation steps are clear.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
- Horizontal work belongs inside a slice as implementation detail; it should not become its own issue unless it has standalone user-visible or system-verifiable behavior
- **Issue titles must describe an observable outcome, not a layer or component.** “User sees config value after saving” is correct; “Config UI” or “Backend resolver” are not. Rewrite any title that names a layer before presenting to the user.
- **Tracer check for the first outcome slice:** after any prep/infrastructure slices, trace one representative value through every integration layer end-to-end (schema → service → API → UI → test). If the trace breaks — any layer is missing or unowned — resolve the gap before presenting the breakdown.
</vertical-slice-rules>

### 3b. Independent slice review (required before presenting to user)

Before presenting the breakdown to the user, spawn an independent critic agent (`oh-my-claudecode:critic`) to evaluate the proposed slices. Do this silently — do not show the draft to the user until the review is complete and MAJOR concerns are resolved.

Brief the critic with:

- The PRD or plan source, user stories, and the proposed slice breakdown
- The decision log sections relevant to this work
- The codebase context needed to spot phantom dependencies or missing seams

The critic must evaluate:

1. **Vertical integrity** — is each slice truly end-to-end, or is any slice a horizontal layer (schema-only, API-only, tests-only)?
2. **Dependency correctness** — is the chain right? are there hidden dependencies on unbuilt infrastructure?
3. **AFK/HITL classification** — are write-authority slices appropriately gated?
4. **Gate classification** — are maintainer/operator slices (types 1–3) marked HITL, and reviewer-validation-only slices (type 4) marked AFK with `Reviewer validation: required` instead of being mislabeled HITL? (See `_docs/human-gate-taxonomy.md`.)
5. **Coverage completeness** — do the slices collectively cover all user stories? are any behaviors (env-var degrades, exclusion rules, edge cases) missing from every slice?
6. **Scope vs. source** — does the breakdown cover the full PRD/plan scope, or is anything hanging?
7. **Risk guards** — for write-authority slices, are KILLSWITCH, dry-run, and rollback paths accounted for?

After the review:

- Address all **MAJOR** concerns by revising the breakdown before presenting to the user
- Surface **MINOR** concerns and **QUESTIONs** to the user as part of step 4 so they can decide
- If the review returns no MAJOR concerns, note the reviewer's LGTM items alongside the breakdown
- Load and apply `references/issue-dependency-audit.md` to classify dependencies, AFK/HITL status, human-review gates, and the recommended executor before showing the issue plan.

Do not skip this step. The independent reviewer catches phantom dependencies, missing coverage, and horizontal-layer disguised as slices that the author normalizes.

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories this addresses (if the source material has them)
- **Outage risk**: low / medium / high / excluded
- **Verification**: required commands or user-journey QA
- **Maintainer/operator gate**: required / not required
- **Reviewer validation**: required / not required
- **Module grill**: completed / not applicable / needed before publish
- **Decision log**: relevant entries linked / not applicable / missing

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?
- Are the correct slices marked as HITL and AFK?
- Are reviewer-validation-only slices marked AFK with `Reviewer validation: required`, not HITL? Are maintainer/operator gates clearly identified?
- Are outage-risk classifications and rollback expectations correct?
- For module work, did the module grill answer the interface, seam, adapter, migration, and testing questions deeply enough?
- Are the relevant decision-log entries present so implementation agents can see alternatives and accepted tradeoffs?
- Are any proposed issues horizontal layer work? If yes, rewrite them before publishing.

Iterate until the user approves the breakdown.

### 5. Publish the issues to the issue tracker

**Idempotency gate (required before any `gh issue create`).** Re-running a breakdown must not create duplicate issues. Before publishing, list existing issues once — `gh issue list --state all --limit 400 --json number,title,state` — and for each approved slice compare its title against that list:

- **Open match** → do not create; reuse the existing issue ID (update its body only if the slice materially changed).
- **Closed match** → do not silently recreate; surface it to the user (already delivered? needs reopen? genuinely new work needing a distinct title?) and let them decide.
- **No match** → create it.

This requires titles to be stable and unique per slice (the observable-outcome rule in step 3 already enforces this; prefix with the source's stable task/slice id such as `build-015:` when one exists). Report a dedup summary — created / reused / skipped-closed — in the publish output. This gate is why duplicate issue sets (e.g. two issues for the same `build-NNN:` slice) never reach the tracker.

For each approved slice that passes the idempotency gate, publish a new issue to the issue tracker. Use the issue body template below. Only apply `ready-for-agent` to vertical-slice issues that meet the triage `ready-for-agent` readiness criteria: clear acceptance criteria, dependency status, verification commands, rollback expectation, AFK/HITL classification, outage-risk classification, mandatory per-issue workflow-base worktree policy with `WORKFLOW_BASE_GATE` plus `WORKTREE_BASELINE_GATE`, review/finalize policy, `Human review: required|not required`, and any required module grill evidence (see `triage` skill for authoritative readiness checklist). If an AFK slice requires maintainer/operator approval (types 1–3 in `_docs/human-gate-taxonomy.md`), mark it `ready-for-human`, apply `needs-human-review` only when that is the tracker label for the maintainer/operator gate, and include the gate type. If an AFK slice requires reviewer validation only (type 4), keep it `ready-for-agent`, do not apply `needs-human-review`, and include `## Reviewer validation steps` for the independent review/validation pass. Publish HITL, high-risk, excluded, blocked, unclear, unverifiable, or ungrilled module slices with the human-implementation state label (`ready-for-human`, or the tracker-equivalent `needs-human`) or `blocked` instead.

Publish issues in dependency order (blockers first) so you can reference real issue identifiers in the "Blocked by" field.

After publishing real issue IDs, rerun `references/issue-dependency-audit.md` and include the final `ISSUE_DEPENDENCY_AUDIT` block in every issue body plus the publish summary. Use it to decide whether the child tree should go to `execute-prd`, independent issues should go to `run-backlog`, or any item should remain human/blocked.

<issue-template>
## Parent

A reference to the parent issue on the issue tracker (if the source was an existing issue, otherwise omit this section).

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

Avoid specific file paths or code snippets — they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it here and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

### User stories

The specific user stories from the PRD that this slice addresses (copy or reference by number).

### Research / documentation notes

*Optional. Include when this slice depends on external APIs, third-party specs, domain constraints, or prior art that implementers will need. Link or inline the key details so an agent can start without a separate research step. Omit when not applicable.*

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## AFK execution policy

- Type: AFK or HITL
- Maintainer/operator gate: required or not required (see `_docs/human-gate-taxonomy.md`)
- Reviewer validation: required or not required
- Outage risk: low, medium, high, or excluded
- Rollback expectation:
- Required verification:
- Module grill evidence: completed / not applicable, with link or summary
- Decision log: relevant entries linked / not applicable
- User-journey QA: required / not applicable, with reason
- Worktree policy: this issue must resolve `WORKFLOW_BASE_GATE`, create its own fresh worktree from the resolved workflow base before implementation starts, and report `WORKTREE_BASELINE_GATE: <workflow-base-ref> -> <branch> @ <worktree-path>`
- Review/finalize policy: PR handoff requires `WORKFLOW_REVIEW_GATE` with `review_profile`, `independent_review: true`, and `verdict: APPROVE`, plus a complete `WORKFLOW_FINALIZE_GATE`

## Reviewer validation steps

Required only when `Reviewer validation: required` (type 4 in `_docs/human-gate-taxonomy.md`). Provide concrete ordered checks an independent reviewer or validation agent can perform against the PR. Do not write vague steps such as "review the PR" or "verify it works"; tie each step to acceptance criteria, required verification, screenshots, deployed state, external access, migration review, or product judgment. If a step needs user/operator judgment, custody, or runtime authority, classify that as a separate maintainer/operator gate instead of hiding it under reviewer validation.

## Blocked by

- A reference to the blocking ticket (if any)

Or "None - can start immediately" if no blockers.

## Issue dependency audit

Include the slice's final `ISSUE_DEPENDENCY_AUDIT` entry after real issue IDs exist. Include `parent_issue`, `source_prd_or_plan`, `blocked_by`, `blocks`, `route_eligible`, and `recommended_executor` so future `run-backlog` or `execute-prd` sessions can read routing evidence from live issue bodies.

</issue-template>

Do NOT close or modify any parent issue.
