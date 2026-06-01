---
name: dnd-lore-ingestion
description: Converts rough D&D lore, brainstorms, transcripts, notes, or ChatGPT outputs into structured campaign documents with canon/draft separation. Use when promoting ideas into the campaign knowledge base.
codex-compatible: false
---

## Purpose

Move material from brainstorm space into usable campaign knowledge without polluting canon.

## Contract

Consumes: rough lore, chat transcript, session recap, brainstorm, worldbuilding notes, NPC sketches
Produces: structured docs, canon candidates, draft notes, unresolved questions, suggested file locations
Requires: source material
Side effects: may create/update campaign files after user approval
Human gates: user approves what becomes canon

## Soft Context

Typical workflows: brainstorm → dnd-lore-ingestion → dnd-grill (canon mode) (validate against canon)
Pairs well with: dnd-grill (ideas to ingest), dnd-grill (canon mode) (canon-check ingested material)

## Workflow

### 1. Separate material by certainty

Classify every extracted claim:

| Category | Meaning |
|----------|---------|
| Canon | Explicitly accepted as true |
| Strong Candidate | Likely true but needs approval |
| Draft | Useful idea, not canon yet |
| Contradiction | Conflicts with existing canon |
| Question | Requires user decision |
| Table Artifact | Useful handout/session material |

### 2. Extract structured entities

Identify:

- NPCs
- factions
- locations
- events
- artifacts
- mysteries
- clues
- timeline entries
- player-facing lore
- GM-only truth

### 3. Recommend file placement

Use existing repo structure. If none exists, recommend:

```text
campaigns/{campaign}/
├── canon/
├── sessions/
├── npcs/
├── factions/
├── locations/
├── mysteries/
├── timeline/
├── handouts/
└── drafts/
```

### 4. Draft documents

Use lightweight frontmatter:

```md
---
type: npc | faction | location | lore | session | mystery
status: canon | draft | candidate
campaign: {name}
arc: {arc}
player_visible: true | false
last_updated: YYYY-MM-DD
---
```

### 5. Ask before promotion

Never promote candidate or draft material to canon without explicit approval.

### 6. Output

```md
# Lore Ingestion Summary

## Canon Extracted

## Candidate Canon

## Draft Ideas

## Contradictions / Risks

## Open Questions

## Recommended Files to Create or Update
```

## Rules

- Preserve uncertainty.
- Separate player-facing lore from GM truth.
- Do not overwrite existing canon silently.
- Prefer smaller focused files over one giant document.
- Mark source material where possible.
