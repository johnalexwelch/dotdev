# Session Reflection: AE-152 sales-page Iceberg migration — review, decision, doc

**Date**: 2026-08-06
**Goal**: Document the migration, run a multi-lane review, settle ownership, and produce a vault walkthrough doc.

## What Went Well

- 7-lane parallel `workflow-review` (logic, backcompat, tests, syntax, acceptance, docs, security) surfaced two real blockers a single-pass review would likely miss: the `created_at_precise` semantic shift and the `processed_trial_or_direct_sub` orphaned unique_key.
- Grounding claims in live Redshift profiles (59 hash collisions, all-null metadata_super fields) turned reviewer objections into evidence-backed answers instead of speculation.
- Ownership decision hit rung 1 of the ladder: the CODEOWNERS "addition" was policy-blocked and the dir was already gated, so the correct action was *no file change* plus a recorded decision. Avoided a rejected edit.
- Three-skill doc pipeline (clarity → humanizer → i-have-adhd) drove the vault doc to 0 mechanical tells with a deterministic gate.

## What Went Wrong / Friction

- Two documentation corrections in a row (profiling numbers drift; metadata_super descriptions not meaningful) both trace to the same skill and both were caught by the *user*, not by the skill's own checks.
- Initial `created_at` / `created_at_precise` docs described a "microsecond copy," which was wrong; only the logic-review lane caught the semantic reality. The doc pass trusted a plausible-sounding proxy over the source schema.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | Don't quote profiling stats in docs (they drift) | skill allowed hardcoded profile numbers | `document-dbt-model` (fixed this session) |
| 2 | `metadata_super.account_type`-style descriptions aren't useful | skill didn't forbid path-echo descriptions strongly enough | `document-dbt-model` |
| 3 | Column-name changes would break 150+ children; keep names (order doesn't matter) | no reflex to preserve the downstream NAME contract | (gap — see below) |
| 4 | Column ORDER does not need preserving | I wrongly claimed `on_schema_change='fail'` made order a contract; dbt compares names as a set, order-insensitive | this reflection |

## Lessons

1. **`on_schema_change='fail'` compares column NAMES as a set, not order.** Reordering the SELECT is safe; only added/removed columns trip `fail`. Commit `cb39cda03` (restoring prod order) was therefore unnecessary — harmless but not required. Preserve names/types for the 150+ downstream children; order is free to change.
2. **For timestamp remaps, read the source schema before writing the description.** The "microsecond copy" error came from reasoning about intent instead of checking that legacy `created_at` was midnight-truncated and `createdatprecise` held the real time.
3. **A blocked mechanism can be the right answer.** CODEOWNERS "leave ungated + record decision" beat forcing an edit the repo policy rejects.

## Proposed Improvements

- [ ] `document-dbt-model/SKILL.md` — add an explicit check: descriptions must not echo the source path/lineage (`metadata_super.X`); require a semantic meaning grounded in profiled values. (priority: med) — evidence: correction #2.
- [ ] `document-dbt-model/SKILL.md` — for timestamp/derived columns, require reading the source schema/sample before describing semantics, not inferring from the name. (priority: med) — evidence: the "microsecond copy" error.
- [ ] Migration-review checklist (owning skill: `workflow-review` or a dbt-specific lane) — when an incremental model redefines a `unique_key`, check every downstream model that reuses that key. (Column *order* is NOT a concern: `on_schema_change` is name-set based.) (priority: high) — evidence: the `processed_trial_or_direct_sub` orphaned-key blocker.

## Skill Extraction Candidates

_None.* The doc pipeline and review lanes are existing skills; the migration gotchas are enhancements to `document-dbt-model` / review, not a new repeatable skill. Column-order + downstream-key checks are two checklist items, not a workflow worth its own skill.
