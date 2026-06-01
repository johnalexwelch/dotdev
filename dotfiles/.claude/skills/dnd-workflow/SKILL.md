---
name: dnd-workflow
description: Entry point for D&D campaign development. Routes to the correct pipeline based on what the user is working on — session prep, mystery design, lore development, or review. Use when the user mentions D&D, campaign, session, mystery, encounter, NPC, faction, or worldbuilding.
codex-compatible: false
---

## Purpose
Route D&D creative work through the right skills in the right order.

## Contract
Consumes: user intent, campaign context clues. Produces: routed pipeline execution. Requires: at least one dnd-* skill installed. Side effects: delegates to downstream skills which may create/update campaign files. Human gates: confirm pipeline selection before starting.

## Pipeline detection
| Signal | Pipeline |
|--------|----------|
| "prep a session", "next session", "what should happen next" | **Session** |
| "design/build an adventure", "prep a situation not a plot", "Three Clue Rule", "node map" | **Adventure design** |
| "mystery", "investigation", "intrigue", "clue web" | **Mystery** |
| "I have an idea", "brainstorm", "rough concept", "what if" | **Ideation** |
| "check continuity", "does this contradict", "open threads", "loose ends", "is this railroady" | **Review** |
| "ingest", "formalize", "these notes", "from ChatGPT" | **Lore Ingestion** |
| "grill", "stress test", "poke holes", "challenge" (± canon/docs) | **Grill** |

If ambiguous, ask one question: "Are we building something new, reviewing something existing, or prepping for the table?"

## Pipelines

**Session:** dnd-grill (premise) → decision-log → dnd-lore-ingestion (if new lore) → dnd-grill *canon mode* (challenge vs campaign state) → decision-log → dnd-review *continuity* → dnd-session-prep → dnd-review *agency* (final gate).
Entry points: step 1 for raw ideas, the canon-grill step if already grilled+logged, dnd-session-prep if direction is settled.

**Adventure design / Mystery:** dnd-grill (premise) → **dnd-adventure-design** (situation, active factions, node map, revelations w/ Three Clue Rule, timelines, stakes) → decision-log → dnd-node-builder (detail the clue web) → dnd-review *continuity* + *agency* → dnd-session-prep.

**Ideation:** dnd-grill → decision-log → dnd-lore-ingestion → dnd-grill *canon mode*.

**Review:** dnd-review *continuity* → dnd-review *threads* → dnd-review *agency*.

**Ad-hoc:** single-skill request → route directly, no pipeline.

## Execution rules
Announce the pipeline and starting step. At each transition, summarize what was settled and what's next. Ensure accepted grill answers reach the decision log before moving on. Skip already-completed steps. Pause on blocking findings (Critical continuity issues, major agency failures) before continuing. Don't re-grill settled decisions. Prefer the lightest pipeline that covers the need; single-skill requests bypass routing.
