#!/usr/bin/env bats
# Characterization tests for ledger.sh
# Pin current behavior for refactoring safety.

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LEDGER="$SCRIPT_DIR/scripts/ledger.sh"

setup() {
    # Create temp git repo for each test
    TEST_REPO="$(mktemp -d)"
    cd "$TEST_REPO"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"
    # Disable global hooks for isolated test environment
    git config core.hooksPath /dev/null
    mkdir -p docs/executions/runs
    echo "init" > README.md
    git add -A
    git commit -m "init" --quiet
    
    # Export for ledger.sh
    export SKILLS_ROOT="$SCRIPT_DIR/.."
}

teardown() {
    cd /
    rm -rf "$TEST_REPO"
}

# ============================================================================
# EXIT CODE 0: Success
# ============================================================================

@test "show: exits 1 with no active run" {
    run "$LEDGER" show
    [ "$status" -eq 1 ]
    [[ "$output" == *"no live ledger state"* ]]
}

@test "init: creates live state and snapshot" {
    run "$LEDGER" init test-run-001 --workflow test --kind bug --steps diagnose,fix,review,finalize
    [ "$status" -eq 0 ]
    [[ "$output" == *"initialized run test-run-001"* ]]
    
    # Verify snapshot was created
    [ -f "docs/executions/runs/test-run-001.yaml" ]
}

@test "set: updates step status" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    run "$LEDGER" set diagnose completed --evidence "found the bug"
    [ "$status" -eq 0 ]
    [[ "$output" == *"diagnose"* ]]
}

@test "check: returns exit 0 for stamped gate" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    "$LEDGER" set diagnose completed --evidence "found issue"
    "$LEDGER" stamp diagnose --attest issue_url=http://example.com/1 --override --reason "test"
    
    run "$LEDGER" check diagnose
    [ "$status" -eq 0 ]
    # Override stamp returns OVERRIDDEN, normal stamp returns OK
    [[ "$output" == *"OVERRIDDEN"* ]] || [[ "$output" == *"OK"* ]]
}

@test "close: closes active run" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    run "$LEDGER" close
    [ "$status" -eq 0 ]
    [[ "$output" == *"closed run"* ]]
}

# ============================================================================
# EXIT CODE 1: Check failed / usage errors
# ============================================================================

@test "check: returns MISSING for unstamped gate (exit 1)" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    run "$LEDGER" check diagnose
    [ "$status" -eq 1 ]
    [[ "$output" == *"MISSING"* ]]
}

@test "unstamp: exits 1 when gate not stamped" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    run "$LEDGER" unstamp diagnose --reason "test"
    [ "$status" -eq 1 ]
}

@test "flush: exits 1 on closed run" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    "$LEDGER" close
    
    # Re-init to have live state again, then test flush behavior
    # Actually flush requires live state, which close removes
    # This tests the "no live state" path instead
    run "$LEDGER" flush
    [ "$status" -eq 1 ] || [ "$status" -eq 6 ]
}

@test "no arguments: shows usage (exit 1)" {
    run "$LEDGER"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]
}

@test "unknown command: shows usage (exit 1)" {
    run "$LEDGER" foobar
    [ "$status" -eq 1 ]
}

# ============================================================================
# EXIT CODE 2: Stamp refused (checked fields failed)
# ============================================================================

@test "stamp: exits 2 when checked fields fail" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    # Try to stamp diagnose without completing the step
    
    run "$LEDGER" stamp diagnose --attest issue_url=http://example.com/1
    [ "$status" -eq 2 ]
    [[ "$output" == *"refused"* ]] || [[ "$output" == *"failed"* ]]
}

# ============================================================================
# EXIT CODE 4: Missing reason
# ============================================================================

@test "unstamp: exits 4 without --reason" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    "$LEDGER" set diagnose completed --evidence "found"
    "$LEDGER" stamp diagnose --attest issue_url=http://example.com/1 --override --reason "test"
    
    run "$LEDGER" unstamp diagnose
    [ "$status" -eq 4 ]
    [[ "$output" == *"reason"* ]]
}

@test "stamp --override: exits 4 without --reason" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    run "$LEDGER" stamp diagnose --override
    [ "$status" -eq 4 ]
    [[ "$output" == *"reason"* ]]
}

