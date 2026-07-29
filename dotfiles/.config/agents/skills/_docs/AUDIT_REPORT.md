# Skill Audit Report

Date: 2026-06-21 (updated #48)
Root: `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills`

## Status

Superseded archive report from 2026-06-21 restore (see "Verified Restore" section below).

This document now serves as the canonical home for skill **overlap and consolidation candidates** awaiting formal retirement decisions.

## Skill Overlap and Consolidation Candidates

These skills are **intentionally retained as redirect stubs** until explicit user approval + invocation history confirms archival readiness.

### Retirement-Leaning Skills (Status: Redirect Stubs, Awaiting Approval)

From workflow-router `## Catalog tier` section — self-declared superseded, not formally retired:

| Stub Skill | Successor | Rationale | Status |
|-----------|-----------|-----------|--------|
| `pr-responder` | `receive-review` (Step 2 of `workflow-finalize`) | Restates reviewer-comment handling as a standalone entry point; receiver-review already covers this within workflow-finalize | Awaiting formal archival approval |
| `pr-review` | `workflow-review` | PR code review gate; workflow-review is the authoritative review orchestrator | Awaiting formal archival approval |
| `review` | `workflow-review` | Legacy alias for PR code review; workflow-review is the authoritative review orchestrator | Awaiting formal archival approval |
| `slop-cleaner` | `humanizer` | Text de-AIing and clarity improvement; humanizer owns the full polish workflow | Awaiting formal archival approval |
| `v1-idea-grill` | `grill-with-docs` (V1 mode) | V1 product discovery and interrogation; grill-with-docs replaced v1-idea-grill with full HITL/Delegate modes | Awaiting formal archival approval |
| `rowan` | `brain-ops` | Brain/second-brain interaction; brain-ops owns the Karpathy-style knowledge workflow | Binary tombstoned 2026-07-20; awaiting formal archival approval |

### Consolidation Opportunities (Exploratory)

These are **not** deprecated but may benefit from closer collaboration or refactoring:

| Skill Group | Observation | Next Step |
|-------------|-------------|----------|
| Decision documentation | `decision-log` (log decisions) vs. `decision-memo` (shape for exec) vs. `design-plan` (roadmap-level decisions) | Clarify scoping: is decision-memo always a follow-up to decision-log? Is design-plan decision output always logged? |
| Audit/investigation | `repo-audit` (codebase evidence) vs. `improve-codebase-architecture` (deepening opportunities) vs. `deep-dive-review` (4-lens daily AFK) | Clarify entry points: when should each be invoked? Do they have non-overlapping gates? |
| Council workflows | `analysis-council`, `metric-council`, `vendor-council`, `worldbuilding-council` (if future) | Common scaffold (council-scaffolding), but each domain has specific pressure scenarios. Current design is sound; monitor for shared-rule emergence. |
| Product planning | `workflow-feature` (ambiguous idea → issues) vs. `workflow-roadmap` (multi-area sequencing) vs. `v1-workflow` (V1 full pipeline) | Clarify: does v1-workflow always use workflow-roadmap as step 3b, or is there a faster path? |

## Verified Restore (2026-06-21)

### Status

The initial archive pass was too narrow and has been reversed.

Reason: many skills are intentionally on-demand for development, data analysis, writing, planning, and creative work. Absence from always-loaded `CLAUDE.md` is not evidence of non-use.

### Restored

All previously archived skills were restored. See SKILL-MANIFEST.md for the complete active skill list.

### Corrected Audit Rule

Do not prune on-demand skills using only always-loaded references. Future pruning must have:

- Actual invocation or usage history
- Replacement coverage by another active skill or workflow
- Explicit user approval for each archive batch
- A rollback path

### Verification

- Active skill count: 74 + all on-demand catalog-tier skills
- No `_archive/2026-06-21/` skill archive remains
- Redirect stubs (`pr-responder`, `pr-review`, `review`, `slop-cleaner`, `v1-idea-grill`, `rowan`) retained as bridges
- SKILL-MANIFEST.md references every active skill by exact name
