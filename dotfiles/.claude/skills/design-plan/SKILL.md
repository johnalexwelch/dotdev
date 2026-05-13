---
name: design-plan
description: Turn a repo-audit report (refactor scale) or a free-form brief (bug/feature scale) into an executable plan. Reads either the most recent audit (audit-mode, FIND-NN anchored) or a brief — inline text, file path, or URL (brief-mode, REQ-NN or ticket-slug anchored) — asks for target outcome and constraints, and writes a plan that tags every task with a delegation marker ([auto] or [human]), includes a pilot/canary phase when scope warrants it, and specifies per-phase rollback. Phase count flexes with scope (1 for bugs, 2-3 for small features, 4-6 for refactors). Supports revision mode for updating an existing plan mid-execution.
triggers:
  - "write a design doc"
  - "create a refactor plan"
  - "turn this audit into a plan"
  - "revise the plan"
  - "/design-plan"
persona: Staff Engineer writing a plan a fresh contributor could execute
inputs:
  - name: mode
    type: string
    default: "draft"
    description: '"draft" to create a new plan from an audit or brief. "revise" to update an existing plan with execution results, blocked phases, or new findings.'
  - name: audit_path
    type: string
    default: ""
    description: Path to a repo-audit report. If empty AND `brief` is empty, use the newest file matching `docs/audits/*-repo-audit.md`. Mutually exclusive with `brief`.
  - name: brief
    type: string
    default: ""
    description: Free-form brief for bug/feature/investigation scale work — inline string, `@path/to/file`, or URL. Mutually exclusive with `audit_path`. When set, plan is brief-mode (no audit required); §5 Addresses lines anchor on `REQ-NN` (auto-numbered from the brief) or ticket slugs found in the brief. Phase count flexes with scope.
  - name: existing_plan
    type: string
    default: ""
    description: Path to existing plan. Required if mode=revise. Defaults to newest `docs/plans/*.md` if empty.
  - name: outcome
    type: string
    default: ""
    description: One sentence describing the target state ("ship a working X by Y"). If empty, ask the user before drafting. In revise mode, used to clarify any outcome drift.
  - name: constraints
    type: string
    default: ""
    description: Free-text constraints — solo vs. team, calendar deadlines, API budgets, production risk tolerance.
  - name: output_path
    type: string
    default: "docs/plans/<date>[-<slug>]-design.md"
    description: Where to write the plan. Default puts plans in `docs/plans/`. Slug is derived (in priority order) from a ticket ID in the brief, kebab-case of the brief's first sentence (≤30 chars), or the audit's `path-slug` if audit-mode. Slug is omitted if none derivable (backward compat with existing `<date>-design.md` plans). Override to `DESIGN_DOC.md` at repo root only if the project explicitly expects it there.
reads:
  - docs/audits/<date>-repo-audit.md (newest unless audit_path is set; skipped in brief-mode)
  - docs/plans/<prior>.md (if mode=revise)
  - <brief content> (if brief is a file path or URL)
  - README.md, CLAUDE.md, any *_SPEC.md at repo root
writes:
  - docs/plans/<date>[-<slug>]-design.md (or override via output_path)
---

## Contract

Consumes: repo audit report (docs/audits/) or free-form brief (inline text, file path, or URL), target outcome, constraints
Produces: phased execution plan (docs/plans/)
Requires: git
Side effects: writes plan file to docs/plans/
Human gates: plan review before execution; outcome and constraints questions asked if not provided

## Context

Typical workflows: audit-loop (after /repo-audit, before /execute-phase), brief-mode (standalone entrypoint for bugs/features)
Pairs well with: repo-audit, execute-phase, grill-with-docs

# /design-plan — Turn an Audit Into an Executable Plan

## Purpose

A `/repo-audit` report tells you what's wrong, with stable `FIND-NN`
IDs. This skill turns that into a plan a contributor could execute:
ordered phases with delegation markers, a pilot/canary phase before
riskier work, per-phase rollback, a delete list, a sync gate, and a
definition of done. Runs in `draft` mode (new plan) or `revise` mode
(update an existing plan mid-execution).

## Step 0: Preflight

