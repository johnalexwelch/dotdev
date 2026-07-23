# Skill Map (2026-07-17) — corrected

## What went wrong (first call-DAG pass)
We overcorrected on “router doesn’t call everything it lists”:
1. Dropped **all** router outbound edges → router looked orphaned
2. Omitted **isolates** → analysis / incident / data / metric / personas disappeared

Classification fan-out ≠ call graph, but the board still needs **three layers**.

## Rules (current)
| Layer | Style | Meaning |
|-------|--------|---------|
| CALL | blue solid | Immediate Flow / Load-and-run (transitively reduced) |
| ROUTER ENTRY | red dashed | `workflow-router` → audit ENTRY only (not mid-chain) |
| DOMAIN ROUTE | black dashed | Decision routes inside analysis/incident/data/metric skills |
| STANDALONE | nodes, no edges | Remaining skills with no parsed call/route |

### Router ENTRY (included)
feature, build-one, debug, run-backlog, execute-prd, autonomous-backlog, v1-workflow, roadmap-only, finalize, review-only, repo-audit, architecture research, cleanup, effectiveness-audit, session-insight, skill-backlog, workflow-skill, skill-evaluator, executive-doc, prototype-only, polish-only, handoff, OKRs, product-launch

### Not router leaves (mid-chain / finalize-owned)
`receive-review`, `describe-pr`, `watch-ci`, `post-mortem`, `prompt-builder` (default), `to-prd`/`to-issues` as leaves, `execute-phase`, `diagnose`, …

## Board
https://www.tldraw.com/f/dXSnXSmPNnKMlWZ3IlLUN

## Counts (latest inject)
- 93 skill nodes (all skills)
- 38 call edges
- 24 router ENTRY edges
- 32 domain route edges
- 0 unbound arrows

## Regenerator
`/tmp/skillmap/full_map.py` (ephemeral) → `call_payload.json`
