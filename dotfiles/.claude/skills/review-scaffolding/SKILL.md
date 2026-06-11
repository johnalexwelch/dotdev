---
name: review-scaffolding
description: Foundational reference pattern for single-pass review skills. Loaded by sibling review skills such as clarity-review, pacing-review, sql-review, dashboard-review, metric-tree-review, dnd-review, dnd-open-thread-review, and dnd-player-agency-review. Never invoked directly.
user-invocable: false
disable-model-invocation: true
---

# Review Scaffolding (Foundation)

This skill is a **library**, not a workflow. Single-pass review skills (`clarity-review`, `pacing-review`, …) reference it for the shared report contract and review discipline. If you are invoking it directly, you probably want a specific `*-review` skill.

## Provenance

Extracted 2026-06-01 from the duplicated report shape + discipline restated in `clarity-review`, `pacing-review`, and their siblings — mirroring the `council-scaffolding` pattern. Note the asymmetry: councils share a *dispatch engine*; reviews share only this lighter *contract*. See `decision-log.md` (D-001).

## What a review is

A review is a **single-pass** assessment of one artifact against a domain's criteria, producing a prioritized, actionable report. One agent, one pass — this is **not** a fan-out (that's `council-scaffolding`, or a gate like `workflow-review` that dispatches lanes) and **not** incoming-feedback processing (that's `receive-review`).

A review skill is built from two parts:

1. **Criteria (the lens)** — domain-specific, lives in the `*-review` SKILL.md. The review's reason to exist.
2. **This scaffold** — the shared discipline, severity vocabulary, and report contract every review reuses.

## The review discipline (every review follows these)

- **Quote the locus.** Cite the exact offending text / unit / line — never an abstract worry.
- **Name the cost.** Explain what goes wrong for the *consumer* (reader, operator, player, downstream agent). Reviews exist because the artifact's cost lands on someone else.
- **Give a concrete fix**, not just a diagnosis — the actual replacement or a specific action. Use an obvious placeholder (`[5pm PT]`, `[+X% YoY]`) when a needed fact is missing.
- **Prioritize.** Lead with the few findings that most affect whether the consumer is misled or blocked. A focused review of the 5 that matter beats 20 trivial ones.
- **Say it's fine when it is.** If the artifact is strong, say so and keep it short — don't manufacture findings.
- **One locus can break several criteria** — pick the most useful framing rather than listing it N times.

## Severity vocabulary (shared)

Tag each finding `[HIGH]` / `[MED]` / `[LOW]` (matches `council-scaffolding`):

- **HIGH** — the consumer is misled, blocked, or the artifact fights itself.
- **MED** — real friction; the consumer has to work harder than necessary.
- **LOW** — polish; safe to defer.

Overall verdict is one of **ship / ship-with-fixes / needs-work / redesign**. Adapters may rename these to fit the domain (e.g. a pacing review's *well-curved / saggy / broken*) as long as the four-step gradient survives.

## The report contract (shared shape)

Markdown. Adapters may rename sections to fit the domain but keep the shape and order:

```markdown
# <Review type>: <artifact name>

**Scope / audience (assumed):** <one line — what this is, who/what consumes it>
**Overall:** <2-3 sentences: in good shape or needs work? the single biggest fix?>

## Findings   <!-- prioritized; numbered so the author can reference "#3" -->
### 1. <title> — [HIGH] <criterion it breaks>
> <exact quote / locus>

**Why it matters:** <consumer cost>
**Fix:** <concrete replacement or action>

### 2. …

## What's working
<1-3 things the artifact already does well, so the author keeps doing them>

## Confidence
<high | medium | low — and why (which signals were clearest)>
```

Group the smallest tweaks under a final **Minor** heading rather than numbering each.

## Optional mechanics (opt in per adapter)

- **Graph-first** — when the domain benefits, follow `graph-first/SKILL.md` and tag graph-sourced findings `[GRAPH]`. The adapter declares the insertion point.
- **Persistence** — write the report to `<domain>/audits/<slug>-<review>-<YYYY-MM-DD>.md` when the adapter opts in. Auto-`.gitignore` on first write.
- **Tracked-changes output** — when the adapter opts in, append a second deliverable *after* the findings report: the artifact reproduced with edits inline, `~~struck~~` for cuts and **bold** for insertions, plus a one-line-per-change table (`locus · was → now · finding #`). It is an *additional* view, never a replacement for the findings report, and never license to rewrite beyond what the numbered findings justify — every inline edit must trace to a finding. Reviews that don't propose text-level replacements (thread inventories, agency reviews) don't opt in.

## Adapter contract

Each `*-review` SKILL.md declares the following, then says *"follow `review-scaffolding` for discipline, severity, and the report contract; deltas below"*:

1. **Criteria / lens** — what this review checks (its standards). Required.
2. **Unit of analysis** — sentence/passage, scene/chapter, query, table, panel, thread, etc. Required.
3. **Persistence** — a path, or "none".
4. **Deltas** — any domain-specific process step (e.g. "identify the audience first") or report-section rename.

## Contract

Consumes: an artifact + the adapter's criteria
Produces: a prioritized markdown review report in the shared shape
Requires: nothing
Side effects: optional persisted report when the adapter opts in
Human gates: none — fire-and-read; the consumer picks what to act on

## Context

Typical workflows: invoked by sibling `*-review` skills, not by users directly
Pairs well with: graph-first, the specific `*-review` adapters, humanizer (on the report prose)