- Confirm you are in a git repo. If not, abort.
- **Resolve the input source.** `audit_path` and `brief` are mutually
  exclusive. Resolution order:
  1. If `audit_path` is set: **audit-mode**. Load it. Anchor §5
     Addresses on `FIND-NN`.
  2. Else if `brief` is set: **brief-mode**. Resolve the brief as
     follows — if it starts with `@`, treat the rest as a file path
     and read it; if it parses as a URL, fetch it via best-effort
     (fall back to prompting if fetch fails); otherwise treat as
     inline text. Anchor §5 Addresses on `REQ-NN` (auto-number from
     the brief content) or any ticket slugs found in the brief
     (`JIRA-123`, `#456`, `ENG-789`, etc.) — keep them verbatim.
  3. Else look for the newest `docs/audits/*-repo-audit.md` and use
     it as `audit_path` (audit-mode).
  4. Else stop and ask the user: run `/repo-audit` first, or
     re-invoke with `brief="..."` for bug/feature work.
- Branch on `mode`:
  - **draft**: input source resolved above. In brief-mode, no audit
    is required.
  - **revise**: locate both the existing plan and (if audit-mode)
    the audit it was based on. If `existing_plan` is set, use it;
    else newest `docs/plans/*.md`. If no plan exists, stop and
    suggest `draft` mode.
- Verify input has stable IDs:
  - audit-mode: check for `FIND-NN`. If absent (older audit format),
    note the limitation — cross-references will be position-based.
  - brief-mode: scan for ticket slugs; if none found, auto-number as
    `REQ-01`, `REQ-02`, … one per distinct deliverable surfaced in
    the brief.
- **Derive the output slug.** Priority order: (a) ticket ID in brief
  (lowercased, e.g. `JIRA-123` → `jira-123`); (b) kebab-case of
  brief's first sentence, ≤30 chars, punctuation stripped; (c)
  audit's `path-slug` if audit-mode and audit is scoped; (d) empty
  (filename falls back to `<date>-design.md`). Set `output_path`
  accordingly if the user didn't override it.
- In draft mode: check for an existing plan at `output_path`. If one
  exists and is not empty, ask whether to overwrite, date-suffix, or
  abort. Default is date-suffix (`<original>-v2.md`).
- Ensure `docs/plans/` exists (`mkdir -p`).
- Read `README.md`, `CLAUDE.md`, and any `*_SPEC.md` at repo root to
  pick up conventions.
- Ask the user up to two questions, batched:
  - If `outcome` empty: *"In one sentence: what does 'done' look
    like — what are you trying to ship, and by when if relevant?"*
  - If `constraints` empty: *"Any constraints I should know? Solo
    or team, deadlines, things that can't break, budget for API
    calls, rollback tolerance, etc."*

Do not ask more than these. If the user says "you pick," infer from
the audit/brief and proceed.

## Step 1: Frame

**In draft mode (audit-mode)**, open the audit and extract:

- **Overall state** — one-paragraph honest read.
- **Findings (FIND-NN)** — the full list with severities. This drives
  task-to-finding cross-references in the plan.
- **Top three** — the critical items the plan must address first.
- **Biggest gaps and risks** — shapes rollback planning.
- **Implementation patterns** — the best-built piece, which new work
  should mirror.
- **Recommended next steps** — raw ordered backlog to turn into
  phases.

**In draft mode (brief-mode)**, parse the brief and extract:

- **What's being asked** — drop into §2 Problem verbatim (with light
  formatting — preserve the user's phrasing).
- **Distinct deliverables** — auto-number as `REQ-01`, `REQ-02`, … if
  no ticket slugs are present. Each becomes a candidate for a phase's
  Addresses line. Trivial bugs collapse into a single REQ.
- **Ticket references** — any `JIRA-123`-style or `#456`-style slugs
  in the brief. Keep verbatim; they go in §5 Addresses alongside or
  instead of `REQ-NN`.
- **Implicit scope hints** — words like "fix," "bug," "broken,"
  "regression" point to bug-scale work (1 phase). "Add," "implement,"
  "support" point to feature-scale (2–3 phases). These hints feed the
  adaptive phase count rule in Step 2.

**In revise mode**, additionally gather:

- The existing plan's phases, delete list, and definition of done.
- Git log since the plan was written: `git log --oneline
  <plan-commit>..HEAD` — to see what was actually done.
- Which phase branches exist: `git branch -a | grep -E '(refactor|fix|feat)/phase-'`.
- Current test status: run the test command; note pass/fail.
- Any new audit findings discovered since the plan (re-run
  `/repo-audit` if the existing audit is >14 days old, or note
  staleness).

