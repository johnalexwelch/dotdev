---
name: dashboard-design
model: opus
reasoning: high
description: Designs a dashboard from a decision, not from available data. Identifies the question, the audience, the 3–6 charts that resolve it, the time grain, the comparators, and what NOT to include. Produces a spec ready for implementation in Metabase / Looker / Tableau / Hex. Use before building any non-trivial dashboard.
---

# Dashboard Design

## Purpose

Most dashboards fail because they were built from available data ("here's what we have, what should we put on it?") rather than a decision ("what does this person need to choose?"). The result is dashboards that everyone has and nobody uses.

This skill produces a design spec anchored to a decision, an audience, and a small number of decisive charts.

## When to invoke

- "Design a dashboard for X"
- "I need a board / ops / exec dashboard"
- "Build a dashboard that shows Y"
- Before implementation in any BI tool

Routing:

- Review existing dashboard → `dashboard-review`
- Just write SQL for a chart → `sql-review` after writing
- Decision-level analysis → `analysis-design`

## Process

### 1. Lock the decision

The dashboard exists to support one (or a small number) of recurring decisions. Force the user to name it:

- "Decide whether to escalate" (ops / incident)
- "Decide whether to keep / kill X" (product)
- "Decide weekly resourcing" (engineering)
- "Decide quarterly bets" (exec)

If the user can't name a decision, propose the most likely one and ask for confirmation.

### 2. Identify the audience and cadence

- **Audience**: Exec, ELT, ops on-call, individual contributor, customer-facing CS, district admin
- **Cadence**: How often will they look? Realtime / daily / weekly / monthly?
- **Time-on-page**: 30s / 5min / deep dive

Audience and cadence drive chart count, density, and interaction model.

### 3. Pick the 3–6 charts that resolve the decision

For each chart, name:

- **The question it answers** (in plain language)
- **The chart type** (line, bar, area, scatter, table, single-stat)
- **The time grain** (day / week / month / quarter)
- **The comparator** (vs prior period, vs target, vs baseline, vs cohort)
- **The drill-down** (what does clicking it reveal — or is it terminal?)

For each chart, apply `viz-integrity/SKILL.md`: chart type must fit the data shape, axes must be honest (bars start at zero), palette must be color-blind-safe, and meaning must never be encoded by color alone.

Cap at 6 charts. If you can't, the dashboard is trying to answer multiple decisions — split it into two.

### 4. Pick the headline

Every dashboard has one stat at the top. What's it? Usually the parent metric of the decision. Single-stat-with-trend is canonical.

### 5. Define "what's NOT here"

Explicitly list what users might expect that this dashboard does NOT include — and why. This is half the design.

- "Why isn't <metric X> here?" — because it doesn't change the decision
- "Why isn't there a per-user breakdown?" — privacy / governance
- "Why isn't there a day-level view?" — noise; weekly is the relevant grain

### 6. Define refresh, freshness, and alerting

- How often does data refresh?
- What's the freshness contract (warn at >24h, fail at >72h)?
- Should any chart trigger an alert? (Threshold or anomaly.)

### 7. Output spec

```markdown
# Dashboard: <name>

## Decision
<the recurring choice this dashboard supports>

## Audience and cadence
- Reader: <role>
- Cadence: <daily | weekly | monthly>
- Time-on-page: <typical>

## Headline
- Metric: <single stat>
- Comparator: <vs prior period | vs target>
- Trend window: <X>

## Charts
1. **<title>**
   - Question: <what it answers>
   - Type: <line | bar | etc>
   - Grain: <time>
   - Comparator: <X>
   - Drill: <click target or none>

2. ...

(3–6 charts max)

## What's NOT here
- <metric / breakdown that users may expect but is omitted>: <why>
- ...

## Data sources
- <table / model / metric name>

## Refresh and freshness
- Refresh: <hourly | daily | etc>
- Freshness SLA: <warn at X, fail at Y>
- Alerts: <if any>

## Governance
- <consent / PII / aggregation notes if relevant>

## Next step
- Implement in <BI tool> with <these sources>
- Or: review existing draft via `dashboard-review`
```

### 8. Persist

`.dashboards/<name>-spec.md` or alongside existing dashboard docs.

## Rules

- One decision per dashboard. If the user resists, split into two.
- 6 charts max. More = trying to answer multiple questions.
- "What's NOT here" is non-negotiable. It prevents future scope creep.
- Headline stat is mandatory. If you can't pick one, the decision isn't clear yet.
- Time grain is opinionated. Don't show day-level when noise dominates the signal.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:

- **Existing dashboards for the same decision or audience** — duplication candidates
- **Candidate metrics**: each metric's definition, owner, refresh, prior trust issues
- **Related ADRs** constraining what the dashboard can show (governance, aggregation thresholds)
- **Prior dashboard designs** in this area — what worked, what was deprecated

Insertion point: step 1 (lock the decision) — surface "a dashboard already supports this decision" before building a duplicate. Tag findings as `[GRAPH-DUPLICATE]`.

`--no-graph` skips. `--graph` forces graphify on `dashboards/` first.

## Contract

Consumes: decision + audience + (optional) available data sources
Produces: dashboard spec ready for implementation
Requires: nothing
Side effects: writes to .dashboards/
Human gates: requires user to name a decision; one clarifying question max

## Context

Typical workflows: pre-implementation, before opening Metabase / Looker
Pairs well with: viz-integrity (per-chart honesty/accessibility), dashboard-review (post-build), analysis-design (when the decision is one-shot, not recurring), sql-review (per-chart SQL)
