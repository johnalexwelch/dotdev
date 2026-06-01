---
name: dnd-session-prep
description: Turns a designed situation or current campaign state into a table-ready D&D session — a clear session goal, secrets/clues/leads, active timers, encounters that are situations (not just fights), meaningful decisions with visible stakes, spotlight moments, a variety/pacing plan, delegation, and narration prep. Use whenever the user wants to prep, plan, or get ready to *run* a session — "prep my next session," "what should happen at the table," "I'm running D&D tomorrow," "turn this into a session," "I don't know what to prep" — especially after an adventure has been designed. Engagement-and-execution focused (Angry GM + DM David); pairs with dnd-adventure-design (structure) upstream.
metadata:
  codex-compatible: false
---

# dnd-session-prep

Turn a settled direction — a designed situation, a campaign in motion, or "we left off here" — into material you can actually run *next session*. Where `dnd-adventure-design` builds the situation's architecture (nodes, clues, factions), this skill makes that architecture playable at the table: what the players will care about, what they can do, how the world pushes back, and how to keep it moving.

Two schools drive this skill. **The Angry GM** — make players *care*: investment, stakes, consequences, meaningful decisions, clear narration (full reference in `references/angry-gm-principles.md`). **DM David** — run it *smoothly*: prepare secrets/clues/leads not scenes, prep only what's needed, delegate, keep momentum, manage spotlight and pacing (full reference in `references/dm-david-principles.md`). Read whichever you need the reasoning from; the workflow below is enough to run.

## The two questions that govern prep
- **Prepare what you'll actually use.** Players only ever experience what reaches the table, and the DM is usually the slowest part of it. Prep the *likely* next content — the situations, NPCs, and locations they'll probably hit — not six sessions of contingency. The best input here is what the players said they'd do at the end of last session; if you don't have it, infer the two or three most probable directions and prep those.
- **Prepare situations, not encounters.** A situation survives player choice; a scripted encounter shatters the moment they negotiate, sneak, or invent something. Frame every prepped beat as a situation with goals and pressures the players can engage any way they like — not a fixed event that must play out.

## Workflow

1. **Anchor in where things stand.** If campaign files exist, read `CAMPAIGN_MAP.md` first (it points to canon), then pull what's live: recent session notes, `TIMELINE.md`, `OPEN_THREADS.md`, `PLAYER_KNOWLEDGE.md`, and the relevant `npcs/**`, `factions/**`, `locations/**`. Capture two things explicitly: **what changed last session**, and **what the players said they'd do next.** If a designed situation exists (from `dnd-adventure-design`), start from it. Don't re-read the whole archive.

2. **Set one clear session goal.** Players need to know what they're trying to accomplish, and so do you. Make it achievable, understandable, and measurable — "stop the ritual before the full moon," not "deal with the cult somehow." This anchors pacing: when play drifts, the goal tells you what to reassert.

