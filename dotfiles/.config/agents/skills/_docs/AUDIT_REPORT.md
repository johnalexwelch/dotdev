# Skill Audit Report

Date: 2026-06-21 (updated #48)
Root: `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills`

## Status

Superseded archive report from 2026-06-21 restore (see "Verified Restore" section below).

This document now serves as the canonical home for skill **overlap and consolidation candidates** awaiting formal retirement decisions.

## Skill Overlap and Consolidation Candidates

Retirement executed 2026-08-18 per D-006 decision 14 (human provenance; explicit approval per the corrected audit rule below). Precondition met: `~/.claude/logs/skill-invocations.log` greped 2026-08-18 — zero invocations of any of the 6 names in the log's full span (log begins 2026-07-20; all `review` hits were suffix false-positives such as `clarity-review`/`workflow-review`).

### Retirement-Leaning Skills (Status: Resolved 2026-08-18)

From workflow-router `## Catalog tier` section — self-declared superseded, now formally retired (directories deleted; git history is the tombstone):

| Stub Skill | Successor | Rationale | Status |
|-----------|-----------|-----------|--------|
| `pr-responder` | `receive-review` (Step 2 of `workflow-finalize`) | Restates reviewer-comment handling as a standalone entry point; receiver-review already covers this within workflow-finalize | Retired 2026-08-18 (D-006 d14); directory deleted |
| `pr-review` | `workflow-review` | PR code review gate; workflow-review is the authoritative review orchestrator | Retired 2026-08-18 (D-006 d14); directory deleted |
| `review` | `workflow-review` | Legacy alias for PR code review; workflow-review is the authoritative review orchestrator | Retired 2026-08-18 (D-006 d14); directory deleted |
| `slop-cleaner` | `humanizer` | Text de-AIing and clarity improvement; humanizer owns the full polish workflow | Retired 2026-08-18 (D-006 d14); directory deleted |
| `v1-idea-grill` | `grill-with-docs` (V1 mode) | V1 product discovery and interrogation; grill-with-docs replaced v1-idea-grill with full HITL/Delegate modes | Retired 2026-08-18 (D-006 d14); directory deleted |
| `rowan` | ~~`brain-ops`~~ (stale — direction reversed) | This row was stale: PR #103 (2026-07-24) stubbed rowan → brain-ops, but PR #149 (2026-08-14) reversed it — `rowan/SKILL.md` is the live knowledge-OS skill and `brain-ops/SKILL.md` now carries the "DEPRECATED — use /rowan" header | **EXCLUDED from the 2026-08-18 retirement; flagged for Alex** — deleting rowan would remove the only live brain-route skill. Decide direction (rowan vs brain-ops), then retire the loser |

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
