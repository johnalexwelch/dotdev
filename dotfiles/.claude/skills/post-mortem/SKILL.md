---
name: post-mortem
description: "After executing some or all of a design plan, produce a blameless retro that compares planned vs. actual, tracks which audit findings (FIND-NN) were addressed, captures new findings discovered during execution, and feeds forward into the next audit cycle. Closes the loop between /repo-audit and /design-plan. In the Audit Loop this skill is loaded by a dedicated post-mortem subagent (dispatched via `Agent` with `subagent_type: general-purpose` or `oh-my-claudecode:writer`) separate from the executor and reviewer subagents — the retro author should have no code-writing or approval bias from the phases under review."
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

# /post-mortem — Close the Loop

## Purpose

The audit/plan pipeline is only a loop if someone writes down what
actually happened. This skill compares the plan to the git history,
tracks which `FIND-NN` findings were resolved, captures anything new
that emerged during execution, and produces a post-mortem that seeds
the next audit cycle. Blameless in tone — the goal is learning, not
grading.

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

**Read `.phase-runs/` first.** If `docs/executions/.phase-runs/`
exists, glob `*-phase-*.md` and read the outcome files whose
`**Plan:**` header matches `plan_path`. These are richer signal than
raw `git log` — they include commit-to-task mapping, pending-human
items, scope-violation records, and `NEW-NN` candidates surfaced
during execution. Fall back to `git log` alone only when `.phase-runs/`
is absent or its records don't cover the commit range (e.g. the plan
was executed manually without `/execute-phase`).

**Then read `.ci-runs/` if present.** If `docs/executions/.ci-runs/`
exists, glob `*-pr-*-attempt-*.md` and read any outcome files whose
PR or branch references match this plan's phase branches. These
record `/watch-ci`'s history: failed CI runs, classifier verdicts,
auto-fix commits, no-progress halts, and self-review comments. Per
`/watch-ci`'s Follow-ups block, these are an additional source of
`NEW-NN` candidates (e.g. flaky tests surfaced during CI watching,
deps that needed pinning, security findings deferred). Add them to
§"New findings" with `Source:` cited as the relevant `.ci-runs/`
attempt file.

Collect the ground truth from git and the working tree:

1. **Commits in range.** `git log --oneline <since>..HEAD` and note
   the count. Also collect commit messages — they reveal intent drift.
2. **Files changed.** `git diff --stat <since>..HEAD`. Note line
   counts added/deleted. Compare to the plan's delete list.
3. **Phase branches.** `git branch -a | grep -E '(refactor|fix|feat)/phase-'` and
   `git log --oneline <since>..HEAD --grep="phase-"`. For each
   phase branch that exists: merged? still open? deleted? Note which
   prefix was used (`refactor/` for audit-mode, `fix/` or `feat/`
   for brief-mode).
4. **Test status now.** Run the test command. Note pass/fail, and
   whether coverage is materially different from the audit's report.
5. **Files deleted.** `git log --diff-filter=D --name-only
   <since>..HEAD`. Compare to the plan's §8 Delete list.
6. **CLAUDE.md and docs changes.** `git log --oneline <since>..HEAD
   -- '*.md'`. Did documentation keep up?

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

Execution almost always surfaces things the audit missed. Look for:

- Commits that mention "fix" or "workaround" without a phase tag —
  often signal a rough patch that needs a follow-up.
- Files added that aren't in the plan — undocumented scope expansion.
- Tests added in one phase that reveal problems in another.
- `TODO` / `HACK` / `FIXME` comments added during execution.
- Comments in PR descriptions or commit messages naming concerns
  ("punting on X for now," "found Y, not fixing here").
- Rollbacks that happened — the phase succeeded on paper but had to
  be reverted once, then redone.

Each new finding gets a placeholder ID of the form `NEW-01`,
`NEW-02`, ... These are intended to be promoted to full `FIND-NN`
IDs the next time `/repo-audit` runs.

## Step 4: Draft the post-mortem

Save to `docs/executions/<date>-post-mortem.md` using this structure:

```
# Post-Mortem — <repo or effort name>
**Date:** <YYYY-MM-DD>
**Plan:** <relative path to plan>
**Audit:** <relative path to audit>
**Git range:** <since_commit>..HEAD (<N> commits)
**Scope:** complete | partial

## Summary
<One paragraph. What the plan set out to do, what actually got done,
what didn't, and whether the overall state improved. Blameless tone.>

## Findings addressed
<Finding-by-finding table per Step 2. If the audit lacked IDs, replace
with a phase-by-phase resolution summary.>

## What went as planned
<Phases completed on scope and intent. Brief — one bullet per phase.>

## What drifted
<Phases that deviated. For each:
  - **Phase N — <name>**
  - Planned: <one line>
  - Actual: <one line>
  - Why: <one line>
  - Cost: <time, scope, rework — one line>
Don't sanitize. Drift isn't failure — it's information.>

## New findings (NEW-NN)
<Things discovered during execution that the audit missed. For each:
  - **NEW-NN — <title>**
  - Source: <commit hash / file / conversation>
  - Severity: critical | high | medium | low
  - Impact: one sentence
  - Recommendation: promote to FIND in next /repo-audit, fix inline,
    defer.>

## Outstanding work
<Findings and tasks still open. Includes:
  - FIND-NN not yet addressed (with a recommendation: re-plan,
    deprioritize, or drop).
  - Phases skipped or deferred.
  - §9 Open questions from the plan that didn't get answered.>

## What I'd change in the next plan
<Concrete lessons about the plan itself. E.g.:
  - "Pilot phase was too small — didn't surface FIND-04 until Phase 3."
  - "Two phases should have been one — the split caused rework."
  - "[human] markers were too conservative — most were fine to [auto]."
Feeds the next /design-plan invocation.>

## Recommendations for next audit
<What to look for in the next /repo-audit cycle. Usually:
  - Re-audit the areas where NEW-NN findings clustered.
  - Run scoped audit on <path> if drift was concentrated there.
  - Add a focus=<slug> if new findings suggest a weak area.>
```

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
- Pair with the full core loop: `/repo-audit` (optional —
  brief-mode skips it) → `/design-plan` → `/execute-phase` →
  `/review` → `/post-mortem` (this skill) → `/describe-pr` →
  `/watch-ci` (post-PR-open) → human merge. The post-mortem runs
  **before** `/describe-pr` so the PR body can cite `NEW-NN`
  entries and drift analysis directly from the retro, and human
  reviewers see the retro context before merging. Plus
  `/setup-worktree` as an on-demand side-car. All seven skills
  share ID vocabulary (`FIND-NN`, `REQ-NN`, `NEW-NN`, ticket slugs,
  phase numbers) and directory conventions (`docs/audits/`,
  `docs/plans/`, `docs/executions/` including the `.phase-runs/`
  subdir written by `/execute-phase` and the `.ci-runs/` subdir
  written by `/watch-ci`), and a blameless tone. This skill
  consolidates new findings from two sources: `/execute-phase`'s
  outcome-file `## Follow-ups` blocks (in-loop discoveries) and
  `/watch-ci`'s `.ci-runs/` outcome files (post-PR discoveries —
  flaky tests, deps that needed pinning, security findings
  deferred). Both feed forward as `NEW-NN` entries recommended for
  promotion to `FIND-NN` in the next `/repo-audit` cycle.