3. **Name the investment, and put it in the room.** State why *this* party cares right now — the emotional anchor (an NPC they love, a place they've bled for, a personal stake). Make the anchor *present and active* this session, not a quest-giver behind a desk: let the party see the frightened person, the empty cot, the threatened place, early. If the upcoming material has none, build one in — a named, vulnerable person tied to this session's problem and on the same clock beats any lore. Note one personal thread per PC so the investment isn't carried by a single character. Investment is the difference between players making choices and players spectating.

4. **Lay out secrets, clues, and leads.** List the **secrets** (truths in the world relevant this session), the **clues** that let players uncover each (with the Three Clue Rule in mind — no single point of failure), and the **leads** that point them onward so they're never stranded without a next move. Players assemble the sequence; you supply the information. Mind the line between **public belief** and **GM truth**: check what the party already knows (`PLAYER_KNOWLEDGE.md` if it exists) so a clue advances them rather than restating what they have — or accidentally handing over a secret they haven't earned.

5. **Advance the clocks.** Note every **active timer** moving this session — villain plans, faction maneuvers, rituals, political events — and where each stands. The world changes whether or not the players act; surface that pressure so their choices carry weight and urgency.

6. **Build encounters as decisions with visible stakes.** Remember an "encounter" is *any* meaningful situation needing a decision — negotiation, chase, investigation, trap, social conflict, or combat — not just a fight. For each, give it the three things a real decision needs: **information** (players can see enough to choose on purpose), **stakes** (state what success, failure, and cost each mean), and **tradeoffs** (every option gives something up). Keep risks *visible* up front — known danger creates tension; hidden "gotcha" lethality breaks trust. Never present a threat the party can't defeat, outwit, or avoid.

7. **Plan spotlight and variety.** Earmark at least one moment per player where their abilities, backstory, or choices matter — don't leave the spotlight to chance. Then check the mix: vary combat, investigation, exploration, and social beats so the session doesn't run as one repeated note.

8. **Plan pacing and momentum.** Predict where players might stall (a stuck investigation, an unclear goal, analysis paralysis) and prep the lever that restores motion: new information, a new threat, a ticking clock, a consequence. Momentum dies in uncertainty; clarity and a fresh choice restore it.

9. **Offload table logistics.** You don't have to run everything. Decide what to delegate — initiative tracking, condition/HP tracking, the session journal, map/mini setup — so you stay focused on situations and narration instead of bookkeeping.

10. **Prep narration for the key scenes.** For the two or three beats that matter most, prep *actionable* description, not mood-poetry: what exists, what matters, and what players can interact with ("three stone altars, one slick with fresh blood" — not "an old, mysterious room"). Visualize the space first so positions and objects stay consistent. At the table, run resolution as **Declare → Determine → Describe**: the player states an action, you resolve it, you narrate the result — clean and in order.

11. **Close the loop.** End the prep with the **consequences** that are queued: how the world will visibly shift depending on what the players do. After the session, update `TIMELINE.md` / `OPEN_THREADS.md` once outcomes are known (only after the DM confirms). For a final pre-table safety check, route to `dnd-review` (agency + continuity).

## Output format
Produce a runnable prep doc. Lead with the goal and what's live; keep beats as situations, not a script.

```md
# Session Prep: {session title / date}
**Session goal:** {achievable, understandable, measurable}
**Why the party cares:** {emotional anchor / personal stake live this session}

## Where we left off
- **Changed last session:** …
- **Players said they'd:** …  → **so I'm prepping:** {the 2–3 likely directions}

## Active timers (moving whether or not they act)
- {Clock} — currently at … → next beat if unchecked …

## Secrets · Clues · Leads
### Secret: {truth in the world}
- Clue ({where/how}): …   · Clue ({where/how}): …   · Clue ({where/how}): …
- Lead onward: …

## Situations this session
### {Situation} — type: {social / investigation / exploration / combat}
- **The decision it poses:** … **Success / Failure / Cost:** … **Visible risks:** …
- **Ways in** (negotiate / sneak / fight / investigate / avoid): …

## Spotlight & variety
- {PC} → their moment: … (repeat per player) · Beat mix check: …

## Pacing plan
- Likely stall point: … → momentum lever: …

## Table logistics to delegate
- {task} → {player}

## Key-scene narration notes
- {Scene}: what exists / what matters / what's interactable …

## Consequences queued
- If they {do X} → world shifts to … (per likely outcome)

## Pre-table check
{route to dnd-review — agency + continuity}
```

## Output rules
Prep for *use*, not for show — favor what the players will probably touch over exhaustive coverage, and favor momentum over simulation detail. Keep every beat a situation that survives unexpected player choices; if you've written a fixed sequence of events, you've written a script, so turn it back into a situation with goals and pressures. Make stakes and risks explicit and visible. Protect player trust: consistent rulings, logical consequences, honest NPCs, no information hidden just to spring a "gotcha." Cite canon file paths when you lean on them, and never update campaign docs until the DM confirms outcomes.
