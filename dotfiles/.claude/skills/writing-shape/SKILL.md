---
name: writing-shape
description: Take a markdown file of raw material and shape it into an article through a conversational session — drafting candidate openings, growing the piece paragraph by paragraph, arguing about format (lists, tables, callouts, quotes) at each step. Use when the user has a pile of notes, fragments, or a rough draft and wants help turning it into something publishable.
codex-compatible: false
---

# Writing Shape

Take raw material and shape it into an article through collaborative paragraph-by-paragraph construction.

## Contract

Consumes: markdown file of raw material (fragments, notes, rough draft)
Produces: separate article file, grown paragraph by paragraph
Requires: none
Side effects: creates article file at user-specified path
Human gates: user picks opening, approves each paragraph, decides when done

## Soft Context

Typical workflows: second stage of writing pipeline (after writing-fragments), standalone article shaping
Pairs well with: writing-fragments (produces the input file), humanizer (terminal polish on finished article), write-to-obsidian (persist to vault)

## Process

1. Read the input pile end-to-end. Form a sense of what is in it.
2. Draft 2-3 candidate openings. Each implies a different thesis or angle. Force the user to pick or compose a hybrid. The chosen opening defines what the rest must do.
3. Grow paragraph by paragraph. After the opening lands, ask "given this opening, what does the reader need to hear next?" Pull material from the pile. Argue about format (prose vs list vs table vs callout vs quote vs code block).
4. Append to the article file as you go. Don't batch. Write each agreed block immediately.
5. Loop step 3 until the article is done. The user decides when.

## Conversational feel

This is a grilling session inverted. The question is "what is this article actually arguing, and in what order does the reader need to hear it?" Push back. Refuse to let weak transitions slide.

Specific moves to keep using:

- "What does this paragraph do for the reader that the previous one didn't?"
- "If I cut this, what breaks?"
- "Is this prose, or should it be a list? Why prose?"
- "This sentence is doing two jobs — split it or pick one."
- "The opening promised X. We've drifted to Y. Either re-thread it or change the opening."

## Pulling from the pile

Treat the raw material as a quarry, not a script. Pull a fragment, rework it to fit the surrounding paragraph, and place it. A fragment may be split across multiple paragraphs, merged with another, or paraphrased.

If the pile lacks something the article needs, name the gap explicitly: "We need an example here and the pile doesn't have one — give me one now or we cut this section."

## Format arguments

When choosing how to render a beat, weigh these tradeoffs out loud:

- Prose vs. list: Prose carries argument; lists carry parallel items
- Inline vs. callout: Tips and asides go in callouts only if they'd genuinely derail the main argument inline
- Table vs. repeated structure: If the same shape repeats 3+ times with the same fields, table
- Quote vs. paraphrase: Quote when the original wording is the point
- Code block vs. inline code: Multi-line or runnable -> block; single token -> inline

## Writing rhythm

Append to the article file as each block is agreed. Re-read the file from disk before every write. Never overwrite blindly. If the user wants a paragraph rewritten, edit that specific paragraph in place.

## Rules

- Do not edit the raw material file. It is read-only.
- Do not mine for new fragments that aren't in the pile. If the pile is incomplete, name the gap.
- Do not add publishing frontmatter the user didn't ask for.
