---
name: dnd-grill-with-canon
model: opus
description: Documentation-grounded D&D planning interrogation. Challenges a session, arc, mystery, faction move, NPC, or lore idea against existing campaign canon, open threads, timelines, player knowledge, and prior decisions. Use when the user wants to grill D&D plans with docs/canon.
codex-compatible: false
---

## Deprecation Status

Status: deprecated. Use `dnd-grill` instead — it handles both lightweight and canon-grounded modes.

- Replaced by: `dnd-grill` (loads campaign docs automatically when present; say "grill with canon" to force doc-grounded mode)
- Date: 2026-06-10

---

## Modes

### Auto-detection

| Condition | Mode |
|-----------|------|
| No canon files found + simple topic | **Lightweight** |
| CANON.md, CAMPAIGN_CONTEXT.md, campaign docs, session notes, or deep topic exists | **Full** |
| User says "grill hard", "with docs", "with canon", "check continuity" | **Full** |

### Lightweight mode

- Ask one question at a time
- Do not update canon files
- Focus on improving the idea quickly
- Good for early brainstorming

### Full mode

- Retrieve relevant campaign documents before questioning
- Ask questions in batches of five unless the user requests one-at-a-time
- Challenge terminology, canon, timelines, and prior decisions
- Update `CAMPAIGN_CONTEXT.md` or `CANON.md` inline when a term or fact is settled
- Offer Campaign Decision Records only when the decision deserves it

## Contract

Consumes: proposed D&D plan, campaign docs, canon files, prior session notes, NPC/faction/location docs, timelines, open-thread trackers
Produces: canon-grounded critique, revised assumptions, accepted-decision log entries, resolved terminology, updated canon/context files, optional decision records
Requires: readable campaign files or user-provided docs
Side effects: may update `CAMPAIGN_CONTEXT.md`, `CANON.md`, `OPEN_THREADS.md`, and create files in `docs/campaign-decisions/`
Human gates: every question batch requires user response before continuing

## Soft Context

Typical workflows: dnd-grill → dnd-grill-with-canon → dnd-continuity-check → dnd-session-prep
Pairs well with: decision-log, dnd-continuity-check (verify after grilling), dnd-session-prep (build from accepted direction), dnd-lore-ingestion (formalize new canon)

## Canon File Structure

Prefer this structure, but adapt to the actual repo:

```text
/
├── CAMPAIGN_CONTEXT.md
├── CANON.md
├── OPEN_THREADS.md
├── TIMELINE.md
├── PLAYER_KNOWLEDGE.md
├── docs/
│   └── campaign-decisions/
├── campaigns/
│   └── {campaign-name}/
│       ├── sessions/
│       ├── npcs/
│       ├── factions/
│       ├── locations/
│       ├── mysteries/
│       ├── handouts/
│       └── lore/
```

If `CAMPAIGN_MAP.md` exists, read it first. It defines where canon lives.

Create files lazily. Only create or update files after the user has accepted the relevant decision.

## Workflow

### 1. Retrieve relevant canon

Before asking questions, inspect available docs for:

- Campaign premise
- Current arc
- Prior session notes
- Relevant NPCs
- Relevant factions
- Relevant locations
- Open threads
- Timeline constraints
- Player knowledge state
- Existing terminology
- Prior campaign decisions

If retrieval is unavailable, ask the user to provide the relevant docs or proceed in lightweight mode.

### 2. Identify the planning object

Classify the user’s plan:

| Object | Documents to prioritize |
|--------|--------------------------|
| Session | prior session notes, open threads, current arc, NPC states |
| Mystery | clue tracker, player knowledge, involved factions, timeline |
| NPC | NPC file, faction file, relationship map, prior appearances |
| Faction move | faction docs, timeline, city/world state, consequences |
| Location | location file, secrets, factions present, travel constraints |
| Lore decision | canon, timeline, cosmology, prior handouts |
| Encounter | session goal, terrain/location, stakes, NPC objectives |

