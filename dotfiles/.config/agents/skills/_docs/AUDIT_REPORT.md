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
| `brain-ops` | `rowan` | Direction resolved: PR #103 (2026-07-24) stubbed rowan → brain-ops, PR #149 (2026-08-14) reversed it — `rowan/SKILL.md` is the live knowledge-OS skill and brain-ops carried the "DEPRECATED — use /rowan" tombstone header since. Pre-delete coverage check (2026-08-18): rowan documents the live `brain` CLI surface (ingest, query, get-page, watch, today, lint, review-queue); brain-ops's four archived-only commands (`capture`, `ingest-dry`, `review --apply`, `export`) no longer exist in the CLI itself — no capability lost. Zero brain-ops invocations across the full skill-invocations.log span (2026-07-20 → 2026-08-18) | Retired 2026-08-18 (corpus-optimization audit batch 1; Alex explicit approval 2026-08-18 per the corrected audit rule); directory deleted. `rowan` kept as the live successor |

### Consolidation Batch 2 (Status: Resolved 2026-08-19)

Alex-approved per-item (2026-08-19). Evidence: `~/.claude/logs/skill-invocations.log` (2026-07-20 → 2026-08-19 span) — zero invocations ever of `herdr`, `herdr-launch`, `humanizer-exec`, `stage-v1-concept`, `find-skills`, `decision-memo`; `humanizer` 8, `deep-research` 1. Also examined and explicitly KEPT: the retro trio and `graph-first`.

| Skill | Disposition | Status |
|-------|-------------|--------|
| `herdr-launch` | Merged into `herdr` (§ Companion tools by delivery stage); pair was 673 lines with zero invocations, merged skill slimmed to <250 | Tombstone redirect 2026-08-19; retirement candidate if still zero-use at next audit (herdr auto-naming extension covers the automatic case) |
| `humanizer-exec` | Folded into `humanizer` § Exec mode (exec-register table, sharpen-don't-reorganize scope, no-fabricated-headline gate); `workflow-executive-doc` rewired | Tombstone redirect 2026-08-19 |
| `stage-v1-concept` | Folded into `v1-workflow` Step 2.25 (Stage the Concept); `grill-with-docs` promotion handoff rewired | Tombstone redirect 2026-08-19 |
| `find-skills` | Kept; description now claims canonical status over the `meta-skills:find-skills` plugin twin (plugin isn't ours to remove) | Resolved 2026-08-19 (seam sentence) |
| `deep-research` | Kept; description now names the engine boundary vs `meta-skills:deep-research` (Claude-native AFK web research vs OpenAI Deep Research API) | Resolved 2026-08-19 (seam sentence) |
| `decision-memo` / `workflow-executive-doc` | Both kept; mirror seam sentences added (single decision → one-pager vs full memos/board docs); exec-doc polish step now explicitly runs `humanizer` exec mode and its decision sections compose `decision-memo` | Resolved 2026-08-19 (seam sentences) |

### Planning-Lane Consolidation (Status: Resolved 2026-08-19)

Executed per the D-006 planning-lane consolidation decision (Alex approval 2026-08-19; corrected-audit-rule preconditions met: invocation history greped 2026-08-19 — `design-plan` 1 invocation (2026-07-20), `execute-phase` 0, `execute-prd` 1 (2026-07-31) over the log's full span; replacement coverage stated below; rollback = tombstone revert, directories kept):

| Skill | Successor | Rationale | Status |
|-------|-----------|-----------|--------|
| `design-plan` | `to-prd` migration mode | Two parallel planning formalisms (phased plan file vs. PRD + issue tree) for one job; post-#168 all slices route through `workflow-deliver`, so the distinct value (FIND-NN/REQ-NN anchors, phased sequencing, pilot/canary, rollback, sync gates) moved into `to-prd` as migration-mode deltas | Tombstone redirect 2026-08-19; directory (incl. `references/`) removed in a later sweep |
| `execute-phase` | `execute-prd` (tree) / `workflow-deliver` (single slice) | Phase runner duplicated `execute-prd`'s dependency orchestration at a different altitude; zero invocations over the full log span | Tombstone redirect 2026-08-19; `references/` kept behind the tombstone for historical `.phase-runs/` artifact formats |

`execute-prd` retained: it orchestrates dependency-ordered issue trees *above* the `workflow-deliver` unit loop — a different altitude, not a duplicate. An `execute-prd`/`run-backlog` merge is deferred pending boundary-confusion evidence.

### Consolidation Opportunities (Exploratory)

These are **not** deprecated but may benefit from closer collaboration or refactoring:

| Skill Group | Observation | Next Step |
|-------------|-------------|----------|
| Decision documentation | `decision-log` (log decisions) vs. `decision-memo` (shape for exec) | Partially resolved 2026-08-19 (batch 2): decision-memo ↔ workflow-executive-doc seam recorded in both descriptions. Remaining: is decision-memo always a follow-up to decision-log? (`design-plan` removed from this group — consolidated into `to-prd` migration mode 2026-08-19, see the Planning-Lane Consolidation table above) |
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
- Redirect stubs deleted 2026-08-18 per D-006 d14 (`pr-responder`, `pr-review`, `review`, `slop-cleaner`, `v1-idea-grill`); `rowan` live, excluded — see retirement table above
- SKILL-MANIFEST.md references every active skill by exact name
