# Session Reflection: FIND-4 _TerminalEmitter extraction (deep-dive)

**Date**: 2026-07-29
**Goal**: Ship the deep-dive FIND-4 narrow win — extract `_run_generator`'s terminal-emit closures into a testable `_TerminalEmitter` — with full review + finalize + merge.

## What Went Well

- **Ground-truth over proxy (strong win).** Compacted memory said PR #1595 (FIND-3) was still open/queued. Before trusting it, I grepped the actual `origin/staging` file and found `logger.warning` already present, then confirmed via `gh pr view` that #1595 had merged out-of-band. Checking the authoritative source prevented branching off a wrong assumption.
- Text-anchored edits (not line numbers) survived a stale line-number map from the compaction summary — the edit tool matched verbatim snippets regardless of drift.
- Risk-lane review earned its keep: it traced all 9 closed-over vars for reassignment/mutation after the new construction point — the exact behavioral risk of a late-binding→by-value capture change — and cleared it with evidence.

## What Went Wrong / Friction

- **Spun on `grep`/`find` hunting the ledger.** Burned ~4 tool calls doing broad recursive searches across `~/.herdr` and `~/.claude` to locate the deep-dive ledger; user interrupted with "you are spinning on grep." The `deep-dive-review` SKILL states the canonical path outright: `~/.deep-dive/<repo-slug>.md`. Root cause: session resumed from compaction (which didn't carry the ledger path), and I filesystem-searched instead of reading the owning skill's Contract line first.
- **Stale file copy after `ruff format`.** Wrote `test_terminal_emitter.py`, ran `ruff format` (which reshaped a multi-line call onto one line), then an `edit` failed on content drift because my oldText came from the pre-format version. Cheap recovery (tool gave a good retry hint), but avoidable.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "you are spinning on grep" — stop broad FS search for the ledger | Didn't consult the owning skill's documented ledger path before searching; path lost in compaction | agent habit / `deep-dive-review` (path is already in Contract) |

## Lessons

1. **When resuming compacted work, re-read the owning skill's Contract before filesystem-searching for its artifacts.** Skills name their state files (ledger, config) explicitly; a `grep -rl` across home dirs is slower and noisier than one skill read. Compaction drops these paths — treat "where does X live?" as a skill lookup, not a search.
2. **Re-read a file after any formatter/codegen step before editing it.** `ruff format` / `prettier` mutate on disk; the agent's last-written copy is a proxy that goes stale the moment a formatter runs.

## Proposed Improvements

- [ ] Agent habit (`docs/agents/habits.md`): "Resuming compacted work → look up artifact paths in the owning skill's Contract line, don't filesystem-search." (priority: med)
- [ ] Agent habit: "After running a formatter/codegen on a file, re-read before the next `edit` — the in-memory copy is stale." (priority: low)
- [ ] `deep-dive-review` SKILL — consider echoing the resolved `~/.deep-dive/<repo-slug>.md` path into the run's own summary/handoff output so a later compacted resume keeps it. (priority: low)

<!-- No Skill Extraction Candidates: the work was a standard refactor fully covered by deep-dive-review + workflow-review + workflow-finalize; no new repeatable pattern emerged. -->
