---
name: scene-craft
description: Design or audit a single scene — POV, opening hook, scene goal, opposition, turn, exit. Works for fiction scenes, D&D scenes, screenplay scenes. Embeds `narrative-purpose-guide` for mission grounding. Use when the user wants to shape a specific scene before drafting, or audit a draft scene that isn't working.
---

# Scene Craft

## Purpose

A scene is the atomic unit of narrative. Most flat scenes fail one of four ways: (1) the POV character has no goal in this scene, (2) the opposition is absent or too weak, (3) the scene ends in the same place it started, (4) the exit doesn't open the next scene.

This skill works at the scene level — design or audit one scene against those criteria.

## When to invoke

- "Help me design this scene"
- "This scene isn't working — what's wrong?"
- "Outline a scene where X happens"
- "What should this scene do?"

Routing:
- Story-level → `story-outline`
- Character arc level → `character-arc`
- Per-unit mission card → `narrative-purpose-guide`
- Multi-scene pacing → `pacing-review`

## Process

### 1. Embed narrative-purpose-guide

If the user hasn't already produced one, run `narrative-purpose-guide --unit=scene` for this scene. The purpose card answers:
- What does the scene need to accomplish for the larger work?
- What does the reader / player know after this scene that they didn't before?
- What's the emotional register?

If a purpose card already exists, reference it.

### 2. Lock the POV

Whose head are we in? What do they know? What do they not know that the reader/player needs to learn?

If the scene shifts POV mid-stream, name where and why.

### 3. Lock the scene goal

The POV character enters this scene wanting something. Make it concrete. Even atmospheric scenes have a goal — "to get through this evening without breaking the secret" is a goal.

Vague goals to avoid:
- "Learn more about X" — replace with "force X to reveal whether they were there that night"
- "Show the character's mood" — replace with "convince Y to take the meeting tomorrow"
- "Explore the setting" — replace with "find the door before the guards return"

### 4. Identify the opposition

What stands between the POV and the goal? Someone, something, internal, external. Without opposition there's no scene — there's exposition.

### 5. Design the turn

A scene's middle is the point where the scene's direction changes. The POV either:
- Achieves the goal but discovers a complication
- Fails the goal but learns something new
- Discovers the goal was the wrong goal
- Has to choose between two incompatible wants

A scene without a turn is flat — the POV begins and ends in the same emotional / informational state.

### 6. Design the exit

What does the POV (and the reader/player) know or feel at scene end that they didn't at the start? How does this exit point the audience toward the next scene?

The exit should NOT resolve the larger story tension — it should advance it.

### 7. Audit (if working from existing draft)

For an existing scene, walk through the same six points:
- Is POV stable? If shifts, are they intentional?
- Is the scene goal explicit and concrete?
- Is the opposition active and strong enough?
- Where's the turn — and does it actually turn?
- Does the exit advance the story?

Output the audit:
- One paragraph diagnosis
- 3–5 concrete fixes (what to add, what to cut, what to reframe)
- Optional: rewritten opening / closing sentences if voice is well-established

### 8. Output (design mode)

```markdown
# Scene: <slug or chapter#scene#>

## Purpose (from narrative-purpose-guide)
<paste or summarize the mission card>

## POV
<character + what they know + don't know>

## Scene goal
<concrete, achievable-in-this-scene want>

## Opposition
<what stands in the way — name it explicitly>

## Turn
<the moment direction changes, and how>

## Exit
<what's different / known / set up at scene end>

## Open questions
- <e.g., is the opposition strong enough?>
- <e.g., does the exit point clearly into the next scene?>

## Optional: opening / closing sentence drafts
- Opening: "..."
- Closing: "..."
```

### 9. Persist

`.writing/scenes/<scene-slug>.md` or alongside chapter / session prep.

## Rules

- A scene needs a goal, opposition, turn, and exit. All four. Missing any = flat scene.
- POV stays stable unless shifts are deliberate.
- Exits set up the next scene — never resolve the whole story prematurely.
- If you cannot name the scene goal in one sentence, the scene doesn't have one yet.
- Atmospheric scenes still have goals — find them.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Characters in this scene**: each character's current emotional + informational state per canon
- **Location**: prior scenes here, established sensory texture, who knows it
- **Adjacent scenes** before / after — the scene's entry and exit must connect
- **Open threads** that touch this scene — what's seeded here, what pays off

Insertion point: step 2 (lock the POV) — character-state retrieval informs what POV can know. Tag canon-grounded findings as `[GRAPH-CANON]`.

`--no-graph` skips. `--graph` forces graphify on `manuscripts/` or `campaign/` first.

## Contract

Consumes: scene slug + optional purpose card + optional existing draft
Produces: scene design or scene audit
Requires: nothing (can embed narrative-purpose-guide if needed)
Side effects: writes to .writing/scenes/ or session prep dir
Human gates: user must commit to a concrete scene goal; one clarifying question max

## Context

Typical workflows: pre-drafting per-scene, mid-draft repair, D&D scene prep
Pairs well with: narrative-purpose-guide (embedded), story-outline (upstream), character-arc (per-character per-scene), pacing-review (across scenes)
