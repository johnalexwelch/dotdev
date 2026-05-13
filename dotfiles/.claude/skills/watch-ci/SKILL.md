---
name: watch-ci
description: Post-PR-open CI watcher and bounded auto-fix loop. Polls GitHub Actions via `gh`, classifies failures, applies bounded auto-fixes (max 3 attempts, halt on no-progress), dispatches the OMC `security-reviewer` agent on green plus `/review` on the auto-fix diff if any auto-fix commits were pushed, posts a structured PR comment, and submits `gh pr review --approve` when both reviews are clean. Closes the post-PR loop between `/describe-pr` (writes PR body) and human merge. Auto-creates the PR if `pr_number` is unset and no PR exists for the branch.
triggers:
  - "/watch-ci"
  - "watch ci"
  - "monitor ci"
  - "fix ci"
  - "ship pr"
persona: Release engineer driving CI to green and self-reviewing the diff before merge
inputs:
  - name: pr_number
    type: integer
    default: 0
    description: GitHub PR number. If 0, look up the PR for the current branch via `gh pr view`. If still 0 (no PR), auto-create one using `body_path` or the most recent `.pr-bodies/` file.
  - name: branch
    type: string
    default: ""
    description: Branch to watch. If empty, use the current branch (`git rev-parse --abbrev-ref HEAD`). Used for PR lookup and for `git push` of auto-fix commits.
  - name: max_attempts
    type: integer
    default: 3
    description: Maximum auto-fix attempts before halting. Cap exists alongside no-progress detection — both halt rules apply.
  - name: dry_run
    type: boolean
    default: false
    description: If true, poll and classify only — no commits, no comments, no Approve. Outcome file is still written. Useful for inspecting what `/watch-ci` would do before turning it loose.
  - name: no_review
    type: boolean
    default: false
    description: If true, skip the post-CI-green self-review pass entirely. The skill still posts a structured comment summarizing CI history but does not dispatch the OMC `security-reviewer` agent or invoke `/review`.
  - name: no_approve
    type: boolean
    default: false
    description: If true, never submit `gh pr review --approve` even when reviews come back clean. Use for repos requiring named human reviewers, or when self-approval policy disallows. Comment is still posted with verdict `Changes requested by /watch-ci`.
  - name: body_path
    type: string
    default: ""
    description: Path to a PR body file used when auto-creating the PR. If empty, fall back to the most recent `docs/executions/.pr-bodies/<date>-pr-*.md` matching the branch.
  - name: base
    type: string
    default: "main"
    description: Base branch for PR creation (only used if `pr_number == 0` and the skill auto-creates the PR).
reads:
  - docs/plans/<date>[-<slug>]-design.md (newest unless overridden in chat — read for plan context only)
  - docs/executions/.phase-runs/<date>[-<plan-slug>]-phase-<N>.md (commit-to-task mapping for review framing)
  - docs/executions/.pr-bodies/<date>-pr-*.md (for auto-PR-creation fallback body)
  - GitHub Actions runs and logs via `gh run list`, `gh run view`, `gh pr checks`, `gh run view --log-failed`
  - PR state via `gh pr view <pr> --json …`
writes:
  - docs/executions/.ci-runs/<date>-pr-<N>-attempt-<M>.md (one per CI attempt this run drives)
  - docs/executions/ci-handoffs/<pr-number>-<date>.md (exhaustion handoff artifact for diagnose)
  - git commits on the PR's branch (auto-fix commits, format `ci-fix(<class>): <one-liner>`)
  - PR comment via `gh pr comment` (one structured comment per `/watch-ci` invocation)
  - PR review via `gh pr review --approve` (only on clean self-review pass; gated by `no_approve`)
---

## Contract

Consumes: PR number or branch, GitHub Actions output, phase-run outcome files
Produces: CI status report (docs/executions/.ci-runs/), PR comment, optional auto-fix commits
Requires: gh, git
Side effects: may push fix commits (max 3 attempts), posts PR comments, submits PR approval (when gate passes), may auto-create PR
Human gates: exhaustion halts with handoff artifact; out-of-scope failures (test-logic, build-infra, security, unknown) always halt

## Context

Typical workflows: audit-loop (after /describe-pr, before human merge)
Pairs well with: describe-pr, review, setup-worktree

