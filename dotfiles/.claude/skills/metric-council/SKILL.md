---
name: metric-council
model: opus
reasoning: high
description: "Convenes a council to stress-test a metric design: does it answer the question, is it gameable, does the denominator stabilize, what's the perverse incentive. Graph-first from existing metric defs/trees in graphify-out. Use after metric-design, before add-metric."
---

# Metric Council

Stress-test a metric design before it becomes load-bearing (a bad metric's cost compounds across every dashboard and review cycle).

**Mechanics:** follow `council-scaffolding` for dispatch/synthesis/persist. Deltas below.

## When to invoke
After `metric-design` (before implementation), auditing an existing metric "not behaving as expected", before promoting to KPI/target/OKR. Routing: design → `metric-design`; implement → `add-metric` (after this); general → `analysis-council`.

## Roster
Required: `skeptical-data-scientist`, `decision-scientist`, `governance-reviewer`. Optional: `statistician`, `economist`, `ops-analyst`, `exec-audience-stand-in`, `causal-reasoner`. Smart-pick by metric domain.

## Graph context (graph-first)
Detect graphify-out (`.council/` → cwd → `metrics/`/`docs/graphify-out/`). Extract parent metric, source tables/events, similar metric names, consuming dashboards, segment dims; pull adjacent/overlapping metrics, proposed tree placement (parent + siblings + claimed decomposition), downstream consumers, prior retired/redefined similar metrics. Tag `[GRAPH]`. `--no-graph` skips.

## Synthesis template
Headline (≤8 lines: answers its question? failure modes real? ship/iterate/redesign) · **Will it survive contact with reality?** (yes-with-notes / no-without-changes) · **Highest-leverage critique** (usually gaming, denominator stability, or definitional drift) · **Where experts disagreed** · **Falsifiers** · **Verdict** (ship / ship-with-revisions / redesign / abandon) · **Per-expert reads**.

## Post-process
`humanizer: true` (synthesis), `domain_cleaner: slop-cleaner --mode analysis`. Persist to `.council/metric/`.
