# Delegate Mode: AFK-Unless-Necessary Grilling

## Overview

Delegate mode auto-resolves routine grill decisions through domain-specialist subagent review, escalating only genuinely-contested decisions back to the human. This realizes the north star: **AFK-unless-necessary applied to grilling itself**.

The flow:

1. **Draft a question batch** (same as HITL)
2. **Auto-accept all recommended answers**
3. **Tag each question with a domain**
4. **Route the batch to a specialist subagent** (security, architecture, risk, product, or tie-break)
5. **Specialist reviews** auto-accepted answers; may override
6. **Consensus loop**: if disagreement, re-review up to 3 rounds; then escalate if no consensus
7. **Capture with provenance tags** before moving to next batch

## D1: Domain Routing with Specialist Assignment

Every grill question carries a **domain tag**. Use this tag to route the batch to the right specialist subagent.

### Domain categories and specialist routing

| Domain | Specialist | Examples |
|--------|-----------|----------|
| **security** | security-reviewer | authentication, authorization, secrets management, data protection, compliance, cryptography, audit, threat models |
| **architecture** | analyst | system design, module structure, abstraction boundaries, interface contracts, data flow, load patterns, scalability |
| **risk/ops/runtime** | risk-reviewer | operational risk, observability, failure modes, recovery paths, capacity planning, cost, performance targets, reliability SLOs |
| **product/scope** | critic | user-facing requirements, feature scope, success metrics, non-goals, prioritization, market/user fit |
| **tie-break/cross-cutting** | plan-arbiter | questions that span multiple domains; meta-decisions about the grill process itself; conflicts between specialist opinions |

### Routing rules

- Classify each question into **one primary domain** (the one that dominates the decision)
- If a question touches multiple domains (e.g., "should we add audit logging?" is both security and ops), pick the **primary one** for the specialist route, and note secondary domains in the specialist's review brief
- Questions in the same domain in a batch are reviewed together by one specialist; do not split a specialist's batch across multiple dispatches
- **Tie-break questions** (routing conflicts, meta-questions, cross-domain decisions) go to plan-arbiter

### Specialist invocation (taskflow dispatch)

Use taskflow to dispatch the batch to the specialist. Each specialist is a **subagent task** with:

- **Input**: the full grill batch (questions + auto-accepted answers), list of secondary domains affected, and the grill context (CONTEXT.md, relevant ADRs, decision history)
- **Task**: review each auto-accepted answer; identify any overrides; provide rationale for agrees and overrides
- **Output**: a structured review (see D2 output spec)

Example taskflow dispatch pseudocode:

```
taskflow.dispatch("security-reviewer", {
  batch: [ Q1, Q2, Q3 ],  // questions with domain tag "security"
  auto_accepted: [ A1, A2, A3 ],
  context: repo_context,
  secondary_domains: ["risk/ops"],
  task: "Review security answers. Override if you disagree. Justify agrees and overrides."
})
```

### Specialist review brief

Each specialist receives context-rich questions (see main SKILL.md "Context-Rich Question Template"). The specialist brief:

```markdown
You are reviewing auto-accepted grill answers in your domain.

For each question, you have:
- **Question** and **Recommendation** (the auto-accepted answer)
- **Why it matters** (impact if wrong)
- **Current assumption** (what was accepted)
- **Blocks** (downstream questions this unlocks)
- **Alternatives considered** (tradeoffs already weighed)

Your task per question:
1. Does the recommendation fit the stated context/constraints?
2. Does the assumption carry hidden risk the primary agent missed?
3. Is the answer internally consistent with other answers in this batch?
4. Are the alternatives fairly weighed, or was a better option dismissed?

Output per question:
- **APPROVE** — answer is sound; one-line rationale
- **CHALLENGE** — [counter-proposal] + [reasoning] + [what changes if adopted]

Do not challenge style or phrasing. Challenge only when the decision is wrong,
risky, or inconsistent. Silence on a question = implicit APPROVE.
```

Completion criterion: specialist task completes and returns structured review output.

## D2: Consensus Loop with Override and Escalation

After a specialist reviews a batch, either:

1. **Full agreement**: the specialist approves all auto-accepted answers → move to next batch
2. **Partial agreement**: the specialist overrides one or more answers → enter consensus loop
3. **Escalation**: after 3 rounds with no consensus on a question, escalate that specific decision

### Specialist override authority

A specialist **may override** an auto-accepted answer. An override is not a flag or suggestion; it is a **binding rejection** of the auto-accepted answer, proposing an alternative. The grill must then either:

- Accept the specialist's override (consensus reached)
- Dispute the override and re-review (enter consensus loop)

### Consensus loop mechanics

When a specialist disagrees with an auto-accepted answer:

1. **Round 1**: Specialist provides override + rationale
2. **Re-review decision**: Grill operator (you) evaluates the specialist's rationale against the original recommendation
   - If specialist's rationale is sound, **accept the override** → consensus reached, move on
   - If specialist's rationale is weak or the original recommendation is stronger, **counter the override** with your reasoning, and re-dispatch the disputed question to the specialist
