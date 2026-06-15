---
name: runbook-author
model: sonnet
reasoning: high
description: "Authors or updates an operational runbook from an incident retro, a recurring failure mode, or a process to make executable by on-call at 2 AM. Produces stepwise prereqs, signals, decision points, rollback, and escalation. Use after incident-retro or proactively."
---

# Runbook Author

## Purpose

A good runbook lets a sleepy on-call engineer recover the system without having to think creatively. Most runbooks fail because they were written from the author's perspective ("I know what comes next") rather than the responder's ("I have no idea what this means, what do I do?").

This skill produces runbooks shaped for the responder under pressure.

## When to invoke

- After `incident-retro` produces a "shorten" or "detect" action
- "Write a runbook for X failure mode"
- Updating a stale runbook
- Proactively for known but unrunbooked failure modes

Routing:
- During an active incident → `incident-triage` (not this skill)
- Post-incident retro → `incident-retro`

## Process

### 1. Identify the scenario

What failure mode does this runbook address? Be precise:
- "Pipeline X timeout at step Y"
- "Dashboard Z showing zero values"
- "Vendor API returning 429s above threshold"

A runbook addresses ONE scenario. If the user describes multiple, split into multiple runbooks.

### 2. Capture prerequisites

What does the responder need before starting?
- Access (tokens, accounts, VPN)
- Tools (kubectl, dbt cli, specific dashboard)
- Permissions (admin role, on-call role)

If the responder doesn't have these, the first step is "page someone who does" — say so explicitly.

### 3. Identify the signals (how the responder knows this scenario)

What alert fires, what error appears, what dashboard turns red. The responder needs to be sure they're in the right runbook.

If the signals overlap with another scenario, name the discriminator.

### 4. Write the diagnostic steps

3–10 steps, each:
- Concrete command or action
- Expected output / what to look for
- Decision: next step depending on what's seen

Avoid abstraction. "Check the dashboard" is bad; "Open <URL>, look for the 'requests-per-second' chart, scan the last 15 minutes for drops below 200 rps" is good.

### 5. Identify rollback / safe state

What's the action that restores partial service even if the root cause isn't fixed? Rollback to last green deploy, scale up replicas, drain a problematic node, route around the failing component.

The rollback step is often more important than the diagnostic steps — sleepy responders need a "get to safe state" lever before any deep investigation.

### 6. Identify escalation path

- When to escalate
- Who to escalate to (named team or person, with contact)
- What information to bring to them

### 7. Write the post-recovery checklist

Once the system is recovered:
- Confirm with which queries / dashboards
- File the incident retro
- Update related runbooks if needed

### 8. Output

```markdown
# Runbook: <scenario name>

**Scenario**: <precise failure mode>
**Severity if unhandled**: <Sev-1 | Sev-2 | etc>
**Last reviewed**: <date>

## Signals (you're in the right place if you see)
- <alert / error / dashboard state>
- ...

## Discriminator (you're NOT in this runbook if)
- <symptom that looks similar but indicates a different scenario>

## Prerequisites
- <access / tool / permission>
- If missing: page <on-call rotation> first

## Get to safe state (do this first if not already done)
1. <action that restores partial service>
2. <action> — verify with <X>

## Diagnostic steps
1. **<step title>**
   - Run: `<command or action>`
   - Look for: <expected output / pattern>
   - If <X>: go to step 2
   - If <Y>: go to step 5 (rollback)

2. **<step title>**
   - ...

## Common causes
| Symptom | Probable cause | Fix |
|---------|----------------|-----|
| <pattern> | <cause> | <action> |

## Rollback / mitigation
1. <action to restore safe state if diagnostic steps don't resolve>

## Escalation
- When to escalate: <criteria>
- Escalate to: <team / person> via <channel>
- Bring with you: <list>

## After recovery
- Confirm: <queries / dashboards>
- File retro: `incident-retro <slug>`
- Update: <related runbooks if relevant>

## Known limitations
<scenarios this runbook does NOT cover>
```

### 9. Persist

`.runbooks/<scenario-slug>.md` or alongside ops documentation.

## Rules

- One scenario per runbook. Multi-scenario runbooks fail under pressure.
- Concrete commands, not abstractions. "Check X" is bad; "run `command`, look for Y" is good.
- Get-to-safe-state comes before diagnostics. Sleepy responders need the lever first.
- Every step has an exit (next step or escalation). No dead ends.
- Discriminator is non-negotiable. If signals overlap with another runbook, name what tells them apart.
- Date the last review. Stale runbooks are worse than no runbook.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Existing runbooks** for related scenarios — avoid duplication, identify discriminator
- **Prior incidents** matching this scenario — what worked, what didn't, common pitfalls
- **System map** of affected services — escalation paths, on-call ownership, dependencies
- **Related action items** from prior retros that called for runbook coverage

Insertion point: step 1 (identify the scenario) — graph reveals whether a related runbook already exists. Tag findings as `[GRAPH-EXISTING-RUNBOOK]` or `[GRAPH-PRIOR-INCIDENT]`.

`--no-graph` skips. `--graph` forces graphify on `runbooks/`, `incidents/` first.

## Contract

Consumes: scenario description + (optional) incident retro + (optional) existing draft
Produces: stepwise runbook
Requires: nothing
Side effects: writes to .runbooks/
Human gates: a peer on-call should review before the runbook ships; the runbook should be tested in a tabletop exercise before being trusted in production

## Context

Typical workflows: post-incident-retro durable change, proactive coverage of known failure modes, runbook refresh
Pairs well with: incident-retro (upstream), incident-triage (downstream — the runbook is consulted during triage), diagnose (when the runbook diagnostics don't resolve)
