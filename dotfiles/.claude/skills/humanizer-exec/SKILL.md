---
name: humanizer-exec
description: Executive-tuned variant of humanizer. Strips AI-writing tells while preserving (and sharpening) executive-strategic register — confident verbs, concrete numbers, audience-aware compression, decision-driven prose. Use as post-process for decision-memo, strategic-analysis-review output, and any board/ELT/CEO-facing draft.
---

# Humanizer (Executive Variant)

## Purpose

The base `humanizer` removes generic AI patterns (em-dash overuse, rule-of-three, filler phrases, etc.). This variant does that AND additionally tunes for executive register — the voice and shape that survives a 15-minute skim by a busy decision-maker.

Use this when the audience is exec/board/customer and the draft was LLM-generated or LLM-assisted.

## When to invoke

- Post-process for `decision-memo`, `strategic-analysis-review`, executive deck narrative, board memos
- User says "make this exec-ready," "tighten this for the board," "de-AI this memo"
- After `analysis-slop-cleaner` (analysis-slop-cleaner runs first to remove analytical tells; this runs second for prose-register)

## What it does beyond base humanizer

Base humanizer fixes prose-level tells:
- Em-dash overuse, semicolon overuse
- "It's worth noting," "it's important to understand"
- Rule of three pattern ("X, Y, and Z" everywhere)
- "Significance inflation" ("critical," "essential," "comprehensive")
- AI vocabulary ("delve," "leverage," "robust," "navigate")

This skill **additionally** tunes for exec register:

| Pattern | Fix |
|---------|-----|
| Passive verbs ("was conducted," "is being explored") | Active: "we did," "we will" |
| Throat-clearing openers ("This memo explores...") | Cut. Lead with the answer. |
| Adverbial hedging ("relatively," "somewhat," "potentially") | Specify or cut |
| Conjunction stacking ("and furthermore," "additionally also") | Pick one |
| Sentence soup (40+ word sentences) | Break to ≤25 words for headline sentences |
| Bullet bloat (5+ bullets in a row) | Compress to 3 or convert to prose |
| Defensive scaffolding ("of course," "it's worth acknowledging") | Cut unless it's load-bearing |
| Conclusion-as-summary (the end restates the start) | Replace with the ask or implication |
| Headline-buried-in-paragraph-3 | Move to paragraph 1, sentence 1 |
| Symmetric weighting ("on one hand X, on the other Y") | Pick a position or remove |
| "We" without specificity | Name the actor (team, person, function) when it matters |

## Process

### 1. Read the draft

Identify the headline answer (or note its absence). Note the audience signal in the doc.

### 2. Apply base humanizer patterns

Run the base 29-pattern check from `humanizer`. Fix prose-level tells.

### 3. Apply exec-tuned patterns

Run the 11 additional patterns above. Pay special attention to:
- The opening sentence (must lead with the answer)
- The closing (must be the ask, not a summary)
- The headline of each section (must be a complete sentence answering "so what")

### 4. Compress

Aim to cut ~20% of word count without losing content. Most LLM exec drafts can lose 20% without losing meaning.

### 5. Output

```markdown
## Cleaned text
<the rewritten draft>

## Changes
- Headline moved to sentence 1
- Compressed: <original word count> → <new word count> (–X%)
- 4 passive constructions → active
- 6 adverbial hedges removed
- 3 paragraphs compressed to 1 each
- <other notable changes>
```

## Rules

- Do NOT strip real uncertainty. "Medium confidence because of X" is exec-grade; "we are confident" without basis is slop.
- Do NOT remove load-bearing caveats. A regulatory or governance caveat must stay.
- Do NOT impose a personal voice — match the author's tone if discernible.
- Preserve the structure (Pyramid / SCQA / Headline-first) — don't restructure unless asked.
- If the draft has no headline answer, flag it and route back to `decision-memo` rather than fabricating one.

## Graph context (GRAPH-FIRST — default behavior)

See `_graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Prior memos by the same author** — voice patterns, recurring constructions, established register
- **Prior memos to the same audience** — what cadence / vocabulary / framing they've seen before
- **Established team / org idioms** — words that mean specific things internally
- **Brand or voice guidelines** if in graph

Insertion point: step 3 (apply exec-tuned patterns) — graph context informs which patterns to preserve vs. strip. Tag voice-consistency findings as `[GRAPH-VOICE]`.

`--no-graph` skips (use for one-off / external-facing docs). `--graph` forces graphify on `memos/` first.

## Contract

Consumes: LLM-drafted or LLM-assisted exec-bound text
Produces: cleaned, exec-register text + change-log
Requires: nothing
Side effects: none
Human gates: if the draft has no clear recommendation, halts and asks rather than fabricating

## Context

Typical workflows: final-step polish before sending exec-bound material
Pairs well with: analysis-slop-cleaner (run before this), decision-memo (upstream), strategic-analysis-review (deeper structural review)
