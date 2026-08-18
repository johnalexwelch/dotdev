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
[ -f "$wt/.env" ] && {
    echo "  PASS: .env actually copied into worktree"
    PASS=$((PASS + 1))
} ||
    {
        echo "  FAIL: .env actually copied into worktree"
        FAIL=$((FAIL + 1))
    }

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
[ ! -e "$wt2" ] && {
    echo "  PASS: no worktree created on branch collision"
    PASS=$((PASS + 1))
} ||
    {
        echo "  FAIL: no worktree created on branch collision"
        FAIL=$((FAIL + 1))
    }

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

# --- Forged sidecar must not satisfy verify (PR #166 post_mortem pattern) ---
# verify's ancestry ground truth comes from git itself (re-resolved base per
# base-branch-policy), never from the cut-written sidecar; the sidecar is a
# cross-check that fails loudly on mismatch.

# A raw `git worktree add` checkout that does NOT descend from the real
# resolved base, plus a hand-written sidecar pointing RESOLVED_BASE at a ref
# the checkout does descend from. Trusting the sidecar passes this; ground
# truth must reject it.
work=$(new_fixture forged_sidecar)
git -C "$work" branch stale
echo "advance" >>"$work/README.md"
git -C "$work" commit -qam "advance main past stale"
git -C "$work" push -q origin main
wt="$TMPDIR_BASE/forged_sidecar/wt1"
git -C "$work" worktree add -b feature/forged "$wt" stale >/dev/null 2>&1
cat >"$TMPDIR_BASE/forged_sidecar/.worktree-baseline.wt1.state" <<EOF
BRANCH=feature/forged
WT_PATH=$wt
PREFERRED_BASE=origin/staging
RESOLVED_BASE=stale
FALLBACK_REASON=origin/staging_absent
STACKED=false
PARENT_BRANCH=
PARENT_PR=
EOF
set +e
forged_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
forged_status=$?
set -e
assert_status "verify rejects forged sidecar on a non-descendant worktree" 6 "$forged_status"
assert_contains "forged-sidecar rejection names the real base" "$forged_output" "not a descendant of origin/main"

# Tampered RESOLVED_BASE on a genuinely well-based worktree: ancestry ground
# truth holds, but the sidecar no longer matches it — fail loudly, don't trust.
work=$(new_fixture tampered_base)
wt="$TMPDIR_BASE/tampered_base/wt1"
(cd "$work" && bash "$SCRIPT" cut --branch feature/tamper --path "$wt" >/dev/null)
git -C "$work" branch old origin/main
sed -i '' 's|^RESOLVED_BASE=.*|RESOLVED_BASE=old|' "$TMPDIR_BASE/tampered_base/.worktree-baseline.wt1.state"
set +e
tampered_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
tampered_status=$?
set -e
assert_status "verify fails on sidecar RESOLVED_BASE mismatch" 11 "$tampered_status"
assert_contains "base-mismatch message names ground truth" "$tampered_output" "does not match git ground truth"
assert_contains "base-mismatch message names the field" "$tampered_output" "RESOLVED_BASE"

# Tampered BRANCH: the sidecar's recorded branch must match the branch git
# actually has checked out in the worktree.
work=$(new_fixture tampered_branch)
wt="$TMPDIR_BASE/tampered_branch/wt1"
(cd "$work" && bash "$SCRIPT" cut --branch feature/real --path "$wt" >/dev/null)
sed -i '' 's|^BRANCH=.*|BRANCH=feature/imposter|' "$TMPDIR_BASE/tampered_branch/.worktree-baseline.wt1.state"
set +e
branch_mismatch_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
branch_mismatch_status=$?
set -e
assert_status "verify fails on sidecar BRANCH mismatch" 11 "$branch_mismatch_status"
assert_contains "branch-mismatch message names the field" "$branch_mismatch_output" "BRANCH"

# A sidecar carrying anything but known KEY=VALUE lines is tampering, and it
# must never execute: load_state used to source the file, so an injected
# `echo PASS; exit 0` line ran as shell inside verify and won outright.
work=$(new_fixture injected_sidecar)
wt="$TMPDIR_BASE/injected_sidecar/wt1"
git -C "$work" worktree add -b feature/inject "$wt" origin/main >/dev/null 2>&1
cat >"$TMPDIR_BASE/injected_sidecar/.worktree-baseline.wt1.state" <<EOF
BRANCH=feature/inject
WT_PATH=$wt
PREFERRED_BASE=origin/staging
RESOLVED_BASE=origin/main
FALLBACK_REASON=origin/staging_absent
echo "PASS: injected" ; exit 0
STACKED=false
PARENT_BRANCH=
PARENT_PR=
EOF
set +e
injected_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
injected_status=$?
set -e
assert_status "verify rejects a sidecar with a non-KEY=VALUE line" 11 "$injected_status"
assert_contains "injected-line rejection names the problem" "$injected_output" "unrecognized"

# No sidecar at all: verify stands on git ground truth alone — a clean
# worktree genuinely descending from the resolved base passes standalone.
work=$(new_fixture no_sidecar)
wt="$TMPDIR_BASE/no_sidecar/wt1"
git -C "$work" worktree add -b feature/bare "$wt" origin/main >/dev/null 2>&1
set +e
no_sidecar_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
no_sidecar_status=$?
set -e
assert_status "verify passes without a sidecar on genuine ground truth" 0 "$no_sidecar_status"
assert_contains "sidecar-less verify reports PASS" "$no_sidecar_output" "PASS:"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
