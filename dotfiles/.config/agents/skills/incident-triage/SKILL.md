---
name: incident-triage
model: sonnet
reasoning: high
description: "During an active data/system incident, establishes facts, scope, blast radius, and responder state as a structured triage card. Not a full incident-management replacement. Use when an incident is active and the responder must think clearly under pressure."
---

# Incident Triage

## Purpose

In the first 15 minutes of an incident, structured thinking saves hours. This skill produces a triage card that captures:

- What's happening (the symptom)
- What's known vs. assumed
- Who's affected and how
- What's been tried
- What to try next

It is NOT a replacement for the incident-management runbook your team uses. It's a thinking aid in parallel.

## When to invoke

- Active incident, responder needs to organize their thinking
- "Help me triage this"
- Mid-investigation when the responder is losing the thread
- Before paging additional responders (the triage card brings them up to speed)

Routing:

- Post-incident review → `incident-retro`
- Author / update a runbook → `runbook-author`
- Diagnose specific bug → `diagnose`

## Process

### 1. State the symptom precisely

What is observable that shouldn't be? Examples:

- "Dashboard X showing 0 for metric Y since 09:00"
- "Pipeline Z failed with timeout at step 4"
- "Users report login failures from district A"

If the user can't state the symptom precisely, ask once.

### 2. Establish facts (vs. assumptions)

Facts: things observed directly (logs, screenshots, queries run).
Assumptions: things believed but not verified.

This split is the hardest discipline of triage — most "stuck" incidents are stuck because assumptions are being treated as facts.

### 3. Scope and blast radius

- Who's affected? (Users, teachers, internal teams, customers)
- What's the visible impact? (Errors, missing data, wrong data, slowness)
- Time bound: when did it start, when did it become visible?
- Is the issue actively expanding, stable, or shrinking?

### 4. State the leading hypothesis

What's the most likely cause given what's known? State it explicitly. Even a low-confidence hypothesis is better than no hypothesis.

### 5. List what's been tried

Each item: what was tried, what was the result, what did we learn.

### 6. List next probes

What can be tested next? Ordered by:

- Cheapness to try
- Information gained
- Reversibility

### 7. Communicate

- Who's been told? (Status page, Slack, customer-facing comms)
- Who needs to be told next?
- What's the next update cadence?

### 8. Output (the triage card)

```markdown
# Incident Triage: <slug>
**Started**: <when first observed>
**Triage card updated**: <now>
**Responder**: <name>

## Symptom
<precise statement of what's observed>

## Scope
- Affected: <who>
- Impact: <what they see>
- Expanding | stable | shrinking
- Started at: <time>

## Facts (verified)
- <fact 1, with source — log, query, screenshot>
- <fact 2>

## Assumptions (unverified)
- <assumption 1>
- <assumption 2>

## Leading hypothesis
<the most likely cause given what's known, even if low-confidence>

## Tried so far
- <action> → <result> → <learning>
- ...

## Next probes (ordered)
1. <cheap, high-info test>
2. <medium-cost test>
3. <expensive but decisive test>

## Comms
- Told: <Slack channel, status page, customers>
- Next update by: <time>
- Update cadence: <every N min>

## Open questions
- ...
```

### 9. Persist

`.incidents/<date>-<slug>.md`. Update in place as the incident evolves.

## Rules

- Facts and assumptions are separate categories. Don't blur.
- Symptom statement is precise. "It's broken" is not a symptom; "dashboard X showing 0 since 09:00" is.
- A leading hypothesis is required even at low confidence — "no hypothesis" is a sign the responder is reactive, not investigative.
- Next probes are ordered by cheap × high-info first.
- Communication is part of triage. An incident with good technical response and bad comms is still a bad incident.
- Update the card in place — don't rewrite history.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:

- **Affected systems / services / metrics** named in the symptom — full lineage and ownership
- **Similar past incidents** by symptom keywords — what was the resolution, what was the cost
- **Runbooks** that match the symptom pattern — fast routing
- **Recent changes** in the blast radius — deploy history, schema changes, dependency bumps
- **Active alerts / outages** elsewhere that may share root cause

Insertion point: step 4 (leading hypothesis) — graph context surfaces "similar incidents resolved by X" before the responder has to remember it. Tag findings as `[GRAPH-PRIORS]`.

`--no-graph` skips graph priors. `--graph` is rarely useful during active incidents — defer ingestion to post-incident retro.

## Contract

Consumes: symptom report + responder context
Produces: triage card (markdown), updated over the incident lifetime
Requires: nothing
Side effects: writes to .incidents/<date>-<slug>.md
Human gates: handoffs between responders use the card as the authoritative artifact

## Context

Typical workflows: active incident response
Pairs well with: incident-retro (after resolution), runbook-author (when a pattern emerges), diagnose (for the technical root-cause work in parallel)
