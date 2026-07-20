---
name: brain-ops
disable-model-invocation: true
model: sonnet
reasoning: high
description: Interact with Alex's Karpathy-style second brain from any Claude session. Ingest sources, query concepts, capture thoughts, run the review queue, or check brain health. Use when the user mentions "brain", "ingest", "what do I know about", "capture this", "brain lint", "brain review", or references the wiki/concept pages.
codex-compatible: false
---

# Brain Ops

Operate on Alex's second brain (`~/Documents/Home/_brain/`) from any Claude session, regardless of current working directory.

## Contract

Consumes: user command (ingest, query, capture, review, lint, today, export), optional file path or text
Produces: brain operation result (concept page updates, query answers, review queue, lint report)
Requires: filesystem access to ~/Documents/Home/, uv (for CLI commands)
Side effects: creates/updates files in ~/Documents/Home/_brain/
Human gates: review verdicts require user input; ingest confirmation for large sources

## Soft Context

Typical workflows: knowledge capture (after meetings, reading, sessions), retrieval (before decisions, briefings, prep), maintenance (weekly lint, review queue triage)
Pairs well with: write-to-obsidian (output persistence; in the `core` plugin namespace — plugin-only, not in this corpus), handoff (brain context for next session), prompt-builder (brain context injection for Codex)

## Environment

```
BRAIN_VAULT=~/Documents/Home
BRAIN_DIR=$BRAIN_VAULT/_brain
BRAIN_SCRIPTS=$BRAIN_DIR/scripts
```

## Operations

### Query — "What do I know about X?"

When the user asks about a topic that might be in their brain:

1. Read `$BRAIN_DIR/index.md` (the retrieval catalog)
2. Identify 3-10 pages most likely to contain the answer
3. Read those pages in full
4. Answer with explicit citations: `[[concept-slug]]` or `[[source-slug]]`
5. Never invent claims — only cite what's on a wiki page
6. If the answer is worth keeping, offer: "Save this as a question?" → creates `_brain/wiki/questions/<slug>.md`

### Ingest — "Ingest this into my brain"

When the user points at a file or text to synthesize:

```bash
cd $BRAIN_SCRIPTS && uv run brain ingest "<path>"
```

Or for a dry run (shows what would happen without calling the LLM):

```bash
cd $BRAIN_SCRIPTS && uv run brain ingest-dry "<path>"
```

The path can be:

- Absolute: `/Users/alexwelch/Documents/Home/path/to/file.md`
- Relative to vault: `* Inbox/Readwise/Articles/Some Article.md`
- A file in `_brain/raw/inbox/` (for manual drops)

After ingest, report: which pages were created vs updated.

### Capture — "Remember this" / "Save this thought"

Quick-capture a thought for later triage:

```bash
cd $BRAIN_SCRIPTS && uv run brain capture "the thought text" --tag optional-tag
```

Or from a pipe:

```bash
echo "thought" | cd $BRAIN_SCRIPTS && uv run brain capture -
```

The captured note lands in `_brain/raw/inbox/` and will appear in the next review queue.

### Review — triage the raw queue

Generate the scored review queue:

```bash
cd $BRAIN_SCRIPTS && uv run brain review
```

This writes `_brain/review-queue.md`. The user edits verdicts (ingest/skip/archive), then:

```bash
cd $BRAIN_SCRIPTS && uv run brain review --apply
```

To show what would happen without acting:

```bash
cd $BRAIN_SCRIPTS && uv run brain review --apply --dry-run
```

### Lint — health check

```bash
cd $BRAIN_SCRIPTS && uv run brain lint
```

Checks: broken links, orphan pages, stale stubs, contradictions, missing entities, index drift, resurrection queue. Report at `_brain/lint-report.md`.

### Today — regenerate the front porch

```bash
cd $BRAIN_SCRIPTS && uv run brain today
```

Regenerates `_brain/today.md` with spaced review picks, changes, stubs, contradictions, raw queue counts, resurrection pick, cross-domain spotlight.

### Watch — sweep for new files

```bash
cd $BRAIN_SCRIPTS && uv run brain watch --once
```

One-pass sweep of all source paths. Ingests up to 5 new files found since last sweep.

### Export — dump context for a project

```bash
cd $BRAIN_SCRIPTS && uv run brain export --project <name> --output <path>
```

Exports relevant concept pages for a project to a readable file that other agents (Codex) can consume. See the `brain-aware` skill for how consumers use this.

## When to invoke automatically

- **Before a briefing or meeting prep**: query the brain for relevant concept pages
- **After a significant session**: if new decisions or concepts emerged, offer to capture them
- **When the user references domain terms**: check if a concept page exists and use its synthesis
- **At session end**: if handoff skill fires, check brain for relevant context to include

## Brain structure (quick reference)

```
_brain/
├── AGENTS.md           ← full operating manual (read for detailed rules)
├── index.md            ← catalog of all pages (your retrieval mechanism)
├── today.md            ← daily front porch
├── log.md              ← timeline of operations
├── wiki/
│   ├── concepts/       ← synthesized concept pages (the meat)
│   ├── entities/       ← people, orgs, products
│   ├── sources/        ← one summary per ingested source
│   ├── questions/      ← saved Q&A
│   └── syntheses/      ← cross-cutting essays
├── raw/inbox/          ← drop files here for later triage
└── scripts/            ← Python CLI (uv run brain <cmd>)
```

## Rules

- Never modify files outside `_brain/` in the vault
- Never edit `MOCs/` files (auto-generated by another tool)
- Never delete raw sources
- Never collapse contradictions silently — track them
- Never invent citations — mark ungrounded claims as `[^conjecture]`
- For queries: only cite what's actually on a wiki page
- For ingests: follow AGENTS.md §6 procedure (one source per pass)
- The brain reads from raw source paths but never writes to them
