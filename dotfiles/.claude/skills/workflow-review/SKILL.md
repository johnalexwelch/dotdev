---
name: workflow-review
description: Dispatch required parallel specialist subagents and synthesize their findings into an auditable review verdict. Use before merging, after implementation, at any explicit review gate, or whenever the user asks to review changes; green CI, GitHub reviews, Claude Code Review, and PR comments do not substitute for this workflow.
---

# Workflow Review

## Purpose

Run multiple specialist reviews in parallel, then synthesize findings into a prioritized action list. This replaces ad-hoc "review this" with structured multi-perspective analysis.

This workflow is not satisfied by one inline review from the current agent. The review is valid only if the required reviewer subagents are actually dispatched and their outputs are cited in the synthesis.

This workflow is also not satisfied by adjacent validation. Green CI, passing tests, GitHub reviewer comments, Claude Code Review, Bugbot, Codex review, or `/receive-review` may be useful inputs, but none of them count as `workflow-review` unless this skill is loaded, reviewer lanes are dispatched, and a synthesis verdict is produced.

## When to invoke

- Before merging any PR
- After execute-phase completes
- When workflow-build-one or workflow-debug reaches the review gate
- When execute-prd, run-backlog, or another parent workflow says `workflow-review`
- Explicitly by user ("review this", "review my changes")

## Gate Invariant

If a workflow says `workflow-review`, the agent must run this skill at that point. It may not proceed to `workflow-finalize`, PR creation, CI monitoring, reconcile, merge, or handoff-as-clean until a `workflow-review` synthesis exists.

For code changes, the review must run against a branch/worktree cut from `origin/staging`, or a valid stacked dependent worktree cut from a clean parent branch. If the change lacks `WORKTREE_BASELINE_GATE` or valid `STACKED_WORKTREE_GATE` evidence, return `NEEDS HUMAN` instead of reviewing a primary-checkout or local-main diff.

Minimum acceptable gate evidence:

- This `SKILL.md` was loaded.
- The active reviewer lanes are listed.
- Required lanes were dispatched as subagents.
- Conditional lanes were either dispatched or marked `skipped-with-reason`.
- The synthesis contains dispatch evidence.
- The verdict is `APPROVE`, `REQUEST CHANGES`, or `NEEDS HUMAN`.

If any evidence is missing, the verdict is `NEEDS HUMAN`; do not infer approval from CI, tests, or PR review state.

## Required Gate Block

Every valid `workflow-review` run must emit this block verbatim in the synthesis and any handoff/completion summary that depends on it:

```markdown
WORKFLOW_REVIEW_GATE:
  worktree_baseline: origin/staging -> <branch> @ <worktree-path> OR stacked: origin/staging -> <parent-branch> -> <child-branch> @ <child-worktree-path>
  skill_loaded: true
  required_lanes:
    security: dispatched|returned
    logic_edge_cases: dispatched|returned
    tests: dispatched|returned|not_applicable_with_reason
    syntax_style: dispatched|returned
  conditional_lanes: <dispatched/skipped-with-reason list>
  dispatch_evidence: <subagent names/types and return status>
  verdict: APPROVE|REQUEST_CHANGES|NEEDS_HUMAN
```

If this block is absent, incomplete, self-reported without real subagent dispatch, or says anything other than `verdict: APPROVE`, parent workflows must treat `workflow-review` as not run. A "soft review", inline checklist, Claude Code Review, GitHub review, Bugbot/Codex review, green CI, or the current agent's reasoning is invalid for this gate.

## Reviewers

Dispatch these in parallel (each gets the same diff/changeset). The minimum required lanes for any code change are **Security Auditor**, **Logic & Edge-Case Reviewer**, **TDD/Test Coverage Agent**, and **Syntax/Style Guide Expert**. Other lanes are conditional but must be explicitly marked `skipped-with-reason` when not run.

