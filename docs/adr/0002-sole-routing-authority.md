# 0002. workflow-router is the sole routing authority

`workflow-router` is the single entry point that classifies incoming work and
dispatches it to the appropriate workflow skill. `dotfiles/.claude/reference/workflows.md`
is reference documentation only — it describes the canonical loop but never
routes on its own. OMC keyword shortcuts (`autopilot`, `ralph`, `ultrawork`,
etc.) bypass only the router's classification step; any mutating code, commit,
PR, or delivery action reached through those shortcuts must still satisfy
`WORKTREE_BASELINE_GATE`, `workflow-review`, and `workflow-finalize`. All other
work goes through the router.

## Considered options

- **Let `workflows.md` double as a routing document.** Rejected — two sources
  of routing truth drift; the router's classification table would inevitably
  diverge from the prose diagram.
- **Require OMC shortcuts to also pass through the router's classification
  step.** Rejected — the shortcuts exist specifically to skip classification
  for known power-user intents; instead their outputs are pinned to the same
  delivery gates as router-dispatched work, so skipping classification never
  skips safety.
