# Phase Design Rules

Use these rules when drafting or revising §5 Execution plan.

## Delegation Markers

Every task in §5 carries exactly one marker:

- `[auto]` — Claude Code can do this autonomously without user input. Examples: file moves, renames, scoped refactors, test writing, deletions from the delete list.
- `[human]` — requires user judgment and should not be executed without confirmation. Examples: calendar or commitment decisions, scope changes, anything with financial impact, interactions with other people, anything touching escalation triggers in `CLAUDE.md`.

If a task is mixed, split it. No task should be half-auto, half-human.

If `[auto]` vs `[human]` is ambiguous, default to `[human]` and let the user
downgrade to `[auto]` on review.

## Phase Count Flexing

Phase count flexes with scope:

- Trivial bug fix: 1 phase total, fix + verify. The pilot/canary collapses into the fix.
- Small feature: 2-3 phases, pilot slice plus 1-2 follow-ups.
- Refactor-scale work: 4-6 phases. Do not compress below 4; do not exceed 6 without forcing a merge or deferring scope.

Do not pad a bug-fix plan with ceremonial phases. Do not hide multiple
verticals inside one refactor phase.

## Pilot / Canary

- §5.0 Phase 0 — Preflight is always present except for trivial bug-scale plans where preflight collapses into Phase 1.
- §5.1 Phase 1 is the Pilot/Canary for feature-scale and refactor-scale plans.
- The pilot is the smallest-possible end-to-end change that validates the approach against real data.
- The pilot comes before any deletion phase.
- The pilot is not optional for refactor-scale work unless the user explicitly waives it in `constraints` with reasoning recorded in §1.
- For brief-mode bug fixes, the fix itself is the pilot.
- If no canary is possible because the change is truly atomic, require explicit waiver in §1 with reasoning. Do not silently skip.

## Vertical Slicing

Prefer end-to-end slices over layer-by-layer phases.

- Phase 2 should not be "backend only" and Phase 3 "frontend only."
- Each phase should deliver a working vertical of the target system.
- The pilot is the first vertical; subsequent phases add features to it.
- If a plan is layer-sliced, flag and reorder it unless the user waived this in constraints.

## Required Phase Fields

Each phase must include:

- **Goal** — one sentence.
- **Tasks** — concrete tasks, each tagged `[auto]` or `[human]`.
- **Addresses** — IDs resolved by this phase: `FIND-NN` in audit-mode, `REQ-NN` or ticket slugs in brief-mode, or `n/a` for hygiene phases.
- **Verification** — falsifiable check that proves the phase is done.
- **Rollback** — recovery path if the phase fails or is backed out.
- **Deletes** — files removed in the phase, or "none."

## Delete List

§8 Delete list includes every file slated for deletion, grouped by phase. For
each file, state why it is deleted and what replaces it, or "no replacement —
dead code."

No file is deleted before its replacement is live and verified.

## Sync Gate

§11 Sync-gate mechanics specifies how phases interleave with git:

- Branch naming: `refactor/phase-N-<slug>`, `fix/phase-N-<slug>`, or `feat/phase-N-<slug>`.
- PR policy.
- "main clean before next phase" rule.
- What happens if a phase fails midway.

For solo projects, sync gate can be lighter: direct commits to main are fine as
long as tests pass. For teams, require PRs with review.

## Self-Review Checklist

Before surfacing the plan, fix any failure:

- Does every task in §5 have either `[auto]` or `[human]`?
- Does every phase have Verification and Rollback?
- Is Phase 1 a Pilot/Canary, or is there an explicit waiver in §1, or is this a brief-mode bug-fix plan where the fix itself is the pilot?
- Does every phase deliver a working vertical?
- Is the phase count appropriate for scope: 1 for bugs, 2-3 for small features, 4-6 for refactors?
- Does every phase's Addresses list reference specific IDs from the audit (`FIND-NN`) or brief (`REQ-NN`, ticket slugs), or note "hygiene" / `n/a` for Phase 0?
- Does §8 Delete list account for every file flagged as legacy or superseded?
- Does §10 Definition of done include the "every ID addressed or deferred" check?
- Are there `TODO` or "figure out later" placeholders in the body? If yes, move them to §9 Open questions with an owner.

## Core Loop Compatibility

The plan feeds into:

```text
/repo-audit     -> docs/audits/<date>-repo-audit.md
     ↓             (FIND-NN; optional because brief-mode skips this)
/design-plan    -> docs/plans/<date>[-<slug>]-design.md
     ↓             (audit-mode or brief-mode)
/execute-phase  -> docs/executions/.phase-runs/*.md +
     ↓             {refactor,fix,feat}/phase-<N>-<slug>
/workflow-review -> review synthesis with dispatch evidence
     ↓
/post-mortem    -> docs/executions/<date>-post-mortem.md
     ↓
/workflow-finalize -> describe-pr, draft PR, receive-review,
                      watch-ci, reconcile, draft handoff
     ↓
[human merge]
```

`/setup-worktree` is an on-demand side car when `/execute-phase` halts at a
`[human]` gate and the user wants an isolated checkout for resolution in
parallel with continued main-branch work.

All seven core skills share ID vocabulary (`FIND-NN`, `REQ-NN`, `NEW-NN`,
ticket slugs, phase numbers) and directory conventions under `docs/audits/`,
`docs/plans/`, and `docs/executions/`. A post-mortem without a plan has
nothing to compare against. `/execute-phase` without a plan has nothing to
execute. `/repo-audit` is the refactor-scale entrypoint; brief-mode
`/design-plan` is the bug/feature entrypoint and skips the audit.
