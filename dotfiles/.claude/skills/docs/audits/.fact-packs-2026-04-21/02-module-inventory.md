# Module Inventory

## Summary

The skills directory contains 11 skills (plus one empty `new-project/` dir) totaling 2,957 lines of SKILL.md. The 6 core-loop skills (repo-audit, design-plan, execute-phase, describe-pr, post-mortem, setup-worktree) are all mature with complete frontmatter, 11–28 body sections each, consistent ID vocabulary (FIND-NN / phase numbers), and explicit cross-references via reads/writes paths. 5 installed skills (ci-deploy-fix, slack-update, write-to-obsidian, td-task-management, omc-reference) are orthogonal to the core loop, vary in frontmatter completeness, and serve distinct specialized roles.

## Findings

### Core-loop skills (6)
| Skill | Lines | Inputs | Sections | Frontmatter |
|---|---|---|---|---|
| repo-audit | 313 | 3 (context, focus, path) | 11 | Complete |
| design-plan | 452 | 5 (mode, audit_path, existing_plan, outcome, constraints, output_path) | 28 | Complete |
| execute-phase | 527 | 6 (plan_path, plan_slug, phase, auto_proceed, dry_run, resume) | 27 | Complete |
| describe-pr | 290 | 5 (plan_path, pr_number, branch, apply, base) | 21 | Complete |
| post-mortem | 288 | 4 (plan_path, audit_path, since, scope) | 21 | Complete |
| setup-worktree | 234 | 5 (plan_path, phase, branch, path, setup_command) | 11 | Complete |

All 6 have explicit `reads:` and `writes:` blocks naming other skills' artifacts. Cross-reference graph forms the documented 4-skill core loop + side-car.

### Installed skills (5)
| Skill | Lines | Role | Frontmatter |
|---|---|---|---|
| ci-deploy-fix | 219 | CI/deploy failure diagnosis | Minimal (no `triggers:` array; triggers in description) |
| slack-update | 118 | PR-digest Slack message | Minimal (triggers in description) |
| write-to-obsidian | 160 | Obsidian vault writer | `user_invocable: false`, triggers in description |
| td-task-management | 215 + references/ | CLI task tracking | Very minimal (name + description only) |
| omc-reference | 141 | Agent catalog lookup | `user_invocable: false`, no triggers |

### Stubs / gaps
- **`new-project/`** — directory exists but is empty. No SKILL.md present. Either placeholder or removed-but-not-deleted.
- **`td-task-management/references/`** subdirectory exists and contains support material; not otherwise referenced by other skills.

### Description-to-body alignment
All 11 skills: descriptions accurately reflect body content. No deceptive descriptions. No "planned" descriptions with stub bodies.

## Evidence

```
wc -l */SKILL.md:
  ci-deploy-fix/SKILL.md        219
  describe-pr/SKILL.md          290
  design-plan/SKILL.md          452
  execute-phase/SKILL.md        527
  omc-reference/SKILL.md        141
  post-mortem/SKILL.md          288
  repo-audit/SKILL.md           313
  setup-worktree/SKILL.md       234
  slack-update/SKILL.md         118
  td-task-management/SKILL.md   215
  write-to-obsidian/SKILL.md    160
  Total                         2,957
```

Empty: `new-project/` (no files).

## Open questions

1. What is `new-project/` supposed to contain? Is it a planned skill not yet created?
2. Should the 5 installed skills be regularized to match core-loop frontmatter format (explicit `triggers:`, `inputs:`, `reads:`, `writes:`)?
3. What's in `td-task-management/references/`?
