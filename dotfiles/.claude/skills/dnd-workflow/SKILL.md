---
name: dnd-workflow
description: Entry point for D&D campaign development. Routes to the correct pipeline based on what the user is working on — session prep, mystery design, lore development, or review. Use when the user mentions D&D, campaign, session, mystery, encounter, NPC, faction, or worldbuilding.
codex-compatible: false
---

## Purpose

Route D&D creative work through the right skills in the right order.

## Contract

Consumes: user intent, campaign context clues
Produces: routed pipeline execution
Requires: at least one dnd-* skill installed
Side effects: delegates to downstream skills which may create/update campaign files
Human gates: confirm pipeline selection before starting

## Soft Context

Typical workflows: user describes D&D work → dnd-workflow detects pipeline → executes skill chain
Pairs well with: all dnd-* skills

## Pipeline Detection

| Signal | Pipeline |
|--------|----------|
| "prep a session", "session prep", "next session", "what should happen next" | **Session** |
| "mystery", "investigation", "intrigue", "node map", "clue web" | **Mystery** |
| "I have an idea", "brainstorm", "rough concept", "what if" | **Ideation** |
| "check continuity", "does this contradict", "audit" | **Review** |
| "open threads", "loose ends", "what did we forget", "dangling hooks" | **Thread Review** |
| "ingest", "formalize", "these notes", "from ChatGPT", "from our discussion" | **Lore Ingestion** |
| "grill", "stress test", "poke holes", "challenge" + no docs mentioned | **Lightweight Grill** |
| "grill", "stress test" + docs or canon mentioned | **Canon Grill** |

If ambiguous, ask one question: "Are we building something new, reviewing something existing, or prepping for the table?"

## Pipelines

### Session Pipeline

Full session development from idea to table-ready prep.

```text
1. dnd-grill              → stress-test the premise
2. decision-log           → record accepted questions, decisions, alternatives, tradeoffs
3. dnd-lore-ingestion     → formalize any new lore (skip if no new lore)
4. dnd-grill-with-canon   → challenge against campaign state
5. decision-log           → record canon-grounded accepted decisions
6. dnd-continuity-check   → audit for contradictions
7. dnd-session-prep       → build runnable prep
8. dnd-player-agency-review → final agency gate
```

Entry points: start at step 1 for raw ideas, step 4 if already grilled and logged, step 7 if direction is settled.

### Mystery Pipeline

Non-linear investigation or intrigue design.

```text
1. dnd-grill              → validate core truth and premise
2. decision-log           → record accepted questions, decisions, alternatives, tradeoffs
3. dnd-node-builder       → build node-based structure
4. dnd-continuity-check   → verify against canon
5. dnd-player-agency-review → ensure real player choice
6. dnd-session-prep       → convert to table-ready format
```

### Ideation Pipeline

Early-stage brainstorming and development.

```text
1. dnd-grill              → challenge the rough idea
2. decision-log           → record accepted questions, decisions, alternatives, tradeoffs
3. dnd-lore-ingestion     → structure what survives grilling
4. dnd-grill-with-canon   → validate against existing world
```

### Review Pipeline

Audit existing plans or campaign state.

```text
1. dnd-continuity-check   → find contradictions
2. dnd-open-thread-review → surface forgotten threads
3. dnd-player-agency-review → check for railroading
```

### Ad-hoc

When the user wants a single skill, route directly. Do not force a pipeline.

## Execution Rules

- Announce which pipeline and starting step you're using.
- At each step transition, summarize what was settled and what's next.
- Before leaving any grill step, ensure accepted answers are in the decision log.
- Skip steps the user has already completed (e.g., if they just finished grilling, start at the next step).
- If a skill produces blocking findings (Critical continuity issues, major agency failures), pause the pipeline and resolve before continuing.
- The user can exit the pipeline at any time.
- Do not re-grill settled decisions from earlier steps.
- Downstream prep should consume logged decisions and their accepted tradeoffs instead of relying on chat memory alone.

## Rules

- Prefer the lightest pipeline that covers the user's need.
- Do not force every interaction through the full session pipeline.
- Single-skill requests bypass pipeline routing entirely.
- Announce the plan, don't just silently start executing.
