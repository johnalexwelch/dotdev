---
name: strategic-analysis-review
description: Reviews executive-facing analyses for argument strength, weaknesses, Pyramid/SCQA structure, insight quality, wording, and what to add, cut, or reframe. Use when reviewing strategy memos, analytical narratives, board/ELT updates, recommendations, business performance analyses, drafts that need sharper executive language, or when the user says "review this memo", "pressure-test this recommendation", or "make this board update sharper".
---

# Strategic Analysis Review

## Purpose

Run a multi-lens review of an analysis or memo, then synthesize concrete improvements: strengths to preserve, weaknesses to fix, enhancements to add, content to remove, and executive-ready rewording.

For full reviews, this workflow dispatches specialist lanes and cites their outputs in the synthesis. For quick reviews, scale down deliberately and label the depth.

## When To Invoke

- User asks to review an analysis, memo, narrative, argument, recommendation, or executive update
- User wants weaknesses, strengths, enhancements, cuts, or rewording
- Draft should follow Pyramid Principle, SCQA, or executive-facing strategic language
- Draft contains data-backed insight, cohort/retention/acquisition analysis, operating metrics, product/business performance, or leadership recommendations

## Reviewer Lanes

For a full strategic review, dispatch these core lanes in parallel:

| Reviewer | Focus | Subagent |
|----------|-------|----------|
| Argument Strategist | Core claim, logic, causal chain, strengths, weaknesses, overreach, missing counterarguments | `critic` or `analyst` |
| Pyramid/SCQA Architect | Top-down answer, grouping, Situation-Complication-Question-Answer, so-what clarity | `writer` or `architect` |
| Evidence & Precision Auditor | Support for claims, numeric precision, caveats, source confidence, overstatement risk | `verifier` or `analyst` |
| Executive Language Editor | Word choice, strategic tone, concision, sentence shape, rewording options | `writer` |
| Insight / So-What Reviewer | Whether the analysis changes what an executive should believe, decide, or do | `analyst` or `verifier` |
| Counterargument / Red-Team Reviewer | How the argument could be wrong, alternate explanations, predictable objections | `critic` |

Conditional lanes:

| Reviewer | Activate When | Subagent |
|----------|---------------|----------|
| MECE / Grouping Reviewer | Supporting points overlap, miss categories, or feel like a list rather than a hierarchy | `architect` or `writer` |
| Quant / Scenario Reasoning Reviewer | Metric-heavy analysis, cohorts, retention, WAP, funnels, scenarios, or partial-year data | `scientist` or `analyst` |
| Source-to-Claim Traceability Reviewer | Draft cites named sources, summaries, research notes, or contested evidence | `verifier` |
| Stakeholder/Risk Reviewer | Political sensitivity, senior audience, tradeoffs, contentious recommendation | `critic` |
| Decision/Actionability Reviewer | Draft should drive a decision, alignment, resourcing, or next step | `verifier` |
| Removal Pass | Draft is long, repetitive, caveat-heavy, or buries the answer | `writer` |

## Dispatch Contract

Use real subagents when available. Before dispatch, read `references/reviewer-briefs.md`, then read only the per-lane templates for active reviewers.

If subagents are unavailable, say so and perform a reduced inline review labeled `INLINE FALLBACK`; do not claim multi-agent review completion.

Depth modes:

- `quick`: inline or 2 lanes, usually Argument Strategist plus Executive Language Editor.
- `standard`: 4-6 lanes, including all obviously relevant core lanes.
- `full`: all core lanes plus every conditional lane triggered by the draft.

## Process

### 1. Prepare Context

- Identify audience, intended decision, draft status, source material, and desired output depth.
- If audience or decision is unclear, infer conservatively and list the assumption.
- Ask a clarifying question only when the review would be materially misleading without the answer.
- Load `references/reviewer-briefs.md` and active per-lane templates.
- Share the draft and any stated constraints with every active reviewer.

### 2. Dispatch Reviewers

- Choose `quick`, `standard`, or `full` depth from the user's request and the draft's risk.
- Launch active reviewers in one parallel batch when using subagents.
- Record lane, subagent type, status, and one-line output summary.
- Each reviewer returns: strengths, weaknesses, add/cut/reframe opportunities, and concrete wording suggestions where relevant.

### 3. Synthesize

Return a concise executive-edit review:

```markdown
## Strategic Review

### What Works
- Strengths worth preserving.

### Must Fix
- Issues that weaken the argument or could mislead an executive.

### Strengthen
- Additions, reframes, caveats, or structure changes that improve the analysis.

### Cut Or Compress
- Material to remove, demote, or shorten.

### Suggested Rewording
- Before: ...
- After: ...
- Why: ...

### Recommended Shape
- Pyramid answer: ...
- SCQA: Situation / Complication / Question / Answer.

### Review Coverage
- Depth: quick | standard | full
- Lanes: ...
- Skipped: ...
```

## Rules

- Lead with the answer, not the process.
- Preserve uncertainty; do not polish away caveats that matter.
- Prefer precise strategic language over inflated language.
- Flag unsupported claims and false precision.
- Use rewording to sharpen the argument, not merely beautify it.
- When applying the user's sample style, keep the pattern: headline answer, short explanatory paragraph, then bullets with sources/caveats.

## Contract

Consumes: analysis draft, source notes, intended audience, decision context
Produces: multi-lane review synthesis with strengths, weaknesses, enhancements, removals, and rewording
Requires: none
Side effects: none unless the user asks to edit a file
Human gates: ambiguity, missing source evidence, or political sensitivity that would make the review materially misleading without clarification

Runtime requirement: subagent dispatch is preferred for a full review. Inline fallback must be labeled when used.

Bundled resources: `references/reviewer-briefs.md` maps reviewer lanes to per-lane prompt templates.

## Context

Typical workflows: executive memo review, business analysis refinement, board/ELT update polish, strategic recommendation critique
Pairs well with: workflow-executive-doc, humanizer, write-to-obsidian, Notion research skills
