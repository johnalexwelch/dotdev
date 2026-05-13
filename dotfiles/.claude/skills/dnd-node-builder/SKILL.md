---
name: dnd-node-builder
description: Builds Alexandrian-style node-based D&D investigations, political intrigue structures, mystery paths, and location networks. Use when planning non-linear discovery or faction intrigue.
codex-compatible: false
---

## Purpose

Create robust non-linear structures where players can discover, choose, and act without needing a single scripted path.

## Contract

Consumes: core truth, mystery premise, factions, locations, NPCs, clues, desired reveal
Produces: node map, clue web, redundancy checks, failure states, escalation logic
Requires: at least one core truth or investigation goal
Side effects: none unless asked to write files
Human gates: confirm core truth before building final node map

## Soft Context

Typical workflows: core truth → dnd-node-builder → dnd-continuity-check → dnd-player-agency-review → dnd-session-prep
Pairs well with: dnd-continuity-check (validate node web), dnd-player-agency-review (ensure real player choice)

## Workflow

### 1. Define the core truth

Every mystery needs a stable answer.

```md
## Core Truth

What is actually happening?
Who is responsible?
Why now?
What evidence proves it?
What happens if no one intervenes?
```

If the core truth is missing, ask for or recommend one.

### 2. Define discovery layers

Separate:

- Surface problem
- First suspicious pattern
- Hidden faction/NPC motive
- Deeper cause
- Final revelation
- Consequence or choice

### 3. Build nodes

Each node needs:

```md
### Node: {Name}

**Type:** location / NPC / document / event / faction / scene
**Purpose:** ...
**What players can learn:** ...
**Clues pointing here:** ...
**Clues pointing outward:** ...
**Complication:** ...
**If skipped:** ...
```

### 4. Enforce clue redundancy

For every required conclusion, include at least three paths.

Use this table:

| Required Conclusion | Clue 1 | Clue 2 | Clue 3 | Optional 4th |
|---------------------|--------|--------|--------|--------------|

### 5. Add active pressure

Investigations should move while players investigate.

Define:
- countdown clocks
- faction reactions
- NPC counter-moves
- evidence degradation
- public pressure
- personal stakes

### 6. Validate agency

Check:
- Can players choose order of nodes?
- Can they reach truth through different methods?
- Does failure change the world rather than stop play?
- Are red herrings fair and bounded?
- Is the reveal earned?

## Output Format

```md
# Node-Based Investigation: {Title}

## Core Truth

## Discovery Layers

## Node Map

## Clue Matrix

## Faction / NPC Reactions

## Failure States

## Reveal Options

## DM Running Notes
```

## Rules

- Do not hide required progress behind a single skill check.
- Do not require a specific player conclusion from one clue.
- Make clues actionable.
- Keep red herrings from becoming dead ends.
- Reveal truth through multiple sensory/social/documentary channels.
