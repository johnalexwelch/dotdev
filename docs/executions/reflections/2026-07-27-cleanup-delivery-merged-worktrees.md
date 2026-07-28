# Session Reflection: Cleanup Delivery Merged Worktrees

**Date**: 2026-07-27
**Goal**: Reflect on the Pergamon cleanup-delivery pass after Phase 7/setup PRs merged.

## What Went Well

- Cleanup stayed bounded: inventory, classify, present a deletion plan, then wait for the user's explicit "approved" before removing anything.
- The destructive actions were re-verified immediately before execution: worktree status, PR merge state, issue #57 state, and cwd anchors were checked again instead of relying on the earlier plan.
- Dirty and active worktrees were preserved, including the active #58 implementation worktree and older worktrees with handoff/document drift.
- Remote branch deletion stayed out of scope. The pass deleted only approved clean local worktrees and local branches.
- Issue #57 was closed only after the acceptance comment existed and PR #62 was merged.

## What Went Wrong / Friction

- `cleanup-delivery`'s default "fetch origin" guidance is too narrow for Pergamon. The authoritative repo remote for this session was `personal`, while `origin` can be stale or not the operational source of truth.
- The handoff-only branch `codex/handoff-next-issue-58` did not fit a clear cleanup bucket: it is clean and pushed, has no PR, and duplicates a global handoff mirror while preserving a repo-local handoff artifact.
- The primary checkout state was important context but appeared mainly in the final readback: `/Users/alexwelch/projects/pergamon` was still behind `personal/main` and had untracked handoff artifacts.
- Several old dirty worktrees contained only handoff/document artifacts. They were correctly preserved, but the current cleanup vocabulary does not distinguish "active implementation dirty" from "handoff artifact drift."
- Multi-account GitHub handling remained an operational wrinkle. GitHub reads required care to use the right account/context, and that pattern is recurring enough to document where cleanup and PR workflows touch `gh`.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | Approved only after seeing the cleanup plan | Cleanup had to remain human-gated before destructive actions | `cleanup-delivery` |
| 2 | Earlier session pressure favored vertical implementation slices over repeated planning | Planning artifacts can overrun delivery unless the next-body-of-work handoff is concrete | `handoff`, `to-prd`, `cleanup-delivery` |

## Lessons

1. **Fetch the authoritative remote, not just the conventional one**: cleanup state is only as good as the remote refs being inspected. In Pergamon, `personal/main` was the current source of truth.
2. **Handoff-only branches need a first-class decision**: a clean branch whose only purpose is a handoff is not equivalent to an active feature branch or a merged PR branch.
3. **Dirty does not mean unsafe in one way**: dirty implementation work, dirty preserved handoff drift, and dirty primary checkout artifacts need separate labels so the cleanup plan can be precise.
4. **Approval scope must stay visible**: the cleanup pass worked because "approved" was interpreted against the previously listed local deletions and issue closure, not as blanket permission.
5. **Live tracker state beats git ancestry**: issue #57 was closed based on PR merge plus user acceptance, not solely because the branch had been merged.
6. **Done should mean clean or explicitly carried forward**: every delivery/handoff should end with a clean-state readback. Any remaining dirty state must be intentionally classified, assigned an owner, and linked to the next action.

## Proposed Improvements

- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-finalize/SKILL.md` — Add a clean-state exit contract: before final response, report whether the touched worktree is clean, whether the primary checkout is untouched/dirty, and whether any remaining artifacts are committed, handed off, or explicitly preserved. This should be a gate, not an implicit destructive cleanup step. Evidence: this cleanup pass left valid preserved dirty states, but the finish criteria did not make "clean or carried forward" a first-class invariant. (priority: high)
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/cleanup-delivery/SKILL.md` — Replace the fixed `git fetch origin --prune` default with guidance to fetch all relevant remotes, then identify and report the authoritative source remote/branch before cleanup decisions. Evidence: Pergamon cleanup used `personal/main` as authoritative while local `main` was behind it. (priority: high)
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/cleanup-delivery/SKILL.md` — Add a `handoff-only branch` bucket for clean pushed branches with no PR whose only payload is a repo-local handoff; require an explicit keep/open-PR/delete decision. Evidence: `codex/handoff-next-issue-58` remained clean, pushed, no PR, and intentionally preserved. (priority: med)
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/cleanup-delivery/SKILL.md` — Make primary-checkout sync and dirty state a standard report line whenever the primary branch is behind/ahead or has untracked files. Evidence: the Pergamon primary checkout was behind `personal/main` and had untracked handoff artifacts. (priority: med)
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/cleanup-delivery/SKILL.md` — Add a `dirty handoff/docs drift` classification distinct from active implementation dirty state; require preserve, commit, or explicitly abandon. Evidence: old issue #29/#30/phase-6-8 worktrees had handoff/document changes that were not safe to delete but also were not active implementation. (priority: med)
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/git-guardrails/SKILL.md` — Add a short noninteractive GitHub account check pattern for multi-account repos and warn not to parallelize account-switching operations. Evidence: Pergamon cleanup and prior PR workflows needed current-account verification before trusting `gh` state. (priority: low)
