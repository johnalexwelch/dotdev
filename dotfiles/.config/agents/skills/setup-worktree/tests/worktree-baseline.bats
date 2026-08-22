#!/usr/bin/env bats
# Characterization tests for worktree-baseline.sh
# Pin current behavior before any refactoring.

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../scripts" && pwd)"
SCRIPT="$SCRIPT_DIR/worktree-baseline.sh"

setup() {
    # Create a temp git repo for each test
    TEST_ROOT="$(mktemp -d)"
    cd "$TEST_ROOT"
    git init >/dev/null 2>&1
    git checkout -b main >/dev/null 2>&1 || true
    git config user.email "test@test.com"
    git config user.name "Test"
    git config core.hooksPath /dev/null  # disable global hooks in test repo
    echo "initial" > file.txt
    git add file.txt
    git commit --no-verify -m "initial" >/dev/null 2>&1
    
    # Setup origin (bare repo)
    ORIGIN_ROOT="$(mktemp -d)"
    git clone --bare "$TEST_ROOT" "$ORIGIN_ROOT/origin.git" >/dev/null 2>&1
    git remote add origin "$ORIGIN_ROOT/origin.git" >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1
}

teardown() {
    cd /
    rm -rf "$TEST_ROOT" "$ORIGIN_ROOT" 2>/dev/null || true
}

# ============================================================================
# Usage / Exit code 1
# ============================================================================

@test "exit 1: no subcommand" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
}

@test "exit 1: unknown subcommand" {
    run "$SCRIPT" bogus
    [ "$status" -eq 1 ]
}

@test "exit 1: cut missing --branch" {
    run "$SCRIPT" cut --path /tmp/test
    [ "$status" -eq 1 ]
}

@test "exit 1: cut missing --path" {
    run "$SCRIPT" cut --branch test-branch
    [ "$status" -eq 1 ]
}

@test "exit 1: verify missing --path" {
    run "$SCRIPT" verify
    [ "$status" -eq 1 ]
}

@test "exit 1: emit missing --path" {
    run "$SCRIPT" emit
    [ "$status" -eq 1 ]
}

# ============================================================================
# verify / Exit code 2 - worktree not found
# ============================================================================

@test "exit 2: verify nonexistent path" {
    run "$SCRIPT" verify --path /nonexistent/path/12345
    [ "$status" -eq 2 ]
    [[ "$output" =~ "worktree not found" ]]
}

# ============================================================================
# cut / Exit code 3 - path already exists
# ============================================================================

@test "exit 3: cut path already exists" {
    mkdir -p "$TEST_ROOT/existing"
    run "$SCRIPT" cut --branch test-br --path "$TEST_ROOT/existing"
    [ "$status" -eq 3 ]
    [[ "$output" =~ "path already exists" ]]
}

# ============================================================================
# cut / Exit code 4 - branch already exists
# ============================================================================

@test "exit 4: cut branch already exists" {
    git branch existing-branch
    run "$SCRIPT" cut --branch existing-branch --path "$TEST_ROOT/new-wt"
    [ "$status" -eq 4 ]
    [[ "$output" == *"already exists"* ]]
}

# ============================================================================
# verify / Exit code 5 - dirty working tree
# ============================================================================

@test "exit 5: verify dirty worktree" {
    # Create a worktree first
    run "$SCRIPT" cut --branch clean-branch --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    # Make it dirty
    echo "dirty" > "$TEST_ROOT/wt/untracked-file.txt"
    
    run "$SCRIPT" verify --path "$TEST_ROOT/wt"
    [ "$status" -eq 5 ]
    [[ "$output" =~ "dirty" ]]
}

@test "verify: env files don't trigger dirty check" {
    run "$SCRIPT" cut --branch envtest --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    # These are known artifacts, shouldn't trigger dirty
    echo "test" > "$TEST_ROOT/wt/.env"
    echo "test" > "$TEST_ROOT/wt/.nvmrc"
    
    run "$SCRIPT" verify --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
}

# ============================================================================
# verify / Exit code 6 - ancestry check failed
# ============================================================================

@test "exit 6: verify not descendant of base" {
    # Create worktree
    run "$SCRIPT" cut --branch ancestry-test --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    # Reset to orphan commit (not descendant of base)
    cd "$TEST_ROOT/wt"
    git checkout --orphan orphan-branch >/dev/null 2>&1
    echo "orphan" > file.txt
    git add file.txt
    git commit -m "orphan" >/dev/null 2>&1
    git checkout -b ancestry-test >/dev/null 2>&1 || git branch -f ancestry-test
    git checkout ancestry-test >/dev/null 2>&1
    cd "$TEST_ROOT"
    
    run "$SCRIPT" verify --path "$TEST_ROOT/wt" --base origin/main
    [ "$status" -eq 6 ]
    [[ "$output" =~ "not a descendant" ]]
}

