# Agent Habits

Recurring correction patterns across sessions — check these before diving in.

This file is the **durable source of truth** for agent habits. OpenWiki may regenerate `AGENTS.md` / `CLAUDE.md`; those stubs only point here. Edit this file when a session teaches a new durable habit.

- **Ground truth over speculation.** Before hunting for how something is configured/installed (a plugin, a marketplace, a mechanism), check what's already visible in context (system prompt's skill/package list, settings.json) before searching the filesystem for it.
- **Scope filesystem searches.** Always pass `path`/`maxdepth` (or the `find`/`grep` tool's `path` param) — don't run repo- or filesystem-wide unscoped searches as a first move.
- **Check newly-wired capabilities before falling back to manual work** for an adjacent task — if a skill, tool, or generator was just set up, use it rather than reinventing the adjacent step by hand.
- **Treat live-checkout runs of mutating/regenerating third-party tools** (doc generators, codegen, scaffolders) like destructive git ops: dry-run in an isolated copy, or diff immediately after — never assume success.
- **After bulk path/string rewrites, do a semantic sanity pass** — string replacement can leave sentences that still parse but no longer mean the intended thing; spot-check wording before calling the migration done.
