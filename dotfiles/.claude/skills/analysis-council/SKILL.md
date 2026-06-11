---
name: analysis-council
model: opus
description: "Convenes a 2-5 expert council to stress-test an analysis, claim, or judgment call. Graph-first: pulls prior decisions/ADRs from graphify-out when present. Use for \"challenge my thinking\", \"pressure-test this\", \"what am I missing\", or before any high-stakes analytical conclusion. Supports --fast and --verify."
---

# Analysis Council

Run a multi-lens council on an analytical topic — each persona a fresh subagent with a named lens; the output preserves disagreement, not a balanced summary. The daily-driver for "challenge my thinking" / "what am I missing" (collapses the old findings-interrogator, analysis-grill, counterfactual-check, causal-review into one entry point).

**Mechanics:** follow `council-scaffolding` for the full dispatch contract (roster resolution, rounds, synthesis, post-process, persist, report). Only the deltas below are council-specific.

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

## Roster
Required: `skeptical-data-scientist`, `decision-scientist`. Smart-pick optional by topic: causal language→`causal-reasoner`; cohort/sample-size→`statistician`; missing counterfactual→`counterfactual-check`; judgment call/recommendation (not a data analysis)→`bias-auditor`; child-data/privacy/regulatory→`governance-reviewer`; board/ELT→`exec-audience-stand-in`; ops/SLA→`ops-analyst`; money/pricing→`economist`. Cap at `roster.limits.max_experts`.

## Graph context (graph-first)
Detect graphify-out (`.council/graphify-out/` → `graphify-out/` → `docs/`/`decisions/graphify-out/`). Extract topic entities (metrics, services, ADR numbers, decision titles, prior analyses); prefix each persona with related ADRs/decisions/prior-analyses/contradicted-claims; tag findings `[GRAPH]`. `--no-graph` skips; `--graph` forces ingestion first; `--fast` loads 1-hop headline entities only.

## Synthesis template
Headline (≤8 lines: agreement first, then splits) · **Where experts disagreed** (with the crux) · **What would change the picture** (falsifiers) · **Confidence** high/med/low · **Per-expert reads** (80-line cap each). Don't force consensus; a `[VERIFIED: claim breaks]` finding outranks lens-only disagreement.

## Post-process
`humanizer: true` (synthesis only, not per-expert), `domain_cleaner: slop-cleaner (analysis mode)` → now `slop-cleaner --mode analysis`. Persist to `.council/analysis/`.
