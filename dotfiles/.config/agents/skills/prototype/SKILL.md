---
name: prototype
model: sonnet
reasoning: high
description: "Build a throwaway prototype to answer a design question: a runnable terminal app for state/logic questions, or toggleable UI variations. Use to prototype, sanity-check a data model/state machine, or explore UI options. Triggers: \"prototype this\", \"try a few designs\"."
codex-compatible: true
---

# Prototype

A prototype is throwaway code that answers a question. The question decides the shape.

## Contract

Consumes: design question (explicit or inferred from context)
Produces: runnable prototype code, answer capture (NOTES.md or commit message)
Requires: project build tools (language runtime, task runner)
Side effects: creates prototype files in project (clearly named as throwaway)
Human gates: confirm question before building; capture answer before deleting

## Soft Context

Typical workflows: mid-feature exploration (between grilling and planning), standalone design validation
Pairs well with: grill-with-docs (grilling surfaces a question prototype can answer), workflow-feature (prototype step between grill and PRD), design-plan (prototype validates assumptions before planning)

## Pick a branch

Identify which question is being answered:

- "Does this logic / state model feel right?" -> [LOGIC.md](LOGIC.md). Build a tiny interactive terminal app that pushes the state machine through cases that are hard to reason about on paper.
- "What should this look like?" -> [UI.md](UI.md). Generate several radically different UI variations on a single route, switchable via a URL search param and a floating bottom bar.

If the question is genuinely ambiguous and the user is not reachable, default to whichever branch better matches the surrounding code (a backend module -> logic; a page or component -> UI) and state the assumption at the top of the prototype.

## Rules that apply to both

1. Throwaway from day one, and clearly marked as such. Locate the prototype close to where it will actually be used (next to the module or page it's prototyping for) so context is obvious — but name it so a casual reader can see it is a prototype, not production.
2. One command to run. Whatever the project's existing task runner supports.
3. No persistence by default. State lives in memory. If the question explicitly involves a database, hit a scratch DB or a local file with a clear "PROTOTYPE — wipe me" name.
4. Skip the polish. No tests, no error handling beyond what makes the prototype runnable, no abstractions.
5. Surface the state. After every action, print or render the full relevant state so the user can see what changed.
6. Delete or absorb when done. When the prototype has answered its question, either delete it or fold the validated decision into the real code.
7. Gate any paid / networked / side-effecting call. When the thing being prototyped needs a real external call (an LLM/API request, a billed operation, a mutating side effect), keep the DEFAULT run offline and free: a self-check plus deterministic aggregation over canned fixtures, so it proves the pipeline *shape* with no spend and is safe to re-run. Put the real call behind an explicit flag AND an env gate (e.g. `--live N` + `MYTOOL_LIVE=1`) so a small real-signal confirmation is one opt-in command away. One throwaway then proves both the shape (free, repeatable) and the real signal (bounded, opt-in) — instead of the usual all-mocked (never validated) or every-run-bills (unsafe) split.

## When done

The answer is the only thing worth keeping from a prototype. Capture it somewhere durable (commit message, ADR, issue, or a NOTES.md next to the prototype) along with the question it was answering. If the user is around, that capture is a quick conversation; if not, leave the placeholder so they (or you, on the next pass) can fill in the verdict before deleting the prototype.
