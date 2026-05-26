---
name: dnd-grill
description: Lightweight D&D planning interrogation. Stress-tests a session idea, arc, NPC, encounter, mystery, faction move, or scene, using existing lore/campaign notes when available but not requiring them. Use when the user says "grill this", "stress test", "poke holes", "challenge this", or wants hard questions before prep.
codex-compatible: false
---

## Purpose

Challenge a D&D idea before it becomes session prep or canon, grounding the critique in existing lore when that lore is available.

This skill is for narrative pressure-testing, not writing the final content. It should expose weak assumptions, missing stakes, weak NPC motivations, railroading risks, thin clue paths, and table-experience problems.

## Contract

Consumes: rough campaign idea, session premise, encounter concept, NPC plan, mystery structure, faction move, or arc outline
Produces: targeted questions, recommended answers, risks, alternatives, accepted-decision log entries, and concrete revision suggestions
Requires: no campaign docs, but must inspect and use relevant lore/campaign docs when they exist
Side effects: none
Human gates: ask one question at a time unless the user asks for a full batch

## Soft Context

Typical workflows: rough idea → dnd-grill → dnd-lore-ingestion or dnd-grill-with-canon
Pairs well with: decision-log, dnd-grill-with-canon (upgrade when continuity/canon audit matters), dnd-lore-ingestion (formalize accepted ideas)

## Modes

### Auto-detection

| Condition | Mode |
|-----------|------|
| No lore/campaign docs found + simple topic | **Lightweight** |
| Lore/campaign docs found + narrow topic | **Lore-aware lightweight** |
| User asks for canon consistency, continuity, timelines, player knowledge, or "with docs/canon" | Use `dnd-grill-with-canon` |

### Lightweight mode

- Ask one question at a time
- Grill the idea on table experience, agency, stakes, clues, NPC motives, and pacing
- Do not update lore or canon files

### Lore-aware lightweight mode

- Retrieve only the lore needed for the current question branch
- Use existing names, facts, unresolved threads, NPC states, factions, and timeline constraints in recommendations
- Call out contradictions between the proposal and existing lore before asking the next question
- Do not update lore or canon files; accepted changes can be formalized later with `dnd-lore-ingestion`

## When to Use

Use this skill when:
- The user wants an idea challenged before building it out
- The premise is still rough, whether or not campaign docs exist
- The user asks for "grill", "stress test", "poke holes", "challenge", "what am I missing", or "make this stronger"
- The topic is a single scene, single NPC, single session beat, or narrow arc question
- Existing lore can inform the critique but the user is not asking for a full canon audit

Do not use this skill when:
- The user wants a final polished handout
- The user wants canon consistency checked exhaustively against documents
- The user is asking for broad worldbuilding generation without critique

Use `dnd-grill-with-canon` instead when continuity, timeline correctness, player knowledge, or campaign-document updates are central to the request.

## Workflow

### 1. Check for relevant lore

Before asking questions, quickly inspect likely campaign sources if they exist:

- `CAMPAIGN_MAP.md`, `CAMPAIGN_CONTEXT.md`, `CANON.md`, `OPEN_THREADS.md`, `TIMELINE.md`, `PLAYER_KNOWLEDGE.md`
- `campaigns/**`, `sessions/**`, `npcs/**`, `factions/**`, `locations/**`, `mysteries/**`, `lore/**`
- Recently attached or open campaign notes

If relevant lore is found, use it as constraints and source material for recommendations. If no relevant lore is found, proceed normally in lightweight mode.

Do not read the whole campaign archive by default. Pull just enough context to make the next question sharper.

### 2. Identify the object under review

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

### 3. Establish the intended table experience

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

### 4. Interrogate one decision branch at a time

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

### 5. Stress-test against D&D-specific failure modes

Always consider:

- **Agency:** Are players making meaningful choices, or just following breadcrumbs?
- **Information:** Are there at least three ways to learn crucial facts?
- **Motivation:** Why do NPCs act now instead of waiting?
- **Consequence:** What changes if the players ignore or fail this?
- **Escalation:** How does pressure increase during the session?
- **Spotlight:** Which PCs have hooks into this material?
- **Table usability:** Can the DM run this without rereading a wall of prose?
- **Improvisation:** What flexible pieces survive unexpected player action?
- **Lore fit:** What existing lore, NPC state, faction pressure, or prior session fact strengthens or contradicts this?

### 6. End with a concise revision summary

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
