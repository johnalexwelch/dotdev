---
name: stage-v1-concept
disable-model-invocation: true
model: sonnet
reasoning: medium
description: Flush a completed grill session into a real project on disk. Takes pending_context_entries, pending_decision_log_entries, and an approved V1_IDEA_BRIEF from a scratch/ephemeral grill and writes them to a staged project directory with CONTEXT.md, decision-log.md, and optional ADRs. Use after grill-with-docs completes in scratch or ephemeral state and the user wants to make the concept real.
---

## Contract

Consumes: approved V1_IDEA_BRIEF and/or pending_context_entries and pending_decision_log_entries from a grill session; optional project name/slug; optional target directory
Produces: staged project directory with CONTEXT.md, docs/decision-log.md, docs/adr/ (if ADRs exist), docs/v1-idea-brief.md (if brief exists)
Requires: filesystem access; git optional (init only if user confirms)
Side effects: creates files and directories on disk; optionally runs git init
Human gates: project location confirmation before writing any files; git init confirmation

## Context

Typical workflows: post-grill project staging (after grill-with-docs in scratch/ephemeral state)
Pairs well with: grill-with-docs, domain-modeling, v1-workflow, v1-system-design

# Stage V1 Concept

Take the output of a completed grill session and write it to a real project directory so the concept becomes buildable.

## When to invoke

- A `grill-with-docs` session in scratch or ephemeral state has completed
- The conversation contains `pending_context_entries` and/or `pending_decision_log_entries`
- The user says "make this real", "stage this", "create the project", "let's build it"

If no grill output is present in context, halt and ask the user to run `grill-with-docs` first.

## 1. Gather inputs from context

Collect from the current conversation:

- `pending_context_entries` — terms and definitions to write to CONTEXT.md
- `pending_decision_log_entries` — accepted decisions to write to docs/decision-log.md
- `pending_adr_entries` — any ADRs that crystallised during the grill
- `V1_IDEA_BRIEF` — the approved brief artifact (if present)
- Product name / slug — from the brief or ask the user

If required inputs are absent, halt and say what's missing.

## 2. Confirm project location

Ask the user:

> "Where should I create the project? (e.g., `~/projects/my-app`) — and should I run `git init`?"

Do not write any files before the user confirms the path. If the directory already exists, confirm before writing into it.

## 3. Create the project structure

Write files in this order:

### CONTEXT.md

```markdown
# Context

<For each pending_context_entry>
## <term>

<definition>
```

If no pending context entries exist, create a minimal CONTEXT.md:

```markdown
# Context

_Add domain terms here as they are defined._
```

### docs/decision-log.md

```markdown
# Decision Log

<For each pending_decision_log_entry>
## <question>

**Decision:** <decision>
**Considered:** <what else was considered>
**Trade-off:** <tradeoff accepted>
```

If no decision entries exist, create a stub:

```markdown
# Decision Log

_Accepted decisions are recorded here._
```

### docs/adr/ (if any ADRs)

For each `pending_adr_entry`, write `docs/adr/NNNN-<slug>.md`:

```markdown
# NNNN. <title>

Date: YYYY-MM-DD
Status: Accepted

## Context
<context>

## Decision
<decision>

## Alternatives considered
<alternatives>

## Consequences
<consequences>
```

### docs/v1-idea-brief.md (if V1_IDEA_BRIEF exists)

Write the full approved `V1_IDEA_BRIEF` verbatim. This becomes the canonical reference for system design.

## 4. Git init (if confirmed)

```bash
git init <project-dir>
git add .
git commit -m "chore: stage V1 concept from grill session"
```

## 5. Emit summary

Report what was written:

```
Staged: ~/projects/my-app/
  CONTEXT.md        — <N> terms
  docs/decision-log.md — <N> decisions
  docs/adr/         — <N> ADRs
  docs/v1-idea-brief.md — approved brief

Next: run v1-system-design (or v1-workflow from Step 3) to turn this into an architecture.
```

Always suggest the next step: `v1-system-design` for system design, or `v1-workflow` starting at Step 3 if the user wants the full pipeline.
