---
name: analysis-council
disable-model-invocation: true
model: opus
reasoning: high
description: "Convenes a 2-5 expert council to stress-test an analysis, claim, or judgment call. Graph-first: pulls prior decisions/ADRs from graphify-out when present. Use for \"challenge my thinking\", \"pressure-test this\", \"what am I missing\", or before any high-stakes analytical conclusion. Supports --fast and --verify."
---

# Analysis Council

Run a multi-lens council on an analytical topic — each persona a fresh subagent with a named lens; the output preserves disagreement, not a balanced summary. The daily-driver for "challenge my thinking" / "what am I missing" (collapses the old findings-interrogator, analysis-grill, counterfactual-check, causal-review into one entry point).

**Mechanics:** follow `council-scaffolding` for the full dispatch contract (roster resolution, rounds, synthesis, post-process, persist, report). Only the deltas below are council-specific.

**Dry run first (a full council is expensive).** Before dispatching, preview the roster it would seat, the per-persona models, quorum, and a seat-cost signal without spending a token:

```bash
scripts/council-explain.py "<topic>"     # keyword-matches optional personas; omit topic for the full roster
```

Use it to sanity-check scope (right lenses seated? cost proportional to stakes?) before committing to the run.

## Contract

Consumes: analysis, claim, judgment call, or user-provided analytical context. When the input is a persisted analysis dir (`<date>-<slug>/` per `_docs/analysis-structure.md`), read its README provenance header first — `as_of`, `sources`, `metrics`, `decisions`, and `fingerprint` feed the council directly instead of being re-derived from prose.
Produces: multi-lens council synthesis with disagreement, falsifiers, confidence, and per-expert reads
Requires: independent expert contexts; graph context optional
Side effects: may persist synthesis to `.council/analysis/` when the run reaches the persistence step
Human gates: high-stakes or unresolved decision points are surfaced for human judgment; verification mode may halt on unverified claims

## When to invoke

"Challenge my thinking on X", "what am I missing", "pressure-test this", "is this analysis right", "second opinion", "what would a skeptic say". Routing tiebreakers: single-claim fast check → `--fast`; polish a memo → `strategic-analysis-review` (not a council); build an analysis → `analysis-design` then loop back.

## Modes

| Mode | Personas | Rounds |
|------|----------|--------|
| `--fast` (default for routine claim checks) | required only | 1 |
| default | required + 2–3 smart-picked optional | 2 |
| `--council <names>` | user-specified (≥ the 2 required) | 2 |
| `--verify` | + tool access for claim-testing | 2 |
| `--round-3` | when round 2 produced ≥3 fresh challenges | 3 |

Prefer the lightest mode the stakes justify: bias to `--fast` for "quick/before EOD" and routine single claims; escalate to default/`--round-3` only on "high-stakes/board/irreversible" signals.

## Framing de-bias (run before dispatch)

#8 The topic text carries the user's preferred conclusion; personas anchor on it. Before dispatch: (a) strip conclusion/advocacy language, hand personas the *evidence and question* neutrally, not the verdict; (b) seat one mandatory pass that **steelmans the opposite conclusion**. In `--fast` this collapses to a one-line "strongest case against" prompt to the skeptic.

## Roster

#7 Smart-pick is semantic-first: classify the topic, then use `dispatch_signals` keywords as boosters, not gates. `roster.smart_pick.always_seat` (bias-auditor) is seated on every default/round run so no topic gets a soft roster. Required: `skeptical-data-scientist`, `decision-scientist`. Smart-pick optional by topic: causal language→`causal-reasoner`; cohort/sample-size→`statistician`; missing counterfactual→`counterfactual-check`; judgment call/recommendation (not a data analysis)→`bias-auditor`; child-data/privacy/regulatory→`governance-reviewer`; board/ELT→`exec-audience-stand-in`; ops/SLA→`ops-analyst`; money/pricing→`economist`; charts-as-code (Vega/matplotlib/plotly/ggplot/SQL-fed figures)→`visualization-critic` (encoding-honesty only; craft goes to `dashboard-review`). Cap at `roster.limits.max_experts`.

## Graph context (graph-first)

Detect graphify-out (`.council/graphify-out/` → `graphify-out/` → `docs/`/`decisions/graphify-out/`). Extract topic entities (metrics, services, ADR numbers, decision titles, prior analyses); prefix each persona with related ADRs/decisions/prior-analyses/contradicted-claims; tag findings `[GRAPH]`. `--no-graph` skips; `--graph` forces ingestion first; `--fast` loads 1-hop headline entities only.

## Synthesis template

Headline (≤8 lines: agreement first, then splits) · **Where experts disagreed** (with the crux) · **What would change the picture** (falsifiers) · **Confidence** high/med/low · **Per-expert reads** (80-line cap each). Don't force consensus; a `[VERIFIED: claim breaks]` finding outranks lens-only disagreement.

#4 **"Where experts disagreed" must be non-empty.** If the council found zero splits, that is a *failure signal* (independence broke / roster too homogeneous), not a win — say so explicitly rather than reporting clean consensus.

#3 **Confidence cap (deterministic, applied by synthesis):** any unrebutted `[HIGH]` challenge caps overall confidence at `medium`; any `[VERIFIED: claim breaks]` caps it at `low`. Self-reported persona confidence never overrides these caps.

#2 **Quorum:** if any required persona did not return `status: contributing`, do not emit a confident synthesis — report the run as INVALID with the partial reads that did arrive.

## Post-process

`humanizer: true` (synthesis only, not per-expert), `domain_cleaner: null` (slop-cleaner retired per DL-0008). Persist to `.council/analysis/`.
