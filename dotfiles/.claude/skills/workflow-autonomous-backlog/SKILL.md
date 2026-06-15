---
name: workflow-autonomous-backlog
model: sonnet
reasoning: high
description: Orchestrates autonomous module discovery into PRDs/issues and AFK backlog execution with outage controls. Use when the user wants agents to find module opportunities, create PRDs/issues, or run a ready-for-agent backlog unattended without bypassing delivery gates.
---

# Workflow Autonomous Backlog

## Purpose

Run the full autonomous loop:

```text
module discovery -> module grilling -> decision log -> PRD/issues -> triage -> AFK execution -> repo-policy-controlled PR handoff
```

This workflow coordinates existing skills. It does not replace their gates.

## Contract

Consumes: repo state, module discovery brief or backlog request, decision log, GitHub Issues, existing PRDs/issues
Produces: module PRDs, implementation issues, AFK backlog run handoff, PRs handled according to repo delivery policy
Requires: gh, git, omc, subagent-dispatch, project-test-runner
Side effects: creates GitHub issues, dispatches implementation work, creates branches/PRs through child workflows, writes handoff artifacts
Human gates: module design summary approval; AFK queue approval unless explicitly requested unattended; high-risk outage categories halt; final release remains human-only only for repos classified `human-only` by `run-backlog/references/repo-delivery-policy.md`

## Flow

### 1. Discover module candidates

- Run `improve-codebase-architecture` for deepening opportunities and, when broader evidence is needed, `repo-audit` or a scoped architecture discovery pass.
- Identify candidate modules from evidence only.
- Each candidate must include current pain, affected area, proposed boundary, public interface shape, testability opportunity, migration/rollout risk, and confidence.

### 2. Classify candidates

Classify every candidate:

- `discard`: insufficient value or duplicate.
- `needs-human`: product/domain/architecture decision unresolved.
- `research-spike`: prototype or investigation required before PRD.
- `module-prd-ready`: enough evidence to draft a PRD.

Do not create PRDs for `needs-human` or `research-spike` candidates.

### 3. Module grilling gate

Before `to-prd`, run `/grill-with-docs` for every `module-prd-ready` candidate. Use full mode when `CONTEXT.md` exists or the module is architecturally significant. Ask in batches with recommended answers, accept recommended answers as provisional defaults when the user approves, record accepted answers in the decision log, and update `CONTEXT.md` / ADRs inline when terms or decisions crystallize.

Use the `improve-codebase-architecture` grilling loop as the architecture-specific lens inside `/grill-with-docs`, so the grill explicitly covers the Module's Interface, Implementation, seams, adapters, locality, leverage, and deletion-test result.

For each module, ask and answer:

- what concept owns the module
- what interface callers should know
- what implementation complexity sits behind the interface
- what seam is real now versus hypothetical
- what adapters exist or will exist
- what tests live at the interface
- what migration, rollout, and rollback risks remain
- what ADR or `CONTEXT.md` updates are needed
- whether a scoped second pass is needed inside the module

### 3.1. Module grill consensus

After `/grill-with-docs` produces recommended answers, run a read-only critic subagent to challenge those recommendations. The critic validates evidence quality only; it does not replace human module design approval. Dispatch the critic in read-only mode; it must not edit files, write artifacts, create ADRs, update `CONTEXT.md`, or author the final recommendation.

The critic reviews against:

- code evidence and current behavior
- `CONTEXT.md` and ADRs
- Module Interface, Implementation, seams, adapters, locality, leverage, and deletion-test claims
- rollout and rollback risk
- over-decomposition or fake submodules

Use bounded rounds:

- Maximum `max_rounds: 2`; no override. If consensus is not reached after 2 rounds, halt as `NEEDS_HUMAN`.
- Parent agent orchestrates each round; subagents do not free-chat indefinitely.
- Each round passes only candidate summary, evidence references, question-batch recommendations, critic reasons, and changed recommendations since the prior round.
- If the same rejection class appears twice, halt as `NEEDS_HUMAN`.

Critic verdicts:

