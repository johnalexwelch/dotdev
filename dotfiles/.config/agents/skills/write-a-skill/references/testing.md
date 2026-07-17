# Testing skill wording

Companion to `write-a-skill/SKILL.md`. Reach for this when a skill **shapes behavior under pressure** — a discipline rule the agent knows and skips, or an output whose shape keeps drifting. Pure reference skills (definitions, API facts) don't need it: verify those by retrieval, not pressure.

The root move: **you don't know a wording works until you've watched the agent fail without it.** Guidance written from imagination fixes imagined failures. Write from observed ones.

## Baseline first (RED)

Before writing the guidance, run the tempting scenario *without* it:

1. Fresh-context sample — a raw API call, or a single-shot subagent. System prompt = the realistic context the guidance will live in (the whole skill or prompt template, not the line in isolation). User message = a task that tempts the failure.
2. Record verbatim what the agent did and every rationalization it gave. Those exact excuses become the rationalization table.
3. If the baseline *doesn't* exhibit the failure, stop — there's nothing to fix, and guidance added anyway is a **no-op** that only costs load.

## Micro-test the wording (GREEN)

Cheaper than full pressure runs; use it to converge wording before spending a scenario battery.

- **Always include a no-guidance control.** The comparison is the measurement.
- **5+ reps per variant.** Single samples lie.
- **Read every flagged match by hand.** Template echoes and quoted counter-examples masquerade as hits; automated counts overstate both failure and success.
- **Variance is a metric.** When guidance binds, reps converge on the same shape. Five different interpretations across five reps means the wording isn't binding — tighten the form (see *Match the form to the failure* in SKILL.md) before adding words.

Micro-tests verify wording. They don't replace a real pressure-scenario battery for a hard discipline skill — that's the final gate.

## Bulletproofing (discipline failures only)

Scope: an agent that *knows* the rule and skips it under pressure. On wrong-shaped or omitted output, prohibition-based bulletproofing backfires — use the recipe/structural forms from *Match the form to the failure* instead.

**Close every loophole explicitly.** Don't state the rule and stop — forbid the specific workarounds the baseline revealed.

- Weak: "Write code before the test? Delete it."
- Strong: "Write code before the test? Delete it. Start over. Don't keep it as reference, don't adapt it while writing the test, don't look at it. Delete means delete."

**Cut the spirit-vs-letter escape** with a foundational line early: "Violating the letter of the rules is violating the spirit of the rules." This kills a whole class of "I'm following the spirit" rationalizations at once.

**Rationalization table** — every excuse from the RED baseline, with its rebuttal:

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. The test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "It's the spirit, not the ritual" | The letter *is* the spirit. Follow it. |

**Red-flags list** — self-check phrases that all mean STOP, so the agent can catch itself mid-rationalization:

```
- "I already manually verified it"
- "This case is different because…"
- "Close enough to done"
```

Add the strongest violation symptom to the skill's `description` too, so the skill loads exactly when the agent is about to slip.
