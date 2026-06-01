---
name: writing-shape
description: Take a markdown file of raw material and shape it into an article through a conversational session. Two rhythms — shape (grow paragraph by paragraph as an argument, picking format at each step) and beats (build beat by beat, choose-your-own-adventure narrative style). Use when the user has notes, fragments, or a rough draft to turn into something publishable.
codex-compatible: false
---

# Writing Shape

Turn a pile of raw material into a finished article through collaborative, incremental construction. Pick the rhythm that fits the piece:

- **shape** (default, argument-first) — grow the article paragraph by paragraph, arguing about format at each step. Best for essays, explainers, posts that carry an argument.
- **beats** (narrative-first) — build beat by beat, choose-your-own-adventure: write one beat, then offer 2–3 directions to pivot to next. Best when the piece is a journey rather than a thesis.

Auto-detect from the user's framing ("walk me through it / make the argument" → shape; "let's see where it goes / tell it as a journey" → beats); honor an explicit request.

## Contract
Consumes: a markdown file of raw material (fragments, notes, rough draft). Produces: a separate article file, built incrementally. Requires: none. Side effects: creates/appends the article file at a user-specified path (ask once, remember it). Human gates: the user picks the opening/starting beat, approves each block, and decides when it's done.

## Shared rules (both rhythms)
- The raw material file is **read-only** — never edit it. Treat it as a quarry: pull a fragment, rework it to fit, place it; split/merge/paraphrase as needed.
- Append each agreed block to the article file immediately — don't batch. **Re-read the file from disk before every write** (the user may have edited between turns).
- If the pile lacks something the piece needs, name the gap explicitly rather than inventing material: "We need an example here and the pile doesn't have one — give me one or we cut this."
- Don't add publishing frontmatter the user didn't ask for.

## Mode: shape (paragraph by paragraph)
1. Read the pile end-to-end; form a sense of what's in it.
2. Draft 2–3 candidate openings, each implying a different thesis/angle. Make the user pick or compose a hybrid — the opening defines what the rest must do.
3. Grow paragraph by paragraph: "given this opening, what does the reader need next?" Pull from the pile. Argue about format out loud:
   - prose vs list (prose carries argument; lists carry parallel items)
   - inline vs callout (callouts only if the aside would derail the main line)
   - table vs repeated structure (same shape 3+ times with same fields → table)
   - quote vs paraphrase (quote when the wording is the point)
   - code block vs inline code
4. Keep pushing: "What does this paragraph do that the last didn't?" "If I cut this, what breaks?" "The opening promised X; we've drifted to Y — re-thread or change the opening." Refuse weak transitions.
5. Loop until the user says it's done.

## Mode: beats (choose-your-own journey)
1. Write 2–3 candidate **starting beats** from the pile, each a different entry point; preview where each might lead. Show them before writing to the file.
2. Once the user picks, write **only that beat** to the file. Stop.
3. Re-read the file, then offer 2–3 candidate **next beats** — directions the journey could pivot to from here.
4. Loop 2–3 until it reaches a natural end. The user can say "cut the last beat", "rewrite it sharper", or "go back to the fork" anytime.

A **beat** does one thing (sets a scene, lands a point, asks a question, drops an aside, twists the angle) then stops — sized by need (a sentence, a short paragraph, or a self-contained vignette). If a beat needs five paragraphs and subheadings, it's two beats — split it. Don't impose whole-article structure; it emerges from the choices.

## Pairs with
writing-fragments (produces the input pile), humanizer (terminal prose polish), write-to-obsidian (persist to vault).
