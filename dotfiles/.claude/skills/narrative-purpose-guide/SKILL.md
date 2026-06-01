---
name: narrative-purpose-guide
description: "Produces a \"mission card\" for one narrative unit (scene, chapter, act): what it must accomplish, what the reader should feel, what's at risk. Modes: --from-outline, --unit, --check. Embedded in scene-craft; keeps units anchored to the larger work."
---

# Narrative Purpose Guide

## Purpose

Most flat scenes / chapters / acts fail because the author lost sight of *why this unit exists in the work*. This skill produces a concise "mission card" per unit that the drafter (or the future reviewer) can hold against the draft.

## When to invoke

Three modes:

### `--unit=<level>`
Produce a single mission card for one unit.
Examples: `narrative-purpose-guide --unit=scene "the dinner before the funeral"`

### `--from-outline`
Batch-produce mission cards for every unit in a `story-outline` output.
Example: `narrative-purpose-guide --from-outline .writing/outlines/title.md`

### `--check`
Compare a draft against the mission card and flag what didn't land.
Example: `narrative-purpose-guide --check .writing/scenes/scene-12.md`

Routing:
- Scene-level execution → `scene-craft` (this skill is embedded there)
- Story structure → `story-outline`
- Pacing across many units → `pacing-review`

## Unit levels

| Level | Scope | Length |
|-------|-------|--------|
| scene | One continuous moment, one POV, one location-or-time block | ~500–3000 words |
| sequence | A run of 2–6 scenes that together form a movement | ~3000–10000 words |
| chapter | A reader-facing structural break | ~2000–6000 words |
| act | A major movement of the work | ~10000–40000 words |

User can specify any level; default is `scene`.

## Process

### 1. Identify the unit

- Slug or name
- Where it sits in the larger work (act / chapter / position)
- POV character(s)

### 2. Determine the mission (single-card mode)

A mission card answers six questions:

- **Function**: What does this unit do for the larger work? (Setup, escalation, reveal, payoff, breath, transition, recontextualization.)
- **Reader-state-after**: What does the reader / player know or feel after this unit that they didn't before?
- **Character-state-after**: What's different for the POV character?
- **Risk if missing**: What breaks in the larger work if this unit doesn't deliver?
- **Emotional register**: The unit's primary emotional shape. (Dread, comedy, grief, suspense, awe, etc.)
- **Anti-mission**: What this unit is NOT for. Drafters drift; the anti-mission keeps them honest.

### 3. Batch mode (`--from-outline`)

Read the outline. For each unit:
- Auto-fill function from the outline's stated role
- Draft reader-state-after / character-state-after from the outline's per-unit notes
- Risk-if-missing from the through-line dependencies
- Emotional register inferred from neighboring units (contrast)
- Anti-mission from what other nearby units claim

User can edit any card before locking.

### 4. Check mode (`--check`)

Compare draft to the mission card. For each of the six dimensions, answer:
- Did it land?
- If partial: what specifically is missing?
- If failed: what to do — rewrite the draft, or rewrite the card?

Output the check as a report with concrete fixes.

### 5. Output (single-card mode)

```markdown
# Mission card: <unit slug>

**Level**: scene | sequence | chapter | act
**Position in work**: <act/chapter/scene reference>
**POV**: <character>

## Function
<one phrase: setup | escalation | reveal | payoff | breath | transition | recontextualization>

## Reader-state-after
<what the reader knows or feels after this unit that they didn't before>

## Character-state-after
<what's different for the POV character — new info, new emotional position, new constraint>

## Risk if missing
<what breaks in the larger work if this unit doesn't deliver>

## Emotional register
<primary register, contrast to neighbors>

## Anti-mission
<what this unit is NOT for; what would tempt the drafter to add and shouldn't>

## Optional: opening line, closing line, key beat
- Opening: ...
- Key beat: ...
- Closing: ...
```

### 6. Output (`--check` mode)

```markdown
# Mission check: <unit slug>

## Mission card recap
<the card being checked against>

## Did it land?
- **Function**: yes | partial | no — <why>
- **Reader-state-after**: yes | partial | no — <why>
- **Character-state-after**: yes | partial | no — <why>
- **Risk-if-missing**: was this unit doing the work? — <why>
- **Emotional register**: matched | drifted to <other register>
- **Anti-mission**: respected | breached at <specific drift>

## Specific fixes
- <concrete edit or addition>
- <concrete cut>
- <reframe suggestion>

## Should the card change instead?
<sometimes the draft revealed a better mission — note if so>
```

### 7. Persist

`.council/missions/<unit-slug>.md` — mission cards live with council outputs in the same `.council/` tree.

## Rules

- A mission card is ≤1 page. If you can't compress, the unit doesn't have a clear purpose yet.
- The anti-mission is non-negotiable — drafters drift; the anti-mission catches drift.
- In check mode, the right answer is *sometimes* "rewrite the card, not the draft." The draft may have found something better than the plan.
- Don't moralize about emotional register — comedy, dread, tenderness, awe are all valid; the check is whether the register matches the surrounding work's curve.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Surrounding units' mission cards** (if any exist in `.council/missions/`)
- **Characters' state at this point** in the work — knowledge, emotional position, location
- **Open threads** touching this unit — what's seeded here, what should pay off later
- **Adjacent unit register and density** — for contrast / pacing alignment

Insertion point: step 2 (determine mission) — graph context informs the mission relative to neighbors. Tag findings as `[GRAPH-NEIGHBOR]`.

`--no-graph` skips. `--graph` forces graphify on the manuscript first.

## Contract

Consumes: unit slug + position + POV; or story outline; or unit draft + mission card
Produces: mission card OR batch of cards OR check report
Requires: nothing (can be invoked standalone, or embedded in scene-craft)
Side effects: writes to .council/missions/
Human gates: in check mode, user decides whether to rewrite the draft or the card

## Context

Typical workflows: pre-drafting per-unit anchoring, batch-up-front from outline, post-draft audit
Pairs well with: scene-craft (embeds this), story-outline (upstream for batch mode), pacing-review (across cards)
