---
name: narrative-council
description: "Convenes a council to evaluate a long-form arc (multi-session, series, multi-volume) for through-line coherence, character-arc handoffs, escalation, and seeded payoffs. Graph-first from canon. Macro-scale; distinct from worldbuilding-council and pacing-review."
---

# Narrative Council

Audits the **macro** narrative — multi-session campaigns, multi-novel sagas, generational sweeps. The question: across the long arc, do through-lines hold, do payoffs land where seeded, do character handoffs work? (worldbuilding-council audits the world; pacing-review audits one work's rhythm.)

**Mechanics:** follow `council-scaffolding`. Uses worldbuilding personas read through a narrative lens; wave-based round 1 like worldbuilding-council. Deltas below.

## When to invoke
Multi-novel saga / novella series / multi-season arc planning, multi-arc D&D campaign review, generational saga audits, "does this 5-book arc hang together?". Routing: world coherence → `worldbuilding-council`; single-work pacing → `pacing-review`; single arc/scene → `story-outline`/`scene-craft`.

## Roster
Required: `historian`, `political-scientist`, `anthropologist`. Optional: `economist`, `ecologist`, `theologian`, `military-strategist`, `linguist`. (No separate narrative personas — the worldbuilding personas read narrative through their domain lens.) Round 1 in waves (foundational → derivative).

## Graph context (graph-first, default on)
Tracing through-lines across the timespan needs the graph. Detect graphify-out (`.council/` → cwd → `campaign/`/`lore/`/`world/`/`manuscripts/graphify-out/`). Extract characters/factions/themes/symbols/prophecies/oaths/debts; per entity pull a **timeline trace** (each appearance w/ book·chapter·session ref + state) and per thread the **seed→escalation→payoff chain**. Tag `[GRAPH]`; multi-unit through-lines `[GRAPH-TIMELINE]`. `--no-graph` skips.

## Synthesis template
Headline (≤10 lines) · **Through-line health** (each thread: seeded@X, escalated@Y, pays off@Z — STRONG/WEAK/MISSING) · **Character handoffs** (clean/rough/dropped) · **Off-page consequence chain** (landed/dropped/over-explained) · **Pacing across the macro arc** (flag false climaxes, sags) · **Productive vs arc-breaking inconsistencies** · **Per-expert reads**.

## Post-process
`humanizer: false`, `domain_cleaner: null`. Persist to `.council/narrative/`.
