# Deprecated Skills

These skills are kept for historical visibility only. Do not route new work to them.
The concrete retired `SKILL.md` files are normalized as top-level directories
(`../ci-deploy-fix/`, `../td-task-management/`, `../grill-me/`) so skill sync
tooling can validate them without nested-path exceptions.

## Fully Retired

| Deprecated Skill | Use Instead | Why |
|---|---|---|
| `ci-deploy-fix` | `workflow-debug` for failures; `workflow-finalize` -> `watch-ci` for PR CI; `receive-review` for review feedback | Bypasses the current workflow gates and issue/PR reconciliation model |
| `td-task-management` | Workflow progress ledgers, `WORKFLOW_*_GATE` blocks, and `handoff` | Superseded by workflow-native progress, gate, and handoff artifacts |
| `grill-me` | `grill-with-docs`, `v1-idea-grill`, `dnd-grill`, or `dnd-grill-with-canon` | Superseded by domain-specific grilling workflows and decision logging |

## Standalone Use Deprecated

These skills remain active outside this folder because workflows load them as implementation helpers. Do not invoke them as standalone delivery routes.

| Skill | Workflow Owner |
|---|---|
| `review` | `workflow-review` |
| `describe-pr` | `workflow-finalize` |
| `watch-ci` | `workflow-finalize` |
| `post-mortem` | `workflow-finalize` conditional gate |
| `setup-worktree` | `workflow-build-one`, `workflow-debug`, `run-backlog`, or `workflow-finalize` human-gate sidecar |

If a prompt, transcript, or repo doc says to run the old Audit Loop, route through `workflow-router` instead.