Keep this in working memory.

## Step 2: Draft (or revise)

**Draft mode** writes a new plan in one pass, following the template
in Step 3. Work through sections in order, because later sections
depend on earlier ones:

1. §4 Current state — compressed from audit.
2. §3 Goals and non-goals — from `outcome`.
3. §5 Execution plan:
   - §5.0 Phase 0 — Preflight (always, except for trivial bug-scale
     plans where preflight collapses into Phase 1).
   - §5.1 Phase 1 — **Pilot/Canary**. Smallest-possible change that
     validates the approach end-to-end against real data. Not
     optional for refactor-scale work unless the user explicitly
     waives it in `constraints` ("greenfield, no canary needed").
     Canary comes before any deletion phase. **For brief-mode bug
     fixes, the pilot rule collapses — the fix itself is the
     pilot.**
   - §5.2 onwards — substantive phases. **Phase count flexes with
     scope.** A trivial bug fix is one phase total (fix + verify) —
     pilot/canary collapses into the fix. A small feature is 2–3
     phases (pilot slice + 1–2 follow-ups). A refactor is 4–6
     phases. Don't pad a bug-fix plan with ceremonial phases; don't
     compress a refactor below 4. Every phase still delivers a
     working vertical.
   - Final phase — cleanup + docs catch-up. (Skip for bug-scale work
     where docs/cleanup live inside the single fix phase.)
   - **Vertical slicing.** Prefer end-to-end slices over
     layer-by-layer phases. Phase 2 should not be "backend only"
     and Phase 3 "frontend only" — each phase should deliver a
     working vertical of the target system. The pilot is the first
     vertical; subsequent phases add features to it.
4. Each phase must include:
   - **Goal** (one sentence)
   - **Tasks** (concrete, each tagged `[auto]` or `[human]`)
   - **Addresses** (which IDs this phase resolves — `FIND-NN` in
     audit-mode, `REQ-NN` or ticket slugs in brief-mode, or `n/a`
     for hygiene phases)
   - **Verification** (how you know the phase is done — falsifiable)
   - **Rollback** (if this phase fails or is backed out, what's the
     recovery path — revert commit, disable feature flag, restore
     from backup, re-enable old code path)
   - **Deletes** (files removed, or "none")
5. §8 Delete list — every file to delete, grouped by the phase that
   removes it. No file is deleted before its replacement is live and
   verified.
6. §7 Architecture rules — invariants.
7. §6 Authoring standard — only if artifact types have a house
   style.
8. §9 Open questions — deferred decisions with owner.
9. §10 Definition of done — binary checklist, each item falsifiable
   in <60s.
10. §11 Sync-gate mechanics — branch naming, PR policy,
    main-clean-before-next-phase rule.

**Delegation markers.** Every task in §5 carries one of:

- `[auto]` — Claude Code can do this autonomously without your
  input. File moves, renames, scoped refactors, test writing,
  deletions from the delete list.
- `[human]` — requires your judgment and should not be executed
  without confirmation. Calendar/commitment decisions, scope
  changes, anything with financial impact, interactions with other
  people, anything touching the escalation triggers in CLAUDE.md.

If a task is mixed, split it. No task should be half-auto,
half-human.

**Revise mode** produces a revision, not a rewrite:

**Verify before accepting revisions.** When the user reports a phase
drifted or a task should change, treat the claim as a hypothesis.
Spot-check against git (`git log`, `git branch`) and the working tree
before rewriting. If the claim doesn't reproduce, surface the
discrepancy rather than silently accepting — mirrors the
evidence-validation pass in `/repo-audit` Step 3.

- Preserve the original phase numbering and structure.
- For each phase, annotate:
  - **Status:** `done` | `in-progress` | `blocked` | `not-started`
    | `removed` | `added`
  - **Actual vs. planned** — one line if drift occurred
  - **Revised tasks** — only change what needs changing
- Add a `## §12 Revision log` at the bottom with date, reason for
  revision, and what changed.
- Do not renumber findings or phases. Stable IDs matter more than
  clean numbering.

## Step 3: Template

Write the file to `output_path` using this structure.

