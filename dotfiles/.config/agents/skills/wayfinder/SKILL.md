---
name: wayfinder
model: opus
reasoning: high
disable-model-invocation: true
description: Plan a huge, foggy chunk of work — more than one agent session can hold — as a shared map of investigation tickets on GitHub, resolved one at a time until the route to the destination is clear enough to hand into the normal delivery funnel. Use for efforts too big or too uncertain for workflow-feature to hold in a single session. Explicit-invocation only (/wayfinder).
---

## Contract

Consumes: a loose idea (chart mode) or an existing map issue URL/number + optional ticket (work mode); this repo's `docs/agents/issue-tracker.md` "Wayfinding operations" section (run `/setup-skills` if absent)
Produces: (chart) one map issue labelled `wayfinder:map` with child tickets and blocking wired; (work) one resolved ticket — a resolution comment, a closed issue, an appended line in the map's Decisions-so-far, and a mirrored entry via `/decision-log`
Requires: `gh`; `/grill-with-docs`, `/domain-modeling`, `/prototype`, `/repo-audit` or `/deep-research`, `/decision-log`, `/handoff`
Side effects: creates/edits issues, sub-issues, and labels; assigns tickets (assignment = claim); writes decision-log entries; creates linked assets referenced from tickets
Human gates: HITL ticket types (grilling, prototype, most tasks) resolve only through live exchange — the agent never answers the human's side; never resolve more than one ticket per session

## Context

Typical workflows: **top of the delivery funnel** — the tier above `workflow-feature` for efforts too big/foggy to hold in one session. Charting is one session; each resolution is its own session. Explicit-invocation only.
Pairs well with: `grill-with-docs` (lightweight mode), `domain-modeling`, `prototype`, `repo-audit`/`deep-research` (research tickets), `decision-log` (decision mirror), `handoff` (each session exits with one), and the funnel it feeds — `workflow-roadmap`, `to-prd`→`to-issues`→`triage`, or `design-plan`→`execute-phase`.
Status: experimental — large-effort planning / idea generation.

---

A loose idea has arrived — too big for one agent session, and wrapped in fog: the way from here to the **destination** isn't visible yet. Wayfinding is about finding that way, not charging at the destination. This skill charts the way as a **shared map** on GitHub, then works its tickets one at a time until the route is clear.

The destination varies per effort, and naming it is the first act of charting — it shapes every ticket. It might be a spec to hand off, a decision to lock before planning starts, or a change made in place like a migration.

## How wayfinder fits our funnel

Wayfinder is **not** a parallel planning system — it's the front of the existing one. `workflow-feature` already turns a vague feature into triaged issues in a single session. Wayfinder is the tier *above* that: when the effort is too large or too foggy to hold in one session, wayfinder charts a multi-session map, and each cleared stretch of route feeds the normal funnel.

- **It plans; it does not deliver.** Wayfinder produces decisions, not code (see "Plan, don't do"). The map is done when the route is clear enough to plan against.
- **The map is never `ready-for-agent`.** The map is a planning artifact labelled `wayfinder:map`. It is PRD-shaped, and `workflow-guard.sh` will (correctly) block a `ready-for-agent` label on it. Only the child implementation issues that `to-issues`/`triage` create *downstream* of a cleared route carry `ready-for-agent`.
- **The cleared route hands off per-effort.** When the destination is reached, wayfinder does not implement it. It routes the result by the destination's shape, named in the map's `## Notes`:
  - product / feature work → `/to-prd` → `/to-issues` → `/triage`
  - refactor / migration / infra → `/design-plan` → `/execute-phase`
  - a strategic decision or roadmap → `/workflow-roadmap` (the human approval gate) or a `/decision-log` entry, then stop.
- **Decisions are mirrored to `decision-log`.** The map's "Decisions so far" is an *index*; the canonical record of each decision (with alternatives and tradeoffs) goes to `docs/decision-log.md` via `/decision-log`, so wayfinding doesn't create a second decision store.

## Plan, don't do

Wayfinder is **planning** by default: each ticket resolves a decision, and the map is done when nothing is left to decide before someone goes and does the thing. The pull to just do the work is usually the signal you've reached the edge of the map and it's time to hand into the funnel. An effort can override this in its **Notes** — but absent that, produce decisions, not deliverables.

## Refer by name

Every map and ticket is an issue, so it has a **name** — its title. In everything the human reads — narration, the map's Decisions-so-far — refer to it by that name, never by a bare id, number, or slug. A wall of `#42, #43, #44` is illegible; names read at a glance. The id and URL ride *inside* the name (a name wraps its link), never stand in for it.

## The Map

