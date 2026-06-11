---
name: improve-codebase-architecture
model: opus
description: Find deepening opportunities in a codebase, informed by the domain language in CONTEXT.md and the decisions in docs/adr/. Use when the user wants to improve architecture, find refactoring opportunities, consolidate tightly-coupled modules, or make a codebase more testable and AI-navigable.
---

## Contract

Consumes: codebase, CONTEXT.md (domain glossary), ADRs (docs/adr/)
Produces: refactoring opportunities report (numbered deepening candidates), optional module grill summaries for workflow-autonomous-backlog
Requires: git
Side effects: none (read-only analysis); may update CONTEXT.md or create ADRs during grilling loop (Step 3)
Human gates: none for analysis; candidate selection requires user choice before grilling

## Context

Typical workflows: architecture improvement (standalone, after /diagnose surfaces structural issues, or as the module discovery lane for workflow-autonomous-backlog)
Pairs well with: diagnose, repo-audit, grill-with-docs, design-plan, workflow-autonomous-backlog

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities** — refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

All development that comes out of this skill must be shaped as vertical slices of app behavior. Do not propose horizontal work such as "build the database layer," "add the API layer," "create all UI components," or "refactor utilities" unless it is part of a thin end-to-end slice with user-visible or system-verifiable behavior.

## Glossary

Use these terms exactly in every suggestion. Consistent language is the point — don't drift into "component," "service," "API," or "boundary." Full definitions in [LANGUAGE.md](LANGUAGE.md).

- **Module** — anything with an interface and an implementation (function, class, package, slice).
- **Interface** — everything a caller must know to use the module: types, invariants, error modes, ordering, config. Not just the type signature.
- **Implementation** — the code inside.
- **Depth** — leverage at the interface: a lot of behaviour behind a small interface. **Deep** = high leverage. **Shallow** = interface nearly as complex as the implementation.
- **Seam** — where an interface lives; a place behaviour can be altered without editing in place. (Use this, not "boundary.")
- **Adapter** — a concrete thing satisfying an interface at a seam.
- **Leverage** — what callers get from depth.
- **Locality** — what maintainers get from depth: change, bugs, knowledge concentrated in one place.

Key principles (see [LANGUAGE.md](LANGUAGE.md) for the full list):

- **Deletion test**: imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep.
- **The interface is the test surface.**
- **One adapter = hypothetical seam. Two adapters = real seam.**

This skill is *informed* by the project's domain model. The domain language gives names to good seams; ADRs record decisions the skill should not re-litigate.

## Process

### 1. Explore

Read the project's domain glossary and any ADRs in the area you're touching first.

Then use the Agent tool with `subagent_type=Explore` to walk the codebase. Don't follow rigid heuristics — explore organically and note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow** — interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow: would deleting it concentrate complexity, or just move it? A "yes, concentrates" is the signal you want.

### 2. Present candidates

Present a numbered list of deepening opportunities. For each candidate:

- **Files** — which files/modules are involved
- **Problem** — why the current architecture is causing friction
- **Solution** — plain English description of what would change
- **Benefits** — explained in terms of locality and leverage, and also in how tests would improve
- **Vertical slice shape** — the narrow end-to-end behavior this candidate would enable or improve; if it only changes one layer, explain why it is not yet ready to become implementation work

**Use CONTEXT.md vocabulary for the domain, and [LANGUAGE.md](LANGUAGE.md) vocabulary for the architecture.** If `CONTEXT.md` defines "Order," talk about "the Order intake module" — not "the FooBarHandler," and not "the Order service."

**ADR conflicts**: if a candidate contradicts an existing ADR, only surface it when the friction is real enough to warrant revisiting the ADR. Mark it clearly (e.g. *"contradicts ADR-0007 — but worth reopening because…"*). Don't list every theoretical refactor an ADR forbids.

Do NOT propose interfaces yet. Ask the user: "Which of these would you like to explore?"

### 3. Grilling loop

Once the user picks a candidate, drop into a grilling conversation. Walk the design tree with them — constraints, dependencies, the shape of the deepened module, what sits behind the seam, what tests survive.

When called by `workflow-autonomous-backlog`, run this grilling loop for every selected module candidate before `to-prd`. If the user asks to "accept recommended answers", provide the recommended answer for each question and proceed with it unless uncertainty is high or the answer would change product behavior, public interfaces, data models, auth/payment behavior, infrastructure, or rollout risk. Record which answers were accepted, overridden, or still need human judgment.

### 3.5. Optional scoped second pass

After the grilling loop, run a second `improve-codebase-architecture` pass inside a selected Module only when the grill exposes real internal friction:

- multiple concepts hidden behind one Interface
- unclear real seams or adapters
- tests that cannot live cleanly at the parent Interface
- internal coupling that defeats locality
- implementation complexity that would spread across callers inside the parent Module if deleted

This second pass is a lens, not a recursive decomposition loop. Bias toward keeping any discovered submodules private to the parent Module unless the submodule has its own stable Interface, passes the deletion test, and earns leverage/locality. Do not create submodules merely because a large Module can be divided by file, layer, or helper function.

Record one of:

- `second_pass: not_needed` with reason
- `second_pass: run` with scope, findings, and recommended private/public submodules
- `second_pass: needs_human` when the split changes product behavior, public Interface, data model, auth/payment behavior, infrastructure, rollout risk, or ADR direction

Minimum module grill output:

- Module concept and name
- Interface callers should know
- Implementation complexity hidden behind the interface
- Real seams and hypothetical seams
- Current or planned adapters
- Tests that survive at the interface
- Migration, rollout, and rollback risks
- Vertical slice plan: first thin end-to-end behavior, layers touched, verification, and what horizontal work is explicitly deferred
- ADR or `CONTEXT.md` updates needed
- Recommended answers accepted by default
- Second-pass decision: `not_needed`, `run`, or `needs_human`

Side effects happen inline as decisions crystallize:

- **Naming a deepened module after a concept not in `CONTEXT.md`?** Add the term to `CONTEXT.md` using the same format discipline as `grill-with-docs`. Create the file lazily if it doesn't exist.
- **Sharpening a fuzzy term during the conversation?** Update `CONTEXT.md` right there.
- **User rejects the candidate with a load-bearing reason?** Offer an ADR, framed as: *"Want me to record this as an ADR so future architecture reviews don't re-suggest it?"* Only offer when the reason would actually be needed by a future explorer to avoid re-suggesting the same thing — skip ephemeral reasons ("not worth it right now") and self-evident ones. Use the ADR format from `grill-with-docs`.
- **Want to explore alternative interfaces for the deepened module?** See [INTERFACE-DESIGN.md](INTERFACE-DESIGN.md).
