---
name: dashboard-review
model: sonnet
reasoning: high
description: Reviews an existing dashboard for decision-fit, clarity, chart-type appropriateness, comparator presence, density, and dead-weight charts. Identifies what to keep, sharpen, demote, and remove. Use when auditing a dashboard, before promoting it to a wider audience, or when a dashboard "isn't getting used."
---

# Dashboard Review

## Purpose

Audit an existing dashboard against the question "does this support a real decision?" Most "unused" dashboards aren't unused because the audience is lazy — they're unused because they don't answer a question someone actually has.

**Mechanics:** follow `review-scaffolding` for the review discipline and confidence/report skeleton. The checks, the keep/sharpen/demote/remove verdicts, and the chart-by-chart output below are dashboard-specific.

## When to invoke

- "Review this dashboard"
- "Why isn't anyone looking at <dashboard>?"
- Before promoting a dashboard to ELT / board / customer-facing
- After a dashboard sprawls past 8+ charts

Routing:

- Design a new dashboard → `dashboard-design`
- Specific SQL behind a chart → `sql-review`
- Tree of metrics underneath → `metric-tree-review`

## What it checks

| Category | Checks |
|----------|--------|
| **Decision fit** | Does the dashboard support an identifiable recurring decision? Can the reviewer state the decision in one sentence? |
| **Audience clarity** | Is the audience consistent? Or is this trying to serve exec + ops + product at once? |
| **Headline** | Is there a single top-of-page stat? Does it answer the most-important question first? |
| **Chart count** | More than 8 charts = trying to do too much. Demote or remove. |
| **Chart type fit** | Is each chart the right type? (Time-series → line; comparison → bar; distribution → histogram; correlation → scatter; status → single-stat.) |
| **Axis honesty** | Bars start at zero? No dual-axis correlation illusion? One scale per axis, log labeled? Consistent scales across small multiples? See `viz-integrity/SKILL.md`. |
| **Accessibility** | Color-blind-safe palette? Meaning never encoded by color alone? Legible font/contrast? |
| **Data conditions** | null shown as gap not zero? Small-n suppressed? Outliers not flattening the scale? Empty/error states defined? |
| **Comparators present** | Every number needs a "compared to what." vs prior period, vs target, vs baseline. |
| **Time grain consistency** | Are charts all on the same grain? Or do day-level and quarter-level mix and confuse? |
| **Dead-weight charts** | Charts that don't change reader behavior — candidates for cut. |
| **Drill-down logic** | Do drill-downs exist where useful and lead somewhere actionable? |
| **Freshness signaling** | Is data freshness visible? Stale data without a stale indicator is dangerous. |
| **Governance** | Aggregations safe? Small-cell-size risk? Cross-segment leakage? |

## Process

### 1. State the decision the dashboard supports

Before reviewing, articulate (or ask the user) what decision this dashboard exists for. If unclear, the first finding is "the dashboard doesn't have a clear decision-fit."

### 2. Score the headline

Is there a clear top stat? Is it the right one? Does it have a comparator?

### 3. Walk each chart

For each chart:

- What question does it answer?
- Is that question relevant to the decision?
- Is the chart type appropriate?
- Is the comparator present?
- Would removing it lose anything?

### 4. Identify keep / sharpen / demote / remove

- **Keep**: chart is decisive, chart type is right, comparator present
- **Sharpen**: chart is decisive but execution is weak — fix type, add comparator, fix grain
- **Demote**: chart is useful but not load-bearing — move to a "details" section or a linked deeper dashboard
- **Remove**: chart doesn't change decisions, is duplicative, or measures something the audience doesn't care about

### 5. Identify what's missing

What chart *should* be here that isn't? The "what's NOT here" gap is often the biggest finding.

### 6. Output

```markdown
## Dashboard Review: <name>

### Headline
<one sentence: well-fit | needs work | doesn't support a clear decision>

### Decision-fit
- Claimed decision: <X>
- Actual decision the dashboard supports: <Y>
- Gap: <if any>

### Chart-by-chart
| Chart | Question | Comparator? | Verdict | Notes |
|-------|----------|-------------|---------|-------|
| <name> | <what> | yes/no | keep / sharpen / demote / remove | <notes> |
| ... |

### Missing
- <chart that should be here but isn't>: <why>

### Structural fixes
1. Move <chart X> to drill-down — it's depth, not headline.
2. Add comparator to <chart Y> — current view is uninterpretable without baseline.
3. Cut <chart Z> — duplicative with <chart W>.

### Open questions
- <ambiguities the reviewer can't resolve from the dashboard alone>
```

## Rules

- Lead with decision-fit. Most flat dashboards are flat because they don't support a clear decision.
- "Keep" verdicts need positive justification, not just "it's there."
- "Remove" verdicts need a concrete reason, not just "feels like clutter."
- Don't propose adding 3 charts to fix a dashboard with 9. Subtraction is usually the right move.
- Axis / accessibility / data-condition findings use `viz-integrity/SKILL.md` verdict tags (`[AXIS-LIE]` `[WRONG-TYPE]` `[A11Y]` `[COLOR-ALONE]` `[SMALL-N]` `[NULL-AS-ZERO]`). These are integrity defects, not taste — flag them even on otherwise-decisive charts.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:

- **The dashboard** as a node — what charts it has, what metrics they consume
- **Sibling dashboards** with overlapping audience or metrics — duplication candidates
- **Source-metric ecosystem**: each metric's definition, owner, refresh, prior trust issues
- **Prior dashboard audits** on this dashboard or close siblings

Insertion point: step 1 (state the decision) is graph-aware — check whether another dashboard already supports this decision. Tag overlap findings as `[GRAPH-DUPLICATE]`.

`--no-graph` skips. `--graph` forces graphify on `dashboards/` first.

## Contract

Consumes: existing dashboard (screenshot, definition, link, or text description)
Produces: structured review + keep/sharpen/demote/remove verdicts + missing-charts gap
Requires: nothing
Side effects: writes to .dashboards/<name>-review-<date>.md optional
Human gates: none

## Context

Typical workflows: pre-promotion audit, "why isn't this used" investigation, post-design verification
Pairs well with: viz-integrity (chart honesty/accessibility rules), dashboard-design (rebuild from spec), sql-review (per-chart SQL), metric-tree-review (the underlying metrics)
