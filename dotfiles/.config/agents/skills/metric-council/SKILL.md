---
name: metric-council
disable-model-invocation: true
model: opus
reasoning: high
description: "Convenes a council to stress-test a metric design: does it answer the question, is it gameable, does the denominator stabilize, what's the perverse incentive. Graph-first from existing metric defs/trees in graphify-out. Use after metric-design, before add-metric, or for a KPI-level metric decision (replacement, retirement, or promotion). For structural review of a whole metric tree, use metric-tree-review instead."
---

# Metric Council

Stress-test a metric design before it becomes load-bearing (a bad metric's cost compounds across every dashboard and review cycle).

**Mechanics:** follow `council-scaffolding` for dispatch/synthesis/persist. Deltas below.

## Contract

Consumes: a metric design, a single named metric's definition/behavior, or a proposed change to one metric (not the structural review of a whole metric tree — that's `metric-tree-review`)
Produces: council synthesis with survivability verdict, critique, falsifiers, and per-expert reads
Requires: independent expert contexts; graph context optional
Side effects: may persist synthesis to `.council/metric/` when the run reaches the persistence step
Human gates: redesign, abandon, governance, or KPI/target promotion decisions require human judgment

## When to invoke

After `metric-design` (before implementation), auditing an existing metric "not behaving as expected", before promoting to KPI/target/OKR, or when changing, replacing, or retiring a north-star/KPI/OKR-level metric. Routing: design → `metric-design`; implement → `add-metric` (after this); structural review of a metric tree (decomposition/double-counting/math) → `metric-tree-review`; general → `analysis-council`.

## Roster

Required: `skeptical-data-scientist`, `decision-scientist`, `governance-reviewer`. Optional: `statistician`, `economist`, `ops-analyst`, `exec-audience-stand-in`, `causal-reasoner`. Smart-pick by metric domain.

## Graph context (graph-first)

Detect graphify-out (`.council/` → cwd → `metrics/`/`docs/graphify-out/`). Extract parent metric, source tables/events, similar metric names, consuming dashboards, segment dims; pull adjacent/overlapping metrics, proposed tree placement (parent + siblings + claimed decomposition), downstream consumers, prior retired/redefined similar metrics. Tag `[GRAPH]`. `--no-graph` skips.

## Synthesis template

Headline (≤8 lines: answers its question? failure modes real? ship/iterate/redesign) · **Will it survive contact with reality?** (yes-with-notes / no-without-changes) · **Highest-leverage critique** (usually gaming, denominator stability, or definitional drift) · **Where experts disagreed** · **Falsifiers** · **Verdict** (ship / ship-with-revisions / redesign / abandon) · **Per-expert reads**.

## Post-process

`humanizer: true` (synthesis), `domain_cleaner: null` (slop-cleaner retired per DL-0008). Persist to `.council/metric/`.
