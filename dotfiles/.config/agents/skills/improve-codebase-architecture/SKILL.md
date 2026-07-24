---
name: improve-codebase-architecture
model: opus
reasoning: high
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
Pairs well with: codebase-design, diagnose, repo-audit, grill-with-docs, design-plan, workflow-autonomous-backlog

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
- **Pin behavior before deepening.** A refactor that silently changes behavior is worse than the shallow module it replaced. No deepening becomes implementation work until current behavior is captured in a characterization test at the interface (the safety net the refactor runs against). If behavior can't be pinned through the current interface, that untestability *is* the finding — surface it, don't refactor blind.
- **A trust seam is not a shallow seam.** Validation, authorization, sanitization, and rate/quota checks look like pass-throughs to the deletion test but are load-bearing. Never collapse one into a deep module without preserving it as an explicit, testable seam.

This skill is *informed* by the project's domain model. The domain language gives names to good seams; ADRs record decisions the skill should not re-litigate.

## Process

### 1. Explore

Read the project's domain glossary and any ADRs in the area you're touching first. If `CONTEXT.md`, `LANGUAGE.md`, or `docs/adr/` is absent, say so in one line and proceed with code-derived vocabulary — state the fallback immediately rather than silently skipping, so the reader knows the analysis isn't grounded in a recorded domain model.

Then use the Agent tool with `subagent_type=Explore` to walk the codebase. Require the subagent to return **file:line references and verbatim snippets**, not prose conclusions — subagent summarization is a hallucination surface, and every candidate's evidence must trace to something you can reopen. Don't follow rigid heuristics — explore organically and note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow** — interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow: would deleting it concentrate complexity, or just move it? A "yes, concentrates" is the signal you want.

Ground each suspicion in a cheap signal so the eventual **Expected benefit** and **Cost of inaction** aren't guesses — record whichever apply per candidate:

- **Churn** — `git log --format= --name-only --since="6 months ago" | sort | uniq -c | sort -rn | head`. High-churn shallow modules are the highest-leverage deepenings; churn is also the decay signal for cost of inaction.
- **Call sites** — grep the module's exported names to count callers. Many callers repeating the same setup = leverage waiting to be captured; one caller = pass-through (fails deletion test).
- **Co-change coupling** — files that keep changing together (`git log --format= --name-only` grouped by commit) reveal a hidden seam that the module boundaries don't reflect.
- **Test reach** — note what can't be tested through the current interface; that gap is a concrete benefit line, not a vibe.

A candidate with no measurable signal is `Speculative` at best — say so.

### 2. Present candidates as an HTML report

Write a self-contained HTML file to the OS temp directory so nothing lands in the repo. Resolve the temp dir from `$TMPDIR`, falling back to `/tmp` (or `%TEMP%` on Windows), and write to `<tmpdir>/architecture-review-<timestamp>.html` so each run gets a fresh file. Open it for the user — `xdg-open <path>` on Linux, `open <path>` on macOS, `start <path>` on Windows — and tell them the absolute path.

The report uses **Tailwind via CDN** for layout and styling, and **Mermaid via CDN** for diagrams where a graph/flow/sequence reliably communicates the structure. Mix Mermaid with hand-crafted CSS/SVG visuals — use Mermaid when relationships are graph-shaped (call graphs, dependencies, sequences), and hand-built divs/SVG when you want something more editorial (mass diagrams, cross-sections, collapse animations). Each candidate gets a **before/after visualisation**. Be visual.

For each candidate, render a card with:

