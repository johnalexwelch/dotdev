#!/usr/bin/env bash
# test-pre-commit-hook.sh — Tests for the routing enforcement pre-commit hook
# 
# Baseline: 2026-08-21 — hook fails on pi-checkpoint commits because it checks
# work-tree path instead of git-dir path

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${ROOT}/dotfiles/.config/git/hooks/pre-commit"
TMPDIR_BASE="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() {
    rm -rf "${TMPDIR_BASE}"
}
trap cleanup EXIT

# Create a mock git repo for testing
setup_test_repo() {
    local repo_dir="${TMPDIR_BASE}/test-repo"
    mkdir -p "${repo_dir}"
    cd "${repo_dir}"
    git init --quiet
    echo "test" > file.txt
    git add file.txt
    git commit --quiet -m "initial" --no-verify
    echo "${repo_dir}"
}

# Test helper: run hook and check result
run_hook_test() {
    local name="$1"
    local expected_exit="$2"
    shift 2
    
    local status=0
    "$@" bash "${HOOK}" >/dev/null 2>&1 || status=$?
    
    if [[ "${status}" -eq "${expected_exit}" ]]; then
        echo "  PASS: ${name}"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: ${name} (expected exit ${expected_exit}, got ${status})"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== pre-commit hook tests ==="
echo ""

# Test 1: Normal repo without routing evidence should fail
echo "Test: Normal repo without routing evidence"
repo=$(setup_test_repo)
cd "${repo}"
echo "change" >> file.txt
git add file.txt
run_hook_test "rejects commit without routing evidence" 1 env -i HOME="${HOME}" PATH="${PATH}"

# Test 2: Repo with ROUTED_SESSION=1 should pass
echo "Test: Bypass with ROUTED_SESSION"
run_hook_test "allows commit with ROUTED_SESSION=1" 0 env -i HOME="${HOME}" PATH="${PATH}" ROUTED_SESSION=1

# Test 3: Repo with .pi/routing-confirmed file should pass  
echo "Test: Bypass with routing-confirmed file"
mkdir -p .pi
echo "route_id: test" > .pi/routing-confirmed
run_hook_test "allows commit with routing-confirmed file" 0 env -i HOME="${HOME}" PATH="${PATH}"
rm -rf .pi

# Test 4: CRITICAL - pi checkpoint repo should skip (via git-dir check)
# This is the bug - checkpoint uses --git-dir pointing to ~/.pi/... but
# --work-tree pointing elsewhere
echo "Test: Pi checkpoint repo skips routing check"
checkpoint_git_dir="${HOME}/.pi/test-checkpoint-${RANDOM}"
mkdir -p "${checkpoint_git_dir}"
git init --bare --quiet "${checkpoint_git_dir}"

# Simulate what pi-checkpoint does: git-dir under ~/.pi, work-tree elsewhere
cd "${TMPDIR_BASE}"
mkdir -p checkpoint-workdir
cd checkpoint-workdir
echo "checkpoint data" > data.txt

# Run the hook with git-dir pointing to ~/.pi/...
# The hook should detect this and exit 0 (skip)
GIT_DIR="${checkpoint_git_dir}" run_hook_test "skips pi checkpoint repo (git-dir under ~/.pi)" 0 env -i HOME="${HOME}" PATH="${PATH}" GIT_DIR="${checkpoint_git_dir}"

rm -rf "${checkpoint_git_dir}"

# Test 5: SKIP_ROUTING_CHECK bypass
echo "Test: SKIP_ROUTING_CHECK bypass"
cd "${repo}"
rm -rf .pi
run_hook_test "allows commit with SKIP_ROUTING_CHECK=1" 0 env -i HOME="${HOME}" PATH="${PATH}" SKIP_ROUTING_CHECK=1

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi
exit 0
