---
name: grill-with-docs
model: opus
reasoning: high
description: "Canonical grill engine for design interrogation, V1 product discovery, and doc-driven interviews. Challenges plans against domain context, sharpens terms, captures accepted decisions, and updates docs when a repo exists. Triggers: \"grill me\", \"stress test this\", \"poke holes\", \"challenge this\", \"v1 grill\", \"product grill\"."
---


## Effort

**Think hard** between questions — surfacing the right next question and its tradeoffs is the whole value here. Favor reasoning depth over speed.

## Modes

### Context states

First classify the context state. This controls where accepted decisions and
terms are captured; it does not change the need for user approval.

| State | Condition | Persistence behavior |
|-------|-----------|----------------------|
| **Scratch** | No project repo/context is available or the user is ideating before deciding to build | Keep accepted decisions as `pending_decision_log_entries` and terms as `pending_context_entries`; do not write files |
| **Ephemeral** | User wants a restart/handoff but not a durable repo | Produce a compact handoff/restart brief; do not write project files unless explicitly asked |
| **Staged** | New project repo exists with `CONTEXT.md` and/or `docs/decision-log.md` | Flush pending entries into repo docs before continuing |
| **Existing** | Mature repo/codebase with docs/ADRs/code to inspect | Use current doc-driven behavior and update repo artifacts inline |

### Auto-detection

The skill auto-selects mode based on project state:

| Condition | Mode |
|-----------|------|
| User asks for V1/product idea discovery, "v1 grill", or "product grill" | **V1 product discovery** |
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

### V1 product discovery mode

Use when the user is turning a loose product idea into a scoped V1 concept.
This mode is the product-discovery face of the same grill engine, not a
separate workflow.

- Ask questions in batches of five with recommended answers.
- Keep the conversation non-technical unless the user introduces a hard
  technical constraint or feasibility risk.
- Cover target user, core job-to-be-done, V1 promise, non-goals, primary flow,
  inputs/outputs, success states, failure states, permissions/privacy/trust,
  dependencies, data/memory expectations, onboarding, operating constraints,
  and what would make V1 complete enough to use.
- Resolve contradictions before continuing; prefer a smaller coherent V1 over
  a broad unclear one.
- In scratch/ephemeral states, capture accepted answers as pending decisions
  instead of requiring a repo-local decision log.
- In staged/existing states, write accepted answers to the repo decision log.
- Output an approved or needs-revision `V1_IDEA_BRIEF` when the grill is
  complete. Do not create PRDs, issues, system designs, or implementation plans.

### Autonomous module-grill drafting mode

Used only when called by `workflow-autonomous-backlog`.

- Produces recommended answers, uncertainty notes, and evidence references for a module candidate.
- Uses full-mode question batches when `CONTEXT.md` exists or the module is architecturally significant.
- May draft `CONTEXT.md` / ADR updates when terms or decisions crystallize.
- Does not satisfy the normal human response gate by itself.
- Does not approve PRD creation. Human approval remains required unless the same invocation explicitly pre-authorized low-risk autonomous module acceptance.
- Feeds its output into `MODULE_GRILL_CONSENSUS`, where a critic subagent validates evidence quality.

## Contract

Consumes: topic/plan/design to stress-test or loose V1 product idea; CONTEXT.md, ADRs (docs/adr/), and code when available
Produces: shared understanding, accepted-decision records, updated context terms, optional ADRs, and in V1 mode an approved or needs-revision `V1_IDEA_BRIEF`
Requires: git only when writing repo artifacts or inspecting repo history
Side effects: may update CONTEXT.md, docs/decision-log.md, and ADR files in docs/adr/ when running in staged/existing states
Human gates: every question batch (groups of five) requires user response before continuing; autonomous module-grill drafting mode may draft recommended answers but does not satisfy human approval for PRD creation

## Context

Typical workflows: pre-planning (before /design-plan or /to-prd), domain modeling, V1 idea discovery
Pairs well with: decision-log, design-plan, to-prd, improve-codebase-architecture, domain-modeling, stage-v1-concept, v1-workflow

<what-to-do>

Interview me relentlessly about every aspect of this plan or product idea until
we reach a shared understanding. Walk down each branch of the design tree,
resolving dependencies between decisions one-by-one. For each question, provide
your recommended answer.

