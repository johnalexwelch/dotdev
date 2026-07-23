# Session Reflection: Router Entry vs Mid-Chain Audit
**Date**: 2026-07-17
**Goal**: deeply classify every `workflow-router` classification-table target as ENTRY / CHAIN / DUAL / MICRO-PIPELINE, and flag dispatches that skip owning orchestrators.

## Method
For each router `Routes to` target:
1. Read that skill's When-to-invoke / Purpose / Flow / Contract.
2. Find parent skills that **strongly invoke** it (`Load and run`, Skill-tool invoke, or `## Flow` step).
3. Cross-check router Audit Loop Retirement Rule (`describe-pr` / `watch-ci` / `post-mortem` already banned as standalone defaults).
4. Note `disable-model-invocation: true` (slash-only; finalize-owned).

## Naming contract used
- **ENTRY**: router should dispatch here; this skill owns the run.
- **CHAIN**: mid-pipeline step; prefer parent orchestrator (direct dispatch skips gates).
- **DUAL**: legitimate standalone user ask *or* mid-chain; router OK only for the standalone signal; otherwise prefer parent.
- **MICRO-PIPELINE**: router row correctly describes a multi-step transition (not a single leaf).

---

## Verdict table (router classification targets)

| skill | router row today | verdict | primary parents | evidence | recommendation |
|-------|------------------|---------|-----------------|----------|----------------|
| `v1-workflow` | V1 | **ENTRY** | — | Router already forbids direct `v1-idea-grill` / `v1-system-design` | keep ENTRY |
| `workflow-feature` | ambiguous feature | **ENTRY** | — | Flow owns grill → roadmap → to-prd → to-issues → triage | keep ENTRY |
| `workflow-build-one` | ready issue | **ENTRY** | `run-backlog`, `workflow-autonomous-backlog` | Flow owns execute → review → finalize | keep ENTRY |
| `workflow-debug` | bug | **ENTRY** | `run-backlog`, `workflow-autonomous-backlog` | Flow owns diagnose → fix → review → finalize | keep ENTRY |
| `run-backlog` | AFK backlog | **ENTRY** | `workflow-autonomous-backlog` | Standalone AFK queue + also called by autonomous backlog | keep ENTRY (also DUAL parent) |
| `execute-prd` | PRD execution | **ENTRY** | — | Parent/dependent trees; router PRD-vs-backlog rule | keep ENTRY |
| `workflow-autonomous-backlog` | autonomous backlog | **ENTRY** | — | Full discover → grill → PRD → AFK loop | keep ENTRY |
| `workflow-roadmap` | product/engineering roadmap | **DUAL** | `workflow-feature`, `v1-workflow` | When-to-use: "what should we build next?"; also Step 1.95 in feature / Step 5 in v1 | keep ENTRY for roadmap-only asks; for feature/V1 prefer parent |
| `to-prd` | roadmap-to-backlog transition | **CHAIN** (in MICRO-PIPELINE) | `workflow-feature`, `v1-workflow`, `workflow-autonomous-backlog`, `workflow-roadmap` | Has hard roadmap gate; skipping grill/decision-log loses provenance | do **not** treat as leaf ENTRY; only via MICRO-PIPELINE / parent |
| `to-issues` | roadmap-to-backlog transition | **CHAIN** (in MICRO-PIPELINE) | same as to-prd | Child of PRD; dependency audit routes execute-prd vs run-backlog | same as to-prd |
| `repo-audit` | repo evidence audit / research | **ENTRY** (feeds MICRO) | optional support for autonomous-backlog | "input to the current workflow, not a standalone delivery loop"; Feeds roadmap/to-prd/design-plan | keep ENTRY; rewrite row to stop at audit + recommend next (don't imply auto-chain) |
| `improve-codebase-architecture` | research | **DUAL** | `workflow-autonomous-backlog` | Standalone architecture deepening *or* Step 1 of autonomous backlog | keep for architecture research; for "find modules + AFK" prefer `workflow-autonomous-backlog` |
| `design-plan` | mentioned after repo-audit | **CHAIN** | `workflow-roadmap` / post-`repo-audit` | Description: "Do not use as the default feature workflow" | never leaf ENTRY; only after audit/refactor brief |
| `workflow-review` | review | **DUAL** | `workflow-build-one`, `workflow-debug`, `workflow-autonomous-backlog` | Purpose: "before merging, after implementation, or whenever user asks to review" | keep ENTRY for "review this"; if shipping a ready issue, prefer build-one/debug (includes finalize) |
| `receive-review` | receive review | **DUAL → prefer CHAIN** | **`workflow-finalize`** (Step 2) | When-to-invoke: "during workflow-finalize's review gate, or address comments" | **demote**: default route "address review comments" → `workflow-finalize` (owns describe-pr → receive-review → watch-ci → reconcile). Direct `receive-review` only when user explicitly wants comment processing without ship/finalize |
| `cleanup-delivery` | delivery cleanup | **DUAL** | post-`workflow-finalize` / autonomous-backlog 6.5 | When-to-use after merge/abandon; also explicit cleanup asks | keep ENTRY for explicit cleanup; do not use mid-delivery |
| `workflow-effectiveness-audit` | effectiveness audit | **ENTRY** (misnamed) | — | Terminal governance; no Flow chain | keep ENTRY; rename (see sister reflection) |
| `session-insight` | reflect / skillify | **ENTRY** | also post-auto-merge follow-through | Standalone reflection; complements effectiveness audit | keep ENTRY |
| `skill-backlog` | skill backlog | **ENTRY** | — | Flow → `workflow-skill` | keep ENTRY (was missing from prior DAG dispatch list) |
| `workflow-skill` | skill authoring | **ENTRY** | `skill-backlog` | Implements approved backlog items | keep ENTRY |
| `skill-evaluator` | skill evaluation | **DUAL** | `workflow-skill` | Standalone eval *or* inside skill authoring | keep ENTRY for explicit eval |
| `workflow-executive-doc` | exec document | **ENTRY** | — | Flow may call `humanizer` | keep ENTRY |
| `prototype` | prototype | **DUAL** | `workflow-feature`, `v1-workflow` | Soft Context: "mid-feature exploration … or standalone design validation" | keep ENTRY for explicit prototype; inside feature/V1 prefer parent |
| `humanizer` | polish | **DUAL** | `workflow-executive-doc` | Leaf polish tool; also writing pipeline (Wren) | keep ENTRY for "humanize this text" |
| `handoff` | session exit | **ENTRY** | many halt paths | Explicit session exit | keep ENTRY |
| `prompt-builder` | prompt generation | **DUAL → prefer CHAIN** | `run-backlog`, `workflow-build-one` | Soft Context: "pre-dispatch (before run-backlog, workflow-build-one…)" | **demote default**: "prep for AFK/Codex" → `run-backlog` or `workflow-build-one` (they invoke prompt-builder). Direct only when user wants a prompt artifact without dispatch |
| `okr-generator` | OKRs | **ENTRY** | — | standalone | keep ENTRY |
| `product-launch-checklist` | product launch | **ENTRY** | — | standalone | keep ENTRY |

### Already correctly excluded from router table (CHAIN / slash-only)

| skill | owners | evidence |
|-------|--------|----------|
| `describe-pr` | `workflow-finalize` Step 1 | `disable-model-invocation: true`; "Auto-routing disabled; workflow-finalize may call it internally" |
| `watch-ci` | `workflow-finalize` Step 3 | same; description: "Manual slash-only… Auto-routing disabled" |
| `post-mortem` | `workflow-finalize` Step 0.5 | `disable-model-invocation: true` |
| `execute-phase` | `workflow-build-one` / `workflow-debug` | mid-implement step |
| `diagnose` | `workflow-debug` | cardinal first step of debug |
| `grill-with-docs`, `decision-log`, `triage` | feature / v1 / autonomous | planning spine steps |
| `user-journey-qa` | build-one / debug | conditional gate before finalize |
| `reconcile-issues` | finalize Step 4 | not a router leaf (good) |

Router Audit Loop Retirement Rule already bans `/review`, `/post-mortem`, `/describe-pr`, `/watch-ci` as standalone default loops — but **`receive-review` is still a direct classification row** even though it is finalize Step 2. That is the strongest inconsistency.

---

## A) Router rows that look like leaf dispatches but are really chain steps

1. **`receive-review`** — primary home is `workflow-finalize` Step 2 ("Resolve PR Reviewer Comments"). Direct dispatch skips describe-pr freshness, CI watch, reconcile, and `WORKFLOW_FINALIZE_GATE`.
2. **`prompt-builder`** — primary home is preflight inside `run-backlog` / `workflow-build-one`. Direct dispatch produces a prompt but does not create the worktree / gates / dispatch.
3. **`to-prd` / `to-issues`** (when read as leaves inside the roadmap-to-backlog row) — parents enforce grill → decision-log → roadmap approval. Jumping to `to-prd` alone trips the skill's own roadmap hard-gate and skips grilling provenance.
4. **`design-plan`** (implied after repo-audit) — not a default feature path; feature path is grill → decision-log → to-prd → to-issues.

## B) Mid-chain dispatches that skip gates (same class as V1 warning)

| If router dispatches… | Skips… |
|-----------------------|--------|
| `receive-review` instead of `workflow-finalize` | describe-pr body file, watch-ci, reconcile, finalize gate, repo-delivery policy |
| `prompt-builder` instead of `run-backlog` / `workflow-build-one` | worktree baseline, tdd/execute, review, finalize |
| `to-prd` without `workflow-feature` / `v1-workflow` / approved roadmap | grill, decision-log, design/roadmap approval |
| `workflow-review` when user meant "ship this issue" | execute + finalize chain (review alone is not delivery) |
| `improve-codebase-architecture` when user meant autonomous backlog | grill consensus, PRD/issues, AFK controls |
| `prototype` mid-feature without parent | decision-log capture / roadmap gate sequencing |

## C) True orchestrators missing (or under-specified) on the router table

| skill | note |
|-------|------|
| `workflow-finalize` | Audit Loop Retirement says delivery closure → finalize, but **no classification-table row** for "ship / finalize / open the PR / close delivery". Users saying "ship this" / "finalize" may get `receive-review` or `watch-ci` instead. **Add ENTRY** (precondition: review gate or halt back to `workflow-review`). |
| `design-plan` | Only mentioned as a feed; OK as non-leaf, but research/audit row should say "halt after audit; ask which next" rather than implying auto-dispatch. |
| `skill-backlog` → `workflow-skill` | Present in table; prior tldraw DAG omitted both from red dispatch edges — board lag, not router lag. |

## D) `workflow-` prefix that does **not** orchestrate multi-skill flows

| skill | orchestrates multi-skill sequence? | note |
|-------|--------------------------------------|------|
| `workflow-effectiveness-audit` | **No** — terminal scorecard | rename candidate → `skill-system-audit` (sister reflection) |
| `workflow-review` | **Yes** (reviewer lanes + synthesis) | keep prefix; it is a gate orchestrator |
| `workflow-finalize` | **Yes** (describe-pr → receive-review → watch-ci → reconcile → …) | keep |
| `workflow-roadmap` | **Yes** (research → approval → next workflow) | keep |
| `workflow-skill` | **Yes** (authoring pipeline incl. evaluator) | keep |
| `workflow-executive-doc` | **Partial** (doc pipeline; may call humanizer) | borderline keep |
| `workflow-router` | meta ENTRY | keep |

---

## Corrected mental model for the DAG / router

```
workflow-router
  ├─ ENTRY orchestrators (red dashed) ──► own blue sequences
  │     feature / v1 / build-one / debug / run-backlog / execute-prd /
  │     autonomous-backlog / roadmap* / executive-doc / skill-backlog /
  │     workflow-skill / effectiveness-audit / session-insight / …
  ├─ DUAL leaves (red dashed only on standalone signal)
  │     workflow-review* / cleanup-delivery* / prototype* / humanizer* /
  │     improve-codebase-architecture* / prompt-builder† / receive-review†
  └─ NEVER red-dashed (chain-only; blue from parent only)
        describe-pr, watch-ci, post-mortem, execute-phase, diagnose,
        grill-with-docs, decision-log, to-prd, to-issues, triage,
        user-journey-qa, reconcile-issues, …

* DUAL: prefer parent when user intent is a full pipeline
† prefer demote: default to parent orchestrator
```

### Recommended router table edits (when approved)

1. Change **receive review** row → Routes to: `workflow-finalize` (comment-resolution + CI + reconcile). Note: direct `receive-review` only if user waives full finalize.
2. Change **prompt generation** row → Routes to: `run-backlog` (batch/AFK) or `workflow-build-one` (single issue); `prompt-builder` alone only when user asks for the prompt artifact.
3. Add **delivery closure / ship** row → `workflow-finalize` (with review-gate precondition).
4. Tighten **roadmap-to-backlog** wording: this is a MICRO-PIPELINE, not permission to start at `to-prd` cold.
5. Tighten **repo evidence audit** wording: stop after `repo-audit`; present next-route options (don't auto-chain).

---

## Lessons
1. Router `Routes to` must name the **owning orchestrator**, not the first skill the user mentioned (`receive-review`, `describe-pr`, `watch-ci`).
2. `disable-model-invocation: true` is the hard signal for chain-only finalize internals — `receive-review` lacks that flag but is still finalize-owned.
3. DUAL skills need router copy that says "standalone signal only; if mid-feature/mid-delivery, stay on parent."
4. The tldraw DAG previously drew red edges for every classification leaf, including DUAL/CHAIN helpers — that overstated router authority.

## Proposed Improvements
- [ ] Edit `workflow-router` classification rows for `receive-review`, `prompt-builder`, add `workflow-finalize` ship row (priority: high)
- [x] Update tldraw DAG: remove red dispatch to chain-prefer targets (`handoff`, `receive-review`); add `workflow-finalize` ship ENTRY; wire blue auto-handoff from parents; add skill-governance ENTRYs (priority: high)
- [ ] Add durable rule to router or `_docs`: "If skill X is Step N of orchestrator Y, classification Routes-to is Y unless user explicitly asks for X alone" (priority: medium)
- [ ] Continue rename of `workflow-effectiveness-audit` (sister reflection) (priority: medium)

## Decision Needed
Approve the demotions (`receive-review` → finalize, `prompt-builder` → build-one/run-backlog) and the new `workflow-finalize` ship row before editing the router skill or redrawing the board.
