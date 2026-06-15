---
name: experiment-design
model: opus
reasoning: high
description: "Designs a controlled experiment (A/B, multivariate, switchback, holdout): hypothesis, primary metric, MDE, sample size, randomization unit, duration, guardrails, stopping rules. Catches under-powered tests, peeking, missing guardrails, confounding. Use before launching any decision-driving experiment."
---

# Experiment Design

## Purpose

Most A/B tests fail before they launch — under-powered, no guardrails, no clear hypothesis, no pre-registered analysis. This skill produces a design spec that survives the test.

## When to invoke

- Before launching any A/B test, multivariate, switchback, or holdout
- "Design an experiment to test X"
- "Is this test going to be conclusive?"
- After a brainstorm, before implementation

Routing:

- After implementation, before ship → `experiment-readout` (post-result) — TBD; for now route to `analysis-design`
- For non-experimental analysis → `analysis-design`
- Stress-test the design → `analysis-council`

## Process

### 1. Lock the primary hypothesis

One sentence:
"If we <intervention>, then <primary metric> will <direction>, because <causal mechanism>."

Every word matters. Absence of a mechanism is a red flag — the test will fire results but not knowledge.

### 2. Pick the primary metric

ONE primary metric. The metric the test will be powered for and judged on. Other metrics are guardrails or secondaries.

- Aligned with the hypothesis
- Sensitive enough to move within the test duration
- Robust to outliers (or pre-define winsorization)
- Owned by a team (it has a home)

### 3. Set the minimum detectable effect (MDE)

What's the smallest effect that would matter? Anchored in the decision:

- "We'd ship at X% lift" → MDE is X%
- "We'd kill the feature if effect is < Y%" → MDE is Y%

Power the test for MDE — not for "any effect."

### 4. Compute sample size and duration

Given MDE + baseline metric value + variance + power (typically 0.8) + alpha (typically 0.05):

- Required sample per arm
- Required calendar duration given typical user traffic
- Realistic ramp schedule

If the required duration is infeasible (>8 weeks for most product tests), either increase MDE, reduce arms, or accept the test won't be conclusive.

### 5. Pick the randomization unit

- User-level (most common, but reduce for short tests with low traffic)
- Session-level (when within-user variance matters)
- Account-level (B2B, edu — to prevent cross-user contamination)
- Cluster (school / district / company) when network effects matter

Wrong unit = SUTVA violation = invalid test.

### 6. Identify guardrails

What metrics MUST NOT move, even if primary moves?

- Quality (error rates, support tickets, NPS)
- Adjacent funnels (don't trade conversion for engagement)
- Revenue (or cost)
- Latency / system metrics
- Equity / fairness across segments

Set a guardrail threshold for each. Crossing a guardrail blocks shipping even if primary wins.

### 7. Stopping rules

- Earliest peek: <time/sample-size after which interim look is allowed>
- Alpha spending plan if peeking
- Hard stop if guardrail crosses threshold
- Hard stop if SRM (sample ratio mismatch) detected
- Maximum duration

Pre-register the stopping rules. "We'll look every day and decide" is not a stopping rule.

### 8. Identify segments to pre-register

Up to 5 segments where heterogeneous effects are plausible. Pre-register or they don't count.

### 9. Output

```markdown
# Experiment Design: <name>

## Hypothesis
"If we <intervention>, then <primary metric> will <direction>, because <mechanism>."

## Primary metric
- Metric: <name>
- Owner: <team>
- Source / definition: <link>

## MDE
- Minimum detectable effect: <X%> on <metric>
- Anchored in: <ship threshold or kill threshold>

## Sample size and duration
- Baseline value: <X>
- Variance: <Y>
- Power: 0.8
- Alpha: 0.05
- Required sample per arm: <N>
- Required duration: <D days/weeks>
- Typical daily traffic: <T>

## Arms
- Control: <description>
- Treatment 1: <description>
- (Treatment 2: ...)

## Randomization unit
<user | session | account | cluster> — because <reason>

## Guardrails
| Metric | Threshold | Direction | Action if crossed |
|--------|-----------|-----------|---------|
| <metric> | <X> | <up/down> | block ship |

## Stopping rules
- Earliest peek: <after N samples or D days>
- Peeking plan: <alpha-spending or no-peek>
- Hard stops: guardrail crossed, SRM detected, max duration <X> reached

## Pre-registered segments
1. <segment> — expected effect: <direction>
2. ...
(up to 5)

## Pre-registered analysis plan
- Primary analysis: <method — t-test, CUPED, etc>
- Multiple-comparisons correction: <Bonferroni | BH | none if single primary>
- Subgroup analysis: only on pre-registered segments

## What would change my mind / kill plan
- "Ship if primary lifts <X%> AND no guardrail crosses."
- "Kill if primary moves <Y%> in the wrong direction."
- "Iterate if effect is ambiguous (within CI of 0)."

## Risks
- <risk 1>: <mitigation>
- <risk 2>: ...

## Next step
- Stress-test design via `analysis-council`
- Implement
- After results: `analysis-design` for readout
```

### 10. Persist

`.experiments/<name>-design.md`.

## Rules

- One primary metric. Two-primary tests are usually under-powered.
- MDE is non-negotiable. "Any positive effect" is a fishing expedition.
- Pre-register stopping rules and segments. Otherwise peeking and post-hoc cuts will inflate false positives.
- Guardrails are mandatory. Tests without guardrails ship harm.
- If required duration is infeasible, redesign — don't proceed under-powered.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:

- **Prior experiments** in this feature area — outcomes, MDEs that proved insufficient, what was learned
- **Primary metric history**: typical variance, baseline, recent shifts, prior MDE choices
- **Related ADRs** that constrain experiment design (e.g., minimum-N policies, governance gates)
- **Prior experiments on this audience** — frequency of testing, audience fatigue concerns

Insertion point: step 3 (set MDE) is graph-aware — prior experiments' actual effect sizes inform realistic MDE choice. Tag findings as `[GRAPH-PRIOR-EXPERIMENT]`.

`--no-graph` skips. `--graph` forces graphify on `experiments/` first.

## Contract

Consumes: hypothesis / feature / intervention candidate
Produces: experiment design spec
Requires: baseline metric values (or notes that they're needed before launch)
Side effects: writes to .experiments/
Human gates: design must be approved before implementation; one clarifying question max

## Context

Typical workflows: pre-implementation, before any production test
Pairs well with: analysis-council (stress-test), analysis-design (readout post-results), metric-design (when test introduces new metric)