**Mode selection:** First classify context state: scratch, ephemeral, staged, or
existing. Then select mode. If the user asks for V1/product idea discovery, use
V1 product discovery mode. If neither V1 nor a complex/doc-backed topic applies
(no CONTEXT.md, simple topic), use lightweight mode. Otherwise use full mode.

**Lightweight mode:** Ask one question at a time. Skip CONTEXT.md and ADR updates. Focus on resolving each decision branch before moving to the next.

**Full mode:** Ask the questions in groups of five, waiting for feedback on each question before continuing.

In full mode, maintain a `.grill-tree.md` scratchpad at the repo root (or in memory only for scratch/ephemeral states). One line per branch: `[ ]` pending or `[x]` resolved, followed by a short question summary. Update it as branches settle so context compaction cannot drop the unresolved frontier. Delete the file when the grill concludes.

**V1 product discovery mode:** Ask in groups of five, waiting for feedback on
each batch. An answer of `a`, `y`, or `yes` accepts the recommendations in that
batch. If the user edits an answer, carry that correction forward. Produce:

```markdown
V1_IDEA_BRIEF:
  product_name:
  one_sentence_pitch:
  target_users:
  core_problem:
  v1_promise:
  primary_user_flow:
  must_have_functionality:
  explicit_non_goals:
  data_and_memory_expectations:
  integrations:
  permissions_privacy_trust:
  failure_states:
  success_metrics:
  open_questions:
  accepted_recommendations:
  decision_log_entries:
  user_overrides:
  approval: approved|needs_revision
```

**Autonomous module-grill drafting mode:** When invoked by `workflow-autonomous-backlog`, draft the question batch, recommended answers, uncertainty notes, and evidence references without treating the draft as user approval. The parent workflow must run critic consensus and still preserve human approval gates.

If a question can be answered from resources available to you (codebase, docs, ADRs, web search), answer it that way instead of asking.

**Decision log requirement:** Use `decision-log` for every accepted
recommendation or user-edited answer when a repo decision log exists. In scratch
or ephemeral states, emit accepted answers as `pending_decision_log_entries`
with the same fields: question, decision, what else was considered, and
tradeoffs accepted. A grill output is incomplete until accepted decisions are
captured either as pending entries or durable repo entries. Draft
recommendations, rejected answers, and unresolved questions stay out of the log.

**Promotion/staging handoff:** If a scratch/ephemeral grill becomes worth
building, do not create a repo yourself unless the user explicitly asks. Hand
off the product/context summary, pending decision entries, pending context
entries, name/slug if known, and restart prompt to `stage-v1-concept` or the
project-staging workflow.

Output should follow the below:
Question
Your Recommendation
Why this is important
Alternatives Considered and the trade offs between them and the recommendation
A visual delineator to separate the questions for ease of reading.

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

Create files lazily and only in staged/existing states. If no `CONTEXT.md`
exists in a staged/existing repo, create one when the first term is resolved. If
no `docs/adr/` exists, create it when the first ADR is needed. In
scratch/ephemeral states, keep terms as `pending_context_entries` instead of
writing files.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Recommend on judgment calls, ask on preference calls

When a question turns on the user's *preference* ("do you want humanizer standalone?"), a bare question is right. But when it turns on *judgment the user lacks the evidence to answer cold* — a design tradeoff, a rule to set, a classification across many items — don't hand them a bare binary. Present a **reasoned recommendation alongside the open question** ("here's the cut I'd make and why; react"), so they refine a draft instead of researching from scratch. Withholding synthesis they then have to ask you for is the smell.

### Lead with the recovery story when gating

When the decision **restricts, gates, locks, or removes** a capability, proactively cover the recovery/escape-hatch *before* asking the user to commit: what breaks, how they undo it, how they restart the affected section. "How do I recover if this fails?" is a predictable objection to any gating decision — surface and answer it yourself rather than making the user raise it.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update CONTEXT.md inline

When a term is resolved in staged/existing states, update `CONTEXT.md` right
there. Don't batch these up — capture them as they happen. Use the format in
[CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md). In scratch/ephemeral states, emit the
term as a pending context entry.

Don't couple `CONTEXT.md` to implementation details. Only include terms that are meaningful to domain experts.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).

</supporting-info>
