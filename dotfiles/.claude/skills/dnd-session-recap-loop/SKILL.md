---
name: dnd-session-recap-loop
description: Closes a played D&D session end-to-end — gathers actual play, writes the post-session note, runs the NPC interaction loop and per-front movement review, catches continuity issues, reviews open threads, and stack-ranks open decisions by unlock value. Use after any played session before next session prep begins.
codex-compatible: false
---

## Purpose

Prevent the gap between "we played" and "we wrote it down" from eating campaign coherence. One skill runs the full close workflow so nothing gets skipped.

## Contract

Consumes: actual play data (from user, session transcripts, memory system), prior session note, front docs, NPC docs, OPEN_THREADS.md
Produces: completed post-session session note, updated OPEN_THREADS.md, ranked open-decisions table, S+1 opening queue
Requires: knowledge of what actually happened at the table
Side effects: writes/updates session note, OPEN_THREADS.md; may update front docs and NPC notes after acceptance
Human gates: user confirms actual play before writing; user approves thread status changes and open-decision ranking

## Soft Context

Typical workflows: session played → dnd-session-recap-loop → dnd-node-builder → dnd-session-prep (next session)
Pairs well with: dnd-review (continuity, threads), dnd-npc-arc-builder (if a revelation arc is active)

---

## Workflow

### 1. Gather actual play

Retrieve what happened at the table. In order of preference:

1. User's direct account
2. Prior session transcript (session_search)
3. .remember/ system — today-*.md, recent.md
4. Prep doc "Moments" fragment notes

Confirm with the user before writing. If the account is incomplete, ask for the missing pieces specifically — don't guess.

Key things to pin down:
- What scenes played vs. were skipped
- Which NPCs were encountered (on-screen)
- Divergences from the prep doc
- Memorable moments the table flagged
- How the session ended

---

### 2. Close session gaps

Update the existing session note (or prep doc if no session note exists yet):

- **What Happened** — fill actual play; annotate divergences from prep
- **Awesome Moments** — confirm group-flagged moments; remove unconfirmed "candidate" tags
- **Open Canon** — lock confirmed items; flag unconfirmed ones with carry-forward notes
- **NPC interaction table** — remove TBD/confirm rows for NPCs not encountered; mark them "not encountered this session"
- **Session Close checklist** — fill inspiration, next player steps if known

---

### 3. Write or complete the post-session note

If no post-session session note exists, create one at `Sessions/Session {NNN} - {Title}.md`. If one exists, fill any remaining gaps.

Required sections:
- Frontmatter: `status: played`
- **What Happened** (actual play, with divergences noted)
- **Moments** (confirmed table highlights)
- **In-Session Notes** (open canon going out, link flags)
- **After-Session Retrospective** (what worked, what didn't, what to improve)
- **NPC Interactions & Relationship Shifts** (see Step 4)
- **Front Movement** (see Step 5)

---

### 4. NPC interaction loop *(do not skip)*

Loop through every NPC who was active this session — on-screen AND off-screen. For each:

**Party ↔ NPC (on-screen):**
- What was the interaction?
- How did it shift the relationship?

**NPC ↔ NPC (off-screen):**
- What were key NPCs doing while the party wasn't watching?
- Did any off-screen interaction shift a relationship, advance a faction, or change available information?

Format as two tables in the session note:

```md
**Party ↔ NPC**
| NPC | Interaction | Relationship shift |
|-----|-------------|-------------------|

**NPC ↔ NPC (off-screen)**
| Between | What happened | Relationship state / shift |
|---------|---------------|---------------------------|
```

Do not limit to NPCs the party spoke to. Every active NPC should appear.

---

### 5. Front movement review *(do not skip)*

For each active front, answer:
- What moved this session — on-screen and off-screen?
- What did the party observe or miss?
- What's the status entering next session?

Format as a table:

```md
| Front | Status entering | What happened (on + off screen) | Status exiting |
|-------|----------------|----------------------------------|----------------|
```

Every active front gets a row. "No movement" is a valid entry — but it must be stated, not omitted.

---

### 6. Run continuity check

Invoke `dnd-review continuity` on the session note and any new canon introduced this session. Surface Critical and High findings before proceeding. Flag link errors (broken NPC links, spelling inconsistencies) even if low severity.

---

### 7. Run thread review

Invoke `dnd-review threads` on the updated session state. Classify active threads; retire or merge weak ones; surface anything ready for payoff. Update OPEN_THREADS.md after user acceptance.

---

### 8. Stack-rank open decisions

Gather all TBD items across session notes, NPC docs, and front docs. Rank by unlock value:

| Tier | Criteria | Action |
|------|----------|--------|
| **1 — Session-blocking** | Must be decided before the next session runs | Decide now or flag as pre-session blocker |
| **2 — Arc-blocking** | Needed before an active arc's key scene | Decide in next prep cycle |
| **3 — Significant** | Unlocks meaningful content when resolved | Address during S+1 prep |
| **4 — Campaign depth** | No deadline; adds richness when reached | Queue, no urgency |

Output the ranked table and update OPEN_THREADS.md → *Open Canon to Resolve*.

---

### 9. Queue next session's opening beats

Identify 1–3 things that should fire at the top of the next session:

- Unfinished threads from this session's close
- Ready-for-payoff items from the thread review
- Character spotlight beats that have been deferred

Write them into the next session's prep stub or note them in OPEN_THREADS.md.

---

## Output Format

```md
# Session Recap — {Session Title}

## Actual Play (confirmed)
...

## Session Note Status
[updated | created] at Sessions/{filename}

## Continuity Findings
Critical: {n} · High: {n} · Medium: {n}

## Thread Review
[summary of status changes]

## Open Decisions — Stack Ranked
| Tier | Decision | Why | Deadline |
|------|----------|-----|----------|

## Next Session Opening Queue
1. ...
2. ...
```

---

## Rules

- Never skip the NPC interaction loop. Off-screen NPC activity is as important as on-screen.
- Never skip the front movement review. Every active front gets a row, even if the entry is "no movement."
- Do not write the session note until actual play is confirmed by the user.
- Lock open canon items that are confirmed; carry forward items that are not — never guess.
- Stack-rank decisions by what they unlock, not by how easy they are to answer.
- A decision with a session deadline is always Tier 1, regardless of difficulty.
