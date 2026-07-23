# Context Map

## Contexts

- [brain](.claude/CONTEXT.md) — Alex's personal knowledge system: Librarian/ROWAN,
  brain layers, heartbeat ops, agent roster (MIRA, CLEO, WREN, ARIA)
- [agents](dotfiles/.config/agents/CONTEXT.md) — dotdev's own workflow-skill system:
  router, gate, ledger, worktree baseline, delivery policy

## Relationships

No shared vocabulary or events between the two contexts. **brain** is Alex's
personal-knowledge domain (implementation mostly lives outside this repo, at
`~/projects/rowan/`). **agents** is the workflow-skill machinery that runs
*this* repo's own planning/execution/delivery pipeline
(`dotfiles/.config/agents/skills/`). They happen to share a repo, not a domain.