# ============================================================================
# Exit code 7 - base branch could not be resolved
# ============================================================================

# exit 7 requires origin to exist but return no valid default branch.
# Hard to trigger in isolation; tested via exit 10 (fetch fail) instead.
# The code path is: fetch OK → no staging → remote show fails → symref fails → exit 7

@test "exit 10: cut fails when fetch fails" {
    # Break origin URL so fetch fails
    git remote set-url origin /nonexistent/path
    
    run "$SCRIPT" cut --branch fetch-fail --path "$TEST_ROOT/new-wt"
    [ "$status" -eq 10 ]
    [[ "$output" == *"git fetch origin --prune failed"* ]]
}

# ============================================================================
# cut / Exit code 8 - parent branch doesn't exist (stacked)
# ============================================================================

@test "exit 8: stacked cut with nonexistent parent" {
    run "$SCRIPT" cut --branch child --path "$TEST_ROOT/wt" --parent-branch nonexistent-parent --parent-pr 123
    [ "$status" -eq 8 ]
    [[ "$output" == *"does not exist"* ]]
}

# ============================================================================
# Exit code 9 - git worktree add failed (hard to trigger in isolation)
# ============================================================================

# Skip: would need to corrupt git state

# ============================================================================
# Exit code 10 - git fetch failed (cut only; verify degrades)
# ============================================================================

@test "verify: fetch failure degrades to warning (exit 0 if otherwise valid)" {
    # Create worktree first while fetch works
    run "$SCRIPT" cut --branch fetch-test --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    # Break origin URL
    git remote set-url origin /nonexistent/path
    
    # verify should still work with stale warning
    run "$SCRIPT" verify --path "$TEST_ROOT/wt" --base origin/main
    [ "$status" -eq 0 ]
    [[ "$output" =~ "PASS" ]]
}

# ============================================================================
# Exit code 11 - state sidecar mismatch
# ============================================================================

@test "exit 11: state file missing required key" {
    run "$SCRIPT" cut --branch state-test --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    # Corrupt state file by removing a key
    state_file="$TEST_ROOT/.worktree-baseline.wt.state"
    grep -v "BRANCH=" "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
    
    run "$SCRIPT" verify --path "$TEST_ROOT/wt"
    [ "$status" -eq 11 ]
    [[ "$output" =~ "missing required key" ]]
}

@test "exit 11: state file has unrecognized line" {
    run "$SCRIPT" cut --branch state-unrec --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    state_file="$TEST_ROOT/.worktree-baseline.wt.state"
    echo "BOGUS_KEY=value" >> "$state_file"
    
    run "$SCRIPT" verify --path "$TEST_ROOT/wt"
    [ "$status" -eq 11 ]
    [[ "$output" =~ "unrecognized line" ]]
}

@test "exit 11: state BRANCH mismatch" {
    run "$SCRIPT" cut --branch real-branch --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    state_file="$TEST_ROOT/.worktree-baseline.wt.state"
    sed -i.bak 's/BRANCH=real-branch/BRANCH=fake-branch/' "$state_file"
    
    run "$SCRIPT" verify --path "$TEST_ROOT/wt"
    [ "$status" -eq 11 ]
    [[ "$output" =~ "does not match git ground truth" ]]
}

# ============================================================================
# Exit code 12 - detached HEAD
# ============================================================================

@test "exit 12: verify detached HEAD" {
    run "$SCRIPT" cut --branch detach-test --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    cd "$TEST_ROOT/wt"
    git checkout --detach HEAD >/dev/null 2>&1
    cd "$TEST_ROOT"
    
    run "$SCRIPT" verify --path "$TEST_ROOT/wt"
    [ "$status" -eq 12 ]
    [[ "$output" =~ "detached HEAD" ]]
}

# ============================================================================
# cut: happy path
# ============================================================================

@test "cut: creates worktree and state file" {
    run "$SCRIPT" cut --branch happy-cut --path "$TEST_ROOT/new-wt"
    [ "$status" -eq 0 ]
    
    # Worktree exists
    [ -d "$TEST_ROOT/new-wt" ]
    [ -f "$TEST_ROOT/new-wt/file.txt" ]
    
    # State file exists (sibling to worktree, not inside)
    [ -f "$TEST_ROOT/.worktree-baseline.new-wt.state" ]
    
    # Output contains gate lines
    [[ "$output" =~ "WORKTREE_BASELINE_GATE:" ]] || [[ "$output" =~ "WORKFLOW_BASE_GATE:" ]]
}

