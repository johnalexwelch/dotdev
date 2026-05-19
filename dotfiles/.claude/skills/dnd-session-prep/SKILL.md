---
name: dnd-session-prep
description: Builds practical, table-ready D&D session prep from accepted campaign direction, prior session notes, open threads, NPC/faction state, and desired table experience. Use after grilling or continuity review.
codex-compatible: false
---

## Purpose

Turn settled campaign direction into runnable session prep.

This skill emphasizes table usability: strong start, scenes, secrets/clues, NPCs, locations, encounters, consequences, and flexible improvisation support.

## Contract

Consumes: session premise, decision log, prior session notes, canon, open threads, NPC/faction/location docs, desired table experience
Produces: session prep document, scene list, secrets/clues, NPC notes, encounters, fallback paths, consequence map
Requires: enough accepted direction to prep from
Side effects: may create or update session prep files after user acceptance
Human gates: ask before writing canon-changing material

## Soft Context

Typical workflows: dnd-grill-with-canon → dnd-continuity-check → dnd-session-prep → dnd-player-agency-review
Pairs well with: decision-log, dnd-player-agency-review (final check), dnd-open-thread-review (surface threads to weave in)

## Workflow

### 1. Retrieve current state

Review:

- Previous session recap
- Campaign decision log entries from recent grills
- Current party location and objective
- Active NPCs
- Active factions
- Open threads
- Player knowledge
- Consequences from last session
- Any accepted decisions from `dnd-grill-with-canon`

Treat decision-log entries as settled prep constraints unless the user explicitly reopens them. Do not re-litigate accepted alternatives; use the logged tradeoffs to explain surprising prep choices.

### 2. Define session target

State these explicitly:

```md
## Session Target

**Primary experience:** ...
**Primary question:** ...
**Likely climax:** ...
**Session should end with:** ...
```

### 3. Build prep in runnable sections

Use this structure:

```md
# Session {N}: {Title}

## Strong Start

## Current Situation

## Key NPCs

| NPC | Wants | Knows | Will Do If Ignored |
|-----|-------|-------|--------------------|

## Locations / Nodes

## Secrets and Clues

1. ...
2. ...
3. ...

## Scenes

### Scene: {Name}

**Purpose:** ...
**Setup:** ...
**Pressure:** ...
**Choices:** ...
**Outcomes:** ...

## Encounters

## Treasure / Rewards

## Consequences

## Improvisation Safety Net

## End-State Options
```

### 4. Preserve player agency

For every major beat, include:

- what happens if players engage
- what happens if they ignore it
- what happens if they solve it early
- what happens if they choose violence/diplomacy/deception/magic

### 5. Validate table readiness

Check:

- Can the opening be read and run quickly?
- Does every scene have a purpose?
- Are there at least 10 usable secrets/clues?
- Are NPC goals active?
- Are stakes visible?
- Is there a flexible ending?

## Rules

- Do not over-script dialogue.
- Do not force a single path.
- Prefer bullets, tables, and usable prompts.
- Keep boxed text short.
- Make NPCs active, not static lore dispensers.
- Include consequences for inaction.
