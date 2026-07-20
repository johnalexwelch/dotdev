---
name: decision-memo
disable-model-invocation: true
model: opus
reasoning: high
description: Transforms a completed analysis (or analysis-council output) into a Pyramid Principle / SCQA structured executive memo. Audience-tuned (board, ELT, CEO, customer). Use after analysis-design + execution, when the analyst has findings and needs to communicate a decision recommendation to a specific audience.
---

# Decision Memo

## Purpose

Take a finished analysis — raw findings, a council output, or a draft — and shape it into a memo a decision-maker can act on. The output follows Pyramid Principle structure: lead with the answer, then group supporting arguments, then provide evidence underneath.

This is the synthesis step between "I have the data" and "the audience makes a choice."

## When to invoke

- User says "write the memo," "structure this for the board," "make this exec-ready," "draft the recommendation"
- After `analysis-council` produces a synthesis and the user wants to convert it into a single-voice document
- After `analysis-design` + execution, before sharing with the audience

Routing:

- "Polish this memo I wrote" → `strategic-analysis-review` (review, not draft)
- "Stress-test this recommendation" → `analysis-council`
- "Make this less AI-shaped" → `humanizer`

## Process

### 1. Identify audience and decision

Same anchors as `analysis-design`:

- Who is the reader?
- What decision is being made?
- One-way or two-way door?
- What's their priors / known objections?

If unclear, route back to `analysis-design` or ask once.

### 2. Pick the Pyramid shape

Three common shapes:

**SCQA (Situation-Complication-Question-Answer)** — when the reader needs context first

```
Situation: how things have been
Complication: what changed or what's at risk
Question: what should we do
Answer: <recommendation>
```

**Headline-first (recommended for ELT/board)** — when the reader is familiar with context

```
Answer: <recommendation in one sentence>
Because: <3 supporting claims>
Therefore: <ask / next step>
```

**Decision matrix** — when comparing 2–4 options

```
Options: A, B, C
Criteria: 4–6 attributes
Recommendation: option X because Y
What would change my mind: Z
```

### 3. Draft the headline answer

One sentence. The full recommendation. The audience should be able to read only this sentence and know what you want.

Bad: "We've conducted a comprehensive analysis of engagement patterns."
Good: "Recommend killing Feature X next quarter to redeploy 4 engineers to retention."

### 4. Draft the supporting claims (3, max 5)

Each claim is a complete sentence that supports the headline. Each claim has 1–3 pieces of evidence underneath. Claims must be MECE (mutually exclusive, collectively exhaustive) — no overlap, no gap.

### 5. Stack evidence under each claim

Use the actual data. Cite cuts, sample sizes, confidence levels. Avoid "comprehensive" / "thoroughly" / "robust" — name what was measured.

### 6. End with the ask

What does the reader need to do? Approve, fund, decide, weigh in by date? Be explicit. If no ask, the memo is informational — say that.

### 7. Add "what would change my mind"

One paragraph. Names the evidence that would flip the recommendation. This is the single biggest signal of analytical maturity — adopt it.

### 8. Add "risks and what we'd do"

Top 2–3 risks. For each, what's the early indicator and the mitigation.

## Output structure (Headline-first variant)

```markdown
# <Memo Title — names the decision, not the analysis>

**To**: <audience>
**From**: <author>
**Date**: <date>
**Decision needed by**: <date>

## Recommendation
<one sentence — the headline answer>

## Why (three supporting claims)
1. **<Claim 1 in a complete sentence.>** <Evidence: cuts, numbers, sources.>
2. **<Claim 2.>** <Evidence.>
3. **<Claim 3.>** <Evidence.>

## What we're asking for
<approval, funding, decision, sign-off — be specific>

## What would change my mind
<evidence that would flip the recommendation>

## Risks and mitigations
- **Risk 1**: <description>. Early indicator: <X>. Mitigation: <Y>.
- **Risk 2**: ...

## Out of scope
<what this memo explicitly does not address>

## Appendix (optional)
<deeper analysis, methodology, source data>
```

## Rules

- Lead with the answer, not the process.
- One sentence at the top. If you can't compress to one sentence, the recommendation isn't sharp enough.
- Use MECE supporting claims. If two claims overlap, merge them. If there's a gap, add a claim.
- Preserve real uncertainty. "Recommend with medium confidence" is fine; "fully confident" without basis is slop.
- Specific verbs, not "explore," "consider," "investigate." Action words: do, kill, fund, hire, change.
- Audience-tune: board memos are shorter and more compressed than ELT memos; district-customer memos lead with their concerns first.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:

- **Prior memos to the same audience** — voice / format consistency, audience priors
- **Prior decisions on this topic** — what was decided, what changed, what's still open
- **ADRs that constrain** the recommendation
- **Related analyses** the memo can cite

Insertion point: step 1 (identify audience and decision) — prior-memo retrieval informs voice + structure choice. Tag findings as `[GRAPH-PRIOR-MEMO]`.

`--no-graph` skips. `--graph` forces graphify on `memos/`, `decisions/` first.

## Contract

Consumes: completed analysis findings, council synthesis, or analysis draft
Produces: Pyramid-structured decision memo
Requires: an identified audience and decision (route to `analysis-design` if missing)
Side effects: writes to `.memos/<date>-<slug>.md` if requested
Human gates: requires the user to confirm audience + decision; ambiguity gets one clarifying question, then proceeds with best inference

## Context

Typical workflows: post-analysis, pre-share, executive communication
Pairs well with: analysis-design (upstream), analysis-council (stress-test before writing), strategic-analysis-review (review after drafting), humanizer (post-process), workflow-executive-doc (longer-form orchestration)