# /watch-ci — Drive CI to Green and Self-Review

## Purpose

`/describe-pr` produces the PR body. After the human (or this skill) opens the PR, CI runs and may fail; deterministic failures (lint, format, type, clear assertion deltas) are exactly the kind of work an agent should drive without human intervention. This skill polls CI, classifies failures, applies bounded auto-fixes, and runs self-review once green. Tightly bounded — max 3 attempts, halt on same-failure-twice — to prevent runaway loops or rubber-stamp drift.

The skill enforces three invariants:

1. **Bounded loops.** Both an attempt cap (`max_attempts`, default 3) and a no-progress detector (same failure signature in two consecutive runs → halt). Both apply; whichever halts first wins.
2. **Auto-fix scope discipline.** Only deterministic failure classes (lint, format, type, clear assertion deltas) are auto-fixed. Test logic, build infra, security findings, and unknown classes always halt and surface to human.
3. **Self-review asymmetry.** The OMC `security-reviewer` agent runs on every green CI; `/review` runs only on the auto-fix diff (since `/review` already saw the original diff in-loop pre-PR). Approve is submitted only when both come back clean and `no_approve` is unset.

## Step 0: Preflight

- Confirm `gh auth status` returns OK and the token has `repo`, `pull_request`, `workflow`, and `actions:read` scopes minimum. Abort with a clear message if not — token mutation is `[human]`, never automatic.
- Confirm a git repo and a clean working tree (`git status --porcelain`). Auto-fix commits need a clean baseline. Abort if dirty.
- Resolve `branch`: if empty, use `git rev-parse --abbrev-ref HEAD`. Abort if still empty.
- Resolve `pr_number`:
  - If set, validate via `gh pr view <pr_number> --json number`.
  - If 0, try `gh pr view <branch> --json number -q .number`. If found, use it.
  - If still no PR: **auto-create**. Resolve a body file: `body_path` if set, else the newest `docs/executions/.pr-bodies/<date>-pr-*.md` whose name or content references `<branch>`. If no body file is findable, abort and tell the user to run `/describe-pr` first or pass `body_path=`. Run `gh pr create --base <base> --head <branch> --title <derived-from-first-commit> --body-file <path>`. Capture the new PR number from `gh` output.
- Compute today's date as `<YYYY-MM-DD>`.
- Ensure `docs/executions/.ci-runs/` exists (`mkdir -p`).
- Initialize attempt counter `M = 1`.
- Initialize `prior_signature = None` (for no-progress detection).
- Initialize `auto_fix_commits = []` (tracks all auto-fix commits this run produces; feeds the self-review scoping in Step 3).

## Step 1: Poll CI

Watch CI for the PR via `gh pr checks <pr_number> --watch` if available; fall back to a polling loop if `--watch` is unsupported in the user's `gh` version:

```
while true; do
  status=$(gh pr checks <pr_number> --json bucket -q '.[].bucket' | sort -u)
  case "$status" in
    *fail*) break ;;
    pass) break ;;
    *) sleep 30 ;;
  esac
done
```

Cap total wait time at 30 minutes per attempt. If runs are stuck in `queued` or `in_progress` past that window, surface to human (`## Pending human` block in the outcome file) and exit — CI infra issues aren't auto-fixable.

After the poll loop exits, fetch full run state:

```
gh pr checks <pr_number> --json name,bucket,workflow,event,description,detailsUrl
```

Branch on outcome:

- **All checks pass** → jump to Step 4 (self-review on green).
- **Any check fails** → continue to Step 2 (classify and fix).

## Step 2: Classify failures

For each failed check, fetch logs:

```
gh run view <run-id> --log-failed
```

Classify each failure into exactly one bucket. Apply rules in order — first match wins:

