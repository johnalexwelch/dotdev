---
globs: "**/{pyproject.toml,package.json,requirements*.txt,Dockerfile,docker-compose*.yml}"
---

# Dependency Management Standards

Derived from Anthropic and OpenAI practices.

## Version Pinning

- Runtime deps: compatible ranges (`>=min, <next_major`). Example: `httpx>=0.25.0, <1`.
- Dev tools: exact pins for type checkers and linters (`pyright==1.1.399`, `mypy==1.17`).
- TypeScript: exact-pin the TypeScript version. Caret ranges for linters and test frameworks.

## Lock Files

- Always commit lock files (`uv.lock`, `package-lock.json`).
- Regenerate lock files when changing dependency ranges.

## When to Add a Dependency

- **Add** when: it solves a hard problem and is well-maintained (HTTP clients, validation, type checking).
- **Build in-house** when: it's a small utility (<200 lines), it would add a dep for a single function, or it has a large transitive dependency tree.
- Minimize runtime dependency count. Use `optional-dependencies` / `peerDependencies` for features not everyone needs.

## Security

- Run dependency audits in CI (`pip-audit`, `npm audit`).
- Use Dependabot or Renovate for automated dependency update PRs.
- Audit GitHub Actions versions alongside application deps.

## Tooling

- Python: `uv` for package management (fast, deterministic).
- TypeScript: commit `package-lock.json`, use `npm ci` in CI for reproducible installs.
