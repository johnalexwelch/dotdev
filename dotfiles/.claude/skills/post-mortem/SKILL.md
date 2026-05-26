---
name: post-mortem
description: "After executing a design plan, multi-phase refactor, significant drift, or work that produced NEW-NN findings, write a blameless retro that compares planned vs. actual, tracks which FIND-NN/REQ-NN/ticket items were addressed, and feeds lessons back into roadmap, PRD, issue, or audit evidence. Use as a conditional retro gate in workflow-finalize, not as a separate default audit loop."
triggers:
  - "post-mortem"
  - "retro the refactor"
  - "what happened vs the plan"
  - "close the loop"
  - "/post-mortem"
persona: Engineering lead writing a blameless retrospective
inputs:
  - name: plan_path
    type: string
    default: ""
    description: Path to the design plan. If empty, use the newest `docs/plans/*.md`.
  - name: audit_path
    type: string
    default: ""
    description: Path to the audit the plan was based on. If empty, resolve from the plan's header (`**Audit:**` field) or use the newest audit older than the plan.
  - name: since
    type: string
    default: ""
    description: Git range to survey. If empty, use the commit at which the plan was added (from git log --follow on the plan file).
  - name: scope
    type: string
    default: "complete"
    description: '"complete" if the plan is fully executed. "partial" if some phases are still in-progress or not-started. Affects tone and recommendations.'
reads:
  - docs/audits/<date>-repo-audit.md (resolved via plan or newest)
  - docs/plans/<date>-design.md (newest unless overridden)
  - git log, git diff, git branch -a (execution trace)
writes:
  - docs/executions/<date>-post-mortem.md
  - (optional) annotations appended to the referenced audit marking FIND-NN as addressed
---

## Deprecation Status

Status: standalone use deprecated. This skill remains loadable only because `workflow-finalize conditional post-mortem gate` may invoke it as an implementation helper.

- Workflow owner: `workflow-finalize conditional post-mortem gate`
- Reason: Retro work is conditional, not a standalone default audit loop.
- Date: 2026-05-21


## Contract

Consumes: executed design plan (docs/plans/), phase-run outcome files (docs/executions/.phase-runs/), CI-run outcome files (docs/executions/.ci-runs/), git history, audit report
Produces: blameless retro document (docs/executions/<date>-post-mortem.md), NEW-NN finding IDs
Requires: git
Side effects: writes post-mortem file; optionally annotates referenced audit
Human gates: none (audit annotation is opt-in, gated on user confirmation)

## Context

Typical workflows: conditional retro gate in `workflow-finalize` for design-plan, multi-phase, drift-heavy, or NEW-NN work
Pairs well with: execute-phase, workflow-review, workflow-finalize, describe-pr, repo-audit

# /post-mortem — Close the Loop

## Purpose

The delivery pipeline only learns if someone writes down what actually
happened when work was planned, phased, or drifted. This skill compares
the plan or issue intent to git history, tracks which `FIND-NN`,
`REQ-NN`, ticket, or phase items were resolved, captures anything new
that emerged during execution, and produces a post-mortem that can feed
roadmaps, PRDs, issues, or a future repo audit. Blameless in tone — the
goal is learning, not grading.

## Step 0: Preflight

- Confirm you are in a git repo. If not, abort.
- Resolve the plan: if `plan_path` is set, use it; else newest
  `docs/plans/*.md`. If no plan exists, abort — nothing to retro.
- Resolve the audit: if `audit_path` is set, use it; else read the
  plan's `**Audit:**` header. If that's missing or stale, use the
  newest audit older than the plan. **If the plan is brief-mode**
  (no `**Audit:**` header, §5 Addresses use `REQ-NN` or ticket
  slugs instead of `FIND-NN`): skip audit resolution entirely. The
  retro is anchored on `REQ-NN` / ticket slugs; FIND-NN cross-refs
  are inapplicable. Note in §Summary that this is a brief-mode
  retro.
- Resolve the git range. If `since` is empty, find the commit that
  introduced the plan file:
  `git log --follow --format=%H <plan_path> | tail -1`.
  Use that as the range start (`<since_commit>..HEAD`).
- Check the ID scheme. If the audit/plan has `FIND-NN` IDs, build the
  resolution table on those. If brief-mode (`REQ-NN` / ticket slugs),
  resolve against those instead — same table mechanics, different
  anchor IDs. If neither, post-mortem uses phase-based attribution.
- Ensure `docs/executions/` exists (`mkdir -p`).

## Step 1: Gather execution evidence

Load `references/evidence-checklist.md` and follow it exactly. It
defines the `.phase-runs/` first, `.ci-runs/` second, git fallback,
test status, deletion, and documentation evidence checklist.

## Step 2: Map plan → reality

Build a phase-by-phase reality check. For each phase in the plan's §5:

- **Status:** done | in-progress | blocked | skipped
- **Evidence:** the commits, branches, or files that establish status
- **Drift:** actual vs. planned — tasks added, tasks dropped, scope
  expanded, rollback invoked, etc.
- **FIND-NN resolved:** which of the phase's "Addresses" findings are
  actually addressed in the code? Spot-check by re-reading the
  relevant files and confirming the finding no longer applies.

Produce a finding-by-finding table anchored on whatever ID scheme the
plan used (`FIND-NN` for audit-mode, `REQ-NN` / ticket slugs for
brief-mode). Same mechanics, different column header.

