# GRILL_RESULT: ledger.sh Characterization Tests

## Analysis Summary

**Target:** `dotfiles/.config/agents/skills/workflow-ledger/scripts/ledger.sh`

- 1918 LOC, 44 functions
- 13 commands: init, set, stamp, unstamp, flush, check, check-snapshot, reconcile, preflight, review-floor, verify-local, show, close
- Critical infrastructure: workflow enforcement kernel, gate management, state persistence

## Risk × Complexity Matrix

| Function/Area | Risk | Complexity | Test Priority |
|---------------|------|------------|---------------|
| `cmd_init` | HIGH | MEDIUM | P1 - Creates state, validates run_id charset (security) |
| `cmd_stamp` | HIGH | HIGH | P1 - Gate enforcement, checked fields, override semantics |
| `cmd_check` / `gate_verdict` | HIGH | HIGH | P1 - Gate verdict logic (OK/MISSING/STALE/OVERRIDDEN) |
| `cmd_unstamp` | HIGH | MEDIUM | P1 - Revocation with atomic rollback |
| `revoke_and_publish` | HIGH | HIGH | P2 - Atomic revocation with whole-file restore |
| `cmd_check_snapshot` | HIGH | MEDIUM | P1 - CI gate verification |
| `fresh_since` | HIGH | MEDIUM | P2 - Staleness detection (content-verified) |
| `cmd_set` | MEDIUM | LOW | P2 - Step status, implicit revocation |
| `cmd_flush` | MEDIUM | MEDIUM | P2 - Publish without gate semantics |
| `cmd_close` | MEDIUM | LOW | P2 - Run termination |
| `cmd_reconcile` | MEDIUM | MEDIUM | P3 - Drift detection |
| `cmd_preflight` | LOW | LOW | P3 - Tool presence check |
| `cmd_review_floor` | LOW | MEDIUM | P3 - Review threshold |
| `cmd_verify_local` | LOW | MEDIUM | P3 - CI manifest execution |
| `cmd_show` | LOW | LOW | P3 - Display only |

## Trust Seams to Preserve

### Exit Codes (API contract)

- 0: success / check passed
- 1: check failed (MISSING|STALE), usage errors, unstamp of unstamped gate
- 2: stamp refused (checked fields failed)
- 4: missing --reason for override/unstamp
- 5: unknown step/gate/skill
- 6: corrupt state, invalid run_id charset, invalid gate type
- 7: init refused (active run exists)
- 8: non-reviewer gate type without --human
- 9: verify-local no manifest (NO_MANIFEST)
- 10: environment breakage (no python/yaml, not in git repo)
- 11: no route evidence under LEDGER_REQUIRE_ROUTE=block

### State File Formats

- Live state: `$GIT_DIR/ledger/state.yaml` (per-worktree)
- Snapshot: `docs/executions/runs/<run_id>.yaml` (committed, per-run)
- Required fields: run_id, workflow, kind, budget, status, steps

### Gate Semantics

- Valid gates: diagnose, fix, review, finalize
- Valid kinds: feature, bug, phase, docs, skill
- Stamp types: reviewer-validation (agent-stampable), maintainer-decision, operator-runtime, secret-custody (require --human)
- Check verdicts: OK, MISSING, STALE, OVERRIDDEN, OVERRIDE_STALE, SNAPSHOT_DRIFT

### Run_id Charset (security boundary)

- Allowed: A-Za-z0-9._-
- Rejected: empty, starts with dot, contains "..", path separators, spaces, glob metacharacters

## Vertical Slice (First Test)

Started with exit code tests (the API contract) since they're:

1. Easy to verify (status code comparison)
2. High coverage (touch all command entry points)
3. Foundation for more detailed tests

## Test Coverage

38 characterization tests covering:

- All 13 commands
- Exit codes 0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11
- State file creation and YAML validity
- Run_id validation (security charset)
- Gate semantics (stamp/unstamp/check)
- Environment isolation (not in git repo)
- Route evidence enforcement

## Upgrade Path

Future tests to add:

- `fresh_since` staleness detection edge cases
- `revoke_and_publish` rollback on failure
- Concurrent run isolation
- Snapshot drift detection
- Content-based STALE detection
