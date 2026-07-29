# IRIS optimization loop — roadmap

**Date:** 2026-07-28 · **Map:** [#118](https://github.com/johnalexwelch/dotdev/issues/118) · **Status:** draft, awaiting approval (to-prd step-0 gate)

Design is locked for both halves: measure = DL-0022 (eval), explore = DL-0023 (candidate-generator); portable loop = DL-0021; top-5 cap = DL-0020. This roadmap sequences the **build** into vertical slices and names the critical-path blocker.

## Critical-path blocker (read first)

**Correction (2026-07-28):** IRIS #945 is *not* our blocker. #945 is IRIS's own production-baseline program (their `eval/baseline.json`, 121 pairs, for the internal Iris-vs-peer-bot contest), gated on the Iris owner's timeline. But DL-0021 made our loop own a thin driver in dotdev (cherry-picking iris-eval's proven pieces — no Inspect), so we do **not** consume IRIS's baseline. **Our baseline = one clean run of our own M1 harness**, gated on things within our control: (1) M1 built, (2) warehouse creds + LLM keys, (3) pinned IRIS commit + judge model, (4) P0a facts-audit done. The scoring milestones therefore depend on **M1 + access + P0a**, not on the external #945 timeline.

## Milestones (vertical slices)

### M0 — Prerequisites

- **P0a — `expected_answer_facts` audit** across the 25 golden_sql pairs. *Unblocked — startable now.* Verifies each pair has gradable grounded facts; feeds L2a's required-fact gate. (Removes the "default omission failures to fixture-gap" stopgap in DL-0023 §H.)
- **P0b — query-pattern-tag taxonomy** enumeration. *Unblocked — startable now.* Required before the generator's first run (DL-0023 §B) or clustering drifts run-over-run.
- **P0c — baseline capture (our loop's, not IRIS #945).** Depends on **M1 + warehouse/LLM access + pinned IRIS commit + pinned judge + P0a** — all within our control. Run our M1 harness once against the pinned commit; capture per-case pass map + P10 floor + permutation null into our loop state. (Two runs, Δ≤2pp, before treating it as authoritative — per the IRIS baseline-DRAFT reproducibility bar.)
- **P0d — judge calibration** (N≥30 pairwise, AC1+κ+CI ≥0.7). Blocked on P0a + P0c. Until it passes, L2b stays advisory (DL-0022).

### M1 — Measure half (thin owned eval driver in dotdev + cherry-picked iris-eval; NO Inspect — DL-0021/0022)

- **Slice 1:** one fixture end-to-end → L1 (execution correctness) + L2a (temp=0 anti-hallucination gate) → score card. Depends P0a.
- **Slice 2:** L2b advisory scoring wired (surfaced, non-gating until P0d).

### M2 — Explore half (candidate-generator, DL-0023)

- **Slice 3:** cluster failures → generate ≤K3 candidates → train/holdout guard → pairwise-vs-baseline whole-suite scoring (permutation p + BH FDR) → regression gate → top-5 + confounder cards. Depends M1 + P0b + P0c.
- **Slice 4:** loop-health (sentinel L2a:attribution candidate, generator≠judge model pins, embedding-model pick + 0.9 calibration).

### M3 — Loop driver + morning report + routing (✅ DESIGNED & LOCKED, DL-0024)

Full spec: `docs/design/iris-loop-driver-report-routing-v1.md`. State on a `loop-state` branch; CLI approval gate (DEFAULT=REJECT); routing to `classdojo/iris` (PRs for Types 1-3, issues for Types 4-5 + fixture-gap); auto-reconcile with squash-safe + `loop-landed`-label landing detection; baseline-refresh loop.

- **Slice 5:** `loop run` → stub issue → CLI approve/reject/edit → route → reconcile → baseline refresh. Build startable now (design complete; needs OD-1..OD-4 answered for live routing).
- **Slice 6:** auto mode — deferred until a multi-run track record + trusted sentinel/health signal.

## Deferred / parked (revisit for wayfinding or grilling)

- Retrieval-path eval (closes the metric-disambiguation EVAL-INVISIBLE blind spot, DL-0023 §A.4).
- Fixture-author diversification / corpus expansion beyond 25 pairs (weak-holdout residual, DL-0023 §E).
- L3 calibration → fold L3 into `net` once κ≥0.7 (DL-0022).
- Fixture-gap queue owner beyond v1; run-frequency decision (daily vs manual) — affects quarantine window.

## Startable now

P0a (facts audit) · P0b (taxonomy) · M1 build (our harness) · M3 design (report/routing grill). None of these wait on IRIS #945. P0c baseline follows once M1 + access + P0a land; M2 (generator build) follows P0c.
