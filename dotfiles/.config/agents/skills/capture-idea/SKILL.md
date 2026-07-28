---
name: capture-idea
model: sonnet
reasoning: high
description: 'Capture the current idea into the Idea Bin WITH full conversation context — what was considered, decided, rejected, and left open — then return to work. Use when the user says "capture this idea", "save this as an idea", "add to the idea bin", "/idea", or wants to bank an idea/decision that emerged in conversation without losing the reasoning around it.'
---

# Capture Idea (with context)

## Purpose

The value of an idea captured mid-conversation is the *context around it* —
tradeoffs weighed, decisions reached, paths rejected, questions still open.
A cold background note loses all of that. This skill runs **inside the live
conversation** so it can distill that context faithfully, write it to the
Idea Bin, and hand control back so work continues.

## Contract

Consumes: the current conversation (considerations, decisions, rejections,
open questions) + the idea to capture
Produces: one Markdown file in `~/Documents/Home/Idea Bin/`, format-compatible
with the `idea` shell function so `ideas review` / `ideas promote` still work
Requires: none (agent writes the file directly; no shell-out to `idea`)
Side effects: creates one `.md` file in the Idea Bin
Human gates: none — capture is non-destructive; confirm in one line and stop

## Process

1. **Identify the idea.** The user's phrasing, or the concept under discussion.
   If ambiguous, ask one question; otherwise proceed.

2. **Distill context from THIS conversation.** Do not fetch or invent. Pull
   only what actually happened in the stream. Fill the sections below; drop any
   that genuinely have no content (don't pad).

3. **Classify.** Pick one `category` from:
   `tool | app | content | research | business | experiment | feature | creative | home | health | other`.
   Set `domain` (free-form area, e.g. `security`, `infra`, `writing`) or `other`.
   Write a one-sentence `pitch` and 2–4 Obsidian tags (`#idea #...`).

4. **Write the file** to `~/Documents/Home/Idea Bin/` using the template below.
   Filename: `YYYY-MM-DD <title>.md` where `<title>` is the title with the
   characters `/ : * ? " < > |` stripped and truncated to 60 chars.

5. **Confirm and return.** One line: `✓ <filename>`. Then stop and resume the
   prior work. Do not grill or expand here — grilling is a downstream step
   (`grill-with-docs` / `ideas review`).

## Template

```markdown
---
title: <title>
created: <YYYY-MM-DD>
category: <category>
domain: <domain>
energy: 0
status: captured
---

# <title>

> <one-sentence pitch>

#idea #<tag> #<tag>

## Key insight
<the core realization, if there is one>

## Considered
<options / framings / data weighed — include tables or structure verbatim
when they carry the reasoning>

## Decided
<what was actually settled, and why>

## Rejected / ceilings
<paths ruled out and the reason; known limits of the chosen direction>

## Open questions
<what's still unresolved — the follow-ups worth returning to>

## Next Steps
- <concrete next step>
- <concrete next step>
```

## Notes

- Faithful over tidy: preserve the actual tradeoff tables, inversions, and
  phrasing from the conversation. That fidelity is the whole point.
- Compatible-by-design: the frontmatter keys (`title`, `created`, `category`,
  `domain`, `energy`, `status`) match the `idea` shell function, so the
  existing review/promote pipeline picks these up unchanged. The extra
  sections are additive.
- `scripts/check.sh <file>` validates that a generated idea file has the
  required frontmatter keys — run it once after writing if unsure.
