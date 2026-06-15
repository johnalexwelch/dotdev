# Design Plan Template

Use this structure for `output_path`.

```markdown
# Design Plan — <repo or effort name>
**Date:** <YYYY-MM-DD>
**Audit:** <relative path to audit report, "n/a (brief-mode)", or source URL/path>
**Mode:** draft | revise v<N>

## §0 For Claude Code — read this first
<Short pointer block: where to start (Phase 0), how the sync gate works,
where the audit or brief source lives for cross-reference, what [auto] vs
[human] tags mean, any non-obvious context.>

## §1 Purpose
<One paragraph. What this document is, who it's for, what it supersedes.
If a pilot/canary is explicitly waived, put the waiver and reasoning here.>

## §2 Problem
<Two or three paragraphs. In audit-mode, draw from audit Overall state +
Top three and cite FIND-NN IDs. In brief-mode, preserve the user's phrasing
with light formatting and cite REQ-NN or ticket slugs.>

## §3 Goals and non-goals
**Goals**
- <Bullet, each tied to a measurable outcome>

**Non-goals**
- <Bullet, each a scope-bound statement>

## §4 Current state
<Compressed snapshot from the audit or brief. File tree at the level that
matters. Load-bearing files. Known-fragile areas with evidence cited by
FIND-NN, REQ-NN, or ticket slugs. Warn here if the audit is older than 14
days.>

## §5 Execution plan

### §5.0 Phase 0 — Preflight
**Goal:** Baseline is clean.
**Tasks:**
1. [auto] Confirm working tree clean.
2. [auto] Sync with origin.
3. [auto] Clear stale lock files.
4. [auto] Run baseline tests; record results.
5. [human] Confirm .gitignore covers local-only files.
**Addresses:** n/a (hygiene, not a finding)
**Verification:** Tests pass on current main; no uncommitted files.
**Rollback:** n/a.
**Deletes:** none.

### §5.1 Phase 1 — Pilot (Canary)
**Goal:** Validate the approach with the smallest-possible change against
real data before committing to larger work.
**Tasks:**
1. [auto] <small, end-to-end slice — e.g. one workflow from audit's
   "Implementation patterns" section or one brief deliverable>
2. [human] Verify the canary's output matches expectations.
**Addresses:** <which FIND-NN, REQ-NN, or ticket slug the canary proves out>
**Verification:** <observable signal that the approach works>
**Rollback:** Revert the canary commit; main returns to pre-pilot state.
**Deletes:** none.

### §5.2 Phase 2 — <name>
**Goal:** <one sentence>
**Tasks:**
1. [auto] <concrete step with file path>
2. [human] <decision point>
...
**Addresses:** FIND-NN, REQ-NN, or ticket slug
**Verification:** <falsifiable check>
**Rollback:** <specific recovery path — revert commit, disable feature flag,
restore old code path, restore from backup, etc.>
**Deletes:** <files removed in this phase, or "none">

<Repeat using the phase-count rules. End refactor-scale and feature-scale
plans with cleanup + docs catch-up. For bug-scale work, keep docs/cleanup
inside the single fix phase.>

## §6 Authoring standard
<Only if the project has skills/agents/other artifact types with a house
style. Otherwise omit this section.>

## §7 Architecture rules
<Invariants. File-size limits, module boundaries, naming, no-circular-import
rules, etc.>

## §8 Delete list
<Every file slated for deletion, grouped by phase. For each: why, and what
replaces it (or "no replacement — dead code"). No file is deleted before
the phase that replaces it is verified.>

## §9 Open questions
<Decisions deferred. Each item: the question, why deferred, who decides
(user | Claude Code | defer until Phase N).>

## §10 Definition of done
<Binary checklist. Each item falsifiable in <60 seconds. Include:
- Every FIND-NN from the audit, REQ-NN from the brief, or ticket slug is
  either addressed or explicitly deferred to a future plan.
- All [auto] tasks completed.
- All [human] decisions made.>

## §11 Sync-gate mechanics
<How phases interleave with git. Branch naming (`refactor/phase-N-<slug>`,
`fix/phase-N-<slug>`, or `feat/phase-N-<slug>`), PR policy, "main clean
before next phase" rule, what happens if a phase fails midway.>

## §12 Revision log
<Only present in revise mode. One line per revision: date, reason, summary
of changes.>
```

## Surface Response Template

After writing the file, present only:

- One-sentence summary, e.g. "5 phases, pilot validates X, deletes 4,200 lines, resolves FIND-01 through FIND-09."
- Phase names in order, with `[auto]`/`[human]` ratio per phase.
- Any `§9 Open questions` that need input before Phase 1.
- Pointer: `See docs/plans/<date>[-<slug>]-design.md`.

Do not repeat the full plan inline.

## Output Path Rules

Default output is `docs/plans/<date>[-<slug>]-design.md`.

Derive slug in priority order:

1. Ticket ID in the brief, lowercased, e.g. `JIRA-123` -> `jira-123`.
2. Kebab-case of the brief's first sentence, <=30 chars, punctuation stripped.
3. Audit `path-slug` if audit-mode and the audit is scoped.
4. Empty slug, falling back to `<date>-design.md`.

Override to `DESIGN_DOC.md` at repo root only if the project explicitly expects it there.
