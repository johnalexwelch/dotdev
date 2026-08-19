---
name: to-prd
layer: orchestrator
model: sonnet
reasoning: high
description: Turn the current conversation context into a PRD and publish it to the project issue tracker. Use when user wants to create a PRD from the current context. Also owns migration mode — turning a repo-audit report or refactor/migration brief into a phased PRD (FIND-NN/REQ-NN anchors, parent + ordered children executed by execute-prd); successor to design-plan (D-006 planning-lane consolidation, 2026-08-19).
---

## Contract

Consumes: conversation context, codebase understanding, grilling output, decision log; repo-audit report or refactor/migration brief (migration mode)
Produces: PRD issue on the project issue tracker
Requires: gh
Side effects: creates issue on the project issue tracker
Human gates: module breakdown confirmed with user; PRD published as spec/reference only; implementation readiness is decided by child issues from to-issues

## Context

Typical workflows: feature ideation (after /grill-with-docs, before /to-issues)
Pairs well with: decision-log, grill-with-docs, domain-modeling, to-issues, triage

This skill takes the current conversation context and codebase understanding and produces a PRD. Do NOT interview the user — just synthesize what you already know.

## Mode selection

Input shape picks the mode:

- **Product mode** (default; the process and template below, unchanged): conversation context or a product brief → feature PRD.
- **Migration mode**: the input is a repo-audit report (`docs/audits/*-repo-audit.md`) or a refactor/migration/already-decided governance brief — scope is settled, discovery is done. Apply the deltas in `## Migration mode` on top of the product-mode process. Successor to the retired `design-plan` → `execute-phase` lane (D-006 planning-lane consolidation, 2026-08-19).

The issue tracker and triage label vocabulary should have been provided to you — run `/setup-skills` if not.

Every development path described by the PRD must be decomposable into vertical slices of app behavior. Do not structure the PRD around horizontal layer work such as "database first," "API first," "frontend later," or "tests at the end." Horizontal work can appear only as implementation detail inside a vertical slice.

## Process

0. Roadmap gate (required):

Before synthesizing the PRD, verify there is an approved roadmap artifact for this workstream (normally from `workflow-roadmap`) with milestone sequencing and vertical-slice intent.

Required evidence:

- roadmap artifact path (typically `docs/roadmaps/YYYY-MM-DD-<topic>-roadmap.md`)
- explicit user approval (or explicit user waiver)
- at least one milestone that maps to this PRD scope

If missing, stale, or out of scope, halt and route back to `workflow-roadmap` before continuing. **Migration mode:** this gate is satisfied differently — see `## Migration mode`; the user-approved repo-audit report or migration brief stands in for the roadmap artifact, and no `workflow-roadmap` detour is forced.

0.5. Graphify knowledge graph gate (conditional, before codebase exploration):

Before exploring the repo, check for an existing knowledge graph. If `graphify-out/graph.json` exists, run one focused `graphify query` for PRD scope context (what modules/domains does this PRD touch, what are the current dependencies?) and include the result in your codebase understanding. Record `graphify: queried` in your response. If no graph exists, record `graphify: not_available_with_reason: <reason>` (e.g. `not_yet_generated`). Do not rebuild the graph — that is explicit `/graphify` work. If you are uncertain whether the graph covers the scope, include it anyway and note any gaps in your exploration output.

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the PRD, and respect any decision log entries and ADRs in the area you're touching.

Before synthesizing the PRD, read `docs/decision-log.md` or the repo's established equivalent if it exists. Treat logged decisions as settled context unless the user explicitly reopens them. If the PRD relies on grill output that has not been logged, reconstruct decision-log entries for the accepted answers before continuing.

2. Sketch out the major modules you will need to build or modify to complete the implementation. Actively look for opportunities to extract deep modules that can be tested in isolation, but keep the delivery plan vertical: each implementation issue must produce a narrow end-to-end behavior, not a layer-only milestone.

A deep module (as opposed to a shallow module) is one which encapsulates a lot of functionality in a simple, testable interface which rarely changes.

For autonomous module discovery, every proposed module must include: responsibility, current pain/evidence, public interface shape, non-goals, migration plan, verification plan, rollout risk, and rollback expectation.

Autonomous module PRD preflight: if this PRD comes from `workflow-autonomous-backlog` or an autonomous module candidate, halt unless the context includes:

- `improve-codebase-architecture` candidate evidence
- `/grill-with-docs` module grill output
- `MODULE_GRILL_CONSENSUS` with `CRITIC_APPROVE`, or `NEEDS_HUMAN` explicitly resolved by the user
- recommended answers accepted, overridden, or marked needs-human
- scoped second-pass decision: `second_pass: not_needed`, `second_pass: run`, or `second_pass: needs_human`
- explicit module design approval evidence
- rollback and verification decisions

Critic consensus is evidence validation only. Do not treat `MODULE_GRILL_CONSENSUS` as module design approval unless the same invocation includes explicit human approval or explicit low-risk autonomous preauthorization.

