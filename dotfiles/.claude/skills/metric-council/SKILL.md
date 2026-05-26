---
name: metric-council
description: Convenes a council to stress-test a metric design — does it answer the question, is it gameable, does the denominator stabilize, what are the perverse incentives, what would falsify it. Graph-first by default — auto-loads existing metric definitions, metric trees, and related dashboards from `graphify-out/` when present so experts can detect cross-metric conflicts and tree-placement issues. Use after `metric-design` and before `add-metric`.
---

# Metric Council

## Purpose

A metric, once instrumented and reported, is hard to retire. The cost of a bad metric compounds — every dashboard, every quarterly review, every KPI cycle inherits its flaws. This council stress-tests a metric design before it becomes load-bearing.

## When to invoke

- After `metric-design` produces a spec, before implementation
- When auditing an existing metric that "isn't behaving as expected"
- Before promoting a metric to KPI / target / OKR status

Routing:
- Design a metric → `metric-design`
- Implement → `add-metric` (after the council)
- General analysis council → `analysis-council`

## Process

### 1. Parse invocation

Identify:
- The metric design (must be a structured spec, ideally from `metric-design`)
- Mode: design-time review vs. existing-metric audit
- Stakes signal: KPI-bound? target-bound? exec-visible?

### 2. Resolve roster

Defaults from `roster.yml`:
- Required: `skeptical-data-scientist`, `decision-scientist`, `governance-reviewer`
- Optional: `statistician`, `economist`, `ops-analyst`, `exec-audience-stand-in`, `causal-reasoner`

Smart-pick based on the metric domain.

### 2.5. Load metric-ecosystem context (GRAPH-FIRST — default behavior)

Auto-detect graphify-out in this order:
1. `.council/graphify-out/` in cwd
2. `graphify-out/` in cwd
3. `metrics/graphify-out/`, `docs/graphify-out/`

**If found (or `--graph` is passed)**:
- Extract entities from the proposed metric: parent metric name (if part of a tree), source tables/events, similar metric names, dashboard names that would consume it, segment dimensions used.
- Query the graph for:
  - **Existing metrics with overlapping definitions** (semantic neighbors of the proposed name / source)
  - **The metric tree** the proposed metric would join — current siblings, parent, claimed decomposition
  - **Dashboards that would consume this metric** (downstream)
  - **Prior metric retirements or redefinitions** of similar metrics — what failed last time
- Bundle into a **metric-ecosystem block** prefixed to every persona's prompt:
  ```
  ## Metric ecosystem context (from knowledge graph)
  Adjacent existing metrics: <list with definitions>
  Proposed tree placement: parent=<X>, current siblings=<list>
  Decomposition relationship: <claimed math>
  Likely downstream consumers: <dashboards, alerts>
  Prior similar metrics that were retired/redefined: <list with reason>
  ```
- Tag findings that depend on graph context as `[GRAPH]` in the synthesis.

**If no graph**: skip context block. Synthesis adds note: "No metric graph detected — council reviewed in isolation. Run `graphify` on `metrics/` to detect cross-metric conflicts."

**If `--no-graph`**: force-skip.

### 3. Dispatch round 1 (parallel)

All personas in a single message. Each evaluates the metric design through their lens.

### 4. Dispatch round 2 (parallel)

Each persona writes a `## Response to other experts` section.

### 5. Synthesize

```markdown
# Metric Council on: <metric name>

## Synthesis
<≤8 lines: does the metric answer its question, are the failure modes real, ship/iterate/redesign verdict>

## Will this metric survive contact with reality?
- **Yes, with notes**: <conditions>
- **No, without changes**: <what must change>

## Highest-leverage critique
<the single most important challenge — usually about gaming, denominator stability, or definitional drift>

## Where experts disagreed
- ...

## What would change the picture
- <falsifiers>

## Verdict
- ship as designed | ship with revisions | redesign | abandon

## Per-expert reads
### skeptical-data-scientist (confidence: ...)
...
```

### 6. Post-process

Per `roster.yml.post_process`:
- humanizer: true (the synthesis section)
- domain_cleaner: analysis-slop-cleaner

### 7. Persist

`.council/metric/<YYYY-MM-DD>-<metric-slug>.md` + JSON sidecar.

## Contract

Consumes: metric design spec (from `metric-design`, or structured equivalent)
Produces: council synthesis with verdict + per-expert reads
Requires: subagent dispatch, _personas/, _council-scaffolding/
Side effects: writes to .council/metric/
Human gates: none — fire-and-read

## Context

Typical workflows: post-metric-design, pre-implementation, KPI promotion audit
Pairs well with: metric-design (upstream), add-metric (downstream implementation), metric-tree-review (placement after implementation)
