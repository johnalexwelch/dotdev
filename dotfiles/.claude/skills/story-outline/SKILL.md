---
name: story-outline
description: Builds a structural outline for a story, novel, novella, or arc. Works at three scales — sequence-of-scenes, chapter-by-chapter, or act-level — and grounds every unit in protagonist desire, opposition, and change. Use when the user wants to outline a longer work, plan a novel, sketch an arc, or move from premise to structure.
---

# Story Outline

## Purpose

Turn a premise into a structural outline. Works for:
- Multi-chapter novel outlines
- Novella or novelette structure
- D&D campaign arcs
- Series-of-scenes for a short

The output is a structural map where every unit has a purpose: who wants what, who opposes, what changes.

## When to invoke

- "Outline this story / novel / arc"
- "Help me sketch the structure"
- "I have a premise but no plot"
- "Move my pile of scenes into a sequence"

Routing:
- Pre-structure ideation → `writing-fragments`
- Post-structure drafting → `writing-shape`
- Single-scene focus → `scene-craft` + `narrative-purpose-guide`
- Pacing audit on existing outline → `pacing-review`

## Process

### 1. Lock the premise

Force a one-sentence statement: "<Protagonist> wants <goal>, but <opposition>, so they must <action>." If the user can't compress to one sentence, that's the first problem to solve.

### 2. Pick the scale

Ask once (if not specified):
- **Sequence (10–20 scenes)** — short story, single sitting
- **Chapter-level (15–40 chapters)** — novella, novel
- **Act-level (3–7 acts)** — epic, multi-volume, campaign arc

### 3. Frame the change

What's different at the end vs. the start — for the protagonist, the world, or both? A story is "and so things are different now." If nothing changes, there's no story.

### 4. Identify the act / arc beats

Use a structure the user prefers, or default to **Four-Act Structure**:

- **Act 1 — Setup**: ordinary world, inciting incident, lock-in (protagonist commits to the action)
- **Act 2a — Rising action**: tests, allies, complications. New rules learned.
- **Act 2b — Crisis**: midpoint reversal. What protagonist wanted is now in question.
- **Act 3 — Climax and resolution**: confrontation, decision, change

Alternative structures user may prefer:
- Three-act (Setup / Confrontation / Resolution)
- Seven-point (Hook / Plot Turn 1 / Pinch 1 / Midpoint / Pinch 2 / Plot Turn 2 / Resolution)
- Hero's Journey
- Save the Cat beat sheet

### 5. Fill in the units

For each scene / chapter / act:
- **Unit title or label**
- **Who wants what**: the protagonist (or POV character) and their immediate goal in this unit
- **Opposition**: what's in the way (person, situation, internal flaw, lack of information)
- **What changes**: the unit ends with the world or character in a different state than it began
- **Connection to the larger arc**: how this unit advances the through-line

Don't fill in dialogue or prose. This is structure.

### 6. Stress-test the outline

For each unit, ask:
- Is there a clear "want"? If no, it's exposition, not story.
- Is there opposition? If no, it's wish fulfillment.
- Does something change? If no, the unit is fat.
- Could you skip this unit and lose nothing? If yes, cut or merge.

### 7. Output

```markdown
# <Working title>

## Premise
<one sentence>

## Change
<from X to Y, for who>

## Structure: <chosen scale>

### Act 1 (Setup)
- **Unit 1 — <title>**: <who wants what>, opposed by <X>, changes <Y>
- **Unit 2 — <title>**: ...
- ...

### Act 2a (Rising action)
- **Unit N — <title>**: ...

### Act 2b (Crisis / Midpoint)
- ...

### Act 3 (Climax / Resolution)
- ...

## Through-lines
- **Protagonist arc**: <from internal-state-A to internal-state-B>
- **World arc**: <from external-state-A to external-state-B>
- **Theme**: <the question the story is asking>

## Open structural questions
- <unit X feels thin — needs more opposition>
- <act-2-to-3 transition is abrupt>
- <where does <subplot> resolve?>

## Next step
- Pacing audit: `pacing-review`
- Per-scene purpose cards: `narrative-purpose-guide --unit=scene --from-outline`
- Begin drafting: `writing-shape` per chapter
```

### 8. Persist

`.writing/outlines/<title-slug>.md`. Falls back to `~/Documents/writing/<title-slug>.md` if no `.writing/` exists.

## Rules

- Premise must compress to one sentence. If it can't, you don't have a premise yet.
- Every unit has a want + opposition + change. No exceptions for "this scene establishes mood" — find the want under the mood.
- Don't over-specify. The outline is a map, not the territory.
- Leave 3–5 open structural questions visible — they reveal where the next draft pass should focus.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Prior outlines / arcs** in the same series — established structure conventions
- **Characters** with existing arcs — the new outline must respect or deliberately diverge
- **World state** — what's established that constrains plotting
- **Open threads** from prior works that this outline could pick up

Insertion point: step 1 (lock the premise) — surface existing series-canon that constrains the premise. Tag canon-grounded findings as `[GRAPH-SERIES-CANON]`.

`--no-graph` skips (use for clean-slate / standalone work). `--graph` forces graphify on prior series docs first.

## Contract

Consumes: premise + optional scale preference + optional structural model
Produces: structural outline with per-unit purpose
Requires: nothing
Side effects: writes to .writing/outlines/ or fallback path
Human gates: user must commit to a premise sentence; one clarifying question max

## Context

Typical workflows: pre-drafting structure, outline-first writers, planning long fiction or campaigns
Pairs well with: writing-fragments (upstream ideation), pacing-review (downstream audit), scene-craft (down a level), narrative-purpose-guide (per-unit mission), worldbuilding-council (if the setting needs review first)
