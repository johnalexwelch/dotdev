# Session Reflection: Pergamon Phase 7 Setup And Handoff
**Date**: 2026-07-27
**Goal**: Reflect on the Pergamon Phase 7 planning, issue #57/#58 routing, setup-skills repair, and handoff workflow.

## What Went Well
- Live state eventually won over proxies: Forgejo/OpenBao/Auth were checked on the real `pergamon` host, GitHub issue/PR states were re-read before routing, and merged PR state changed the #58 handoff from stacked-base to `personal/main`.
- The user correction on #57 improved the routing model: technical validation was separated from human acceptance, letting #58 become truly `ready-for-agent`.
- Independent verification caught quality risks before final claims on both #57 and setup-skills repair.
- The final handoff was improved by rechecking PR #61/#62/#63 merge state instead of copying the older stale handoff.

## What Went Wrong / Friction
- The initial Phase 7 decomposition drifted toward repeated planning layers until the user corrected: "are these vertical slices?", "why are we doing so many planning sessions?", and "each prd should be a vertical slie".
- HITL was treated too broadly at first. The user had to ask "what is hitl for these?", "can any of that actually be afk?", and later corrected #57 with "this seems like something you can confirm and validate".
- `setup-skills` had been considered configured because `AGENTS.md` and `docs/agents/*` existed, but the repo lacked the promised root `CONTEXT.md`.
- GitHub account state was volatile. Parallel `gh auth switch` calls collided in the keyring, and HTTPS/SSH pushes failed until the command supplied the intended `johnalexwelch` token directly.
- `docs/executions/state.yaml` in a later worktree was stale relative to live tracker and PR state. The handoff had to override it after current GitHub readback.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "each prd should be a vertical slie" | Phase decomposition allowed horizontal planning PRDs instead of vertical outcomes. | `dotfiles/.config/agents/skills/to-prd/SKILL.md` or `execute-prd/SKILL.md` |
| 2 | "can any of that actually be afk?" | HITL label was conflated with implementation mode instead of separating AFK technical validation from human acceptance. | `dotfiles/.config/agents/skills/prompt-builder/SKILL.md` |
| 3 | "this seems like something you can confirm and validate" | #57 remained human-gated after agent-confirmable validation was already complete. | `dotfiles/.config/agents/skills/triage/SKILL.md` and `prompt-builder/SKILL.md` |
| 4 | "we missed this at the very beginning as we should have CONTEXT.md and ADRs" | `setup-skills` config was present but not audited for promised artifacts. | `dotfiles/.config/agents/skills/setup-skills/SKILL.md` |
| 5 | "/handoff for the next body of work" after PRs merged | Existing handoff preserved stale stacked-base assumptions from before PR merge. | `dotfiles/.config/agents/skills/handoff/SKILL.md` |

## Lessons

1. **Vertical PRDs Are Not Optional In Phase Work**: A phase work order can coordinate, but child PRDs must each deliver an end-to-end outcome. Otherwise the backlog becomes planning about planning.
2. **HITL Needs Two Axes**: "Human review required" should not imply "agent cannot implement or validate." Distinguish AFK execution eligibility, live-mutation risk, and human acceptance gate.
3. **Setup Is Incomplete Until The Advertised Files Exist**: `AGENTS.md` saying "single-context repo" is insufficient without root `CONTEXT.md` and validation coverage.
4. **State Files Are A Starting Point, Not A Substitute For Live Readback**: When the ask is "current open ready-for-agent issues," GitHub issue and PR readback must refresh stale local state.
5. **Multi-Account GitHub Needs A Non-Interactive Path**: Active `gh` account is volatile in this environment; parallel switching is unsafe, and pushes should use an explicit token credential helper when repository ownership matters.

## Proposed Improvements

- [ ] `dotfiles/.config/agents/skills/to-prd/SKILL.md` — Add a Phase/PRD decomposition gate: every child PRD must be a vertical slice with user-visible or operator-visible outcome, dependencies, validation, and rollback; horizontal work belongs in the parent work order only. Evidence: user corrections "are these vertical slices?" and "each prd should be a vertical slie". (priority: high)
- [ ] `dotfiles/.config/agents/skills/prompt-builder/SKILL.md` — Split AFK policy output into `execution_mode`, `human_review_gate`, and `acceptance_gate`; explicitly allow "AFK implementation with human PR review" and "agent-confirmable technical validation with human policy acceptance." Evidence: #57 was validated by agent but initially left as broad HITL. (priority: high)
- [ ] `dotfiles/.config/agents/skills/setup-skills/SKILL.md` — After discovering a single-context layout, require either root `CONTEXT.md` exists or generate a draft for approval; include a validation recommendation for `AGENTS.md`, `CONTEXT.md`, and `docs/agents/*`. Evidence: repo had setup files but no `CONTEXT.md`. (priority: high)
- [ ] `dotfiles/.config/agents/skills/handoff/SKILL.md` — Add a "live queue refresh" step when the user asks for current work: re-read open ready-for-agent issues and relevant PR merge states, and override stale local `state.yaml` only with an explicit conflict note. Evidence: prior #58 handoff still assumed stacked branches after PR #61/#62/#63 merged. (priority: med)
- [ ] `dotfiles/.config/agents/skills/git-guardrails/SKILL.md` — Add a multi-account GitHub note: do not parallelize `gh auth switch`; when the repo owner matters and remotes fail, use an explicit `GH_TOKEN=... git -c credential.helper=...` push pattern without printing token values. Evidence: keyring collision and repository-not-found push failures. (priority: med)

