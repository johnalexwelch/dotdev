# Research — eval harness options for AI-response quality (wayfinder #119)

**Ticket:** [#119](https://github.com/johnalexwelch/dotdev/issues/119) · **Map:** [#118](https://github.com/johnalexwelch/dotdev/issues/118)
**Date:** 2026-07-28 · **Type:** research (AFK) · **Status:** provisional — final pick revisits after [#120](https://github.com/johnalexwelch/dotdev/issues/120) (what-gets-evaluated)

## Criteria (from the ticket)

Local-first · no vendor lock · Claude/Anthropic support · cheap to run manually · scores **agent/skill outputs** (not just single prompts) · **machine-readable** scores the loop can rank.

## Landscape

| Framework | License/host | Scores agents? | Local & cheap | Machine-readable | Fit note |
|---|---|---|---|---|---|
| **promptfoo** | Apache-2 (now under OpenAI) | prompt→response native; agent via custom providers | ✅ CLI, config-driven | ✅ JSON/YAML out | Strongest default for prompt/response scoring; Anthropic first-class; huge adoption |
| **Inspect AI** (UK-AISI) | MIT | ✅ solver-scorer, agent tasks | ✅ Python, local | ✅ structured logs | Rigorous; best when unit = full agent task run; more setup |
| **DeepEval** | Apache-2 | metric-based (LLM-judge) | ✅ pytest-style, free | ✅ | 50+ built-in metrics; good if we want Python judge metrics |
| **Harbor** | Apache-2, ~3.6k★, Aug-2025 | ✅ containerized agent eval, pre-integrates Claude Code | ⚠️ container overhead, immature | ✅ dataset-based | Best conceptual fit for "score agent runs" but very new + heavy |
| Braintrust / LangSmith / Arize Phoenix | hosted/SaaS | ✅ | ❌ vendor lock / observability-first | ✅ | Fails no-vendor-lock; skip |
| Coder Eval / OpenEval / AgentEval Lab | OSS, niche | ✅ CLI-agent A/B, local dashboards | ✅ | ✅ | Watch-list; young, narrow |

## Recommendation (provisional)

The right pick **depends on the evaluation unit** decided in #120:

- **If unit = prompt→response pairs / skill-output snippets** → **promptfoo** as the backbone. CLI + config, local, Anthropic-native, cheap manual runs, JSON output the ranker consumes. Lowest friction; matches "manual for now."
- **If unit = full agent task runs (sandboxed)** → **Inspect AI** (mature, MIT, local) as primary; keep **Harbor** on the watch-list to revisit once it matures — its Claude-Code container integration is the cleanest conceptual fit but too green to bet on today.
- **LLM-as-judge metrics** (groundedness, conciseness, format adherence) can ride on either via DeepEval-style rubric scorers.

**Lean:** start with **promptfoo** — it satisfies every criterion at the lowest cost, and the loop is manual/small at first. Escalate to Inspect AI only if #120 defines the unit as full agent runs. **Do not adopt Harbor yet** (maturity risk); reassess in a later map pass.

## Open dependency

Locking the harness **before** #120 defines the corpus + quality dimensions risks tooling for undefined requirements. Recommendation: treat this as *provisional selection* → confirm/finalize as a follow-up once #120 lands.

## Sources

- Harbor: https://www.harborframework.com/docs · https://github.com/harbor-framework/harbor
- Eval frameworks compared (2026): https://thepromptbench.com/evals-and-testing/eval-frameworks-compared/
- promptfoo vs Inspect AI: https://aicoolies.com/comparisons/promptfoo-vs-inspect-ai
- Braintrust vs promptfoo vs DeepEval: https://aicraftguide.com/article/braintrust-vs-promptfoo-vs-deepeval-llm-eval-stack-2026

*Evidence tier: **inferred** (synthesized web research, 2026-07-28); framework capabilities not hands-on verified this session.*
