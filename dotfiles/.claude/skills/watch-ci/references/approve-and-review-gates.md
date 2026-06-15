# Review Monitoring And Draft Handoff Gates

Load this reference when CI is green, before posting a green summary comment or handing the draft PR back to the user.

`/watch-ci` never submits approval, never marks the PR ready for review, never merges, and never enables auto-merge. The user reviews the draft PR and decides when to mark it ready.

## Self-Review And Reviewer-Agent Monitoring

If `no_review == true`, skip launching self-review agents only when one of these is recorded in the outcome file:

- explicit user waiver accepting the risk
- complete `WORKFLOW_REVIEW_GATE` with `review_profile`, `independent_review: true`, and `verdict: APPROVE` plus an explicit user waiver for skipping `/watch-ci` self-review

If neither exists, halt. Existing PR review comments still must be monitored and incorporated or resolved before handoff.

Otherwise dispatch:

### Always: Security Review

Dispatch the OMC `security-reviewer` agent:

```text
You are running a security review. Read the full diff of PR #<pr_number> via `gh pr diff <pr> | head -5000` and any specific files cited. Your remit: identify security-relevant issues introduced by this PR - auth bypasses, injection vectors, secret leaks, missing input validation, broken access control, dependency CVEs, insecure defaults. Use the criteria from `~/.claude/skills/review/SKILL.md`'s "What Counts As A Bug" section, scoped to security. Return a structured report: list of findings (one per issue, severity tagged), or "clean" if nothing meets the bar.
```

### Conditional: `/review` On Auto-Fix Diff

Run only if `auto_fix_commits` is non-empty:

```text
You are reviewing a delta. The original PR diff was already reviewed in-loop pre-PR. Your job is narrower: review ONLY the diff added by `/watch-ci`'s auto-fix commits - `git diff <last-non-auto-fix-commit>..HEAD`. Identify issues the original-author would fix per `~/.claude/skills/review/SKILL.md`. Common concerns to weight: did the formatter or linter mask a real bug; did the type-fix narrow correctly or paper over a wider issue; did the assertion-patch fix the symptom but miss the cause. Return findings or "clean".
```

If `auto_fix_commits` is empty, skip `/review` only if the original diff already had its in-loop review. If this skill created reviewer-feedback fix commits, run `/review` on those commits too.

If a review agent fails or times out, treat the verdict as `Changes requested`; do not hand back as clean.

## Active Monitoring Loop

After CI is green and review agents have had a chance to respond:

1. Fetch all review-level and inline feedback:

   ```bash
   gh api repos/<owner>/<repo>/pulls/<pr_number>/reviews
   gh api repos/<owner>/<repo>/pulls/<pr_number>/comments
   ```

2. Run `receive-review` on all active comments.
3. Incorporate all valid feedback, including:
   - blockers
   - non-blockers
   - comments
   - observations
   - questions
   - nits
4. Push feedback-fix commits.
5. Return to CI polling because fixes may trigger CI or new reviews.
6. Repeat until no actionable feedback arrives for `review_quiet_minutes`.

Only halt instead of incorporating feedback when a suggestion is technically invalid, conflicts with another reviewer, contradicts a project invariant, or requires product/human judgment. In that case, present the conflict to the user with evidence.

## Reviewer-Comment Gate

Before a clean draft handoff verdict, fetch active review feedback:

```bash
gh api repos/<owner>/<repo>/pulls/<pr_number>/reviews
gh api repos/<owner>/<repo>/pulls/<pr_number>/comments
```

Classify every active reviewer comment:

| State | Meaning | Gate |
|-------|---------|------|
| Fixed | A later commit clearly addresses the comment and the thread has a reply citing it. | Pass |
| Replied with evidence | The comment was declined or clarified with a substantive reply. | Pass |
| Acknowledged | Praise or informational comment has a brief acknowledgment reply. | Pass |
| Human waived | The user explicitly accepted the risk or deferred it. | Pass |
| Unanswered | No fix, no reply, no waiver. | Block |
| Blocker unresolved | Reviewer requested changes and the concern is still present. | Block |

If any comment is `Unanswered` or `Blocker unresolved`, do not hand back as clean. Invoke `receive-review` when actionable; otherwise post a `Changes requested` summary and halt for human input. Record unresolved comments in the outcome file.

## Draft Handoff Gate

Hand the draft PR back as clean only when all conditions are true:

- Security review returned clean, or `no_review=true` has an explicit user waiver, or a complete `WORKFLOW_REVIEW_GATE` with `review_profile`, `independent_review: true`, and `verdict: APPROVE` plus an explicit user waiver for skipping `/watch-ci` self-review.
- Either there are no auto-fix/reviewer-feedback commits, or `/review` on those commits returned clean.
- Reviewer-comment gate passed: no unanswered comments and no unresolved blockers remain.
- The active monitoring loop observed no new actionable feedback for `review_quiet_minutes`.
- CI is green after all feedback-fix commits.

If the gate passes, post the summary comment and stop. Do not run any of:

```bash
gh pr review <pr_number> --approve
gh pr ready <pr_number>
gh pr merge <pr_number>
```

Record in the outcome file that the PR remains a draft awaiting user review.

## Tuning Notes

- Lower `max_attempts` for expensive CI. If CI takes more than 10 minutes per run, use `max_attempts=2` to cap cost.
- Raise `max_attempts` for flaky-test repos only when flakes are known and the no-progress detector remains active.
- `dry_run` is for unfamiliar repos: poll and classify without commits or comments.
- Use `no_review=true` only when review already happened outside the loop. Existing PR comments still must be resolved.
- Use `/setup-worktree` when `/watch-ci` halts and you want an isolated checkout for resolving the blocker, then re-invoke `/watch-ci pr_number=<N>` after pushing the fix.
- The final handoff is not a merge signal. It means the agent believes CI is green and review feedback is incorporated, but the user still decides when to mark the draft PR ready.
