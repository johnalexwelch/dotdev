# Post-Mortem Evidence Checklist

Load this during Step 1 before mapping plan to reality.

Read `.phase-runs/` first. If `docs/executions/.phase-runs/` exists, glob `*-phase-*.md` and read the outcome files whose `**Plan:**` header matches `plan_path`. These are richer signal than raw `git log`: commits mapped to tasks, pending-human items, scope violations, and `NEW-NN` candidates.

Then read `.ci-runs/` if present. If `docs/executions/.ci-runs/` exists, glob `*-pr-*-attempt-*.md` and read outcome files whose PR or branch references match this plan's phase branches. Add follow-up discoveries to `## New findings` with `Source:` cited as the relevant `.ci-runs/` file.

Collect ground truth from git and the working tree:

1. Commits in range: `git log --oneline <since>..HEAD`; note count and intent drift in commit messages.
2. Files changed: `git diff --stat <since>..HEAD`; compare changed line counts to the plan's delete list.
3. Phase branches: `git branch -a | grep -E '(refactor|fix|feat)/phase-'` and `git log --oneline <since>..HEAD --grep="phase-"`; note merged, open, deleted, and branch prefix.
4. Test status now: run the test command; note pass/fail and material coverage drift from the audit.
5. Files deleted: `git log --diff-filter=D --name-only <since>..HEAD`; compare to the plan's §8 Delete list.
6. Documentation changes: `git log --oneline <since>..HEAD -- '*.md'`; note whether docs kept up.

Fall back to `git log` alone only when `.phase-runs/` is absent or does not cover the commit range.
