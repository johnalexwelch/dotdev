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
# Sidecars are regenerated whole from heredocs (not sed -i) so the mutation is
# portable across BSD/GNU sed on CI runners.
work=$(new_fixture tampered_base)
wt="$TMPDIR_BASE/tampered_base/wt1"
(cd "$work" && bash "$SCRIPT" cut --branch feature/tamper --path "$wt" >/dev/null)
git -C "$work" branch old origin/main
cat >"$TMPDIR_BASE/tampered_base/.worktree-baseline.wt1.state" <<EOF
BRANCH=feature/tamper
WT_PATH=$wt
PREFERRED_BASE=origin/staging
RESOLVED_BASE=old
FALLBACK_REASON=origin/staging_absent
STACKED=false
PARENT_BRANCH=
PARENT_PR=
EOF
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
cat >"$TMPDIR_BASE/tampered_branch/.worktree-baseline.wt1.state" <<EOF
BRANCH=feature/imposter
WT_PATH=$wt
PREFERRED_BASE=origin/staging
RESOLVED_BASE=origin/main
FALLBACK_REASON=origin/staging_absent
STACKED=false
PARENT_BRANCH=
PARENT_PR=
EOF
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

# --- Review round-1 hardening contracts ---

# Ambiguous short refnames must not steer the recomputed base: a local TAG
# literally named origin/staging shadows the remote-tracking namespace in
# rev-parse/merge-base short-name resolution, silently retargeting ground
# truth. Resolution must use fully-qualified refs/remotes/origin/... refs.
work=$(new_fixture shadow_staging)
git -C "$work" branch stale
echo "advance" >>"$work/README.md"
git -C "$work" commit -qam "advance main past stale"
git -C "$work" push -q origin main
wt="$TMPDIR_BASE/shadow_staging/wt1"
git -C "$work" worktree add -b feature/shadow "$wt" stale >/dev/null 2>&1
git -C "$work" tag origin/staging stale
set +e
shadow_staging_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
shadow_staging_status=$?
set -e
assert_status "verify ignores a local tag shadowing origin/staging" 6 "$shadow_staging_status"
assert_contains "staging-shadow rejection names the real base" "$shadow_staging_output" "not a descendant of origin/main"

# Same shadow on the default-branch fallback path (tag named origin/main).
work=$(new_fixture shadow_default)
git -C "$work" branch stale
echo "advance" >>"$work/README.md"
git -C "$work" commit -qam "advance main past stale"
git -C "$work" push -q origin main
wt="$TMPDIR_BASE/shadow_default/wt1"
git -C "$work" worktree add -b feature/shadow2 "$wt" stale >/dev/null 2>&1
git -C "$work" tag origin/main stale
set +e
shadow_default_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
shadow_default_status=$?
set -e
assert_status "verify ignores a local tag shadowing origin/main" 6 "$shadow_default_status"
assert_contains "default-shadow rejection names the real base" "$shadow_default_output" "not a descendant of origin/main"

# Omission is tampering too: deleting a key must not vacuously pass its
# cross-check. Every known key is required once a sidecar exists.
work=$(new_fixture missing_key)
wt="$TMPDIR_BASE/missing_key/wt1"
(cd "$work" && bash "$SCRIPT" cut --branch feature/missing --path "$wt" >/dev/null)
sidecar="$TMPDIR_BASE/missing_key/.worktree-baseline.wt1.state"
grep -v '^RESOLVED_BASE=' "$sidecar" >"$sidecar.tmp" && mv "$sidecar.tmp" "$sidecar"
set +e
missing_key_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
missing_key_status=$?
set -e
assert_status "verify fails on a sidecar missing a required key" 11 "$missing_key_status"
assert_contains "missing-key message names the key" "$missing_key_output" "RESOLVED_BASE"

# STACKED must be exactly true or false — anything else is tampering, not
# an implicit "not stacked" downgrade.
work=$(new_fixture bad_stacked)
wt="$TMPDIR_BASE/bad_stacked/wt1"
(cd "$work" && bash "$SCRIPT" cut --branch feature/badstack --path "$wt" >/dev/null)
sidecar="$TMPDIR_BASE/bad_stacked/.worktree-baseline.wt1.state"
grep -v '^STACKED=' "$sidecar" >"$sidecar.tmp" && mv "$sidecar.tmp" "$sidecar"
echo "STACKED=maybe" >>"$sidecar"
set +e
bad_stacked_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
bad_stacked_status=$?
set -e
assert_status "verify fails on an invalid STACKED value" 11 "$bad_stacked_status"
assert_contains "bad-STACKED message names the field" "$bad_stacked_output" "STACKED"