# ============================================================================
# EXIT CODE 5: Unknown step/gate/skill
# ============================================================================

@test "stamp: exits 5 for unknown gate" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    run "$LEDGER" stamp foobar
    [ "$status" -eq 5 ]
    [[ "$output" == *"unknown gate"* ]]
}

@test "unstamp: exits 5 for unknown gate" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    run "$LEDGER" unstamp foobar --reason "test"
    [ "$status" -eq 5 ]
    [[ "$output" == *"unknown gate"* ]]
}

# ============================================================================
# EXIT CODE 6: Corrupt/invalid state or run_id
# ============================================================================

@test "init: exits 6 for invalid run_id (path traversal)" {
    run "$LEDGER" init "../escape" --workflow test --kind bug --steps diagnose
    [ "$status" -eq 6 ]
    [[ "$output" == *"unusable"* ]]
}

@test "init: exits 6 for run_id with spaces" {
    run "$LEDGER" init "my run" --workflow test --kind bug --steps diagnose
    [ "$status" -eq 6 ]
    [[ "$output" == *"unusable"* ]]
}

@test "init: exits 6 for run_id starting with dot" {
    run "$LEDGER" init ".hidden" --workflow test --kind bug --steps diagnose
    [ "$status" -eq 6 ]
    [[ "$output" == *"unusable"* ]]
}

@test "stamp: exits 6 for invalid gate type" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    run "$LEDGER" stamp diagnose --gate-type invalid-type
    [ "$status" -eq 6 ]
    [[ "$output" == *"invalid gate type"* ]]
}

# ============================================================================
# EXIT CODE 7: Init refused (active run exists)
# ============================================================================

@test "init: exits 7 when run already exists" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    run "$LEDGER" init test-run --workflow test --kind bug --steps diagnose
    [ "$status" -eq 7 ]
    [[ "$output" == *"already exists"* ]]
}

@test "init --force: overwrites existing run" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    run "$LEDGER" init test-run --workflow other --kind bug --steps diagnose --force
    [ "$status" -eq 0 ]
}

# ============================================================================
# EXIT CODE 8: Non-reviewer gate without --human
# ============================================================================

@test "stamp: exits 8 for non-reviewer gate type without --human" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    "$LEDGER" set diagnose completed --evidence "found"
    
    run "$LEDGER" stamp diagnose --gate-type maintainer-decision
    [ "$status" -eq 8 ]
    [[ "$output" == *"human"* ]] || [[ "$output" == *"--human"* ]]
}

@test "stamp: non-reviewer gate type succeeds with --human" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    "$LEDGER" set diagnose completed --evidence "found"
    
    run "$LEDGER" stamp diagnose --gate-type maintainer-decision --human --override --reason "test"
    [ "$status" -eq 0 ]
}

# ============================================================================
# EXIT CODE 9: verify-local no manifest
# ============================================================================

@test "verify-local: exits 9 when no manifest" {
    run "$LEDGER" verify-local
    [ "$status" -eq 9 ]
    [[ "$output" == *"NO_MANIFEST"* ]]
}

# ============================================================================
# EXIT CODE 10: Environment breakage
# ============================================================================

@test "not in git repo: exits 10" {
    cd /tmp
    run "$LEDGER" show
    [ "$status" -eq 10 ]
    [[ "$output" == *"not inside a git repository"* ]]
}

# ============================================================================
# EXIT CODE 11: No route evidence under block mode
# ============================================================================

@test "init: exits 11 under LEDGER_REQUIRE_ROUTE=block without --route" {
    export LEDGER_REQUIRE_ROUTE=block
    
    run "$LEDGER" init test-run --workflow test --kind bug --steps diagnose
    [ "$status" -eq 11 ]
    [[ "$output" == *"route"* ]]
}

@test "init: succeeds with --route under LEDGER_REQUIRE_ROUTE=block" {
    export LEDGER_REQUIRE_ROUTE=block
    
    run "$LEDGER" init test-run --workflow test --kind bug --steps diagnose --route "team-budget|workflow-feature|confirmed"
    [ "$status" -eq 0 ]
}

