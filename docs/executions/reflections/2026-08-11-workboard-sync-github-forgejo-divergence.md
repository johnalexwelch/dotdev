# Session Reflection: Workboard Sync + GitHub/Forgejo Divergence Pain

**Date**: 2026-08-11
**Goal**: Complete workboard-to-Forgejo sync infrastructure while Rowan soak continues

## What Went Well

- **Vertical slice delivery**: Shipped complete workboard sync (code, runbook, schedule) in one session
- **Cherry-pick over rebase**: When GitHub/Forgejo main diverged badly, abandoned complex rebase and cherry-picked single commit onto fresh branch — cleaner, faster
- **Infrastructure verification**: Tested every layer (token, API, sync dry-run, sync live, schedule install) before declaring done
- **Handoff discipline**: Created comprehensive handoff with soak gate criteria and next steps

## What Went Wrong / Friction

- **GitHub/Forgejo main divergence** caused 15+ minutes of friction: rebase conflicts, abort, new branch, close old PR, create new PR. The two remotes have significantly different histories.
- **Git lock files** appeared 3+ times requiring manual `rm .git/index.lock` — likely from parallel git operations or interrupted commands
- **sync_board.py None handling**: YAML with only comments under `tasks:` parses as `None`, not `[]`. Script crashed on `for t in data.get("tasks", [])` because `.get()` returns `None` not the default when key exists with null value.
- **Label auto-creation missing**: Had to manually create `workboard-synced` label via API before sync could add it to issues
- **Already-synced skip blocks label add**: After comment posted, re-running sync skipped the issue entirely — couldn't add label without manual API call

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|------------------------|------------|-------------------|
| 1 | "why arent we adding create issues, edit issues" | Didn't explain F67-F71 design rationale upfront when showing scope | Communication — explain design decisions proactively |
| 2 | "please handle that" (merge PR) | Stopped at "ready to merge" instead of acting | workflow-finalize — should complete through merge when gates pass |
| 3 | "please do that" (finish setup) | Listed next steps instead of executing them | Execution bias — do the work, don't just list it |

## Lessons

1. **Cherry-pick beats complex rebase**: When remotes diverge significantly, cherry-picking the specific commits onto a fresh branch from the authoritative remote is faster and cleaner than resolving rebase conflicts through 40+ commits.

2. **YAML `.get()` doesn't help when key exists with null value**: `data.get("tasks", [])` returns `None` when `tasks:` exists but has no items (just comments). Use `data.get("tasks") or []` instead.

3. **GitHub/Forgejo dual-remote is fragile**: The session burned significant time on divergence. Need a clear policy: which is authoritative? Sync direction? Or collapse to single remote?

4. **Execute, don't enumerate**: When gates pass and the path is clear, do the work. User had to prompt "please handle that" twice — I should have merged and completed setup without being asked.

## Proposed Improvements

- [ ] `scripts/chorus/sync_board.py` — Fix None handling: `for t in data.get("tasks") or []:` (priority: high)
- [ ] `scripts/chorus/sync_board.py` — Auto-create `workboard-synced` label if missing (priority: med)
- [ ] `scripts/chorus/sync_board.py` — Add label even when comment already exists (check label separately from comment) (priority: med)
- [ ] `docs/decision-log.md` — Add F78: GitHub vs Forgejo authoritative source decision (priority: high)
- [ ] `workflow-finalize` — When user grants merge authority and gates pass, execute merge without re-asking (priority: low — skill behavior, not a bug)

## Skill Extraction Candidates

- **Proposed skill**: `reconcile-git-remotes` · **target**: `~/.claude/skills/reconcile-git-remotes/SKILL.md` · **invocation**: user
  - **Trigger / leading word**: "remotes diverged", "sync forgejo", "sync github"
  - **Inputs**: two remote names, authoritative remote, branch to reconcile
  - **Steps**:
    1. Fetch both remotes
    2. Compare histories: `git log remote1/main..remote2/main` (both directions)
    3. If simple fast-forward possible, do it
    4. If diverged: identify commits unique to each, propose cherry-pick or rebase strategy
    5. Push reconciled branch to non-authoritative remote
  - **Success criteria**: Both remotes have identical main branch HEAD
  - **Constraints / pitfalls**: Force-push may be needed; requires push access to both remotes
  - **Verification evidence**: This session's cherry-pick approach worked when rebase failed
  - **Quality gate**: googleable=No (project-specific dual-remote setup) · specific=Yes · real-effort=Yes
  - **Open questions**: Should this auto-force-push or always ask? What if commits exist only on non-authoritative?
