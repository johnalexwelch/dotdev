---
name: design-plan
description: Use when turning a repo-audit report, refactor-scale brief, migration, or existing plan revision into an executable phased plan with FIND-NN/REQ-NN anchors, [auto]/[human] tasks, pilot/canary coverage, rollback, and sync gates. Do not use as the default feature workflow; use grill-with-docs → decision-log → to-prd → to-issues → triage for product work.
triggers:
  - "write a design doc"
  - "create a refactor plan"
  - "turn this audit into a plan"
  - "revise the plan"
  - "/design-plan"
persona: Staff Engineer writing a plan a fresh contributor could execute
inputs:
  - name: mode
    type: string
    default: "draft"
    description: '"draft" to create a new plan from an audit or brief. "revise" to update an existing plan with execution results, blocked phases, or new findings.'
  - name: audit_path
    type: string
    default: ""
    description: Path to a repo-audit report. If empty and `brief` is empty, use the newest `docs/audits/*-repo-audit.md`. Mutually exclusive with `brief`.
  - name: brief
    type: string
    default: ""
    description: 'Refactor-scale, migration, or investigation brief: inline string, `@path/to/file`, or URL. Mutually exclusive with `audit_path`. Product features should use the PRD/issues workflow instead.'
  - name: existing_plan
    type: string
    default: ""
    description: Path to existing plan. Required if mode=revise unless defaulting to newest `docs/plans/*.md`.
  - name: outcome
    type: string
    default: ""
    description: One sentence describing the target state. If empty, ask before drafting. In revise mode, use to clarify outcome drift.
  - name: constraints
    type: string
    default: ""
    description: 'Free-text constraints: solo vs. team, deadlines, API budgets, production risk tolerance, rollback tolerance.'
  - name: output_path
    type: string
    default: "docs/plans/<date>[-<slug>]-design.md"
    description: Where to write the plan. Slug derives from a ticket ID, brief first sentence, or scoped audit path-slug unless overridden.
reads:
  - docs/audits/<date>-repo-audit.md (newest unless audit_path is set; skipped in brief-mode)
  - docs/plans/<prior>.md (if mode=revise)
  - <brief content> (if brief is a file path or URL)
  - README.md, CLAUDE.md, any *_SPEC.md at repo root
writes:
  - docs/plans/<date>[-<slug>]-design.md (or override via output_path)
---

# /design-plan

## Effort

**Think hard** before drafting — this is planning work, and reasoning depth here prevents expensive rework downstream. Run on the strongest available session model.


## Purpose

Turn a `/repo-audit` report or refactor-scale brief into an executable plan a
fresh contributor can run: ordered phases with `FIND-NN` / `REQ-NN` / ticket
anchors, `[auto]` and `[human]` task markers, pilot/canary coverage when scope
warrants it, per-phase rollback, a delete list, sync-gate mechanics, and a
falsifiable definition of done.

This is the specialized phase-plan lane inside the current workflow. It is
for repo-wide refactors, migrations, and complex remediation where issue
slices are not enough yet. For normal product/feature work, route through
`grill-with-docs → decision-log → to-prd → to-issues → triage` instead.

Every development phase must be a vertical slice of app behavior. Do not create horizontal phases such as "database layer," "API layer," "frontend shell," "tests," or "cleanup" unless each phase still delivers independently verifiable end-to-end behavior.

Runs in `draft` mode for new plans and `revise` mode for evidence-checked
updates to an existing plan.

## Contract

Consumes: repo audit report or refactor-scale brief, decision log, target outcome, constraints
Produces: phased execution plan in `docs/plans/`
Requires: git
Side effects: writes or revises one plan file
Human gates: plan review before execution; outcome and constraints questions if not provided

## Load References

Load only the references needed for the invocation:

- Audit-mode draft: `references/audit-mode.md`, `references/phase-design-rules.md`, `references/rollback-examples.md`, and `references/plan-template.md`.
- Brief-mode draft: `references/brief-mode.md`, `references/phase-design-rules.md`, `references/rollback-examples.md`, and `references/plan-template.md`.
- Revision mode: `references/revision-mode.md`, `references/phase-design-rules.md`, `references/rollback-examples.md`, and `references/plan-template.md`.

## Core Flow

1. Confirm the workspace is a git repo. If not, abort.
2. Resolve mode and input source:
   - `mode=revise`: use revision mode and locate `existing_plan` or newest `docs/plans/*.md`.
   - `audit_path` set: use audit-mode and anchor §5 Addresses on `FIND-NN`.
   - `brief` set: use brief-mode and anchor §5 Addresses on `REQ-NN` or ticket slugs.
   - neither set: use newest `docs/audits/*-repo-audit.md`; if none exists, stop and ask for `/repo-audit` or `brief="..."`.
3. Abort if `audit_path` and `brief` are both set.
4. Read `README.md`, `CLAUDE.md`, root `*_SPEC.md` files, and `docs/decision-log.md` if present for conventions and settled rationale.
5. Ask at most two batched questions if missing:
   - Outcome: what does done look like?
   - Constraints: solo/team, deadlines, budget, production risk, rollback tolerance.
6. Draft or revise the plan using the relevant mode reference and `plan-template.md`.
7. Apply `phase-design-rules.md`: phase count flexes with scope, pilot/canary precedes risky work, every phase has a vertical slice, every task is `[auto]` or `[human]`, every phase has Addresses, Verification, Rollback, and Deletes.
8. Use `rollback-examples.md` to make rollback specific.
9. Self-review before surfacing: no missing markers, no missing rollback, correct `FIND-NN` / `REQ-NN` / ticket anchors, no inappropriate phase padding or compression, no unresolved placeholders outside §9 Open questions.
10. Surface only the summary, phase list with `[auto]`/`[human]` counts, open questions, and the plan path. Do not paste the full plan inline.

## Required Behaviors

- Preserve stable ID vocabulary: `FIND-NN`, `REQ-NN`, `NEW-NN`, ticket slugs, and phase numbers.
- Brief-mode is only for refactor-scale or migration briefs. Product features should use `workflow-feature`/`to-prd`/`to-issues`.
- Audit-mode is the refactor-scale evidence path after `repo-audit`.
- Phase count flexes with scope: 1 phase for bugs, 2-3 for small features, 4-6 for refactors.
- Each phase must name the vertical behavior it makes real and the layers it crosses. Rewrite horizontal layer phases before presenting the plan.
- Pilot/canary is required for feature/refactor plans unless explicitly waived with reasoning; for bug fixes, the fix itself is the pilot.
- Canary comes before deletion.
- No file is deleted before its replacement is live and verified.
- If `[auto]` vs `[human]` is ambiguous, default to `[human]`.
- In revise mode, verify claims against git, branches, tests, or working-tree evidence before changing the plan.
- Treat decision-log entries as settled rationale. Reference relevant entry titles when a plan choice would otherwise look arbitrary, and reopen a logged decision only when new evidence changes its accepted tradeoffs.
