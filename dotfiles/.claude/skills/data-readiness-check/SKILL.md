---
name: data-readiness-check
model: haiku
reasoning: high
description: "Before an analysis or metric, checks whether the needed data exists, is fresh, correctly grained, and governed for the use. Catches analyses that assume missing/stale/off-limits data. Use as the first check in analysis-design or before depending on an unverified source."
---

# Data Readiness Check

## Purpose

Half of "this analysis is slow" or "this metric doesn't make sense" is data that was assumed but never verified. This skill verifies — before any SQL — that the data needed exists, is fresh, is at the right grain, and is governed for the use case.

## When to invoke

- Embedded in `analysis-design` (run before locking the analytical plan)
- "Do we have the data for X?"
- "Is the <source> still fresh?"
- Before any analysis or metric that depends on an unfamiliar source

Routing:
- Lineage trace upstream → `lineage-audit`
- Active SQL review → `sql-review`
- Quality issues across the warehouse → `data-quality-audit`

## What it checks

| Category | Checks |
|----------|--------|
| **Existence** | Does the table / view / source actually exist? In which schema / database? |
| **Freshness** | When was the last write? Is it on-schedule? Is the freshness SLA met? |
| **Grain** | What's the unit of one row? Per-user-per-day? Per-event? Per-session? Mismatch is silent. |
| **Completeness** | Are recent partitions present? Are there gaps in the time series? |
| **Population coverage** | Does the source cover the audience the analysis targets — or just a subset? |
| **Definitional drift** | Has the source's schema or semantics changed recently? Any column renames, type changes, NULL-pattern changes? |
| **Volume sanity** | Row count vs. expected. Order of magnitude check. |
| **Governance and consent** | Is the data covered by the consent / contract for this use? COPPA / FERPA / GDPR / vendor-data restrictions? |
| **Joinability** | Does the source join cleanly to other sources the analysis will use? On what key? Is the key stable? |
| **Documentation** | Is the source documented? Is it the "official" source vs. a shadow copy? |

## Process

### 1. Identify the planned sources

From the analysis brief or user's question, list every table / model / source the analysis will touch.

### 2. Check existence + freshness

For each source:
- Does it exist? In what schema?
- When was the last write? Is the freshness SLA met?
- Are recent partitions present?

If a source is missing or stale, surface it as a blocker before the analysis proceeds.

### 3. Check grain

What's the unit of one row? Force a precise answer. Then check: does the analysis plan match this grain?

Common bug: analysis assumes per-user grain, source is per-event. The analyst joins and gets fanout.

### 4. Check population coverage

If the analysis targets "all teachers," does the source actually cover all teachers? Or only logged-in / active / a specific tier?

### 5. Check governance

For the use case (analyst exploration, board memo, vendor share, public report) — is the data governed for it?

- COPPA-bound under-13 data
- FERPA-bound student records
- Vendor-data with use restrictions
- Aggregation thresholds for small cells

### 6. Check joinability

If the analysis joins multiple sources, do the join keys exist and behave consistently?

### 7. Output

```markdown
## Data Readiness Check: <analysis title>

### Headline
<one sentence: ready | blocked by <X> | partial readiness with caveats>

### Source-by-source
| Source | Exists | Fresh | Grain | Coverage | Governance | Joinable | Verdict |
|--------|--------|-------|-------|----------|------------|----------|---------|
| <table> | ✓/✗ | ✓/⚠/✗ | <unit> | <scope> | <legal basis> | ✓/✗ | green / yellow / red |

### Blockers (red)
- <source X is missing / stale / off-limits — what to do before the analysis proceeds>

### Cautions (yellow)
- <source has caveats but is usable — what to acknowledge in the analysis>

### Open questions
- <ambiguities to resolve before locking the plan>

### Recommended next step
- proceed | proceed with caveats | resolve blocker via <X>
```

## Rules

- Run before, not during, the analysis. The point is to catch problems before they shape conclusions.
- "Off-limits for this use case" is a real verdict — don't let governance issues become silent.
- Grain mismatch is the #1 silent bug. If you can't state the grain in one sentence, that's the first finding.
- A red verdict halts the analysis until resolved or explicitly accepted. A yellow verdict requires acknowledgment in the analysis output.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Planned sources**: each source's freshness contract, owner, consent classification
- **Lineage**: where each source comes from (so upstream stale-ness is visible)
- **Prior readiness checks** on these sources — recurring issues, known caveats
- **Cross-source joinability**: graph edges showing which sources have stable join keys

Insertion point: step 2 (existence + freshness) is graph-driven if a graph is available. Tag findings as `[GRAPH]`.

`--no-graph` skips. `--graph` forces graphify on the warehouse / dbt project first.

## Contract

Consumes: analysis brief or source list + use case
Produces: readiness verdict + per-source assessment + blockers + cautions
Requires: ability to introspect warehouse (graphify, lineage tool, or warehouse query); fallback to user-provided info
Side effects: none
Human gates: red verdict blocks the analysis pipeline until resolved

## Context

Typical workflows: embedded in analysis-design; standalone before metric definition; pre-dashboard build
Pairs well with: lineage-audit (upstream of source), sql-review (downstream when SQL is being written), governance-reviewer persona (when consent is the blocker)
