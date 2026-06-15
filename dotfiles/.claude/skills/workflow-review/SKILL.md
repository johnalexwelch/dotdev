---
name: workflow-review
model: opus
reasoning: high
description: Run an auditable independent review gate with a risk-sized review profile. Use before merging, after implementation, at any explicit review gate, or whenever the user asks to review changes; green CI, GitHub reviews, Claude Code Review, and PR comments do not substitute for this workflow.
---

# Workflow Review

## Model selection

Dispatch reviewer lanes on **Opus** (`model: opus`) — review is judgment work where the strongest model pays off. The `fast` integrated reviewer may use Sonnet for low-risk changes.

## Purpose

Run an independent review sized to the change's risk, then synthesize findings into a prioritized verdict. This replaces ad-hoc "review this" with an auditable gate, without forcing every small change through a full council. A valid review needs a *fresh independent reviewer context* — the author approving their own work, green CI, GitHub/Claude/Bugbot/Codex reviews, or resolved PR comments do **not** satisfy it unless this skill is loaded, reviewer lanes are dispatched, and a synthesis verdict is produced.

## Gate Invariant

If a workflow says `workflow-review`, run this skill before proceeding to finalize/PR/CI/merge/handoff. For code changes the review must run against a branch/worktree cut from `origin/staging` (or a valid stacked worktree). Without that baseline evidence, return `NEEDS HUMAN` rather than reviewing a local-main diff.

## Required Gate Block

Every valid run emits this block verbatim in the synthesis and any handoff that depends on it:

```markdown
WORKFLOW_REVIEW_GATE:
  worktree_baseline: origin/staging -> <branch> @ <worktree-path> OR stacked: origin/staging -> <parent> -> <child> @ <path>
  skill_loaded: true
  review_profile: fast|standard|full
  independent_review: true
  required_lanes:
    <lane>: dispatched|returned|not_applicable_with_reason
  conditional_lanes: <dispatched/skipped-with-reason list>
  dispatch_evidence: <reviewer context/subagent names/types and return status>
  verdict: APPROVE|REQUEST_CHANGES|NEEDS_HUMAN
```

If this block is absent, incomplete, self-reported without an independent reviewer context, or says anything other than `verdict: APPROVE`, parent workflows must treat the review as not run.

## Choose a profile (lightest that preserves independence; escalate when in doubt)

**Default to `fast`.** Most changes are low-risk; run the single integrated reviewer and stop. Escalate to `standard`/`full` only when the change hits a trigger in the table below (auth/data/infra/migrations, public APIs, dependency changes, broad refactors, concurrency, or large diffs >15 files/500 LOC). Don't escalate by reflex — an unjustified `full` review dispatches ~13 reviewer subagents for no added safety.

| Profile | Required lanes | Use when |
|---------|----------------|----------|
| `fast` | one fresh **Integrated Reviewer** (security+logic+tests+style+acceptance checklist) | small, low-risk: docs, tests, formatting, config-only, prompt/skill wording, narrow edits with deterministic tests and no public-behavior/data risk |
| `standard` | **Logic & Edge-Case** + **TDD/Test Coverage** for behavior changes; add **Security** for auth/secrets/permissions/user-data/dep/injection surfaces; add **Syntax/Style** when no linter ran | normal issue work, most production code |
| `full` | Security, Logic, Tests, Syntax/Style + triggered conditional lanes | auth/data/infra/migrations, public APIs, dep changes, broad refactors, concurrency, frontend UX, risky releases, large diffs (>15 files or >500 LOC) |

The full lane roster, subagent mapping, and the progress-ledger format live in `references/reviewer-roster.md` — load it when you need the catalog or are running `full`.

## Dispatch — independent context required

Use a fresh independent reviewer context, not an author-only checklist. Read the brief index `references/reviewer-briefs.md`, then read only the per-lane templates (`references/reviewer-briefs/<lane>.md`) for the *active* lanes; don't improvise prompts unless a template is missing (if an active lane's template is missing, halt `NEEDS HUMAN` — the review wouldn't be reproducible). Prefer subagents, launched in one parallel batch. If the environment can't provide a fresh independent reviewer context, halt `NEEDS HUMAN` — do not silently downgrade to author-only review.

## Process

1. **Prepare context.** Gather the diff (staged/committed/PR), list changed files and types, pick the `review_profile`, record skipped conditional lanes with concrete reasons, and load the active per-lane templates. Prepare placeholders: `<diff_summary>`, `<diff>`, `<changed_files>`, `<context>`, `<acceptance_criteria>`, `<verification>`. Print the step ledger (see roster reference).
2. **Dispatch reviewers** in fresh independent contexts using their per-lane templates. Each gets the diff + relevant file contents + CONTEXT.md if present, and returns findings with severity and confidence. If any required lane for the profile doesn't return, the verdict is `NEEDS HUMAN`.
3. **Synthesize.** Merge and dedupe findings into: a **Dispatch evidence** table (lane | subagent | status | summary), then **Must-fix (blocks merge)**, **Should-fix (follow-up)**, **Acceptable risks**, and **Human gate required**.
4. **Verdict.** `APPROVE` (no must-fix, and all required lanes returned), `REQUEST CHANGES` (has must-fix), or `NEEDS HUMAN` (blocking human-gate items). The synthesis must include the `WORKFLOW_REVIEW_GATE` block.

## Rules

Only report findings the author would agree need fixing. No style nits unless they hurt readability. Only findings with >70% confidence. If a finding contradicts an ADR, the ADR wins (note it, don't flag). Never claim "review complete" without independent evidence for each required lane; never substitute the author's own reasoning, CI, tests, or external bot reviews for the dispatch-and-synthesis gate.

## Contract

Consumes: diff/changeset, file contents, CONTEXT.md, ADRs. Produces: review synthesis (markdown) with independent-review evidence + verdict. Requires: git, independent-review context. Side effects: none. Human gates: `NEEDS HUMAN` halts until a human responds. If subagents are unavailable, use only a host-provided fresh independent reviewer context; otherwise halt `NEEDS HUMAN`.
