---
name: metric-design
description: Designs a new metric from a question, not from available data. Forces a precise definition (what counts, what's excluded), a stable denominator, a Goodhart's-Law check, a falsifier, and a maintenance plan. Produces a metric spec ready for YAML implementation. Use before adding any new metric to a tree, a dashboard, or a target.
---

# Metric Design

## Purpose

Most bad metrics are bad by design — vague definitions, drifting denominators, perverse incentives, or no way to know if they're wrong. This skill produces a precise design spec before the YAML is written.

## When to invoke

- Before adding a new metric to a tree
- Before declaring a new KPI / target
- "How should we measure X?"
- "I want to track Y"

Routing:
- After this, implement via `add-metric`
- Stress-test the design via `metric-council`
- If it's a one-shot analysis, not a recurring metric → `analysis-design`

## Process

### 1. State the question the metric answers

Force one sentence: "We want this metric because it tells us <X>." If it's "to track engagement" or "for visibility," the question is too vague — sharpen.

### 2. Pick the metric shape

| Shape | When to use |
|-------|-------------|
| Count | "How many" — events, users, occurrences |
| Rate / ratio | "How much of <denominator> does <numerator>" |
| Average / percentile | "How long," "how big" — usually with quantiles |
| Funnel conversion | "What % of <stage A> reach <stage B>" |
| Retention curve | "What % of <cohort> still active at <time T>" |
| Distribution | "What's the spread" — for hygiene, not targets |
| Composite index | "Weighted combination" — use sparingly |

### 3. Define numerator and denominator precisely

For each:
- What event / row counts
- What's explicitly excluded (test users, internal staff, churned accounts, deleted records)
- Source table / source event
- Time window
- Time zone

Be ruthless about precision. "Active users" is not a definition; "users who logged in via web or mobile at least once in the rolling 7-day window, excluding internal staff and test accounts" is.

### 4. Stability of denominator

A ratio whose denominator can change is unstable over time. Check:
- Does the denominator population shift week-over-week?
- If so, the metric will move for reasons unrelated to the numerator.
- Either fix the denominator (e.g., "of accounts that were active in Q1") or report the denominator alongside the rate.

### 5. Goodhart's Law check

If this metric becomes a target, how would someone game it?
- Cheap wins (e.g., counting opens vs. meaningful actions)
- Selection effects (excluding users to inflate the rate)
- Substitution (lowering quality to hit volume)
- Window-shopping (timing actions for the measurement window)

If the gaming paths are easy, the metric is fragile. Either accept the risk, design a paired counter-metric, or change the metric.

### 6. Falsifier

"This metric would be misleading if <X>." Name the failure mode that should trigger a re-design. (E.g., "if account-creation pattern changes such that denominator becomes non-comparable, this metric is misleading.")

### 7. Maintenance plan

- Who owns the metric?
- How often is the SQL revisited?
- What's the freshness contract?
- What's the documentation home?

### 8. Output

```markdown
# Metric Design: <name>

## Question this metric answers
<one sentence>

## Shape
<count | rate | percentile | funnel | retention | distribution | composite>

## Numerator
- Counts: <precise definition>
- Excludes: <list>
- Source: <table.column or event name>
- Time window: <X>
- Time zone: <UTC or local>

## Denominator (if applicable)
- Counts: <precise definition>
- Excludes: <list>
- Source: <X>
- Stability: stable | drifts (and how to handle)

## Goodhart's Law check
- Gaming paths: <list>
- Mitigation: paired counter-metric / accept risk / redesign

## Falsifier
"This metric is misleading if <X>."

## Comparator (how it's read)
- vs prior period | vs target | vs cohort | vs baseline

## Maintenance
- Owner: <name>
- Documentation: <path>
- SQL review cadence: <quarterly | when source changes>
- Freshness SLA: <hourly | daily | etc>

## Out of scope (this metric does NOT)
- <thing it could be confused with but doesn't measure>

## Next step
- Stress-test via `metric-council`
- Implement via `add-metric`
- Validate gap SQL via `validate-metric-trees` after add
```

### 9. Persist

`.metrics/designs/<metric-slug>.md`.

## Rules

- Precise definitions or no metric. "Active" without scope is meaningless.
- Denominator stability is non-negotiable for ratios.
- Goodhart's Law check is non-negotiable. If you can't think of how to game it, you haven't tried hard enough.
- Falsifier is non-negotiable. A metric with no falsifier is just a number.
- "Out of scope" prevents future scope creep.

## Graph context (GRAPH-FIRST — default behavior)

See `_graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Existing metrics with overlapping definitions** — avoid duplicate-with-drift
- **Candidate tree placements** (parents and siblings the new metric could compose with)
- **Prior retired or redefined metrics** in this space — what failed before
- **Source tables** the new metric would depend on — freshness, ownership, governance

Insertion point: step 3 (define numerator and denominator) — duplicate-detection surfaces here. Tag findings as `[GRAPH-DUPLICATE]` or `[GRAPH-PRIOR-RETIRED]`.

`--no-graph` skips. `--graph` forces graphify on `metrics/` first.

## Contract

Consumes: question / area / KPI candidate
Produces: metric design spec
Requires: nothing
Side effects: writes to .metrics/designs/
Human gates: requires user to commit to a precise definition; one clarifying question max

## Context

Typical workflows: pre-implementation metric design, KPI candidate review
Pairs well with: metric-council (stress-test), add-metric (implement), metric-tree-review (placement), validate-metric-trees (SQL validation after implementation)
