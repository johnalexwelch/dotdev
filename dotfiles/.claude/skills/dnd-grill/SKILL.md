---
name: dnd-grill
description: D&D planning interrogation that stress-tests a session, arc, mystery, NPC, faction move, encounter, or lore idea. Runs lightweight (no docs) or canon-grounded against campaign files, open threads, timelines, and player knowledge. Use for "grill this", "stress test", "poke holes", "challenge this", "grill with canon", or "check continuity while grilling".
codex-compatible: false
---

# dnd-grill

Challenge a D&D idea before it becomes prep or canon. Expose weak assumptions, missing stakes, thin NPC motives, railroading, brittle clue paths, and table-experience problems. This is pressure-testing, not writing the final content.

## Modes (auto-detect, or honor an explicit request)

| Condition | Mode |
|-----------|------|
| No campaign docs found, or a quick/narrow topic | **Lightweight** — ask one question at a time, don't touch files |
| Campaign docs found, or user says "with canon/docs", "grill hard", "check continuity" | **Canon** — retrieve docs, ask in batches of five, update canon on acceptance |

Lightweight can be *lore-aware*: if a few relevant notes exist, use them as constraints without doing a full canon audit. Escalate to Canon mode when continuity, timeline correctness, player knowledge, or campaign-document updates become central.

## Workflow

1. **Gather context (just enough).** Inspect likely sources if they exist — `CAMPAIGN_MAP.md` (read first; it says where canon lives), `CANON.md`, `CAMPAIGN_CONTEXT.md`, `OPEN_THREADS.md`, `TIMELINE.md`, `PLAYER_KNOWLEDGE.md`, and `campaigns/**`, `npcs/**`, `factions/**`, `locations/**`, `mysteries/**`, `lore/**`. Pull only what sharpens the next question; don't read the whole archive.
2. **Identify the object** (session premise, mystery, NPC, faction move, encounter, location, arc, lore decision) and its primary risks.
3. **Establish the intended table experience** (tense investigation, political pressure, wonder, horror, tactical danger, emotional payoff, moral dilemma, etc.). If unclear, ask: "What table experience are you aiming for?"
4. **Interrogate one branch at a time** (Lightweight) or **in batches of five** (Canon), each question in this format:

```md
## Question {N}
**Question:** {pointed question}
**My Recommendation:** {a strong default}
**Why this matters:** {continuity / agency / pacing / payoff / prep concern}
**Alternatives:**
- {A}: {tradeoff}
- {B}: {tradeoff}
---
```

Acceptance shorthand: `a`/`accept`/`yes`/`y` accepts the recommendation; treat it as settled, and record it with `decision-log` (question, decision, alternatives, tradeoffs). Reject → ask a resolving follow-up.

5. **Always stress-test the D&D failure modes:** agency (real choices vs breadcrumbs), information (≥3 ways to learn crucial facts), motivation (why NPCs act now), consequence (what changes on failure/ignore), escalation, spotlight (which PCs have hooks), table usability, improvisation survival, and lore fit (what existing canon strengthens or contradicts this).

### Canon-mode extras
- **Challenge canon language** immediately when a term conflicts with established usage (propaganda vs truth, public myth vs GM truth). Ask whether it's in-world framing or a canon change.
- **Sharpen fuzzy terms** into canonical language ("cult" → "cell/order/devotional faction"; "magic problem" → "leyline instability/ritual contamination").
- **Invent concrete table scenarios** that expose weak structure (players ignore the hook, accuse the wrong NPC, ally with the antagonist, solve the chain early, bypass with magic, fail publicly, kill/spare a key NPC).
- **Update canon inline** in `CAMPAIGN_CONTEXT.md`/`CANON.md` only after acceptance — settled facts only, never brainstorm.
- **Offer a Campaign Decision Record** only when the change is hard to reverse, surprising-without-context, and has real trade-offs (e.g., "the Phoenix Heart is propaganda for the Titan's Heart"). Skip for tavern names, one-session NPCs, monster reskins, easily-moved clues.

6. **Close with a revision summary:**

```md
# Revised Direction
## Settled Decisions   (include decision-log entry titles)
## Canon Updates Made   (Canon mode only)
## Remaining Risks / Continuity Risks
## Strongest Version
## Next Prep Step   (dnd-session-prep / dnd-node-builder / dnd-review)
```

## Output rules
Be direct; don't flatter the idea. Recommend a path, don't stay neutral. Cite file paths when referencing canon; never overwrite canon without acceptance; never invent canon when docs are silent (mark proposals). Prefer concrete table-facing fixes and campaign-specific language over generic fantasy filler. Keep DM table-usability in view. Preserve player agency.
