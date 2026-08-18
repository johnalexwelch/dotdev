---
name: workflow-review
layer: judgment
model: opus
reasoning: high
description: Run an auditable independent review gate with a risk-sized review profile. Use before merging, after implementation, at any explicit review gate, or whenever the user asks to review changes; green CI, GitHub reviews, Claude Code Review, and PR comments do not substitute for this workflow.
---

# Workflow Review

## Purpose

Run an independent review sized to the change's risk, then synthesize findings into a prioritized verdict. This replaces ad-hoc "review this" with an auditable gate, without forcing every small change through a full council. A valid review needs a *fresh independent reviewer context* — the author approving their own work, green CI, GitHub/Claude/Bugbot/Codex reviews, or resolved PR comments do **not** satisfy it unless this skill is loaded, reviewer lanes are dispatched, and a synthesis verdict is produced.

If a workflow says `workflow-review`, run this skill before proceeding to finalize/PR/CI/merge/handoff. For code changes the review must run against a branch/worktree cut from the resolved workflow base recorded in `WORKFLOW_BASE_GATE` (or a valid stacked worktree) — the kernel re-verifies the worktree at stamp time. Without that baseline evidence, return `NEEDS_HUMAN` rather than reviewing a local-main diff.

## The seam — judgment here, gate in the orchestrator (D-006 #12)

This skill is `layer: judgment`: it produces the review — dispatched lane files plus a synthesis verdict — and never writes the gate. The invoking orchestrator (workflow-deliver, execute-prd, a batch driver) records the gate with the kernel's review stamp (contract: `workflow-ledger/SKILL.md`), which re-verifies the worktree, checks the chosen profile against the computed floor, and ingests the lane files. This skill's output is that stamp's input; a review whose lane files cannot survive the stamp's checks did not happen.

## Workflow Progress Reporting

