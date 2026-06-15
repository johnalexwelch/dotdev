---
name: humanizer-exec
model: sonnet
reasoning: high
description: Executive-tuned humanizer — strips AI-writing tells and sharpens exec register (active verbs, concrete numbers, lead-with-the-answer, compression). Use as the final polish on any board/ELT/CEO/customer-facing draft, or after decision-memo or strategic-analysis-review. Trigger on "make this exec-ready", "tighten for the board", "de-AI this memo", or any LLM-drafted memo, board update, or deck narrative.
---

# Humanizer (Executive Variant)

Final polish for exec/board/customer drafts that were LLM-written. Does everything the base `humanizer` does, plus tunes for the voice that survives a 15-minute skim. It **sharpens** a draft; it doesn't re-architect it (see Scope).

## Dependencies (all optional — degrade gracefully)

- `humanizer` — its `references/pattern-catalog.md` holds the 29 base AI-writing patterns this extends. If absent, use the common-tells list below.
- `graph-first` — optional voice/audience context; auto-detects a knowledge graph and skips silently if none (`--graph` forces ingestion, `--no-graph` skips).
- `slop-cleaner (analysis mode)` — run *before* this on analytical drafts: it removes analytical tells (false precision, generic frameworks), this handles prose register.
- `decision-memo` / `strategic-analysis-review` — common upstream producers of the drafts you'll polish (not called by this skill).

## Exec-register patterns (beyond the base 29)

| Pattern | Fix |
|---|---|
| Passive verbs ("was conducted") | Active: "we did", "we will" |
| Throat-clearing openers ("This memo explores…") | Cut. Lead with the answer. |
| Adverbial hedging ("relatively", "somewhat", "potentially") | Specify or cut |
| Conjunction stacking ("and furthermore", "additionally also") | Pick one |
| Sentence soup (40+ words) | Break headline sentences to ≤25 words |
| Bullet bloat (5+ in a row) | Compress to 3, or convert to prose |
| Defensive scaffolding ("of course", "it's worth acknowledging") | Cut unless load-bearing |
| Conclusion that restates the start | Replace with the ask or implication |
| Headline buried in paragraph 3 | Move to paragraph 1, sentence 1 |
| Symmetric weighting ("on one hand… on the other…") | Take a position, or cut the framing |
| "We" with no actor | Name the team/person/function when it matters |

Base tells most common in exec drafts: em-dash/semicolon overuse, "it's worth noting", rule-of-three, significance inflation ("critical", "comprehensive"), AI vocabulary ("delve", "leverage", "robust"). Full list: `humanizer/references/pattern-catalog.md`.

## Scope — sharpen, don't reorganize

This is the one rule that, left fuzzy, makes the skill behave inconsistently:

- **MAY:** relocate a buried headline to the top; turn a summary-conclusion into the ask. These sharpen the existing structure.
- **MAY NOT:** merge, reorder, split, or drop sections, or change the argument flow (Pyramid / SCQA — Situation, Complication, Question, Answer), unless asked. If the draft came through `decision-memo`, that structure was deliberate.

Same skeleton, sharper muscle.

## Process

1. **Read** the draft; identify the headline answer. If there's none at all, halt and ask — don't fabricate one (see Gate).
2. **Base pass:** run the base AI-writing tells (load the catalog for non-trivial drafts), then a quick self-audit — "what still reads as obviously AI?" — and fix it.
3. **Exec pass:** apply the table above. Highest leverage: the opening leads with the answer, the close is the ask (not a summary), each heading answers "so what?". If a graph is present, check voice against prior memos by the author/audience and tag findings `[GRAPH-VOICE]`.
4. **Compress** ~20% — never at the cost of a real caveat or a stated confidence basis.

## Output

```
## Cleaned text
<rewritten draft>

## Changes
- Headline moved to sentence 1; words <X> → <Y> (–Z%)
- <N passives → active; hedges cut; paragraphs compressed; etc.>
```

## Rules

- Keep real uncertainty ("medium confidence, because X") and load-bearing caveats (regulatory/governance/risk) even when they cost words. Only cut confidence claims with **no** stated basis.
- Match the author's tone; don't impose your own.
- Honor Scope.

## Contract

Consumes LLM-drafted exec-bound text → produces cleaned text + a change log. Requires nothing hard (siblings and graph used when present, skipped when not). No side effects unless editing a file in place. **Gate:** if there's no clear recommendation/headline, halt and ask (or route to `decision-memo`); never fabricate one.
