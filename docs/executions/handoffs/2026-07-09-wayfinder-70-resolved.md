# Handoff — dotdev overhaul: wiring-verification method (#70) resolved

Exit: completion (one ticket resolved; more frontier work remains)
Target: claude or pi
Generated: 2026-07-09

## Start here (resuming agent)

You are resuming multi-session `/wayfinder` **work-mode** in `johnalexwelch/dotdev`. No `state.yaml` — durable state is the **map issue on GitHub (#68)**, not a file.

1. Read the map (#68) at low res, and the paths under "Files to read first".
2. This chain: map charted → #69 (FIND-09) resolved → **#70 resolved this session**. Only read prior handoffs for context you lack; don't redo.
3. Do **Next step 1** below. **Never resolve more than one ticket per session.** No open blocker gates the next session.

**Next step 1:** Run `/wayfinder` against map #68. Take **one** frontier ticket. Frontier is now **#71, #72, #73, #74, #75** (all open, unassigned, unblocked). Recommended: **#71** (router-exclusivity) — now *backed* by #70's decision (the static audit will enforce the `disable-model-invocation` set, so #71 only needs to decide the set). It's a HITL grilling → resolve through live exchange, agent never answers the human's side. AFK alternative: **#73** or **#74** (research, agent-drivable). **Claim first** (assign self), then resolve → comment → close → append map Decisions-so-far → mirror via `/decision-log` → graduate any newly-specifiable fog → `/handoff`.

## Where we are

Flat frontier of independent investigation tickets under map #68. Destination: reproducible clean install across pi/claude/codex, verified wiring, in-session visibility, doc-management, token-lean. Two tickets resolved so far (#69 security, #70 keystone). Five frontier tickets remain + fog.

## What was done this session

- **Resolved #70** (wiring-verification method, the destination keystone). Decision: two-layer method — (1) *reachable* proven in CI via a static wiring audit + hook-fire smoke test; (2) *invoked* proven by telemetry (Langfuse for claude, pi-observability for pi), sampled, never a gate; codex static-only until a trace sink exists. Resolution comment posted, issue closed.
- **Research asset:** `docs/research/2026-07-09-wiring-verification-method.md` (includes runnable-check spec for `scripts/verify-wiring.sh`).
- **Map #68 updated:** Decisions-so-far line added; FIND-27 codex fog note graduated (verification stance now decided; remaining codex work folds into the `verify-wiring.sh` cleared-route build — no separate frontier decision needed, so no new ticket spawned).
- **Mirrored** to `docs/decision-log.md` (2026-07-09 entry). Committed + pushed `91995e0`.

## What is NOT done

Five open frontier tickets, all unclaimed/unblocked:
- **#71** `grilling` (HITL) — router-exclusivity: which internal skills get `disable-model-invocation` (12/85 today). Backed by #70.
- **#72** `prototype` (HITL) — in-session visibility/trust: what a session should surface.
- **#73** `research` (AFK) — fresh-Mac reproducible-install verification across pi/claude/codex (FIND-11–19, 29).
- **#74** `research` (AFK) — token/context-efficiency baseline + approach, incl. pi context-stack dedup (FIND-26).
- **#75** `grilling` (HITL) — doc-management structure: canonical pages + generated lists (FIND-20).

Remaining fog (on map): MCP fleet capture/wiring (FIND-25, needs user creds); nvim navigation-first rebuild (FIND-28); dangling-tool reconciliation (FIND-22/23/24/10). Codex-wiring fog now graduated into #70's decision + cleared-route build.

## Blockers requiring human input

None gate the next session. HITL *within* tickets: #71, #72, #75 need live exchange; MCP fog needs user endpoints/creds before it can graduate.

## Key decisions made

- **#70:** wiring = two claims. *Reachable* (deterministic → CI: static audit + hook-fire smoke test). *Invoked* (non-deterministic → telemetry, sampled, never a gate). Cleared route (infra) → `/design-plan` → `/execute-phase` to build `scripts/verify-wiring.sh` + a telemetry query recipe. Full record: decision-log 2026-07-09.

## Suggested skills

- `wayfinder` — work-mode entry point.
- `grill-with-docs` + `domain-modeling` — #71, #72, #75 (HITL).
- `repo-audit` / `deep-research` — #73, #74 (research).
- `prototype` — #72. `decision-log` — mirror resolution.

## Files to read first

- **Map #68** (source of truth): https://github.com/johnalexwelch/dotdev/issues/68
- /Users/alexwelch/dotdev/docs/research/2026-07-09-wiring-verification-method.md — #70 asset (this session)
- /Users/alexwelch/dotdev/docs/audits/2026-07-09-setup-audit.md — fog (FIND-09…29)
- /Users/alexwelch/dotdev/docs/agents/issue-tracker.md → "Wayfinding operations" — tracker ops
- /Users/alexwelch/dotdev/dotfiles/.claude/skills/wayfinder/SKILL.md — work-mode procedure
- /Users/alexwelch/dotdev/docs/decision-log.md — decisions (latest: #70, 2026-07-09)
- /Users/alexwelch/dotdev/docs/executions/handoffs/ — prior handoffs in this chain
