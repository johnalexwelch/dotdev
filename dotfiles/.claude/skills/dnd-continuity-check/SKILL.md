---
name: dnd-continuity-check
description: Audits D&D plans or docs for continuity problems across canon, timeline, NPC states, faction agendas, player knowledge, and prior decisions. Use before session prep finalization or when introducing new lore.
codex-compatible: false
---

## Purpose

Find contradictions before they reach the table.

This skill reviews a proposed session, arc, handout, lore entry, NPC, or faction move against established campaign state.

## Contract

Consumes: target document or plan, canon files, session notes, timeline, NPC/faction/location docs, player knowledge records
Produces: continuity findings, severity ratings, recommended fixes, and optional canon updates
Requires: campaign docs or user-provided excerpts
Side effects: may update docs only after explicit acceptance
Human gates: user chooses which fixes to accept

## Soft Context

Typical workflows: dnd-grill-with-canon → dnd-continuity-check → dnd-session-prep
Pairs well with: dnd-session-prep (validate before finalizing), dnd-player-agency-review (pair for full pre-session audit)

## Workflow

### 1. Determine scope

Classify the review:

| Scope | Focus |
|-------|-------|
| Session prep | prior session outcomes, active NPCs, open threads |
| Lore doc | cosmology, history, terminology, faction claims |
| NPC | relationship history, motives, prior behavior, voice |
| Faction | incentives, public/private agenda, resources, timeline |
| Mystery | clue chain, player knowledge, reveal pacing |
| Handout | player-facing truth vs propaganda vs unreliable text |

### 2. Retrieve source of truth

Read in this order when available:

1. `CAMPAIGN_MAP.md`
2. `CANON.md`
3. `CAMPAIGN_CONTEXT.md`
4. `TIMELINE.md`
5. `PLAYER_KNOWLEDGE.md`
6. `OPEN_THREADS.md`
7. Relevant NPC/faction/location docs
8. Recent session notes
9. Campaign decision records

### 3. Audit across six axes

#### Canon Truth

Does the plan contradict objective GM truth?

#### In-World Belief

Does it confuse propaganda, myth, rumor, religion, or faction doctrine with objective truth?

#### Timeline

Could these people, events, and consequences coexist in time?

#### NPC/Faction State

Are motives, resources, relationships, and knowledge consistent?

#### Player Knowledge

Are players being asked to act on facts they do not have?

#### Payoff and Setup

Does this contradict prior foreshadowing, promises, or unresolved threads?

### 4. Rate findings

Use this severity table:

| Severity | Meaning | Action |
|----------|---------|--------|
| Critical | Breaks established canon or session logic | Fix before use |
| High | Likely to confuse players or undercut payoff | Fix or explain intentionally |
| Medium | Creates friction or weakens coherence | Consider fixing |
| Low | Cosmetic inconsistency | Optional |
| Opportunity | Not a contradiction, but a useful callback/payoff | Consider adding |

### 5. Output format

```md
# Continuity Check

## Summary
- Critical: {n}
- High: {n}
- Medium: {n}
- Low: {n}
- Opportunities: {n}

## Findings

### {Severity}: {Finding Title}

**Issue:** ...

**Evidence:** `{file path}` says ..., while the current plan says ...

**Why it matters:** ...

**Recommended fix:** ...

**Alternatives:**
- ...

---

## Recommended Canon Updates
- ...

## Safe to Run?
{Yes / Yes with changes / No}
```

## Rules

- Cite file paths when referencing docs.
- Do not invent missing canon.
- Distinguish contradiction from intentional unreliable narration.
- Prefer small fixes over retcons.
- Surface opportunities, but do not bury actual problems under suggestions.
