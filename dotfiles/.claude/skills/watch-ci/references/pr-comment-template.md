# PR Comment Templates

Load this reference before posting any `/watch-ci` PR comment. Post one structured comment per `/watch-ci` invocation.

In `dry_run`, do not post comments.

## Halt Comment

Post this when `/watch-ci` halts for no-progress, max attempts, out-of-scope failures, rejected push, CI timeout, or unresolved reviewer comments.

```markdown
## /watch-ci halted

**Attempts:** <M>/<max_attempts>
**Reason:** <halt reason - short>
**Auto-fix history:** <commit hashes pushed this run, or "none">

**Pending action:**
<For each unfixed failure class:
  - <class>: <job names>
  - Logs: <gh run view URL>
  - Recommended: <human action>
>

Re-invoke `/watch-ci pr_number=<N>` after resolving in your local checkout, or hand off to `/setup-worktree phase=<N>` for an isolated checkout.
```

Rules:

- Surface halt state to chat.
- Exit non-zero.
- Do not submit approval, mark ready, merge, or enable auto-merge.
- `watch-ci` never invokes `diagnose`; it writes the handoff artifact and halts. The calling workflow routes to diagnose.

## Green Summary Comment

Post this when CI is green, reviewer-agent feedback has been incorporated, and the draft PR is ready for user review.

```markdown
## /watch-ci summary

**CI status:** all checks pass
**Attempts:** <M>/<max_attempts>
**Auto-fix history:**
<For each commit in auto_fix_commits:
  - `<short-hash>` ci-fix(<class>): <subject>
If empty: "No auto-fixes needed - CI passed first try.">

## Security review findings
<Verbatim from the OMC security-reviewer agent report. If clean: "No security issues found.">

## /review on auto-fix diff
<Only present if auto_fix_commits is non-empty. Verbatim from /review subagent. If no auto-fixes: omit this section.>

## Reviewer feedback
<Summary of blockers, non-blockers, observations, comments, questions, and nits incorporated. Include unanswered count; must be 0 for clean handoff.>

## Verdict
<One of:
  - **Draft ready for user review.** CI is green, review agents are clean, and all actionable feedback has been incorporated or human-gated.
  - **Changes requested.** Findings above need human review before the draft can be marked ready.
  - **Self-review skipped.** Existing PR comments were handled, but manual review is still required.>
```

Post via:

```bash
gh pr comment <pr_number> --body-file <path-to-comment-file>
```
