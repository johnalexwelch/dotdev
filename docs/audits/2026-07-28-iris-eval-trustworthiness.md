# iris-eval trustworthiness assessment (dotdev #124)

**Date**: 2026-07-28
**Scope**: read-only audit of `/Users/alexwelch/projects/agents/iris` (branch `staging`) —
`backend/src/iris/eval/` + `backend/eval/`.
**Question** (#124): Is `iris-eval` trustworthy enough to be the AI-optimization loop's quality signal?
**Verdict**: **Augment before adopting. NO-GO as-is; conditional GO as harness** after the fixes below.

---

## TL;DR

iris-eval is a competent *skeleton* (loader, comparators, composite grader, suite structure,
prompt-sha versioning) but **cannot be trusted as the loop's optimization signal today**:

1. **No baseline** — `eval/baseline.json` `baseline_pass_rate: null`, blocked on IRIS #945. No baseline ⇒ deltas are meaningless.
2. **No signal actually runs in CI** — `.github/workflows/eval.yml` runs **only `iris-eval --validate`** (structural checks, no LLM, no SQL generation, no scoring). The scoring path exists in code but is unwired (needs live generator + `REDSHIFT_*` + MCP + per-PR LLM cost). So there is no automated pass_rate/quality number being produced at all.
3. **Default SQL metric is lexical, not semantic** — `EvalEngine` default `ComparisonMethod.TOKEN_OVERLAP` @ threshold `0.8` (`engine.py`). Correct-but-different SQL can fail; wrong-but-lexically-similar SQL can pass. Execution-equivalence exists but is an **opt-in fallback**.
4. **LLM judge is unvalidated** — no human-calibration set; judges "accuracy" without ever seeing the data; nondeterministic; two divergent implementations coexist.

Optimizing against pass_rate(token_overlap) with a null baseline = **textbook Goodhart**.

---

## Findings by audit dimension

### 1. Coverage — 25 golden pairs (`backend/eval/golden_sql/seed.yml`, v1.8)

- **Count**: 25 pairs. Difficulty spread: **9 basic / 13 intermediate / 3 advanced** — skewed easy; only 3 advanced (all window-function/top-N).
- **Domain**: entirely ClassDojo product metrics — engagement (dau/wau/map/wap), revenue (mrr/churn/plus conversion), teachers (wact/messaging/signups), parents, dojo_islands (blocks), tutor trials. Reasonable breadth of *metrics*, narrow breadth of *task types*.
- **Each pair ships `metric_context` + `schema_context`** to the generator. So the eval tests **SQL generation given the right context**, not retrieval/metric-disambiguation (the harder, more error-prone step in real usage).
- **`expected_answer_facts` are loose and mention-checkable** (e.g. "reports daily active user counts", "covers the last 7 days", "uses fct_daily_user_active as the source"). Easy for a judge to mark covered by keyword echo ⇒ gameable.
- **Blind spots**: no ambiguous/underspecified questions; no unanswerable/"should refuse" cases; no multi-turn; no data-quality traps; no adversarial inputs; no questions where two metrics could plausibly apply. A separate `capability/` suite (~67 pairs: metric_coverage, sparse_documentation, crosswalk) tests coverage/docs, but that is a different axis, not answer quality. `regression/` and `mined/` dirs are empty (`.gitkeep`).

**Representative of real IRIS usage?** Partially — good on "known metric, well-formed question," blind on ambiguity/refusal/judgment, which is where an analyst agent actually fails.

### 2. SQL scoring (`comparator.py`, `engine.py`)

Three methods:

- `NORMALIZED` — sqlglot parse+regen, exact match ⇒ 1.0/0.0. Brittle: equivalent SQL differing in structure scores 0.
- `TOKEN_OVERLAP` (**default**) — count-aware Jaccard on tokens. **Forgiving in both wrong directions**: a query with the right tables/columns but wrong filters/joins can clear 0.8; a correct query phrased differently can miss.
- `EXECUTION` (`compare_sql_by_execution`, async) — the good one: runs both, order-independent numeric-tolerant row compare. But it's **opt-in** (needs `mcp_manager`) and only used as a below-threshold *promotion* fallback, not the primary metric.

**Can wrong SQL pass?** Yes — (a) token overlap ≥0.8 with wrong semantics; (b) even under EXECUTION, the **column-sum boost** promotes to 0.8 when column totals match within 1% (`row_score = max(row_score, 0.8)`) — two different queries with the same aggregate total "pass"; partial shape scores 0.3/0.5 also leak.

**Can correct-but-different SQL fail?** Yes under NORMALIZED and TOKEN_OVERLAP; only EXECUTION handles it, and it's not the default.

There is an optional `numeric_comparator` path (promote FAIL→PASS when the first numeric cell is within `tolerance_pct` of `expected_value`) — a decent cheap check, but also optional and single-value only.

### 3. Answer quality (LLM-as-judge)

**Two implementations coexist** (maintenance smell — unclear which the loop would use):

- `answer_judge.py` `AnswerJudge` — **3 dims** (fact_coverage, sufficiency, accuracy), **hardcoded** prompt, model default **`claude-haiku-4-5`** (cheap/weak judge), `overall` = mean.
- `graders/llm_grader.py` `LLMGrader` — **5 dims** (adds citation_accuracy, completeness), loads `judge_prompt.md` (**sha-tracked** ✅ good), model via `settings.eval_judge_model`. Consumed by `CompositeGrader`.
- `judge_prompt.md` describes **5 dims**; the hardcoded `answer_judge.py` prompt describes **3** — the two are **out of sync**.

`CompositeGrader` weighting: sql_quality 0.3 (code grader) · result_accuracy 0.3 (LLM accuracy+citation) · analysis_quality 0.2 (fact_cov+suff) · completeness 0.1 · efficiency 0.1 (latency).

**Correlate with a human's judgment?** Unknown — **no calibration set, no human spot-check comparison exists.**
**Gameable?** Yes:

- `accuracy`/`result_accuracy` (0.3 of composite) is scored by the judge **without the actual data** — it guesses whether findings "are consistent with what the data would show" ⇒ hallucination-prone and rewardable by confident prose.
- `fact_coverage` rewards echoing the loose `expected_answer_facts` ⇒ verbose fact-stuffing wins.
- No `temperature=0` set ⇒ nondeterministic scores run-to-run.
- Single judge, no ensemble/self-consistency.

### 4. Baseline

`eval/baseline.json` → `baseline_pass_rate: null`, note: blocked on IRIS #945 (W0-2 production baseline). The eval.yml comment logic already **skips the delta line** when null. **No baseline = no improvement evidence**, which is a hard prerequisite for a loop whose whole output is "did this change improve quality."

---

## Verdict: **Augment** (not "trust as-is", not "don't trust at all")

Reuse iris-eval as the **harness** (the code is a fine starting point and confirms DL-0017's "reuse IRIS over adopting promptfoo/Inspect/Harbor"), but do **not** adopt its current default metric as the loop's optimization objective.

**Go/no-go**: **NO-GO** on adopting iris-eval as the loop's primary quality signal in its current form. **Conditional GO** as the harness once the required fixes land. Until then, treat `pass_rate(token_overlap)` as a **smoke test only**, never the objective.

### Required fixes before it can be the signal (gate for #120)

1. **Establish a real baseline** — unblock/track IRIS #945. No deltas count until this exists. (Prerequisite already noted on map #118.)
2. **Make execution-equivalence the primary SQL metric** (not a fallback); demote TOKEN_OVERLAP to a diagnostic. Remove or flag the column-sum→0.8 boost (it manufactures false passes).
3. **Wire an actual scored run** — the loop must run the scoring path (`--generator analyst --e2e` equivalent), not just `--validate`. Decide where the LLM/warehouse cost is paid (loop is manual, so acceptable off-CI).
4. **Harden + consolidate the judge** — one implementation (keep the 5-dim `LLMGrader`, retire `answer_judge.py`), pin model, `temperature=0`, and **calibrate against ~10-15 human-scored outputs** before trusting `answer_quality`. Don't credit judge "accuracy" that isn't grounded in executed results.

### Recommended augmentations (can follow the loop's first pass)

5. Expand coverage with adversarial/ambiguous/unanswerable/multi-turn cases; test the retrieval/disambiguation step, not just SQL-gen-given-context.
6. Track per-dimension scores in the report, not a single blended pass_rate, so the loop optimizes the right sub-signal and Goodhart is visible.

---

## Evidence index (files read)

- `backend/eval/golden_sql/seed.yml` (25 pairs, v1.8), `judge_prompt.md` (5-dim), `capability/*.yml` (~67), empty `regression/`+`mined/`
- `backend/eval/baseline.json` (null)
- `backend/src/iris/eval/{comparator,engine,answer_judge,loader}.py`
- `backend/src/iris/eval/graders/{composite_grader,llm_grader}.py`
- `.github/workflows/eval.yml` (validate-only today)