3. **Round 2**: Specialist receives counter-rationale and responds
   - Agrees with counter-rationale → consensus reached
   - Maintains override with strengthened rationale → round 3
4. **Round 3**: Specialist receives second counter-rationale and makes final determination
   - If specialist still maintains override, **escalate** the decision (only that question) back to human
   - If specialist agrees with counter, consensus reached

**3-round cap**: After round 3, no further loops. Escalate to human if consensus not reached.

Completion criterion: decision resolved (specialist agrees with auto-accepted answer or accepts override) or escalated to human with full evidence trail.

### Escalation to human

When a decision cannot reach consensus after 3 rounds:

- **Escalate only that specific decision**, not the entire batch or grill
- Provide human with: the original auto-accepted answer, all specialist overrides and rationales, all counter-rationales from the grill, and the evidence the human needs to decide
- Tag the decision **`escalated-human`** in provenance
- **Human makes final decision**, and grill continues with the human's decision captured

Do **not** escalate the whole batch or pause the grill. Continue with other (non-escalated) questions in the same batch, and only surface the escalated decision separately.

Completion criterion: human has provided decision on escalated question; grill resumes with next batch.

## D3: Granularity — Per-Domain Batch Review

All questions in a batch that share the same domain are reviewed **together** by one specialist in **one dispatch**, not separately.

Why: A specialist reviewing related questions together can identify cross-question patterns, consistency issues, and second-order effects. A specialist reviewing questions one-at-a-time may miss these.

### Batch composition rules

- **In HITL mode**, questions in a batch are grouped by the grill (arbitrary grouping, typically 5 per batch)
- **In Delegate mode**, after the HITL-format batch is drafted, **re-sort the batch by domain** before specialist dispatch
- Specialists receive all their domain's questions in a batch, not scattered across multiple dispatches
- **Exception**: if a batch has only 1–2 questions in a domain, keep them with the batch for speed (do not wait for a future batch to accumulate more questions in that domain)

### Example batch re-sorting

HITL batch (as drafted):

```
Q1 (architecture): Should we split the monolith?
Q2 (security): How do we secure inter-service comms?
Q3 (architecture): What's the boundary between API and worker?
Q4 (product): Should partial-updates be user-visible?
Q5 (risk/ops): What's the observability baseline?
```

Delegate dispatch (re-sorted by domain):

```
Specialist: analyst
  Q1 (architecture): Should we split the monolith?
  Q3 (architecture): What's the boundary between API and worker?

Specialist: security-reviewer
  Q2 (security): How do we secure inter-service comms?

Specialist: critic
  Q4 (product): Should partial-updates be user-visible?

Specialist: risk-reviewer
  Q5 (risk/ops): What's the observability baseline?
```

Completion criterion: each specialist receives all and only questions in their domain for that grill stage; no question is reviewed in isolation when related questions exist in the same batch.

## D4: Mid-Grill Escape Hatch

At any point during a Delegate-mode grill, the human may:

### `defer`

Pivot **only the current question** to HITL (human) review. The grill re-asks the question in HITL fashion, waits for human response, and captures it as **`escalated-human`** in provenance. Then continues to next question (specialist review if Delegate mode resumes, or HITL if the human also says `delegate the rest`).

Use when: "I want a say on this one decision."

### `delegate the rest`

Pivot **all remaining questions** from Delegate mode to auto-accept mode (no specialist review). Questions continue to be drafted and captured, but specialists are not dispatched. Decisions are tagged **`escalated-human`** because the human explicitly deferred them (even though no human review happened; the label indicates the human took control).

Use when: "I'm out of time; auto-accept the rest without specialist review" or "Just close this out with auto-accept for now."

### Escape keyword matching

- Match keywords case-insensitively: `defer`, `Defer`, `DEFER` are all valid
- `delegate the rest`, `defer the rest`, `auto-accept the rest`, `close it out`, and `skip specialist review` are all synonymous to `delegate the rest`
- Only one keyword per escape; if the human says both, treat `defer` as the action on the current question, and ask which for the rest

### Provenance tagging on escape

- **`defer`**: the deferred question is tagged **`escalated-human`** in the decision log (human reviewed it interactively)
- **`delegate the rest`**: remaining questions are tagged **`escalated-human`** in the decision log (human took control by explicitly deferring specialist review)

Completion criterion: escape keyword detected; remaining questions handled per keyword intent; provenance tags updated in decision log.

## D5: Provenance Tagging

Every captured decision in the decision log **must carry a provenance tag** showing how it was reached. This creates a complete evidence trail.

### Provenance tags

| Tag | Meaning | Capture rule |
|-----|---------|--------------|
| `human` | User answered the question directly in HITL mode (or via escape hatch `defer`) | Applied to all HITL-answered questions; also to questions deferred mid-grill |
| `auto+specialist-consensus` | Auto-accepted answer, reviewed by specialist(s), reached consensus (no override or override countered) | Applied after specialist review loop concludes without escalation |
| `escalated-human` | Auto-accepted answer; specialist override; 3 consensus rounds; no agreement → escalated to human; human decided | Applied to questions that required human decision after specialist disagreement; also used for `delegate the rest` (human control) |

