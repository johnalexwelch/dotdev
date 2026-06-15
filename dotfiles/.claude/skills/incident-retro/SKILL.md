---
name: incident-retro
model: opus
reasoning: high
description: Blameless post-incident retrospective. Reconstructs the timeline, separates contributing factors from root cause, surfaces what worked and what didn't in the response, and proposes durable changes (runbooks, alerts, instrumentation, process). Use after any incident worth learning from — even a near-miss.
---

# Incident Retro

## Purpose

The point of a retro is not to assign blame — it's to extract durable change. Most incidents have multiple contributing factors and a chain of decisions that *each made sense at the time*. The retro surfaces the chain.

## When to invoke

- After incident resolution (within a few days)
- After a near-miss (still worth the retro)
- After repeated small incidents that share a root cause

Routing:

- Active incident still ongoing → `incident-triage`
- Need to write a new runbook → `runbook-author`
- General post-mortem (non-incident, e.g., project retro) → `post-mortem`

## Process

### 1. Reconstruct the timeline

Pull from:

- Triage card (`incident-triage` output if used)
- Slack channel
- Status page updates
- Logs and dashboards
- Commit history during the incident

Build a minute-by-minute timeline from first observable to declared-resolved.

### 2. Identify the symptom chain

The reader observed X. X was caused by Y. Y was caused by Z. Walk the chain. Don't stop at the "first plausible cause" — keep asking why.

### 3. Distinguish contributing factors from root cause

Most incidents have a single deepest cause and several contributing factors that made the cause possible or made the response slower. Name them separately.

- **Root cause**: the thing whose absence would have prevented the incident
- **Contributing factors**: the things that, individually, didn't cause the incident but together made it possible / longer

### 4. Surface what worked

Equally important. What in the response worked well? What was the moment of breakthrough? Who made a key call? Recognize and capture.

### 5. Surface what didn't work

Where did the response get stuck? Where were assumptions treated as facts? Where did communication fail?

### 6. Propose durable changes

For each contributing factor and the root cause, propose at least one change that would prevent / detect / shorten next time:

- **Prevent**: changes that make the failure mode impossible (typed schema, idempotency keys, capacity headroom)
- **Detect**: changes that surface the failure mode earlier (new alert, new monitoring, dashboard)
- **Shorten**: changes that speed recovery next time (runbook, automation, on-call shift)
- **Soften**: changes that reduce blast radius (rate limit, circuit breaker, feature flag)

Rank proposed changes by effort × impact.

### 7. Identify the blameless framing

Re-read the retro before sharing. For each decision in the chain: was the person making that decision acting reasonably given what they knew at the time? If the retro reads like a blame trail, rewrite. If the retro misses a system issue because it stops at individual decisions, dig deeper.

### 8. Output

```markdown
# Incident Retro: <slug>

**Date**: <incident date>
**Duration**: <X hours>
**Severity**: <Sev-1 | Sev-2 | etc>
**Status**: resolved
**Retro author**: <name>

## Summary
<2–3 sentences: what happened, what was the impact, what's changing>

## Impact
- Users / customers affected: <count or scope>
- Duration of impact: <X>
- Visible vs. silent: <whether the impact was noticed by affected users>

## Timeline
| Time | Event | Notes |
|------|-------|-------|
| 09:00 | <event> | <notes> |
| 09:05 | <event> | <notes> |
| ... |

## Root cause
<the single deepest cause whose absence would have prevented the incident>

## Contributing factors
- <factor 1>: <why this enabled / extended the incident>
- <factor 2>: ...

## What worked in the response
- <action / decision / process that worked well>

## What didn't work
- <where the response got stuck or slow>

## Durable changes
### Prevent
- <change>: owner <X>, effort <S/M/L>, impact <S/M/L>

### Detect
- ...

### Shorten
- ...

### Soften
- ...

## Action items (ranked)
1. <highest leverage> — owner, by <date>
2. ...
3. ...

## Lessons (for the team's memory)
- <observation worth carrying forward, even without a specific action>
```

### 9. Persist

`.incidents/<date>-<slug>-retro.md`.

## Rules

- Blameless framing is non-negotiable. If the retro reads like a blame trail, rewrite.
- Root cause and contributing factors are separate categories. Many retros conflate them.
- Every durable change has an owner and a date. Action items without owners die.
- Capture what worked — not just what didn't. Reinforcing good response is half the value.
- Don't propose more action items than the team can absorb. Pick the top 3.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:

- **Prior retros** in this system / area — surface lessons not learned, pattern of failure
- **Open action items** from prior retros — did this incident result from one of those?
- **Related runbooks** — were they consulted, were they correct, do they need update
- **System edges** active during the incident window — what was deploying, scaling, drifting

Insertion point: step 2 (reconstruct the timeline) — graph surfaces inputs the human responders may not have logged. Tag retro findings that surface lessons-not-learned as `[GRAPH-RECURRING]`.

`--no-graph` skips. `--graph` forces graphify on `incidents/` first.

## Contract

Consumes: incident triage card + Slack history + logs + responder interviews
Produces: blameless retro markdown
Requires: access to incident artifacts (or user-supplied content)
Side effects: writes to .incidents/<date>-<slug>-retro.md
Human gates: review by another responder before circulating; the retro author and a peer should both sign off

## Context

Typical workflows: 1–5 days post-incident
Pairs well with: incident-triage (upstream artifact), runbook-author (for shortening / detecting changes), post-mortem (for non-incident retros)
