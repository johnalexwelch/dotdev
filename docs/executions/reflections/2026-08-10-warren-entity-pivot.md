# Session Reflection: Warren Entity Pivot

**Date**: 2026-08-10
**Goal**: Pivot Warren from markdown-file editing to structured entities with typed relationships and graph-first UI

## What Went Well

- **State-driven autonomous work**: `state.yaml` tracking enabled effective AFK development across 4 phases
- **Incremental commits per phase**: Each phase committed separately, making the work reviewable and revertible
- **Mode toggle approach**: Keeping old markdown code as fallback via UI toggle avoided breaking tests while adding new functionality
- **TypeScript strictness**: `exactOptionalPropertyTypes` caught real type safety issues (undefined vs missing props)
- **Merge over rebase**: When divergence was large (17 commits), `git merge` resolved in one pass vs multiple rebase conflicts

## What Went Wrong / Friction

- **Forgejo outage blocked push**: SSH daemon down on pergamon; continued local but created large divergence requiring complex merge later
- **exactOptionalPropertyTypes churn**: Multiple rounds of type fixes for `prop?: T` vs `prop?: T | undefined` — kept hitting this pattern
- **Rebase abandoned mid-flight**: Started rebase, hit 6 conflict files at commit 5/17, aborted and switched to merge
- **ESLint allowDefaultProject**: Had to manually add each new client file to eslint.config.js — 4 separate edits

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|------------------------|------------|-------------------|
| 1 | "import from actual vault" | Started with empty entity DB, no sample data | workflow-build-one (should verify meaningful test state) |
| 2 | "remove black background" | Dark theme CSS inherited from old components | Entity.css design decision |
| 3 | "make UI easier, less blocky" | Shipped functional but utilitarian CSS | No owning skill — UX polish is judgment |
| 4 | "faster navigation for large campaigns" | EntityList had no filtering/keyboard nav | Same — feature request, not process gap |

## Lessons

1. **Merge beats rebase for large divergence**: When local and remote have diverged significantly (10+ commits each), `git merge` resolves all conflicts once. Rebase requires resolving at each commit, and the same conflict can repeat.

2. **exactOptionalPropertyTypes requires `| undefined` for explicit undefined assignment**: With this tsconfig flag, `prop?: T` means "can be missing" but NOT "can be explicitly set to undefined". Use `prop?: T | undefined` when you want both.

3. **ESLint allowDefaultProject is a scaling bottleneck**: Adding each new client file manually to the allow list creates friction. Consider a glob pattern or moving client files into tsconfig coverage.

4. **Sample data on first run matters**: An empty entity list gives no confidence the system works. Seeding with real-ish data (from the user's actual vault) builds trust.

## Proposed Improvements

- [ ] `eslint.config.js` — Add glob pattern `src/client/**/*.tsx` to allowDefaultProject instead of per-file entries (priority: med)
- [ ] `docs/agents/habits.md` — Add note: "When Forgejo/git remote is unreachable, prefer smaller incremental pushes when it returns rather than accumulating large divergence" (priority: low)
- [ ] `workflow-build-one` — Consider: verify test data exists before declaring "ready to test" for UI work (priority: low)

## Skill Extraction Candidates

None — no repeatable multi-step workflow emerged that isn't already covered by existing skills. The entity pivot was project-specific implementation work, not a generalizable pattern.
