# Session Reflection: Pergamon Issue 60 Delivery Loop

**Date**: 2026-07-28
**Goal**: Reflect on the issue #60 build/review/finalize/cleanup session and propose durable process improvements.

## What Went Well

- The workflow eventually preserved the right source of truth: GitHub PR/issue state, `personal/main`, final `just validate` output, and explicit PR merge state were checked before final claims.
- Independent review lanes caught real bugs before delivery: weak credential detection, missing render-root gating, stale-preview defaulting, multi-record/overwrite behavior, partial-apply recovery, concurrent writes, rollback binding, restore readback consistency, and missing-readback diagnostics.
- The user correction, "for human gates you do not need to stop. at any point unless my involvement is 100% needed", helped avoid unnecessary stalls while still preserving actual durable/live-root approval boundaries.
- Post-merge cleanup used PR state as authority, reconciled #60, removed the local worktree/branch, and left unrelated primary-checkout WIP untouched.

## What Went Wrong / Friction

- `workflow-finalize` was initially treated as effectively done after creating the draft PR, but the user invoked it again and the stricter skill revealed missing ledger/final gate details. The final answer had a PR and evidence, but not the full finalize protocol.
- The PR body was effectively hand-generated even though `workflow-finalize` says `describe-pr` must run and must produce the body. The stale `describe-pr` reference to `_docs/human-gate-taxonomy.md` made strict execution awkward.
- Long `just validate` runs were started while review lanes were still finding blockers, which wasted time and left stale validation processes that had to be killed.
- Validation mutated `platform/secrets/runtime-migration.md` as test residue once; this had to be detected and manually removed.
- The full review lane fan-out was useful but expensive and slow. Several lanes repeated the same stale-validation finding, and the product lane timed out long after the blocking implementation issues were already known.
- Cleanup after merge required manually composing a reconciliation comment, closing #60, deleting the local worktree/branch, and appending the handoff. This pattern is repeatable and currently too manual.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | Human gates should not stop progress unless user involvement is 100% needed. | Workflow interpretation was too conservative around human gates and reviewer validation. | `workflow-finalize`, `workflow-build-one` |
| 2 | Explicitly invoked `workflow-finalize` after the first closeout. | The initial finalization did not fully emit and verify the required step ledger/final gate. | `workflow-finalize` |
| 3 | "Continue. Merged" required post-merge cleanup. | Merge-time cleanup/reconciliation was not automatically resumed from the finalize handoff. | `cleanup-delivery`, `workflow-finalize` |

## Lessons

1. **Do not start the full final validation until review blockers are closed**: For long suites, run focused tests while review lanes are active, then run the authoritative suite once after the last code/evidence edit.
2. **Finalize is a protocol, not a PR URL**: A draft PR plus tests is not complete unless the ledger, reviewer comments, CI/check state, issue reconciliation, clean-state exit, and final gate are all recorded.
3. **Review fan-out should be staged**: Run high-yield blocking lanes first for security, logic, tests, state, docs, and architecture; dispatch product/frontend/release after blockers are fixed or in a second wave.
4. **Validation residue must be checked explicitly**: After broad test harnesses, inspect tracked diffs for unrelated mutations before committing.
5. **Merged PR cleanup is a recurring workflow**: Once the user says a PR merged, the agent should verify merge state, reconcile issue state, remove clean local delivery worktrees/branches, and update the handoff.

## Proposed Improvements

- [ ] `dotfiles/.config/agents/skills/workflow-finalize/SKILL.md` — Add a "resume after draft PR already exists" checklist that starts with the step ledger and audits describe-pr, PR comments, checks, issue reconciliation, clean-state exit, and final gate before claiming completion. (priority: high)
- [ ] `dotfiles/.config/agents/skills/workflow-finalize/SKILL.md` — Add guidance to delay the authoritative full validation until after review-fix churn is done; use focused checks during active review lanes. (priority: med)
- [ ] `dotfiles/.config/agents/skills/workflow-review/SKILL.md` — Add staged lane fan-out: first blocking lanes, then secondary acceptance/UX/release lanes after first-wave blockers are fixed. (priority: med)
- [ ] `dotfiles/.config/agents/skills/describe-pr/SKILL.md` — Fix or inline the stale `_docs/human-gate-taxonomy.md` reference so strict use does not fail when the helper is loaded from `.codex/skills/describe-pr`. (priority: high)
- [ ] `dotfiles/.config/agents/skills/workflow-finalize/SKILL.md` — Add a post-validation residue check: after `just validate` or equivalent broad gates, run `git status` and inspect unrelated tracked diffs before staging/committing. (priority: high)
- [ ] `dotfiles/.config/agents/skills/cleanup-delivery/SKILL.md` — Add a narrow "post-merge local cleanup after user says merged" path: verify PR merged, reconcile referenced issue, remove only clean local delivery worktree/branch, preserve remote branches unless explicitly approved. (priority: med)

## Skill Extraction Candidates

- **Proposed skill**: `post-merge-reconcile-cleanup` · **target**: `dotfiles/.config/agents/skills/post-merge-reconcile-cleanup/SKILL.md` · **invocation**: user or workflow-finalize
  - **Trigger / leading word**: "Continue. Merged", "PR merged", "clean up after merge", or workflow-finalize detecting a previously draft/human-gated PR is now merged.
  - **Inputs**: PR number or branch, issue refs, worktree path, authoritative remote/base.
  - **Steps**:
    1. Verify PR state is `MERGED`, capture merge commit and merged timestamp.
    2. Verify issue disposition and decide whether to close, comment, remove stale labels, or preserve open state.
    3. Confirm local delivery worktree is clean and no live process is anchored in it.
    4. Remove the local worktree and local branch only when clean and PR-merged; preserve remote branches unless explicitly approved.
    5. Update the existing handoff/finalize artifact with merge, reconciliation, and cleanup evidence.
    6. Report primary checkout dirty state without touching unrelated WIP.
  - **Success criteria**: PR merge state verified, issue reconciled, local delivery residue removed or explicitly preserved, handoff updated, unrelated WIP untouched.
  - **Constraints / pitfalls**: Do not infer merge from git ancestry alone; squash/rebase merges break ancestry. Do not delete remote branches without approval. Do not close an issue when the PR intentionally used `Addresses` unless post-merge evidence or user direction establishes acceptance.
  - **Verification evidence**: This session verified PR #67 was merged, closed #60 with a reconciliation comment, removed the issue #60 local worktree/branch, preserved the remote branch and primary WIP, and appended the handoff.
  - **Quality gate**: googleable=No · specific=Yes · real-effort=Yes
  - **Open questions**: Whether this should be a standalone skill or a dedicated subflow inside `cleanup-delivery`.
