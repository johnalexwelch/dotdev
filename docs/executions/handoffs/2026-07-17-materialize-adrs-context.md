# Handoff — Materialize phantom ADRs + workflow CONTEXT (arch candidate 3)

Exit: manual (architecture review complete; grilling not started)
Target: either
Generated: 2026-07-17T18:40:32Z

## Start here (resuming agent)

> You are resuming multi-session work in `dotdev` at `/Users/alexwelch/dotdev`.
> No `docs/executions/state.yaml` — boot from this handoff + Files to read first.
>
> 0. `cd /Users/alexwelch/dotdev` before any git/gh work.
> 1. Read Files to read first (architecture report candidate **#3**, CONTEXT, router Authority).
> 2. Then do Next step 1: run the **improve-codebase-architecture grilling loop** for
>    "Materialize phantom ADRs + workflow CONTEXT" — lock CONTEXT-MAP shape,
>    which ADRs to extract first, and what stays in decision-log only. Do **not**
>    mass-rewrite skills until the user asks after an accepted design.
>
> Open human choice: single CONTEXT vs CONTEXT-MAP (brain vs agents); accept
> recommended answers or answer live.

## Where we are

Architecture review found `workflow-router` cites **ADR-0002** (sole routing
authority) but **`docs/adr/` does not exist**. `.claude/CONTEXT.md` is Librarian /
ROWAN vocabulary only — workflow domain language lives in openwiki + skill prose.
`docs/decision-log.md` exists for issue-scoped DLs. Candidate **3 (Strong)**.
Analysis only — no grill, no ADR files written yet.

## What was done this session

- Confirmed missing `docs/adr/` (only `grill-with-docs/ADR-FORMAT.md` template).
- Confirmed CONTEXT is brain/Librarian-scoped; workflow terms absent.
- Durable HTML report saved under architecture-reviews/.

## What is NOT done

- Grilling: CONTEXT-MAP vs single CONTEXT; ADR numbering; which prose → ADR vs DL.
- Writing `docs/adr/0002-…` and agents vocabulary terms.
- Pointing router (and other skills) at real ADR paths.

## Key decisions made (provisional — confirm in grill)

- Recommended: **CONTEXT-MAP** with `brain` (existing Librarian CONTEXT) + `agents`
  (router, Step Ledger, Gate Block, Worktree Baseline, Delivery Policy).
- First ADR to materialize: **0002 sole routing authority** from router Authority section.
- Do not contradict **DL-0003** (no new pytest empire for markdown specs).

## Next steps

1. Grill candidate 3 (CONTEXT layout, ADR set, migration of citations).
2. On accept: create `docs/adr/0002-sole-routing-authority.md`; add agents terms;
   replace “Per ADR-0002” vapor with a real link; optionally `CONTEXT-MAP.md`.
3. Sibling handoffs for candidates 1–2 — independent unless user merges.

## Ready-to-use prompt

> Resume ADR/CONTEXT deepening in `/Users/alexwelch/dotdev`. Read
> `/Users/alexwelch/dotdev/docs/executions/handoffs/2026-07-17-materialize-adrs-context.md`
> and follow Start here. Load `improve-codebase-architecture` and grill candidate 3
> only. Recommended defaults: CONTEXT-MAP with brain + agents; first ADR =
> sole routing authority extracted from
> `workflow-router/SKILL.md` Authority section; keep decision-log for issue-scoped
> DLs. Do not write files until I accept the grill outcomes.

## Suggested skills

- `improve-codebase-architecture` — grilling loop
- `grill-with-docs` — ADR + CONTEXT discipline
- `domain-modeling` — agents vocabulary terms
- `decision-log` — if a grill answer is DL-shaped not ADR-shaped

## Files to read first

- `/Users/alexwelch/dotdev/docs/executions/architecture-reviews/2026-07-17-workflow-skills.html` — candidate #3
- `/Users/alexwelch/dotdev/.claude/CONTEXT.md` — current (Librarian) glossary
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-router/SKILL.md` (Authority / ADR-0002 cite)
- `/Users/alexwelch/dotdev/docs/decision-log.md`
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/grill-with-docs/ADR-FORMAT.md`
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/improve-codebase-architecture/SKILL.md`
- `/Users/alexwelch/dotdev/openwiki/quickstart.md` — workflow vocabulary already in prose
- `/Users/alexwelch/dotdev/docs/executions/handoffs/2026-07-17-deepen-worktree-baseline.md` — sibling
- `/Users/alexwelch/dotdev/docs/executions/handoffs/2026-07-17-collapse-step-ledger.md` — sibling