| Class | Detection heuristic | Auto-fix? |
|-------|---------------------|-----------|
| `format` | Output mentions `prettier`, `black`, `gofmt`, `rustfmt`, `ruff format`, `dprint`, `clang-format`. Or job name contains `format`/`fmt`. | Yes — re-run formatter, commit. |
| `lint` | Output mentions `eslint`, `tslint`, `flake8`, `pylint`, `golangci-lint`, `clippy`, `ruff check`. Or job name contains `lint`. Failures are line-and-rule-cited. | Yes — apply linter's suggested fixes, or dispatch a scoped subagent if the rule has no autofix. |
| `type` | Output from `tsc`, `mypy`, `pyright`, `flow`. Failures are `<file>:<line>: TS<code>: <msg>` or similar. | Yes — dispatch a scoped subagent with the failure list and the failing files. |
| `test-assertion` | Test output contains a unified diff between expected and actual at a single symbol (e.g., `expected: 42, got: 43`, or `assertEqual(a, b)` with clear delta). Single test, single assertion. | Yes — dispatch a scoped subagent with the failing test file and the assertion delta. |
| `test-logic` | Test failure is multi-line, indirect, or asserts on side effects (timing, race conditions, mock interactions). | **No** — surface as `[human]`. |
| `build-infra` | Output mentions missing dependencies, network errors, runner-image issues, missing env vars, secrets unavailable. | **No** — surface. CI config and secrets are not auto-fix territory. |
| `security` | Job name or workflow name contains `security`, `sast`, `codeql`, `snyk`, `trivy`, `audit`. Or output cites a CVE / advisory. | **Never** — always `[human]`, even for trivial-looking warnings. |
| `unknown` | Doesn't match any of the above heuristics. | **No** — surface. |

**Astronomer's `.github/actions` directory is the heuristic-pattern source.** When refining or adding rules, mirror the patterns Astronomer uses (e.g., their `auto-format-on-fail` action's detection logic, their lockfile-regeneration trigger, their flaky-test retry policy) — port the detection inline, do not depend on the action externally. Cite the source action by name in any new rule added to this table.

## Step 3: Compute failure signature, check no-progress, dispatch fixes

**Compute signature.** Build a deterministic signature for this CI run:

```
sig = sha1(sorted(
  [f"{job.name}:{first_failure_line_hash(job.log)}" for job in failed_jobs]
))
```

Where `first_failure_line_hash` is the first non-progress, non-timestamped line in the failed job's log (skip `==>`, `[INFO]`, ANSI codes, etc.). If `sig == prior_signature`: **no-progress halt**. Same failures haven't been resolved by the prior fix attempt. Skip Step 3's fix dispatch, jump to Step 5 (halt and surface).

Otherwise, set `prior_signature = sig` and continue.

**Attempt cap check.** If `M > max_attempts`: halt. Skip fix dispatch, jump to Step 5.

**Halt on out-of-scope failures.** If any failed job classifies as `test-logic`, `build-infra`, `security`, or `unknown`: halt regardless of attempt count. These never auto-fix. Jump to Step 5.

**Dispatch fixes.** For each failure class with auto-fix capability (`format`, `lint`, `type`, `test-assertion`):

- **`format`**: dispatch one `general-purpose` `Agent` with this brief:
  > Run the project's formatter on the changed-files set: `<list>`. Use the project's standard invocation (`bun run format`, `npm run format`, `make format`, etc. — auto-detect from `package.json`/`Makefile`/repo conventions). After running, commit the result with message `ci-fix(format): apply <tool> to changed files`. Stage only the formatter's writes. Report files touched and the exact command used.

- **`lint`**: similar, but the brief asks the subagent to apply linter autofixes (`--fix` flag, or `--apply-suggestions`) where available, and only patch by hand when the rule is non-autofixable. Commit message: `ci-fix(lint): <one-liner from rule list>`.

- **`type`**: brief includes the type-error list (`<file>:<line>: <code>: <msg>`), instructs the subagent to read each cited file and patch the type narrowly. Commit message: `ci-fix(type): tighten <symbol> at <file>:<line>`.

- **`test-assertion`**: brief includes the failing test file, the assertion's expected/actual diff, and the symbol under test. Subagent patches the implementation OR the test (whichever the diff narrative implies). Commit message: `ci-fix(test): <symbol> assertion`.

After each subagent reports success: `git push origin <branch>` and append the new commit hash to `auto_fix_commits`. If `git push` is rejected (force-required, conflict with main rebased onto something), halt — that's `[human]`.

Increment `M`. Write outcome file for attempt `M-1` (with the fix-attempt commit hashes), then return to Step 1 to re-poll CI.

## Step 4: Self-review on green

Reached when `gh pr checks` returns all-pass.

If `no_review == true`: skip this step entirely. Post a brief comment summarizing CI history (no review section) and jump to Step 6.