The map is a single GitHub issue labelled `wayfinder:map` — the canonical artifact and the cross-session state (no separate `state.yaml` for the wayfinding itself; the issue is the source of truth). Its tickets are child issues (sub-issues) of the map.

The map is an **index**, not a store. It lists the decisions made and points at the tickets that hold their detail; a decision lives in exactly one place — its ticket (and mirrored to `decision-log`) — so the map never restates it, only gists it and links.

**The concrete GitHub operations** — labels, creating the map, sub-issues, blocking, the frontier query, resolution — live in this repo's `docs/agents/issue-tracker.md` under **"Wayfinding operations"**. Consult it before touching the tracker. If it's absent, run `/setup-skills` (or apply the GitHub defaults it documents).

**Repo readiness (both modes, before any tracker write).** Confirm the target repo is the *live* one and is writable: it is **not archived** (`gh repo view --json isArchived`) and the **active `gh` account has write access** (`gh repo view` resolves it). An archived or wrong-account repo fails only after you've started — a `403 Repository was archived` mid-charting means the map has no home. Fix the account/repo first.

### The map body

The whole map at low resolution, loaded once per session. Open tickets are **not** listed — they are open child issues, found by the frontier query.

```markdown
## Destination

<what reaching the end of this map looks like, and how it hands off — "a PRD via to-prd", "a design-plan", "a locked decision". One or two lines; every session orients to it before choosing a ticket.>

## Notes

<domain; the handoff target for the cleared route; skills every session should consult; standing preferences for this effort>

## Decisions so far

<!-- the index — one line per closed ticket; the full decision is in the ticket and in docs/decision-log.md -->

- [<closed ticket title>](link) — <one-line gist of the answer> (decision-log: <anchor>)

## Not yet specified

<!-- Fog of war: in-scope fog you can't ticket yet; graduates as the frontier advances -->

## Out of scope

<!-- work ruled beyond the destination; closed, never graduates -->
```

### Tickets

Each ticket is a **child issue (sub-issue)** of the map; the issue id is its identity. Its body is the question, sized to one ~100K-token agent session:

```markdown
## Question

<the decision or investigation this ticket resolves>
```

