---
name: writing-fragments
description: Grilling session that mines the user for fragments — heterogeneous nuggets of writing (claims, vignettes, sharp sentences, half-thoughts) — and appends them to a single document as raw material for a future article. Use when the user wants to develop ideas before imposing structure, or mentions "fragments", "ideate", or "raw material" for writing.
codex-compatible: false
---

# Writing Fragments

Mine the user for raw material through a grilling session. Produce fragments, not structure.

## Contract

Consumes: user's ideas, topic, or rough thoughts (conversation)
Produces: markdown file of fragments separated by horizontal rules
Requires: none
Side effects: creates/appends to a fragment file
Human gates: asks once where to save; otherwise appends silently

## Soft Context

Typical workflows: first stage of writing pipeline (fragments -> shape or beats -> humanizer)
Pairs well with: writing-shape (takes fragment file as input), writing-beats (takes fragment file as input), humanizer (terminal polish), write-to-obsidian (persist to vault)

## Process

Run a grilling session that produces fragments. Interview the user relentlessly about whatever they want to write about. Do not impose phases, outlines, or structure.

As fragments emerge from either side of the conversation, append them to a single markdown file. The user will be editing this file during the session; always re-read it before writing so their edits are preserved.

If the user did not pass a path, ask once where to save the document, then remember it for the rest of the session.

Capture fragments from the very first thing the user says, including the initial prompt.

On first write, put a single H1 at the top with a working title (it can change later) and nothing else.

## What is a fragment

A fragment is any piece of text that might survive into the final article. It must be readable by the author but does not need to define its terms or be comprehensible to a cold reader. The bar is "is this a piece of good writing?", not "is this a self-contained argument?"

Fragments are deliberately heterogeneous:

- A sharp sentence you'd want to deploy somewhere but don't yet know where
- A claim with a one-line justification
- A vignette: a thing that happened, a code snippet, a scenario, an analogy
- A half-thought: "something about how X feels like Y, work this out later"
- A quote, a piece of dialogue, an overheard line
- A list of related observations that hang together by feel
- A complaint, a confession, a punchline

## File format

Fragments are separated by a horizontal rule (`---`). No headings inside the body. No tags. No order beyond the order they were added.

```text
# Working title

A first fragment lives here.

It can be multiple paragraphs.

---

A second fragment.

---

> A quoted line that the user wants to keep around.

A reaction to it.
```

## Writing rhythm

Append silently. Don't ask permission for each fragment. Mention what you added in passing ("adding that"), but don't interrupt the conversation with save dialogs.

Before every write: re-read the file from disk. The user may have edited, reordered, or deleted fragments between turns. Never overwrite the file; only append (or, if the user asks, edit a specific fragment in place).

The user can say "cut the last one", "rewrite that one sharper", "merge those two" at any time.

## Rules

- Do not impose structure. No outlines, no sections, no argument maps.
- Do not evaluate whether there are "enough" fragments. That is the user's call.
- Do not suggest "organizing" the fragments. That is what writing-shape and writing-beats are for.