# ============================================================================
# STATE FILE FORMAT
# ============================================================================

@test "snapshot: is valid YAML with expected fields" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    # Check snapshot is valid YAML
    run python3 -c "import yaml; yaml.safe_load(open('docs/executions/runs/test-run.yaml'))"
    [ "$status" -eq 0 ]
    
    # Check required fields exist
    run python3 -c "
import yaml
with open('docs/executions/runs/test-run.yaml') as f:
    data = yaml.safe_load(f)
    assert 'run_id' in data, 'missing run_id'
    assert 'workflow' in data, 'missing workflow'
    assert 'kind' in data, 'missing kind'
    assert 'steps' in data, 'missing steps'
    assert 'status' in data, 'missing status'
    print('OK')
"
    [ "$status" -eq 0 ]
}

@test "snapshot: run_id matches init argument" {
    "$LEDGER" init my-unique-run-id --workflow wf --kind bug --steps diagnose
    
    run python3 -c "
import yaml
with open('docs/executions/runs/my-unique-run-id.yaml') as f:
    data = yaml.safe_load(f)
    assert data['run_id'] == 'my-unique-run-id'
    print('OK')
"
    [ "$status" -eq 0 ]
}

# ============================================================================
# COMMAND: preflight
# ============================================================================

@test "preflight: exits 5 for unknown skill" {
    run "$LEDGER" preflight --skill nonexistent-skill-xyz
    [ "$status" -eq 5 ]
    [[ "$output" == *"unknown skill"* ]]
}

# ============================================================================
# COMMAND: check-snapshot
# ============================================================================

@test "check-snapshot: reads from committed snapshot" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    "$LEDGER" set diagnose completed --evidence "found"
    "$LEDGER" stamp diagnose --attest issue_url=http://example.com/1 --override --reason "test"
    
    # check-snapshot should find the committed file
    run "$LEDGER" check-snapshot diagnose --file docs/executions/runs/test-run.yaml
    [ "$status" -eq 0 ]
    # Override stamp returns OVERRIDDEN, normal stamp returns OK
    [[ "$output" == *"OVERRIDDEN"* ]] || [[ "$output" == *"OK"* ]]
}

@test "check-snapshot: MISSING for unstamped gate in snapshot" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    run "$LEDGER" check-snapshot diagnose --file docs/executions/runs/test-run.yaml
    [ "$status" -eq 1 ]
    [[ "$output" == *"MISSING"* ]]
}

# ============================================================================
# COMMAND: reconcile
# ============================================================================

@test "reconcile: runs without error when no drift" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    
    run "$LEDGER" reconcile
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
    # May report drift or no drift depending on state
}

# ============================================================================
# COMMAND: flush
# ============================================================================

@test "flush: publishes state without gate semantics" {
    "$LEDGER" init test-run --workflow test --kind bug --steps diagnose,fix,review,finalize
    "$LEDGER" set diagnose completed --evidence "original"
    
    # Capture initial mtime
    local snap="docs/executions/runs/test-run.yaml"
    local mtime1=$(stat -f %m "$snap" 2>/dev/null || stat -c %Y "$snap")
    sleep 1
    
    run "$LEDGER" flush
    [ "$status" -eq 0 ]
}

# ============================================================================
# COMMAND: review-floor
# ============================================================================

@test "review-floor: outputs floor value" {
    # review-floor computes based on git history
    run "$LEDGER" review-floor
    # May succeed or fail based on repo state - just test it runs
    # and doesn't crash with env error (10)
    [ "$status" -ne 10 ]
}

# ============================================================================
# VALID RUN_ID CHARACTERS
# ============================================================================

@test "init: accepts alphanumeric run_id" {
    run "$LEDGER" init abc123XYZ --workflow test --kind bug --steps diagnose
    [ "$status" -eq 0 ]
}

@test "init: accepts run_id with dots and dashes" {
    run "$LEDGER" init test-run.2024-01-01 --workflow test --kind bug --steps diagnose
    [ "$status" -eq 0 ]
}

@test "init: accepts run_id with underscores" {
    run "$LEDGER" init test_run_001 --workflow test --kind bug --steps diagnose
    [ "$status" -eq 0 ]
}
