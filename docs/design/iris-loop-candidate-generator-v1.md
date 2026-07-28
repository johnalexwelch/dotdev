# IRIS optimization loop — candidate-generator (explore half), v1

**Status:** locked 2026-07-28 by 4-round 3-specialist consensus (methodology / IRIS-domain / risk). Map #118. Measure half = the locked eval (DL-0022). Top-5 cap = DL-0020. Portable loop = DL-0021. This doc: DL-0023.

Operational constants are marked `[tunable]` (build/calibration params). Items marked **OPEN** are human-input decisions that do **not** block the design.

**Purpose.** Given a run's eval signal, propose candidate *changes* to the agent stack, score them, rank them, and emit the **top-5** for human-approved routing to issues / PRs / reflections. This is the "explore" half; the eval is the "measure" half.

## A. Candidate types (levers) + blast-radius tier

1. **Prompt/instruction edits** — HIGH if global prefix (all lanes), MEDIUM if lane-scoped suffix. Must carry `{target_prompt: sql_generation | findings_prose | system_prefix}`. A `findings_prose` candidate is **rejected at generation** if the cluster's failures are all L1 (SQL-layer — wrong lever).
2. **Reflections/habits (notes)** — HIGH global / MEDIUM domain / LOW table|user. Must carry `{scope, scope_key}`. "landed" = merged **and** approved.
3. **Tool schema/description edits** — MEDIUM.
4. **Retrieval-corpus content edits** — **EVAL-INVISIBLE** (the eval injects context directly; retrieval is bypassed) → routed to the human-judgment queue, **not** suite-scored. Metric-disambiguation failures surface as a distinct morning-report line (count + examples) — an acknowledged v1 structural blind spot with zero closed-loop leverage. **OPEN:** accept for v1; roadmap a retrieval-path eval.
5. **Routing/classifier code AND findings-pipeline code** (row formatter, context assembler, data-assembly) — HIGH, requires a code PR.

**Excluded:** eval fixtures + judge prompts (meta-eval firewall) → route to the fixture-audit queue.

## B. Input unit = failure cluster

Cluster by **(L2a failure-tag + domain + lane co-filter)** + low-L2b cases (flagged advisory-driven). **L3 excluded from clustering until κ ≥ 0.7.**

- **Clustering priority:** fabrication/omission → cluster by query-pattern-tag first; attribution/required-fact-missing → cluster by domain first.
- **query-pattern-tag taxonomy must be pre-enumerated before the first run** (else clustering drifts run-over-run).
- Cluster input: transcripts, executed rows, failure tags, baseline diffs, per-case L1 pass/fail.
- Fallback axis = query-pattern-tag when a cluster is `< N` `[fallback-N seed 3, tunable]`.

## C. Minimum cluster size

Train/holdout split activates only at **N ≥ 4** (≥2 train / ≥2 holdout), random 50/50 with a **logged seed**. Below N=4 → candidate tagged **CANNOT-VALIDATE**, human-judgment only, never auto-emitted as validated.

## D. Generation

Per cluster, propose **K ≤ 3** candidates, each = `{hypothesis, diff, target-case set, change-type, blast tier, (Type-1 target_prompt / Type-2 scope+scope_key)}`.
**Cross-cluster dedup** before ranking: near-identical `(type + diff)` (cosine > 0.9 `[tunable]` on the diff embedding — specify the embedding model on first run, calibrate the threshold against 5–10 manually-judged pairs) → merge into one, union target sets, score once. **Never merge across types.**

## E. Anti-overfit / reward-hacking guard

Split each failure class into **TRAIN** (generator sees) / **HOLDOUT** (blind); a candidate counts only if it moves **holdout** cases of the same class to pass.

