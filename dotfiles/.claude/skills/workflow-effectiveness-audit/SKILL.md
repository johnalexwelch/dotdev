---
name: workflow-effectiveness-audit
description: Evaluate whether skills and workflows are actually working. Audits recent agent transcripts, GitHub PRs/issues, and execution artifacts for skipped steps, missing subagents, unresolved review comments, weak handoffs, and routing gaps.
codex-compatible: true
---

# Workflow Effectiveness Audit

## Purpose

Measure whether the skill system is producing the behavior it promises. This is a governance and feedback-loop skill: it finds places where workflows were invoked but required steps were skipped, degraded silently, or produced weak outcomes.

Use this when the user asks:

- "Are these skills working?"
- "Evaluate workflow effectiveness"
- "Find gaps in our workflows"
- "Why did this workflow skip a step?"
- "Audit recent agent transcripts"
- "Did PRs merge with unresolved review comments?"

## Contract

Consumes: recent agent transcripts, skill files, GitHub PR/issue state, docs/executions artifacts, optional CORA findings
Produces: workflow effectiveness scorecard, gap findings, recommended skill/workflow fixes
Requires: git
Side effects: none by default; may create follow-up issues only with approval
Human gates: approval before editing skills, creating issues, or applying labels

## Context

Typical workflows: skill library governance, weekly workflow retro, post-incident review after agent misses
Pairs well with: skill-maintenance, reconcile-issues, receive-review, workflow-router

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

### 1. Define audit window

Default to the most recent 7 days or the latest 20 parent transcripts. If the user names a repo, PR, issue, or workflow, scope to that.

Collect evidence from:

- Parent agent transcripts only for user-facing behavior. Use subagent transcripts as supporting evidence, but cite parent transcript IDs to the user.
- `~/.claude/skills/` and `~/.codex/skills/` for the current skill definitions.
- `docs/executions/` artifacts: phase runs, handoffs, CI runs, PR bodies, retros.
- GitHub PRs/issues via `gh` when available.
- CORA findings when CORA is available.

### 2. Build expected workflow traces

For each workflow invocation, derive the expected trace from the skill:

| Workflow | Required trace |
|----------|----------------|
| `workflow-autonomous-backlog` | improve-codebase-architecture discovery evidence -> optional repo-audit supporting evidence -> candidate classification -> grill-with-docs module grill with recommended answers and CONTEXT/ADR updates -> MODULE_GRILL_CONSENSUS -> scoped second-pass decision -> module design summary approval for every module PRD -> to-prd -> to-issues -> triage -> AFK queue approval evidence -> run-backlog -> repo-policy-controlled PR handoff |
| `workflow-review` | worktree baseline evidence -> parallel specialist subagents -> dispatch evidence -> synthesized verdict |
| `workflow-finalize` | worktree baseline evidence -> optional post-mortem -> describe-pr -> ensure draft PR -> receive-review -> watch-ci -> reconcile-issues -> verification gate -> repo-policy final action |
| `describe-pr` | PR body -> issue disposition -> record review expectations only |
| `watch-ci` | draft PR -> CI poll -> bounded fixes -> security review -> reviewer-comment gate -> draft handoff gate |
| `run-backlog` | queue -> dependency/stack plan -> prompt-builder per issue with mandatory worktree/stack command -> isolated per-issue origin/staging or stacked dispatch -> monitor -> reconcile -> handoff |
| `workflow-build-one` | per-issue origin/staging worktree -> prompt-builder/preflight -> triage -> execute-phase -> workflow-review -> optional UJ QA -> workflow-finalize |

Mark each required step as:

- `done`: evidence exists
- `skipped-with-reason`: explicitly skipped with a valid reason
- `skipped-silently`: expected step missing and no reason recorded
- `failed`: attempted but did not complete
- `unknown`: evidence missing or ambiguous

### 3. Score effectiveness

Produce a scorecard with these dimensions:

| Dimension | What to measure |
|-----------|-----------------|
| Routing accuracy | Did the router pick the right workflow for the user request? |
| Step compliance | Were required workflow steps completed or explicitly skipped? |
| Review coverage | Did `workflow-review` launch required specialist subagents? |
| Review resolution | Were PR review comments fixed, replied to, waived, or followed up before merge? |
| Issue hygiene | Were Closes/Fixes/Addresses dispositions used correctly? |
| Verification quality | Were tests/CI/lints actually run and evidenced? |
| Handoff quality | Did halts and completions produce usable handoff artifacts? |
| Autonomous backlog safety | Did module PRDs/issues preserve provenance, candidate confidence, grill-with-docs module answers, MODULE_GRILL_CONSENSUS artifacts, CONTEXT/ADR updates when needed, scoped second-pass decisions, rollback expectations, queue approval, outage-risk controls, and all gate blocks per PR? |
| Sync health | Did Claude/Codex skill copies and Stow source remain aligned? |

Use a simple rating:

- `green`: no material misses
- `yellow`: minor gaps or justified skips
- `red`: required step skipped, unsafe merge behavior, or lost context

### 4. Detect known gap patterns

Always check for these:

1. `workflow-review` claimed completion but no subagent dispatch evidence exists.
2. `WORKFLOW_REVIEW_GATE` missing, incomplete, self-reported, or not backed by subagent outputs.
3. `workflow-finalize` claimed completion but no `WORKFLOW_FINALIZE_GATE` exists.
4. Mutating issue work lacks a fresh per-issue `WORKTREE_BASELINE_GATE: origin/staging -> ...` or valid `STACKED_WORKTREE_GATE: origin/staging -> <parent-branch> -> ...` created before implementation.
5. PR was approved, auto-merged, merged, or closed while actionable review comments were unanswered.
6. `watch-ci` handed back a draft despite unresolved comments, missing security review, or skipped required self-review.
7. `describe-pr` used `Closes/Fixes/Resolves` for partial work.
8. `workflow-finalize` skipped `receive-review` before `watch-ci`.
9. `run-backlog` dispatched raw issue bodies instead of `prompt-builder` outputs.
9a. `prompt-builder` output omitted the mandatory per-issue `origin/staging` worktree command or `WORKTREE_BASELINE_GATE` requirement.
9b. Stacked dependent work ran without complete clean parent gates, without `STACKED_WORKTREE_GATE`, or with a child PR targeting `staging` instead of the parent branch.
10. `workflow-autonomous-backlog` used `repo-audit` alone for module discovery without `improve-codebase-architecture`.
11. `workflow-autonomous-backlog` created module PRDs without evidence-backed module candidate provenance, confidence, rollback expectation, `/grill-with-docs` module grill output, `MODULE_GRILL_CONSENSUS`, scoped second-pass decision, or explicit module design summary approval.
11b. `MODULE_GRILL_CONSENSUS` was missing, unbounded, used plain `APPROVE` instead of `CRITIC_APPROVE`, lacked critic reasons, repeated the same rejection class twice without halting, or was treated as human module design approval.
11c. `MODULE_GRILL_CONSENSUS` schema was incomplete or invalid. Required fields: `candidate`, `source_evidence`, `question_batch`, `recommended_answers`, `critic_rounds`, `final_consensus`, `unresolved_uncertainties`, `human_gate_check`, `second_pass_decision`, `rollout_rollback_risk`, and `context_adr_updates`. Required enum values: critic verdict is `CRITIC_APPROVE|CRITIC_REJECT|NEEDS_HUMAN`; `second_pass_decision` is `not_needed|run|needs_human`; `human_gate_check` is `required|granted|preauthorized_low_risk|needs_human`.
11a. `workflow-autonomous-backlog` recursively decomposed modules without a grill-backed trigger, or promoted submodules that failed the deletion test / lacked a stable Interface.
12. `to-prd` or another workflow labeled a PRD/spec parent issue `ready-for-agent`; only child implementation issues may receive that label.
13. `to-issues` produced AFK issues without AFK/HITL classification, outage-risk classification, dependencies, verification commands, rollback expectation, module grill evidence when applicable, or worktree/review/finalize policy.
14. `run-backlog` auto-approved a queue without an explicit unattended/AFK request in the same invocation.
15. Backlog PR was accepted as successful without all required gate blocks: `WORKTREE_BASELINE_GATE`, `WORKFLOW_REVIEW_GATE`, and `WORKFLOW_FINALIZE_GATE`.
16. AFK run dispatched high-risk/excluded outage categories without explicit issue-level human approval and rollback plan.
17. Backlog PR final action violated `REPO_DELIVERY_POLICY`: human-only repo became ready/auto-merged, auto-merge-eligible repo skipped ready/auto-merge after gates passed, or `WORKFLOW_FINALIZE_GATE.repo_delivery_policy` was missing.
18. Handoff promised but no artifact was written.
19. Skill was edited in `~/.claude/skills` or `~/.codex/skills` but not in the Stow source.
20. Codex-visible skill requires MCPs or interactive tools without `codex-compatible: false`.
21. User had to correct the same agent behavior more than once.

### 5. Output

Return:

```markdown
# Workflow Effectiveness Audit

## Scope
- Window:
- Sources:
- Workflows audited:

## Scorecard
| Dimension | Rating | Evidence | Recommended fix |
|-----------|--------|----------|-----------------|

## Findings
### RED
- Finding, evidence, why it matters, proposed fix

### YELLOW
- Finding, evidence, proposed fix

### GREEN
- What is working as intended

## Repeated Corrections
- User correction pattern -> workflow/skill to update

## Autonomous Backlog Gate Matrix
| PR/Issue | Module PRD provenance | Confidence | Module grill | Rollback | AFK queue approval | Risk policy result | Draft PR state | Worktree gate | Review gate | Finalize gate | Result |
|----------|-----------------------|------------|--------------|----------|--------------------|--------------------|----------------|---------------|-------------|---------------|--------|

## Follow-up Work
- Skill edits recommended
- Issues to create
- CORA/sync checks to run
```

## Rules

- Findings require evidence. Cite transcript IDs, PR numbers, issue numbers, or artifact paths.
- Do not cite subagent transcript IDs to the user; cite the parent transcript ID.
- Do not create issues or edit skills unless the user asks for fixes or approves the proposed change list.
- Prefer changing the narrowest skill that owns the failure. Example: unresolved PR comments belong in `receive-review`, `workflow-finalize`, `watch-ci`, and `reconcile-issues`, not in every workflow.
- Treat green CI as insufficient evidence for reviewer-comment resolution.
