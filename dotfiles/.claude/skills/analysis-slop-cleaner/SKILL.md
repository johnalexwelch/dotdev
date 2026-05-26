---
name: analysis-slop-cleaner
description: Detects and rewrites AI-generated analysis patterns — false precision, generic frameworks, balanced-on-both-sides hedging, "comprehensive" without substance, unsourced "studies show," and synthesis that lists everything instead of answering. Use as post-process for analysis-council, decision-memo, and analysis-design outputs, or directly on a draft.
---

# Analysis Slop Cleaner

## Purpose

`humanizer` strips the writing tells of AI generation. This skill strips the *analytical* tells — patterns specific to analyses, memos, and decision documents that signal "this was produced quickly, without commitment to a point of view."

## When to invoke

- Post-process pipeline for `analysis-council`, `decision-memo`, `analysis-design`, `strategic-analysis-review`
- User says "clean up this analysis," "remove the analysis slop," "is this synthesis too AI-shaped?"
- After any LLM-drafted memo, before it goes to a human reader

This is *not* a general humanizer. Use `humanizer` for prose-level tells. Use this for analysis-shaped tells.

## What it catches

| Pattern | Tell | Fix |
|---------|------|-----|
| False precision | "increased engagement by 12.7%" with no CI | Replace with band or qualified statement: "increased ~10-15%, n=234" |
| Generic frameworks | "we should consider X, Y, and Z dimensions" | Replace with the load-bearing dimension, drop the rest |
| Balanced-on-both-sides hedging | "on one hand X, on the other Y" with no resolution | Force a conclusion or remove |
| "Comprehensive" without substance | "a comprehensive analysis suggests" | Cut "comprehensive"; name what was actually analyzed |
| Unsourced authority | "studies show," "research suggests," "best practice indicates" | Either cite or cut |
| Listed-everything synthesis | A 14-bullet "key findings" section | Reduce to ≤5 load-bearing findings; demote the rest |
| Recommendation-without-decision | "we should explore," "consider evaluating" | Replace with verb-driven recommendation: "do X by Y, owner Z" |
| Confidence-without-specificity | "we are confident" with no basis | Add evidence or downgrade confidence |
| The "however" pivot | Every paragraph hedges with "however" | Cut hedges where the analysis actually does have a position |
| Synthesis as restatement | The synthesis section just restates the findings | Force the synthesis to add what the findings don't say |
| Fake quantification | "significantly," "meaningfully," "substantially" | Replace with the actual number or cut |
| Recommendation soup | 8 recommendations, none ranked | Rank top 3, mark the rest as deferred |
| Decision-not-named | The analysis recommends action without naming the decision being made | Lead with: "this analysis supports the decision to <X>" |

## Process

### 1. Read the input

Identify which sections are LLM-generated (synthesis, exec summary, recommendations) vs. expert-authored (per-expert reads in a council output). Only the LLM sections need cleaning; expert reads preserve voice.

### 2. Scan for the 13 patterns above

Flag each instance. Note the load-bearing version vs. the slop version.

### 3. Rewrite

For each flagged instance:
- **Cut** if the line adds nothing the surrounding text doesn't already say.
- **Sharpen** if the line is right but vague — replace generic words with specific ones.
- **Resolve** if the line hedges — force a position or cut.
- **Specify** if the line claims authority without source — cite or remove the claim.

### 4. Preserve uncertainty that matters

Do NOT remove caveats that are real. A finding with low n or unclear causation should *stay* uncertain in the rewrite. The goal is to remove unjustified hedging, not real hedging.

### 5. Output

Return the cleaned text with a brief change-log:

```markdown
## Cleaned text
<rewritten output>

## Changes
- Removed 4 instances of "comprehensive" / "thoroughly" without substance
- Resolved 2 "on one hand / on the other" hedges to a position
- Replaced 3 "studies show" claims with cited sources / cuts
- Compressed 14-bullet findings list to 5 load-bearing + 9 deferred
```

## Rules

- Do not invent specificity the analysis doesn't have. If the analysis didn't measure n, don't fabricate one.
- Do not impose a single voice across multi-expert sections. Per-expert reads keep their author's voice.
- Do not strip qualifying language that is doing analytical work ("among teachers who logged in" is not slop).
- When in doubt, leave it. The cost of removing a real caveat is higher than the cost of leaving a "however."

## Graph context (GRAPH-FIRST — default behavior)

See `_graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Prior cleaned analyses** in this domain — style consistency, recurring slop patterns previously found
- **Domain-specific vocabulary** that should NOT be stripped (e.g., "denominator drift" is precise, not slop)
- **Author voice patterns** to preserve when the input is from a known author

Insertion point: step 4 (preserve uncertainty that matters) — graph context distinguishes domain-specific precise terms from generic AI vocabulary. Tag preservation decisions as `[GRAPH-DOMAIN]`.

`--no-graph` skips (use for one-off cleaning). `--graph` rarely useful — manual flagging is usually faster.

## Contract

Consumes: analysis draft, memo, or council synthesis
Produces: cleaned text + change-log
Requires: nothing
Side effects: none
Human gates: none

## Context

Typical workflows: post-process for analysis-council, decision-memo, analysis-design
Pairs well with: humanizer (run after this, on the cleaned text), strategic-analysis-review (for deeper structural review)
