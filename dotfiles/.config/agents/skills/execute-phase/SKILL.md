---
name: execute-phase
disable-model-invocation: true
description: Retired (D-006 planning-lane consolidation, 2026-08-19). Do not invoke; phased work is a to-prd migration-mode parent issue executed by execute-prd, and a single slice runs workflow-deliver.
---

# Execute Phase — retired

Retired on 2026-08-19 (D-006 planning-lane consolidation; evidence: zero invocations over the full `skill-invocations.log` span, and post-#168 all slices route through `workflow-deliver`). Phased refactor/migration sequencing now lives as a `to-prd` migration-mode parent issue with ordered children — there is no separate phase runner. For any work that would have routed here, Load and run `execute-prd/SKILL.md` against the migration-mode parent issue tree; for one lone slice, Load and run `workflow-deliver/SKILL.md`. `references/` stays in place behind this tombstone (historical phase-run artifacts under `docs/executions/.phase-runs/` keep their documented format) until a later sweep rewires long-tail callers; do not add content here.
