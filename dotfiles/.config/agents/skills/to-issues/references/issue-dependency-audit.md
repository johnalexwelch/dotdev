# Issue Dependency Audit

Use this reference after slice approval and again after publishing real issue IDs.
It decides whether issues are independent backlog work or a parent/dependent PRD
tree.

## Output Block

```markdown
ISSUE_DEPENDENCY_AUDIT:
- parent_issue:
- source_prd_or_plan:
- issues:
  - issue:
    parent:
    blocked_by:
    blocks:
    type: AFK|HITL
    maintainer_operator_gate: required|not_required
    reviewer_validation: required|not_required
    human_review: required|not_required
    state_label:
    review_gate_labels:
    route_eligible: yes|no
    recommended_executor: workflow-build-one|execute-prd|run-backlog|needs-human
- independent_backlog_safe: yes|no
- dependency_tree_safe: yes|no
- notes:
```

## Rules

- PRD/spec parent issues are references only. They must not receive
  `ready-for-agent`.
- A parent issue with dependent child implementation issues routes to
  `execute-prd`, not `run-backlog`.
- Only independent, unblocked `ready-for-agent` issues route to `run-backlog`.
- Reviewer-validation-only issues stay AFK when they include concrete reviewer
  validation steps. They must not receive `needs-human-review`; set
  `human_review: not_required`, `reviewer_validation: required`, and
  `review_gate_labels: []`.
- Use `human_review: required` and `needs-human-review` only for
  maintainer/operator gates: explicit product/architecture/security decisions,
  operator-held runtime access, secret custody, public exposure, destructive
  cleanup, or other non-delegable approval.
- HITL, high-risk, excluded, blocked, unclear, unverifiable, or ungrilled module
  slices route to `ready-for-human`, `blocked`, or `needs-human`.
- If the audit is inconclusive, do not publish or queue the issues as AFK-ready.
