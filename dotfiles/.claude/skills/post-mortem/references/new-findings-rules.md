# NEW-NN Classification Rules

Load this during Step 3 when identifying new findings.

Execution almost always surfaces things the audit missed. Look for:

- Commits that mention "fix" or "workaround" without a phase tag.
- Files added that are not in the plan.
- Tests added in one phase that reveal problems in another.
- `TODO`, `HACK`, or `FIXME` comments added during execution.
- PR descriptions or commit messages naming concerns such as "punting on X for now" or "found Y, not fixing here".
- Rollbacks that happened before the phase succeeded.
- `/watch-ci` outcome files that identify flaky tests, dependency pinning, deferred security findings, or no-progress halts.

Each new finding gets a placeholder ID of the form `NEW-01`, `NEW-02`, and so on. These are intended to be promoted to full `FIND-NN` IDs the next time `/repo-audit` runs.

For each `NEW-NN`, record:

- Title.
- Source: commit hash, file path, phase-run, CI-run, PR comment, or conversation.
- Severity: critical, high, medium, or low.
- Impact: one sentence.
- Recommendation: promote to `FIND-NN` in next `/repo-audit`, fix inline, or defer.