### Decision log entry format with provenance

When capturing a decision, include the provenance tag in the `decision_log_entry`:

```markdown
---
question: "Should the system auto-persist on every state change, or batch-write periodically?"
decision: "Batch-write periodically with a configurable flush interval (default 5 seconds)."
provenance: "auto+specialist-consensus"  # NEW FIELD
considered:
  - "Auto-persist: simpler semantics, higher write load, lower latency sensitivity"
  - "Batch-write: efficient write amplification, introduces eventual consistency trade-off"
tradeoffs: "Chose batch-write for efficiency; eventual consistency is acceptable given the 5s window and the domain context."
---
```

### In HITL-mode decisions

Tag decisions that were directly answered by the human in HITL mode:

```markdown
provenance: "human"
```

### In Delegate-mode decisions with specialist consensus

Tag decisions where auto-accept was affirmed or overridden+countered to consensus:

```markdown
provenance: "auto+specialist-consensus"
status: "[CONSENSUS]"  # visible marker in output
specialist_reviewed_by: ["analyst"]  # optional: list of specialists who reviewed
override_summary: "Security reviewer challenged 'allow plaintext comms' → accepted override to require TLS"  # optional: if an override was countered to consensus
```

### In Delegate-mode decisions with escalation

Tag decisions that required human judgment after specialist disagreement:

```markdown
provenance: "escalated-human"
status: "[UNRESOLVED]"  # visible marker until human decides; becomes [CONSENSUS] after
escalation_reason: "Security reviewer and risk-reviewer diverged on acceptable MTTR after 3 rounds"
specialist_positions: [
  { specialist: "risk-reviewer", position: "MTTR must be <30min", rationale: "SLO commitments" },
  { specialist: "security-reviewer", position: "MTTR acceptable up to 2hrs for patching", rationale: "realistic patch cycle" }
]
human_decision: "1 hour MTTR, with incident-driven fast-track override if <data sensitivity level>"
```

### In Delegate-mode decisions with escape hatch

Tag decisions affected by `defer` or `delegate the rest`:

```markdown
provenance: "escalated-human"
escape_reason: "User invoked 'defer' mid-grill; human reviewed this question directly"
# OR
escape_reason: "User invoked 'delegate the rest'; remaining questions auto-accepted without specialist review (human control override)"
```

### No provenance compression

Do **not** compress the evidence trail. Every decision must show *how* it was reached:

- HITL decisions show the user answered directly
- Specialist-consensus decisions show which specialists reviewed and whether any overrides occurred
- Escalated decisions show the specialist disagreement, all positions, and the human's final call

The evidence trail is the point; do not discard it for brevity.

Completion criterion: every captured decision carries a provenance tag and relevant evidence context; the decision log is an auditable trail of how each decision was reached.

---

## Grill Summary Output (Delegate Mode)

At grill conclusion, emit a summary table showing consensus status for all questions:

```markdown
## GRILL_CONSENSUS_SUMMARY

| Q# | Title | Decision | Status | Reviewed By | Rounds |
|----|-------|----------|--------|-------------|--------|
| Q1 | Auth provider | NextAuth + GitHub OAuth | [CONSENSUS] | analyst | 1 |
| Q2 | Session storage | Redis with 24h TTL | [CONSENSUS] | security-reviewer | 2 |
| Q3 | Rate limiting | 100 req/min per user | [UNRESOLVED] | risk-reviewer | 3 → escalated |
| Q4 | Error handling | Structured error codes | [CONSENSUS] | analyst | 1 |

**Consensus rate:** 3/4 (75%)
**Escalated to human:** Q3 (rate limiting)
**Total specialist rounds:** 7
```

This summary:

- Shows which questions reached AFK consensus vs needed human input
- Tracks review depth (rounds) per question
- Provides an audit trail for the grill's AFK effectiveness

---

## Complete Delegate Mode Workflow (Recap)

1. **Draft question batch** (HITL-style, e.g., 5 questions)
2. **Auto-accept** all recommended answers for that batch
3. **Tag each question** with its domain (security, architecture, risk, product, tie-break)
4. **Re-sort batch by domain** to group specialist work
5. **Dispatch to specialists** (taskflow dispatch per domain)
6. **Collect specialist reviews** and assess agreement
   - Full agreement → tag `auto+specialist-consensus`, move to next batch
   - Disagreement → enter consensus loop (up to 3 rounds)
   - No consensus after 3 rounds → escalate and wait for human decision
7. **Capture all decisions** with provenance tags in decision log
8. **Continue to next batch** or conclude grill if all questions resolved
9. **Watch for escape hatches** (`defer`, `delegate the rest`) and pivot as needed

## Integration with HITL mode

- User can switch from HITL to Delegate at any question by saying `delegate the rest`
- User can switch from Delegate to HITL at any question by saying `defer` (single question) or `defer the rest` (all remaining)
- The provenance tag reflects the actual path: questions answered in HITL are tagged `human`, regardless of when they were asked in the session
