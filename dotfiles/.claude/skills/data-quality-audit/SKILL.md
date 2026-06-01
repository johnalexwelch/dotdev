---
name: data-quality-audit
description: "Audits a table, model, or pipeline for data-quality issues: NULL rates, duplicates, schema drift, distribution shifts, referential integrity, late-arriving data, freshness drift. Produces a prioritized findings list with severity. Use for periodic audits or when an analysis turned up a weird number."
---

# Data Quality Audit

## Purpose

Surface data quality issues in a structured way before they corrupt downstream analyses or dashboards. Most data quality issues are silent — the numbers look plausible until someone notices they don't add up.

## When to invoke

- Periodic audit of a critical source
- After an analysis produces a surprising number
- Before promoting a model to "blessed" / "trusted" status
- After upstream change ripples in

Routing:
- Per-query review → `sql-review`
- Lineage understanding → `lineage-audit`
- Readiness check before analysis → `data-readiness-check`
- Profile a single table → `data-engineering:profiling-tables`

## What it checks

| Category | Checks |
|----------|--------|
| **NULLs** | NULL rate per column — vs. expected, vs. historical baseline. Sudden spikes are silent corruption. |
| **Duplicates** | Primary-key violations, near-duplicates, identical rows. |
| **Distribution shifts** | Column distributions over time — sudden shifts indicate upstream change. |
| **Referential integrity** | Foreign keys point to existing rows in parent tables. |
| **Late-arriving data** | Rows arriving for partitions that should be closed; backfills not flagged. |
| **Schema drift** | Column added / removed / renamed without notice. Type changes. |
| **Freshness drift** | Refresh cadence has slipped. Expected hourly, actual every 3h. |
| **Cardinality drift** | Number of distinct values changed unexpectedly. |
| **Range / domain** | Values outside expected range (negative ages, future dates). |
| **Boolean / enum hygiene** | "active" / "Active" / "ACTIVE" / true / 1 — multiple representations of the same boolean. |
| **Time zone consistency** | Timestamps mixing UTC and local. Daylight-savings transitions. |

## Process

### 1. Scope the audit

Single table? A pipeline (source → transformed → consumed)? A model and its parents?

### 2. Pull profile stats

For each relevant table:
- Row count over time (last 30 days, last 1 year)
- NULL rate per column
- Cardinality per column
- Min/max for numeric and date columns
- Top 10 values per categorical column
- Duplicate rate (per PK candidate)
- Freshness (most recent partition / write)

Use `data-engineering:profiling-tables` if available, otherwise generate the queries.

### 3. Compare to baseline

If a baseline exists (last audit, last week, last quarter): flag deltas above threshold (e.g., NULL rate up 5pp, distinct values down 20%).

If no baseline: establish one. The audit's first run is the baseline.

### 4. Severity-rank findings

For each finding:
- **Critical**: silent data corruption with active downstream impact (e.g., duplicates in fact table, NULLs in load-bearing column, broken FK)
- **High**: drift that will misleading analyses if unaddressed (e.g., schema drift, distribution shift)
- **Medium**: hygiene issues that won't break analyses but compound over time (e.g., enum casing inconsistency)
- **Low**: documentation / stylistic findings

### 5. Output

```markdown
## Data Quality Audit: <scope>

### Headline
<one sentence: clean | hygiene issues | active corruption>

### Critical findings
- **<table.column>**: <issue>. Impact: <which downstreams>. Recommended action: <fix>.

### High findings
- ...

### Medium findings
- ...

### Low findings
- ...

### Profile summary
- Row count: <N> (vs. <baseline N>, delta: <X>%)
- NULL rate range: <column-min%> to <column-max%>
- Distinct-value range: <X to Y per column>
- Freshness: <last write timestamp + SLA compliance>

### Recommended cadence
- Re-audit: <weekly | monthly | quarterly>
- Add to monitoring: <which dimensions to alert on>

### Open questions
- ...
```

### 6. Persist

`.data-audits/quality/<scope>-<date>.md`.

## Rules

- Critical findings halt downstream uses of this data until resolved. Surface them prominently.
- Establish a baseline if none exists — single-run audits without baselines can only find structural problems, not drift.
- Don't catalog every NULL — focus on the columns where NULLs matter for analysis correctness.
- "Schema drift since last audit" is a finding even if the new schema is fine — silent schema changes are dangerous.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Target tables / columns**: schema-drift history, prior NULL-rate spikes, prior duplicate findings
- **Downstream consumers**: who depends on this asset (the audit's blast-radius scope)
- **Prior quality audits** on this asset — recurring patterns, known caveats
- **Related models** that share upstream sources — corruption signals may be correlated

Insertion point: step 3 (compare to baseline). Tag historical drift findings as `[GRAPH-HISTORY]`.

`--no-graph` skips graph history. `--graph` forces graphify on the warehouse first.

## Contract

Consumes: scope (table / pipeline / model)
Produces: severity-ranked findings + profile summary + recommended cadence
Requires: warehouse query access OR user-supplied profile data
Side effects: writes to .data-audits/quality/ + may add monitoring config (with confirmation)
Human gates: critical findings recommend halting downstream until resolved

## Context

Typical workflows: periodic audits, post-incident, pre-promotion to trusted-model status
Pairs well with: data-engineering:profiling-tables, lineage-audit, data-readiness-check, sql-review
