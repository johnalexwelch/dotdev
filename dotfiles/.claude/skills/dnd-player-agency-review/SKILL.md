---
name: dnd-player-agency-review
description: Reviews D&D plans for railroading, false choices, brittle clue paths, over-scripted outcomes, and weak player impact. Use before finalizing sessions, arcs, mysteries, or set-piece encounters.
codex-compatible: false
---

## Purpose

Protect meaningful player choice while preserving strong prep.

## Contract

Consumes: session plan, arc outline, encounter design, mystery structure, or scene sequence
Produces: agency risks, choice improvements, consequence branches, failure-forward options
Requires: draft plan
Side effects: none unless asked
Human gates: user chooses which recommended changes to apply

## Soft Context

Typical workflows: dnd-session-prep → dnd-player-agency-review (final gate before table)
Pairs well with: dnd-session-prep (review its output), dnd-node-builder (validate investigation agency)

## Workflow

### 1. Identify intended choices

List the major choices players appear to have.

For each choice, ask:
- Is this actually a choice?
- Do different choices lead to different consequences?
- Are players given enough information to choose intentionally?
- Can players reject the premise?

### 2. Check for common agency failures

| Failure | Test |
|---------|------|
| Railroad | Does only one path work? |
| Quantum ogre | Does every choice secretly lead to the same outcome? |
| Forced reveal | Must players reach a specific conclusion? |
| NPC overcontrol | Are NPCs solving the problem? |
| Brittle clue | Does one failed check stop progress? |
| Fake dilemma | Is one option obviously correct? |
| No consequence | Does player action fail to change the world? |

### 3. Add flexible branches

For each major scene, define:

```md
### Scene: {Name}

**If players engage directly:** ...
**If players investigate first:** ...
**If players negotiate:** ...
**If players use stealth/deception:** ...
**If players attack:** ...
**If players ignore it:** ...
```

### 4. Improve choice quality

Good choices should have:
- visible stakes
- incomplete but useful information
- real tradeoffs
- consequences that persist
- more than one defensible answer

### 5. Output

```md
# Player Agency Review

## Main Risks

## False Choices Found

## Brittle Paths Found

## Recommended Revisions

## Consequence Branches

## Safe to Run?
```

## Rules

- Do not remove all structure. Good prep supports agency.
- Preserve dramatic pressure.
- Prefer meaningful consequences over punishment.
- Let players surprise the prep without breaking the session.