Follow the step-ledger reporting protocol in `workflow-ledger/SKILL.md`: the invoking run's `review` step is recorded durably via `ledger.sh set`; the table below tracks this skill's internal progress in-conversation, emitted at run start, on every transition, and in every halt/handoff/completion.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| Step 0: Prepare Context | required | pending | - |
| Step 1: Select Review Profile | required | pending | - |
| Step 2: Dispatch Independent Review | required | pending | - |
| Step 3: Synthesize Findings | required | pending | - |
| Step 4: Emit Verdict | required | pending | - |
```

Never mark a required review step skipped. If independent context is unavailable, mark Step 2 `blocked` and return `verdict: NEEDS_HUMAN`.

## Profile selection — the floor is computed, escalation is judgment

Run `ledger.sh review-floor` (kernel; Load `workflow-ledger/SKILL.md` for the contract). It prints `fast|standard|full` — the minimum profile, computed deterministically from diff stats and per-repo path patterns (`docs/executions/review-patterns.txt` when present). Escalate above the floor when judgment sees risk the diff stats cannot — concurrency, public-API semantics, subtle state machines, security-adjacent logic under paths the patterns miss. Never run below the floor: the orchestrator's stamp refuses a chosen profile below the computed value, so an under-sized review is unrecordable, not merely discouraged. Do not escalate by reflex either — an unjustified `full` dispatches ~13 reviewer subagents for no added safety.

| Profile | Required lanes (stamp-verified) | Judgment additions |
|---------|--------------------------------|--------------------|
| `fast` | one fresh **Integrated Reviewer** (security+logic+tests+style+acceptance checklist) | — |
| `standard` | **Logic & Edge-Case** + **TDD/Test Coverage** | **Security** for auth/secrets/permissions/user-data/dep/injection surfaces; **Syntax/Style** when no linter ran |
| `full` | Security, Logic, Tests, Syntax/Style | triggered conditional lanes from the roster |

The full lane roster and subagent mapping live in `references/reviewer-roster.md` — load it when you need the catalog or are running `full`.

## Lane-file contract (what the stamp ingests)

The canonical lane keys are exactly what the kernel requires per profile: `integrated` (fast), `logic`, `tests` (standard), plus `security`, `style` (full) — a lane file under any other key fails the stamp's existence check. Each dispatched lane writes its full review to a **run-scoped** path (e.g. `/tmp/<run_id>-<lane>-review.md`), which the orchestrator maps via the stamp's `--attest lanes=<lane>=<path>,...`; the kernel's bare default `/tmp/<lane>-review.md` is a cross-run bleed risk — a stale approve from an unrelated review at that path satisfies every check the stamp makes, so never rely on it. Every lane file must begin with `model:` (or `model_used:`), `verdict:` (underscored tokens: `APPROVE|REQUEST_CHANGES|NEEDS_HUMAN`), and `reviewed_sha: <HEAD>` lines per the Shared Output Contract in `references/reviewer-briefs.md`; the stamp verifies existence, verdict, and model floor and records per-lane sha256/line-count/verdict/model digests, and the orchestrator must confirm each lane's `reviewed_sha` matches HEAD before stamping (the kernel does not bind lane files to the diff — that check is the orchestrator's). Reviewer prompts must therefore default to "write your full review to the lane file and return only a one-line confirmation + verdict" — full inline returns routinely get mangled by output wrappers, forcing a re-run. Synthesize by reading the files, not the chat return.

Dispatch reviewer lanes on **Opus** (`model: opus`) — review is judgment work where the strongest model pays off; the `fast` integrated reviewer may use Sonnet. The kernel's model floor derives from the **computed** floor (fast → sonnet, standard/full → opus), not the chosen profile — so when you escalate the profile above a `fast` floor, the orchestrator must attest a raised `model_floor` at stamp time, or a Sonnet-dispatched escalated review stamps clean. The primary control is pinning `model` at dispatch; the lane file's model line is the diagnostic record.

## Dispatch — independent context required

Use a fresh independent reviewer context, not an author-only checklist. Read the brief index `references/reviewer-briefs.md`, then read only the per-lane templates (`references/reviewer-briefs/<lane>.md`) for the *active* lanes; don't improvise prompts unless a template is missing (if an active lane's template is missing, halt `NEEDS_HUMAN` — the review wouldn't be reproducible). Prefer subagents, launched in one parallel batch. If the environment can't provide a fresh independent reviewer context, halt `NEEDS_HUMAN` — do not silently downgrade to author-only review.

Lane independence for `standard`/`full` requires genuinely separate dispatched subagent calls, one per required lane. A single continuous reasoning pass covering multiple lanes' checklists satisfies `fast` only, even when run in a fresh context. If dispatch is unavailable and the floor (or your escalation) calls for `standard`/`full`: halt `NEEDS_HUMAN` (reason: `dispatch_unavailable_for_required_profile`). Do not self-downgrade to `fast` silently — downgrading below the floor is a human decision; present the option and require an explicit user waiver before treating fast-tier evidence as sufficient.

## Process

1. **Prepare context.** Gather the diff (staged/committed/PR), list changed files and types, run `ledger.sh review-floor`, pick the `review_profile` (≥ floor), record skipped conditional lanes with concrete reasons, and load the active per-lane templates. If a review round runs long or spans multiple sessions, `git fetch origin --prune` and re-diff against the workflow base before synthesizing — a stale base makes lanes review a diff that no longer matches HEAD, and neither `review-floor` nor the stamp fetches for you. Prepare placeholders: `<diff_summary>`, `<diff>`, `<changed_files>`, `<context>`, `<acceptance_criteria>`, `<verification>`. **Graphify knowledge graph gate (conditional, for reviewer context):** if `graphify-out/graph.json` exists, note its availability to reviewers as an optional resource and record `graphify: available_for_reviewer_context`; else record `graphify: not_available_with_reason`. Do not rebuild the graph. Print the step ledger.
2. **Dispatch reviewers** in fresh independent contexts using their per-lane templates. Each gets the diff + relevant file contents + CONTEXT.md if present, and returns findings with severity and confidence. If any required lane for the profile doesn't return, the verdict is `NEEDS_HUMAN`.
3. **Synthesize.** Merge and dedupe findings into: a **Dispatch evidence** table (lane | subagent | status | summary), then **Must-fix (blocks merge)**, **Should-fix (follow-up)**, **Acceptable risks**, and **Human gate required**.
4. **Verdict.** `APPROVE` (no must-fix, and all required lanes returned), `REQUEST_CHANGES` (has must-fix), or `NEEDS_HUMAN` (blocking human-gate items). The synthesis must end with the return block below.

## Synthesis return block

This block is the attestation payload the orchestrator feeds to the kernel's review stamp — the durable gate is the stamp record, and this markdown is its input, not a substitute for it:

```markdown
WORKFLOW_REVIEW_GATE:
  review_profile: fast|standard|full
  computed_floor: <output of ledger.sh review-floor>
  independent_review: true
  lanes: <lane>=<path> for every dispatched lane
  conditional_lanes: <dispatched/skipped-with-reason list>
  dispatch_evidence: <concrete evidence per lane: subagent id/tool-call, files actually read, exact command output (e.g. real test-pass counts) — vague language is treated as unverified>
  verdict: APPROVE|REQUEST_CHANGES|NEEDS_HUMAN
```

If the block is absent, incomplete, or says anything other than `verdict: APPROVE`, the orchestrator must treat the review as not run — and the stamp's checks refuse to record it regardless.

## Rules

Only report findings the author would agree need fixing. No style nits unless they hurt readability. Only findings with >70% confidence. If a finding contradicts an ADR, the ADR wins (note it, don't flag). Never claim "review complete" without independent evidence for each required lane; never substitute the author's own reasoning, CI, tests, or external bot reviews for the dispatch-and-synthesis gate.

## Contract

Consumes: diff/changeset, file contents, CONTEXT.md, ADRs
Produces: per-lane review files (`/tmp/<lane>-review.md`) and a review synthesis with verdict — the inputs to the invoking orchestrator's review stamp
Requires: git; `ledger.sh` (workflow-ledger kernel) for `review-floor`
Side effects: writes lane review files to /tmp
Human gates: `NEEDS_HUMAN` halts until a human responds. If subagents are unavailable, use only a host-provided fresh independent reviewer context; otherwise halt `NEEDS_HUMAN`.
