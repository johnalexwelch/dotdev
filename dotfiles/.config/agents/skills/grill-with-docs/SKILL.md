---
name: grill-with-docs
layer: judgment
model: fable
reasoning: high
description: "Canonical grill engine for design interrogation, V1 product discovery, and doc-driven interviews. Challenges plans against domain context, sharpens terms, captures accepted decisions, and updates docs when a repo exists. Supports HITL and Delegate execution modes. Triggers: \"grill me\", \"stress test this\", \"poke holes\", \"challenge this\", \"v1 grill\", \"product grill\"."
---


## Effort

**Think hard** between questions — surfacing the right next question and its tradeoffs is the whole value here. Favor reasoning depth over speed.

## Execution Modes

At the start of every grill session, select one:

### HITL (Human-In-The-Loop) Mode

**Current default behavior.** User answers each batch of questions directly, optionally accepting or editing recommended answers. Full user control over every decision. Select this when you need high user involvement and want to walk through decisions interactively.

### Delegate Mode

**New: AFK-unless-necessary.** Auto-accept recommended answers, then route each grill question to domain-specialist subagent reviewers for critique and consensus. Loop to resolution or escalate only genuinely-contested decisions back to the human.

**When to pick Delegate:**

- Routine grilling where most decisions will be uncontroversial
- User is bandwidth-constrained but wants rigor on contested points
- You want an audit trail showing which decisions were human-driven vs. auto-resolved

**Selection UI:** At grill start, show:

```
EXECUTION MODE SELECT
(1) HITL     – User answers each batch, full control
(2) Delegate – Auto-accept, specialist review, escalate disagreements only
Enter choice (1 or 2):
```

## Delegate Mode Specification

See `references/delegate-mode.md` for the complete Delegate mode flow including:

- D1 routing rules for domain-specialist subagents
- D2 consensus loop with override and escalation
- D3 per-domain-batch granularity  
- D4 mid-grill escape hatch (`defer`, `delegate the rest`)
- D5 provenance tagging (`human`, `auto+specialist-consensus`, `escalated-human`)

The Delegate flow runs after HITL-compatible question batches are drafted; it overlays specialist review on auto-accepted answers before finalizing the decision log.

## Context states

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

### Preflight (ticket-backed / resumed grills)

Before grilling a ticket-backed decision (an issue number, or a handoff that says "grill #N"),
VERIFY the ticket is still open and undecided — a handoff is a proxy; the tracker is authoritative,
and a concurrent agent may have resolved it since the handoff was written:

```bash
gh issue view <N> --repo <owner/slug> --json state,comments
```

- If **CLOSED**, or an existing comment already carries a resolution/decision → **STOP re-deriving.**
  Switch to *reconcile-mirror* mode: read the locked resolution and mirror it into `docs/decision-log.md`
  if missing; do not author a fresh, possibly-conflicting decision.
- Only when the ticket is genuinely open and unresolved do you start the interview below.

(Skip this gate for ad-hoc "grill me" sessions with no backing ticket.)

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

**Wayfinder escalation.** A full-mode grill can surface evidence that the effort demonstrably exceeds one session's resolution — the signal examples live in `workflow-feature`'s "Step 1 escalation: wayfinder handoff" clause, which owns them; this applies equally when the grill was invoked outside workflow-feature. When that evidence appears, halt the interview, present the escalation recommendation with the evidence, and on user confirmation hand off to `/wayfinder` chart mode, seeding it with the answers captured so far: `pending_decision_log_entries` and the open branches in `.grill-tree.md` become ticket candidates. Never escalate on a guess at grill start — only on accumulated mid-grill evidence, and only with the user's confirmation (wayfinder is explicit-invocation only).

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

Consumes: topic/plan/design to stress-test or loose V1 product idea; CONTEXT.md, ADRs (docs/adr/), and code when available; execution mode selection (HITL or Delegate)
Produces: shared understanding, accepted-decision records (tagged by provenance in Delegate mode), updated context terms, optional ADRs, and in V1 mode an approved or needs-revision `V1_IDEA_BRIEF`
Requires: git only when writing repo artifacts or inspecting repo history; taskflow and domain-specialist subagents when running Delegate mode
Side effects: may update CONTEXT.md, docs/decision-log.md, and ADR files in docs/adr/ when running in staged/existing states; in Delegate mode, routes questions to specialist subagents and collects their consensus feedback
Human gates: in HITL mode, every question batch requires user response; in Delegate mode, only escalated decisions require human input; escape hatch (`defer`, `delegate the rest`) can pivot remaining questions mid-grill

## Process

### Starting a grill session

1. **Detect context state** (scratch, ephemeral, staged, or existing)
2. **Auto-select grill sub-mode** based on context (V1 product discovery, lightweight, or full)
3. **Present execution mode selector** (HITL vs Delegate)
4. **Proceed with chosen flow** (HITL or Delegate)

Completion criterion: user has selected execution mode and the grill has begun question generation.

### HITL flow (current behavior)

- User answers question batches directly
- User may accept recommended answers with `a`, `y`, or `yes`; or edit answers
- Captured decisions are tagged `human` in the decision log
- If user says `defer` or `delegate the rest`, pivot remaining questions to Delegate mode (see Escape hatch section)

Completion criterion: all question branches resolved and decisions captured in CONTEXT.md, decision log, and/or pending entries.

### Delegate flow

See `references/delegate-mode.md` for the detailed flow. Briefly:

1. **Draft question batch** (same as HITL)
2. **Auto-accept all recommended answers**
3. **Tag each question with a domain** (security, architecture, risk, product, tie-break)
4. **Route batch to specialist subagent** based on domain (taskflow dispatch)
5. **Specialist reviews** auto-accepted answers and may override
6. **Consensus loop**: if specialist disagrees with auto-accepted answer, re-review up to 3 rounds
7. **Escalate if needed**: after 3 rounds with no consensus on any question, escalate only that specific decision back to human
8. **Capture with provenance**: each decision tagged `auto+specialist-consensus` or `escalated-human`
9. **Continue to next batch** or conclude if all branches resolved

Completion criterion: all question branches resolved; all decisions captured with provenance tags in decision log and/or pending entries; any escalated decisions have human approval.

### Escape hatch (Delegate mode)

At any point during a Delegate-mode grill, user may:

- Say `defer` → pivot only the *current* question to human review; ask it again in HITL fashion
- Say `delegate the rest` → auto-accept remaining questions without specialist review; conclude grill

In both cases, those decisions are tagged `escalated-human` in the provenance.

Completion criterion: user escape keyword processed; remaining questions handled per the keyword intent; decision-log provenance updated.

<what-to-do>

Interview me relentlessly about every aspect of this plan or product idea until
we reach a shared understanding. Walk down each branch of the design tree,
resolving dependencies between decisions one-by-one. For each question, provide
your recommended answer.

**Mode selection:** First classify context state: scratch, ephemeral, staged, or
existing. Then auto-select grill sub-mode. Next, **present the execution mode selector and wait for user choice** (HITL or Delegate).

**HITL (Human-In-The-Loop) flow:** Ask the questions in groups of five (or one at a time in lightweight mode), waiting for feedback on each batch before continuing. Maintain a `.grill-tree.md` scratchpad at the repo root (or in memory only for scratch/ephemeral states) to track unresolved branches.

**Delegate mode flow:** Follow the detailed process in `references/delegate-mode.md`. Briefly: draft batches, auto-accept all answers, route to domain-specialist subagents for review, loop to consensus or escalate. Tag all decisions with provenance.

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

**Decision log requirement:** follow `decision-log` for every accepted
recommendation or user-edited answer when a repo decision log exists. In scratch
or ephemeral states, emit accepted answers as `pending_decision_log_entries`
with the same fields: question, decision, what else was considered, and
tradeoffs accepted. In Delegate mode, **tag each entry with provenance**:
`human`, `auto+specialist-consensus`, or `escalated-human` (see D5 in `references/delegate-mode.md`). A grill output is incomplete until accepted decisions are
captured either as pending entries or durable repo entries, with full provenance
in Delegate mode. Draft recommendations, rejected answers, and unresolved questions stay out of the log.

**Pre-lock ground-truth gate:** Before locking a decision whose correctness
depends on how something is actually implemented (substrate, engine,
integration, data location, read/write path), verify it against the
authoritative repo or running state — not priors, memory, or verbal summaries.
While a checkable verification question is open, do not fan the decision out to
durable records (decision log, CONTEXT.md, ADRs, tickets); resolve the check
first, then lock and capture.

**Promotion/staging handoff:** If a scratch/ephemeral grill becomes worth
building, do not create a repo yourself unless the user explicitly asks. Hand
off the product/context summary, pending decision entries, pending context
entries, name/slug if known, and restart prompt to `stage-v1-concept` or the
project-staging workflow.

## Context-Rich Question Template

Every question must be self-contained so humans can answer in any order and specialists can evaluate without needing the full frontier. Use this format:

```markdown
───────────────────────────────────────────────────────────────
### Q<N>: <Short title>

**Question:** <The actual question>

**Recommendation:** <Your proposed answer>

**Why it matters:** <1-2 sentences: what decision this unblocks, what breaks if wrong>

**Current assumption:** <The default if user skips — what you'll proceed with>

**Blocks:** <List of downstream questions this unlocks, or "None">

**Alternatives considered:**
- <Alternative 1> — <tradeoff vs recommendation>
- <Alternative 2> — <tradeoff vs recommendation>

**Your answer** (or 'a'/'y' to accept, 'skip' to defer):
───────────────────────────────────────────────────────────────
```

### Why this structure

| Field | Purpose |
|-------|--------|
| **Why it matters** | Human sees impact → can say "out of scope" or prioritize |
| **Current assumption** | Human can confirm with "a" without re-reading recommendation |
| **Blocks** | Human sees dependency chain → knows which answers to nail first |
| **Alternatives** | Human doesn't research from scratch; refines your draft |

### Batch behavior

- In **HITL mode**: present 5 questions per batch; human answers any subset; unanswered questions carry forward with their `Current assumption` marked `[assumed]`
- In **Delegate mode**: auto-accept all `Current assumption` values; specialist reviews the full batch with context visible
- In **Lightweight mode**: one question at a time, same template (simplified: skip `Blocks` if linear)

An answer with 'a' or 'y' accepts the recommendation. 'skip' defers the question (uses `Current assumption` and marks it `[assumed]` in the decision log). In Delegate mode, the auto-acceptance is implicit, and the specialist review supplies the feedback.

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

### Verify capability ownership against the target runtime

Before classifying a requirement, facet, or axis as "owned by / covered by another tool" (and therefore out of scope), confirm that tool actually runs **in the runtime the product ships to** — not just that it exists somewhere. "Tool X already does this" is only true if X is available where this product runs. A peer tool from a different harness/platform is not coverage; the axis is *uncovered*, not owned. When unsure, check availability in the target environment rather than assuming parity.

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
