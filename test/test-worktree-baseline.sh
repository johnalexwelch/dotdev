#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/dotfiles/.config/agents/skills/setup-worktree/scripts/worktree-baseline.sh"
TMPDIR_BASE=$(mktemp -d)
PASS=0
FAIL=0

cleanup() {
    # Best-effort: remove any worktrees registered under TMPDIR_BASE before
    # deleting the directory tree, so git doesn't leave dangling metadata in
    # the developer's real git dirs. Fixture repos are self-contained so this
    # is a courtesy, not a correctness requirement.
    rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

assert_status() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" -eq "$expected" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    expected exit $expected, got $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local name="$1" haystack="$2" needle="$3"
    if grep -Fq "$needle" <<<"$haystack"; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    expected output to contain: $needle"
        echo "    output was:"
        echo "$haystack"
        FAIL=$((FAIL + 1))
    fi
}

# Build a fresh fixture: a bare "origin" repo with a seeded main branch and a
# local working checkout cloned from it, both under a unique fixture dir.
# Real git commands run against these local, file-path remotes — no network
# needed, same "tmp-git-repo local adapter" shape as test-workflow-guard.sh's
# mocked `gh`.
new_fixture() {
    local name="$1"
    local fixture="$TMPDIR_BASE/$name"
    local origin="$fixture/origin.git"
    local seed="$fixture/seed"
    local work="$fixture/work"

    mkdir -p "$fixture"
    git init --bare -q "$origin"
    git -C "$origin" symbolic-ref HEAD refs/heads/main

    git clone -q "$origin" "$seed"
    git -C "$seed" config user.email "t@example.com"
    git -C "$seed" config user.name "Test"
    echo "seed" >"$seed/README.md"
    git -C "$seed" add README.md
    git -C "$seed" commit -q -m init
    git -C "$seed" push -q origin main
    rm -rf "$seed"

    git clone -q "$origin" "$work"
    git -C "$work" config user.email "t@example.com"
    git -C "$work" config user.name "Test"
    # Untracked on purpose: cut's env-file copy step reads straight off the
    # source checkout's working tree, not out of git history.
    echo "ENVVAL=1" >"$work/.env"

    printf '%s' "$work"
}

echo "=== worktree-baseline.sh tests ==="
echo ""

# --- Happy path: cut, verify, emit ---
work=$(new_fixture happy_path)
wt="$TMPDIR_BASE/happy_path/wt1"

cut_output=$(cd "$work" && bash "$SCRIPT" cut --branch feature/happy --path "$wt")
assert_contains "cut happy path reports resolved base" "$cut_output" "resolved_base: origin/main"
assert_contains "cut happy path emits WORKTREE_BASELINE_GATE" "$cut_output" \
    "WORKTREE_BASELINE_GATE: origin/main -> feature/happy @ $wt"
assert_contains "cut happy path copies .env" "$cut_output" "Copied: .env"
[ -f "$wt/.env" ] && { echo "  PASS: .env actually copied into worktree"; PASS=$((PASS + 1)); } \
    || { echo "  FAIL: .env actually copied into worktree"; FAIL=$((FAIL + 1)); }

set +e
verify_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
verify_status=$?
set -e
assert_status "verify happy path exits 0" 0 "$verify_status"
assert_contains "verify happy path reports PASS" "$verify_output" "PASS:"

emit_output=$(cd "$work" && bash "$SCRIPT" emit --path "$wt")
assert_contains "emit reproduces exact WORKFLOW_BASE_GATE block" "$emit_output" \
    "WORKFLOW_BASE_GATE:
  preferred_base: origin/staging
  resolved_base: origin/main
  fallback_reason: origin/staging_absent
  fetched: true"
assert_contains "emit reproduces exact WORKTREE_BASELINE_GATE line" "$emit_output" \
    "WORKTREE_BASELINE_GATE: origin/main -> feature/happy @ $wt"

# --- Missing base ref: no origin/staging, no resolvable remote default ---
fixture="$TMPDIR_BASE/missing_base"
mkdir -p "$fixture"
git init --bare -q "$fixture/origin.git"
mkdir -p "$fixture/work"
git -C "$fixture/work" init -q
git -C "$fixture/work" config user.email "t@example.com"
git -C "$fixture/work" config user.name "Test"
echo hi >"$fixture/work/f.txt"
git -C "$fixture/work" add f.txt
git -C "$fixture/work" commit -q -m init
git -C "$fixture/work" remote add origin "$fixture/origin.git"

