---
name: grill-with-docs
description: Grilling session that handles both lightweight design interrogation and deep documentation-driven interviews. Challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise. Use when user wants to stress-test a plan, get grilled on their design, poke holes in an idea, or challenge a decision. Triggers on "grill me", "stress test this", "poke holes", "challenge this", "grill me hard".
---

## Modes

### Auto-detection

The skill auto-selects mode based on project state:

| Condition | Mode |
|-----------|------|
| No CONTEXT.md + quick/simple topic | **Lightweight** |
| CONTEXT.md present OR deep/complex topic OR user says "grill me hard" | **Full** |

### Lightweight mode

- One question at a time (not batches of five)
- Skip CONTEXT.md and ADR updates
- Focus on reaching shared understanding quickly
- Good for: quick design decisions, simple feature scoping, sanity checks

### Full mode (default when CONTEXT.md exists)

- Questions in batches of five with recommended answers
- Live CONTEXT.md updates as terms are defined
- ADR creation for qualifying architectural decisions
- Relentless interviewing until all decision branches resolved
- Good for: new features, architectural decisions, refactoring plans, system design

### Autonomous module-grill drafting mode

Used only when called by `workflow-autonomous-backlog`.

- Produces recommended answers, uncertainty notes, and evidence references for a module candidate.
- Uses full-mode question batches when `CONTEXT.md` exists or the module is architecturally significant.
- May draft `CONTEXT.md` / ADR updates when terms or decisions crystallize.
- Does not satisfy the normal human response gate by itself.
- Does not approve PRD creation. Human approval remains required unless the same invocation explicitly pre-authorized low-risk autonomous module acceptance.
- Feeds its output into `MODULE_GRILL_CONSENSUS`, where a critic subagent validates evidence quality.

## Contract

Consumes: topic/plan/design to stress-test, CONTEXT.md, ADRs (docs/adr/)
Produces: shared understanding, decision-log entries for accepted grill answers, updated CONTEXT.md terms, new ADR files (when decisions crystallize)
Requires: git
Side effects: may update CONTEXT.md and create ADR files in docs/adr/
Human gates: every question batch (groups of five) requires user response before continuing; autonomous module-grill drafting mode may draft recommended answers but does not satisfy human approval for PRD creation

## Context

Typical workflows: pre-planning (before /design-plan or /to-prd), domain modeling
Pairs well with: decision-log, design-plan, to-prd, improve-codebase-architecture

<what-to-do>

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

**Mode selection:** Check for CONTEXT.md in the project and assess topic complexity. If neither exists (no CONTEXT.md, simple topic), use lightweight mode. Otherwise use full mode.

**Lightweight mode:** Ask one question at a time. Skip CONTEXT.md and ADR updates. Focus on resolving each decision branch before moving to the next.

**Full mode:** Ask the questions in groups of five, waiting for feedback on each question before continuing.

**Autonomous module-grill drafting mode:** When invoked by `workflow-autonomous-backlog`, draft the question batch, recommended answers, uncertainty notes, and evidence references without treating the draft as user approval. The parent workflow must run critic consensus and still preserve human approval gates.

If a question can be answered by exploring the codebase, explore the codebase instead.

**Decision log requirement:** Use `decision-log` for every accepted recommendation or user-edited answer. A grill output is incomplete until accepted decisions are available in `docs/decision-log.md` or the repo's established equivalent. Each entry must include the question, decision, what else was considered, and tradeoffs accepted. Draft recommendations, rejected answers, and unresolved questions stay out of the log.

Output should follow the below:
Question
Your Recommendation
Why this is important
Alternatives Considered and the trade offs between them and the recommendation
A visual delineator to seperate the questions for ease of reading.

An answer with 'a' or 'y' represent the user acceptance of the recommendation.

</what-to-do>

<supporting-info>

## Domain awareness

During codebase exploration, also look for existing documentation:

### File structure

Most repos have a single context:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` exists at the root, the repo has multiple contexts. The map points to where each one lives:

```
/
├── CONTEXT-MAP.md
├── docs/
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/
```

Create files lazily — only when you have something to write. If no `CONTEXT.md` exists, create one when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up — capture them as they happen. Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

Don't couple `CONTEXT.md` to implementation details. Only include terms that are meaningful to domain experts.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).

</supporting-info>
