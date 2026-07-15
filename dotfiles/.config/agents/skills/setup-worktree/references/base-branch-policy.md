# Workflow Base Branch Policy

Load this before creating or validating a workflow worktree.

## Resolution

1. Run `git fetch origin --prune`.
2. Prefer `origin/staging` when it exists.
3. If `origin/staging` is absent, resolve the remote default branch:

   ```bash
   git remote show origin | sed -n '/HEAD branch/s/.*: //p'
   ```

4. Use `origin/<default-branch>` only when that remote ref exists.
5. If neither `origin/staging` nor a valid remote default ref exists, halt and ask the user for the workflow base.

## Gate

Every mutating workflow must record the resolved base before implementation:

```markdown
WORKFLOW_BASE_GATE:
  preferred_base: origin/staging
  resolved_base: origin/staging|origin/<default-branch>
  fallback_reason: not_applicable|origin/staging_absent
  fetched: true
```

Worktree and review/finalize gates must use `resolved_base`, not a hard-coded branch.

Examples:

```markdown
WORKFLOW_BASE_GATE:
  preferred_base: origin/staging
  resolved_base: origin/main
  fallback_reason: origin/staging_absent
  fetched: true

WORKTREE_BASELINE_GATE: origin/main -> codex/example @ /Users/alexwelch/wt/repo/example
```

## Rules

- Do not use local `main`, local `staging`, or an unfetched cached ref as the base.
- Do not silently fall back to `origin/main`; record `WORKFLOW_BASE_GATE`.
- Stacked child worktrees still record the original resolved base in `STACKED_WORKTREE_GATE`.
- If a repository has a documented protected integration branch, add that policy to repo docs and treat it as the preferred base for that repo.
