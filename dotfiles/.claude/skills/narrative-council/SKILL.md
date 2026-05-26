---
name: narrative-council
description: Convenes a council to evaluate a multi-session arc, series-of-novellas, multi-volume work, or generational sweep — focusing on through-line coherence, character arc handoffs, escalation curve, and whether the long-form payoffs are seeded. Graph-first by default — auto-loads canon and prior-session context from `graphify-out/` when present so the council can trace through-lines across the timespan. Distinct from worldbuilding-council (which audits the world) and pacing-review (which audits a single unit) — narrative-council reads at the macro narrative scale.
---

# Narrative Council

## Purpose

`worldbuilding-council` audits the world's coherence. `pacing-review` audits a single work's rhythm. **`narrative-council`** audits the macro narrative — multi-session campaigns, multi-novel sagas, generational sweeps. The question: across this long arc, do the through-lines hold, do the payoffs land where they should, and do the character handoffs work?

## When to invoke

- Planning a multi-novel saga, novella series, or multi-season story arc
- D&D campaign multi-arc review (where the campaign spans many sessions)
- Generational saga audits (where characters age, die, hand off to descendants)
- "Does this 5-book arc actually hang together?"

Routing:
- World coherence → `worldbuilding-council`
- Single-work pacing → `pacing-review`
- Single arc / chapter / scene → `story-outline` / `scene-craft`

## Process

### 1. Parse invocation

Identify:
- Scope: number of works / sessions / generations
- Existing material: outlines, drafts, session-logs, lore
- Mode flags: `--graph` (force graphify ingestion first), `--no-graph` (skip even if graph exists), `--council <list>`, `--round-3`

### 2. Resolve roster

Defaults (uses worldbuilding personas + narrative-specific lenses):
- Required: `historian`, `political-scientist`, `anthropologist`
- Optional: `economist`, `ecologist`, `theologian`, `military-strategist`, `linguist`

(No separate "narrative-specific" personas — the worldbuilding personas read narrative through their domain lens; the council framing is what differs.)

### 2.5. Load canon and timeline context (GRAPH-FIRST — default behavior)

Macro narrative councils are **graph-first by default**. The whole point is tracing through-lines across the timespan — without a graph, the council reads a single snapshot and misses the chain from book 1 setup to book 4 payoff.

Check for graphify-out in this order:
1. `.council/graphify-out/` in cwd
2. `graphify-out/` in cwd
3. `campaign/graphify-out/`, `lore/graphify-out/`, `world/graphify-out/`, `manuscripts/graphify-out/`
4. The `~/.council-sessions/<project-slug>/graphify-out/` fallback

**If a graph is found (or `--graph` is passed)**:
- Extract entities and through-line threads from the topic: character names, faction names, settlement names, themes, recurring symbols, prophecies, oaths, debts, hidden parentage, dropped weapons, etc.
- For each entity, query the graph for the **timeline trace** — every appearance with its book/chapter/session reference and the state of the entity at that moment.
- For each through-line thread, query for the **seed → escalation → payoff chain** across the timespan.
- Bundle into a **canon-and-timeline-context block** prefixed to every persona's dispatch prompt:
  ```
  ## Canon and timeline context (from knowledge graph)
  Entities active across the topic: <list>
  Per-entity timeline trace: <list with book/chapter/session refs>
  Through-line threads detected: <list — each with seed point, escalations, current state, intended payoff point>
  Dropped or stalled threads: <list>
  Cross-arc dependencies: <list>
  ```
- In the synthesis, tag any persona finding that builds on canon-context as `[GRAPH]`. Tag through-line analyses that span multiple units as `[GRAPH-TIMELINE]`.

**If no graph is found AND user did not pass `--graph`**:
- Skip the canon-context block.
- In synthesis output, add a one-line note: "No canon graph detected — council reviewed at single-snapshot scope. For multi-arc through-line tracing, run `graphify` on the manuscript / session-logs and re-invoke."

**If `--no-graph` is passed**:
- Force-skip graph lookup. Use when reviewing a fresh planning doc that isn't yet in canon.

### 3. Dispatch round 1 in waves (like worldbuilding-council)

Same wave structure as `worldbuilding-council`. Foundational personas first, then derivative.

### 4. Dispatch round 2 (parallel)

Response-to-experts pass. Each persona's narrative lens:
- **Historian**: do the timeline beats land in order? Do the off-page events ripple correctly into on-page consequences?
- **Political-scientist**: do the political arcs escalate or deflate believably across the timespan?
- **Anthropologist**: do cultural changes track plausibly across generations?
- **Economist**: are economic shifts (rise/fall of houses, trade routes, tech shifts) consistent with the timespan?
- **Ecologist**: are environmental / ecological arcs (climate change, beast extinctions) seeded and paid off?
- **Theologian**: do religious arcs (schism, reform, heresy, conversion) track the timeline?
- **Military-strategist**: are conflicts properly seeded by earlier political / economic shifts?
- **Linguist**: does language shift believably (loanwords from contact, register drift) across the timespan?

### 5. Synthesize

```markdown
# Narrative Council on: <work title / arc>

## Synthesis
<≤10 lines: does the long arc hang together, where are the through-lines strong, where do they sag, what payoffs are at risk>

## Through-line health
- **<thread name>**: seeded at <X>, escalated at <Y>, pays off at <Z> — STRONG | WEAK | MISSING
- ...

## Character handoffs (for generational / large-cast works)
- <character A's arc closes at X, character B picks up the through-line at Y> — clean | rough | dropped

## Off-page consequence chain
- <event in book 1> → <consequence felt in book 3> — landed | dropped | over-explained

## Pacing across the macro arc
- <book/arc 1 escalation level>
- <book/arc 2 escalation level>
- ...
<flag false climaxes, sags, missing breathing room at the macro level>

## Productive inconsistencies (story fuel)
- ...

## Inconsistencies that break the arc
- ...

## Per-expert reads
...
```

### 6. Post-process

- humanizer: false (preserve persona voice)
- domain_cleaner: null

### 7. Persist

`.council/narrative/<YYYY-MM-DD>-<work-slug>.md`.

## Contract

Consumes: outlines / drafts / session-logs / canon for a multi-unit work
Produces: narrative-arc-level council synthesis + per-expert reads
Requires: _personas/ (worldbuilding personas), _council-scaffolding/
Side effects: writes to .council/narrative/
Human gates: none — fire-and-read

## Context

Typical workflows: multi-book / multi-arc planning, mid-saga audit, pre-final-volume review
Pairs well with: worldbuilding-council (single-snapshot world audit), pacing-review (single-unit pacing), story-outline (per-volume structure), narrative-purpose-guide (per-scene mission)
