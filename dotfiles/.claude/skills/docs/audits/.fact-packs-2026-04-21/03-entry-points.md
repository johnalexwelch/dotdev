# Entry Points

## Summary

The skills directory exposes 38 distinct trigger phrases across 9 invokable surfaces: 6 core-loop slash commands, 2 keyword-triggered installed skills (ci-deploy-fix, slack-update), 1 CLI-based skill (td-task-management — bash `td <cmd>`), 2 non-invocable reference/utility skills (write-to-obsidian, omc-reference). No shell scripts, cron jobs, or launchd plists exist at repo root. All trigger phrases are distinct — zero overlap across skills.

## Findings

### Core-loop slash commands (6)

- **`/repo-audit`** — 5 triggers: `/repo-audit`, "audit this repo", "state of the repo", "where are the gaps", "what's fragile here"
- **`/design-plan`** — 5 triggers: `/design-plan`, "write a design doc", "create a refactor plan", "turn this audit into a plan", "revise the plan"
- **`/execute-phase`** — 4 triggers: `/execute-phase`, "execute phase", "run phase", "land phase"
- **`/describe-pr`** — 4 triggers: `/describe-pr`, "describe pr", "generate pr description", "write pr body"
- **`/post-mortem`** — 5 triggers: `/post-mortem`, "post-mortem", "retro the refactor", "what happened vs the plan", "close the loop"
- **`/setup-worktree`** — 4 triggers: `/setup-worktree`, "setup worktree", "create worktree", "isolated checkout"

All six have `triggers:` arrays in frontmatter, so are discoverable by Claude Code's skill loader.

### Keyword-only installed skills (2)

- **ci-deploy-fix** — 6 keyword triggers embedded in description (no `triggers:` array): "CI failed", "build broke", "deploy failed", "fix the red check", "pipeline is failing", "CI is red"
- **slack-update** — 5 keyword triggers in description: "slack update", "send update", "engineering update", "daily update", "PR summary"

### Non-slash-command skills (3)

- **td-task-management** — no slash command; primary interface is bash `td <subcommand>` (usage, start, log, handoff, review, approve). Not discoverable via Claude Code trigger system.
- **write-to-obsidian** — `user_invocable: false`; used as internal subroutine by other skills. 5 trigger phrases in description but marked non-invocable.
- **omc-reference** — `user_invocable: false`; auto-loaded when OMC agents are delegated to. No triggers.

### Repo-root artifacts

- No shell scripts at root
- No `*.plist` (launchd)
- No cron references
- Only `.gitignore`, two design plan markdown files, `.omc/` state dir, and skill subdirs

### Trigger overlap analysis

All 38 trigger phrases are unique. No skill's triggers match another's. No ambiguity.

## Evidence

- Extracted `triggers:` arrays from each SKILL.md frontmatter
- Scanned descriptions for keyword-trigger patterns
- `ls /Users/alexwelch/.claude/skills/` — confirmed no scripts, plists at root
- `git log --all` — 2 commits total, no scheduler/cron setup

## Open questions

1. Should ci-deploy-fix and slack-update be regularized with formal `triggers:` arrays like the core loop?
2. Is td-task-management intended to also be slash-invocable, or is bash CLI the definitive interface?
3. No central command index (no `COMMAND_INDEX.md`). Is discovery-by-reading-every-SKILL.md acceptable?