- `CRITIC_APPROVE`: recommendations are evidence-backed and no human-gated issue was detected.
- `CRITIC_REJECT`: specific evidence gap or contradiction must be revised.
- `NEEDS_HUMAN`: the decision touches product behavior, public Interface, data model, auth/payment behavior, infrastructure, rollout risk, ADR direction, or unresolved domain language.

Required artifact:

```markdown
MODULE_GRILL_CONSENSUS:
  candidate: <id/name>
  source_evidence: <candidate evidence references>
  question_batch: <summary>
  recommended_answers: <summary>
  critic_rounds:
    - round: <n>
      verdict: CRITIC_APPROVE|CRITIC_REJECT|NEEDS_HUMAN
      reasons: <bullets>
      changes_requested: <bullets>
  final_consensus: <accepted recommendation or needs_human reason>
  unresolved_uncertainties: <none/list>
  human_gate_check: <required/granted/preauthorized_low_risk/needs_human>
  second_pass_decision: not_needed|run|needs_human
  rollout_rollback_risk: <summary>
  context_adr_updates: <made/needed/not_applicable>
  decision_log_entries: <entry titles or missing reason>
```

`MODULE_GRILL_CONSENSUS` and related decision-log entries are required provenance for autonomous module PRDs. Consensus is not approval to create a PRD unless human approval evidence exists, or the same invocation explicitly pre-authorized low-risk autonomous module acceptance.

Present the recommended answers, call out uncertainty, and require user approval for every candidate before PRD creation. Approval is the gate that turns evidence into a PRD; without it, classify the candidate as `needs-human`.

### 3.5. Optional scoped second architecture pass

After the module grill, decide whether to run `improve-codebase-architecture` a second time, scoped only to the selected Module.

Run the second pass only when the grill identifies real internal friction:

- multiple concepts behind one interface
- unclear seams or adapters
- tests that cannot live at the parent interface
- internal coupling that harms locality
- implementation complexity that would spread across internal callers

Do not recursively decompose Modules by default. The second pass is a lens, not a loop. Treat second-pass findings as possible private submodules unless they pass the deletion test and have a stable interface worth testing directly.

Record one of:

- `second_pass: not_needed` with reason
- `second_pass: run` with scope, findings, and recommended private/public submodules
- `second_pass: needs_human` when the split changes product behavior, public interface, data model, auth/payment behavior, infrastructure, rollout risk, or ADR direction

Required summary fields:

- module name and responsibility
- why the module should exist
- non-goals
- interface and seam
- implementation hidden behind the interface
- adapters
- migration plan
- verification plan
- rollout and rollback risks
- recommended answers accepted or overridden
- second-pass decision and findings, or `not_needed` with reason
- approval evidence

### 4. Create PRDs and issues

- Use `to-prd` only for approved `module-prd-ready` candidates.
- Use `to-issues` to split each PRD into vertical slices.
- Every issue must include clear acceptance criteria, dependency order, AFK/HITL classification, outage-risk classification, verification expectations, and the worktree rule:
  `WORKTREE_BASELINE_GATE: origin/staging -> <branch> @ <worktree-path>`.
- Run `/triage` on every child implementation issue after creation. `/triage` owns the labels and agent brief required for execution.
- Only `/triage` may apply `ready-for-agent`, and only to issues with clear acceptance criteria, no unresolved human decisions, an executable verification path, AFK-safe risk classification, rollback expectations, the exact worktree gate requirement, review/finalize policy, and required module grill evidence.

### 5. Prepare AFK queue

Invoke `run-backlog` only after loading `run-backlog/references/outage-risk-policy.md` and `run-backlog/references/repo-delivery-policy.md`.

The queue must exclude:

- `blocked`, `needs-human`, or `in-progress` issues
- issues without acceptance criteria
- issues without test/verification commands
- high-risk outage categories without explicit human approval
- dependency-conflicting issues in the same wave

AFK approval is valid only when the user explicitly requested unattended backlog execution in the current invocation. Otherwise present the queue and halt.

The run must record `REPO_DELIVERY_POLICY` before dispatch:

- `human-only`: final output is draft PR handoff or existing non-draft PR preservation; never mark ready, merge, or enable auto-merge.
- `auto-merge-eligible`: after all required gates pass, `run-backlog` may mark PRs ready and enable GitHub auto-merge.

### 6. Execute backlog

Each issue runs through `workflow-build-one` or `workflow-debug`.

Each issue must create its own fresh worktree before work starts. Worktree creation must follow `setup-worktree` or the Cursor `using-git-worktrees` pattern only when it is constrained to the project policy: fetch `origin`, create a fresh branch from `origin/staging`, run inside that worktree, and emit `WORKTREE_BASELINE_GATE`. Generic worktree creation that omits `origin/staging`, reuses another issue's worktree, or works from the primary checkout does not satisfy this workflow.

### 6.1. Stacked dependent development

Dependent issues may continue before the parent PR is merged only through a controlled stacked flow:

- The parent issue PR must have `WORKTREE_BASELINE_GATE`, `WORKFLOW_REVIEW_GATE` with `review_profile`, `independent_review: true`, and `verdict: APPROVE`, a complete `WORKFLOW_FINALIZE_GATE`, green CI, and no unresolved reviewer comments.
- The child issue creates its own fresh worktree from the parent branch, not from the primary checkout.
- The child PR targets the parent branch, not `staging`.
- The child handoff records:
  `STACKED_WORKTREE_GATE: origin/staging -> <parent-branch> -> <child-branch> @ <child-worktree-path>; parent_pr: #<n>; parent_gates: complete`
- The stack handoff records merge order and retargeting instructions after the parent lands.

If any parent gate is missing, stale, or not clean, the dependent issue remains `blocked` or `needs-human`. Stacked development follows `REPO_DELIVERY_POLICY`: `human-only` stacks do not permit marking PRs ready, approving, merging, enabling auto-merge, force-pushing, rebasing, or using destructive git; `auto-merge-eligible` stacks may mark ready and enable GitHub auto-merge only after gates pass and the child PR targets the parent branch.

No issue can enter finalization until `workflow-review` emits `WORKFLOW_REVIEW_GATE` with `review_profile`, `independent_review: true`, and `verdict: APPROVE`. No issue can be marked successful until `workflow-finalize` emits a complete `WORKFLOW_FINALIZE_GATE`.

Required gates per PR:

- `WORKTREE_BASELINE_GATE` or valid `STACKED_WORKTREE_GATE`
- local verification evidence
- `user-journey-qa` when triggered
- `WORKFLOW_REVIEW_GATE` with `review_profile`, `independent_review: true`, and `verdict: APPROVE`
- `WORKFLOW_FINALIZE_GATE`
- repo-policy-controlled PR handoff (`pr_state: draft`, `existing_non_draft_not_modified`, or `ready_auto_merge_enabled` in the finalization gate)

Missing gate evidence marks the item `needs-human`; it is not a successful AFK item.

### 7. Handoff

At completion, write a handoff with:

- module candidates considered
- `/grill-with-docs` module grill summaries, recommended answers, and any `CONTEXT.md` / ADR updates
- PRDs/issues created
- AFK queue and explicit approval evidence
- per-issue status
- PR links and repo delivery policy outcome
- all gate blocks or missing-gate blockers
- failed/retryable prompts
- human release decisions still required for `human-only`, blocked, or failed items

Never approve, force-push, rebase, or perform destructive git from this workflow. Mark ready and enable GitHub auto-merge only when `run-backlog` resolved `REPO_DELIVERY_POLICY.mode: auto-merge-eligible` and all required gates passed.

## Completion Criteria

This workflow completes only when:

- every created issue is triaged
- every dispatched issue has a terminal status: repo-policy-controlled PR handoff, `needs-human`, `blocked`, or failed with handoff
- `run-backlog` reconciliation has run
- no issue is marked `done` without merged PR plus all required gate evidence

## Context

Typical workflows: autonomous module discovery, overnight AFK backlog execution, periodic backlog processing
Pairs well with: repo-audit, to-prd, to-issues, triage, run-backlog, workflow-effectiveness-audit
