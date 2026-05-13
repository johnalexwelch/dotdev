# Legacy vs. New

## Summary

The repository is in a clean state with no half-refactored artifacts. Only 2 commits exist (baseline + gitignore). Zero `.bak`, `.old`, or `.orig` files. No commented-out sections in any SKILL.md. Language like "legacy" / "deprecated" / "superseded" appears only in contextual roles (e.g., `/repo-audit`'s discovery-question slug "legacy-vs-new" is the question itself, not a deprecation marker). All 11 skills are current and load-bearing. No non-core-loop skill duplicates core-loop functionality.

## Findings

### Clean state evidence

- Zero `*.bak`, `*.old`, `*.orig`, or numbered-copy files
- No tarballs inside the repo tree (the `skills.pre-phase-*.tgz` tarballs live one level up at `~/.claude/`, outside this repo)
- No commented-out sections in SKILL.md files (grep for `<!--` finds zero matches in skill files)
- 2 commits total: `b9a579e` (baseline) and `019414d` (gitignore OMC runtime state)

### Core-loop dependency chain (load-bearing)

1. `/repo-audit` — FIND-NN producer (entry point)
2. `/design-plan` — consumes FIND-NN, produces `§5.<N> Phase` blocks
3. `/execute-phase` — consumes phases, writes `.phase-runs/` outcome files + branches + commits
4. `/describe-pr` — consumes `.phase-runs/` + commits, produces PR body
5. `/post-mortem` — consumes all upstream, produces retro with NEW-NN (feeds back to next `/repo-audit`)
6. `/setup-worktree` — on-demand side-car, consumes plan phase headers

Each step is necessary. Removing any breaks the loop.

### No duplicated functionality

Five installed skills are orthogonal:

- `ci-deploy-fix` — single CI failure fix, no overlap with multi-phase orchestration
- `slack-update` — PR-digest publisher, no overlap with plan/execute
- `write-to-obsidian` — vault I/O, no overlap with repo state
- `td-task-management` — session-scoped task tracking (orthogonal to plan-phase mapping)
- `omc-reference` — read-only lookup reference, no state mutation

### No deprecation language

Grep for "legacy", "deprecated", "superseded", "old", "refactor" across all SKILL.md files returns 27 matches, all contextual:

- `/repo-audit` discovery question slug: `04 | legacy-vs-new` (the audit question itself)
- `/execute-phase` tutorial examples referencing "legacy scripts"
- `/design-plan` tuning notes mentioning "refactor" as a use case
- Branch-naming convention `refactor/phase-<N>-<slug>`

No SKILL.md description contains deprecation notices or "replaced by" language.

## Evidence

- `git log --oneline`: 2 commits only, both on 2026-04-21
- `find . -name '*.bak' -o -name '*.old' -o -name '*.orig'`: no matches
- `grep -r '<!--' skills/*/SKILL.md`: no matches
- `grep -il 'deprecated\|legacy\|superseded' */SKILL.md`: 3 files contain the words, all in contextual/tutorial roles

## Open questions

1. Are there offline/historical skill versions from before commit `b9a579e` worth preserving in git notes or a CHANGELOG?
2. Should there be a `VERSION` or `CHANGELOG.md` at root capturing the evolution of the skills?
3. Is there a promotion-to-main workflow envisioned, or will main stay as the only branch?
