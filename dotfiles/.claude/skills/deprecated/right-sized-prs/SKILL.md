---
name: right-sized-prs
model: haiku
description: Defines reviewable PR sizing policy and split discipline for implementation work. Use when work mentions right-sized PRs, split PRs, PR budget, reviewable diff size, 300-500 lines, slice sizing, scope creep, oversized PRs, or when a workflow creates or evaluates implementation slices.
---

## Deprecation Status

Status: deprecated as a skill. Policy extracted to ~/.claude/docs/pr-sizing-policy.md for direct reference.

- Replaced by: ~/.claude/docs/pr-sizing-policy.md
- Date: 2026-06-10

---


# Right-Sized PRs

## Policy

Keep implementation PRs reviewable by default:

- Target: about 400 reviewable changed lines.
- Acceptable range: 300-500 reviewable changed lines.
- Default cap: 500 reviewable changed lines.
- Coherence beats padding: a complete, reviewable 180-line PR is better than bundling unrelated work to reach 300.

Apply this to code, tests, docs, config, migrations, and skill files. The policy is about reviewer load, not runtime code only.

## Count Reviewable Changed Lines

Use reviewable changed lines, not net LOC.

Count:

- Source code and tests.
- Documentation and skill markdown that requires human review.
- Config, migration, fixture, and contract changes that affect behavior or maintenance.

Exclude when they are not the subject of the PR:

- Generated files.
- Mechanically regenerated lockfiles.
- Snapshots or vendored output.
- Local state artifacts, caches, and tool output.

If exclusions materially affect the size claim, name them in the PR description.

## Slice Rules

Right-sized PRs should usually be vertical slices: one narrow behavior through the needed layers, independently demoable or verifiable.

Horizontal splits are allowed only when the result is independently verifiable, such as:

- Mechanical refactors or renames.
- Migrations with clear validation.
- Generated API or schema updates.
- Preparatory changes that have their own tests or checks.

Do not split by technical layer merely to hit the line budget if that creates half-shipped behavior or integration risk.

## When A Task Is Too Large

Pause and propose a split when the work:

- Is likely to exceed 500 reviewable changed lines.
- Spans unrelated concerns.
- Requires multiple independent verification stories.
- Forces broad file churn that is not logically atomic.

Split proposals must include:

- Proposed PRs.
- Target line estimate for each PR.
- Dependencies and whether stacked PRs are needed.
- Verification for each PR.
- What stays out of scope.
- Whether each PR is AFK-safe or needs human approval.

Create new issues only through the project's normal issue workflow after user approval or existing workflow authorization.

## Size Exceptions

PRs over 500 reviewable changed lines require a Size Exception. Allow one only when the change is logically atomic and hard to split safely.

Common candidates:

- Coordinated migrations.
- Broad mechanical renames.
- Dependency upgrades.
- Generated contract updates.
- Cross-cutting changes where splitting would create unsafe intermediate states.

The PR description must explain why the PR was not split.

## Checklist

Before creating or finalizing a PR:

1. Estimate reviewable changed lines against the branch base.
2. Identify excluded generated, mechanical, or local-state files.
3. Confirm the PR has one coherent behavior or independently verifiable change.
4. If over 500 lines or unrelated, produce a split proposal and wait for approval when the split changes issue scope.
5. If over 500 lines and atomic, write a Size Exception.
6. Add PR Size evidence to the PR body.
