---
name: skill-maintenance
description: "Use when auditing, improving, creating, deduplicating, syncing, or reorganizing agent skills (Claude/Codex/SKILL.md), or finding conflicting skills, weak structure, missing frontmatter, stale refs, or over-broad descriptions; or for skill-authoring best practices."
---

## Contract

Consumes: skill directory state (~/.claude/skills, ~/.codex/skills, project skill dirs)
Produces: audit findings report, normalization recommendations, trigger-quality analysis
Requires: none (CORA optional for deterministic findings)
Side effects: may rename/move/edit skill directories and files (after approval)
Human gates: change plan presented for approval before any destructive operations (renames, moves, deletions)

## Context

Typical workflows: skill library hygiene (standalone or periodic)
Pairs well with: write-a-skill, repo-audit

# Skill Maintenance

Audit and improve a personal or project skill library. Treat skills as portable Agent Skills unless the user explicitly wants a platform-specific feature.

## Workflow

1. **Scope the library**
   - Inspect `~/.claude/skills`, `~/.codex/skills`, and project `.claude/skills` or `skills` directories that are relevant to the current repo.
   - If the CORA repo exists at `~/projects/cora`, run `uv run cora --dry-run` for broad maintenance findings.
   - For a targeted skills-source audit when the public `cora skills` command is unavailable, run the Python fallback from `~/projects/cora`:
     `CORA_CLAUDE_SKILLS_DIR=<skills-root> CORA_AUTO_SKILLS_SYNC=false uv run python -c 'import asyncio; from cora.tasks.skills_sync import _run_skills_audit; findings=asyncio.run(_run_skills_audit(dry_run=True)); [print(f"{f.severity.value}: {f.message}") for f in findings]'`
   - Do not move, delete, or rewrite skills until the user approves a concrete change plan.

2. **Research current guidance**
   - For deep audits, browse current official or primary sources before making broad best-practice claims.
   - Prefer, in order:
     - Claude Code skills docs: `https://code.claude.com/docs/en/skills`
     - Anthropic skill authoring best practices: `https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`
     - Agent Skills open standard docs: `https://agentskills.io/`
     - Local OpenAI/Codex `skill-creator` guidance when available.
   - Cite sources in the final audit. Use community posts only as secondary, clearly labeled evidence.

3. **Validate structure**
   - Each skill should live at `<skill-root>/<name>/SKILL.md`.
   - Require YAML frontmatter with `name` and `description` for cross-tool portability.
   - Names should be lowercase letters, digits, and hyphens; avoid vague names such as `helper`, `utils`, or `tools`.
   - Prefer one skill per coherent capability. Flag broad, catch-all, or overlapping skills for split/merge review.
   - Keep `SKILL.md` concise. If it approaches 500 lines or carries detailed reference material, suggest `references/`, `scripts/`, or `assets/` with explicit links from `SKILL.md`.
   - Check markdown links to local bundled resources. Missing links are real maintenance findings.

4. **Review activation quality**
   - The `description` is the main trigger surface. It must say what the skill does and when to use it.
   - Flag descriptions that are vague, too broad, first-person, missing likely trigger phrases, or overloaded with implementation details.
   - Suggest 8-10 should-trigger prompts and 8-10 should-not-trigger prompts for important skills.

5. **Look for conflicts**
   - Compare skill names, descriptions, and bodies for duplicated responsibilities or contradictory instructions.
   - Pay special attention to skills that govern planning, reviewing, testing, CI, GitHub, writing, docs, and skill creation because they often overlap.
   - Prefer consolidating duplicate guidance into one canonical skill plus narrow supporting skills.

6. **Suggest new skills**
   - Search recent docs, plans, audits, PR descriptions, recurring commands, and repeated user corrections for reusable workflows.
   - Recommend a new skill only when it captures a repeatable procedure, non-obvious project convention, specialized tool usage, or a quality bar the agent would miss unaided.
   - For each suggestion, include the proposed `name`, trigger description, source evidence, and why it should be a skill instead of AGENTS.md, a command, or normal code.

7. **Report and edit**
   - Report findings in priority order:
     - Critical load blockers
     - Conflicts or unsafe guidance
     - Structural quality issues
     - Description/trigger improvements
     - New skill opportunities
   - Include exact file paths and concise recommended fixes.
   - After approval, make focused edits, then run CORA dry-run or direct validation again.

## Output Format

```markdown
# Skill Library Audit

## Sources Checked
- [source](url) - why it mattered

## Critical Findings
- `[skill-name]`: issue, evidence, recommended fix

## Conflicts And Consolidation
- `skill-a` vs `skill-b`: overlap/conflict, recommendation

## Structure Improvements
- `[skill-name]`: structure issue, recommendation

## Trigger Improvements
- `[skill-name]`: current problem, proposed description

## New Skill Opportunities
- `proposed-name`: trigger description, source evidence, why this should be a skill

## Next Actions
1. Highest-leverage fix
2. Next fix
3. Validation command
```
