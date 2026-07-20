# /analysis-qa: QA gate for an analysis document

Usage: `/analysis-qa <path-to-doc>` (markdown, memo, or narrative that reports numbers).

Thin entrypoint that runs the three gates a data-analysis narrative needs before it
ships. It owns no checks of its own: it sequences the humanizer detector and the
`clarity-review` / `viz-integrity` skills, which already cover slop, the 5 C's,
metrics-reporting rules (including internal arithmetic tie-out), and chart integrity.

Report every finding with the exact quoted text and its location. End with one verdict
line: `VERDICT: PASS` (all gates clean or every remaining hit justified) or
`VERDICT: ISSUES (N)`.

## Gate 1: Slop (humanizer)

```
python3 ~/.claude/skills/humanizer/scripts/check_tells.py --locations <file>
```

`TOTAL` must be `0`, or every remaining hit is named and justified. For a legitimate hit
you cannot reword (a real data enumeration like `revenue / margin / growth`), add an
inline `<!-- slop-ok: CATEGORY -->` to that line and say why. If the count is
non-trivial, load the `humanizer` skill and clean it.

## Gate 2: Clarity and metrics (clarity-review)

Run the `clarity-review` skill. It covers the 5 C's plus the metrics-reporting rules
that matter for an analysis doc: absolute/YoY/vs-goal, experiment vs top-line, CIs on
counter metrics, numerator/denominator disclosure, false precision, internal
contradictions, and **internal arithmetic tie-out** (parts sum to totals, %s recompute,
same metric identical everywhere, tables foot). Do not re-derive these here.

The tie-out and false-precision rules are the load-bearing ones for numbers. An
unreconciled figure is blocking, not a recommendation.

## Gate 3: Charts (viz-integrity)

If the doc contains or describes charts, apply `viz-integrity` (via `dashboard-review`).

## Output

Findings grouped by gate (quote + location + fix), then the verdict line. A non-zero
Gate 1 `TOTAL` and any unreconciled number from Gate 2 are blocking. Everything else is
a recommendation unless it makes a headline number unjudgeable.
