---
name: dnd-review
description: Audits D&D plans and campaign state before the table. Three modes — continuity (contradictions across canon/timeline/NPC/faction/player-knowledge), open-threads (which loose ends to pay off, escalate, preserve, retire), and player-agency (railroading, false choices, brittle clue paths). Use before finalizing sessions/arcs/mysteries, when introducing new lore, between arcs, or to check for railroading.
codex-compatible: false
---

# dnd-review

Catch problems before they reach the table. Pick the mode that matches the request (you can run more than one for a full pre-session audit):

- **continuity** — "does this contradict", "check continuity", "audit this lore/plan"
- **threads** — "open threads", "loose ends", "what did we forget", "dangling hooks"
- **agency** — "is this railroady", "are these real choices", final gate before the table

## Shared steps (all modes)
1. **Scope** what's under review (session, arc, lore doc, NPC, faction, mystery, handout, encounter).
2. **Retrieve source of truth** when available, in order: `CAMPAIGN_MAP.md`, `CANON.md`, `CAMPAIGN_CONTEXT.md`, `TIMELINE.md`, `PLAYER_KNOWLEDGE.md`, `OPEN_THREADS.md`, relevant NPC/faction/location docs, recent session notes, decision records.
3. Run the mode below. **Only update docs after explicit acceptance**; the user chooses which fixes to apply.

---
## Mode: continuity
Audit across six axes: **Canon truth** (contradicts GM truth?), **In-world belief** (propaganda/myth/rumor confused with truth?), **Timeline** (can these coexist in time?), **NPC/faction state** (motives, resources, relationships, knowledge consistent?), **Player knowledge** (acting on facts they don't have?), **Setup/payoff** (contradicts foreshadowing, promises, open threads?).

Rate findings: Critical (breaks canon/session logic — fix before use), High (confuses players or undercuts payoff — fix or make intentional), Medium (friction — consider), Low (cosmetic), Opportunity (useful callback to add).

```md
# Continuity Check
## Summary  Critical {n} · High {n} · Medium {n} · Low {n} · Opportunities {n}
## Findings
### {Severity}: {title}
**Issue:** … **Evidence:** `{path}` says … vs the plan … **Why it matters:** … **Recommended fix:** … **Alternatives:** …
## Recommended Canon Updates
## Safe to Run?  {Yes / Yes with changes / No}
```
Distinguish contradiction from intentional unreliable narration; prefer small fixes over retcons; don't bury real problems under opportunities.

---
## Mode: threads
Gather unresolved material (NPC promises, faction moves, mysteries, visions, prophecies, backstory hooks, abandoned locations, active villains, unshown consequences, unpaid handouts). Classify each: Active / Brewing / Dormant / Ready for Payoff / Needs Reinforcement / Retire / Merge. Score 1–5 on player memory, emotional weight, plot relevance, faction relevance, ease of payoff, risk-if-ignored.

```md
### {Thread}
**Status:** … **Why it matters:** … **Recommended action:** … **Best payoff window:** … **Possible callback:** … **If ignored:** …
```
Update `OPEN_THREADS.md` (Active/Brewing/Dormant/Ready for Payoff/Retired) after approval. Keep 2–4 active threads; retire weak ones deliberately; escalate ignored faction threads offscreen; preserve player-facing promises.

---
## Mode: agency
For each major choice, ask: is it actually a choice? do different choices lead to different consequences? do players have enough info to choose intentionally? can they reject the premise? Then test the failure modes: Railroad (only one path works), Quantum ogre (every choice → same outcome), Forced reveal, NPC overcontrol (NPCs solve it), Brittle clue (one failed check stops progress), Fake dilemma (one obviously-correct option), No consequence.

Add flexible branches per scene (engage directly / investigate / negotiate / stealth-deception / attack / ignore). Good choices have visible stakes, useful-but-incomplete info, real tradeoffs, persistent consequences, and more than one defensible answer.

```md
# Player Agency Review
## Main Risks ## False Choices Found ## Brittle Paths Found ## Recommended Revisions ## Consequence Branches ## Safe to Run?
```
Don't strip structure (good prep supports agency); preserve dramatic pressure; prefer meaningful consequences over punishment; let players surprise the prep without breaking the session.