Otherwise dispatch self-review subagents:

**Always-on**: security review. Dispatch the OMC `security-reviewer` agent (one `general-purpose` `Agent`):
> You are running a security review. Read the full diff of PR #<pr_number> via `gh pr diff <pr> | head -5000` and any specific files cited. Your remit: identify security-relevant issues introduced by this PR — auth bypasses, injection vectors, secret leaks, missing input validation, broken access control, dependency CVEs, insecure defaults. Use the criteria from `~/.claude/skills/review/SKILL.md`'s "What Counts As A Bug" section, scoped to security. Return a structured report: list of findings (one per issue, severity tagged), or "clean" if nothing meets the bar.

**Conditional**: `/review` on auto-fix diff. Run only if `len(auto_fix_commits) > 0`:
> You are reviewing a delta. The original PR diff was already reviewed in-loop pre-PR. Your job is narrower: review ONLY the diff added by `/watch-ci`'s auto-fix commits — `git diff <last-non-auto-fix-commit>..HEAD`. Identify issues the original-author would fix per `~/.claude/skills/review/SKILL.md`. Common concerns to weight: did the formatter or linter mask a real bug; did the type-fix narrow correctly or paper over a wider issue; did the assertion-patch fix the symptom but miss the cause. Return findings or "clean".

If `len(auto_fix_commits) == 0`, skip the `/review` dispatch — the original diff already had its in-loop review.

Wait for both subagents (when both dispatched). Collect reports.

## Step 5: Halt path (for any halt reason)

Halt reasons (any of):

- No-progress detection (Step 3).
- Max attempts hit (`M > max_attempts`).
- Out-of-scope failure (`test-logic`, `build-infra`, `security`, `unknown`).
- `git push` rejected.
- CI poll exceeded 30-minute window.

On halt:

- Write the outcome file for attempt `M` with halt reason and full failure-class breakdown.
- Post a single structured comment on the PR via `gh pr comment <pr_number> --body-file -`:

  ```
  ## /watch-ci halted

  **Attempts:** <M>/<max_attempts>
  **Reason:** <halt reason — short>
  **Auto-fix history:** <commit hashes pushed this run, or "none">

  **Pending action:**
  <For each unfixed failure class:
    - <class>: <job names>
    - Logs: <gh run view URL>
    - Recommended: <human action>
  >

  Re-invoke `/watch-ci pr_number=<N>` after resolving in your local checkout, or hand off to `/setup-worktree phase=<N>` for an isolated checkout.
  ```

- Surface halt state to chat. Exit non-zero. **Do not submit Approve.**

> **Explicit rule:** watch-ci never invokes diagnose. On exhaustion, it produces the handoff artifact and halts. The calling workflow is responsible for routing to diagnose.

## Step 6: Post review comment + Approve gate

Reached on green CI with self-review (or `no_review == true`) complete.

**Post the comment.** Always post a single structured comment summarizing CI + review history:

```
## /watch-ci summary

**CI status:** all checks pass
**Attempts:** <M>/<max_attempts>
**Auto-fix history:**
<For each commit in auto_fix_commits:
  - `<short-hash>` ci-fix(<class>): <subject>
If empty: "No auto-fixes needed — CI passed first try.">

## Security review findings
<Verbatim from the OMC security-reviewer agent's report. If clean: "No security issues found.">

## /review on auto-fix diff
<Only present if auto_fix_commits non-empty. Verbatim from /review subagent. If no auto-fixes: omit this section.>

## Verdict
<One of:
  - **Approved by /watch-ci self-review pass.** (when security review clean AND (no auto-fixes OR /review on auto-fix clean) AND no_approve == false)
  - **Changes requested.** Findings above need human review before merge.
  - **Self-review skipped** (no_review == true). Manual review recommended before merge.>
```

Post via `gh pr comment <pr_number> --body-file <path-to-comment-file>`.

**Approve gate.** Submit Approve only when ALL of:

- Security review (OMC `security-reviewer` agent) returned clean (no findings).
- Either no auto-fix commits OR `/review` on auto-fix diff returned clean.
- `no_approve == false`.
- `no_review == false` (skipping review means we can't approve — human can override after manual inspection).

If gate passes:

```
gh pr review <pr_number> --approve --body "Approved by /watch-ci self-review pass."
```

Verify Approve landed via `gh pr view <pr_number> --json reviews -q '.reviews[-1]'`. Record success in outcome file.

## Step 7: Write outcome file

Save to `docs/executions/.ci-runs/<date>-pr-<pr_number>-attempt-<M>.md` with this structure:

```
# /watch-ci attempt <M> — PR #<pr_number>

**Date:** <YYYY-MM-DD>
**Branch:** <branch>
**Base:** <base>
**Attempt:** <M>/<max_attempts>
**Mode:** live | dry_run

## CI runs
<Table: job name | workflow | status | duration | log URL>

## Failure classes
<Per failed job:
  - **<job name>** — class: <class>
  - Log excerpt: <first ~10 lines of failure>
  - Auto-fix proposed: <yes — <command/subagent brief> | no — surfaced to human>>

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

## Self-review (only present in final-attempt outcome file with green CI)
- security-review (OMC security-reviewer): <clean | N findings>
- /review on auto-fix diff: <clean | N issues | N/A no-auto-fixes>
- Verdict: <Approved | Changes requested | Self-review skipped>
- Comment posted: <yes — <comment URL> | no>
- Approve submitted: <yes | no — <reason>>

## Verdict
<one of: would-have-fixed (dry_run) | fixed | halted (no-progress) | halted (max-attempts) | halted (out-of-scope) | green-first-try | approved | changes-requested>
```

## Step 8: Surface to user

Print to chat:

- One-sentence summary: `"PR #<N> — <verdict>: <K> auto-fix commits, security-review <clean|N findings>, /review on auto-fix <clean|N issues|N/A>, Approve <submitted|withheld|skipped>."`
- PR URL.
- Pointer to outcome file: `docs/executions/.ci-runs/<date>-pr-<N>-attempt-<M>.md`.
- If halted: the specific blocker and recommended next step.
- If approved: "Ready for human merge."

## Output Format

Markdown at `docs/executions/.ci-runs/<date>-pr-<N>-attempt-<M>.md`, structured per Step 7. One file per attempt. The final attempt's file carries the self-review and Approve outcomes. PR comment is posted via `gh pr comment`. Approve is submitted via `gh pr review --approve` (gated).

## Classifier rules

The Step 2 classifier table is the canonical reference. Maintenance rules:

- **First-match-wins.** Order in the table matters — `format` checked before `lint` because formatters often run as lint plugins.
- **Heuristics target output, not workflow names alone.** Job names lie ("test" jobs that include lint steps). Inspect the failure log first; fall back to job name only when the log is ambiguous.
- **Astronomer-actions reference.** The `astronomer/.github/actions/` directory holds custom actions Astronomer uses for CI auto-fix in their own repos. Port detection patterns inline; do not call those actions externally. Cite the source action name in any rule that mirrors one (e.g., `# mirrors astronomer/auto-format-on-fail v2.1`).
- **Adding a class.** Two questions: (1) Is the failure class deterministic enough to auto-fix without human judgment? (2) Is the fix bounded — i.e., does the subagent's scope cover the failure without spilling into adjacent code? If either is no, surface to human. Do not add a class with weak boundaries.

## Error Handling

| Failure | Behavior |
|---------|----------|
| `gh auth status` fails | Abort with token-scope guidance. Token mutation is `[human]`. |
| Working tree dirty | Abort. Auto-fix commits need a clean baseline. |
| `pr_number == 0` and no PR for branch and no body file findable | Abort. User must pass `body_path=` or run `/describe-pr` first. |
| `pr_number == 0`, auto-create PR fails | Abort with the `gh pr create` error message verbatim. |
| CI poll exceeds 30-minute window with runs stuck queued/in-progress | Halt. Surface CI infra issue to human. |
| Failed job classifies as `test-logic` / `build-infra` / `security` / `unknown` | Halt regardless of attempt count. Surface to human via PR comment. |
| Same failure signature in two consecutive attempts | No-progress halt. Surface to human. |
| `M > max_attempts` | Halt. Surface to human. |
| Auto-fix subagent reports failure | Treat as that attempt's failure class. Halt if classification is out-of-scope; otherwise the next attempt re-classifies. |
| `git push` rejected (force-required, branch-protection blocks) | Halt — `[human]` to resolve. Don't force-push from this skill. |
| OMC `security-reviewer` agent fails / times out | Treat as `Changes requested` verdict; do not Approve. Surface to human. |
| `gh pr review --approve` fails | Keep the comment; surface the `gh` error; tell user to manually approve or investigate. |
| `dry_run == true` | Poll + classify only. Outcome file written marked `dry_run`. No commits, no comments, no Approve. |
| `no_review == true` | Skip Step 4 entirely. Post a comment with CI history only. Cannot Approve (gate requires review). |
| `no_approve == true` | Run review pass normally. Post comment with verdict. Skip the `gh pr review --approve` call regardless of cleanness. |
| Astronomer reference dir not present locally | Skip the cross-reference; classifier still works from the inline table. Note in Tuning notes that pattern-source guidance is unavailable. |

## Exhaustion Handoff

When auto-fix exhausts (3 attempts with no progress toward green), emit a structured handoff artifact instead of silently halting:

### Handoff artifact format

```markdown
## CI Exhaustion Handoff — [PR #N]

**Workflow:** [workflow name that failed]
**Job:** [specific job name]
**Classification:** [lint | type-error | test-failure | build-failure | deploy-failure | timeout | unknown]
**Attempts:** 3/3 (exhausted)

### Failure pattern
[Concise description of what's failing and why auto-fix couldn't resolve it]

### Log excerpt
\`\`\`
[Relevant error lines from the most recent failure — max 50 lines]
\`\`\`

### Attempts tried
1. [What was tried in attempt 1 + why it didn't work]
2. [What was tried in attempt 2 + why it didn't work]
3. [What was tried in attempt 3 + why it didn't work]

### Suspected root cause
[Best guess based on the pattern — may be wrong, diagnose should verify]

### Recommended diagnosis mode
[quick | standard | deep | regression — based on failure complexity]
```

### Rules

- watch-ci does NOT invoke diagnose directly — it produces the artifact and halts
- When issue context is available, write to `docs/tasks/{issue-number}-{slug}/ci-handoff.md`. Fallback: `docs/executions/ci-handoffs/{pr-number}-{date}.md`
- workflow-debug or workflow-build-one will pick up the artifact and route to diagnose
- The artifact must be self-contained: diagnose should be able to start without re-reading CI logs

## Example Invocation

Clean PR, CI passes first try, auto-Approve:

```
User: /watch-ci pr_number=142
Claude: [preflight: gh auth ok, branch fix/phase-1-mobile-scroll, PR #142 valid]
        [poll: all checks pass, no failures]
        [security-review (OMC security-reviewer): clean]
        [no auto-fix commits → skip /review on auto-fix]
        [post comment, Verdict: Approved]
        [gh pr review --approve submitted]
        [outcome: docs/executions/.ci-runs/2026-04-22-pr-142-attempt-1.md]

        PR #142 — approved: 0 auto-fix commits, security-review clean,
        /review on auto-fix N/A, Approve submitted.
        https://github.com/myorg/myrepo/pull/142
        Ready for human merge.
```

CI fails twice with auto-fixable lint, fix lands, Approve:

```
User: /watch-ci pr_number=143
Claude: [attempt 1: poll, lint failure detected (eslint, 4 rules)]
        [classify: lint — auto-fix eligible]
        [dispatch eslint --fix subagent, commits, push]
        [outcome: attempt 1 file written]

        [attempt 2: poll, type failure detected (tsc, 1 error in src/auth.ts:42)]
        [signature differs from attempt 1 — progress]
        [classify: type — auto-fix eligible]
        [dispatch type-fix subagent, commits, push]
        [outcome: attempt 2 file written]

        [attempt 3: poll, all checks pass]
        [security-review (OMC security-reviewer) on PR diff: clean]
        [/review on auto-fix diff (2 commits): clean]
        [post comment, Verdict: Approved]
        [gh pr review --approve submitted]

        PR #143 — approved: 2 auto-fix commits, security-review clean,
        /review on auto-fix clean, Approve submitted.
```

CI fails with un-fixable test-logic, halt:

```
User: /watch-ci pr_number=144
Claude: [attempt 1: poll, test failure detected]
        [classify: test-logic (multi-line failure, asserts on timing)]
        [out-of-scope — halt]
        [post comment, Verdict: Changes requested]
        [outcome: attempt 1 file with halt reason]

        PR #144 — halted (out-of-scope): test-logic failure in
        tests/scheduler.test.ts. Logs: <run URL>.
        See PR comment for human action.
```

PR auto-creation:

```
User: /watch-ci
Claude: [preflight: branch feat/phase-1-dark-mode, no PR exists]
        [find body: docs/executions/.pr-bodies/2026-04-22-pr-feat-phase-1-dark-mode.md]
        [gh pr create succeeded → PR #145]
        [proceeds to Step 1 with pr_number=145]

        PR #145 created for branch feat/phase-1-dark-mode. Watching CI.
```

## Tuning notes

- **Lower `max_attempts` for expensive CI.** If your CI takes >10 minutes per run, drop `max_attempts=2` to cap blast radius. Three attempts at 10 min each is 30 min of CI burn before halt.

- **Raise `max_attempts` for flaky-test repos.** When tests genuinely flake, two attempts may dismiss a fix that would have stuck. Raise to 5 — but watch for runaway loops via the no-progress detector still catching them.

- **`dry_run` is cheap.** Run it on any unfamiliar repo before turning the loop loose. Confirms CI integration, classification rules, and `gh` auth work end-to-end without side effects.

- **`no_approve` for repos requiring named human reviewers.** Some repos enforce branch protection requiring approvals from specific users. Self-Approve from the PR author's `gh` identity won't unblock those. Set `no_approve=true` and let a human approve after seeing the structured comment.

- **`no_review` for fast-iteration mode.** Skips both reviews. Use only when you've already reviewed manually outside the loop and just want CI babysitting. The Approve gate will refuse to fire (review required) — manual approve afterward.

- **When to use `/setup-worktree`.** When `/watch-ci` halts (out-of-scope or no-progress) and you want to fix in an isolated checkout while continuing other work on main, run `/setup-worktree branch=<halted-branch>` and resolve there. Then re-invoke `/watch-ci pr_number=<N>` from the worktree (or after pushing the fix from the worktree to update the PR).

- **Auto-fix scope discipline.** `/watch-ci`'s subagents inherit the scope-based isolation pattern from `/execute-phase`: each fix subagent is given an explicit changed-files scope in its brief, and the post-fix `git status` is implicitly scope-checked by the auto-fix-only commit pattern (anything outside the failure's cited files would surface in the commit but not be a fix — flagged in the next iteration's classification).

- **Astronomer reference patterns.** When working in an Astronomer-adjacent repo, read `astronomer/.github/actions/` first to see what custom actions are in play. Mirror their detection logic inline in this skill's classifier rules; cite the source by name in any new rule.

- **The Approve is the riskiest action this skill takes.** All other writes are reversible (push commits, PR comments). Approve, once submitted, is dismissable but visible in the PR's review history. The triple gate (security review clean + `/review` on auto-fix clean if applicable + `no_approve` unset + `no_review` unset) is deliberately strict.

## Pairing with the core loop

```
/repo-audit (optional)
     ↓
/design-plan (audit OR brief mode)
     ↓
/execute-phase ({refactor,fix,feat}/phase-* branches)
     ↓
/review (workspace reviewer subagent, in-loop)
     ↓
/post-mortem (writes retro citing NEW-NN)
     ↓
/describe-pr (PR body cites retro)
     ↓
[human gh pr create — or this skill auto-creates if no PR]
     ↓
/watch-ci (this skill)
     ↓
[human merge]

(on-demand side-car: /setup-worktree → isolated checkout for human review or halt resolution)
```

`/watch-ci` is the closing skill in the post-PR-open chain. `/post-mortem` later (in the next loop) reads `.ci-runs/` outcome files alongside `.phase-runs/` to attribute post-PR discoveries (flaky tests, security findings deferred, deps that needed pinning) as `NEW-NN` candidates for promotion to `FIND-NN` in the next `/repo-audit`.

All seven skills share ID vocabulary (`FIND-NN`, `REQ-NN`, `NEW-NN`, ticket slugs, phase numbers) and `docs/` artifact conventions. `/watch-ci` is the only skill that writes to GitHub directly (PR comments, Approve reviews); all others write only inside `docs/`.
