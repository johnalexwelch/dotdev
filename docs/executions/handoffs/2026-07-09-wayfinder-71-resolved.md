# Handoff — dotdev overhaul: router-exclusivity (#71) resolved

Exit: completion (one ticket resolved; frontier work remains)
Target: claude or pi
Generated: 2026-07-09

## Start here (resuming agent)

You are resuming multi-session `/wayfinder` **work-mode** in `johnalexwelch/dotdev`. No `state.yaml` — durable state is the **map issue on GitHub (#68)**, not a file.

1. Read the map (#68) at low res + the paths under "Files to read first".
2. Chain so far: map charted → #69 (FIND-09) → #70 (keystone) → **#71 resolved this session**. Read prior handoffs only for context you lack; don't redo.
3. Do **Next step 1**. **Never resolve more than one ticket per session.** No open blocker gates the next session.

**Next step 1:** Run `/wayfinder` against map #68. Take **one** frontier ticket. Frontier is now **#72, #73, #74, #75** (all open, unassigned, unblocked). Options:
- **#73** (research, AFK, agent-drivable) — fresh-Mac reproducible-install proof across pi/claude/codex (FIND-11–19, 29). Recommended if going AFK.
- **#74** (research, AFK) — token/context-efficiency baseline + approach (FIND-26). Note: **#71 deferred budget to #74** ("integrity wins; budget managed elsewhere") — so #74 now owns the context-budget lever explicitly.
- **#72** (prototype, HITL) — in-session visibility/trust; needs live exchange + `/prototype`.
- **#75** (grilling, HITL) — doc-management structure (FIND-20); needs live exchange.
**Claim first** (assign self), then resolve → comment → close → append map Decisions-so-far → mirror via `/decision-log` → graduate fog → `/handoff`.

## What was done this session

- **Resolved #71** (router-exclusivity, HITL grilling). Decision: **strict router-entry (provisional)** — `workflow-router` + self-contained advisory/writing tools stay model-invokable (**39**); all workflow entries, sub-steps, executors/mutators, orchestrators, and shared references are `disable-model-invocation: true` (**46 total**, 12 existing + 34 new). Owner is **skeptical — locked in to trial live, may revisit.**
- **Enabling mechanic proven:** locking is safe because parents load locked skills **by path** (`workflow-finalize` → "Load and execute `describe-pr/SKILL.md`") and humans `/slash` them; restart preserved via direct slash + `workflow-router` Resume Check (`state.yaml`).
- **Rule for future skills:** default to locked unless `workflow-router` or a no-mutation/no-route advisory-writing tool.
- Resolution comment posted, #71 closed, **map #68** Decisions-so-far appended, **mirrored** to `docs/decision-log.md`. Committed + pushed `15636b0`.

## What is NOT done

Four open frontier tickets (all unclaimed/unblocked): **#72** (prototype/HITL), **#73** (research/AFK), **#74** (research/AFK), **#75** (grilling/HITL).

Remaining fog (on map): MCP fleet capture/wiring (FIND-25, needs user creds); nvim navigation-first rebuild (FIND-28); dangling-tool reconciliation (FIND-22/23/24/10). Codex-wiring fog graduated under #70.

**#71 follow-up is EXECUTION, not a frontier decision:** the 34 frontmatter flips + encoding the rule into `write-a-skill` fold into the `verify-wiring.sh` cleared-route build (a `disable-model-invocation` audit enforces the set — ties to #70). Do NOT re-ticket it. The exact 39-open / 46-locked lists are in the #71 resolution comment and decision-log.

## Blockers requiring human input

None gate the next session. HITL *within* tickets: #72, #75 need live exchange; MCP fog needs user endpoints/creds.

## Key decisions made

- **#71:** strict router-entry, provisional. Judgment calls to watch during trial: `decision-log` kept open; `git-guardrails`/`slack-update`/`tdd` locked but debatable (first to reopen if the gate chafes); the `workflow-*` entries being locked is the biggest bet (trades topic-reach for a single front door). Full record: decision-log 2026-07-09.

## Files to read first

- **Map #68** (source of truth): https://github.com/johnalexwelch/dotdev/issues/68
- #71 resolution comment (full 39/46 per-skill lists): https://github.com/johnalexwelch/dotdev/issues/71
- /Users/alexwelch/dotdev/docs/decision-log.md — decisions (latest: #71, 2026-07-09)
- /Users/alexwelch/dotdev/docs/research/2026-07-09-wiring-verification-method.md — #70 asset (verify-wiring.sh spec that absorbs #71's apply)
- /Users/alexwelch/dotdev/docs/audits/2026-07-09-setup-audit.md — fog (FIND-09…29)
- /Users/alexwelch/dotdev/dotfiles/.claude/skills/write-a-skill/SKILL.md — the invocation rule #71 sharpened
- /Users/alexwelch/dotdev/dotfiles/.claude/skills/wayfinder/SKILL.md — work-mode procedure
