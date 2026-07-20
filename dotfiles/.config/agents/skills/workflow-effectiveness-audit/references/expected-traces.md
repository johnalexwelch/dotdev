# Expected Workflow Traces

Per-workflow required traces for step 2 of `workflow-effectiveness-audit`. For
each workflow invocation in the audit window, derive the expected trace from
this table and compare against the evidence.

| Workflow | Required trace |
|----------|----------------|
| `workflow-autonomous-backlog` | improve-codebase-architecture discovery evidence -> optional repo-audit supporting evidence -> candidate classification -> grill-with-docs module grill with recommended answers and CONTEXT/ADR updates -> MODULE_GRILL_CONSENSUS -> scoped second-pass decision -> module design summary approval for every module PRD -> to-prd -> to-issues -> triage -> AFK queue approval evidence -> run-backlog -> repo-policy-controlled PR handoff |
| `workflow-review` | worktree baseline evidence -> risk-sized review_profile -> independent reviewer evidence -> synthesized verdict |
| `workflow-finalize` | worktree baseline evidence -> optional post-mortem -> describe-pr, including reviewer validation footer when referenced issues carry `needs-human-review`, `Human review: required`, or equivalent explicit human-review gate -> ensure draft PR -> receive-review -> watch-ci -> reconcile-issues -> verification gate -> repo-policy final action |
| `describe-pr` | PR body -> issue disposition -> record review expectations only |
| `watch-ci` | draft PR -> CI poll -> bounded fixes -> security review -> reviewer-comment gate -> draft handoff gate |
| `run-backlog` | queue -> dependency/stack plan -> prompt-builder per issue with mandatory base/worktree/stack command -> isolated per-issue workflow-base or stacked dispatch -> monitor -> reconcile -> handoff |
| `workflow-build-one` | per-issue workflow-base worktree -> prompt-builder/preflight -> triage -> execute-phase -> workflow-review -> optional UJ QA -> workflow-finalize |
| `workflow-router` | classification evidence -> ROUTE_CARD -> user confirmation or valid direct/read-only skip -> target workflow preflight -> confirmed dispatch -> ROUTER_LEARNING_NOTE when completed, halted, or corrected |
