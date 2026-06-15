# OKR Rubric & Worked Example

Companion to `okr-generator/SKILL.md`.

## Scorecard (run each KR through it)

| Test | Pass looks like | Fail signal |
|------|-----------------|-------------|
| Outcome not output | measures an effect | "ship / launch / build X" |
| Baseline present | `from A → to B` | bare target "reach B" |
| Definition rigor | passes `metric-design` | numerator/denominator unclear |
| Gameability | no cheap way to hit it while missing the objective, or a guardrail pairs it | obvious lazy path exists |
| Attributable | team can move it | depends on exogenous forces |
| Ambition | ~70% = success | certain 100% (sandbag) or impossible |

## Anti-patterns

- **Task lists in KR clothing.** A quarter of "ship A, ship B, ship C" — those are initiatives; the KRs are what shipping them should cause.
- **Vanity numerators.** "Total registered users" (only goes up) instead of "active connected families" (can fall — therefore informative).
- **No guardrails.** Every growth KR with no paired quality/cost counter-metric.
- **Too many objectives.** 5 objectives × 5 KRs = no focus; cut to ≤3 objectives.

## Worked example — bet: "make the family the durable unit, not the classroom"

**Objective:** Families stay connected even when a child changes classroom or teacher.

| KR | baseline → target | window | owner |
|----|-------------------|--------|-------|
| Monthly active connected families | [baseline] → +[X]% | quarter | PM |
| Families retaining connection across a teacher change | [baseline]% → [target]% | quarter | PM |
| **Guardrail:** teacher-side weekly active does not fall | hold ≥ [baseline] | quarter | PM |

Why it passes: objective is directional (a state, not a number); KRs are outcomes with baselines; the guardrail blocks the cheap win of pushing family metrics by over-prompting teachers. KR definitions ("connected family," "retaining connection") are pinned via `metric-design`, not left to interpretation.
