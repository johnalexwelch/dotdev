---
name: workflow-executive-doc
model: opus
reasoning: high
description: "Orchestrates executive-doc creation and review across research, domain analysis, drafting, adversarial critique, revision, and polish. Use for executive memos, board updates, strategy docs, org/product analyses, or any decision document needing multiple expert perspectives."
---

# Workflow Executive Doc

## Purpose

Create or review executive-facing documents through a sequenced multi-expert workflow. This is a thinking system first and a writing system second: evidence comes before analysis, analysis before drafting, critique before polish.

## When to invoke

- User asks for an executive memo, board update, strategy doc, leadership recommendation, or decision brief
- User wants to synthesize messy source material into an executive-ready point of view
- User asks for organizational, operating-model, governance, product-engagement, retention, or activation analysis
- User wants a document reviewed from multiple expert angles before sending
- workflow-router classifies work as "executive document"

## Flow

```
intake -> research-synthesizer -> [iris numeric check] -> domain experts
          -> executive-memo-architect -> numeric claims audit
          -> strategic-reviewer -> revision -> [humanizer]
```

## Workflow Progress Reporting

Follow `../_docs/step-ledger.md` (step-ledger protocol): emit the `WORKFLOW_STEPS` ledger before executing or dispatching any step, update it at every status transition, and include the final ledger in every halt, handoff, and completion response.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| <step name> | required|conditional|optional | pending|completed|skipped|blocked|failed|not_applicable | <evidence, reason, or -> |
```

## Process

### 1. Intake

Clarify the minimum viable brief:

- Audience: who will read this, and what do they already believe?
- Decision: what decision, alignment, or action should this drive?
- Stakes: why now, and what happens if the organization does nothing?
- Sources: which docs, Notion pages, Slack threads, transcripts, analytics, interviews, or prior memos matter?
- Constraints: deadline, length, tone, political sensitivities, and non-goals

If the user only wants a review of an existing draft, skip source gathering only when the draft contains enough evidence to evaluate.

### 2. Evidence pass: research-synthesizer

Use `research-synthesizer` when available; otherwise perform the role directly.

Output:

- Source map with confidence levels
- Key facts and signals
- Themes across sources
- Contradictions or unresolved questions
- Evidence-backed implications

Do not draft recommendations until this pass has separated evidence from interpretation.

### 3. Numeric check: Iris or source-of-truth validation

When the document depends on quantitative claims, route the numbers
through Iris if available, but treat Iris as a fallible assistant, not a
source of truth. Iris is still in development and can be wrong.

Load `references/numeric-claims-ledger.md` and create the ledger before
drafting recommendations.

### 4. Domain expert pass

Load `references/expert-lane-prompts.md`. Activate only the relevant
expert lenses; if both apply, run them independently before synthesis.
If neither applies, state why and continue.

### 5. Draft pass: executive-memo-architect

Use `executive-memo-architect` when available; otherwise perform the role directly.

Load `references/memo-template-quality-bar.md` and use its required
draft structure. Lead with the answer. Put supporting detail after the
recommendation, not before it.

### 6. Numeric claims audit

After drafting, load `references/numeric-claims-ledger.md` again and
extract every number and quantitative comparison from the memo back
into the claims ledger. Re-check any number introduced during writing.
Do not let polishing or synthesis create new numeric claims without
validation.

### 7. Red-team pass: strategic-reviewer

Use `strategic-reviewer` when available; otherwise perform the role directly.

Review for:

- Unsupported claims
- Hidden or fragile assumptions
- Missing data
- Ambiguity in the ask
- Stakeholder and political risk
- Second-order effects
- Pre-mortem failure modes
- Whether the document would actually help an executive make a decision

Return prioritized findings, not general writing feedback.

### 8. Revision pass

Revise the draft using the red-team findings. Track unresolved issues explicitly:

- Accepted changes
- Rejected critique with reason
- Open questions for the user or decision owner
- Evidence gaps that cannot be closed yet

Do not hide uncertainty with smoother prose.

### 9. Final polish

Use `humanizer` only after the reasoning loop is complete. Polish for clarity, brevity, executive tone, and non-AI texture, but preserve the claims, tradeoffs, and caveats produced by the workflow.

## Quality bar

Before finalizing, load `references/memo-template-quality-bar.md` and
verify the artifact against its quality bar.

## Worktree Policy

This workflow is document/research work, not code delivery. It does not cut a code worktree unless the user asks to persist edits into a repository. If repository files will be edited, first resolve `WORKFLOW_BASE_GATE`, create a fresh worktree from the resolved workflow base, and record `WORKTREE_BASELINE_GATE` in the final summary.

## Contract

Consumes: executive-doc request, source material, existing draft, or research brief
Produces: executive-ready memo/draft/review plus unresolved questions and source confidence notes
Requires: none
Side effects: may read external sources or workspace docs when provided; may create or edit document files if user requests persistence
Human gates: intake ambiguity; unresolved strategic or political decisions; final approval before sending/publishing

## Context

Typical workflows: standalone executive writing, leadership strategy work, board/ELT memo prep, multi-source synthesis
Pairs well with: humanizer, write-to-obsidian, Notion research/documentation skills, meeting-intelligence
