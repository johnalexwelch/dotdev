# Git Conventions

Derived from Anthropic and OpenAI repository practices.

## Commits
- Conventional Commits format: `type(scope): description`.
- Types: `feat`, `fix`, `perf`, `refactor`, `chore`, `docs`, `test`, `ci`, `build`.
- Scope is optional but encouraged — keep it short (`api`, `auth`, `db`, `ui`).
- Subject line under 72 characters, imperative mood.
- `test` and `ci` commits are hidden from changelogs.

## Branches
- `feature/<description>` or `feat/<description>` for new work.
- `fix/<description>` for bug fixes.
- `chore/<description>` for maintenance.
- Never commit directly to `main`.
- Before applying fixes/commits, verify current branch (`git branch --show-current`) matches the intended target — especially in stacked-PR setups. Confirm commits land on the right branch before pushing.

## PRs
- Squash merge feature branches for a clean linear history.
- PR title follows conventional commit format (it becomes the merge commit).
- Include: summary, test plan, and any breaking changes.
- Never enable auto-merge until required CI checks are green AND all existing bot/reviewer comments have been read and addressed. Read review comments before merging, not after.

## Versioning
- SemVer. Tag with `v` prefix (`v1.2.3`).
- Automate changelog generation from commit types.
