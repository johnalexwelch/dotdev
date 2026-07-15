# Analysis structure — the standard

Single source of truth for how analyses are persisted. Grounded in RAP
(UK Gov Reproducible Analytical Pipelines) + Cookiecutter Data Science.
Scaffold with `new-analysis.sh <slug>`; both live in this `_docs/` dir.

## Where analyses live

One dedicated `analyses/` repo, one top-level dir per analysis:
`<yyyy-mm-dd>-<slug>/`. Not inside the iris app repo. Not one repo per
analysis — promote a *single* analysis to its own repo with CI only when it
becomes a recurring published pipeline (RAP Gold). Until then, one repo.

## Layout

```
<yyyy-mm-dd>-<slug>/
├── README.md          # provenance header + question + findings (the record)
├── run.sh             # ONE command regenerates outputs from raw → done
├── sql/               # every query, named, parametrized (:as_of, :region)
├── src/               # transform/analysis logic (scripts, not notebooks)
├── notebooks/         # presentation ONLY — import from src/, no hidden logic
├── data/              # gitignored (PII/secrets boundary); regenerable
│   ├── raw/           #   immutable pull, READ-ONLY
│   └── interim/       #   intermediate, regenerable
├── outputs/           # charts/tables/report (tracked; no data dumps)
└── requirements.txt   # or uv.lock — pinned deps
```

## Provenance header (top of README.md)

```yaml
question:   "Did X drive Y in Q2?"
author:     alex
date:       2026-07-07
as_of:      2026-06-30          # data snapshot date
sources:    [iris.golden.orders@v3, warehouse.events]
metrics:    [gross_margin@metric-tree v2]   # cite versions; don't re-derive
git_sha:    <commit that produced outputs/>
decisions:                      # human judgment as explicit params, not prose
  cohort:   "signed_up 2026-01..2026-03, teacher segment only"
  excluded: "test accounts (is_internal), refunds"
  window:   "trailing 90d"
  rejected: "per-school cohorting (n too small); LTV proxy (no revenue join yet)"
fingerprint:                    # the real reproducibility anchor (see below)
  rows:     18342
  checksum: sha256:ab12…        # of the sorted extract
  headline: {gross_margin: 0.412, n: 18342}
findings:   "3-line answer. The number. The caveat."
```

## The three rules that make it reproducible

1. **SQL is persisted, named, parametrized.** No query lives only in a
   notebook cell or shell history. `:as_of` makes re-runs deterministic.
2. **Notebooks import, never define.** Logic in `src/` so it's diffable and
   testable. This is the #1 reproducibility killer.
3. **`run.sh` regenerates outputs from raw.** If it doesn't run clean, the
   analysis isn't reproducible. This is the RAP Baseline→Silver line.

## Why a fingerprint, not just `as_of`

Warehouses mutate history — backfills, late-arriving rows, and COPPA/FERPA
**deletions**. Re-running the same SQL at the same `as_of` later returns
*different rows* (deleted users are gone). So the record of record is the
**fingerprint** (row count + checksum + headline aggregates), not the raw
data. "Reproduce" = regenerate and diff the fingerprint; drift from deletions
is then *visible*, not silent. The raw extract stays in `data/` (gitignored) —
never commit row-level/PII data.

## Tie-out (the analysis equivalent of a test)

Before an analysis is "done", assert the headline number in `findings`
matches what the persisted SQL actually returns. A clean council review with
an unverified number still passes today — this closes that. Cheapest form:
one line in `run.sh` that recomputes the headline and `diff`s it against
`fingerprint.headline`, exiting non-zero on mismatch.

## How the skills plug in

- `analysis-design` **writes into** this structure (scaffold first, then fill).
- `analysis-council` + tie-out **read the provenance header** — `as_of`,
  `sources`, `metrics`, `decisions` feed graph-first ingestion for free
  (structured provenance, not re-derived from prose).
