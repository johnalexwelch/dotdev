---
name: dnd-npc-arc-builder
description: Designs the revelation structure for an NPC whose truth the party will discover over multiple sessions — hidden truth, planted details, layered click moments, reveal scene, and payoff branches. Use when an NPC has a secret that should land with retroactive weight rather than as a simple reveal. Distinct from character-arc (internal transformation) and dnd-node-builder (discovery paths); sits between them.
codex-compatible: false
---

## Purpose

A reveal that lands. Not "the players found out," but "everything they already knew suddenly meant something different." This skill designs the revelation structure — what to plant, when clicks land, how layers build — so the payoff feels earned rather than announced.

Distinct from:
- `character-arc` — designs the NPC's internal transformation (want, need, false belief). Run that first or alongside; this skill consumes its output.
- `dnd-node-builder` — maps the investigation paths players take to find the truth. Run that after; this skill feeds it.
- `scene-craft` — designs the individual reveal scene. Run that last for the climactic moment.

## Contract

Consumes: NPC identity, hidden truth, campaign state, player knowledge records, session history
Produces: hidden truth statement, planted detail inventory, click sequence map, reveal scene design, payoff branch map
Requires: at least one confirmed hidden truth
Side effects: may update NPC notes and session prep docs after acceptance
Human gates: user confirms hidden truth before building reveal structure; user approves planted details before they appear in prep

## Soft Context

Typical workflows: character-arc (NPC internal journey) → dnd-npc-arc-builder (revelation structure) → dnd-node-builder (discovery paths) → scene-craft (reveal scene) → dnd-session-prep
Pairs well with: dnd-grill-with-canon (stress-test planted details against canon), dnd-review continuity (check planted details don't contradict established facts)

---

## Workflow

### 1. Lock the hidden truth

Every revelation arc needs a stable secret. The skill cannot proceed without it.

```md
## Hidden Truth

What is actually true about this NPC?
Who else knows it?
Why has it been concealed, and from whom?
What evidence, if found, would prove it?
What happens if it is never revealed?
```

If multiple secrets exist, rank them. The primary secret drives the arc. Secondary secrets can layer in — but only after the primary is locked.

---

### 2. Define the planted details

Planted details are fragments seeded before the truth is understood. They must be:

- **Visible** — the party genuinely has access to them (heard in whispers, seen in documents, told by NPCs)
- **Ambiguous** — interpretable innocently on first encounter
- **Meaningful in hindsight** — once the truth lands, these details recontextualize

For each planted detail:

```md
### Plant: {slug}

**The detail:** [exactly what the party perceives]
**When/where it appears:** [session, scene, mechanic]
**Innocent interpretation:** [what it seems to mean before the truth]
**True interpretation:** [what it means after]
**Click layer it belongs to:** [1 / 2 / 3]
```

Require at least two plants per click layer. A revelation with only one plant per layer is brittle.

---

### 3. Design the click structure

A click is the moment when a planted detail becomes meaningful. Clicks should layer — each one recontextualizes what came before and raises the stakes of what's still unknown.

```md
## Click Structure

### Click 1 — {title}: [earliest, lowest stakes]
**Trigger:** [what causes this click — player action, NPC revelation, session event]
**What becomes meaningful:** [which planted detail(s) suddenly land]
**What it recontextualizes:** [what the party now understands differently]
**What it raises:** [the question this click opens, leading toward Click 2]

### Click 2 — {title}: [mid-arc, higher stakes]
...

### Click 3 — {title}: [the full reveal, highest stakes]
**Trigger:** ...
**What becomes meaningful:** [all remaining plants; the full picture]
**What it recontextualizes:** [ideally: everything from Click 1 onward]
**Emotional register:** [what the party should feel — betrayal, grief, recognition, horror]
```

The final click should recontextualize at least one element from the earliest click. If it doesn't, the arc is additive (facts stacked) not revelatory (meaning retroactively changed).

---

### 4. Design the reveal scene

The moment of full disclosure. Hand off to `scene-craft` for detailed execution. Before that, lock:

- **Who is present** — party members, the NPC, witnesses
- **What triggers it** — player action, NPC crack, evidence surfaced, external pressure
- **What the NPC does** — confess, deny, deflect, break; what their reaction reveals about their arc
- **What the party knows at the moment of entry** — which plants have already clicked; what's still dark
- **The scene's turn** — the moment direction changes (see `scene-craft`)
- **What is different at scene exit** — what the party now knows, feels, or must decide

Special case — the involuntary reveal: if the truth surfaces without the NPC present (evidence found, third party reveals it), design the party's reaction moment as the scene instead. The NPC's response comes after.

---

### 5. Map the payoff branches

What does the NPC do when the truth is out? Map at least three branches:

```md
## Payoff Branches

### Branch A — [label]
**Condition:** [what triggers this branch]
**NPC response:** ...
**Consequence for the party:** ...
**Consequence for the campaign:** ...

### Branch B — [label]
...

### Branch C — [label]
...
```

At least one branch should be "the party handles it poorly" — what happens if the reveal goes wrong.

---

### 6. Validate the structure

Check before finalizing:

- [ ] Is each planted detail visible in hindsight? (Would the party feel "we should have seen it" — not "how could we have known?")
- [ ] Does each click genuinely recontextualize something earlier — or just add new information?
- [ ] Does the final click change the meaning of something from Click 1?
- [ ] Are there at least two planted details per click layer?
- [ ] Does the reveal scene have a concrete trigger the party can reach through play?
- [ ] Does at least one payoff branch follow if the party misses the reveal entirely?

---

### 7. Hand off

- Arc (internal transformation): → `character-arc`
- Discovery paths (how players get to each click): → `dnd-node-builder`; planted details become the clue matrix
- Reveal scene (execution): → `scene-craft`
- Canon consistency: → `dnd-review continuity` (check plants don't contradict established facts)

---

## Output Format

```md
# NPC Revelation Arc: {NPC Name}

## Hidden Truth
...

## Planted Details
| Plant | Appears when | Innocent read | True read | Click layer |
|-------|-------------|---------------|-----------|-------------|

## Click Structure
### Click 1 — {title}
### Click 2 — {title}
### Click 3 — {title}

## Reveal Scene
- Trigger:
- Present:
- NPC response:
- Scene turn:
- Scene exit:

## Payoff Branches
| Branch | Condition | NPC response | Campaign consequence |
|--------|-----------|--------------|---------------------|

## Validation
[ ] Plants visible in hindsight
[ ] Each click recontextualizes
[ ] Final click changes meaning of Click 1 element
[ ] Reveal scene has reachable trigger
[ ] Failure branch exists

## Hand-offs
- character-arc: [status]
- dnd-node-builder: [clues to distribute]
- scene-craft: [reveal scene]
```

---

## Rules

- Lock the hidden truth before designing any plants. Plants built on a moving truth will contradict each other.
- Plants must be visible in hindsight, not hidden. If the party couldn't have noticed it, it's a cheat, not a click.
- Each click must recontextualize — not just add. Stacking facts is exposition. Changing meaning is revelation.
- The final click must connect back to something from the first. If the arc is purely additive, it isn't layered.
- Design at least one failure branch. The party will miss things; what happens then is part of the arc.
- Do not announce plants at the table. Deliver them as normal scene content. Trust the structure.
