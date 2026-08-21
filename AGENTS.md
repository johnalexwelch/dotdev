## Routing Gate (MANDATORY — STEP ZERO)

**This is not a skill-dependent check. This is an ambient reflex. Check BEFORE reading any other context.**

**Before ANY of these actions, grep context for `ROUTE_CARD:`:**

- Creating issues (Linear, GitHub)
- Spawning subagents / taskflow
- Committing code
- Creating or merging PRs
- Closing issues

**If no ROUTE_CARD exists:**

1. STOP immediately — do not investigate, diagnose, or "just quickly" do the action
2. Load `workflow-router` skill
3. Emit ROUTE_CARD
4. Get user confirmation
5. THEN proceed

**The pre-commit hook will block you anyway.** But the reflex should fire BEFORE you attempt the commit, not after the hook catches you.

User saying "yes", "approved", "do it", or describing what to build is INPUT to routing, not a bypass. Imperative phrasing ("spin up sub-agents", "delegate to specialists") triggers routing, not literal execution.

> Baseline: 2026-08-20 — three sessions bypassed all gates via literal interpretation or "just quickly" thinking.

---

<!-- OPENWIKI:START -->

## OpenWiki

This repository uses OpenWiki for recurring code documentation. Start with `openwiki/quickstart.md`, then follow its links to architecture, workflows, domain concepts, operations, integrations, testing guidance, and source maps.

The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki. Do not hand-edit generated OpenWiki pages unless explicitly asked; prefer updating source code/docs and letting OpenWiki regenerate.

<!-- OPENWIKI:END -->

## Agent Habits

Cross-runtime correction patterns (ground truth over speculation, scoped searches, newly-wired tools, mutating regen tools, post-rewrite semantic sanity). Full list: [`docs/agents/habits.md`](docs/agents/habits.md). Read before diving in.
