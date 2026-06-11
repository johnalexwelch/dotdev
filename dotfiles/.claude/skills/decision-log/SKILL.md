---
name: decision-log
model: sonnet
description: Use when grilling, design, PRD, planning, or implementation workflows need to record or consume accepted decisions, alternatives considered, and tradeoffs.
---

# Decision Log

## Purpose

Keep the "why" behind accepted decisions available to future workflows. All grilling sessions must capture a decision log entry for each accepted decision, including the question, the answer, alternatives considered, and tradeoffs accepted.

## Contract

Consumes: accepted decisions, questions asked, alternatives considered, tradeoffs, source conversations or docs
Produces: decision-log entries in the project or domain decision log
Requires: git
Side effects: may create or append to decision-log files after a decision is accepted
Human gates: only record accepted decisions; do not log unresolved recommendations or reopen settled decisions unless the user explicitly does so

## Canonical Location

Prefer the repo-local log:

```text
docs/decision-log.md
```

For non-code or domain-specific work, use the established local equivalent when one already exists. Examples:

```text
docs/decisions/decision-log.md
docs/domain-decisions/decision-log.md
docs/campaign-decisions/decision-log.md
```

If an ADR, domain decision record, or other durable decision artifact is warranted, create it too, but still add a short decision-log entry that points to the record.

## Required Entry Shape

Every accepted decision from any grilling session must preserve:

```markdown
## YYYY-MM-DD - {short decision title}

**Question:** {the question that forced the decision}

**Decision:** {what we decided}

**What else was considered:**
- {alternative}: {why we did not choose it}

**Tradeoffs accepted:**
- {cost, risk, constraint, or future burden we knowingly accepted}

**Source:** {conversation, grill skill, PRD/design link, ADR/CDR link, or issue}
```

## Producer Rules

Use this when a workflow asks questions that settle direction:

- Record only accepted decisions. Draft recommendations and unresolved questions do not belong in the log.
- During all grilling sessions, maintain enough notes to record the decision question, accepted answer, rejected alternatives, and accepted tradeoffs before leaving the grill.
- If the user replies `a`, `y`, `yes`, or `accept`, translate the accepted recommendation into a log entry.
- If the user edits the recommendation, log the edited decision, not the original default.
- Preserve alternatives and tradeoffs from the grill answer. Add newly surfaced tradeoffs from user discussion.
- Group small related decisions under one entry only when they answer the same question.

## Consumer Rules

Before writing a PRD, design plan, system design, session prep, or implementation issue:

1. Read the relevant decision log if it exists.
2. Treat logged decisions as settled context unless the user explicitly reopens them.
3. Reference the decision title or ADR/CDR in downstream artifacts when explaining why a path was chosen.
4. Do not re-grill logged decisions. Ask only about gaps, contradictions, or decisions whose tradeoffs have changed.

## Missing Log Recovery

If prior grill output exists but no decision log exists, reconstruct entries from accepted answers before continuing. Mark uncertain entries with `Source: reconstructed from conversation` and ask the user only when the decision or tradeoff is ambiguous.
