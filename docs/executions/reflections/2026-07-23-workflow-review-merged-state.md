# Session Reflection: workflow-review + finalize over already-merged PRs
**Date**: 2026-07-23
**Goal**: Run workflow-review on 5 architecture PRs (#1520–#1524), finalize, and merge; land any review must-fix.

## What Went Well
- **Caught a model-floor violation the harness hid.** Initial review lanes used taskflow's `security-reviewer`/`risk-reviewer`/`test-engineer`, which run on **sonnet-4** — below the opus-4-5 floor that `workflow-review` mandates for `standard`/`full`. Noticed via the per-lane `MODEL:` lines and re-ran 7 lanes on the opus `reviewer` agent before certifying APPROVE.
- **Verified before claiming.** The C5 regex change was proven byte-identical at runtime (`old.pattern == new.pattern`) and 115/115 tests before asserting "behavior-preserving."
- **Clean recovery once ground truth was known.** Landed the orphaned must-fix as a fresh PR (#1528) onto `staging` rather than resurrecting a merged branch; handled the merge queue correctly (dropped `--delete-branch`/`--squash` when it rejected them).
- **Didn't hand-wave the must-fix.** Treated the reviewer's "dead duplicate constants" finding as worth landing even after the parent PR merged.

## What Went Wrong / Friction
- **Chased a phantom "PR won't sync / CI won't fire" for ~5 min** — push, force-with-lease, amend-to-new-SHA, repeated CI/head polling — before discovering all 5 PRs were **already MERGED** (by the user, at their original heads). My fix commit was orphaned on a closed branch the whole time, which is why no `synchronize` event/CI ever fired.
- **Left a mess:** an amended orphan commit force-pushed onto the merged `arch/c5-sql-review-safety` branch — a side effect of acting before checking state.
- Under-weighted two early signals: the `[new branch]` push hint and the PR head never advancing after a real force-push.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| — | (No explicit corrections — user was hands-off: "yes", "merge".) The friction was self-inflicted, not user-flagged. | Trusted a stale proxy over authoritative state. | workflow-finalize |

## Lessons
1. **Check PR state before touching its branch.** I trusted a proxy (prior-session memory + the assumption the PRs were still open/draft) and pushed a fix. The authoritative source — `gh pr view <n> --json state` — said `MERGED`. Had I checked first, I'd have gone straight to a follow-up PR and saved the entire sync/CI goose chase. Proxy vs ground-truth: the live PR/API state wins.
2. **A skill's model floor is only real if the dispatch harness honors it.** `workflow-review` says "dispatch on opus," but its recommended subagent mapping routes Security/Tests/Concurrency to agents that default to sonnet-4. Following the roster verbatim (via taskflow shorthand, which can't pin `model`) silently produces below-floor lanes the same skill says must be `NEEDS_HUMAN`. The floor must be verified per lane, not assumed from the roster.

## Proposed Improvements
- [ ] `workflow-finalize/SKILL.md` — **high**: add a ground-truth precheck at the top of any "apply a fix to a PR" path: run `gh pr view <n> --json state,mergedAt,headRefOid` first; if `MERGED`/`CLOSED`, do **not** push to the branch — land the fix as a fresh PR onto the base. Add the rule "a same-SHA re-push fires no `synchronize` event; a stuck PR head means check `state`, not re-push."
- [ ] `workflow-review/references/reviewer-roster.md` — **high**: annotate the subagent mapping: "these specialist agents may run **below** the opus floor for `standard`/`full`. Before relying on them, confirm each lane's model; if the harness can't pin `model: opus` at dispatch (e.g. taskflow shorthand), use the opus general `reviewer` agent with the per-lane brief instead. Capture `model_used` per lane and re-run any below-floor lane."
- [ ] `workflow-review/SKILL.md` (near line 20, the `model_below_floor` rule) — **med**: strengthen from a self-report backstop to an active check: "When dispatching through a subagent harness, verify each lane's actual model meets the floor — do not infer it from the roster's default agent, which may be below floor."

## Skill Extraction Candidates
<!-- Better-way-found refines existing skills; not a new standalone skill. Omitting a full draft. -->
- **Better way found (fold into `workflow-review`)**: for `standard`/`full` in a taskflow/subagent harness, dispatch lanes on the **opus general `reviewer` agent + per-lane brief** rather than the specialized sonnet-configured agents — satisfies lane independence *and* the model floor in one move. Trigger: harness cannot pin per-phase `model` and the default specialist agents are below opus. Fails the new-skill gate (it's a refinement, not a repeatable standalone workflow).
