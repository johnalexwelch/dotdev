# Session Reflection: Architecture Improvement Test Discovery Gap

**Date**: 2026-08-21  
**Goal**: Run improve-codebase-architecture skill recursively to identify and address architectural friction

## What Went Well

- Multi-lane orchestration worked smoothly — 3 parallel subagents on isolated worktrees
- C1 (zed-herdr tests) delivered 64 characterization tests in ~5 minutes
- C2/C3 correctly applied deletion tests and deferred/discarded work that wasn't justified
- Quick recovery when duplicate test PRs were discovered — closed them cleanly
- Decision-log entries (DL-0019, DL-0020) provide clear future triggers for revisiting deferred work

## What Went Wrong / Friction

1. **Spawned subagents for shell script tests without checking existing coverage** — Loop 1 created bats tests for `ledger.sh` (38 tests) and `worktree-baseline.sh` (30 tests), but the repo already had comprehensive shell test suites in `test/` directory (1728 LOC and 642 LOC respectively). ~2.5 hours of subagent work wasted.

2. **C2 subagent took 136 minutes** vs C1's 5 minutes — extreme variance suggests the subagent may have struggled or stalled. No visibility into intermediate state.

3. **Direct push to main failed** — forgot branch protection, had to create branch + PR for decision-log entries.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| — | None explicit | — | — |

## Lessons

1. **Check existing test infrastructure before spawning test-writing subagents**: The `test/` directory had 8392 LOC of shell tests covering all major scripts. A 30-second grep would have avoided 2+ hours of duplicate work.

2. **Architecture analysis should include test coverage mapping**: The initial analysis identified "zero tests for zed-herdr" but didn't survey shell script test coverage in `test/`.

3. **Long-running subagent variance needs investigation**: C2 taking 27x longer than C1 for comparable work size is a signal — either the task was harder, the subagent got stuck, or there's a systemic issue worth understanding.

## Proposed Improvements

- [ ] `improve-codebase-architecture` — Add "Survey existing test infrastructure" step before recommending test additions. Check both co-located tests (`.test.ts`) and centralized test directories (`test/`, `tests/`, `__tests__/`). (priority: high)

- [ ] `docs/agents/habits.md` — Add habit: "Before spawning test-writing subagents, grep for existing test files covering the target" (priority: med)

- [ ] Subagent task templates — Include "verify no existing tests cover this" as a precondition gate before test-writing work (priority: med)

## Skill Extraction Candidates

*None — the lesson is a refinement of existing skills, not a new repeatable workflow.*
