# Outcome File Template

Load this reference whenever `/watch-ci` writes an attempt file under `docs/executions/.ci-runs/`.

One outcome file is written per CI attempt:

```text
docs/executions/.ci-runs/<date>-pr-<pr_number>-attempt-<M>.md
```

The final attempt's file carries CI, review-agent monitoring, and reviewer-feedback outcomes when CI reaches green.

## Template

```markdown
# /watch-ci attempt <M> - PR #<pr_number>

**Date:** <YYYY-MM-DD>
**Branch:** <branch>
**Base:** <base>
**Attempt:** <M>/<max_attempts>
**Mode:** live | dry_run

## CI runs
<Table: job name | workflow | status | duration | log URL>

## Failure classes
<Per failed job:
  - **<job name>** - class: <class>
  - Log excerpt: <first ~10 lines of failure>
  - Auto-fix proposed: <yes - <command/subagent brief> | no - surfaced to human>>

## Proposed fixes
<Per auto-fix-eligible class: what was dispatched. Empty if all-pass first try or all out-of-scope.>

## Fix commits
<Per commit pushed by this attempt:
  - <short-hash> ci-fix(<class>): <subject>
  - Files touched: <list>>

## Pending human
<Out-of-scope failures surfaced as [human]. Empty if attempt is clean.>

## Signature
sha1: <signature hash from Step 3>
(Compared against prior attempt for no-progress halt detection.)

## Review monitoring
<Only present in final-attempt outcome file with green CI>
- security-review (OMC security-reviewer): <clean | N findings>
- no_review evidence/waiver: <N/A | artifact/user waiver and rationale>
- /review on auto-fix or feedback-fix diff: <clean | N issues | N/A no-auto-fixes>
- reviewer feedback incorporated: <blockers N, non-blockers N, observations N, comments N, questions N, nits N>
- reviewer-comment gate: <passed | blocked - N unresolved>
- quiet period: <review_quiet_minutes> minutes with no new actionable feedback
- Verdict: <Draft ready for user review | Changes requested | Self-review skipped>
- Comment posted: <yes - <comment URL> | no>
- PR state: draft; user must decide when to mark ready

## Verdict
<one of: would-have-fixed (dry_run) | fixed | halted (no-progress) | halted (max-attempts) | halted (out-of-scope) | green-first-try | draft-ready | changes-requested>
```

## Chat Summary Format

After writing the outcome file, print to chat:

- `PR #<N> - <verdict>: <K> auto-fix commits, security-review <clean|N findings>, /review on auto-fix or feedback-fix <clean|N issues|N/A>, reviewer feedback incorporated, unresolved comments <N>.`
- PR URL.
- Outcome file path: `docs/executions/.ci-runs/<date>-pr-<N>-attempt-<M>.md`.
- If halted, the specific blocker and recommended next step.
- If clean, `Draft PR ready for your review; you decide when to mark ready.`
