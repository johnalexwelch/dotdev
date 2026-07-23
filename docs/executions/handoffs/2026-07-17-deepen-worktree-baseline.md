# Handoff — Deepen Worktree Baseline (arch candidate 1)

Exit: manual (architecture review complete; grilling not started)
Target: either
Generated: 2026-07-17T18:40:32Z

## Start here (resuming agent)

> You are resuming multi-session work in `dotdev` at `/Users/alexwelch/dotdev`.
> No `docs/executions/state.yaml` — boot from this handoff + Files to read first.
>
> 0. `cd /Users/alexwelch/dotdev` before any git/gh work.
> 1. Read Files to read first (architecture report candidate **#1**, then the listed skills).
> 2. Then do Next step 1: run the **improve-codebase-architecture grilling loop** for
>    "Deepen Worktree Baseline" until Module Interface / seams / adapters / vertical
>    slice / second_pass are locked (or `needs_human` recorded). Do **not** implement
>    until grilling produces an accepted design and the user asks to proceed
>    (`to-prd` / `workflow-build-one` / etc.).
>
> Open human choice: accept recommended answers during grill, or answer live.

## Where we are

`/improve-codebase-architecture` ran on the **workflow-skills** surface
(`dotfiles/.config/agents/skills/`). Seven candidates written to an HTML report.
Candidate **1 (Strong)** is deepen Worktree Baseline: worktree/base/stacked gate
invariants leak across many workflow skills while `setup-worktree` is a deprecated
sidecar. Analysis only — no grill, no PRD, no code changes.

## What was done this session

- Explored workflow skills (~99), hooks, decision-log; no `docs/adr/` found.
- Wrote architecture report (durable copy under architecture-reviews/).
- Selected top recommendation: Worktree Baseline.

## What is NOT done

- Grilling loop for this module (Interface, seams, adapters, tests, migration, vertical slice, `second_pass`).
- CONTEXT.md / ADR updates that crystallize during grill.
- Implementation / issues / PR.

## Key decisions made

- Scope of review = workflow skills + shared protocol, not Librarian brain ops.
- Agent-agnostic skills hoist (2026-07-15) is **done** — out of scope to re-propose.
- `execute-prd` / `run-backlog` / `workflow-build-one` kept as distinct modules.

## Next steps

1. Grill Worktree Baseline per `improve-codebase-architecture` §3 (and INTERFACE-DESIGN.md if exploring alternate interfaces).
2. On accepted design: update CONTEXT (agents vocabulary) and/or ADR if load-bearing; then `to-prd` or thin vertical slice via `workflow-build-one` when user asks.
3. Sibling candidates 2–3 have their own handoffs — do not fold them into this session unless user says so.

## Ready-to-use prompt

> Resume Worktree Baseline deepening in `/Users/alexwelch/dotdev`. Read
> `/Users/alexwelch/dotdev/docs/executions/handoffs/2026-07-17-deepen-worktree-baseline.md`
> and follow Start here. Load `improve-codebase-architecture` and run only the
> **grilling loop** for candidate 1 (Deepen Worktree Baseline). Recommended
> defaults: sole interface = cut/verify/emit `WORKFLOW_BASE_GATE` +
> `WORKTREE_BASELINE_GATE` / `STACKED_WORKTREE_GATE`; callers delete restated
> invariant prose; first vertical slice = `workflow-build-one` Step 0 only.
> Record accepted answers; do not implement until I say so.

## Suggested skills

- `improve-codebase-architecture` — grilling loop (current)
- `grill-with-docs` — if domain terms need CONTEXT/ADR stress-test
- `to-prd` — after grill accepts a module design
- `workflow-build-one` — later: vertical slice implementation

## Files to read first

- `/Users/alexwelch/dotdev/docs/executions/architecture-reviews/2026-07-17-workflow-skills.html` — candidate #1 card
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/improve-codebase-architecture/SKILL.md`
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/improve-codebase-architecture/LANGUAGE.md`
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/improve-codebase-architecture/DEEPENING.md`
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/setup-worktree/SKILL.md`
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/setup-worktree/references/base-branch-policy.md`
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-build-one/SKILL.md` (Per-Issue Worktree Invariant)
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/run-backlog/SKILL.md`
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-finalize/SKILL.md` (worktree preconditions)
- `/Users/alexwelch/dotdev/docs/executions/handoffs/2026-07-17-collapse-step-ledger.md` — sibling (do not start unless asked)
- `/Users/alexwelch/dotdev/docs/executions/handoffs/2026-07-17-materialize-adrs-context.md` — sibling
