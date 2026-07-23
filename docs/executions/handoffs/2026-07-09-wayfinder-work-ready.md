# Handoff — dotdev overhaul: wayfinder map charted, ready to work tickets

Exit: manual (charting done + Tier-0 #69 resolved; ready for work-mode sessions)
Target: claude or pi
Generated: 2026-07-09

## Start here (resuming agent)

> You are resuming multi-session work in `johnalexwelch/dotdev`. No `state.yaml`
> exists — the durable state is the **map issue on GitHub**, not this file.
>
> 1. Read the paths under "Files to read first" (bottom) to rebuild context —
>    above all the **map, #68**.
> 2. This is a `/wayfinder` **work-mode** effort. Do Next step 1 below.
>
> **Next step 1:** Run `/wayfinder` against the map (#68). Take **one** frontier
> ticket (recommended: **#70**, the wiring-verification keystone — agent-drivable,
> unblocks the Codex-wiring fog). **Claim it first** (assign to self), resolve it,
> record the resolution (comment → close → append to map's Decisions-so-far →
> mirror via `/decision-log`), graduate any newly-specifiable fog, then `/handoff`.
> **Never resolve more than one ticket per session.** No open blocker gates this.

## Where we are

The dotdev setup overhaul is charted as a wayfinder map (**#68**) with a flat
frontier of independent investigation tickets. The Tier-0 security item (FIND-09,
leaked SSH key) is **fully resolved and closed** (#69): the key was found trusted
nowhere (dead) and erased from git history. Everything else is planning that has
not started. The map — not any local file — is the source of truth.

## What was done this session

- **Charted the map:** [Map: dotdev setup overhaul (#68)](https://github.com/johnalexwelch/dotdev/issues/68), label `wayfinder:map`. Destination + Notes + fog + out-of-scope written. Destination = reproducible clean install across pi/claude/codex; understandable flow with in-session visibility for trust; skills/hooks used to full ability and **confidently wired (proven-invoked, not silently dead/ambiguous)**; managed/current docs; token/context-efficient sessions. **opencode out of scope.**
- **Created + attached 7 sub-issue tickets** (#69–#75). Frontier is flat (independent decisions; no blocking wired).
- **Resolved Tier-0 #69 (FIND-09):** rotation check found the key dead; erased from history via `git filter-repo` on a fresh clone; force-pushed main (temporarily toggled branch protection `allow_force_pushes`, then restored to false) + renovate branches + `v0.1.0` tag. **Verified on origin: private key = 0 objects, commit `449613f` GONE, new main HEAD `f1b6455`.** Mirrored to `docs/decision-log.md`.
- **cleanup-delivery earlier this session:** committed real WIP (`bc9efa2`), deleted stale merged PR #67 branch.
- **handoff skill hardened:** "Files to read first" now requires absolute paths (worktree-safe).
- Both local checkouts reset to rewritten history; herdr worktree re-registered.

## What is NOT done

Six open frontier tickets — all unclaimed, all unblocked:

- **#70** `research` — Decide the wiring-verification method (keystone; graduates Codex-wiring fog, backs #71/hooks).
- **#71** `grilling` — Router-exclusivity: which internal skills get `disable-model-invocation` (FIND-21).
- **#72** `prototype` — In-session visibility/trust: what a session surfaces (FIND-none / destination T2).
- **#73** `research` — Fresh-Mac reproducible-install verification across pi/claude/codex (FIND-11–19, 29).
- **#74** `research` — Token/context-efficiency baseline + approach, incl. pi context-stack dedup (FIND-26).
- **#75** `grilling` — Doc-management structure: canonical pages + generated lists (FIND-20).

Fog (Not yet specified, on the map): Codex skill wiring (FIND-27); MCP fleet capture/wiring (FIND-25, needs creds); nvim navigation-first rebuild (FIND-28); dangling-tool reconciliation (cursor/hunk/trino, git-secrets — FIND-22/23/24/10).

## Blockers requiring human input

None gate the next session. Live human input is needed *within* certain tickets when worked: #71 and #75 are HITL grillings (design calls); the MCP fog needs user endpoints/creds before it can graduate.

## Key decisions made

- FIND-09: rotate-first-then-erase; key was dead; history rewritten. (decision-log 2026-07-09; ticket #69.)
- opencode dropped from the harness set (out of scope).
- Frontier kept flat — the six tickets are genuinely independent; add blocking only if a resolution creates a dependency.

## Next steps

1. `/wayfinder` work-mode on #68 → resolve **#70** (recommended) or another single ticket. Claim first.
2. Record resolution + mirror to decision-log; graduate fog; `/handoff`.
3. Repeat one ticket per session until the route clears, then hand each cleared stretch into the funnel named in the map's Notes (`design-plan`→`execute-phase` for infra; `to-prd`→`to-issues`→`triage` for feature-ish; `decision-log` for pure decisions).

## Ready-to-use prompt (work session)

> `/wayfinder` — work the dotdev overhaul map (#68, <https://github.com/johnalexwelch/dotdev/issues/68>).
> Take one frontier ticket — recommend #70 (wiring-verification method). Claim it
> (assign to me) before any work, resolve just that one, post a resolution comment,
> close it, append one line to the map's Decisions-so-far, mirror the decision via
> /decision-log, graduate any newly-specifiable fog into tickets, then /handoff.
> Do not resolve more than one ticket.

## Suggested skills

- `wayfinder` — work-mode entry point (this effort).
- `repo-audit` / `deep-research` — the `research` tickets (#70, #73, #74).
- `grill-with-docs` + `domain-modeling` — the `grilling` tickets (#71, #75).
- `prototype` — the visibility ticket (#72).
- `decision-log` — mirror every resolution.

## Files to read first

- **Map #68** (source of truth): <https://github.com/johnalexwelch/dotdev/issues/68>
- `/Users/alexwelch/dotdev/docs/audits/2026-07-09-setup-audit.md` — the fog (FIND-09…FIND-29).
- `/Users/alexwelch/dotdev/docs/agents/issue-tracker.md` → "Wayfinding operations" — how the map/tickets/labels/frontier work here.
- `/Users/alexwelch/dotdev/dotfiles/.claude/skills/wayfinder/SKILL.md` — work-mode procedure.
- `/Users/alexwelch/dotdev/docs/decision-log.md` — decisions (latest: FIND-09, 2026-07-09).
- `/Users/alexwelch/dotdev/docs/executions/handoffs/2026-07-09-wayfinder-map-charted.md` — the charting handoff (prior link in this chain).
