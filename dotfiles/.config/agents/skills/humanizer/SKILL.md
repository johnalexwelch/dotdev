---
name: humanizer
model: sonnet
reasoning: high
description: Remove signs of AI-generated writing from text. Detects 29 patterns (significance inflation, promotional language, AI vocabulary, em dash overuse, rule of three, filler phrases, etc.) and rewrites them. Based on Wikipedia's "Signs of AI writing" guide. Use when editing text to make it sound more natural, or say "humanize", "de-AI", "make it sound human". Exec mode adds executive-register sharpening for board/ELT/CEO/customer drafts — trigger on "make this exec-ready", "tighten for the board", or as the polish step after decision-memo or workflow-executive-doc.
codex-compatible: true
---

# Humanizer

Edit text to remove the tells of AI-generated writing so it reads as natural and human. Based on Wikipedia's "Signs of AI writing" guide (WikiProject AI Cleanup). Preserve the author's meaning and intended tone; the goal is to strip AI-isms and add genuine personality, not to rewrite the message.

## Contract

Consumes: text to rewrite or edit
Produces: draft rewrite, tells found, and final rewrite
Requires: none; bundled references are loaded only when needed
Side effects: none unless the user explicitly asks to edit a file
Human gates: unclear intended meaning, audience, or tone may require clarification before rewriting

## References — load only what the request needs

- `references/pattern-catalog.md` — the 29 patterns, watch-words, before/after examples. Load it as your checklist for any non-trivial text.
- `references/voice-calibration.md` — its **Personality and Soul** section is default reading for any prose rewrite (stripping tells without adding voice produces sterile output that reads as slop). Load its **Voice Calibration** section additionally when the user gives a writing sample or asks for voice-matching.
- `references/final-audit.md` — the final anti-AI pass, output format, and a worked example. Load before the final rewrite on anything longer than a quick line edit.

Keeping this file light is deliberate: most jobs only need one reference, so loading on demand keeps each run cheap.

## How to work

The deterministic detector `scripts/check_tells.py` is not optional — it catches the mechanical tells a self-audit reliably misses. Run it on the way in and again as an exit gate.

1. **Scan the input.** Run `python3 scripts/check_tells.py <file|->` to get a baseline tell count. Add `--locations` (`-v`) to print `line:col  category  <snippet>` per hit so you can jump straight to each one instead of re-searching. For non-trivial text, load `pattern-catalog.md` for the subtler patterns the script can't judge (promotional tone, fake significance, synonym cycling).
2. **Draft** rewrite: replace AI-isms with natural phrasing, vary sentence length, prefer specific detail over vague claims, keep the core message. For prose, apply the **Personality and Soul** pass from `voice-calibration.md` so the result has a pulse, not just an absence of tells.
3. **Gate the output.** Re-run `check_tells.py` on the **final** rewrite. `TOTAL` must be `0`, or every remaining hit is named and justified (a real em dash the author wants, a legitimately quoted phrase, an intentional semicolon). For a hit you've judged legitimate but can't reword away — e.g. a real data enumeration `revenue, margin, and growth` tripping `rule_of_three` — mark its line with an inline `<!-- slop-ok: rule_of_three -->` comment (space-separated categories, or `all`); the detector then suppresses that category on that line so the gate reaches `0` without mangling real content. Use it sparingly and only for justified hits. Rewriting often *introduces* new tells — this re-scan is what catches them. Then run the `final-audit.md` judgment pass for the subtler tells the script doesn't cover.
4. Return the draft, the tells found (script counts + judgment), and the final rewrite.

> Trivial one-line edits can skip the script; anything longer runs both passes.

## Exec mode

For exec-bound drafts (board, ELT, CEO, customer; typical upstream producers: `decision-memo`, `workflow-executive-doc`, `strategic-analysis-review`), run the base passes above, then an **exec pass** that tunes for the voice that survives a 15-minute skim. Highest leverage: the opening leads with the answer, the close is the ask (not a summary), each heading answers "so what?". Then compress ~20% — never at the cost of a real caveat or a stated confidence basis.

Exec-register patterns (beyond the base 29):

| Pattern | Fix |
|---|---|
| Passive verbs ("was conducted") | Active: "we did", "we will" |
| Throat-clearing openers ("This memo explores…") | Cut. Lead with the answer. |
| Adverbial hedging ("relatively", "somewhat", "potentially") | Specify or cut |
| Sentence soup (40+ words) | Break headline sentences to ≤25 words |
| Bullet bloat (5+ in a row) | Compress to 3, or convert to prose |
| Defensive scaffolding ("of course", "it's worth acknowledging") | Cut unless load-bearing |
| Conclusion that restates the start | Replace with the ask or implication |
| Headline buried in paragraph 3 | Move to paragraph 1, sentence 1 |
| Symmetric weighting ("on one hand… on the other…") | Take a position, or cut the framing |
| "We" with no actor | Name the team/person/function when it matters |

Exec-mode rules — these keep the mode consistent:

- **Sharpen, don't reorganize.** MAY relocate a buried headline to the top or turn a summary-conclusion into the ask. MAY NOT merge, reorder, split, or drop sections or change the argument flow (Pyramid/SCQA) unless asked — a `decision-memo` structure was deliberate. Same skeleton, sharper muscle.
- **No headline, no fabrication.** If the draft has no clear recommendation/headline at all, halt and ask or route to `decision-memo`; never invent one.
- Keep real uncertainty ("medium confidence, because X") and load-bearing caveats (regulatory/governance/risk) even when they cost words; only cut confidence claims with no stated basis. Match the author's tone.
- Output adds a change log after the cleaned text: headline moves, word delta, passives→active count, hedges cut.