```
# Design Plan — <repo or effort name>
**Date:** <YYYY-MM-DD>
**Audit:** <relative path to audit report>
**Mode:** draft | revise v<N>

## §0 For Claude Code — read this first
<Short pointer block: where to start (Phase 0), how the sync gate works,
where the audit lives for cross-reference, what [auto] vs [human] tags
mean, any non-obvious context.>

## §1 Purpose
<One paragraph. What this document is, who it's for, what it supersedes.>

## §2 Problem
<Two or three paragraphs. What's wrong today, drawn from audit Overall
state + Top three. Name the pain concretely and reference FIND-NN IDs.>

## §3 Goals and non-goals
**Goals**
- <Bullet, each tied to a measurable outcome>

**Non-goals**
- <Bullet, each a scope-bound statement>

## §4 Current state
<Compressed snapshot from the audit. File tree at the level that matters.
Load-bearing files. Known-fragile areas with audit evidence cited by
FIND-NN.>

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
   "Implementation patterns" section>
2. [human] Verify the canary's output matches expectations.
**Addresses:** <which FIND-NN the canary proves-out the fix for>
**Verification:** <observable signal that the approach works>
**Rollback:** Revert the canary commit; main returns to pre-pilot state.
**Deletes:** none.

### §5.2 Phase 2 — <name>
**Goal:** <one sentence>
**Tasks:**
1. [auto] <concrete step with file path>
2. [human] <decision point>
...
**Addresses:** FIND-NN, FIND-NN
**Verification:** <falsifiable check>
**Rollback:** <specific recovery path — revert commit, feature flag
off, restore old code path, etc.>
**Deletes:** <files removed in this phase, or "none">

<Repeat. 3–6 substantive phases total after the pilot. End with a
"cleanup + docs" phase.>

## §6 Authoring standard
<Only if the project has skills/agents/other artifact types with a
house style. Otherwise omit this section.>

## §7 Architecture rules
<Invariants. File-size limits, module boundaries, naming, no-circular-
import rules, etc.>

## §8 Delete list
<Every file slated for deletion, grouped by phase. For each: why, and
what replaces it (or "no replacement — dead code"). No file is deleted
before the phase that replaces it is verified.>

## §9 Open questions
<Decisions deferred. Each item: the question, why deferred, who
decides (user | Claude Code | defer until Phase N).>

## §10 Definition of done
<Binary checklist. Each item falsifiable in <60 seconds. Include:
- Every FIND-NN from the audit is either addressed or explicitly
  deferred to a future plan.
- All [auto] tasks completed.
- All [human] decisions made.>

## §11 Sync-gate mechanics
<How phases interleave with git. Branch naming (`refactor/phase-N-<slug>`),
PR policy, "main clean before next phase" rule, what happens if a phase
fails midway.>

## §12 Revision log
<Only present in revise mode. One line per revision: date, reason,
summary of changes.>
```

## Step 4: Self-review

Before finishing, read the draft against this checklist. Fix anything
that fails.

- Does every task in §5 have either `[auto]` or `[human]`?
- Does every phase have both Verification and Rollback?
- Is Phase 1 a Pilot/Canary (or is there an explicit waiver in §1, or
  is this a brief-mode bug-fix plan where the fix itself is the pilot)?
- Does every phase in §5 deliver a working vertical, or is the plan
  sliced by layer? If layer-sliced, flag and re-order unless the
  user waived this in constraints.
- Is the phase count appropriate for scope? 1 for bugs, 2–3 for small
  features, 4–6 for refactors. No ceremonial padding on small work; no
  compression on large work that hides multiple verticals in one phase.
- Does every phase's "Addresses" list reference specific IDs from the
  audit (`FIND-NN`) or brief (`REQ-NN`, ticket slugs), or note
  "hygiene" / `n/a` for Phase 0?
- Does §8 Delete list account for every file flagged as "legacy" or
  "superseded" in the audit?
- Does §10 Definition of done include the "every FIND-NN addressed or
  deferred" check?
- In revise mode, does §12 exist and reflect what actually changed?
- Are there "TODO" or "figure out later" placeholders in the body? If
  yes, move them to §9 Open questions with an owner.

## Step 5: Surface

After writing the file, present to the user in chat:

- One-sentence summary ("5 phases, pilot validates X, deletes 4,200
  lines, resolves FIND-01 through FIND-09").
- Phase names in order, with `[auto]`/`[human]` ratio per phase
  (e.g. "Phase 2 — Skill scaffolding (6 auto, 1 human)").
- Any `§9 Open questions` that need your input before Phase 1.
- Pointer: `See docs/plans/<date>-design.md`.

Do not repeat the full plan inline.

## Output Format

Standard markdown at `output_path` (default
`docs/plans/<date>[-<slug>]-design.md` — slug present in brief-mode
or for scoped audits, omitted otherwise). In revise mode, the file
may be at the original plan's path with §12 appended.

## Error Handling

| Failure | Behavior |
|---------|----------|
| Not in a git repo | Abort. |
| No audit found AND no brief set (draft mode) | Stop. Tell user to run `/repo-audit` first OR re-invoke with `brief="..."`. Do not attempt to audit inline. |
| Both `audit_path` and `brief` set | Abort. They're mutually exclusive — pick one. |
| `brief` is a file path (`@...`) and the file is missing | Abort with the path that was tried. |
| `brief` is a URL and fetch fails | Prompt the user to paste the brief contents inline. Do not silently fall back. |
| revise mode with no existing plan | Abort. Suggest draft mode. |
| Audit lacks FIND-NN IDs (older format) | Proceed but note in §2 that cross-references are position-based. Recommend re-running `/repo-audit` for full traceability. |
| Brief has no ticket slugs and no extractable deliverables | Auto-number a single `REQ-01` for the entire scope; surface the assumption in §2. |
| `outcome` and `constraints` both empty and user unresponsive | Infer outcome from audit's top recommended step (audit-mode) or the brief's stated intent (brief-mode); note the inference in §1. |
| Existing plan at output_path (draft mode) | Ask: overwrite, date-suffix, or abort. Default date-suffix. |
| Audit older than 14 days | Warn at top of §4. Recommend re-running `/repo-audit` before executing. |
| Phase count > 6 (refactor) or > 3 (small feature) or > 1 (bug) | Force a merge or defer. Right-size the plan to scope. |
| No canary possible (truly atomic change) | Require explicit waiver in §1 with reasoning. Do not silently skip. |

## Example Invocation

```
User: /design-plan
Claude: [preflight — finds docs/audits/2026-04-20-repo-audit.md with
         FIND-01 through FIND-14]
        [asks: what does done look like? what are your constraints?]
User: Ship a working refactor that kills the legacy scripts and moves
      memory to Obsidian. Solo dev, no hard deadline, tests must stay
      green every commit.
Claude: [drafts plan, self-reviews]
        [writes docs/plans/2026-04-20-design.md]

        6-phase plan. Pilot validates one workflow end-to-end before
        legacy deletion. Deletes 3,946 lines. Resolves FIND-01 through
        FIND-09 and FIND-13.

        Phases:
          §5.0 Phase 0 — Preflight (4 auto, 1 human)
          §5.1 Phase 1 — Pilot: /morning slash command (5 auto, 2 human)
          §5.2 Phase 2 — Skill scaffolding (/prep, /triage) (8 auto, 1 human)
          §5.3 Phase 3 — Replace legacy scripts (6 auto, 0 human)
          §5.4 Phase 4 — Integration consolidation (7 auto, 1 human)
          §5.5 Phase 5 — Memory → Obsidian split (4 auto, 2 human)
          §5.6 Phase 6 — Docs + test catch-up (3 auto, 0 human)

        Two §9 open questions need your call before Phase 1:
          - Which memory files go to Obsidian vs. stay in repo?
          - Keep launchd or move to a simpler scheduler?

        Full plan: docs/plans/2026-04-20-design.md
```

Revise example:

```
User: /design-plan mode=revise
Claude: [finds docs/plans/2026-04-20-design.md; finds phase branches
         refactor/phase-0-*, refactor/phase-1-*, refactor/phase-2-*
         merged; phase-3 branch exists but open]
        [test status: green]
        [annotates: Phase 0, 1, 2 done; Phase 3 in-progress;
         Phase 4-6 not-started]
        [§12 Revision log: Phase 3 scope expanded to include
         OAuth-refactor after FIND-05 was found more invasive
         than expected]
```

## Iteration Mode

When invoked with "iterate" or on an existing plan:

1. Read the existing plan file first
2. Identify what has changed (new requirements, execution feedback, post-mortem findings)
3. Produce a DIFF of changes rather than regenerating from scratch
4. Preserve phase numbering and completed phases
5. Mark changed sections clearly

This prevents first-draft bias where a skill always starts from scratch. The iterate path is triggered when:

- User says "update the plan" or "iterate on the plan"
- A post-mortem references plan gaps
- Execution feedback suggests plan revision
- The plan file already exists and the user invokes design-plan again

## Tuning notes

- If the audit's "Biggest gaps and risks" names more than three
  distinct fragility areas: bias toward more phases (smaller batches,
  more sync gates).
- For production systems with live users: rollback sections should
  name the exact commit/flag/toggle, not a generic "revert." Verify
  the rollback path before the phase starts.
- For solo projects: sync gate can be lighter — direct commits to
  main fine as long as tests pass. For teams: require PRs with
  review.
- For greenfield work: no §8 Delete list, rename §5 to "Build plan."
  Pilot phase is still required.
- For tasks where `[auto]` vs `[human]` is ambiguous: default to
  `[human]` and let the user downgrade to `[auto]` on review. Safer
  bias.
- If the user heavily edits the first draft, don't regenerate — apply
  the edits and keep the rest. A plan the user has touched is more
  valuable than a plan that's optimally structured.
- The plan feeds into `/execute-phase` (runs each phase's `[auto]`
  tasks under scope-based subagent isolation, commits with
  Addresses IDs echoed verbatim — `FIND-NN` / `REQ-NN` / ticket
  slugs all work), `/review` (workspace reviewer subagent, in-loop),
  `/post-mortem` (writes the retro that `/describe-pr` then cites),
  `/describe-pr` (reads plan + `.phase-runs/` outcome files +
  post-mortem to produce deviation-aware PR bodies), `/watch-ci`
  (post-PR-open: polls CI, applies bounded auto-fixes, runs
  `/security-review` plus `/review` on auto-fix diff if any, posts
  approve when clean), and on-demand `/setup-worktree` (isolated
  checkout for resolving `[human]` gates in parallel with main-branch
  work). The plan's §5 phase headers, `[auto]/[human]` tags,
  Addresses IDs, and Verification text are load-bearing for all of
  them — write them as machine-consumable contracts, not just prose.

- **Brief-mode examples.** Bug: `/design-plan brief="fix mobile
  scroll on /profile page"` produces a 1-phase plan with `REQ-01`
  in §5 Addresses and filename `<date>-fix-mobile-scroll-on-profile-page-design.md`.
  Small feature: `/design-plan brief="add dark-mode toggle to
  settings"` produces a 2–3 phase plan. Brief from a ticket:
  `/design-plan brief="@docs/tickets/JIRA-123.md"` reads the file,
  extracts `JIRA-123` as the anchor slug, and uses it as the §5
  Addresses reference. Brief from a URL:
  `/design-plan brief="https://linear.app/.../issue/ENG-456"`
  fetches and extracts `ENG-456`.

## Pairing with the core loop

```
/repo-audit     →  docs/audits/<date>-repo-audit.md            (FIND-NN; optional —
     ↓                                                          brief-mode skips this)
/design-plan    →  docs/plans/<date>[-<slug>]-design.md        (this skill;
     ↓                                                          audit-mode OR brief-mode)
/execute-phase  →  docs/executions/.phase-runs/*.md +          (scoped subagents,
     ↓             {refactor,fix,feat}/phase-<N>-<slug>          stacked branches,
                                                                 FIND/REQ/ticket-citing commits)
/review         →  inline reviewer comments (workspace)        (in-loop, fresh subagent)
     ↓
/post-mortem    →  docs/executions/<date>-post-mortem.md       (NEW-NN, drift)
     ↓
/describe-pr    →  PR body / docs/executions/.pr-bodies/*.md   (cites NEW-NN from retro)
     ↓
[human gh pr create]
     ↓
/watch-ci       →  docs/executions/.ci-runs/*.md               (poll, classify, auto-fix,
                                                                 /security-review always,
                                                                 /review on auto-fix diff,
                                                                 approve when clean)
     ↓
[human merge]
```

Plus `/setup-worktree` as an on-demand side-car — used when
`/execute-phase` halts at a `[human]` gate and the user wants an
isolated checkout for resolution in parallel with continued work on
main.

All seven core skills share ID vocabulary (`FIND-NN`, `REQ-NN`,
`NEW-NN`, ticket slugs, phase numbers) and directory conventions
under `docs/audits/`, `docs/plans/`, and `docs/executions/`. A
post-mortem without a plan has nothing to compare against.
`/execute-phase` without a plan has nothing to execute. `/repo-audit`
is the refactor-scale entrypoint; brief-mode `/design-plan` is the
bug/feature entrypoint and skips the audit.
