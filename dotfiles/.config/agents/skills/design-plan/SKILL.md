---
name: design-plan
disable-model-invocation: true
description: Superseded by to-prd migration mode (D-006 planning-lane consolidation, 2026-08-19). Do not invoke; Load and run to-prd/SKILL.md in migration mode instead.
---

# Design Plan — superseded

Folded into `to-prd` **migration mode** on 2026-08-19 (D-006 planning-lane consolidation; evidence: 1 invocation over the full `skill-invocations.log` span, and post-#168 all slices route through `workflow-deliver`). For any work that would have routed here — repo-audit findings, refactor/migration/governance briefs — Load and run `to-prd/SKILL.md` in migration mode (FIND-NN/REQ-NN anchors, parent + ordered children, pilot/canary slice, rollback expectations, sync-gate child issues), then `to-issues` → `triage` → `execute-prd`. This directory (including `references/`) remains only until a later sweep rewires long-tail callers; do not add content here.
