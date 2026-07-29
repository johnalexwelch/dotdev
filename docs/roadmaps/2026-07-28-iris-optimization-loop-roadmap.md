# IRIS optimization loop — roadmap

**Date:** 2026-07-28 · **Map:** [#118](https://github.com/johnalexwelch/dotdev/issues/118) · **Status:** draft, awaiting approval (to-prd step-0 gate)

Design is locked for both halves: measure = DL-0022 (eval), explore = DL-0023 (candidate-generator); portable loop = DL-0021; top-5 cap = DL-0020. This roadmap sequences the **build** into vertical slices and names the critical-path blocker.

## Critical-path blocker (read first)

**IRIS #945 keeps `eval/baseline.json:baseline_pass_rate = null`.** Every scoring milestone (M1/M2) depends on a non-null baseline. Until #945 lands + a baseline is captured, only unblocked prep (P0a, P0b) and design work (M3) are startable. **The loop cannot produce AFK-safe scoring issues yet.**

## Milestones (vertical slices)

### M0 — Prerequisites

- **P0a — `expected_answer_facts` audit** across the 25 golden_sql pairs. *Unblocked — startable now.* Verifies each pair has gradable grounded facts; feeds L2a's required-fact gate. (Removes the "default omission failures to fixture-gap" stopgap in DL-0023 §H.)
- **P0b — query-pattern-tag taxonomy** enumeration. *Unblocked — startable now.* Required before the generator's first run (DL-0023 §B) or clustering drifts run-over-run.
- **P0c — baseline capture.** ⛔ **BLOCKED on IRIS #945** + the new 5-dim judge. Re-run suite, set `baseline_pass_rate`, capture P10 floor + permutation null.
- **P0d — judge calibration** (N≥30 pairwise, AC1+κ+CI ≥0.7). Blocked on P0a + P0c. Until it passes, L2b stays advisory (DL-0022).

### M1 — Measure half (eval harness on Inspect AI, DL-0021/0022)

- **Slice 1:** one fixture end-to-end → L1 (execution correctness) + L2a (temp=0 anti-hallucination gate) → score card. Depends P0a.
- **Slice 2:** L2b advisory scoring wired (surfaced, non-gating until P0d).

### M2 — Explore half (candidate-generator, DL-0023)

- **Slice 3:** cluster failures → generate ≤K3 candidates → train/holdout guard → pairwise-vs-baseline whole-suite scoring (permutation p + BH FDR) → regression gate → top-5 + confounder cards. Depends M1 + P0b + P0c.
- **Slice 4:** loop-health (sentinel L2a:attribution candidate, generator≠judge model pins, embedding-model pick + 0.9 calibration).

### M3 — Loop driver + morning report + routing (⚠ still UNDESIGNED)

- **Slice 5:** morning ranked report format → human approval → route to issue/PR/reflection. *Design not yet grilled — the last fog item on #118.* Design work is startable now (no baseline dependency).
- **Slice 6:** auto mode.

## Deferred / parked (revisit for wayfinding or grilling)

- Retrieval-path eval (closes the metric-disambiguation EVAL-INVISIBLE blind spot, DL-0023 §A.4).
- Fixture-author diversification / corpus expansion beyond 25 pairs (weak-holdout residual, DL-0023 §E).
- L3 calibration → fold L3 into `net` once κ≥0.7 (DL-0022).
- Fixture-gap queue owner beyond v1; run-frequency decision (daily vs manual) — affects quarantine window.

## Startable now (no #945 dependency)

P0a (facts audit) · P0b (taxonomy) · M3 design (report/routing grill). Everything else waits on the baseline.
