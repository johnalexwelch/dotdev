---
name: worldbuilding-council
description: Convenes a council of named worldbuilding experts (anthropologist, cartographer, economist, ecologist, historian, linguist, theologian, political-scientist, military-strategist) to stress-test a world, region, culture, polity, or fictional setting. Graph-first by default — auto-loads canon context from `graphify-out/` when present and feeds it into every persona's prompt. Uses wave-based round 1 — foundational personas first (geography, ecology, culture), then dependent personas (history, religion), then derivative personas (politics, military). Round 2 is fully parallel. Use when the user says "challenge this world," "what's wrong with this setting," "interrogate this faction/culture/region," or wants multi-domain consistency review of a fictional world.
---

# Worldbuilding Council

## Purpose

Run a multi-lens council on a fictional world or part of one. Unlike `analysis-council`, this council uses **wave-based round 1** because worldbuilding personas have real dependency order: you can't critique politics until you know terrain + economy + history.

Inconsistencies are not failures — they're story fuel. The synthesis names them and asks how to make them load-bearing rather than how to erase them.

## When to invoke

- "Challenge this world / region / culture / polity / faction"
- "What's broken in this setting?"
- "Interrogate this worldbuilding"
- "What would <anthropologist / historian / etc.> say about this?"
- Before locking in major lore, before publishing canon, before running the campaign

Routing:
- "Quick continuity check" → `dnd-continuity-check`
- "Stress test this single scene" → `dnd-grill`
- "Deep dive on one element" → `worldbuilding-deep-dive`
- "Full multi-lens review" → here

## Process

### 1. Parse invocation

Identify:
- **Topic**: world, region, culture, polity, faction, scene
- **Scope**: full-world, single region, single culture, single mechanism
- **Mode flags**: `--council <list>`, `--verify`, `--graph`, `--no-graph`, `--round-3`

If `--council` is specified, honor it. Otherwise resolve roster per `roster.yml`.

### 2. Resolve roster

Defaults:
- Required: `cartographer`, `anthropologist`, `historian`, `political-scientist`
- Smart-pick optional based on topic keywords (see `roster.yml.dispatch_signals`)

### 2.5. Load canon context (GRAPH-FIRST — default behavior)

Worldbuilding councils are **graph-first by default**. Canon coherence is the whole point; ignoring an existing knowledge graph would mean the council critiques the topic in isolation rather than against established lore.

Check for graphify-out in this order:
1. `.council/graphify-out/` in cwd
2. `graphify-out/` in cwd
3. `campaign/graphify-out/`, `lore/graphify-out/`, `world/graphify-out/`
4. The `~/.council-sessions/<project-slug>/graphify-out/` fallback

**If a graph is found (or `--graph` is passed)**:
- Extract entities from the topic: settlement names, faction names, character names, location names, event references, deity/religion names, language names.
- Query the graph for each entity. Pull: the entity's node, 1-hop neighbors (relationships), any contradicting or contested edges, and the timeline/canon-source of each fact.
- If `--graph` is passed AND no graph exists yet, run `graphify` on the topic's canon directory first, then proceed.
- Bundle the query results into a **canon-context block** that prefixes every persona's dispatch prompt:
  ```
  ## Canon context (from knowledge graph)
  Entities in topic: <list>
  Known relationships: <bulleted, with source/canon tag>
  Open or contradicted edges: <list>
  Cross-references the topic depends on: <list>
  ```
- In the synthesis, tag any persona finding that builds on canon-context as `[GRAPH]`.

**If no graph is found AND user did not pass `--graph`**:
- Skip canon-context block.
- In synthesis output, add a one-line note: "No canon graph detected — council ran in isolation. Consider running `graphify` on canon docs and re-invoking for canon-coherence checks."

**If `--no-graph` is passed**:
- Force-skip graph lookup even if `graphify-out/` exists. Use when the user wants a clean-slate read.

### 3. Dispatch round 1 in waves

Read `roster.yml.waves`. Default:

```
Wave A (parallel): cartographer, anthropologist, ecologist, economist
Wave B (parallel, sees Wave A output): historian, linguist
Wave C (parallel, sees A + B): theologian, political-scientist
Wave D (parallel, sees A + B + C): military-strategist
```

For each wave:
- Dispatch all wave members in parallel via Agent tool (single message, multiple tool calls)
- Inline persona Voice + Lens + Anti-patterns + Falsifier
- Apply matching `roster.overlays.<name>` text
- Wait for all wave members to complete before starting the next wave

Skip any persona not in the resolved roster. Skip empty waves.

### 4. Dispatch round 2 in parallel (all personas)

After all waves complete, every persona runs a second pass in parallel:
- They see all round-1 outputs
- They write `## Response to other experts`
- They may withdraw, sharpen, or escalate

### 5. Synthesize

```markdown
# World Council on: <topic>

## Synthesis
<≤10 lines. What experts agreed on, then where they split. Inconsistencies are highlighted as opportunities, not failures.>

## Where experts disagreed
- <persona-A> argued <X>; <persona-B> argued <Y>. This is interesting because <Z>.

## Inconsistencies worth keeping (story fuel)
- <contradiction A is actually productive because it suggests <hidden history / unresolved tension>>

## Inconsistencies worth fixing (breaks the world)
- <contradiction B is a real problem — <why>>

## Open questions for the author
- <question 1>
- <question 2>

## Confidence: high | medium | low

## Per-expert reads
### cartographer (confidence: high)
<their full markdown, 80-line cap>

### anthropologist (confidence: medium)
<their full markdown, 80-line cap>

...
```

**Synthesis rules**:
- Distinguish productive inconsistency (story fuel) from broken inconsistency (immersion breaks).
- Do NOT force narrative consensus on contested lore — that's the worldbuilder's call.
- Surface dependencies: "if X (per economist) is true, then Y (per political-scientist) breaks."

### 6. Post-process

Per `roster.yml.post_process`:
- `humanizer: false` — preserve persona voice
- `domain_cleaner: null` — fiction doesn't need analysis-slop cleaning

(Both off by default for worldbuilding councils — voice matters more than tells.)

### 7. Persist

`.council/worldbuilding/<YYYY-MM-DD>-<topic-slug>.md` + JSON sidecar.

Fallback: `~/.council-sessions/<project-slug>/worldbuilding/...`.

### 8. Report

- Synthesis section to user
- Path of persisted output
- If round 2 produced ≥3 fresh challenges and `roster.recommend_round_3: true`: offer round 3.

## Contract

Consumes: world description, setting notes, lore draft, scene, region map, faction sheet
Produces: multi-lens council synthesis + per-expert reads, persisted to .council/worldbuilding/
Requires: subagent dispatch via Agent tool, _personas/, _council-scaffolding/
Side effects: writes to .council/worldbuilding/
Human gates: none — fire-and-read

## Context

Typical workflows: pre-canon-lock review, faction-design stress-test, region-deep-dive, pre-session multi-lens audit
Pairs well with: dnd-grill (lightweight), dnd-continuity-check (single-axis), worldbuilding-deep-dive (single-element), dnd-lore-ingestion (downstream), narrative-purpose-guide (scene-level)

Reference: see `_council-scaffolding/COUNCIL-PATTERN.md` for the full pattern. This council differs from `analysis-council` in: (a) wave-based round 1, (b) post-process disabled, (c) inconsistency framed as opportunity.
