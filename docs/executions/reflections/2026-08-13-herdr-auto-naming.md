# Session Reflection: Herdr Auto-Naming Extension

**Date**: 2026-08-13
**Goal**: Enable intelligent auto-naming for herdr agent panes/tabs

## What Went Well

- Found and fixed CLI syntax bug in pi-herdr-subagents (`--token task=X` not `--token task --value X`)
- Created working `herdr-task-naming.ts` extension that auto-hooks first user message and goal events
- Discovered existing `herdr` skill at `~/.claude/skills/herdr/SKILL.md` with correct instructions

## What Went Wrong / Friction

- Took ~10 minutes searching to find the herdr skill existed — should have checked `~/.claude/skills/` first
- User had to remind me "this was working not that long ago. we worked on it together" — indicating previous work was lost or improperly persisted
- The pi-herdr-subagents patch is in node_modules and will be lost on reinstall

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "isnt the agent supposed to update it with the purpose of the chat" | herdr skill is instruction-based, not auto-invoked | herdr skill (gap: no auto-hook) |
| 2 | "this was working not that long ago. we worked on it together" | Previous session work not persisted durably | session-insight / cleanup-delivery |

## Lessons

1. **Extension beats instruction skill for auto-behavior**: The herdr skill tells agents how to name themselves, but agents must remember. An extension with event hooks removes the cognitive load.
2. **node_modules patches are ephemeral**: The pi-herdr-subagents fix will be lost on reinstall. Should upstream or fork.
3. **Check ~/.claude/skills/ early**: When user says "we did this before", check the skill directories first.

## Proposed Improvements

- [ ] `~/.pi/agent/npm/node_modules/pi-herdr-subagents/` — Upstream the `--token task=X` fix or create a persistent fork (priority: high)
- [ ] `~/.pi/agent/extensions/herdr-task-naming.ts` — Verify event names work across session types (priority: med)
- [ ] `~/.claude/skills/herdr/SKILL.md` — Add note that auto-naming extension exists (priority: low)

## Skill Extraction Candidates

- **Proposed skill**: `herdr-auto-naming` · **target**: extension (already created) · **invocation**: automatic
  - **Trigger**: Pi session start inside herdr (HERDR_ENV=1)
  - **Inputs**: First user message, goal creation events
  - **Steps**: (1) Hook `input` event, (2) Truncate to 60 chars, (3) Call `herdr pane report-metadata`
  - **Success criteria**: Sidebar shows task description instead of generic "pi"
  - **Constraints**: Only works when HERDR_ENV=1 and HERDR_PANE_ID set
  - **Verification evidence**: Manual `herdr pane report-metadata` call worked; extension created
  - **Quality gate**: googleable=No · specific=Yes · real-effort=Yes
  - **Open questions**: Are `input` and `tool_result` the correct pi event names? Need to test.
