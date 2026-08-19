# Skill Root Manifest

Status: restored after 2026-06-21 audit correction.

The prior keep rule was too narrow: on-demand skills are intentionally absent from always-loaded `CLAUDE.md`, but still earn their keep across development, data, writing, planning, and creative workflows.

Active skills:

- `airflow-failure-rca`
- `analysis-council`
- `analysis-design`
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
- `design-plan` *(tombstone redirect since 2026-08-19 — folded into `to-prd` migration mode, D-006 planning-lane consolidation; directory removed in a later sweep)*
- `diagnose`
- `domain-modeling`
- `execute-phase` *(tombstone redirect since 2026-08-19 — retired, phased work runs as a `to-prd` migration-mode parent via `execute-prd`, D-006 planning-lane consolidation; directory removed in a later sweep)*
- `execute-prd`
- `experiment-design`
- `external-tool-compatibility`
- `graph-first`
- `grill-with-docs`
- `handoff`
- `humanizer`
- `humanizer-exec` *(tombstone redirect since 2026-08-19 — folded into `humanizer` exec mode, consolidation batch 2; directory removed once callers are rewired)*
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
- `rowan` *(the live knowledge-OS skill; its predecessor `brain-ops` was retired 2026-08-18 — corpus-optimization audit batch 1, Alex-approved — see AUDIT_REPORT.md)*
- `run-backlog`
- `runbook-author`
- `setup-skills`
- `setup-worktree`
- `slack-update`
- `sql-review`
- `stage-v1-concept` *(tombstone redirect since 2026-08-19 — folded into `v1-workflow` Step 2.25, consolidation batch 2; directory removed once callers are rewired)*
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
