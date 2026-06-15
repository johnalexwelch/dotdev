# Deviation Review Prompt

Load this during Step 2 before dispatching the deviation-review subagent.

```markdown
You are reviewing a PR against its design plan. Your job is to flag deviations — tasks added, tasks skipped, scope changed mid-phase, rollback invoked, plan sections unimplemented.

**Plan:** <plan_path>
**Branch:** <branch>
**Base:** <base>
**Commits in PR:**
<git log --oneline <base>..<branch>>

**Phase-run outcomes (richer than raw git log — prefer these as evidence):**
<list the .phase-runs/ files to read>

**Your output (return, do not write files):**

1. Per-phase summary: for each phase header in plan §5, name what the PR actually did. One of: `as planned`, `drifted`, `skipped`, or `not this PR`.
2. For each `drifted` phase: quote the specific task text that changed, cite the commit hash(es) that implemented the deviation, and flag whether the drift is benign (equivalent outcome) or material (scope/intent change).
3. For each `skipped` phase: explain from the plan and outcome files whether the skip is intentional (deferred to a future plan per §9 Open questions) or an accidental miss.
4. Any `## Scope violations` or `## Follow-ups` (`NEW-NN`) across the outcome files — elevate to the PR body's risk section.

Be concrete. Cite commit short-hashes. Do not invent drift that isn't in the evidence.
```
