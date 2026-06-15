---
name: analysis-design
model: opus
reasoning: high
description: Designs a decision-first analysis from a question, not from the data. Produces a 1-pager spec — decision being made, audience, headline answer hypothesis, the 3 cuts of data needed, what would change the recommendation, and the analytical plan. Use when starting any non-trivial analysis, before pulling data or writing SQL.
---

# Analysis Design

## Purpose

Most analyses fail because they start from the data ("let me explore this table") rather than the decision ("what does the audience need to choose?"). This skill produces a 1-pager design spec that anchors the analysis to a decision before any SQL is written.

The output feeds into:

- The analyst who runs the analysis
- `analysis-council` for stress-testing the design before execution
- `decision-memo` after results are in

## When to invoke

- User says "I need to analyze X," "let's look at Y," "can you pull data on Z"
- Before starting any analysis that will be >1 hour of work or feed a non-trivial decision
- When a half-finished analysis is wandering and needs a re-anchor

Routing:

- "Design the analysis" → here
- "Challenge my analysis design" → `analysis-council` with the output of this skill as input
- "Write the memo" → `decision-memo` (after this skill + execution)

## Process

### 1. Identify the decision

Force the user to name one of:

- A specific choice (build X vs. Y, fund A or B, kill Z or keep)
- A specific belief that's load-bearing (do parents engage with Class Story? does feature X drive retention?)
- A specific action gate (is metric M healthy enough to ship?)

If the user can't name one, ask once. If they still can't, the analysis doesn't have a decision — flag that as the first finding and offer to switch to `writing-fragments` or general exploration.

### 2. Identify the audience and stakes

- **Audience**: Who reads this? CDO, ELT, board, district customer, internal team?
- **Stakes**: Is this a one-way door or a two-way door? What's the cost of being wrong in each direction?
- **Timeline**: When does the decision need to be made? What's the analysis budget?

### 3. State the headline answer hypothesis

Force the user (or yourself) to state, BEFORE seeing the data, what the headline answer probably is. This is not prediction-as-truth; it's prediction-to-detect-surprise. If the data confirms the hypothesis, the analysis was cheap. If it diverges, the analysis was worth doing.

### 4. Name the 3 cuts of data

List the 3 cuts that would resolve the decision:

1. The cut that supports the hypothesis if true
2. The cut that supports the alternative
3. The cut that would surprise you (and force re-framing)

If you can't name 3, you don't understand the question yet. Iterate.

### 5. Name the falsifier

"My recommendation would flip if <X>." This is the line that lets the audience push back productively, and the line that prevents motivated analysis on your end.

### 6. Sketch the analytical plan

- Tables / sources you'll query
- Joins / aggregations / cohorts
- Comparators / counterfactuals
- Statistical method (if any) — t-test? bootstrap? cohort retention curve?
- Governance check: any consent/age/PII concerns? (route to `governance-reviewer` lens if yes)

### 7. Output the 1-pager

```markdown
# Analysis Design: <question>

## Decision
<the specific choice this analysis informs>

## Audience and stakes
- Reader: <CDO / ELT / board / etc>
- Door: one-way | two-way
- Cost of being wrong: <direction A>: <X>; <direction B>: <Y>
- Timeline: <when>

## Headline hypothesis
<what we expect to find, in one sentence>

## Three cuts
1. <cut that supports the hypothesis>
2. <cut that supports the alternative>
3. <cut that would surprise>

## Falsifier
"My recommendation would flip if <evidence>."

## Analytical plan
- Sources: <tables>
- Method: <approach>
- Comparators: <baseline / control>
- Governance: <consent/PII/age notes if any>

## Out of scope
<what this analysis explicitly will not answer>

## Next step
- Stress-test design via `analysis-council` (recommended for high-stakes)
- Or: execute analysis, then loop back to `decision-memo`
```

## Rules

- Do NOT start sketching the analysis without naming the decision. If the user resists, that's the most important finding to surface.
- Do NOT skip the headline hypothesis — even a coin-flip guess is more useful than no anchor.
- Do NOT scope-creep the analytical plan. List only what answers the named decision.
- DO scope OUT what this analysis will not address — it prevents the doc from ballooning.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:

- **Prior analyses** on the same question or close neighbors — has this been answered before
- **Related ADRs / decisions** that constrain the analysis
- **Related metrics / dashboards / sources** that exist and the analyst should know about
- **Prior memos** that already touched this audience on this topic

Insertion point: step 1 (identify the decision) — surface "this decision has been touched before" before the analyst commits scope. Tag findings as `[GRAPH-PRIOR-WORK]`.

`--no-graph` skips. `--graph` forces graphify on `docs/`, `decisions/`, `memos/` first.

## Contract

Consumes: question or topic from user
Produces: 1-pager analysis design spec
Requires: nothing (no data pulls — this is design, not execution)
Side effects: writes design to `.analyses/<date>-<slug>.md` if user requests persistence
Human gates: requires the user (or self) to name a specific decision; if none, the analysis is malformed

## Context

Typical workflows: pre-analysis design, before SQL/dashboard work, before any board-bound analysis
Pairs well with: analysis-council (stress-test the design), decision-memo (downstream output), governance-reviewer persona (called as a check when PII/age/consent is touched)
