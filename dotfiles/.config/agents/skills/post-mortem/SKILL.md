---
name: post-mortem
model: sonnet
reasoning: high
description: "After executing a design plan, multi-phase refactor, significant drift, or work that produced NEW-NN findings, write a blameless retro that compares planned vs. actual, tracks which FIND-NN/REQ-NN/ticket items were addressed, and feeds lessons back into roadmap, PRD, issue, or audit evidence. Use as a conditional retro gate in workflow-finalize, not as a separate default audit loop."
triggers:
  - "post-mortem"
  - "retro the refactor"
  - "what happened vs the plan"
  - "close the loop"
  - "/post-mortem"
disable-model-invocation: true
persona: Engineering lead writing a blameless retrospective
inputs:
  - name: plan_path
    default: ""
    description: Design plan path. If empty, newest `docs/plans/*.md`.
  - name: audit_path
    default: ""
    description: Audit the plan was based on. If empty, resolve from the plan's `**Audit:**` header or newest audit older than the plan.
  - name: since
    default: ""
    description: Git range to survey. If empty, the commit that introduced the plan file.
  - name: scope
    default: "complete"
    description: '"complete" if fully executed, "partial" otherwise. Affects tone and recommendations.'
reads:
  - docs/audits/<date>-repo-audit.md
  - docs/plans/<date>-design.md
  - docs/executions/.phase-runs/*.md, docs/executions/.ci-runs/*.md
  - git log, git diff, git branch -a
writes:
  - docs/executions/<date>-post-mortem.md
---

# /post-mortem — Close the Loop

The pipeline only learns if someone records what actually happened. Compare plan/issue intent to git history, track which `FIND-NN`/`REQ-NN`/ticket/phase items were resolved, capture what newly emerged (`NEW-NN`), and produce a retro that can feed roadmaps, PRDs, issues, or a future audit. Blameless — the goal is learning, not grading.

Standalone use is deprecated; this runs as the conditional retro gate inside `workflow-finalize`. Edge cases, a worked example, and tuning guidance live in `references/edge-cases-and-examples.md` — load it when needed.

## Contract

Consumes: design plan, audit evidence, phase-run and CI-run artifacts, git history, and optional git range
Produces: blameless post-mortem under `docs/executions/` with resolved findings, drift, new findings, and takeaways
Requires: git
Side effects: writes post-mortem artifact; may annotate the source audit only with explicit user opt-in
Human gates: missing plan/evidence, audit annotation, or unresolved human tasks halt for human input

## Step 0 — Preflight

Confirm a git repo (else abort). Resolve the plan (`plan_path` or newest `docs/plans/*.md`; if none, abort). Resolve the audit (`audit_path`, else the plan's `**Audit:**` header, else newest audit older than the plan). **Brief-mode** plans (no `**Audit:**`, §5 uses `REQ-NN`/ticket slugs) skip audit resolution and anchor on `REQ-NN`/slugs — note this in §Summary. Resolve the git range (`since`, else `git log --follow --format=%H <plan_path> | tail -1` → `<since>..HEAD`). Pick the ID scheme: `FIND-NN` (audit-mode), `REQ-NN`/slugs (brief-mode), or phase-based if neither. `mkdir -p docs/executions/`.

## Step 1 — Gather execution evidence

Load `references/evidence-checklist.md` and follow it (`.phase-runs/` first, `.ci-runs/` second, git fallback, test status, deletions, docs).

## Step 2 — Map plan → reality

For each §5 phase: **Status** (done/in-progress/blocked/skipped), **Evidence** (commits/branches/files), **Drift** (actual vs planned), **Findings resolved** (re-read the files to confirm the finding no longer applies). Produce a resolution table anchored on the chosen IDs:

| ID | Severity | Addressed by | Status |
|----|----------|--------------|--------|
| FIND-01 | critical | Phase 1 commits … | resolved |

Status is the load-bearing column; brief-mode severity is often `—`.

## Step 3 — New findings

Load `references/new-findings-rules.md`; detect and classify `NEW-NN`, including discoveries in phase-run and CI-run outcome files.

## Step 4 — Draft

Load `references/retro-output-template.md` and write `docs/executions/<date>-post-mortem.md` in that structure.

## Step 5 — (Optional) annotate the audit

If the user opts in, append a "Post-mortem annotations" footer to the referenced audit listing each finding's status. Gate on confirmation — audits are historical records.

## Step 6 — Surface

In chat: a one-sentence summary (phases done/in-progress, findings resolved, NEW count, drift), the top 3 "what I'd change" takeaways, and a pointer to the file.
