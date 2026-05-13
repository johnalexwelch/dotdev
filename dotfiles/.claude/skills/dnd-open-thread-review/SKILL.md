---
name: dnd-open-thread-review
description: Reviews unresolved D&D campaign threads and recommends which ones to pay off, escalate, preserve, retire, or connect to upcoming prep. Use before arc planning or session prep.
codex-compatible: false
---

## Purpose

Turn loose campaign material into intentional future play.

This skill prevents forgotten hooks, dangling NPCs, abandoned mysteries, and missed payoffs.

## Contract

Consumes: open thread tracker, prior session notes, campaign canon, NPC/faction docs, current arc direction
Produces: thread inventory, status classification, payoff recommendations, escalation suggestions, retirement candidates
Requires: open threads or session notes
Side effects: may update `OPEN_THREADS.md` after acceptance
Human gates: user approves thread status changes

## Soft Context

Typical workflows: between arcs or before session prep → dnd-open-thread-review → dnd-session-prep
Pairs well with: dnd-session-prep (weave active threads into prep), dnd-grill-with-canon (stress-test thread payoffs)

## Workflow

### 1. Gather threads

Search for unresolved:
- NPC promises
- faction moves
- mysteries
- unexplained visions
- prophecies
- player backstory hooks
- abandoned locations
- villains still active
- consequences not yet shown
- items/handouts not yet paid off

### 2. Classify each thread

| Status | Meaning |
|--------|---------|
| Active | Should matter in the next 1-3 sessions |
| Brewing | Should develop offscreen |
| Dormant | Keep available but do not foreground |
| Ready for Payoff | Setup is sufficient; bring it back soon |
| Needs Reinforcement | Players may not remember it yet |
| Retire | No longer useful; close or ignore intentionally |
| Merge | Better combined with another thread |

### 3. Score each thread

Rate 1-5:
- Player memory
- Emotional weight
- Plot relevance
- Faction relevance
- Ease of payoff
- Risk if ignored

### 4. Recommend action

For each meaningful thread, recommend:

```md
### {Thread}

**Status:** ...
**Why it matters:** ...
**Recommended action:** ...
**Best payoff window:** ...
**Possible callback:** ...
**If ignored:** ...
```

### 5. Update tracker

After approval, update `OPEN_THREADS.md` using:

```md
# Open Threads

## Active

## Brewing

## Dormant

## Ready for Payoff

## Retired
```

## Rules

- Do not force every thread into the next session.
- Prefer 2-4 active threads at a time.
- Retire weak threads deliberately.
- Preserve player-facing promises unless there is a good reason not to.
- Escalate faction threads offscreen when players ignore them.
