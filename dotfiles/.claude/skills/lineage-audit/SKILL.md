---
name: lineage-audit
model: sonnet
description: Traces a metric, dashboard, or table backward to its upstream sources and forward to its downstream dependents. Surfaces orphan tables, single-points-of-failure, transformation logic risks, and dependents that may break if upstream changes. Use before refactoring a model, deprecating a table, or investigating a data incident.
---

# Lineage Audit

## Purpose

Before changing or deprecating any data asset, you need to know what feeds it and what it feeds. Lineage audits surface the dependency graph in a structured way and call out the risks.

This skill complements `data-engineering:tracing-upstream-lineage` and `data-engineering:tracing-downstream-lineage` — it adds a higher-level audit framing (risk, blast radius, recommended action) on top of the raw lineage data.

## When to invoke

- Before deprecating a table / view / model
- Before refactoring a model that may have many dependents
- After a data incident — to understand the blast radius
- "What feeds this dashboard?"
- "What breaks if I change this table?"

Routing:
- Just need the lineage data → `data-engineering:tracing-upstream-lineage` / `tracing-downstream-lineage`
- Quality issues per-source → `data-quality-audit`
- About to refactor → run this audit then `metric-tree-review` for affected metrics

## Process

### 1. Identify the asset

Table, view, model, metric, dashboard. What's the canonical name and schema?

### 2. Trace upstream (3–5 hops or until raw sources)

For each parent:
- What table / event source / external API
- Transformation logic between (filters, joins, aggregations)
- Freshness contract
- Owner

Stop at raw event sources OR at 5 hops (whichever first).

### 3. Trace downstream (3–5 hops or until terminal consumers)

For each child:
- What consumes this — model, dashboard, alert, vendor export, ML feature
- Owner
- Criticality (is this consumer load-bearing?)

### 4. Identify risk patterns

- **Single-point-of-failure**: one upstream feeds many critical downstreams
- **Hidden transformation**: business logic embedded in a CTE that's hard to find
- **Orphan**: model with no downstream consumers (delete candidate?)
- **Cycle**: downstream depending on its own upstream (shouldn't exist but does sometimes)
- **Cross-schema leak**: raw production data flowing into analytical without governance gate
- **Ownership gap**: no owner identified for a load-bearing model
- **Freshness mismatch**: downstream expects hourly, upstream refreshes daily

### 5. Output

```markdown
## Lineage Audit: <asset>

### Headline
<one sentence: safe to change | risky | depends-on-X-first>

### Upstream
```
<asset>
├── <parent 1> (owner: <X>, freshness: <Y>)
│   └── <grandparent 1> (...)
├── <parent 2>
│   └── ...
```

### Downstream
```
<asset>
├── <child 1> — <what it is, owner, criticality>
│   └── <grandchild 1>
├── <child 2>
```

### Risks identified
- **Single-point-of-failure**: <asset> feeds <N> critical downstreams; any change ripples
- **Hidden transformation**: filter logic in <model X> at <line>
- **Orphan candidate**: <model Y> has no downstream
- **Ownership gap**: <model Z> has no listed owner
- **Freshness mismatch**: <consumer A> expects hourly, this asset is daily

### Blast radius if changed
- <N critical downstreams>
- <list>

### Recommended action
- safe to change | requires migration plan | block change until <X>

### Open questions
- <ambiguities the lineage tool can't resolve>
```

## Rules

- Use the actual lineage data, not assumptions. Use `tracing-upstream-lineage` / `tracing-downstream-lineage` if available.
- Stop at 5 hops — deeper traces produce noise.
- Always identify orphan candidates — they're cheap wins.
- Risk patterns surface findings; the final verdict (safe to change / block) is a recommendation, not a decree.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Target asset**: full upstream chain (≥5 hops), full downstream chain (≥5 hops), owner edges, freshness edges
- **Related assets**: anything that shares a parent or child with the target — they may share blast radius
- **Hidden transformation edges**: graph-encoded business logic that wouldn't surface from raw lineage queries alone
- **Prior lineage audits** on this asset or its neighbors

The graph IS the substrate for this skill — if a graph exists, use it instead of re-deriving lineage. Insertion point: replaces "trace upstream / trace downstream" steps. Tag findings derived from graph as `[GRAPH-LINEAGE]`.

`--no-graph` falls back to native lineage tools. `--graph` forces graphify ingestion of the data warehouse / dbt project first.

## Contract

Consumes: asset name / model / dashboard
Produces: lineage tree + risk findings + blast-radius assessment
Requires: lineage tooling OR user-supplied lineage data
Side effects: writes to .data-audits/lineage/<asset>-<date>.md optional
Human gates: high blast radius triggers a recommendation to require migration plan

## Context

Typical workflows: pre-refactor, pre-deprecation, incident blast-radius assessment
Pairs well with: data-engineering:tracing-upstream-lineage, data-engineering:tracing-downstream-lineage, data-quality-audit, metric-tree-review