Check with the user that these modules match their expectations. Check with the user which modules they want tests written for. For new modules, broad architecture moves, product behavior changes, public API changes, data model changes, auth/payment paths, or high-risk refactors, this confirmation is a hard module design summary gate.

2b. Independent slice coverage review (required after module confirmation, before writing PRD):

After the user confirms the module breakdown, spawn an independent critic agent (`oh-my-claudecode:critic`) to verify the proposed modules decompose into clean vertical slices before you commit the full PRD to writing.

Brief the critic with:

- The confirmed module breakdown and user stories
- The relevant decision log sections
- Enough codebase context to spot phantom dependencies or missing integration seams

The critic must check:

1. **Vertical decomposability** — can each module be delivered as narrow end-to-end behavior, or does any module require another to be "done first" for a reason that isn't a real data dependency?
2. **Horizontal-layer disguise** — are any proposed modules secretly horizontal (e.g., "build the schema," "build the API," "build the UI" as separate modules)?
3. **Dependency ordering** — are module dependencies correctly ordered so slices can be independently implemented?
4. **User story coverage** — does the module set cover all identified user stories? are any behaviors orphaned (no module owns them)?
5. **Missing seams** — are there integration points (registration in a task registry, enum members, migration of existing records) that no module accounts for?

Address all **MAJOR** concerns before writing the PRD. Surface **MINOR** concerns and **QUESTIONs** in the PRD's Implementation Decisions or Further Notes sections so downstream implementers can see them.

2c. ADR promotion scan (required before writing PRD):

Scan every entry in the proposed Implementation Decisions against the three ADR criteria:

1. **Hard to reverse** — the cost of changing this decision later is meaningful
2. **Surprising without context** — a future reader will wonder “why did they do it this way?”
3. **Real trade-off** — there were genuine alternatives and one was chosen for specific reasons

For any decision that satisfies all three: either write the ADR now (using the format in `docs/adr/`) or surface it to the user with the three criteria scored so they can decide. Do not embed it only in the PRD and move on — Implementation Decisions sections get lost when the PRD is done. Decisions that do not satisfy all three criteria stay in the PRD as-is.

3. Write the PRD using the template below, then publish it to the project issue tracker as a PRD/spec/reference issue. Do not apply `ready-for-agent` to the PRD itself: PRD/spec parent issues are not implementation issues and must not be labeled `ready-for-agent` (per `triage` skill). Only child implementation issues produced by `to-issues` may receive `ready-for-agent`, and only after triage confirms all readiness criteria are met.

<prd-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. Include decision-log entry titles or ADR references where they explain why a path was chosen. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions
- Outage-risk classification and rollback expectations
- Alternatives considered and tradeoffs accepted when no separate decision-log entry exists
- Vertical slice boundaries: the first end-to-end behavior, layers it crosses, and horizontal work explicitly deferred

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## AFK Readiness

State whether this PRD can produce AFK-safe issues. Include required verification commands, expected `user-journey-qa` coverage when applicable, and the implementation policy that all code work resolves `WORKFLOW_BASE_GATE`, then starts from a fresh workflow-base worktree with `WORKTREE_BASELINE_GATE` evidence.

State explicitly that child implementation issues must be vertical slices. If the work cannot yet be sliced vertically, mark the PRD as needing more design before issue creation.

## Out of Scope

A description of the things that are out of scope for this PRD.

## Further Notes

Any further notes about the feature.

</prd-template>

## Migration mode

Deltas on the product-mode process for refactor-scale work. The PRD template is the same; these change how it is filled and how children are cut.

- **Roadmap gate**: satisfied by the **user-approved** repo-audit report or migration brief itself — approval of the input artifact is required in both variants (an agent's own unapproved audit output does not self-satisfy the gate); the scope is already decided, so no `workflow-roadmap` detour is forced. Mirrored as the in-rule exception in `workflow-router`'s Roadmap Gate Rule.
- **Anchors**: preserve `FIND-NN` / `REQ-NN` / ticket IDs verbatim from the audit or brief — never renumber. Implementation Decisions maps anchors → slices; every child issue cut by `to-issues` must cite the anchors it addresses.
- **Phasing is issue ordering, not a phase runner**: sequencing lives as one parent PRD issue plus ordered child issues with explicit dependencies ("blocked by #N"). The tree is executed by `execute-prd`; there is no separate phase executor.
- **Pilot/canary slice**: the first child proves the migration pattern on the narrowest real surface. Canary precedes any deletion; no file or behavior is deleted before its replacement is live and verified. Waiving the pilot requires stated reasoning in Implementation Decisions.
- **Rollback expectation**: every child states its rollback (revert unit or recovery path); the PRD carries the overall rollback posture in Implementation Decisions.
- **Sync gates are child issues**: human-only checkpoints (approvals, production verification, credential/custody actions) become explicit child issues marked for a human and ordered in the dependency chain — never silent assumptions inside an agent-executable slice. `execute-prd` skips a human gate and everything blocked behind it, so the parent tree needs a re-invocation after each gate clears; one run is not the whole migration.
- **User stories**: the extensive-actor bar relaxes to affected-behavior coverage — enumerate the behaviors that must not regress.
