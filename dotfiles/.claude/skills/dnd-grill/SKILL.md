---
name: dnd-grill
description: Lightweight D&D planning interrogation. Stress-tests a session idea, arc, NPC, encounter, mystery, faction move, or scene without requiring campaign docs. Use when the user says "grill this", "stress test", "poke holes", "challenge this", or wants hard questions before prep.
codex-compatible: false
---

## Purpose

Challenge a D&D idea on its own merits before it becomes session prep or canon.

This skill is for narrative pressure-testing, not writing the final content. It should expose weak assumptions, missing stakes, weak NPC motivations, railroading risks, thin clue paths, and table-experience problems.

## Contract

Consumes: rough campaign idea, session premise, encounter concept, NPC plan, mystery structure, faction move, or arc outline
Produces: targeted questions, recommended answers, risks, alternatives, accepted-decision log entries, and concrete revision suggestions
Requires: no campaign docs
Side effects: none
Human gates: ask one question at a time unless the user asks for a full batch

## Soft Context

Typical workflows: rough idea → dnd-grill → dnd-lore-ingestion or dnd-grill-with-canon
Pairs well with: decision-log, dnd-grill-with-canon (upgrade when docs available), dnd-lore-ingestion (formalize accepted ideas)

## When to Use

Use this skill when:

- The user wants an idea challenged before building it out
- The premise is still rough or docs are unavailable
- The user asks for "grill", "stress test", "poke holes", "challenge", "what am I missing", or "make this stronger"
- The topic is a single scene, single NPC, single session beat, or narrow arc question

Do not use this skill when:

- The user wants a final polished handout
- The user wants canon consistency checked against documents
- The user is asking for broad worldbuilding generation without critique

Use `dnd-grill-with-canon` instead when campaign docs are available or continuity matters.

## Workflow

### 1. Identify the object under review

Classify what is being grilled:

| Object | Primary risks |
|--------|---------------|
| Session premise | weak opening, unclear objective, poor pacing |
| Mystery | single-point clue failure, reveal pacing, false agency |
| NPC | weak agenda, inconsistent behavior, shallow voice |
| Faction move | poor incentives, unclear consequences, static world |
| Encounter | tactical blandness, stakes mismatch, no story movement |
| Location | no interactivity, thin secrets, weak affordances |
| Arc | vague promise, weak escalation, payoff mismatch |

### 2. Establish the intended table experience

Before critique, infer or ask what the scene should feel like:

- Tense investigation
- Political pressure
- Wonder and discovery
- Horror or unease
- Tactical danger
- Emotional payoff
- Moral dilemma
- Comic relief
- Player empowerment

If unclear, ask one question: "What table experience are you aiming for?"

### 3. Interrogate one decision branch at a time

Ask one question at a time by default.

Each question must include:

```md
## Question {N}

**Question:** {The pointed question}

**My Recommendation:** {A strong default answer}

**Why this matters:** {What breaks if unresolved}

**Alternatives:**
- {Alternative A}: {tradeoff}
- {Alternative B}: {tradeoff}

---
```

Acceptance shorthand:

- `a`, `accept`, `yes`, or `y` means accept the recommendation
- If accepted, treat it as settled for the rest of the session
- If accepted, record it with `decision-log`, preserving the question, decision, alternatives considered, and tradeoffs accepted
- If rejected, ask a follow-up that resolves the branch

### 4. Stress-test against D&D-specific failure modes

Always consider:

- **Agency:** Are players making meaningful choices, or just following breadcrumbs?
- **Information:** Are there at least three ways to learn crucial facts?
- **Motivation:** Why do NPCs act now instead of waiting?
- **Consequence:** What changes if the players ignore or fail this?
- **Escalation:** How does pressure increase during the session?
- **Spotlight:** Which PCs have hooks into this material?
- **Table usability:** Can the DM run this without rereading a wall of prose?
- **Improvisation:** What flexible pieces survive unexpected player action?

### 5. End with a concise revision summary

When enough branches are resolved, produce:

```md
# Revised Direction

## Settled Decisions
- ... (include decision-log entry titles or note entries created)

## Remaining Risks
- ...

## Strongest Version
- ...

## Next Prep Step
- ...
```

## Output Rules

- Be direct.
- Do not flatter the idea.
- Recommend a path instead of staying neutral.
- Do not write final prose unless asked.
- Prefer concrete table-facing fixes over abstract theory.
- Preserve player agency.
- Avoid generic fantasy filler.
