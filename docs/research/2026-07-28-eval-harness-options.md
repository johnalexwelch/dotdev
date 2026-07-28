# Research — eval harness options for AI-response quality (wayfinder #119)

**Ticket:** [#119](https://github.com/johnalexwelch/dotdev/issues/119) · **Map:** [#118](https://github.com/johnalexwelch/dotdev/issues/118)
**Date:** 2026-07-28 · **Type:** research (AFK) · **Status:** provisional — final pick revisits after [#120](https://github.com/johnalexwelch/dotdev/issues/120) (what-gets-evaluated)

## Criteria (from the ticket)

Local-first · no vendor lock · Claude/Anthropic support · scores **agent/skill outputs** (not just single prompts) · **machine-readable** scores the loop can rank. *("cheap to run manually" dropped 2026-07-28 per Alex — run cost is not a constraint.)*

## Landscape

| Framework | License/host | Scores agents? | Local & cheap | Machine-readable | Fit note |
|---|---|---|---|---|---|
| **promptfoo** | Apache-2 (now under OpenAI) | prompt→response native; agent via custom providers | ✅ CLI, config-driven, local | ✅ JSON/YAML out | Strong for prompt/response scoring; Anthropic first-class; huge adoption |
| **Inspect AI** (UK-AISI) | MIT | ✅ solver-scorer, agent tasks | ✅ Python, local | ✅ structured logs | Rigorous + mature; best when unit = full agent task run |
| **DeepEval** | Apache-2 | metric-based (LLM-judge) | ✅ pytest-style, free | ✅ | 50+ built-in metrics; good if we want Python judge metrics |
| **Harbor** | Apache-2, ~3.6k★, Aug-2025 | ✅ containerized agent eval, pre-integrates Claude Code | ✅ local (container) | ✅ dataset-based | Best conceptual fit for "score agent runs"; sole knock is **maturity** (very new) |
| Braintrust / LangSmith / Arize Phoenix | hosted/SaaS | ✅ | ❌ vendor lock / observability-first | ✅ | Fails no-vendor-lock; skip |
| Coder Eval / OpenEval / AgentEval Lab | OSS, niche | ✅ CLI-agent A/B, local dashboards | ✅ | ✅ | Watch-list; young, narrow |

## Recommendation (provisional)

Run cost is not a constraint, so the pick is **cleanly gated on the evaluation unit** decided in #120 — no cost thumb on the scale:

- **If unit = prompt→response pairs / skill-output snippets** → **promptfoo** (native, config-driven, Anthropic-first, JSON the ranker consumes).
- **If unit = full agent task runs** → **Inspect AI** (mature, MIT, local) as primary, with **Harbor** a live contender — its Claude-Code container integration is the cleanest conceptual fit; the only reason to prefer Inspect over Harbor is Harbor's immaturity (Aug-2025). If Harbor proves stable during a spike, it wins the agent-run case.
- **LLM-as-judge metrics** (groundedness, conciseness, format adherence) can ride on either via DeepEval-style rubric scorers.

**Lean:** no default winner ahead of #120 — resolve the eval unit first, then pick promptfoo (prompt→response) or Inspect AI/Harbor (agent runs). Harbor is a watch-list contender on maturity alone, no longer discounted for weight.

## Open dependency

Locking the harness **before** #120 defines the corpus + quality dimensions risks tooling for undefined requirements. Recommendation: treat this as *provisional selection* → confirm/finalize as a follow-up once #120 lands.

## Sources

- Harbor: <https://www.harborframework.com/docs> · <https://github.com/harbor-framework/harbor>
- Eval frameworks compared (2026): <https://thepromptbench.com/evals-and-testing/eval-frameworks-compared/>
- promptfoo vs Inspect AI: <https://aicoolies.com/comparisons/promptfoo-vs-inspect-ai>
- Braintrust vs promptfoo vs DeepEval: <https://aicraftguide.com/article/braintrust-vs-promptfoo-vs-deepeval-llm-eval-stack-2026>

*Evidence tier: **inferred** (synthesized web research, 2026-07-28); framework capabilities not hands-on verified this session.*
