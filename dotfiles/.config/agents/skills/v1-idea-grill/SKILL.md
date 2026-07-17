---
name: v1-idea-grill
model: opus
reasoning: high
description: "DEPRECATED — use grill-with-docs in V1 product discovery mode instead. v1-workflow Step 1 now invokes grill-with-docs directly."
disable-model-invocation: true
---

# V1 Idea Grill

## Contract

Consumes: loose product idea, target users, constraints, existing notes
Produces: approved `V1_IDEA_BRIEF` ready for system design and decision-log entries for accepted grill answers
Requires: none
Side effects: none by default; may create or update product notes only when explicitly asked
Human gates: every question batch requires user response; final V1 brief requires user approval

## Context

Typical workflows: idea-to-V1 discovery, pre-PRD product shaping
Pairs well with: decision-log, v1-system-design, to-prd, to-issues, grill-with-docs

## Purpose

Turn a vague idea into a crisp V1 definition without assuming technical implementation. This is looser than `grill-with-docs`: the starting idea may be incomplete, contradictory, or only a desired outcome.

## Process

### 1. Frame the idea

Restate the idea in plain language and identify what is currently unknown. Do not propose architecture, tools, schemas, or implementation modules.

### 2. Run the non-technical grill

Ask questions in batches of five. For each question provide:

- **Question**
- **Recommended answer**
- **Why this matters**
- **Alternatives and trade-offs**

An answer of `a`, `yes`, or `y` accepts the recommendations in that batch. If the user edits an answer, carry that correction forward.

For every accepted recommendation or user-edited answer, use `decision-log` to record the question, final decision, alternatives considered, and tradeoffs accepted. Do this before producing the final brief so downstream system design can understand why the V1 shape was chosen.

Cover these areas before drafting the brief:

- target user and buyer, if different
- core job-to-be-done
- V1 promise and non-goals
- primary user flow
- inputs, outputs, and success states
- failure states and edge cases
- permissions, privacy, and trust expectations
- integrations or external dependencies
- data users expect the product to remember
- onboarding and first-run experience
- pricing, packaging, or operational constraints if relevant
- what would make V1 feel complete enough to use

### 3. Resolve contradictions

When answers conflict, stop and resolve the contradiction before continuing. Prefer a smaller coherent V1 over a broad unclear one.

### 4. Produce the brief

Return this artifact:

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

## Rules

- Keep the conversation non-technical unless the user introduces a hard technical constraint.
- Do not create PRDs, issues, designs, or implementation plans from an unapproved brief.
- If the user asks to continue after approval, invoke `v1-system-design`.
