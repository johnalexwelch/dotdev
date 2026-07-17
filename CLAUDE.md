<!-- OPENWIKI:START -->

## OpenWiki

This repository uses OpenWiki for recurring code documentation. Start with `openwiki/quickstart.md`, then follow its links to architecture, workflows, domain concepts, operations, integrations, testing guidance, and source maps.

The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki. Do not hand-edit generated OpenWiki pages unless explicitly asked; prefer updating source code/docs and letting OpenWiki regenerate.

<!-- OPENWIKI:END -->

## Agent Habits

Recurring correction patterns across sessions — check these before diving in:

- **Ground truth over speculation.** Before hunting for how something is configured/installed (a plugin, a marketplace, a mechanism), check what's already visible in context (system prompt's skill/package list, settings.json) before searching the filesystem for it.
- **Scope filesystem searches.** Always pass `path`/`maxdepth` (or the `find`/`grep` tool's `path` param) — don't run repo- or filesystem-wide unscoped searches as a first move.
