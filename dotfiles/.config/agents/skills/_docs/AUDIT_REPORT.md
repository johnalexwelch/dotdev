# Skill Audit Report

Date: 2026-06-21
Root: `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills`

## Status

Superseded. The initial archive pass was too narrow and has been reversed.

Reason: many skills are intentionally on-demand for development, data analysis, writing, planning, and creative work. Absence from always-loaded `CLAUDE.md` is not evidence of non-use.

## Current State

- Active skill directories: 74
- Archived skill directories: 0
- Archive path `_archive/2026-06-21/`: removed after restore
- `omc-reference/SKILL.md`: restored to tracked version
- `workflow-router/SKILL.md`: restored to tracked version
- `CLAUDE.md`: added as a manifest of active skills

## Restored

All previously archived skills were restored:

- `analysis-council`
- `analysis-design`
- `brain-ops`
- `caveman`
- `clarity-review`
- `council-scaffolding`
- `dashboard-design`
- `dashboard-review`
- `data-quality-audit`
- `data-readiness-check`
- `decision-log`
- `decision-memo`
- `design-plan`
- `experiment-design`
- `graph-first`
- `grill-with-docs`
- `handoff`
- `humanizer`
- `humanizer-exec`
- `improve-codebase-architecture`
- `incident-retro`
- `incident-triage`
- `lineage-audit`
- `metric-council`
- `metric-design`
- `metric-tree-review`
- `mock-data-generator`
- `okr-generator`
- `post-mortem`
- `pr-responder`
- `product-launch-checklist`
- `prototype`
- `review`
- `review-scaffolding`
- `runbook-author`
- `setup-skills`
- `slack-update`
- `slop-cleaner`
- `sql-review`
- `strategic-analysis-review`
- `to-issues`
- `to-prd`
- `triage`
- `user-journey-qa`
- `v1-idea-grill`
- `v1-system-design`
- `v1-workflow`
- `vendor-council`
- `workflow-autonomous-backlog`
- `skill-system-audit`
- `workflow-executive-doc`
- `workflow-feature`
- `workflow-roadmap`
- `write-a-skill`
- `zoom-out`

## Corrected Audit Rule

Do not prune on-demand skills using only always-loaded references.

Future pruning needs all of:

- actual invocation or usage history
- replacement coverage by another active skill or workflow
- explicit user approval for each archive batch
- a rollback path

## Verification

- Active skill count restored to 74.
- No `_archive/2026-06-21/` skill archive remains.
- `CLAUDE.md` references every active skill by exact name.