Each ticket carries a `wayfinder:<type>` label — `research`, `prototype`, `grilling`, or `task` (see [Ticket Types](#ticket-types)).

A session **claims** a ticket by assigning it to the driving dev **first**, before any work, so concurrent sessions skip it. That assignee _is_ the claim: an open, unassigned ticket is unclaimed.

Blocking uses GitHub's native dependency relationship where available (it renders the frontier visually in the GitHub UI); otherwise the `Blocked by: #N` + `wayfinder:blocked` body convention documented in the tracker doc. A ticket is **unblocked** when every ticket blocking it is closed; the **frontier** is the open, unblocked, unclaimed children — the edge of the known.

The answer is recorded on resolution, not in the body. Assets (research summaries, prototypes) are linked from the issue, not pasted in.

## Ticket Types

Every ticket is **HITL** — worked *with* a human who speaks for themselves — or **AFK**, driven by the agent alone. A HITL ticket resolves only through that live exchange; the agent never stands in for the human's side (a grilling agent that answers its own questions has broken this).

- **Research** (AFK): Knowledge from outside the working directory. Use `/repo-audit` for codebase evidence, `/deep-research` for external/web/API research. Creates a markdown summary as a linked asset.
- **Prototype** (HITL): Raise the fidelity of the discussion with a cheap, rough, concrete artifact via `/prototype` — an outline, a stub, or UI/logic code. Links the prototype as an asset. Use when "how should it look/behave" is the key question.
- **Grilling** (HITL): Conversation via `/grill-with-docs` (lightweight mode) and `/domain-modeling`, one question at a time. The default case.
- **Task** (HITL or AFK): Manual work that must happen before a *decision* can be made — provisioning access, signing up for a service to judge its API, moving data so its shape can be seen. The one type that *does* rather than decides, and it earns its place by unblocking a decision, not by delivering the destination. Agent drives it alone where it can (AFK); otherwise hands the human a precise checklist (HITL). The answer records what was done and any facts (credentials location, new URLs, row counts) later tickets depend on.

## Fog of war

The map is _deliberately_ incomplete: don't chart what you can't yet see. Beyond the live tickets lies the **fog of war** — decisions you can tell are coming but can't yet pin down, because they hang on open questions. Resolving a ticket clears the fog ahead of it, graduating whatever's now specifiable into fresh tickets — until the route is clear and no tickets remain.

**Not yet specified** on the map is where that dim view is written: the suspected question, the area to revisit. It's the frontier _toward_ the destination — in scope, just not sharp enough to ticket. It doubles as a signpost for collaborators reading where the effort is headed.

**Fog or ticket?** The test is whether you can state the question precisely now — _not_ whether you can answer it now.

- **Ticket when** the question is already sharp — even if blocked.
- **Not yet specified when** you can't phrase it that sharply. Don't pre-slice the fog; one patch may graduate into several tickets, or none.

**Not yet specified** excludes what's decided (Decisions so far), already a live ticket, or out of scope.

## Out of scope

The destination fixes the scope, so work beyond it is **out of scope** — not fog, and it doesn't belong in **Not yet specified**. It gets its own section: work consciously ruled out of _this_ effort. Out-of-scope work never graduates; it returns only if the destination is redrawn, as a fresh effort.

When a ticket turns out to sit past the destination — mis-scoped in, or exposed by a resolution — **close it** and leave one line in **Out of scope**: the gist plus why, linking the closed ticket. It stays out of **Decisions so far**, which records only the route actually walked.

## Invocation

Two modes. Either way, **never resolve more than one ticket per session**, and **every session exits with `/handoff`** pointing at the map (the map issue is the durable state; the handoff is the pointer).

### Chart the map

User invokes with a loose idea.

0. **Confirm the ground first.** Before naming anything, survey for existing implementations and the effort's likely home repo — a loose idea often already has ~half of it built somewhere. The destination *and its handoff target* depend on which repo owns the work, so identify that repo and confirm it is the **live, writable, non-archived** copy (not an archived or stale checkout). Charting against the wrong copy silently invalidates the map.
1. **Name the destination.** `/grill-with-docs` (lightweight) + `/domain-modeling` to pin down what this map finds its way to *and how it hands off* (to-prd / design-plan / decision). Record the handoff target in the map's Notes. The destination fixes scope, so it's settled first.
2. **Map the frontier.** Grill again, **breadth-first**: fan out across the whole space, surfacing open decisions and first-takeable steps. **If this surfaces no fog** — the route is already clear and the whole journey fits one session — you don't need a map. Stop and route it straight into `workflow-feature` or the appropriate funnel entry.
3. **Create the map** (label `wayfinder:map`, per the tracker doc): Destination and Notes filled, Decisions-so-far empty, fog sketched into **Not yet specified**. Do not label it `ready-for-agent`.
4. **Create the specifiable tickets** as sub-issues of the map, then wire blocking in a **second pass** (issues need ids before they can reference each other). Everything not yet specifiable stays in the fog.
5. Stop — charting is one session's work. Exit with `/handoff`.

### Work through the map

User invokes with a map (URL or number). A ticket is optional — without one, you pick the next decision.

1. Load the **map** — the low-res view, not every ticket body. **Pin the working repo path first.** The tracker/map and the code/docs you'll edit may live in a *different* repo than the session's cwd (e.g. a herdr worktree of repo A while the map + work land in repo B). Identify that repo once, state its absolute path, and run git/`gh` there — don't rely on `cd X 2>/dev/null || cd Y` fallbacks, which hide which checkout is live and can strand commits or trigger false "work lost" scares.
2. Choose the ticket. If the user named one, use it; otherwise compute the frontier with the **canonical query** in the tracker doc (open + unblocked + **`no:assignee`**) and take the first one — never infer the frontier from labels or blocking-impact alone. The `no:assignee` filter is load-bearing under concurrent sessions: a ticket with an assignee is already being worked, skip it. **Claim** your pick (assign to the driving dev) before any work.
3. Resolve it — **zoom as needed**: fetch the full body of any related/closed ticket on demand; invoke the skills the Notes name and the ticket type requires. If in doubt, `/grill-with-docs` + `/domain-modeling`.
4. Record the resolution: post the answer as a **resolution comment**, **close** the issue, **append a context pointer** to the map's Decisions-so-far, and **mirror the decision to `docs/decision-log.md`** via `/decision-log`.
5. Graduate any fog the answer made specifiable into fresh tickets (create-then-wire), clearing each graduated patch from **Not yet specified**. If the answer reveals a ticket sits beyond the destination, **rule it out of scope**. If a decision invalidates other tickets, update or delete them. **If this resolution clears the whole route** — no open tickets, no fog left toward the destination — don't keep going: hand the route into the funnel named in Notes (`to-prd`/`design-plan`/decision) and say so in the handoff.
6. Exit with `/handoff` pointing at the map. If the handoff recommends a next ticket, **derive it by running the canonical frontier query (open + unblocked + `no:assignee`) and paste that exact command into the handoff** — do not recommend a ticket you haven't confirmed is unclaimed.

The user may run unblocked tickets in parallel, so expect concurrent edits to the tracker.
