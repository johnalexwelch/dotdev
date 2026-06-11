---
name: clarity-review
model: sonnet
description: >-
  Review a document, email, Slack post, memo, metrics update, spec, or set of instructions
  for communication clarity, and produce a structured report of recommended changes — each
  quoting the offending text, naming the principle it breaks, explaining why it matters, and
  giving a concrete rewrite. Built on ClassDojo's "Extreme Clarity" 5 C's (Clear, Context
  Aware, Consistent, Concrete, Concise) plus metrics-reporting rules, and it also catches
  internal contradictions, writer-facing meta-commentary, and false precision. Use whenever
  the user asks to review, critique, edit, tighten, "make clearer", proofread, or give
  feedback on any writing, or pastes a draft asking "how can I improve this?" Trigger even
  when they don't explicitly say "Extreme Clarity" or "5 C's".
---

# Clarity Review

Review a piece of writing against ClassDojo's standards for clear communication. Your job is not to rewrite it wholesale or nitpick grammar — it's to find where the reader could be confused, misled, or made to work too hard, explain *why* each spot is a problem, and show a better version.

The core idea: communication is expensive for the *reader*, and the writer should absorb that cost rather than push it onto everyone who reads the message. A vague sentence written once gets misread by fifty people. So the test for every recommendation is: would a busy reader, who doesn't share the writer's full context, understand this correctly on the first pass?

**Mechanics:** follow `review-scaffolding` for the review discipline, severity vocabulary, and report contract. The criteria, unit of analysis, and deltas below are what make this a *clarity* review.

## Criteria — the standards

Apply the 5 C's to everything; the metrics rules when the document reports numbers; the structural checks to longer docs, specs, and instructions.

### The 5 C's of Extreme Clarity

1. **Clear** — One possible meaning. Watch for pronouns with no clear antecedent ("it", "this"), times with no timezone or deadline ("by Wednesday" — end of day? which zone?), and instructions that don't say *where* or *how* ("sign up" — where?).
2. **Context Aware** — Use only words, acronyms, and references the *entire intended audience* knows. Spell out any acronym or internal term on first use, e.g. "LED (Launches, Experiments, Decisions)". Ask: does every reader know what this points to?
3. **Consistent** — Same name, term, and format every time. "The review" in one place and "the LED meeting" in another for the same thing forces the reader to reconcile them; so do mixed date/time formats or a metric called two different things.
4. **Concrete** — Specific and quantified. Replace vague qualifiers ("slightly positive", "short", "grew quickly", "soon") with specifics ("+2.0M MAU/yr", "1 character", "grew 75% vs last year", "by June 3"). Magnitude adverbs ("much", "significantly", "a lot") are a red flag — quantify them.
5. **Concise** — Only the necessary words. Cut filler ("As far as the process goes", "I just wanted to reach out to", "please don't hesitate to"), redundancy, and throat-clearing. Concise isn't terse or cold — a warm message can still be concise; it's about respecting the reader's time.

### Best practices (where relevant)

- **Lead with the point.** The first sentence (email) or title (doc/slide) should state the actual point, not name the topic. "We propose building X on platform W, accepting a 3-month delay to avoid high eng cost" is a title; "Options to launch feature X" is not. Add a one-line TL;DR on longer pieces.
- **Numbered lists, not bullets**, when items get referenced — so people can say "#2" unambiguously.
- **Make decisions and actions explicit** — what was decided, what action, by whom, by when. Vague ownership ("we should follow up") is a clarity failure.
- **Reference structure** — page/section numbers, "X of Y" totals, for anything people navigate.

### Metrics-reporting rules (when the document reports numbers)

1. **Absolute, YoY, and vs goal.** Carry all three where possible: "5.2M MAU (+12% YoY, -3% vs goal)". A bare number can't be judged good or bad. Corollary: a number worth repeating should have a goal — if there's none, flag that the author may not know what they want it to be.
2. **No weasel words.** Quantify comparative claims: not "grew quickly" but "grew 75% vs last year". (The metrics-specific version of Concrete.)
3. **Green/yellow/red properly.** Green = on track to hit/exceed goal; yellow = off-track but confident in the recovery plan; red = off-track, no known path. Flag "watermelon" status (green all year, suddenly red) — surface risk early.
4. **Experiment results → expected top-line impact.** An in-experiment lift ≠ rolled-out impact: "+X% lift in Y (+Z% expected lift in top-line V once fully rolled out)". If the top-line effect is negligible, say "no expected top-line effect" rather than implying it.
5. **Show how unusual metrics are calculated** — numerator and denominator — so readers can interpret and dig in.
6. **Counter metrics → always give the confidence interval.** "We didn't negatively impact X" hides whether the test could even detect harm. Give the CI.

### Structural and integrity checks (any document; especially specs and instructions)

These cut across the 5 C's and matter most where a reader — or an agent executing the instructions — can't act when the text fights itself.

1. **Internal contradictions.** Two statements that can't both be followed (e.g. "don't restructure" vs. "move the headline to the top"; "Requires: nothing" vs. a default path that queries a database). Quote *both* sides and propose the reconciling rule. Usually the highest-impact find in an instruction doc.
2. **Meta-commentary aimed at the writer, not the reader.** Scaffolding that leaks onto the audience: "(lead with this)", "this section is intentionally decisive", "TODO: tighten". Cut it or convert it to something the reader needs. Test each sentence: "is this *for the reader*, or me talking to myself?"
3. **False precision.** A specific number or citation the reader can't verify or reconcile ("the 29-point check" when only 5 are shown; "studies show" with no study; "up 40%" with no base). Precise-but-unactionable borrows credibility it hasn't earned — point to the source/enumerate it, or drop the number.

## Unit of analysis

Sentence / passage for the prose-level 5 C's; the whole document for the structural and integrity checks.

## Deltas

- **Identify audience and purpose first.** A note to your own team can assume context a company-wide announcement can't — judge Context Aware and Concise against *the actual intended readers*, not an omniscient one. If the audience isn't stated and it changes your review, say so and state your assumption. (This runs before the scaffold's prioritize step.)
- **Severity mapping for the 5 C's:** internal contradictions, a missing decision, or an unexplained acronym in a wide announcement are usually `[HIGH]`; a vague-but-recoverable phrasing is `[MED]`; wording tightening is `[LOW]`/Minor.
- **Section naming:** title the report `# Clarity review: <document name or type>` and the findings section `## Recommended changes`.
- **Protected elements.** Never edit inside code fences, tables, or LaTeX/math — treat them as fixed context you may quote but not rewrite.
- **Readability is advisory, not a target.** You may note a Flesch–Kincaid grade level as one *signal*, but never recommend a change merely to move the score. A short sentence that misleads is worse than a long one that doesn't — the 5 C's, not a readability formula, decide. There is deliberately **no "strictness" / rewrite-aggressiveness knob**: this review finds where the reader is confused and shows a better version; it does not do wholesale rewriting.
- **Tracked-changes (opt-in).** Opts into the scaffold's tracked-changes output. When the user asks to "show edits" / "track changes," append the text with `~~cuts~~` and **insertions** plus a change table *after* the `## Recommended changes` report — every inline edit tracing to a numbered finding. Default off; the findings report is always the primary deliverable.

## Persistence

None.

## Worked example

For the canonical "less clear" email and the review it should get, read `references/example-review.md`.