| ID | Severity | Addressed by | Status |
|----|----------|--------------|--------|
| FIND-01 | critical | Phase 3 commits abc123..def456 | resolved |
| FIND-02 | critical | Phase 4 (in-progress) | partial |
| REQ-01 | — | Phase 1 commit 7ab8cd | resolved |
| JIRA-123 | — | Phase 2 commits ef0123..gh4567 | resolved |
| ... | ... | ... | ... |

For brief-mode plans, severity is often `—` (briefs don't carry the
audit's severity classification). That's fine — Status is the
load-bearing column.

## Step 3: Identify new findings

Load `references/new-findings-rules.md`. Use it to detect and classify
`NEW-NN` findings, including discoveries from phase-run and CI-run
outcome files.

## Step 4: Draft the post-mortem

Load `references/retro-output-template.md` and save to
`docs/executions/<date>-post-mortem.md` using that structure.

## Step 5: (Optional) annotate the audit

If the user opts in, append a footer to the referenced audit:

```
---

## Post-mortem annotations
**Post-mortem:** <relative path to this post-mortem>
**Findings status** (as of <YYYY-MM-DD>):
- FIND-01: resolved by Phase 3
- FIND-02: partial (Phase 4 in-progress)
- FIND-03: open
- ...
```

This makes old audits self-describing: anyone opening a 6-month-old
audit can see which findings still apply. Gate on user confirmation —
audits are historical records and some users prefer them untouched.

## Step 6: Surface

Present to the user in chat:

- One-sentence summary ("Phases 0–3 done, Phase 4 in-progress,
  resolved FIND-01/02/05, 3 new findings, 2 phases drifted").
- Top 3 most important items from "What I'd change" — these are the
  actionable takeaways.
- Pointer: `See docs/executions/<date>-post-mortem.md`.

## Artifact Output

When issue context is available, write to:

```
docs/tasks/{issue-number}-{slug}/post-mortem.md
```

Fallback: `docs/executions/{date}-post-mortem.md`

## Output Format

Markdown at `docs/executions/<date>-post-mortem.md`, structured per
Step 4. Optional audit annotation per Step 5.

## Error Handling

| Failure | Behavior |
|---------|----------|
| Not in a git repo | Abort. |
| No plan found | Abort. Nothing to retro against. |
| No audit referenced or findable | Proceed with phase-based attribution only. Note in §Summary that audit linkage was unavailable. |
| `since` commit not findable | Use `HEAD~50` as a fallback and note the approximation. |
| Test command fails | Note in §Summary; do not block post-mortem. |
| Plan has no `FIND-NN` references | Skip the finding table; use phase-only structure. Recommend future audits use the ID schema. |
| Scope was "complete" but phases remain in-progress | Downgrade to "partial" automatically and note it. |

## Example Invocation

```
User: /post-mortem
Claude: [finds docs/plans/2026-04-20-design.md]
        [resolves audit: docs/audits/2026-04-20-repo-audit.md]
        [git range: 14 commits across 6 phase branches]
        [phases 0–3 merged to main; phase-4 branch open with 2 commits;
         phases 5–6 not started]
        [test status: green]
        [maps: FIND-01 resolved, FIND-02/03/05 resolved, FIND-04 still
         open, FIND-06 partially addressed]
        [new findings: NEW-01 (launchd race condition surfaced during
         Phase 2), NEW-02 (OAuth refresh token edge case in Phase 3)]
        [writes docs/executions/2026-04-20-post-mortem.md]

        Phases 0–3 done, Phase 4 in-progress. Resolved FIND-01, 02,
        03, 05; FIND-04 still open, FIND-06 partial. 2 new findings.
        Phase 2 drifted — OAuth refactor expanded mid-phase.

        Top 3 lessons:
        - Pilot was too narrow; NEW-01 surfaced in Phase 2 instead of
          Phase 1 where it would have been cheaper.
        - [human] markers on Phase 3 tasks were fine — most could have
          been [auto] with a review gate.
        - Delete list for Phase 3 was incomplete — 4 files missed.

        Full report: docs/executions/2026-04-20-post-mortem.md
```

## Output format

The primary artifact is always the markdown report at `docs/executions/`. When running in Cursor IDE, also produce a **canvas** (`.canvas.tsx`) for the retro summary — the planned-vs-actual table, drift analysis, and NEW-NN findings render better as an interactive artifact. Use the Cursor `canvas` skill pattern: create a `canvases/<date>-post-mortem.canvas.tsx` with the structured retro data.

Skip the canvas when running headless (Codex AFK, CI, non-IDE context).

## Tuning notes

- Run `/post-mortem` with `scope=partial` after each major phase lands
  — don't wait until the whole plan is done. Short feedback loops are
  more valuable than comprehensive retros.
- For team projects, include a "who decided what, when" column in the
  drift table — useful for retros, dangerous if framed as blame.
- If `NEW-NN` count is high (>5), the original audit had blind spots.
  Feed those into the next `/repo-audit` as a `focus=` hint.
- Post-mortems should be short. If the file is >500 lines, the audit
  was too coarse or the plan was too ambitious. Fix upstream.
- Pair with the current delivery workflow as a conditional retro gate:
  - Routine issue work: usually skip, with `not_applicable_with_reason`
    in `WORKFLOW_FINALIZE_GATE`.
  - Multi-phase/refactor work: run before `describe-pr` so the PR body
    can cite drift and `NEW-NN` entries.
  - Audit-derived work: use the retro to feed follow-up roadmap, PRD,
    issue, or future `repo-audit` evidence.
  This skill consolidates new findings from `/execute-phase` outcome
  files and `watch-ci` `.ci-runs/` outcome files, but it is no longer a
  standalone audit-loop requirement for every delivery.
