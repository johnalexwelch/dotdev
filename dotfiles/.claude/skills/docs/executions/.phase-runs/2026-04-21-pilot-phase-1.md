# Phase 1 — Pilot canary

**Plan:** /tmp/pilot-plan.md
**Date:** 2026-04-21
**Goal:** Validate that `/execute-phase` parses a phase, dispatches its `[auto]` tasks, surfaces `[human]` tasks, and writes an outcome file.
**Addresses:** GAP-01 (pilot)
**Mode:** live

## Executed

- **Task 1:** "Create the directory `/tmp/pilot-scratch/` and write a file at `/tmp/pilot-scratch/hello.txt` containing the single line `canary` (with a trailing newline)."
  - Status: done
  - Files touched: `/tmp/pilot-scratch/` (dir, created), `/tmp/pilot-scratch/hello.txt` (written)
  - Subagent command: `mkdir -p /tmp/pilot-scratch/ && printf 'canary\n' > /tmp/pilot-scratch/hello.txt && wc -c /tmp/pilot-scratch/hello.txt`
  - Notes: `wc -c` returned `7` bytes (matches `canary\n`, 6 chars + newline). No deviations.

- **Task 2:** "List the contents of `/tmp/pilot-scratch/` (e.g. `ls -la /tmp/pilot-scratch/`) and capture the full listing in your report."
  - Status: done
  - Files touched: none (read-only)
  - Subagent command: `/bin/ls -la /tmp/pilot-scratch/` (first attempt via plain `ls` returned only a bare filename; absolute-path invocation produced the full long listing — see `## Plan parse warnings` for the NEW-04 candidate this surfaced)
  - Listing (verbatim):
    ```
    total 8
    drwxr-xr-x@  3 alexwelch  wheel    96 Apr 21 11:07 .
    drwxrwxrwt  88 root       wheel  2816 Apr 21 11:08 ..
    -rw-r--r--@  1 alexwelch  wheel     7 Apr 21 11:07 hello.txt
    ```

## Pending human

1. Decide the final name of the output artifact (e.g. `phase-1.md` vs. `phase-01.md` vs. something else) before Phase 2 production port.

## Verification (extracted, not run)

> Outcome file at `docs/executions/.phase-runs/<date>-phase-1.md` exists, has the three-section shape (`## Executed` with two entries marked done; `## Pending human` with one entry quoting the task text; `## Verification (extracted, not run)` containing this Verification paragraph). `/tmp/pilot-scratch/hello.txt` exists with content `canary`.

(This paragraph is reproduced here by the pilot skill; Phase 2 of `2026-04-21-skills-updates-design.md` adds a verification subagent that would actually run the falsifiable check against this text.)

## Rollback (reference)

> `rm -rf /tmp/pilot-scratch/` and `rm -f ~/.claude/skills/docs/executions/.phase-runs/2026-04-21-phase-1.md`. No other state changed.

(Note: the referenced rollback path `2026-04-21-phase-1.md` is the filename the contrived plan expected; this pilot test was routed to `2026-04-21-pilot-phase-1.md` to avoid colliding with the outer skills-updates Phase 1 outcome file — see NEW-05 for the production-port fix.)

## Plan parse warnings

- All five expected plan sections were present and parsed (Goal, Tasks, Addresses, Verification, Rollback, Deletes). No warnings.
- **NEW-04 candidate (for skills-updates plan):** The first `ls -la` invocation inside the general-purpose subagent returned only a bare filename — the long-format columns were stripped somewhere in the tool-harness output pipeline. Subagent worked around by using the absolute path `/bin/ls`. The production `/execute-phase` should either (a) advise subagents to prefer absolute-path invocations for commands whose evidence output matters, or (b) teach the post-batch verification subagent to re-execute `git status --porcelain` / `ls -la` itself from the orchestrator rather than trust the subagent's quoted output verbatim. Escalated to `2026-04-21-phase-1.md` `## Follow-ups`.
