# Session Reflection: MDR/district OBT build-out — scope drift, layering pushback, shipped-but-wrong comment
**Date**: 2026-07-22
**Goal**: Reconcile dim_districts/daily_district_summary parity, fix the resulting engagement-count bug, then build the MDR staging→conform→marts pipeline toward the district OBT rewrite.

## What Went Well
- The 6-lane `taskflow` `workflow-review` (security/logic/test/style/architecture/docs) run before calling the MDR+engagement work "done" caught real defects a single pass would likely have missed: a factually wrong code comment about SCD2 behavior, a snapshot `unique_key` grain bug, and a regression test that didn't actually detect its target bug. Worth keeping as the default gate before closing out a data-pipeline change, not just an audit-on-failure step.
- When blocked on MDR source access, kept building the parts that didn't need it (staging models, conform logic against known schemas) instead of stalling, then resumed the blocked parts once access landed.
- Validated hypotheses against live Redshift repeatedly rather than trusting inference alone — e.g. confirmed `stg_dim_schools__type2__deleted_events` exists before finalizing the SCD2 point-in-time claim (see Corrections #3), and hand-verified row-window-overlap counts before committing to the final regression-test shape.

## What Went Wrong / Friction
- Picked a comparison target for the reconciliation task by column-name similarity twice before landing on the structurally-correct one (`dim_districts` → `fct_district_daily_teacher_engagement` → `agg_district_daily`), each requiring a user correction. No lineage/ref-graph check was done up front to see which model in the DAG actually produces the numbers being compared.
- Jumped to implementation on an ambiguous multi-phase ask; user had to say "I did not ask for implementation yet," and the written files had to be reverted.
- Argued a naming-convention placement (staging vs. `int_`) with the user for two rounds before conceding staging should fully conform names — there's no written rule in the repo the agent could point to, so it improvised and got it backwards on the first pass.
- Repeated dbt CLI friction: `dbt: command not found` locally, wrong `--state` path tried twice (`../../prod_artifacts` before finding the real `prod_artifacts/manifest.json`), and the working venv (`.venv-dbt`) had to be discovered rather than being obvious.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | Comparison target was wrong (dim_districts, then the wrong fact table) before landing on `agg_district_daily` | No lineage trace before writing comparison SQL — picked models by column-name match, not by tracing which model actually feeds the reporting numbers | `reconcile-tables` (should mandate a `ref()`/lineage check before authoring comparison queries) |
| 2 | "I did not ask for implementation yet" — files were written and had to be reverted | Ambiguous multi-phase request defaulted to "build" instead of confirming plan-vs-build mode | no current skill owns this; candidate for a habits.md note on scoping ambiguous asks |
| 3 | Shipped code comment claimed `dim_schools.deleted` "is not point-in-time tracked"; later self-discovered via review that it IS a tracked Type-2 attribute (`stg_dim_schools__type2__deleted_events`) | Asserted SCD2 column behavior from semantic inference instead of checking the actual event-stream/SCD2 generator inputs first | none currently; general ground-truth-over-proxy discipline for SCD2 claims |
| 4 | Naming-cleanup layer placement (staging should conform names, not `int_`) needed two rounds of pushback | No written repo rule distinguishing "staging conforms names/types" from "`int_` owns business logic only" | `sql-standards` or a repo dbt-conventions doc — candidate addition |

## Lessons
1. **Trace lineage before writing a reconciliation query.** When asked to compare "table A" against "table B," resolve which DAG node actually produces the comparable metric via `ref()`/manifest lineage before writing SQL — column-name similarity picked the wrong node twice in one session.
2. **A regression test must be proven red pre-fix, not just green post-fix.** The first deleted-filter regression test (distinct school count) was insensitive to the bug it targeted; it only became a real regression test after being redesigned at the SCD2-row-window-overlap grain and manually checked against both old and new behavior.
3. **Don't assert SCD2 tracking behavior from column semantics — check the event-stream inputs.** A wrong "not point-in-time tracked" claim was written into a shipped comment and only caught by a later independent review lane, not by re-derivation during authoring.

## Proposed Improvements
- [ ] `reconcile-tables/SKILL.md` — add a step requiring lineage/`ref()` confirmation of the comparison target(s) before authoring the comparison query, given this misfired twice in one session (priority: med)
- [ ] `sql-standards` (or a new dbt-conventions doc) — codify "staging fully conforms source names and types; `int_`/marts must not re-alias source-derived names" so this doesn't need re-litigating per model (priority: med)
- [ ] `docs/agents/habits.md` — add a note: on ambiguous multi-phase requests, confirm plan-vs-build mode before writing files (priority: low; single occurrence this session, but the revert cost was real)

## Skill Extraction Candidates
- **Proposed skill**: `legacy-model-parity-port` · **target**: new skill, or steps folded into existing `dbt`/`reconcile-tables` · **invocation**: model|user
  - **Trigger / leading word**: porting a legacy `reporting_*`/ad-hoc model into the layered staging→intermediate→mart dbt architecture with a parity requirement against the old table
  - **Inputs**: legacy SQL model(s), raw source table (schema via `svv_redshift_columns`/`information_schema` when not yet documented), target architecture pseudocode/design doc if one exists
  - **Steps**: (1) read legacy model(s) fully to extract decode/business logic verbatim; (2) confirm real source column list/types directly against Redshift metadata, don't trust assumed names; (3) build a thin 1:1 staging wrapper — cast/rename only, no business logic; (4) port decode/heuristic logic into an `int_` conform layer, preserving legacy behavior unless a bug is found; (5) build mart(s) as siblings off the conform layer, never looping marts back into intermediate; (6) reconcile new output against the legacy table row-for-row and document/explain any diff; (7) lint with `sql-standards`, add grain-appropriate `unique`/`not_null` tests
  - **Success criteria**: new model(s) compile, pass tests, and any diff vs. the legacy table is explained (not just measured)
  - **Constraints / pitfalls**: don't assume decode logic is bug-free just because it's "legacy" — validate diffs before writing them off as pre-existing quirks; keep naming cleanup in staging, not `int_` (see Lesson/Correction #4)
  - **Verification evidence**: this session ported MDR buildings/school-leaders through exactly this flow (staging → `int_mdr__conform` → `dim_mdr_districts`/`dim_mdr_schools`/`dim_mdr_charter_networks`), landed at parity on 2 of 3 marts with the third diff explained by a real fix
  - **Quality gate**: googleable=No · specific=Yes · real-effort=Yes
  - **Open questions**: this pattern will very likely recur for every remaining legacy model in the district/Salesforce OBT rewrite (per `docs/districts/district-transformation-pseudocode.md`) — worth a real skill, but routing (new skill vs. extending `dbt`/`reconcile-tables`) needs a decision, not assumed here
