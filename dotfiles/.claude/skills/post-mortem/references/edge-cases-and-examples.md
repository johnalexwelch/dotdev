# post-mortem — error handling, examples, tuning

Load when you hit an unusual input, want the worked example, or need the tuning guidance.

## Error handling
| Failure | Behavior |
|---|---|
| Not in a git repo | Abort. |
| No plan found | Abort — nothing to retro against. |
| No audit referenced/findable | Phase-based attribution only; note audit linkage unavailable in §Summary. |
| `since` commit not findable | Fall back to `HEAD~50`, note the approximation. |
| Test command fails | Note in §Summary; don't block. |
| Plan has no `FIND-NN` | Skip finding table, use phase-only structure; recommend future audits adopt IDs. |
| scope="complete" but phases in-progress | Auto-downgrade to "partial" and note it. |

## Cursor-IDE output
When running in Cursor IDE, also emit a `canvases/<date>-post-mortem.canvas.tsx` rendering the planned-vs-actual table, drift, and NEW-NN findings. Skip the canvas when headless (CI, Codex AFK, non-IDE).

## Tuning notes
Run with `scope=partial` after each major phase lands — short loops beat one big retro. For teams, a "who decided what, when" column helps (frame as learning, not blame). If NEW-NN count >5, the original audit had blind spots — feed them into the next `/repo-audit` as `focus=`. Keep post-mortems short; >500 lines means the audit was too coarse or the plan too ambitious. Conditional retro gate in workflow-finalize: routine issue work usually skips (record `not_applicable_with_reason`); multi-phase/refactor runs before `describe-pr` so the PR body can cite drift/NEW-NN; audit-derived work feeds roadmap/PRD/issues/next audit.
