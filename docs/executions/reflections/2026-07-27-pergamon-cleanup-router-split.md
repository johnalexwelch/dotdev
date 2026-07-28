# Session Reflection: Pergamon Cleanup And Router Split

**Date**: 2026-07-27
**Goal**: Reflect on the Phase 5 cleanup, Phase 6 handoff, and router/session split meta-work.

## What Went Well

- Live state beat proxies: PR/issue state, worktree cleanliness, process cwd checks, and branch state were verified before cleanup.
- Cleanup stayed bounded: only the explicitly approved safe local worktrees and local branches were removed; dirty/live worktrees and remote branches were kept.
- The handoff was durable: it was written to both the repo and `/Users/alexwelch/.chorus/handoffs/pergamon/`.

## What Went Wrong / Friction

- The Phase 6 handoff over-weighted the active `state.yaml` cleanup ledger. Evidence: the user corrected with "i want the other session starting fresh from phas 6". The handoff did mention start-fresh, but it still made the unrelated cleanup resume check feel like the first task.
- The cleanup flow had two approval moments: route confirmation, then cleanup-plan approval. That is correct for safety, but the user had to infer the exact approval phrase from prior context.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "i want the other session starting fresh from phas 6" | `handoff` used active `state.yaml` as the first operational gate even though the user wanted a separate fresh Phase 6 session. | `dotfiles/.config/agents/skills/handoff/SKILL.md` |
| 2 | "Resume 2026-07-26-post-phase-5-delivery-cleanup at cleanup-plan-approval" | The session needed to split responsibilities explicitly: this session continues cleanup; the other starts Phase 6. | `dotfiles/.config/agents/skills/workflow-router/SKILL.md` |

## Lessons

1. **Split-session intent should override handoff shape**: When the user says another session should start fresh on a new phase, the handoff should make the old active ledger context, not the next session's first task.
2. **Cleanup approval phrases should be explicit**: A safe cleanup plan should end with the exact minimal phrase that approves only the listed safe local items.
3. **Ground truth checks prevented data loss**: Dirty handoff files and a live process kept two worktrees out of the removal set.

## Proposed Improvements

- [ ] `dotfiles/.config/agents/skills/handoff/SKILL.md` — Add a "separate fresh session" clause: when the user explicitly wants a different session to start new work, the Start Here block must say the current active `state.yaml` is context only unless it conflicts with the new work; the first operational step is the requested fresh route. Evidence: "i want the other session starting fresh from phas 6". (priority: high)
- [ ] `dotfiles/.config/agents/skills/workflow-router/SKILL.md` — Refine Step 0: if an active ledger exists but the user explicitly says "start fresh" for unrelated work, show the ledger as a conflict check and ask for one confirmation only if there is a real shared-resource conflict. Evidence: the user split cleanup and Phase 6 across sessions. (priority: med)
- [ ] `dotfiles/.config/agents/skills/cleanup-delivery/SKILL.md` — Require cleanup plans to end with an exact approval phrase and a one-line "will not touch" list for remote branches, dirty worktrees, and tickets. Evidence: the user approved with "approve safe local cleanjp" after the assistant supplied the phrase. (priority: med)
