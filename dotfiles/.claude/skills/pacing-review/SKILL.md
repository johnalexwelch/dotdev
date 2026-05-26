---
name: pacing-review
description: Audits a draft, outline, or arc for pacing — scene rhythm, escalation curve, breathing room, dead weight, and whether the reader's attention stays engaged across the full work. Use when a draft "drags," "feels rushed," or when an outline has too many flat units in a row.
---

# Pacing Review

## Purpose

Audit a work for pacing — the moment-to-moment rhythm and the macro escalation curve. Most "this is dragging" problems have a structural cause: scenes in the same emotional register, stalled escalation, repeated beats, or breathing room placed in the wrong spot.

## When to invoke

- User says the draft "drags" or "feels rushed"
- Mid-outline review to catch escalation problems before drafting
- Pre-publication audit
- After a beta reader flags pacing
- D&D arc / campaign pacing check

Routing:
- Per-scene problem → `scene-craft`
- Character flatness across scenes → `character-arc`
- Restructure recommendation → `story-outline` (after this surfaces the structural issue)

## Process

### 1. Identify the unit of analysis

Scene-by-scene, chapter-by-chapter, or act-by-act. Pick the level at which the pacing concern lives. Most novel pacing audits are chapter-level; most short fiction is scene-level.

### 2. Tag each unit with three signals

For each unit, tag:

- **Register**: action | dialogue | reflection | exposition | description
- **Stakes**: low | medium | high | climactic
- **Information density**: low (atmospheric) | medium | high (new revelations, plot turns)

You don't need exhaustive tagging — first impressions are fine. The goal is the *pattern*, not perfection per unit.

### 3. Scan for pacing anti-patterns

- **Same-register clustering**: 3+ reflection units in a row, or 3+ action units in a row, with no contrast.
- **Stalled escalation**: stakes flat across 5+ units. The reader feels nothing is changing.
- **Exposition lump**: a high-density information unit not buffered by lower-density units before / after.
- **False climax**: high-stakes unit followed by no breathing room, immediately into next high-stakes unit.
- **Missing release**: climactic unit not followed by a denouement / breathing unit.
- **Repeated beat**: the same emotional beat (e.g., "character discovers betrayal") hit twice without escalation.
- **Dead-weight unit**: low stakes + low information + same register as neighbors = candidate for cut.
- **Pacing valley**: 3+ units of low stakes in a row in the middle. The "saggy middle."

### 4. Diagnose the macro curve

Sketch the escalation curve: stakes over time. Look for:
- Does it rise to the climax?
- Are there false peaks that release tension prematurely?
- Is the climax distinct from the surrounding stakes?
- Is the denouement long enough to land the change?

### 5. Output the audit

```markdown
# Pacing Review: <work title>

## Macro curve
<one paragraph: does the stakes curve rise meaningfully to climax, where are the false peaks, where does it sag>

## Anti-patterns found
- **<Pattern name>** at units <X>–<Y>: <description>
- **<Pattern name>** at unit <Z>: <description>
- ...

## Specific recommendations
1. **Cut or merge** units <list> — they're dead weight / repeated beats.
2. **Add contrast register** between units <X> and <Y> — currently 4 reflection units in a row.
3. **Move information dump** from unit <X> into <Y> and <Z>; the current placement is unbuffered.
4. **Add breathing room** after unit <climactic-X>; the reader needs a denouement beat.

## Open structural questions
- <where the outline is fighting itself>
- <where the climax may need to shift>

## Confidence
- Pattern detection: <high | medium> based on which signals are clearest in the input
```

### 6. Persist (optional)

`.writing/audits/<title-slug>-pacing-<date>.md`.

## Rules

- Don't dictate pacing — surface patterns and let the author choose. "This is a problem" beats "this is wrong."
- Three-in-a-row is the magic number for register / stakes / pattern concerns.
- Macro curve matters more than per-unit perfection. A flat unit in a well-curved book is fine; a curved book with a sag in the middle is the typical failure mode.
- "Saggy middle" is real and common; flag it explicitly.
- Tag for *pattern*, not exhaustive accuracy. The skill produces a diagnostic, not a verdict.

## Graph context (GRAPH-FIRST — default behavior)

See `_graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Full work structure** as a graph — scenes / chapters / acts with their relationships
- **Character appearance distribution** across the work
- **Thread escalation history** — which threads are escalating, deflating, stalled
- **Genre / comp pacing references** if in graph — for stakes-curve comparison

Insertion point: step 2 (tag each unit) — graph provides systematic tagging instead of per-unit human inference. Tag pattern-detections derived from graph as `[GRAPH-STRUCTURAL]`.

`--no-graph` skips. `--graph` forces graphify on the manuscript first.

## Contract

Consumes: draft, outline, or chapter / scene list
Produces: pacing audit with macro curve + per-issue recommendations
Requires: nothing
Side effects: writes to .writing/audits/ optional
Human gates: none — fire-and-read; user picks what to act on

## Context

Typical workflows: mid-draft audit, beta-reader pacing complaint, outline review before drafting begins
Pairs well with: story-outline (upstream), scene-craft (per-scene fixes), character-arc (when stakes flat = character not changing)