set +e
missing_output=$(cd "$fixture/work" && bash "$SCRIPT" cut --branch feature/none --path "$fixture/wt" 2>&1)
missing_status=$?
set -e
assert_status "cut halts when base ref cannot be resolved" 7 "$missing_status"
assert_contains "missing base ref message names the blocker" "$missing_output" \
    "neither origin/staging nor a valid remote default branch ref could be resolved"

# --- Dirty existing worktree ---
work=$(new_fixture dirty_worktree)
wt="$TMPDIR_BASE/dirty_worktree/wt1"
(cd "$work" && bash "$SCRIPT" cut --branch feature/dirty --path "$wt" >/dev/null)
echo "untracked" >"$wt/scratch.txt"

set +e
dirty_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
dirty_status=$?
set -e
assert_status "verify fails on dirty worktree" 5 "$dirty_status"
assert_contains "dirty verify message names the path" "$dirty_output" "is dirty"

# --- Branch name collision ---
work=$(new_fixture branch_collision)
wt1="$TMPDIR_BASE/branch_collision/wt1"
wt2="$TMPDIR_BASE/branch_collision/wt2"
(cd "$work" && bash "$SCRIPT" cut --branch feature/dup --path "$wt1" >/dev/null)

set +e
collision_output=$(cd "$work" && bash "$SCRIPT" cut --branch feature/dup --path "$wt2" 2>&1)
collision_status=$?
set -e
assert_status "cut fails on existing branch name" 4 "$collision_status"
assert_contains "branch collision message names the branch" "$collision_output" "feature/dup"
[ ! -e "$wt2" ] && { echo "  PASS: no worktree created on branch collision"; PASS=$((PASS + 1)); } \
    || { echo "  FAIL: no worktree created on branch collision"; FAIL=$((FAIL + 1)); }

# --- Path already exists ---
work=$(new_fixture path_exists)
wt="$TMPDIR_BASE/path_exists/wt1"
mkdir -p "$wt"

set +e
path_output=$(cd "$work" && bash "$SCRIPT" cut --branch feature/pathexists --path "$wt" 2>&1)
path_status=$?
set -e
assert_status "cut fails when path already exists" 3 "$path_status"
assert_contains "path-exists message names the path" "$path_output" "$wt"

# --- Stacked-parent ancestry check ---
work=$(new_fixture stacked_parent)
git -C "$work" branch parent/feature-a origin/main
git -C "$work" worktree add "$TMPDIR_BASE/stacked_parent/parentwt" parent/feature-a >/dev/null
git -C "$TMPDIR_BASE/stacked_parent/parentwt" config user.email "t@example.com"
git -C "$TMPDIR_BASE/stacked_parent/parentwt" config user.name "Test"
echo "parent work" >"$TMPDIR_BASE/stacked_parent/parentwt/parent.txt"
git -C "$TMPDIR_BASE/stacked_parent/parentwt" add parent.txt
git -C "$TMPDIR_BASE/stacked_parent/parentwt" commit -q -m "parent commit"

child_wt="$TMPDIR_BASE/stacked_parent/childwt"
stacked_cut_output=$(cd "$work" && bash "$SCRIPT" cut --branch feature/child-a --path "$child_wt" \
    --parent-branch parent/feature-a --parent-pr 42)
assert_contains "stacked cut emits STACKED_WORKTREE_GATE" "$stacked_cut_output" \
    "STACKED_WORKTREE_GATE: origin/main -> parent/feature-a -> feature/child-a @ $child_wt; parent_pr: #42; parent_gates: complete"

set +e
stacked_verify_output=$(cd "$work" && bash "$SCRIPT" verify --path "$child_wt" 2>&1)
stacked_verify_status=$?
set -e
assert_status "stacked verify passes against parent ancestry" 0 "$stacked_verify_status"
assert_contains "stacked verify names the parent branch" "$stacked_verify_output" "parent/feature-a"

# A worktree cut from origin/main directly (no shared history with the
# unrelated parent branch's extra commit) must fail ancestry when checked
# against that parent — proves the ancestry check actually discriminates.
unrelated_wt="$TMPDIR_BASE/stacked_parent/unrelatedwt"
(cd "$work" && bash "$SCRIPT" cut --branch feature/unrelated --path "$unrelated_wt" >/dev/null)
set +e
ancestry_fail_output=$(cd "$work" && bash "$SCRIPT" verify --path "$unrelated_wt" --parent-branch parent/feature-a 2>&1)
ancestry_fail_status=$?
set -e
assert_status "verify fails ancestry check against an unrelated parent" 6 "$ancestry_fail_status"
assert_contains "ancestry failure message names the base" "$ancestry_fail_output" "not a descendant of"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
