# Revision Mode Reference

Use revision-mode when `mode=revise`, when the user says "update the plan" or
"iterate on the plan," when a post-mortem references plan gaps, when execution
feedback suggests plan revision, or when a plan file already exists and the
user invokes design-plan again.

Revision-mode produces a targeted revision, not a rewrite.

## Input Resolution

- `existing_plan` is required for revise mode unless a newest `docs/plans/*.md` exists.
- If `existing_plan` is set, use it.
- Otherwise use the newest `docs/plans/*.md`.
- If no plan exists, abort and suggest draft mode.
- Locate the audit or brief source the plan was based on when possible.

## Evidence Gathering

Gather:

- The existing plan's phases, delete list, and definition of done.
- Git log since the plan was written: `git log --oneline <plan-commit>..HEAD`.
- Which phase branches exist: `git branch -a | grep -E '(refactor|fix|feat)/phase-'`.
- Current test status: run the test command and note pass/fail.
- Any new audit findings discovered since the plan. Re-run `/repo-audit` if the existing audit is older than 14 days, or note staleness.

## Verify Before Accepting Revisions

When the user reports a phase drifted or a task should change, treat the claim
as a hypothesis. Spot-check against git (`git log`, `git branch`) and the
working tree before rewriting. If the claim does not reproduce, surface the
discrepancy rather than silently accepting it. This mirrors the
evidence-validation pass in `/repo-audit`.

## Revision Rules

- Read the existing plan file first.
- Identify what changed: new requirements, execution feedback, post-mortem findings, blocked phases, or new findings.
- Produce a diff of changes rather than regenerating from scratch.
- Preserve original phase numbering and structure.
- Preserve completed phases.
- Do not renumber findings or phases. Stable IDs matter more than clean numbering.
- Mark changed sections clearly.
- If the user heavily edited the first draft, do not regenerate; apply the edits and keep the rest. A plan the user has touched is more valuable than a plan that is optimally structured.

For each phase, annotate:

- **Status:** `done` | `in-progress` | `blocked` | `not-started` | `removed` | `added`
- **Actual vs. planned** — one line if drift occurred
- **Revised tasks** — only change what needs changing

Add `## §12 Revision log` at the bottom with date, reason for revision, and
what changed.

## Revision Self-Review

Before finishing, check:

- Does §12 exist and reflect what actually changed?
- Were claims checked against git, branches, tests, or the working tree?
- Are completed phases preserved?
- Are phase numbers and `FIND-NN` / `REQ-NN` / ticket slugs stable?
- Are revised tasks still tagged `[auto]` or `[human]`?
- Does every modified phase still have Verification, Rollback, Addresses, and Deletes?

## Revision Error Handling

| Failure | Behavior |
|---------|----------|
| Revise mode with no existing plan | Abort. Suggest draft mode. |
| Existing audit is older than 14 days | Note staleness and recommend re-running `/repo-audit`. |
| User-reported drift does not match git/working tree evidence | Surface the discrepancy instead of rewriting silently. |
| Tests currently fail | Record failure status in the revision; do not claim the plan is ready to execute until failures are understood. |

## Revise Example

```text
User: /design-plan mode=revise
Claude: [finds docs/plans/2026-04-20-design.md; finds phase branches
         refactor/phase-0-*, refactor/phase-1-*, refactor/phase-2-*
         merged; phase-3 branch exists but open]
        [test status: green]
        [annotates: Phase 0, 1, 2 done; Phase 3 in-progress;
         Phase 4-6 not-started]
        [§12 Revision log: Phase 3 scope expanded to include
         OAuth-refactor after FIND-05 was found more invasive
         than expected]
```
