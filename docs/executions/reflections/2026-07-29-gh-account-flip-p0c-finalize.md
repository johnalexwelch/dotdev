# Session Reflection: gh account flip during P0c finalize + stacked-PR CI regression

**Date**: 2026-07-29
**Goal**: Ship 3 P0c follow-ups (data-eng issue #132, capture-tooling PR #1597, stale-fixture fix on #1594) via subagents; then cleanup + merge #1597 per workflow-finalize; then unblock #1594 CI.

## What Went Well
- **Taskflow DAG with correct side-effect ordering**: task 3 (personal-account `gh` issue) ran *first* so it could switch to the personal account and restore the work account before the two iris pushes ran in parallel — preventing wrong-account pushes. Verified the DAG before running.
- **Ground-truth over subagent self-reports**: independently re-verified issue #132, PR bases, commit stats, and re-ran the graded-fact audit rather than trusting the three subagents' "done" claims.
- **Independent review caught a real bug**: Codex flagged a P2 reproducibility gap in `capture_numeric.py` (script didn't emit `n_groundable`/`empty_pairs`); a reviewer fork then found C1 (per-result `groundable` drift). Both fixed and verified by recomputing over the committed artifact (zero mismatches).
- **Precise regression diagnosis**: traced 7 failing #1594 tests to one line (`harness.py:276` `str.join` over now-dict facts); minimal 3-line fix; verified the full `tests/eval/test_analyst_production_replay.py` file (19 passed) before pushing.
- **Held the HITL line**: #1594 became CLEAN/MERGEABLE but was left unmerged because it is a #127 reviewer-validation ticket — did not merge on the user's behalf.

## What Went Wrong / Friction
- **`gh` active account silently reset to the personal account repeatedly — even mid-bash-block.** A background process kept rewriting `~/.config/gh/hosts.yml` back to `johnalexwelch`, which has no `classdojo/iris` access. This produced misleading `Could not resolve to a Repository` / `Not Found` errors and, once, an **empty `gh pr merge` output** that made a *successful* merge look ambiguous. Cost ~4 retries and a ground-truth re-check to confirm the merge landed.
  - **Better way found**: pin identity per-call with `GH_TOKEN=$(gh auth token --user alexwelch-dojo)` — this bypasses the mutable active-account entirely and is immune to the flip. `gh auth switch` at the top of a block is NOT reliable (the flip can happen between sequential commands in the same shell). `git push` was never affected (SSH key auth), only `gh` REST/GraphQL.
- **A latent P0a regression escaped to CI.** Merging #1597 into `loop/p0a` re-triggered Backend CI, which surfaced a bug the P0a slice introduced (dict facts breaking a raw `seed.yml` reader in the replay harness). It escaped because the P0a session verified with `pytest tests/unit/eval/` only — but the harness lives in `tests/eval/`. Scoped test subset was a proxy for the authoritative full suite.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | (none — user only asked "should we merge it?" and gave "go") | n/a | n/a |

No direct corrections; findings below are Pass-B opportunities.

## Lessons
1. **Multi-account `gh` needs token pinning, not `auth switch`.** In an environment where something resets the active account, `gh auth switch` is a proxy for identity that can go stale within one shell. `GH_TOKEN=$(gh auth token --user <acct>)` is the authoritative, flip-proof form. Silent/empty `gh` output ≠ failure — confirm state via a token-pinned read.
2. **Eval verification must span `tests/eval/` AND `tests/unit/eval/`.** Golden-fixture schema changes ripple into the replay harness and other `tests/eval/` consumers that read `seed.yml` raw. A `tests/unit/eval/`-only run is a false green.
3. **Merging a stacked child into its parent re-triggers the parent's full CI** and can surface latent parent-branch regressions unrelated to the child. Expect it; treat the parent's post-merge CI as the real gate.

## Proposed Improvements
- [ ] `docs/agents/habits.md` — add a habit: "Multi-account GitHub: pin `GH_TOKEN=$(gh auth token --user <acct>)` per `gh` call rather than relying on `gh auth switch`; the active account can be reset out from under you. Empty `gh pr merge` output is not proof of failure — confirm with a token-pinned `gh pr view`." (priority: high)
- [ ] `dotfiles/.config/agents/skills/workflow-finalize/SKILL.md` — in the Step 6 verification note, add eval-specific guidance: golden-SQL/fixture changes must run `tests/eval/` (harness/replay consumers that read `seed.yml` raw) in addition to `tests/unit/eval/`; a unit-scoped run is a false green. (priority: med)
- [ ] Investigate the background process rewriting `~/.config/gh/hosts.yml` to `johnalexwelch` (herdr worktree hook? launchd agent?) — root-cause the flip rather than only working around it. (priority: med, not a skill edit)

## Skill Extraction Candidates
<!-- GH_TOKEN pinning is a one-line habit, not a multi-step workflow → routed to habits.md, not a new skill. Taskflow multi-account parallel-PR orchestration is already covered by taskflow. No new skill warranted. -->
