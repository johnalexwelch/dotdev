---
name: dnd-encounter-design
description: "Designs a D&D combat/tactical encounter via a military-strategist lens: tactical objective, terrain, force composition, intel asymmetry, escape routes, victory conditions, hooks, balance check. Use when planning a combat or set-piece battle for a session."
---

# D&D Encounter Design

## Purpose

Most combat encounters fail at design time: no objective beyond "reduce HP to 0," flat terrain, symmetric intel, no time pressure, no narrative consequence. The result is a slog. This skill applies the `military-strategist` lens to encounter design, with D&D-specific mechanical balance.

## When to invoke

- Designing a combat encounter for a session
- Planning a set-piece battle or chase or heist
- Auditing an encounter that "felt flat" last session
- Composing pre-session encounters from a list of stat blocks

Routing:
- Whole-session prep → `dnd-session-prep`
- Player agency / railroad audit → `dnd-review (agency)`
- Stress-test the encounter narrative → `dnd-grill`
- Generalized narrative pacing → `pacing-review`

## Process

### 1. Identify the encounter context

- Where in the session? (opener, midpoint, climax)
- Where in the arc? (early test, escalation, climactic)
- What story beats does the encounter need to land?
- What does the encounter teach the players about the larger threat?

### 2. State the tactical objective

NOT "kill the monsters." The objective is something the players are trying to accomplish, of which combat is one path or one obstacle:

- "Reach the bridge before the army does"
- "Capture the lieutenant alive"
- "Prevent the ritual from completing (turn count)"
- "Survive long enough for the rescue"
- "Get information from one of the cultists without alerting others"
- "Escape the building before it collapses"

The objective creates choice. Without it, combat is a damage race.

### 3. Design the terrain

Terrain features that actually matter:
- Vertical (high ground, climbing, falling)
- Cover (full, partial, moving)
- Hazards (fire, water, traps, weather)
- Chokepoints (doorways, bridges, narrow passages)
- Escape routes (windows, tunnels, the river)
- Interactive objects (chandeliers, barrels, levers)

A flat 30×30 room is the worst encounter terrain. Even a dungeon room should have 2–3 features that matter.

### 4. Design the forces

For each side:
- **Force composition**: how many of what type
- **Doctrine**: how do they fight? (massed, ranged, flanking, stealth, magic-supported)
- **Morale**: when do they break / surrender / flee?
- **Leadership**: who's giving orders? What happens if they fall?
- **Support assets**: anything offstage (reinforcements after X turns, a wizard finishing a ritual)

### 5. Map intel asymmetry

What does each side know?

- What do the players know going in? (Reconnaissance results, lore, rumor)
- What do the players NOT know? (Surprise twist, hidden ally, hidden objective)
- What do the adversaries know about the players? (Numbers, classes, key abilities)
- What do the adversaries NOT know?

Asymmetry creates meaningful tactical choices. Symmetric encounters degrade into damage races.

### 6. Set time pressure

What forces the players to act now?

- Ritual completing in N turns
- Reinforcements arriving in N turns
- Hostage takes damage every turn
- Environmental collapse / fire spread

If no time pressure, combat tends to drag. Add one.

### 7. Define victory conditions for both sides

- Players: <objective achieved>
- Adversaries: <objective achieved or players failed at the time-pressure threshold>

Both sides should have visible win conditions. Players should be able to read what the adversaries are trying to accomplish.

### 8. Map narrative consequences

For each outcome path:
- Players succeed cleanly → <what changes in the campaign>
- Players succeed but pay a cost → <what changes>
- Players fail → <what changes>
- Players retreat → <what changes>

Failure is a valid outcome — the campaign continues with different consequences.

### 9. Mechanical balance check

- CR / encounter budget appropriate?
- Action economy: are the players outnumbered, equal, or outnumbering?
- Damage output check: can the encounter kill a PC if it goes wrong?
- Resource attrition: where in the day is this encounter? (Fresh vs. depleted matters)
- HP / AC variance: are there glass-cannon and tank enemies, or just middling?

Run quickly through the standard D&D 5e encounter-difficulty math (or whatever system). Note if the encounter is deadly, hard, medium, or easy.

### 10. Output

```markdown
# Encounter: <slug>

**Where**: <location in session / arc>
**Beats it lands**: <story beats>

## Tactical objective
<one sentence — the players' goal in this encounter; not "kill the monsters">

## Terrain features that matter
- <feature 1>
- <feature 2>
- <feature 3>

## Forces

### Adversaries
- Composition: <N enemies of type X>
- Doctrine: <how they fight>
- Morale: <break / flee condition>
- Leadership: <leader or hierarchy>
- Reinforcements: <if any, when>

### Players
- Expected composition: <party size + classes if known>
- Resource state: <fresh | mid-day | depleted>

## Intel asymmetry
- Players know: <what they've learned>
- Players don't know: <surprise twist, hidden objective>
- Adversaries know: <what they know about the players>
- Adversaries don't know: <what the players can use>

## Time pressure
<what forces the players to act now>

## Victory conditions
- Players win if: <X>
- Adversaries win if: <Y>

## Outcomes and consequences
- **Clean success**: <campaign change>
- **Costly success**: <campaign change>
- **Failure**: <campaign change — what's the next session>
- **Retreat**: <campaign change>

## Mechanical balance
- CR / encounter budget: <X>
- Action economy: <player advantage / parity / adversary advantage>
- Difficulty estimate: <easy / medium / hard / deadly>
- Risk of PC death: <low / medium / high>

## What this encounter teaches players
<about the larger threat, the world, themselves>

## DM notes
- Watch for: <player tactics likely to emerge>
- Adjust if: <encounter trends one direction>
- Hard pause if: <safety / pacing flag>
```

### 11. Persist

`.dnd/encounters/<encounter-slug>.md` or alongside session-prep docs.

## Rules

- Tactical objective is not optional. "Kill the monsters" is not an objective.
- Three terrain features minimum, with mechanical interaction.
- Intel asymmetry is required — both directions.
- Time pressure is required — adds urgency, creates triage.
- Outcomes for all four paths (clean, costly, fail, retreat) — failure is valid.
- Mechanical balance is checked but doesn't dominate design. A "hard" encounter with great tactical design beats an "easy" encounter that drags.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Location**: prior session events here, terrain canon, who controls it now
- **NPCs / factions involved**: relationships to PCs, current state (alive, hostile, owed favors), open threads
- **PCs**: known intel, prior wounds / scars / debts, established tactical preferences
- **Adjacent plot threads** that this encounter touches — escalation status, intended payoff

Insertion point: step 5 (intel asymmetry) — graph surfaces what each side actually knows from canon. Tag canon-derived facts as `[GRAPH-CANON]`.

`--no-graph` skips. `--graph` forces graphify on `campaign/` first.

## Contract

Consumes: encounter context + adversary stat blocks + party info
Produces: encounter design doc
Requires: nothing (uses military-strategist lens via inlined prompt or direct dispatch)
Side effects: writes to .dnd/encounters/
Human gates: none — DM reviews before running

## Context

Typical workflows: pre-session encounter design, mid-arc set-piece planning
Pairs well with: dnd-session-prep (broader prep), dnd-grill (stress-test the design), dnd-review (agency) (audit for railroading), military-strategist persona (the core lens of this skill)