| Reviewer | Focus | Default |
|----------|-------|---------|
| **Security Auditor** | Vulnerabilities, injection flaws, auth bypass, data leaks, secrets, privacy regressions, OWASP Top 10 | Always for code changes |
| **Logic & Edge-Case Reviewer** | Business logic, logical loopholes, edge cases, null/empty/error states, architectural integrity at the change boundary | Always |
| **TDD/Test Coverage Agent** | Tests that prove the behavior, regression coverage, integration coverage, test quality, whether TDD expectations were met | Always for behavior changes |
| **Syntax/Style Guide Expert** | Team-specific linting rules, naming conventions, formatting, cleanliness, local idioms | Always for code changes |
| **Performance Specialist** | Time complexity, memory usage, query counts, hot paths, bottleneck risks, async/background throughput | Conditional: loops, queries, large data, hot paths, background jobs, caching |
| **Documentation Reviewer** | README/docs/docstrings/comments/config docs updated when behavior or public APIs change | Conditional: public APIs, setup/config, workflows, non-obvious behavior |
| **Architecture Reviewer** | Coupling, cohesion, abstraction boundaries, dependency direction, module ownership, long-term maintainability | Conditional: multi-file changes, new abstractions, shared modules |
| **Backward Compatibility Reviewer** | API contracts, persisted data, migrations, config compatibility, stable public behavior | Conditional: public APIs, schemas, persisted data, config, migrations |
| **Concurrency & State Reviewer** | Races, retries, idempotency, transactions, cache invalidation, background jobs, state machines | Conditional: async/stateful code, jobs, caches, retries, distributed behavior |
| **Observability Reviewer** | Logs, metrics, traces, actionable errors, alertability, debugging affordances | Conditional: production paths, failure handling, background jobs, infra |
| **Release/Rollback Reviewer** | Feature flags, rollout safety, revertability, deploy risk, migration rollback | Conditional: risky releases, migrations, infra, broad user impact |
| **Dependency/Supply-Chain Reviewer** | New packages, lockfile churn, licenses, dependency security, vendored code | Conditional: dependency or lockfile changes |
| **Product/Acceptance Reviewer** | Whether the diff satisfies the issue/PRD acceptance criteria and avoids scope drift | Conditional: issue/PRD-backed work |
| **Frontend/UX/A11y Reviewer** | Accessibility, responsive behavior, UX consistency, component patterns | Conditional: frontend or user-facing behavior |

## Dispatch Contract

Use real subagents, not an internal checklist. Launch active reviewers in one parallel batch when the environment supports it.

Before dispatch, read the brief index at `references/reviewer-briefs.md`, then read only the per-lane template files for active reviewer lanes. Do not improvise reviewer prompts from scratch unless the required template file is missing; if any active lane template is missing, halt with `NEEDS HUMAN` because the review would not be reproducible.

Recommended subagent mapping:

| Reviewer | Subagent type |
|----------|---------------|
| Security Auditor | `security-reviewer` |
| Logic & Edge-Case Reviewer | `code-reviewer` |
| TDD/Test Coverage Agent | `test-engineer` |
| Syntax/Style Guide Expert | `code-reviewer` or `code-simplifier` in review-only mode |
| Performance Specialist | `code-reviewer` with performance brief, or `architect` for system-level bottlenecks |
| Documentation Reviewer | `writer` |
| Architecture Reviewer | `architect` or `code-architect` |
| Backward Compatibility Reviewer | `code-reviewer` with compatibility brief |
| Concurrency & State Reviewer | `debugger`, `tracer`, or `code-reviewer` with concurrency brief |
| Observability Reviewer | `architect` or `code-reviewer` with observability brief |
| Release/Rollback Reviewer | `verifier` or `architect` |
| Dependency/Supply-Chain Reviewer | `security-reviewer` |
| Product/Acceptance Reviewer | `verifier` |
| Frontend/UX/A11y Reviewer | `designer` for UX/accessibility or `code-reviewer` for frontend correctness |

If the current environment cannot launch subagents, halt with `NEEDS HUMAN`. Do not silently downgrade to inline review.

## Workflow Progress Reporting

