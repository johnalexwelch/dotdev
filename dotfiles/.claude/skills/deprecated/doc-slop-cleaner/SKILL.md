---
name: doc-slop-cleaner
model: sonnet
description: "Strips AI-generated documentation tells: over-explained obvious code, generic best-practices warnings, redundant comments, signature-restating docstrings, bloated examples, 'comprehensive guide' framing. Use as a final pass on LLM-drafted docs, READMEs, runbooks, or code comments."
---

## Deprecation Status

Status: deprecated. Use `slop-cleaner` instead — it covers both docs and analysis modes.

- Replaced by: `slop-cleaner` (select docs or analysis mode)
- Date: 2026-06-10

---

# Doc Slop Cleaner

## Purpose

LLMs generate documentation that *looks* thorough but actually buries the load-bearing content in noise. This skill strips the noise patterns specific to technical documentation.

Use on:

- README files
- API docs
- Inline code comments / docstrings
- Runbooks
- Architecture docs
- Plugin / skill descriptions

Don't use on:

- Prose meant to persuade (use `humanizer-exec`)
- Analysis output (use `analysis-slop-cleaner`)

## When to invoke

- "Clean up this doc"
- After LLM drafts a README, API doc, runbook
- Before merging LLM-assisted docs
- "De-AI this technical writing"

## What it catches

| Pattern | Tell | Fix |
|---------|------|-----|
| Restating the signature | `def get_user(id)` followed by docstring "Gets a user by id." | Cut or add what isn't obvious |
| Over-explained obvious code | `# increment counter by 1` next to `counter += 1` | Cut |
| Generic best-practice warning | "Be sure to handle errors appropriately" | Cut unless specifying which errors |
| "Comprehensive guide" framing | "This comprehensive guide will walk you through..." | Cut framing; lead with the task |
| Redundant inline + block comments | Block comment above + inline next to + docstring all saying same thing | Pick one |
| Defensive scaffolding | "Note that," "It's important to note that," "Keep in mind" | Cut unless the note is non-obvious |
| Bullet bloat in setup | 15-step setup that could be 4 commands | Compress to commands, prose only where needed |
| Step numbering for trivial sequences | "Step 1: Open the file. Step 2: Read it." | Use prose |
| Capability soup | "This module provides functions for X, Y, Z, A, B, C..." | Pick the 3 load-bearing ones; link the rest |
| Generic intro paragraph | "In modern software development, X is crucial..." | Cut; lead with what this doc is for |
| Pattern-spotted examples | Three near-identical examples showing the same pattern | Keep one with variation noted |
| Output-format restating | "The output will be a JSON object with the following fields: ..." next to a schema | Pick one |
| Closing wrap-up | "In conclusion, this module..." | Cut; the doc ends when the content ends |

## Process

### 1. Read the doc

Identify the doc type (README, API, runbook, inline) — different types tolerate different levels of explanation.

### 2. Scan for patterns

Walk the 13 patterns. Flag each instance.

### 3. Rewrite

For each flagged instance:

- **Cut** when the surrounding text already says it
- **Sharpen** when the line is right but vague
- **Replace** when the bullet/prose form is wrong for the content
- **Merge** when overlap exists across inline + block + docstring

### 4. Preserve the load-bearing content

Don't strip examples that are doing real work. Don't cut warnings that protect against real footguns. The goal is to remove ceremony, not content.

### 5. Output

```markdown
## Cleaned doc
<rewritten text>

## Changes
- Removed N "comprehensive guide" framings
- Compressed N-step setup to M commands
- Cut N redundant inline-vs-block comment overlaps
- Replaced N "step 1, step 2" sequences with prose
- ...

## Word count
- Original: X
- Cleaned: Y (-Z%)
```

## Rules

- Don't strip useful examples. The cost of removing a load-bearing example is higher than the cost of leaving a bullet.
- Don't impose a personal voice — match the doc's existing tone if discernible.
- Don't restructure the doc unless asked. Pattern-strip in place.
- If a doc has no clear purpose statement (what is this README for?), flag it but don't fabricate one.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:

- **In-repo documentation conventions** — established README structure, docstring style, comment density
- **Related docs** the cleaned output should align with stylistically
- **Code modules referenced** — their actual API (so over-explanation can be cut to "see <module>")
- **Prior cleaned docs** — patterns already addressed

Insertion point: step 2 (scan for patterns) — graph context informs which conventions are local norms vs. cuttable noise. Tag retained patterns as `[GRAPH-CONVENTION]`.

`--no-graph` skips. `--graph` forces graphify on `docs/` first.

## Contract

Consumes: technical doc / README / API doc / inline comments / runbook
Produces: cleaned doc + change log
Requires: nothing
Side effects: none
Human gates: none

## Context

Typical workflows: post-draft doc polish, README cleanup, code-comment audit
Pairs well with: humanizer (run after for prose-level tells), describe-pr (when the doc is a PR description)
