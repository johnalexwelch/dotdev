# Skill Root Manifest

Status: restored after 2026-06-21 audit correction.

The prior keep rule was too narrow: on-demand skills are intentionally absent from always-loaded `CLAUDE.md`, but still earn their keep across development, data, writing, planning, and creative workflows.

Active skills:

- `airflow-failure-rca`
- `analysis-council`
- `analysis-design`
- `brain-ops`
- `caveman`
- `clarity-review`
- `cleanup-delivery`
- `codebase-design`
- `council-scaffolding`
- `dashboard-design`
- `dashboard-review`
- `data-quality-audit`
- `data-readiness-check`
- `git-guardrails`
- `git-worktree-audit`
- `spec-review`
- `wayfinder`
- `decision-log`
- `decision-memo`
- `describe-pr`
- `design-plan`
- `diagnose`
- `domain-modeling`
- `execute-phase`
- `execute-prd`
- `experiment-design`
- `external-tool-compatibility`
- `graph-first`
- `grill-with-docs`
- `handoff`
- `humanizer`
- `humanizer-exec`
- `implement`
- `improve-codebase-architecture`
- `incident-retro`
- `incident-triage`
- `lineage-audit`
- `metric-council`
- `metric-design`
- `metric-tree-review`
- `mock-data-generator`
- `okr-generator`
- `omc-reference`
- `post-mortem`
- `product-launch-checklist`
- `prompt-builder`
- `prototype`
- `receive-review`
- `reconcile-issues`
- `repo-audit`
- `resolving-merge-conflicts`
- `review-scaffolding`
- `rowan` *(excluded from the D-006 retirement 2026-08-18 — revived by PR #149; direction vs `brain-ops` flagged, see AUDIT_REPORT.md)*
- `run-backlog`
- `runbook-author`
- `setup-skills`
- `setup-worktree`
- `slack-update`
- `sql-review`
- `stage-v1-concept`
- `strategic-analysis-review`
- `tdd`
- `to-issues`
- `to-prd`
- `triage`
- `user-journey-qa`
- `v1-system-design`
- `v1-workflow`
- `vendor-council`
- `watch-ci`
- `workflow-autonomous-backlog`
- `workflow-build-one` *(tombstone redirect since 2026-08-18 — merged into `workflow-deliver`, D-006 #11; directory removed in Phase 4/5)*
- `workflow-debug` *(tombstone redirect since 2026-08-18 — merged into `workflow-deliver`, D-006 #11; directory removed in Phase 4/5)*
- `workflow-deliver`
- `skill-system-audit`
- `workflow-executive-doc`
- `workflow-feature`
- `workflow-finalize`
- `workflow-review`
- `workflow-roadmap`
- `workflow-router`
- `write-a-skill`
- `zoom-out`

Audit rule going forward: do not archive a skill merely because it is absent from always-loaded `CLAUDE.md`. Prove non-use from actual invocation history, replacement coverage, and user approval.
