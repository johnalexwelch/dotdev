---
name: character-arc
description: Designs or audits a character's transformation arc — false belief, want vs. need, defining wound, key turns, internal vs. external resolution. Works for protagonists, antagonists, and major supporting cast. Use when the user wants to build a character's journey, audit a flat character, or check that an arc is doing structural work.
---

# Character Arc

## Purpose

A character without an arc is a function — they do the same thing every scene. A character with an arc *changes*, in response to pressure, in a way the reader (or player) can feel. This skill designs that change or audits whether it's working.

## When to invoke

- "Design <character>'s arc"
- "Why does <character> feel flat?"
- "What does <character> actually want vs. need?"
- "Audit the protagonist's transformation"

Routing:
- Story-level outline → `story-outline`
- Per-scene purpose → `narrative-purpose-guide --unit=scene`
- Multi-character ensemble dynamics → `worldbuilding-council` with anthropologist + political-scientist lens

## Process

### 1. Lock the character's want, need, and false belief

Three primitives. The skill cannot proceed without them — surface them or push the user to.

- **Want**: What the character is consciously pursuing. The visible goal.
- **Need**: What would actually heal / complete / serve them. Often opposite to the want.
- **False belief**: The lens that makes them pursue the want instead of the need. Usually formed by a defining wound.

If the want = need, there's no arc — just task completion. Push the user to find the gap.

### 2. Locate the defining wound (backstory pressure)

What past event made the false belief feel necessary? This doesn't need to be in the text — but it must exist behind the text. Bullet 1–3 candidate wounds. Pick the one with the most leverage.

### 3. Identify the testing events

For an arc to land, the character's false belief must be tested repeatedly under increasing pressure:

- **Test 1**: A situation where the false belief works (reinforces it)
- **Test 2**: A situation where the false belief partially fails (cracks it)
- **Test 3**: A situation where the false belief fails completely (forces choice)
- **Climactic choice**: The character chooses between the want (false belief preserved) and the need (false belief abandoned)

### 4. Frame the choice

The climax of the arc is the moment of choice. Make it concrete:

- What's the literal external action that embodies the choice?
- What does choosing the want cost the character? (often: external loss preserved, internal loss continues)
- What does choosing the need cost? (often: external loss accepted, internal healing)

### 5. Design the resolution

- **Closed positive**: Character chooses need, internal change complete, external loss
- **Closed negative**: Character chooses want, internal change refused, external gain
- **Open**: Character chooses but consequences unclear
- **Tragic**: Character chooses too late, change has come but situation has not
- **Anti-arc / static**: Character doesn't change; the world or other characters change around them

### 6. Audit (if working from existing material)

Read the existing scenes / chapters. For each major beat involving this character:
- Which testing event is this? Or is it just task completion?
- Is the false belief visible to the reader? To other characters?
- Does pressure increase across appearances, or is it flat?
- Is the climactic choice actually a choice (with cost on both sides), or a foregone conclusion?

Output the audit:
- What's working
- Where the arc flattens (specific scenes / chapters)
- Concrete fixes (which test to add, which scene to reframe, which beat to cut)

### 7. Output (design mode)

```markdown
# <Character name> — Arc

## Want (visible goal)
<what they're chasing>

## Need (what would heal / complete them)
<what they don't see they need>

## False belief (the lens preventing the need)
"<the lie they believe about themselves or the world>"

## Defining wound
<the past event that made the false belief feel necessary>

## Tests
1. **<scene/chapter reference>**: false belief reinforced — <how>
2. **<reference>**: false belief cracked — <how>
3. **<reference>**: false belief fails — <how>

## Climactic choice
- External: <the literal action>
- Cost of want: <X>
- Cost of need: <Y>
- Choice and direction: <closed positive | closed negative | open | tragic | anti-arc>

## Resolution
<what's different about this character at the end>

## Open questions
- <where the arc has slack>
- <subplots that should tie back here but don't yet>
```

### 8. Persist

`.writing/characters/<character-slug>.md` or alongside other character docs if a campaign canon exists.

## Rules

- Want ≠ need. If they're equal, there's no arc; push the user to find the gap.
- Tests escalate. If pressure is flat across appearances, the arc is too.
- The choice has costs on both sides. A "choice" with no cost on one side isn't a choice; it's a reveal.
- Static characters are valid — but if you choose static, name it as anti-arc and identify what changes around them.
- Don't moralize. The character's "need" isn't always the "right" answer — sometimes need-fulfillment is tragic.

## Graph context (GRAPH-FIRST — default behavior)

See `_graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Character's prior appearances** — every scene / chapter with the character's state at that point
- **Established traits** and the canon that proves them
- **Relationships** to other characters — relational arcs run parallel to internal ones
- **Prior arc attempts** if the character has had multiple arcs in a series

Insertion point: step 2 (locate the defining wound) — graph reveals canon backstory that may already exist. Tag findings as `[GRAPH-CANON]`.

`--no-graph` skips. `--graph` forces graphify on the manuscript / canon docs first.

## Contract

Consumes: character name + premise / outline / existing material
Produces: arc design or arc audit
Requires: nothing
Side effects: writes to .writing/characters/ or campaign canon dir
Human gates: requires user to engage with want/need distinction; one clarifying question if blocked

## Context

Typical workflows: pre-drafting character work, mid-draft audits, ensemble cast planning
Pairs well with: story-outline (story-level structure), narrative-purpose-guide (per-scene), scene-craft (per-scene execution)
