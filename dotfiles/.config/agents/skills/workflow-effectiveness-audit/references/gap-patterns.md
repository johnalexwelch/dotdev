# Known Gap Patterns

Checklist for step 4 of `workflow-effectiveness-audit`. Always check for these:

1. `workflow-review` claimed completion but no independent review evidence exists.
2. `WORKFLOW_REVIEW_GATE` missing, incomplete, self-reported by the author, missing `review_profile`, missing `independent_review: true`, or not backed by the selected profile's required reviewer outputs.
3. `workflow-finalize` claimed completion but no `WORKFLOW_FINALIZE_GATE` exists.
4. Mutating issue work lacks `WORKFLOW_BASE_GATE` plus a fresh per-issue `WORKTREE_BASELINE_GATE: <workflow-base-ref> -> ...` or valid `STACKED_WORKTREE_GATE: <workflow-base-ref> -> <parent-branch> -> ...` created before implementation.
5. PR was approved, auto-merged, merged, or closed while actionable review comments were unanswered.
6. `watch-ci` handed back a draft despite unresolved comments, missing security review, or skipped required self-review.
7. `describe-pr` used `Closes/Fixes/Resolves` for partial work.
8. `workflow-finalize` skipped `receive-review` before `watch-ci`.
9. `run-backlog` dispatched raw issue bodies instead of `prompt-builder` outputs.
9a. `prompt-builder` output omitted the mandatory `WORKFLOW_BASE_GATE`, per-issue workflow-base worktree command, or `WORKTREE_BASELINE_GATE` requirement.
9b. Stacked dependent work ran without complete clean parent gates, without `STACKED_WORKTREE_GATE`, or with a child PR targeting `staging` instead of the parent branch.
9c. `prompt-builder` or `run-backlog` dispatched a human-review-required issue without carrying `Human review: required` and concrete `## Reviewer validation steps` into the worker prompt.
10. `workflow-autonomous-backlog` used `repo-audit` alone for module discovery without `improve-codebase-architecture`.
11. `workflow-autonomous-backlog` created module PRDs without evidence-backed module candidate provenance, confidence, rollback expectation, `/grill-with-docs` module grill output, `MODULE_GRILL_CONSENSUS`, scoped second-pass decision, or explicit module design summary approval.
11b. `MODULE_GRILL_CONSENSUS` was missing, unbounded, used plain `APPROVE` instead of `CRITIC_APPROVE`, lacked critic reasons, repeated the same rejection class twice without halting, or was treated as human module design approval.
11c. `MODULE_GRILL_CONSENSUS` schema was incomplete or invalid. Required fields: `candidate`, `source_evidence`, `question_batch`, `recommended_answers`, `critic_rounds`, `final_consensus`, `unresolved_uncertainties`, `human_gate_check`, `second_pass_decision`, `rollout_rollback_risk`, and `context_adr_updates`. Required enum values: critic verdict is `CRITIC_APPROVE|CRITIC_REJECT|NEEDS_HUMAN`; `second_pass_decision` is `not_needed|run|needs_human`; `human_gate_check` is `required|granted|preauthorized_low_risk|needs_human`.
11a. `workflow-autonomous-backlog` recursively decomposed modules without a grill-backed trigger, or promoted submodules that failed the deletion test / lacked a stable Interface.
12. `to-prd` or another workflow labeled a PRD/spec parent issue `ready-for-agent`; only child implementation issues may receive that label.
13. `to-issues` produced AFK issues without AFK/HITL classification, outage-risk classification, dependencies, verification commands, rollback expectation, module grill evidence when applicable, human-review classification, or worktree/review/finalize policy.
13a. `to-issues` marked human-validation-only work as `Type: HITL` or `ready-for-human` instead of keeping it AFK with `Human review: required`, `needs-human-review`, and concrete `## Reviewer validation steps`.
13b. `to-issues` produced a human-review-required issue without `Human review: required` and a concrete `## Reviewer validation steps` section.
13c. `to-issues` published implementation issues without an `ISSUE_DEPENDENCY_AUDIT`, or the audit routed a parent/dependent PRD child tree to `run-backlog` instead of `execute-prd`.
14. `run-backlog` auto-approved a queue without an explicit unattended/AFK request in the same invocation.
14a. `run-backlog` queued PRD child issues instead of halting and routing to `execute-prd`.
15. Backlog PR was accepted as successful without all required gate blocks: `WORKTREE_BASELINE_GATE`, `WORKFLOW_REVIEW_GATE`, and `WORKFLOW_FINALIZE_GATE`.
16. AFK run dispatched high-risk/excluded outage categories without explicit issue-level human approval and rollback plan.
17. Backlog PR final action violated `REPO_DELIVERY_POLICY`: human-only repo became ready/auto-merged, auto-merge-eligible repo skipped ready/auto-merge after gates passed, or `WORKFLOW_FINALIZE_GATE.repo_delivery_policy` was missing.
18. Handoff promised but no artifact was written.
19. Skill was edited in `~/.claude/skills` or `~/.codex/skills` but not in the Stow source.
20. Codex-visible skill requires MCPs or interactive tools without `codex-compatible: false`.
21. User had to correct the same agent behavior more than once.
22. `workflow-router` dispatched a non-trivial, mutating, artifact-producing, issue/PR, delivery, or AFK workflow without a `ROUTE_CARD` and explicit confirmation.
23. `workflow-router` completed, halted, or received user route correction without a `ROUTER_LEARNING_NOTE`.
24. `workflow-finalize` referenced a `needs-human-review`, `Human review: required`, or equivalent human-review-required issue, but the PR body did not end with a `## Reviewer validation steps` section containing concrete ordered validation actions from the issue.
25. `describe-pr` or `workflow-finalize` treated `ready-for-human` or generic `Type: HITL` as a PR reviewer-validation trigger.
