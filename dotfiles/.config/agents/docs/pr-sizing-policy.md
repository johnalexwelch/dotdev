# PR Sizing Policy

Keep implementation PRs reviewable by default:

- **Target:** ~400 reviewable changed lines
- **Acceptable range:** 300–500 lines
- **Hard cap:** 500 lines (exceptions require written justification in PR body)
- **Coherence beats padding:** a complete 180-line PR beats bundling unrelated work to hit 300

## What counts as reviewable

Count: source code, tests, docs, config, migrations, fixture/contract changes.
Exclude: generated files, lockfiles, snapshots, vendored output, local state artifacts.

## Slice discipline

Right-sized PRs should be vertical slices — one narrow behavior through the needed layers, independently demoable or verifiable.

Horizontal splits allowed only when independently verifiable: mechanical refactors, migrations with clear validation, generated API/schema updates, preparatory changes with their own tests.

Never split by technical layer merely to hit the line budget if that creates half-shipped behavior.

## When to pause and split

Pause when work is likely to exceed 500 lines, spans unrelated concerns, requires multiple verification stories, or forces broad non-atomic churn.

A split proposal must include: proposed PRs, target line estimate each, dependencies, verification path per PR, what stays out of scope, and AFK-safety assessment.

## Size exceptions

PRs over 500 lines require a written exception explaining why splitting would be unsafe. Common candidates: coordinated migrations, broad mechanical renames, dependency upgrades, cross-cutting changes with unsafe intermediate states.
