---
name: viz-integrity
model: sonnet
reasoning: high
description: Shared chart-integrity rules — chart-type-to-data-shape fit, axis honesty, color-blind accessibility, encoding accuracy. Referenced by dashboard-design (per-chart) and dashboard-review (checks). Not invoked standalone.
---

# Viz Integrity

Shared fragment. A dashboard can support the right decision and still lie or exclude readers. These rules make each chart honest and readable. Referenced by `dashboard-design` (step 3, per chart) and `dashboard-review` (checks table).

## Contract

Consumes: a chart or dashboard spec under design/review — chart type, data shape, axes, color encoding, data conditions
Produces: integrity rulings + verdict tags (`[AXIS-LIE]`, `[WRONG-TYPE]`, `[A11Y]`, `[COLOR-ALONE]`, `[SMALL-N]`, `[NULL-AS-ZERO]`) applied as guidance — not code artifacts
Requires: none
Side effects: none (shared reference fragment; advises, does not mutate files)
Human gates: none

## 1. Chart type ← data shape

| Data shape | Use | Never |
|-----------|-----|-------|
| Value over time | line | pie, stacked area unless true parts-of-whole |
| Compare categories | horizontal bar (ordered by value) | pie >5 slices; alphabetical order |
| Part-of-whole (≤5 parts) | stacked bar / single bar | pie >5, donut |
| Distribution | histogram / box | bar of raw values |
| Correlation | scatter | dual-axis line (fakes correlation) |
| Single status | single-stat + trend | gauge |

- **No dual-axis** to imply correlation between two series. Use two panels or a scatter.
- **Rank/sort categorical bars by value**, not label. Alphabetical hides the signal.
- **Direct-label** lines/bars where possible; legend is a lookup tax.

## 2. Axis honesty (the top way dashboards lie)

- **Bar charts start at zero.** Truncated baseline exaggerates differences — no exceptions for bars.
- Line charts may crop the axis, but **label the range** and don't crop so hard noise reads as trend.
- **One scale per axis.** Mixed linear/log or rescaled twins mislead. If log, label it.
- **Consistent scales across small multiples** — otherwise comparison is a lie.
- Time axis: equal intervals, no gaps silently collapsed.

## 3. Accessibility (trust boundary — do not skip)

- **Color-blind-safe palette** (Okabe-Ito, Viridis, or ColorBrewer safe sets). ~8% of men can't read red/green.
- **Never encode meaning by color alone** — pair with shape, label, position, or pattern.
- Min font ~12px; text/background contrast ≥ 4.5:1.
- ≤ ~6 distinguishable colors per chart; beyond that, group or facet.

## 4. Data conditions

- **Empty / loading / error states** defined, not a blank panel.
- **Small-n suppression**: hide or flag cells below the governance threshold (default n<5).
- **null ≠ zero.** Show gaps as gaps; don't plot missing as 0.
- Outliers: cap or annotate so one point doesn't flatten the rest of the scale.

## Verdict tags (for review use)
`[AXIS-LIE]` `[WRONG-TYPE]` `[A11Y]` `[COLOR-ALONE]` `[SMALL-N]` `[NULL-AS-ZERO]`
