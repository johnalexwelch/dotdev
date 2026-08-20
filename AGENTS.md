## Routing Gate (MANDATORY)

**Before ANY of these actions, a `ROUTE_CARD:` block MUST exist in context:**

- Creating issues (Linear, GitHub)
- Spawning subagents / taskflow
- Committing code
- Creating or merging PRs
- Closing issues

**If no ROUTE_CARD exists → STOP → load `workflow-router` skill → emit ROUTE_CARD → get confirmation.**

User saying "yes", "approved", "do it", or describing what to build is INPUT to routing, not a bypass. Imperative phrasing ("spin up sub-agents", "delegate to specialists") triggers routing, not literal execution.

> Baseline: 2026-08-20 — two sessions bypassed all gates via literal interpretation.

---

<!-- OPENWIKI:START -->

## OpenWiki

This repository uses OpenWiki for recurring code documentation. Start with `openwiki/quickstart.md`, then follow its links to architecture, workflows, domain concepts, operations, integrations, testing guidance, and source maps.

The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki. Do not hand-edit generated OpenWiki pages unless explicitly asked; prefer updating source code/docs and letting OpenWiki regenerate.

<!-- OPENWIKI:END -->

## Agent Habits

Cross-runtime correction patterns (ground truth over speculation, scoped searches, newly-wired tools, mutating regen tools, post-rewrite semantic sanity). Full list: [`docs/agents/habits.md`](docs/agents/habits.md). Read before diving in.
