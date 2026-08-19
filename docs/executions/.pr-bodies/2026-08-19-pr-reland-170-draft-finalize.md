# fix(workflow-ledger): re-land draft-PR finalize acceptance (#170 onto main)

## Summary

Re-lands PR #170's fix, which was lost off `main`: #170 (`fix(workflow-ledger): finalize stamp accepts draft PRs`, squash `ec61612`) merged into stacked parent `feat/phase3-review-finalize` **after** that parent had already landed via #169, so its commits were never reachable from `origin/main`. The finalize↔draft deadlock therefore persisted on main — `ledger.sh stamp finalize` required `pr_state=open` while the default `human-only` delivery policy keeps PRs draft — and every stamped run since (#171, #176) worked around it via a scratch `git worktree add --detach ec61612` checkout with `SKILLS_ROOT` repointed.

`checked_finalize()` now accepts forge `pr-state` of `open` **or** `draft` and records the actual state in the stamp's checked fields. Any other *reported* state (`merged`, `closed`, an error) still refuses; a real merged/closed PR is usually invisible to the open-PR lookup and records `forge=no_pr`, which stamps successfully with the forge checks skipped.

**This PR is its own proof:** the delivery run for this PR stamps `finalize` against this very draft PR using the re-landed kernel — the first stamped run since #169 that needs no workaround.

## What's in it

| Commits | Area | Content |
|---|---|---|
| `dd84409` → `3332f21` | kernel + test | Red-first re-land of #170's F3 fix (fix hunk byte-identical to `ec61612`); red test adapted to the batch-#8 sanitized flat mock names — the original nested mock path would have fake-passed via the leftover `none` lookup |
| `63e8d20`, `f64aab1` | docs | #170's siblings: verdict-token underscores in 21 reviewer-brief files (skills + `.pi` mirrors); finalize SKILL.md stale "Known collision" note replaced |
| `2c56ee6`, `455611f` | test + docs | Review R1 should-fixes: merged-refusal case, exact-message assert needles, mock-state restore; gate-table `open\|draft` wording; decision-log resolution entry (append-only, 4 insertions 0 deletions) |
| `513237c` | docs | Review R2 blocking fix: corrected the merged/closed claim — `no_pr` stamps clean with forge checks skipped |
| 3 merge commits | base refresh | `origin/main` advanced mid-run (#179, #180, #181); each merged in, `state.yaml` resolved to this run's snapshot |

## Verification

- `bash test/test-ledger.sh` → **161 passed / 0 failed** at HEAD (red-first verified: 157/2 at the test commit, exactly the two draft assertions).
- Diagnose repro (kind=bug ledger run `2026-08-19-reland-170-draft-finalize`): scripted fixture drives `stamp finalize` against a forge-mocked draft PR — exit 2 (`PR #7 is not open: draft`) pre-fix, exit 0 post-fix; captured/re-run by the kernel's diagnose/fix gates.
- Independent review: profile `full`, 5 Opus lanes (security, logic, tests, style, documentation — the kernel stamp records the four canonical lane keys; documentation was a conditional addition), 7 rounds — R1 all-APPROVE with adopted should-fixes, R2 docs `REQUEST_CHANGES` (refusal-by-another-route wording) fixed and re-verified clause-by-clause against `ledger.sh:1057-1066`, final all-APPROVE at HEAD.

## Issue disposition

| Issue | Disposition |
|---|---|
| *none referenced* | Work originates from PR #170's loss (no tracking issue); provenance recorded in `_docs/decision-log.md` § "D-006 Phase 3 F3 follow-up resolved" |

Follow-ups filed as task chips (not issues): `worktree-baseline.sh cut` records a relative `--path` verbatim, making `verify` fail from inside the worktree (hit live this run); per-run ledger snapshot paths (chipped by the peer session as the systemic fix for cross-PR `state.yaml` conflicts).

## Merge policy

`human-only` — draft PR, **do not merge** (explicit instruction for this delivery). The finalize stamp does not require readiness.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