- **Files** — which files/modules are involved
- **Problem** — why the current architecture is causing friction
- **Solution** — plain English description of what would change
- **Wins** — the gains, in terms of locality and leverage, and how tests would improve
- **Expected benefit** — the concrete payoff if shipped: what it unblocks, the leverage/locality gained, backed by the evidence signal (e.g. "12 call sites stop repeating validation", "the file that changed 40× last quarter gets one place to change"). This is the *why now*.
- **Cost of inaction** — what keeps hurting if skipped, and whether it decays (coupling spreads, callers multiply) or just stays flat. A flat cost is a fine reason to defer.
- **Effort** — rough size (`S` / `M` / `L`, or a day-scale), so benefit reads against cost. Effort × benefit is what ranks the Top recommendation.
- **Vertical slice shape** — the narrow end-to-end behavior this candidate would enable or improve; if it only changes one layer, explain why it is not yet ready to become implementation work
- **Before / After diagram** — side-by-side, custom-drawn, illustrating the shallowness and the deepening
- **Recommendation strength** — one of `Strong`, `Worth exploring`, `Speculative`, rendered as a badge
- **Dependency category** — tag using the categories from [DEEPENING.md](DEEPENING.md) (`in-process`, `local-substitutable`, `ports & adapters`, `mock`), when the candidate crosses a seam
- **Risk flags** (only when they apply, rendered as red/amber chips) — `trust seam` if the deepening touches validation/authz/sanitization/rate-limiting (must survive as an explicit seam); `hot path` if it sits on a perf-sensitive path (measure before/after — a deepening must not regress latency/throughput; route an actual regression to `diagnose`); `unpinned behavior` if current behavior can't yet be captured in a characterization test.

End the report with a **Top recommendation** section: which candidate you'd tackle first and why — justified by effort × expected benefit, not by which is most interesting.

**Use CONTEXT.md vocabulary for the domain, and [LANGUAGE.md](LANGUAGE.md) vocabulary for the architecture.** If `CONTEXT.md` defines "Order," talk about "the Order intake module" — not "the FooBarHandler," and not "the Order service."

**ADR conflicts**: if a candidate contradicts an existing ADR, only surface it when the friction is real enough to warrant revisiting the ADR. Mark it clearly in the card as a warning callout (e.g. *"contradicts ADR-0007 — but worth reopening because…"*). Don't list every theoretical refactor an ADR forbids.

See [HTML-REPORT.md](HTML-REPORT.md) for the full HTML scaffold, diagram patterns, and styling guidance.

Do NOT propose interfaces yet. After the file is written, ask the user: "Which of these would you like to explore?"

#### Autonomous triage (when the user asks to run this unattended, or via `workflow-autonomous-backlog`)

Instead of stopping at the human question, triage the whole set with subagents:

- **`Strong` candidates** carry forward directly.
- **`Worth exploring` / `Speculative` candidates** — dispatch one read-only Explore subagent per candidate to test whether it should actually be actioned. Each returns a verdict backed by file:line evidence: `promote` (evidence upgrades it to actionable), `discard` (deletion test fails, or leverage/locality gain is illusory), or `needs-human` (touches product behavior, public interface, data model, auth/payment, infra, rollout risk, or ADR direction). No verdict without evidence — a candidate with no measurable signal is discarded, not promoted.
- Present the triaged set (promoted + discarded-with-reason). This classification maps directly onto `workflow-autonomous-backlog` Step 2 (`discard` / `needs-human` / `research-spike` / `module-prd-ready`).

**Then hand off, don't reinvent.** The grill-with-critic-consensus loop, PRD/issue creation, and the `workflow-build-one` → `workflow-review` → `workflow-finalize` → policy-gated merge chain are owned by `workflow-autonomous-backlog` (grill consensus is its Step 3.1: a read-only critic subagent, bounded rounds, halt at `NEEDS_HUMAN`). Route there rather than orchestrating it here. Merge authority is not granted by this skill — it comes from the repo's classification in `run-backlog/references/repo-delivery-policy.md` (`auto-merge-eligible` vs `human-only`); `workflow-finalize` still gates every merge on its own criteria.

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
- **Behavior pin**: the characterization test capturing current behavior at the interface, written and green *before* any deepening (gate — don't proceed without it, or record why it's impossible)
- **Trust seams touched** (validation/authz/sanitization/rate-limiting) and how each stays explicit and testable after deepening
- **Performance**: is this a hot path? If so, the before metric and the after budget it must not exceed; hand an actual regression to `diagnose`
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
