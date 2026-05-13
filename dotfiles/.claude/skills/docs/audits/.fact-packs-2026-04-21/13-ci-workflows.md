# CI / Workflows

## Summary

**Zero CI infrastructure exists in this repo.** No `.github/workflows/`, `.gitlab-ci.yml`, `Makefile`, `package.json`, `.pre-commit-config.yaml`, or any automation. This is a defensible gap for a skills-definition repo (not a product codebase), but it creates specific risks: (a) no automated SKILL.md YAML parse validation, (b) no enforcement of the load-bearing `phase-<N>: <Goal> (addresses <IDs>)` commit-message schema that `/post-mortem` and `/describe-pr` depend on, (c) no pre-commit secret-scanning. The `ci-deploy-fix` skill itself presupposes GitHub Actions infrastructure that this repo doesn't have — the skill is designed for end-user repos, not for this skills repo.

## Findings

### Zero CI configured

- `find . -name '.github' -o -name '.gitlab-ci.yml' -o -name 'Makefile' -o -name 'package.json' -o -name '.pre-commit-config.yaml'`: zero matches
- No remote configured (`git remote -v`: empty)
- No CI runners, no workflows, no pre-commit hooks

### Gap 1 (medium): No automated SKILL.md YAML validation

- SKILL.md files must conform to `---`-bounded YAML frontmatter with `name`, `description`, `triggers`, `inputs`, etc.
- No CI gate runs `python3 -c "import yaml; yaml.safe_load(...)"` on commit
- The skills-updates plan's §10 Definition of Done literally includes a strict-YAML check, but it's executed manually by the orchestrator, not by CI
- A malformed SKILL.md would go undetected until skill-load time

### Gap 2 (high-impact): No commit-message schema enforcement

- `/execute-phase` produces commits with schema `phase-<N>: <Goal> (addresses <ID list>)`
- `/post-mortem` and `/describe-pr` parse this schema to attribute commits to plan phases
- A malformed commit message (e.g., missing phase number, wrong format) would silently break downstream parsing
- No pre-commit hook or CI gate validates the schema

### Gap 3 (low-impact for local-only, medium for future push): No secret scanning

- Repo is freshly `git init`-ed with no remote
- If pushed to GitHub or similar, no pre-push hook or CI step scans for committed secrets
- `gitleaks`, `detect-secrets`, or GitHub's native secret scanning would be prudent before any push

### `/ci-deploy-fix` skill is designed for end-user repos, not for this one

- `ci-deploy-fix/SKILL.md` workflow assumes GitHub Actions workflows exist (`gh run list`, `gh run view --log-failed`)
- Scanning for CI failure patterns like Ruff, mypy, pytest, Docker build errors presupposes a real application codebase
- Not a bug in the skill — just a clarification that the skill serves consumers of this skills-definition repo, not the repo itself

### `/repo-audit` question 13 can't self-report on this repo

- `/repo-audit`'s 13th discovery question literally inspects CI/workflows/Makefile etc.
- Running `/repo-audit` on this repo (as in the current Phase 5 dogfood) correctly surfaces "zero CI" as this fact-pack's primary finding
- Meta: this audit is the mechanism for flagging the gap

### No release automation

- No documented "plan-complete branches promote to main" path
- User manually merges/fast-forwards phase branches
- Defensible for a skills repo (no binary artifact to release); noted for completeness

## Evidence

- `find . -type f \( -name '*.yml' -o -name '*.yaml' -o -name 'Makefile' -o -name 'package.json' \) -not -path './.git/*'`: 0 non-skill matches
- `git remote -v`: empty (no remote configured)
- `git log --oneline`: 2 commits, both on 2026-04-21, neither references CI
- `ci-deploy-fix/SKILL.md` contains `gh run view`, `gh run list --workflow=ci.yml` references

## Open questions

1. Will this repo be pushed to GitHub? If yes: add `.github/workflows/skill-lint.yml` that runs YAML parsing + commit-schema check on PRs.
2. Should a local `.pre-commit-config.yaml` be added to run before-push checks without requiring GitHub?
3. Is there a plan to dogfood `/ci-deploy-fix` on a real GitHub Actions repo to validate its workflow?
4. Does it make sense to add a `Makefile` with `make verify-skills` that runs strict-YAML + commit-schema checks (usable by both humans and any future CI)?