# A bare known key with no '=' is its own parse-failure branch.
work=$(new_fixture bare_key)
wt="$TMPDIR_BASE/bare_key/wt1"
(cd "$work" && bash "$SCRIPT" cut --branch feature/barekey --path "$wt" >/dev/null)
echo "PARENT_PR" >>"$TMPDIR_BASE/bare_key/.worktree-baseline.wt1.state"
set +e
bare_key_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
bare_key_status=$?
set -e
assert_status "verify fails on a bare known-key line" 11 "$bare_key_status"
assert_contains "bare-key message flags the missing separator" "$bare_key_output" "no '='"

# emit is load_state's second caller: a corrupt sidecar must fail closed
# there too, never emit gate lines.
work=$(new_fixture emit_corrupt)
wt="$TMPDIR_BASE/emit_corrupt/wt1"
(cd "$work" && bash "$SCRIPT" cut --branch feature/emitbad --path "$wt" >/dev/null)
echo "evil-line" >>"$TMPDIR_BASE/emit_corrupt/.worktree-baseline.wt1.state"
set +e
emit_corrupt_output=$(cd "$work" && bash "$SCRIPT" emit --path "$wt" 2>&1)
emit_corrupt_status=$?
set -e
assert_status "emit fails on a corrupt sidecar" 11 "$emit_corrupt_status"
assert_contains "emit corruption message says unrecognized" "$emit_corrupt_output" "unrecognized"

# An explicit --base is the caller naming ground truth: it skips the
# sidecar's RESOLVED_BASE cross-check and the PASS line must say the base
# was caller-supplied so the evidence can't pose as a resolved-base pass.
work=$(new_fixture base_override)
wt="$TMPDIR_BASE/base_override/wt1"
(cd "$work" && bash "$SCRIPT" cut --branch feature/baseok --path "$wt" >/dev/null)
git -C "$work" branch legit-base origin/main
set +e
base_override_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" --base legit-base 2>&1)
base_override_status=$?
set -e
assert_status "verify --base passes on a genuine ancestor" 0 "$base_override_status"
assert_contains "override PASS names the caller-supplied base" "$base_override_output" "caller-supplied base legit-base"

# ...and --base still enforces real ancestry.
work=$(new_fixture base_override_fail)
git -C "$work" branch stale
echo "advance" >>"$work/README.md"
git -C "$work" commit -qam "advance main past stale"
git -C "$work" push -q origin main
wt="$TMPDIR_BASE/base_override_fail/wt1"
git -C "$work" worktree add -b feature/basefail "$wt" stale >/dev/null 2>&1
set +e
base_fail_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" --base origin/main 2>&1)
base_fail_status=$?
set -e
assert_status "verify --base fails on a non-descendant" 6 "$base_fail_status"

# Detached HEAD is its own fault, not sidecar tampering — the message must
# point the operator at the checkout, not the state file.
work=$(new_fixture detached_head)
wt="$TMPDIR_BASE/detached_head/wt1"
(cd "$work" && bash "$SCRIPT" cut --branch feature/detach --path "$wt" >/dev/null)
git -C "$wt" checkout -q --detach HEAD
set +e
detached_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
detached_status=$?
set -e
assert_status "verify fails distinctly on detached HEAD" 12 "$detached_status"
assert_contains "detached message names the condition" "$detached_output" "detached HEAD"

# verify must not brick on network loss: fetch failure falls back to the
# existing remote-tracking refs with a loud staleness warning (cut keeps its
# hard exit 10 — cutting from an unfetchable base is different from
# re-checking ancestry offline).
work=$(new_fixture offline_verify)
wt="$TMPDIR_BASE/offline_verify/wt1"
(cd "$work" && bash "$SCRIPT" cut --branch feature/offline --path "$wt" >/dev/null)
git -C "$work" remote set-url origin /nonexistent/nope.git
set +e
offline_output=$(cd "$work" && bash "$SCRIPT" verify --path "$wt" 2>&1)
offline_status=$?
set -e
assert_status "verify falls back to cached refs when fetch fails" 0 "$offline_status"
assert_contains "offline verify warns about staleness" "$offline_output" "possibly stale"

# The stacked PASS line is gate evidence — pin it verbatim like the other
# gate strings in this suite (reuses the stacked_parent fixture's output).
assert_contains "stacked verify PASS line is verbatim" "$stacked_verify_output" \
    "PASS: $child_wt is clean, descends from origin/main, and descends from parent parent/feature-a"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
