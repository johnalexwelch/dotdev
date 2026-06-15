---
name: to-prd
model: sonnet
reasoning: high
description: Turn the current conversation context into a PRD and publish it to the project issue tracker. Use when user wants to create a PRD from the current context.
---

## Contract

Consumes: conversation context, codebase understanding, grilling output, decision log
Produces: PRD issue on the project issue tracker
Requires: gh
Side effects: creates issue on the project issue tracker
Human gates: module breakdown confirmed with user; PRD published as spec/reference only; implementation readiness is decided by child issues from to-issues

## Context

Typical workflows: feature ideation (after /grill-with-docs, before /to-issues)
Pairs well with: decision-log, grill-with-docs, to-issues, triage

This skill takes the current conversation context and codebase understanding and produces a PRD. Do NOT interview the user — just synthesize what you already know.

The issue tracker and triage label vocabulary should have been provided to you — run `/setup-skills` if not.

Every development path described by the PRD must be decomposable into vertical slices of app behavior. Do not structure the PRD around horizontal layer work such as "database first," "API first," "frontend later," or "tests at the end." Horizontal work can appear only as implementation detail inside a vertical slice.

## Process

0. Roadmap gate (required):

Before synthesizing the PRD, verify there is an approved roadmap artifact for this workstream (normally from `workflow-roadmap`) with milestone sequencing and vertical-slice intent.

Required evidence:
- roadmap artifact path (typically `docs/roadmaps/YYYY-MM-DD-<topic>-roadmap.md`)
- explicit user approval (or explicit user waiver)
- at least one milestone that maps to this PRD scope

If missing, stale, or out of scope, halt and route back to `workflow-roadmap` before continuing.

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

3. Write the PRD using the template below, then publish it to the project issue tracker as a PRD/spec/reference issue. Do not apply `ready-for-agent` to the PRD itself. Only child implementation issues produced by `to-issues` may receive `ready-for-agent`, and only after triage confirms AFK safety.

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

State whether this PRD can produce AFK-safe issues. Include required verification commands, expected `user-journey-qa` coverage when applicable, and the implementation policy that all code work starts from a fresh `origin/staging` worktree with `WORKTREE_BASELINE_GATE` evidence.

State explicitly that child implementation issues must be vertical slices. If the work cannot yet be sliced vertically, mark the PRD as needing more design before issue creation.

## Out of Scope

A description of the things that are out of scope for this PRD.

## Further Notes

Any further notes about the feature.

</prd-template>
