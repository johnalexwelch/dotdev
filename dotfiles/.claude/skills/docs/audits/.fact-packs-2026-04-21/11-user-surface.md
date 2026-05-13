# User Surface

## Summary

All 6 core-loop skills have strong, consistent user surfaces: documented `triggers:`, explicit `## Example Invocation` blocks showing both user input and expected Claude output, and detailed `## Error Handling` tables with specific behaviors per failure mode. Voice is unified (Staff Engineer persona, blameless tone, evidence-driven, imperative). The 5 installed skills vary: `ci-deploy-fix` and `slack-update` have triggers in description only (no formal array) and lack formal Example Invocation blocks; `td-task-management` has no slash surface (bash CLI only); `write-to-obsidian` is marked non-invocable; `omc-reference` is reference-only. No central command index exists — discovery is per-file.

## Findings

### Core loop: strong surface consistency

All 6 skills have:

- ✅ Formal `triggers:` array (4-5 triggers each)
- ✅ Complete `## Example Invocation` block (often 2 examples: clean path + gate/failure path)
- ✅ Detailed `## Error Handling` table (6-16 rows per skill)
- ✅ Consistent vocabulary (FIND-NN, NEW-NN, phase-<N>, `[auto]`/`[human]`)
- ✅ Unified Staff Engineer voice

### Installed skills: variable surface quality

**ci-deploy-fix:**

- ❌ No formal `triggers:` array (triggers embedded in description)
- ❌ No `## Example Invocation` block showing user → Claude interaction
- ✅ Workflow documented in Steps 1-7
- ✅ Detailed failure classification table (lint, types, tests, builds, migrations, k8s, skaffold, IAM diagnose-only)

**slack-update:**

- ❌ No formal `triggers:` array
- ⚠️  Partial Example Invocation — shows example output only, not user input step
- ✅ Token-resolution chain documented
- ✅ mrkdwn syntax reference included

**td-task-management:**

- ❌ Not slash-invocable — accessed via bash CLI (`td <cmd>`)
- ⚠️  Minimal frontmatter (name + description only)
- ❌ No error handling table
- ✅ Session-isolation and agent-handoff workflows documented

**write-to-obsidian:**

- N/A — marked `user_invocable: false`
- ✅ Clear rules (bash heredoc, mkdir -p, required frontmatter)
- Used as internal subroutine by other skills

**omc-reference:**

- N/A — marked `user_invocable: false`
- ✅ Reference content (agents, tools, skills registry, commit protocol)

### Error-handling quality

Core loop: all have specific behaviors per row (14 rows in `/execute-phase`, 16 in `/describe-pr`, 9 in `/design-plan`, 8 in `/post-mortem`, 10 in `/setup-worktree`, 8 in `/repo-audit`).

Installed: ci-deploy-fix has a classification table; slack-update has inline fallback chains; td-task-management has no error handling documented.

### Discoverability gap

- No `SKILL_INDEX.md`, `COMMANDS.md`, or root `README.md`
- Users discover available slash commands via Claude Code's internal skill loader (which reads frontmatter)
- No human-readable index of "what slash commands exist and when to use each"

### Voice coherence

- Core loop: unified (active voice, imperative, evidence-first, blameless). Every skill has a "Preflight" Step 0.
- Installed: domain-specific but internally coherent per skill (ci-deploy-fix is DevOps-flavored, slack-update is comms-flavored, td-task-management is orchestration-flavored)

## Evidence

- Extracted `triggers:` blocks from all 11 SKILL.md frontmatter
- Counted `## Example Invocation` blocks (6 core-loop have them; 0 of 5 installed do in full form)
- Counted `## Error Handling` table rows per skill
- Scanned for central command index (none found at root, none in docs/)

## Open questions

1. Should the 5 installed skills be regularized to core-loop format (formal `triggers:` array, `## Example Invocation` block, `## Error Handling` table)?
2. Should a `docs/COMMANDS.md` or root `README.md` index all available slash commands with one-line descriptions?
3. Is `td-task-management`'s bash-CLI interface intended to be the only entry point, or should a slash wrapper exist?
