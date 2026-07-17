---
name: skill-backlog
model: sonnet
reasoning: high
description: 'Harvest accumulated skill-improvement suggestions from session reflections into one standing ledger, cluster them by failure mode and cross-session frequency, decide what is worth doing, and dispatch approved items to workflow-skill. Use to process the skill backlog, review skill improvements, or turn reflections into skill changes.'
codex-compatible: true
---

# Skill Backlog

The consumer that closes the loop `session-insight` opens. Each session drops improvement proposals and skill-extraction candidates into `~/dotdev/docs/executions/reflections/`; those pile up and no single session can see that the *same* friction recurred four times. This skill reads the whole pile, so **cross-session frequency of a failure mode** — the signal no producer has — becomes the primary prioritizer.

It plans and stops at approval, then hands each approved item to `workflow-skill` for implementation (the same seam as `workflow-feature` → `workflow-build-one`). It never edits a skill itself.

## When to invoke

- "Process the skill backlog", "review skill improvements", "what should I fix in the skills"
- Periodic personal skill retro (weekly/monthly)
- After a burst of `session-insight` reflections has accumulated

## Flow

```
Harvest → Ground-truth probe → Cluster by failure mode → Evaluate → Plan (STOP) → Dispatch → Update ledger
```

## Workflow Progress Reporting

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| Step 1: Harvest | required | pending | - |
| Step 1.5: Ground-Truth Probe | required | pending | - |
| Step 2: Cluster By Failure Mode | required | pending | - |
| Step 3: Evaluate Value | required | pending | - |
| Step 4: Plan + Approval Gate | required | pending | - |
| Step 5: Dispatch To workflow-skill | conditional | pending | Per approved item |
| Step 6: Update Ledger | required | pending | - |
```

Initialize `pending`; update as each finishes; include the final ledger in every halt and completion.

### Step 1: Harvest

Scan `~/dotdev/docs/executions/reflections/*.md`. From each file pull **only concrete proposals**:

- `## Proposed Improvements` items that name a concrete path + change (`` `- [ ] \`path\` — change` ``). Drop meta lines ("none require a skill edit", process commentary) → ledger as `rejected` with reason `non-proposal`.
- `## Skill Extraction Candidates` — the full draft payload (name, target, steps, gate result).

Resolve owning paths at harvest (`readlink -f` / existence check). If the reflection's path is stale (e.g. `.claude/skills` vs `.config/agents/skills`), normalize to the canonical path before keying.

Skip anything the reflection already marks resolved (e.g. a `_Note: already folded…_` footer) — record as `implemented`.

Merge into `~/dotdev/docs/executions/skill-backlog.md`. Idempotency key: `owning-file + normalized-summary`. Existing row → add source, bump `occ`; never duplicate. Closed rows (`implemented`/`rejected`) stay closed; note recurrence in-row rather than reopening.

Completion criterion: every reflection file accounted for; every concrete proposal has a ledger row.

### Step 1.5: Ground-truth probe (mandatory)

**Do not trust reflection checkboxes or frequency alone.** For every open (`new`/`accepted`/`deferred`) row:

1. Open the owning file (or confirm it does not exist yet for a net-new skill).
2. Search for evidence the proposed change is already present.
3. If present → set `status: implemented`, `resolution: already landed (ground-truth <date>)`.
4. If absent → leave open.

Reflections are rarely updated when a later session implements a proposal. Ground-truth is the authority; reflection notes are a hint only.

Completion criterion: every open row has been probed against the current filesystem; ghosts closed.

### Step 2: Cluster by failure mode

Cluster on the **failure mode / theme**, not the owning skill. Popular skills accumulate unrelated proposals — owner-frequency over-counts.

Examples of failure-mode clusters: canonicality-over-compatibility, proxy-vs-ground-truth, self-cwd safety, discoverability, finalize→cleanup coupling.

Within a cluster:

1. **Fold/merge pass (required before ranking):** if two rows are the same concern split across owners, keep one `implement` and mark the rest `fold` into it. Record the fold target in `resolution`.
2. Set `occ` = distinct reflection *sessions* that evidence this failure mode (not distinct checkbox lines on one popular skill).
3. Rank clusters by **failure-mode frequency × leverage × priority**.

Every open row belongs to exactly one cluster (`cluster` column). Surface ranked clusters; don't drown the queue.

Completion criterion: fold/merge done; every open row has a cluster; clusters ranked.

### Step 3: Evaluate value

For each top cluster, assign an action:

- `implement` — clear, worth doing now.
- `fold` — same concern as another row; name the absorb target.
- `reject` — one-off, googleable, non-proposal, or premature generalization; record why.
- `defer` — plausible but niche; wait for recurrence.
- `needs-evidence` — value uncertain *and* empirically testable → invoke `skill-evaluator` before committing effort.

Completion criterion: every top cluster has an action + one-line rationale.

### Step 4: Plan + approval gate (STOP)

Present the ranked decision queue: cluster, `occ`, sources, evidence, proposed action, target. Ask which to implement this run. **Do not dispatch before explicit approval.**

Completion criterion: user selected items (possibly none).

### Step 5: Dispatch (conditional)

Per approved item, Load and run `workflow-skill/SKILL.md` with the scoped change and harvested evidence. Process independently; rejected/deferred items are not dispatched.

Completion criterion: every approved item dispatched; `workflow-skill` result captured.

### Step 6: Update ledger

Write final statuses: landed → `implemented` (+ commit/ref if any); rejected → `rejected` (+ reason); approved-but-not-done → `accepted`; untouched open → stay `new`/`deferred`. Prefer ground-truth over rewriting old reflections.

Completion criterion: every row touched this run has final status + resolution.

## Ledger schema — `~/dotdev/docs/executions/skill-backlog.md`

```markdown
# Skill Backlog
<!-- maintained by skill-backlog; do not hand-edit status fields -->

## Clusters (MECE)
| cluster | theme (failure mode) | occ sessions | open items | rank signal |
|---------|----------------------|--------------|------------|-------------|

## Ledger
| id | first_seen | occ | sources | owning skill/file | summary | priority | status | action | cluster | resolution |
|----|-----------|-----|---------|-------------------|---------|----------|--------|--------|---------|------------|
| SB-001 | 2026-07-16 | 2 | 2026-07-16-… | session-insight | … | high | implemented | — | CZ | already landed |
```

`status`: `new` \| `accepted` \| `implemented` \| `rejected` \| `deferred`.
`occ` = distinct sessions evidencing the **failure mode** (after clustering), not raw checkbox count.
Assign ids sequentially (`SB-NNN`).

## Contract

Consumes: `~/dotdev/docs/executions/reflections/*.md`, existing `~/dotdev/docs/executions/skill-backlog.md`
Produces: an updated backlog ledger, a ranked decision queue, dispatched `workflow-skill` runs for approved items
Requires: nothing (stdlib/native — keeps `codex-compatible: true`); `workflow-skill` for implementation
Side effects: writes/updates `skill-backlog.md`; dispatches implementation runs only after approval
Human gates: Step 4 approval before any dispatch

## Context

Typical workflows: periodic skill retro; the consumer end of the session-insight → skill-backlog → workflow-skill pipeline
Pairs well with: session-insight (producer), workflow-skill (implements approved items), skill-evaluator (values uncertain items)
