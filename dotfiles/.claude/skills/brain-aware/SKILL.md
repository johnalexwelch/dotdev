---
name: brain-aware
description: How to use brain context when it's provided in a prompt. Tells any agent (especially Codex) how to leverage synthesized concept pages, respect domain language, flag contradictions, and produce outputs the brain can later ingest. Active whenever brain-context is injected into a task.
codex-compatible: true
---

# Brain Aware

When brain concept pages are included as context in your prompt, follow these rules to use them effectively and produce outputs the brain can later ingest.

## Contract

Consumes: brain concept pages (included inline in prompt context), task instructions
Produces: task output that respects domain language + optional brain-ingestible artifacts
Requires: none (brain context is provided to you, not fetched)
Side effects: none directly (outputs are ingested by the brain agent later)
Human gates: none

## Soft Context

Typical workflows: any Codex task where brain context was injected by prompt-builder or run-backlog
Pairs well with: prompt-builder (injects brain context), handoff (produces brain-ingestible artifacts), brain-ops (the full brain agent, Claude-only)

## How brain context arrives

Brain context appears in your prompt between markers:

```
<brain-context>
... concept pages, entity pages, or index excerpts ...
</brain-context>
```

Or as a file at `docs/brain-context/<project>.md` in the project repo.

## Rules for consuming brain context

### 1. Use domain language exactly

Concept pages define the team's vocabulary. When a concept page says "WAC" means "Weekly Active Customers" (not classrooms, not children), use that exact meaning. Don't invent your own abbreviations or redefine terms.

### 2. Respect documented decisions

If a concept page or ADR documents a decision (e.g., "chose MetricFlow over Lightdash because X"), don't contradict it unless the task explicitly asks you to revisit that decision.

### 3. Flag contradictions explicitly

If your implementation or findings contradict something in the brain context, don't silently override. Call it out:

```markdown
## Contradiction with brain context

The concept page [[semantic-layer]] states MetricFlow is the chosen engine,
but this task requires Lightdash integration. This may indicate a decision
change that should be captured.
```

### 4. Use citations when referencing brain knowledge

When your output references something from brain context, cite it:

```markdown
Per the team's data architecture guardrails ([[dojo-data-architecture-guardrails]]),
production DB access is not customer-facing SLA-grade substrate.
```

### 5. Don't fabricate brain knowledge

If the brain context doesn't cover a topic, say so. Don't pretend brain context exists for something it doesn't address.

## Rules for producing brain-ingestible output

When your task produces new knowledge the brain should capture, structure it for easy ingestion:

### In handoff artifacts

Include a `## Brain updates` section:

```markdown
## Brain updates

The following should be ingested into the brain:

- **New concept discovered**: [name] — [one-sentence definition]
- **Existing concept updated**: [[concept-slug]] — [what changed and why]
- **New entity**: [name] — [role/relevance]
- **Contradiction found**: [[concept-slug]] says X, but we found Y
- **Decision made**: [what was decided and why] — candidate for ADR
```

### In PR descriptions

If the PR changes something that a brain concept page documents, note it:

```markdown
## Brain impact

This PR changes the WAC calculation methodology. The brain's [[wac]] concept
page documents the prior methodology and should be updated after merge.
```

### In commit messages

No special formatting needed. The brain ingests from higher-level artifacts (PRs, handoffs, session transcripts), not individual commits.

## What NOT to do

- Don't try to access `~/Documents/Home/` or the vault filesystem (you can't)
- Don't try to run `brain` CLI commands (you don't have the environment)
- Don't modify brain concept pages directly (that's the brain agent's job)
- Don't treat brain context as infallible — it's synthesized from sources and may be stale
- Don't ignore brain context — it represents accumulated team knowledge

## Example: Codex task with brain context

```markdown
<brain-context>
## [[iris]] (concept, active, sc=12)
Internal AI/agent-class data tool ClassDojo is shipping...
Eval thread: Gregg methodology at 65%, Will regression-question dataset...

## [[dojo-data-architecture-guardrails]] (concept, active, sc=4)
Named guardrails: (1) dbt-write-access-restricted-to-AE...
</brain-context>

## Task
Implement the IRIS eval harness per issue #42.

## Acceptance criteria
- [ ] Eval framework runs gold-standard SQL against IRIS output
- [ ] Results stored in eval_results/ directory
- [ ] CI runs evals on PR
```

In this case, the agent should:
1. Use "IRIS" (not "Iris" or "iris") per the brain's established naming
2. Know that eval-as-arbiter is the agreed decision mechanism
3. Know that Gregg owns eval methodology and Will owns the dataset
4. Respect dbt-write-access-restricted-to-AE if touching dbt models
5. If the implementation reveals eval methodology needs to change, flag it in `## Brain updates`
