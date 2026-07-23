---
name: resolving-merge-conflicts
model: sonnet
reasoning: medium
description: Resolve an in-progress git merge or rebase conflict. Use when git reports merge conflicts, a rebase is paused on a conflict, or the user asks to resolve conflicts.
---

## Contract

Consumes: in-progress git merge or rebase with conflicts, codebase history, CONTEXT.md
Produces: clean resolved working tree, passing automated checks, completed merge/rebase
Requires: git
Side effects: modifies conflicted files in place; stages and commits on completion
Human gates: ambiguous intents that cannot be resolved by reading commit messages or issues — halt and ask rather than guess

## Context

Typical workflows: standalone (pre-PR, post-rebase), workflow-build-one (conflict during feature branch sync)
Pairs well with: tdd, pr-review, workflow-build-one, workflow-finalize

# Resolving Merge Conflicts

## 1. Understand the current state

```bash
git status                         # which files are conflicted
git log --oneline --graph --all    # both branch histories
git log --oneline <base>..<ours>   # what our branch changed
git log --oneline <base>..<theirs> # what the other branch changed
```

Do not touch any conflict markers until you understand what each side was trying to do.

## 2. Find the primary source for each conflict

For each conflicted file, trace the intent of each side:

- Read the commit messages that introduced each change
- If commit messages reference issue numbers, fetch the issue/PR body
- Look at the full hunk, not just the conflict markers — the surrounding lines show the broader context

Goal: be able to state in one sentence what each side intended. If you cannot, read more context — do not guess.

## 3. Resolve each hunk

For each conflict:

1. **Preserve both intents where possible.** Most conflicts are non-exclusive: one side added a function, the other changed the same area for a different reason — both changes belong in the result.
2. **Where intents are incompatible**, pick the one that matches the stated goal of the current merge/rebase (e.g. "we are rebasing our feature onto main" → prefer main's behavior for infrastructure changes, prefer the feature branch for feature-specific code). Note the trade-off in a comment or the commit message.
3. **Never invent new behavior.** The resolution must be a combination of what both sides intended, not a third thing.
4. **Never `--abort`.** If a hunk looks genuinely ambiguous and context does not resolve it, halt and ask the user — do not guess and do not abort.

Remove all conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`). A merged file with markers left in is broken.

## 4. Run automated checks

Discover the project's check suite from CI config, `Makefile`, `package.json`, or `pyproject.toml`. Run in order:

1. Typecheck (tsc, mypy, pyright)
2. Tests (pytest, vitest, jest) — at minimum the files you touched
3. Lint / format (eslint, ruff, prettier) — auto-fix where safe

Fix anything the merge broke. Do not move on until checks pass.

## 5. Finish the merge or rebase

**Merge:**

```bash
git add <resolved files>
git commit   # git will pre-fill the merge commit message; keep it
```

**Rebase:**

```bash
git add <resolved files>
git rebase --continue   # repeat phases 2–5 for each remaining commit
```

State in the commit message which intents were preserved and any trade-off made in step 3.