- **Merged candidates** (spanning clusters) must fix ≥1 holdout case in **each** contributing cluster (no free-riding on one cluster's holdout).
- **Quarantine:** a held-out case cannot re-enter train for `[N+7 tunable]` runs; a baseline refresh resets quarantine clocks and re-quarantines the pre-refresh holdout set.
- **Explicit residuals:** (i) on ~25 pairs holdout is weak → the **human approval gate is the PRIMARY defense**, the split is a secondary signal; (ii) all 25 fixtures share one author → an edit could exploit curator style and pass train+holdout while failing real queries → the reviewer checklist ("fluency vs grounding?") is the guard. **OPEN:** diversify fixture authorship post-v1.

## F. Scoring / ranking

Score each candidate **pairwise vs baseline across the WHOLE suite**.

- **Severity:** L1=3, L2a=2, L2b=1; **L3 excluded from net until calibrated.**
- `net = Σ(moved-to-pass × severity) − Σ(regressions × severity)`.
- **Significance (permutation-based, no normality assumption):** compute a permutation p-value — repeatedly (1000× `[tunable]`) shuffle the per-case candidate-vs-baseline win/loss labels, recompute net, take `p = fraction of permuted |net| ≥ observed`. Then apply **Benjamini-Hochberg FDR (q=0.05) across ALL M candidates** (M = total, holdout-failers assigned p=1.0 — not M_holdout, which would inflate FDR ~2×). **No 2σ pre-filter** (permutation + BH subsumes it).
- **Emission minimums:** net > 0 for all tiers; additionally HIGH net ≥ 2, MEDIUM ≥ 1.
- **Tiebreak:** smallest blast tier.
- **Early-exit:** fail holdout → skip whole-suite scoring (holdout stage strictly precedes the whole-suite + FDR stage; no statistical conflict).
- **Suite-version lock:** reject cross-version scores.
- **Per-run cost budget** `[~2000 judge calls or $30, tunable]`: on exhaustion emit current top-5, flag remaining clusters `budget-exceeded`; within a tier, process clusters in descending cluster-N order (deterministic).

## G. Regression gate

Disqualify (regardless of target wins) any candidate that (a) regresses an L1/L2a gate on a previously-passing case, or (b) drops L2b below the P10 floor. **L3 degradation = reviewer flag, not a disqualifier.**

- All HIGH-tier candidates (global prefix or global note) must carry a **CROSS-LANE RISK NOTE** (fires across all lanes; the suite covers only WAREHOUSE_ANALYSIS).
- L1-targeting Type-1 candidates must carry a **SQL-LOGIC COVERAGE NOTE** (few advanced/window pairs exist → elevated uncovered-case risk).

## H. Fixture-gap path

Emit a **FIXTURE-GAP NOTE** `{fixture_id, failure_tag, transcript evidence agent was correct, missing/ambiguous property, proposed change, confidence, origin: generator-run-{date}}` → P0 fixture-audit queue, **not** counted vs top-5. Prefer a fixture-gap note over a weak-evidence prompt candidate.

- **Low confidence** = stated confidence < 0.6 OR transcript equally supports agent-error vs fixture-gap → surfaced as a count only.
- Until the P0 `expected_answer_facts` audit lands, **required-fact-missing/omission failures default to a fixture-gap note (confidence=LOW)**; default removed post-audit. LOOP-PREREQ check: while the audit is incomplete, the `required-fact-missing` signal is suppressed with a warning (not a halt).
- **Queue owner = the loop operator for v1** (**OPEN:** reassign later); review cadence every 3 runs or each baseline refresh; **halt trigger** — unreviewed fixture-gap count > `[M=5 tunable]` blocks emission for affected clusters with a FIXTURE-GAP-BACKLOG flag.

## I. Emission

Top-5 by net → morning ranked report → human approval → route to issue/PR/reflection. CANNOT-VALIDATE candidates appear in a **separate section** (do not consume the 5 slots).
**Confounder card** per candidate: cluster N, holdout N, permutation p-value, FDR q-value, pinned model version, baseline freshness, changes-since-baseline, blast tier, cross-lane note, within-domain coverage note (MEDIUM), L2b mean-delta, and **interpreted flags** (`[AT VALIDITY FLOOR]`, `[MINIMUM HOLDOUT]`, `[SOLE-DOMAIN]`, `[NEXT APPROVAL TRIGGERS BASELINE REFRESH]`, `[NEAR FDR THRESHOLD]`).

## J. Baseline / drift

Refresh on (model version bump) OR (`[5 tunable]` approved candidates landed): re-run suite, reset P10 floor + change counter + quarantine clocks + re-estimate the permutation null.

- **Cumulative drift guard:** `> [5 tunable]` approved prompt edits since refresh → re-capture proposal.
- **Delta-vs-last-baseline:** at each refresh, compare per-case pass vs the prior baseline; any newly-regressed case raises a blocking **CUMULATIVE-REGRESSION** flag (attribution granularity: batch ≤5 candidates, not per-candidate — known limitation).
- **Eval-config prereqs for any scoring:** pinned model version (not an alias), judge temp=0, baseline non-null.

## K. Loop health

1. **Sentinel** — one human-authored, previously-validated **L2a:attribution** candidate (L2a chosen because deterministic at temp=0) is re-scored every run; **LOOP-HEALTH-FAILURE** (halt emission) triggers if its net drops run-over-run vs the immediately prior run; keep the full sentinel net time-series; a refresh re-establishes its expected net.
2. **Generator model ≠ judge model** (reduce shared-blindspot reward hacking).
3. Reviewer checklist item: "is this candidate rewarded for fluency rather than grounding?"

## Open decisions (human input; do not block the design lock)

- Fixture-gap queue owner beyond v1.
- Post-v1 fixture-author diversification.
- v1 acceptance of the metric-disambiguation EVAL-INVISIBLE blind spot.
- Run frequency (calendar-daily vs manually triggered) — affects the practical quarantine-window duration.

## New build prerequisites (roadmap #118)

- Pre-enumerate the **query-pattern-tag taxonomy** before first run.
- Estimate the **permutation null / judge-noise** at each baseline refresh.
- Author the **sentinel** L2a:attribution candidate.
- Pick + pin the **dedup embedding model** and calibrate the 0.9 threshold.
- Pin **generator ≠ judge** model choices.
