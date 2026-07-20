---
name: domain-modeling
disable-model-invocation: true
model: sonnet
reasoning: medium
description: Build and sharpen a project's domain model. Update CONTEXT.md, challenge term usage, record ADRs. Use when sharpening vocabulary mid-session, resolving ambiguous terms, or when another skill needs to maintain the domain model without a full grill session.
---

## Contract

Consumes: current CONTEXT.md (if any), ADRs (docs/adr/), codebase, conversation context
Produces: updated CONTEXT.md, new ADR files when warranted, pending entries in scratch/ephemeral states
Requires: git (only when writing repo artifacts)
Side effects: may update CONTEXT.md and docs/adr/ files; in scratch/ephemeral states emits pending entries instead
Human gates: none for term clarification; ADR creation requires user confirmation

## Context

Typical workflows: invoked inline during grill-with-docs, improve-codebase-architecture, or tdd planning
Pairs well with: grill-with-docs, improve-codebase-architecture, tdd, design-plan, codebase-design

# Domain Modeling

Actively build and sharpen the project's domain model as you design. This is the *active* discipline — challenging terms, inventing edge-case scenarios, and writing the glossary and decisions down the moment they crystallise.

Merely *reading* `CONTEXT.md` for vocabulary is not this skill. This skill is for when you are *changing* the model, not just consuming it.

## Context state

Before touching any files, classify the context state:

| State | Condition | Behavior |
|-------|-----------|----------|
| **Scratch** | No repo or pre-build ideation | Keep terms as `pending_context_entries`; emit ADRs as `pending_adr_entries`; no file writes |
| **Ephemeral** | Temporary session, no durable project | Same as scratch; produce compact summary on request |
| **Staged** | New repo exists, CONTEXT.md may or may not exist yet | Write on first resolved term; create files lazily |
| **Existing** | Mature repo with CONTEXT.md and/or docs/adr/ | Update inline as terms and decisions crystallise |

## File structure

Most repos have a single context:

```
/
├── CONTEXT.md
└── docs/adr/
    ├── 0001-*.md
    └── 0002-*.md
```

If a `CONTEXT-MAP.md` exists at the root, the repo is multi-context — each subdomain has its own `CONTEXT.md` and `docs/adr/`. Update the correct context for the area you're in.

Create files **lazily**: only when you have something to write. If no `CONTEXT.md` exists, create it when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately.

> "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

Do not silently accept drifting terminology — consistency is the whole value of CONTEXT.md.

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term.

> "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Stress-test with concrete scenarios

When domain relationships are being discussed, invent edge-case scenarios that probe the boundaries and force precision.

> "You say an Order can be cancelled. Can it be partially cancelled — some line items removed, others kept? What happens to a payment that's already been captured for the full amount?"

### Cross-reference with code

When the user states how something works, check whether the code agrees. If there's a contradiction, surface it.

> "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update CONTEXT.md inline

When a term is resolved in staged/existing states, update `CONTEXT.md` right there. Do not batch — capture as it happens.

`CONTEXT.md` is a **glossary only**. No implementation details, no specs, no scratch notes. Only terms meaningful to domain experts. Format:

```markdown
## <Term>

<One-paragraph definition. What it is, what distinguishes it from similar terms.>
```

### Emit pending entries in scratch/ephemeral states

In scratch/ephemeral states, emit accepted terms and decisions as structured entries instead of writing files:

```
pending_context_entries:
  - term: Order
    definition: A customer's request to purchase one or more Products...

pending_decision_log_entries:
  - question: Should cancellation be partial or whole-order only?
    decision: Whole-order only for V1
    considered: partial-line-item cancellation
    tradeoff: Partial cancellation requires refund proration logic; deferred
```

These can be flushed to repo files when the project reaches staged state.

## Offering ADRs

Only offer to create an ADR when **all three** are true:

1. **Hard to reverse** — changing your mind later has meaningful cost
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **Real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in `docs/adr/NNNN-<slug>.md`:

```markdown
# NNNN. <Short title>

Date: YYYY-MM-DD
Status: Accepted

## Context

Why this decision was needed.

## Decision

What was decided.

## Alternatives considered

What else was considered and why it was rejected.

## Consequences

What this decision makes easier and harder.
```
