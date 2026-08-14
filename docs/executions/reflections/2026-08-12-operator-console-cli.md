# Session Reflection: Operator Console CLI

**Date**: 2026-08-12
**Goal**: Build agent messaging in Talk surface — `chorus send/inbox` without separate CLI sessions

## What Went Well

- Fork-based independent review worked cleanly for `fast` profile
- `git-forge` wrapper elegantly handles GitHub vs Forgejo dispatch
- Roadmap/decision-log updates kept in sync with code changes
- Test-first approach caught `minimal_registry` fixture gap early

## What Went Wrong / Friction

- Worktree drifted behind origin/main after PRs merged → stash/reset dance
- `--wait` changes existed only in memory, had to re-implement after reset
- Multiple `git-forge` debugging cycles (jq errors, API format)
- Forgejo token scope issues with `tea` CLI → fell back to curl

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| 1 | "Why still using GitHub?" | workflow-finalize assumes gh CLI | workflow-finalize |
| 2 | "Forgejo for personal only" | Assumed Forgejo was universal | AGENTS.md scope |

## Lessons

1. **Commit early, commit often**: The `--wait` feature was "done" in my head but never committed — lost on worktree reset. Working code that isn't committed doesn't exist.

2. **Worktree hygiene before new work**: When picking up a worktree after PRs merged to main, sync it first. A `git fetch && git log HEAD..origin/main` check would have shown the drift.

3. **Forgejo ≠ GitHub API**: PR create/merge/list calls differ. The `git-forge` wrapper pattern (detect origin, dispatch to correct API) is the right abstraction.

## Proposed Improvements

- [ ] `workflow-finalize` — Add Forgejo branch: detect origin URL, use `git-forge` or direct API (priority: med)
- [ ] `workflow-build-one` — Add pre-commit check: "is worktree behind origin/main?" (priority: low)
- [ ] `decision-log` — Add "mark capability DONE" recipe template (priority: low)

## Skill Extraction Candidates

None — the `git-forge` wrapper is infrastructure, not a repeatable workflow skill.
