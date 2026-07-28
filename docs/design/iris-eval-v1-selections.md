# IRIS eval — v1 selections (dimensions + thresholds)

**Status:** locked 2026-07-28 by 3-specialist consensus (methodology / IRIS-domain / risk), 3 review rounds. Map #118, ticket #120. Architecture: DL-0021. This doc: DL-0022.

**Eval unit:** a full IRIS analysis response = SQL + executed data + findings.

## Layer-3 analysis-quality dimensions

Isolated judge per dimension; **advisory until human agreement ≥ 0.7** (never gates pre-calibration).

1. **Sufficiency** — direct, committed answer to the core request; not deflecting/hedging without basis (≠ interpretation; ≠ accuracy — accuracy is gated at L2a).
   - Low = deflects with no data-limitation basis
   - Mid = commits with scope qualification OR hedges with an explicit data-limitation basis *(gap-flagging is Sufficiency-Mid only when the gap prevents commitment; if the response commits despite the gap, credit Completeness, not Sufficiency)*
   - High = commits with a falsifiable claim
2. **Completeness** — covers aspects the question implies (time ranges, segments, comparisons); **credit** flagging known data gaps; **credit** characterizing metric unit/definition when plausibly ambiguous (distinct users vs sessions, calendar vs rolling).
3. **Insight** — interprets vs restates.
   - Low = echoes rows
   - Mid = correctly states "flat/stable" when **CV (std/mean) < X%** — *X is a CALIBRATION PARAMETER, seeded 10%, not design-locked; for daily series computed over same-weekday-type observations (weekend cycles are structural, not trend signals)*
   - Mid-High = correctly describes an obvious directional/comparative trend
   - High = surfaces a non-obvious trend/anomaly/attribution needing cross-referenced context

## Per-layer thresholds

### L1 — Data correctness (GATE)

Execution-equivalence; pass = **set equality (order-independent) + 1% float tolerance + column-alias normalization**; suite gate = **no regression vs baseline**.

### L2a — Findings grounding (IMMEDIATE GATE; LLM-assisted deterministic, temp=0; anti-hallucination trust boundary)

- **accuracy = ZERO fabricated numeric claims.** "Fabricated" = value NOT literal in executed rows AND NOT derivable by one arithmetic op (sum/avg/diff/ratio/%chg; a windowed aggregation counts as one op **only when the full time series spanning the window is present** in the executed rows) within tolerance, OR attribution-incorrect (wrong column/segment/time/aggregation-scope).
- **Tolerance:** ≤2% no approximation language needed; >2%–≤10% requires explicit approx language ("approximately/roughly/around/~"); >10% = fabrication. Rounding preserving ≥2 sig figs (51,847→52,000) is not approximation. **Cap: ≤3 approximation-language claims/response** (anti-slop).
- **Affirmative:** ≥1 grounded quantitative claim referencing a fact marked `required` (blocks omission-gaming; activates after audit).
- **Required-facts gate** (binary, activates after audit): all `required` `expected_answer_facts` present.
- **Reference fabrication:** `citation_accuracy` **dropped** as a standalone dimension (would sit ~0.5 = dead weight). A fabricated/misattributed table/column/metric reference is an **L2a attribution failure**. Findings need not cite tables (prose for non-technical users); only fabricated references are penalized.
- **Attribution verification:** tuple-based joint check — judge sees executed rows + prose claim + prompt "does the claim [value, segment, time, aggregation-scope] match the corresponding tuple in the executed rows?" (not compositional).
- **Failure tagging:** `{gate:'L2a', failure:'fabrication'|'omission'|'attribution'|'required-fact-missing', details:[...]}`.

### L2b — Fact-coverage (ADVISORY until agreement ≥ 0.6; LLM judge)

Threshold = **P10 of the fact_coverage distribution from the known-good baseline run**. Baseline MUST use the new grounded judge (not iris-eval's legacy judge) → baseline capture is sequenced **after** the P0 audit and once the new judge prompt is frozen.

### L3 — Analysis quality (ADVISORY until agreement ≥ 0.7)

Pairwise vs baseline per dimension; **excluded from all aggregate reporting until calibrated**; never gates pre-calibration.

## Calibration set (N ≥ 30; purpose-built, not convenience-sampled — P1)

- ≥3 flat/ambiguous cases (incl. ≥1 daily-series case with weekend-dip pattern + documented rationale)
- ≥3 signal-present cases where "no notable pattern" would be WRONG (penalizes false-negative hedging)
- ≥1 pre-scored tie case per dimension (3 total) with documented rationale
- Humans score **pairwise** (better/tie/worse); report **Gwet's AC1 alongside Cohen's κ with 95% CI**
- Gating readiness: **L3 κ ≥ 0.7 AND CI_lower ≥ 0.55; L2b ≥ 0.6**

## Prerequisites (roadmap #118)

- **P0 — `expected_answer_facts` audit (25 pairs):** (a) move SQL-layer facts to L1; (b) mark ≥1 required fact/pair; (c) mark numeric facts required; (d) **negative test** — each pair has ≥1 fact that fails a known-bad response; (e) for pairs with no quantitative findings-layer fact post-(a), author ≥1 new falsifiable quantitative fact (e.g. dau-basic: "states at least one specific daily user count from the 7-day result set"), satisfying (b)(c)(d).
- **P0 — baseline capture:** sequenced *after* the audit; uses the new grounded judge; P10 for L2b computed from it.
- **P1 — purpose-built calibration set** sourcing.

**Top-5/run cap** (DL-0020) applies to **loop runs only** — not to human calibration sessions.