@test "cut: state file contains required keys" {
    run "$SCRIPT" cut --branch state-keys --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    state_file="$TEST_ROOT/.worktree-baseline.wt.state"
    grep -q "^BRANCH=state-keys$" "$state_file"
    grep -q "^WT_PATH=" "$state_file"
    grep -q "^PREFERRED_BASE=" "$state_file"
    grep -q "^RESOLVED_BASE=" "$state_file"
    grep -q "^FALLBACK_REASON=" "$state_file"
    grep -q "^STACKED=false$" "$state_file"
    grep -q "^PARENT_BRANCH=$" "$state_file"
    grep -q "^PARENT_PR=$" "$state_file"
}

@test "cut: stacked worktree records parent info" {
    # Create parent branch first
    git checkout -b parent-branch
    git push origin parent-branch >/dev/null 2>&1
    git checkout main
    
    run "$SCRIPT" cut --branch child-branch --path "$TEST_ROOT/wt" --parent-branch parent-branch --parent-pr 42
    [ "$status" -eq 0 ]
    
    state_file="$TEST_ROOT/.worktree-baseline.wt.state"
    grep -q "^STACKED=true$" "$state_file"
    grep -q "^PARENT_BRANCH=parent-branch$" "$state_file"
    grep -q "^PARENT_PR=42$" "$state_file"
    
    [[ "$output" =~ "STACKED_WORKTREE_GATE:" ]]
}

# ============================================================================
# verify: happy path
# ============================================================================

@test "verify: clean worktree passes" {
    run "$SCRIPT" cut --branch verify-happy --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    run "$SCRIPT" verify --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "PASS:" ]]
}

@test "verify: accepts --base override" {
    run "$SCRIPT" cut --branch base-override --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    run "$SCRIPT" verify --path "$TEST_ROOT/wt" --base origin/main
    [ "$status" -eq 0 ]
    [[ "$output" =~ "caller-supplied base" ]]
}

# ============================================================================
# emit: happy path
# ============================================================================

@test "emit: outputs gate from state file" {
    run "$SCRIPT" cut --branch emit-test --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    run "$SCRIPT" emit --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "WORKFLOW_BASE_GATE:" ]]
    [[ "$output" =~ "WORKTREE_BASELINE_GATE:" ]]
}

@test "emit: accepts manual overrides" {
    run "$SCRIPT" emit --path "$TEST_ROOT" --branch manual-br --base origin/custom --preferred origin/staging --fallback-reason manual_test
    [ "$status" -eq 0 ]
    [[ "$output" =~ "resolved_base: origin/custom" ]]
    [[ "$output" =~ "fallback_reason: manual_test" ]]
}

@test "emit: stacked flag produces STACKED_WORKTREE_GATE" {
    run "$SCRIPT" emit --path "$TEST_ROOT" --branch child --base origin/main --stacked --parent-branch parent --parent-pr 99
    [ "$status" -eq 0 ]
    [[ "$output" =~ "STACKED_WORKTREE_GATE:" ]]
    [[ "$output" =~ "parent_pr: #99" ]]
}

# ============================================================================
# Base branch resolution
# ============================================================================

@test "resolve: prefers origin/staging when present" {
    # Create staging branch on origin
    git checkout -b staging
    git push origin staging >/dev/null 2>&1
    git checkout main
    
    run "$SCRIPT" cut --branch staging-pref --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    state_file="$TEST_ROOT/.worktree-baseline.wt.state"
    grep -q "^RESOLVED_BASE=origin/staging$" "$state_file"
    grep -q "^FALLBACK_REASON=not_applicable$" "$state_file"
}

@test "resolve: falls back to default branch when no staging" {
    # No staging branch, should fall back to main (the default)
    run "$SCRIPT" cut --branch fallback-test --path "$TEST_ROOT/wt"
    [ "$status" -eq 0 ]
    
    state_file="$TEST_ROOT/.worktree-baseline.wt.state"
    grep -q "^RESOLVED_BASE=origin/main$" "$state_file"
    grep -q "^FALLBACK_REASON=origin/staging_absent$" "$state_file"
}

# ============================================================================
# Relative path handling
# ============================================================================

@test "cut: absolutizes relative path" {
    run "$SCRIPT" cut --branch rel-path --path "relative-wt"
    [ "$status" -eq 0 ]
    
    # State file should have absolute path
    state_file="$TEST_ROOT/.worktree-baseline.relative-wt.state"
    wt_path="$(grep "^WT_PATH=" "$state_file" | cut -d= -f2)"
    [[ "$wt_path" = /* ]]
}
