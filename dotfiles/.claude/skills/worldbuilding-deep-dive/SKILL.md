---
name: worldbuilding-deep-dive
description: Single-element deep dive on one piece of a fictional world — a culture, a city, a polity, a religion, a magic system, a faction, a geography. Goes deeper than `worldbuilding-council` (which is multi-lens breadth) by interrogating one element from many angles, including its history, internal contradictions, lived experience, and how it connects to neighbors. Use when the user wants to develop a single piece of a world thoroughly.
---

# Worldbuilding Deep Dive

## Purpose

`worldbuilding-council` is breadth — many experts on the whole setting. `worldbuilding-deep-dive` is depth — one expert lens (or several, used in series) on a single element of the world. The output is a worldbuilding doc that's ready to ingest as canon.

## When to invoke

- "Develop this culture / city / religion / faction"
- "I want to build out <element> in detail"
- "Take this idea and make it real"
- After `worldbuilding-council` surfaces an inconsistency worth turning into story fuel — dive into the contested element

Routing:
- "Stress-test breadth" → `worldbuilding-council`
- "Quick grill" → `dnd-grill`
- "Promote to canon" → `dnd-lore-ingestion` after this

## Process

### 0. Load canon context (GRAPH-FIRST — default behavior)

Before any lens runs, check for graphify-out:
1. `.council/graphify-out/` in cwd
2. `graphify-out/` in cwd
3. `campaign/graphify-out/`, `lore/graphify-out/`, `world/graphify-out/`

**If found**: query the graph for the element by name and pull:
- The node itself + 2-hop neighbors (this element's relationships in canon)
- Any contested or contradicted edges
- All prior mentions / appearances with their canon source
- Cross-references to other elements the user has already developed

Bundle into a **canon context block** that prefixes the first lens's prompt. Each subsequent lens sees both prior lens output AND the canon context.

**If no graph**: proceed without canon context. The deep dive will create new lore that may need reconciliation with existing canon later.

### 1. Identify the element and the depth axis

The element is the *what* (a culture, a city, a faction). The depth axis is the *how* — which dimensions to develop. Common axes:

- **Lived experience**: What's it like to live here, day-to-day, at different status levels?
- **History**: Origin event, key inflection points, how the past shapes the present
- **Internal structure**: Factions, sub-cultures, dissent, how power works inside
- **External relations**: How this element interacts with its neighbors / rivals / dependents
- **Inconsistencies and tensions**: What internal contradictions are productive? Which are problems?
- **Sensory texture**: What does it smell, sound, look, taste like? Why?
- **Vocabulary and idiom**: How do people talk here? What do they have words for that outsiders don't?

User can specify axes, or you pick 3–5 based on the element type.

### 2. Pick the lens(es)

Use 1–3 personas from `_personas/`, run in series (not parallel — each builds on the prior). Common pairings:

- City → cartographer + economist + anthropologist
- Religion → theologian + anthropologist + historian
- Culture → anthropologist + linguist + theologian
- Faction → political-scientist + historian + economist
- Magic system → ecologist + political-scientist + theologian (treats magic as both natural phenomenon and social technology)
- War / conflict → military-strategist + political-scientist + historian

### 3. Run lens 1

Dispatch one persona via Agent tool. Pass the element + axes + any prior canon context. Get back a markdown deep-read.

### 4. Run lens 2 (with lens 1 output as context)

Dispatch second persona. They see lens 1's output. They add their dimension and may explicitly challenge or extend lens 1.

### 5. Run lens 3 (if used) similarly

### 6. Synthesize into a canon-ready doc

```markdown
# <Element name>

## One-line description
<the element in one sentence, for the index>

## Lived experience
<2–3 paragraphs of what it's like, at multiple status levels>

## Structure
<internal factions, sub-cultures, organization>

## History
<origin event, inflection points, present-tense state>

## External relations
<rivals, allies, dependents, contested boundaries>

## Sensory texture
<sights, sounds, smells, foods, materials, idioms>

## Productive tensions
<internal contradictions that generate story potential>

## Open questions for the author
<2–4 questions the canon hasn't answered yet — leave deliberately open>

## Lens contributions
- <persona 1>: <what they uniquely added>
- <persona 2>: <what they uniquely added>
- <persona 3>: <what they uniquely added>
```

### 7. Persist

`.worldbuilding/<element-slug>.md`. Fall back to `~/.council-sessions/<project-slug>/worldbuilding/<element-slug>.md`.

If the user has a campaign canon directory (look for `campaign/`, `lore/`, `world/`), offer to write there instead.

## Rules

- Run lenses **in series**, not parallel — each persona should see and build on the prior.
- Preserve persona voice in the lens-contribution section; the main doc is single-voice.
- Always leave 2–4 open questions — over-specifying kills story potential.
- Sensory texture is non-negotiable; worldbuilding without sensory grounding is a wiki page.

## Contract

Consumes: element name + axes + prior canon (optional)
Produces: canon-ready single-element doc + lens contributions
Requires: _personas/, subagent dispatch
Side effects: writes to .worldbuilding/ or campaign canon directory
Human gates: none — fire-and-read; user reviews before promoting to canon

## Context

Typical workflows: development of single world elements, post-council deepening, pre-session prep
Pairs well with: worldbuilding-council (breadth upstream), dnd-lore-ingestion (downstream promotion), narrative-purpose-guide (for scenes using this element)