At the start of every run, display a step ledger before executing or dispatching any step. Use the exact step names from this skill and include conditional or optional steps.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| <step name> | required|conditional|optional | pending|completed|skipped|blocked|failed|not_applicable | <evidence, reason, or -> |
```

Rules:

- Initialize every known step as `pending`; conditional steps remain `pending` until their trigger is evaluated.
- As each step finishes or is skipped, update the ledger with the new status and evidence or reason.
- A step may be `skipped` only when this skill explicitly makes it optional/conditional or a routing decision stops the workflow; record the exact reason.
- Do not mark required gates as skipped. If a required gate cannot run, mark it `blocked` or `failed` and halt according to this workflow.
- At every halt, STOP, handoff, and final completion, include the final ledger in the response or artifact.
- The final ledger must distinguish `completed`, `skipped`, `blocked`, `failed`, and `not_applicable`, and every non-completed status must include a reason.

## Process

### 1. Prepare context

- Gather the diff (staged, committed, or PR)
- Identify which files changed and their types
- Determine which reviewers to activate (see "Default" column)
- Record skipped conditional lanes with the concrete reason, e.g. `skipped-with-reason: no dependency or lockfile changes`
- Load the template index at `references/reviewer-briefs.md`
- Load only the per-lane template files for active reviewer lanes
- Prepare shared placeholders for reviewer templates: `<diff_summary>`, `<diff>`, `<changed_files>`, `<context>`, `<acceptance_criteria>`, and `<verification>`

### 2. Dispatch reviewers

- Launch each active reviewer as a parallel subagent (via OMC executor or direct dispatch)
- Use that reviewer's per-lane prompt template from `references/reviewer-briefs/<lane>.md`
- Record which reviewer lanes were launched, which subagent type handled each lane, and whether any required lane was skipped
- Each reviewer receives: the diff, relevant file contents, CONTEXT.md if present
- Each reviewer returns: list of findings with severity and confidence
- If any minimum required lane does not return a result, the verdict is `NEEDS HUMAN`

### 3. Synthesize

Merge all reviewer outputs. Deduplicate overlapping findings. Prioritize:

```markdown
## Review Synthesis

### Dispatch evidence
| Lane | Subagent | Status | Output summary |
|------|----------|--------|----------------|
| Security Auditor | security-reviewer | returned | clean |
| Logic & Edge-Case Reviewer | code-reviewer | returned | 2 findings |
| TDD/Test Coverage Agent | test-engineer | returned | clean |
| Syntax/Style Guide Expert | code-reviewer | returned | 1 finding |
| Performance Specialist | code-reviewer | skipped-with-reason | no hot paths |
| Documentation Reviewer | writer | skipped-with-reason | no public API/docs impact |

### Must-fix (blocks merge)
- [Critical bugs, security issues, data loss risks]

### Should-fix (merge OK, follow-up needed)
- [Architecture concerns, test gaps, maintainability issues]

### Acceptable risks (acknowledged, no action needed)
- [Trade-offs, known limitations, intentional shortcuts]

### Human gate required
- [Decisions that need human judgment — ambiguous requirements, business logic, UX choices]
```

### 4. Verdict

- **APPROVE**: No must-fix items
- **REQUEST CHANGES**: Has must-fix items
- **NEEDS HUMAN**: Has human-gate items that block the decision

`APPROVE` is allowed only when all minimum required reviewer lanes returned successfully.
Conditional lanes may be skipped only when the synthesis records a specific skip reason.
The synthesis must include the `WORKFLOW_REVIEW_GATE` block. Without it, the review is invalid even if the prose says "approved".

## Rules

- Only report findings the original author would agree need fixing
- No style nits unless they affect readability significantly
- Confidence threshold: only include findings with >70% confidence
- If a finding contradicts an ADR, the ADR wins — note it but don't flag it
- Never claim "review complete" unless the synthesis includes dispatch evidence for each required lane
- Never substitute the current agent's own reasoning for a missing reviewer lane
- Never substitute CI, tests, GitHub/Claude/Codex/Bugbot reviews, or resolved PR comments for this workflow's dispatch-and-synthesis gate

## Contract

Consumes: diff/changeset, file contents, CONTEXT.md, ADRs
Produces: review synthesis (markdown) with dispatch evidence and verdict (APPROVE/REQUEST CHANGES/NEEDS HUMAN)
Requires: git, subagent-dispatch
Side effects: none
Human gates: NEEDS HUMAN verdict halts workflow until human responds

Runtime requirement: subagent dispatch must be available for a valid review. If the environment cannot launch subagents, halt with `NEEDS HUMAN`.
Bundled resources: `references/reviewer-briefs.md` maps reviewer lanes to token-efficient per-lane prompt templates in `references/reviewer-briefs/`.

## Context

Typical workflows: workflow-build-one, workflow-debug, workflow-finalize, workflow-autonomous-backlog
Pairs well with: execute-phase, describe-pr, user-journey-qa, run-backlog
