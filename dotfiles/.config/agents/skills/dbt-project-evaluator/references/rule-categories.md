# dbt_project_evaluator rule categories

Test-name pattern → category → what a failure means → typical fix. Model names below (`stg_`, `int_`, `fct_`, `dim_`) follow the package's own convention naming (staging/intermediate/marts) — map them to whatever layer naming the target project actually uses.

| Test name pattern | Category | What a failure means | Typical fix |
|---|---|---|---|
| `fct_undocumented_models` | Documentation coverage | Model has no description in its `.yml` | Add a `description:` to the model's schema entry |
| `fct_undocumented_source_columns` | Documentation coverage | Source column has no description | Add column-level descriptions to the source `.yml` |
| `fct_missing_primary_key_tests` | Testing coverage | Model has no unique/not-null test on its grain column | Add `unique` + `not_null` tests on the primary key |
| `fct_test_coverage` | Testing coverage | Project-wide test coverage % below threshold | Prioritize marts/exposed models first |
| `fct_direct_join_to_source` | Staging/marts layering | A non-staging model joins directly to a `source()` instead of a `stg_` model | Introduce or reuse a staging model between the source and the join |
| `fct_rejoining_of_upstream_concepts` | Staging/marts layering | A model re-joins to an ancestor it already has (directly or transitively) upstream | Restructure to pull the needed column through the existing lineage path instead of a fresh join |
| `fct_model_fanout` | Fanout | A model has downstream dependents in more than one packages/layers, or a staging model feeds many marts directly | Introduce an intermediate model to consolidate before fanning out |
| `fct_multiple_sources_joined` | Source hygiene | A single model joins two or more sources directly | Stage each source separately, join the staging models instead |
| `fct_source_fanout` | Source hygiene | One source feeds many staging models | Usually fine if the source genuinely is shared raw data — flag but don't force a fix |
| `fct_staging_dependent_on_marts_or_intermediate` | Staging/marts layering | A `stg_` model depends on an `int_`/`fct_`/`dim_` model — backwards | Move the logic downstream or re-derive the staging model from raw sources only |
| `fct_marts_or_intermediate_dependent_on_staging_downstream` | Staging/marts layering | Same inversion, checked from the other direction | Same fix as above |
| `fct_root_models` | Layering | A mart/intermediate model has no ancestors at all (skips staging) | Add a proper staging layer underneath, or confirm it's intentionally a seed/root and document why |
| `fct_chained_views_dependencies` | Performance/layering | A chain of views (no tables/materializations) beyond the configured depth | Materialize an intermediate node in the chain as a table/incremental model |
| `fct_duplicate_sources` | Source hygiene | The same physical table is declared as a source more than once | Consolidate to one source declaration, repoint dependents |
| `fct_unused_sources` | Source hygiene | A declared source has no models built on top of it | Remove the source declaration, or confirm it's reserved for near-term work |
| `fct_hard_coded_references` | Modeling hygiene | A model references a table by hardcoded string instead of `ref()`/`source()` | Replace the hardcoded reference with `ref()` or `source()` |
| `*_naming` / `fct_*_naming_conventions` | Naming conventions | Model/column name doesn't match the configured prefix rules (e.g. `stg_`, `int_`, `fct_`, `dim_`) | Rename the model/column (check for downstream `ref()` breakage first) |

## Notes

- Categories above are the package's own groupings (its `models/marts/` structure) — do not invent new ones when a failure doesn't fit; report it under "Not evaluated" instead and quote the raw test name.
- The package's naming-convention and layering rules are configurable via `dbt_project.yml` vars (e.g. `models` prefixes). Check the project's actual var overrides before flagging a naming violation as a bug — it may be intentional divergence from the package defaults.
- Row/record counts in `fct_model_fanout`, `fct_source_fanout`, and `fct_duplicate_sources` failures are useful severity signals — a fanout of 2 is a note, a fanout of 20 is a priority fix.
