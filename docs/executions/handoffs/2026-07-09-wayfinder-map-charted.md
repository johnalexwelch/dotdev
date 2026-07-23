# Handoff — dotdev setup overhaul map is charted

Exit: manual (wayfinder chart session complete)
Target: claude or pi
Generated: 2026-07-09

## Start here (resuming agent)

> The dotdev setup overhaul has been **charted** with `/wayfinder`. The durable
> state is the **map issue, not this file** — this handoff is only a pointer.
>
> **Map: [dotdev setup overhaul — reproducible, verified-wiring, observable, token-lean](https://github.com/johnalexwelch/dotdev/issues/68)** (#68, label `wayfinder:map`).
>
> To continue: run **`/wayfinder`** in *work mode* against the map (#68). Take the
> first frontier ticket in order (or one the user names), **claim it** (assign to
> self) before any work, resolve exactly **one ticket this session**, record the
> resolution (comment → close → append to map's Decisions-so-far → mirror to
> `/decision-log`), graduate any newly-specifiable fog, and exit with `/handoff`.
> Do NOT resolve more than one ticket per session.

## What was done this session (charting)

- Named the **destination** with the user (see map body #68): reproducible clean install across pi/claude/codex; understandable flow + in-session visibility for trust; skills/hooks used to full ability and **confidently wired (proven-invoked, not silently dead/ambiguous)**; managed/current docs; token/context-efficient sessions.
- **opencode ruled out of scope** (harness set is pi/claude/codex).
- **FIND-09** surfaced as a human decision → user chose **Tier-0 ticket**, rotate-first-then-erase-history (git-filter-repo). Now ticket #69.
- This handoff lives at `/Users/alexwelch/dotdev/docs/executions/handoffs/2026-07-09-wayfinder-map-charted.md`.
- Ran `/cleanup-delivery`: committed real WIP (`bc9efa2`, pushed), deleted stale merged remote branch `claude/wayfinder-skill-setup-aptvd9` (PR #67), left the herdr worktree for herdr to reap.
- Created the map (#68) + 7 sub-issue tickets and attached them.

## The frontier (open, unclaimed, all unblocked — flat)

- **#69** `task` — Rotate + erase leaked ollama SSH key (FIND-09) — **Tier-0, do first**.
- **#70** `research` — Decide the wiring-verification method (keystone; graduates Codex-wiring fog + backs #71).
- **#71** `grilling` — Router-exclusivity: which internal skills get `disable-model-invocation` (FIND-21).
- **#72** `prototype` — In-session visibility/trust: what a session surfaces (T2).
- **#73** `research` — Fresh-Mac reproducible-install verification across pi/claude/codex (FIND-11–19, 29).
- **#74** `research` — Token/context-efficiency baseline + approach, incl. pi context-stack dedup (FIND-26).
- **#75** `grilling` — Doc-management structure: canonical pages + generated lists (FIND-20).

## Fog (Not yet specified — see map body)

Codex skill wiring (FIND-27, hangs on #70); MCP fleet capture/wiring (FIND-25, needs creds); nvim navigation-first rebuild (FIND-28); dangling-tool reconciliation (cursor/hunk/trino, git-secrets — FIND-22/23/24/10). These graduate into tickets as the frontier advances.

## Blockers requiring human input (live at resolution, not now)

- #71 (which skills become router-exclusive) — user design call.
- #74 (token) / #73 (install) — none blocking; user runs when ready.
- MCP fleet (fog) — needs user endpoints/creds before it can graduate.

## Files to read first (absolute paths — worktree sessions cannot resolve relative ones)

- **Map #68** — the canonical state (destination, notes, fog, out-of-scope): <https://github.com/johnalexwelch/dotdev/issues/68>
- `/Users/alexwelch/dotdev/docs/audits/2026-07-09-setup-audit.md` — the fog source (FIND-09…FIND-29).
- `/Users/alexwelch/dotdev/docs/agents/issue-tracker.md` → "Wayfinding operations" — how the map/tickets/labels/frontier work here.
- `/Users/alexwelch/dotdev/dotfiles/.claude/skills/wayfinder/SKILL.md` — work-mode procedure.

## Ready-to-use prompt (work session)

> `/wayfinder` — work the dotdev overhaul map (#68). Take the first frontier ticket
> (#69 is Tier-0 — the leaked-key rotate+erase; or name another). Claim it, resolve
> just this one, record + mirror to decision-log, graduate any fog, and handoff.