### 3. Challenge against canon language

When the user uses a term that conflicts with established campaign language, call it out immediately.

Example:

> Your canon distinguishes the Titan’s Heart from the public Phoenix Heart myth. Here you use “Phoenix Heart” as if it is objectively real. Is this in-world propaganda, player-facing language, or a canon change?

### 4. Sharpen fuzzy campaign terms

When the user uses vague terms, propose precise canonical language.

Examples:

- "cult" → "cell", "order", "devotional faction", "revolutionary sect"
- "bad guy" → "active antagonist", "rival faction", "manipulated pawn"
- "magic problem" → "leyline instability", "Titanic pressure release", "ritual contamination"

### 5. Stress-test concrete scenarios

Invent specific table scenarios that expose weak structure:

- Players ignore the hook
- Players accuse the wrong NPC
- Players ally with an antagonist
- Players solve the clue chain early
- Players use magic to bypass the intended path
- A PC makes the conflict personal
- The party fails publicly
- The party kills or spares a key NPC

### 6. Ask in batches of five

In full mode, ask five questions at a time.

Each question must use this format:

```md
## Question {N}

**Question:** {The pointed question}

**My Recommendation:** {A strong default answer}

**Why this matters:** {Continuity, agency, pacing, payoff, or prep concern}

**Alternatives:**
- {Alternative A}: {tradeoff}
- {Alternative B}: {tradeoff}

---
```

Acceptance shorthand:

- `a`, `accept`, `yes`, or `y` means accept the recommendation
- If accepted, update the working assumptions
- If accepted, record it with `decision-log`, preserving the question, decision, alternatives considered, and tradeoffs accepted
- If canon changes, update the relevant file after acceptance

### 7. Update campaign context inline

When a term, relationship, or canon fact is resolved, update `CAMPAIGN_CONTEXT.md` or `CANON.md` immediately.

Use [CAMPAIGN-CONTEXT-FORMAT.md](./CAMPAIGN-CONTEXT-FORMAT.md).

Do not put every brainstorm into canon. Only write settled facts.

### 8. Record accepted decisions

Every accepted answer must be available in the campaign decision log. Use `docs/campaign-decisions/decision-log.md` when present, otherwise use the nearest repo-local `docs/decision-log.md`.

Log entries are required even when a full Campaign Decision Record is not warranted. The log captures the lightweight "why"; CDRs are for durable campaign canon decisions that need their own record.

### 9. Offer Campaign Decision Records sparingly

Offer a decision record only when all three are true:

1. **Hard to reverse** — the change would affect multiple sessions or docs
2. **Surprising without context** — future GM will wonder why this is true
3. **Real trade-off** — there were meaningful alternatives

Use [CAMPAIGN-DECISION-FORMAT.md](./CAMPAIGN-DECISION-FORMAT.md).

Examples that qualify:

- The Phoenix Heart is propaganda for the Titan’s Heart
- Avalor’s mages interpret magic as rational technology rather than divine mystery
- A major antagonist is being manipulated rather than knowingly evil
- A faction’s public doctrine intentionally contradicts its private agenda

Examples that do not qualify:

- A tavern name
- A one-session NPC detail
- A monster reskin
- A clue placement that is easy to change

### 10. End with resolved operating assumptions

After each batch or session, summarize:

```md
# Canon-Grounded Revision Summary

## Accepted Decisions
- ... (include decision-log entry titles or note entries created)

## Canon Updates Made
- ...

## Open Questions
- ...

## Continuity Risks Remaining
- ...

## Recommended Next Skill
- dnd-session-prep / dnd-node-builder / dnd-continuity-check / dnd-open-thread-review
```

## Output Rules

- Be direct and specific.
- Cite file paths when referencing canon.
- Do not overwrite canon without explicit acceptance.
- Do not invent canon when documents are silent; mark it as a proposal.
- Prefer campaign-specific language over generic fantasy language.
- Keep the DM’s table usability in view.
