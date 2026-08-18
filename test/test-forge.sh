#!/usr/bin/env bash
set -uo pipefail

# Red-first suite for the origin-detecting forge shim.
# Contract: docs/executions/plans/2026-08-19-workflow-ledger-spec.md
# Mock-mode file contract defined by this suite (implementer must honor):
#   FORGE_MOCK_DIR=<dir> => forge.sh reads the canned normalized answer from
#   "$FORGE_MOCK_DIR/<forge>-<op>-<pr>" (e.g. github-ci-status-42) instead of
#   touching gh or the Forgejo API. Zero network in mock mode — FORGE_URL is
#   pointed at an .invalid host so any real call fails loudly.
# Detect interpretation: origin URLs containing github.com => github; any
# other origin URL => forgejo; no origin remote => none.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORGE="$ROOT/dotfiles/.config/agents/skills/workflow-ledger/scripts/forge.sh"
TMPDIR_BASE=$(mktemp -d)
PASS=0
FAIL=0
OUT=""
STATUS=0

cleanup() {
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

assert_equal() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_exists() {
    local name="$1" path="$2"
    if [ -f "$path" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    MISSING: $path"
        FAIL=$((FAIL + 1))
    fi
}

# Run forge.sh from inside a repo; captures OUT and STATUS. Mock mode is
# always on and FORGE_URL points at an .invalid host so any accidental
# network path fails instead of leaving the sandbox.
run_forge() {
    local dir="$1"
    shift
    OUT="$(cd "$dir" && FORGE_MOCK_DIR="$MOCK_DIR" \
        FORGE_URL="https://forge.invalid" FORGE_TOKEN="dummy-token" \
        bash "$FORGE" "$@" 2>&1)"
    STATUS=$?
}

new_repo() {
    local name="$1" remote="${2:-}"
    local repo="$TMPDIR_BASE/$name"
    mkdir -p "$repo"
    git init -q -b main "$repo"
    git -C "$repo" config user.email "t@example.com"
    git -C "$repo" config user.name "Test"
    echo "seed" >"$repo/README.md"
    git -C "$repo" add README.md
    git -C "$repo" commit -q -m init
    if [ -n "$remote" ]; then
        git -C "$repo" remote add origin "$remote"
    fi
    printf '%s' "$repo"
}

MOCK_DIR="$TMPDIR_BASE/mock"
mkdir -p "$MOCK_DIR"

echo "=== forge.sh tests ==="
echo ""

assert_file_exists "forge.sh exists at spec'd path" "$FORGE"

# --- detect: three remote shapes ---
repo_gh=$(new_repo gh_repo "git@github.com:acme/widgets.git")
repo_fj=$(new_repo fj_repo "https://code.example.org/acme/widgets.git")
repo_none=$(new_repo none_repo)

run_forge "$repo_gh" detect
assert_status "detect exits 0 on github remote" 0 "$STATUS"
assert_equal "detect prints github for github.com ssh remote" "github" "$OUT"

run_forge "$repo_fj" detect
assert_status "detect exits 0 on forgejo remote" 0 "$STATUS"
assert_equal "detect prints forgejo for non-github https remote" "forgejo" "$OUT"

run_forge "$repo_none" detect
assert_status "detect exits 0 with no origin remote" 0 "$STATUS"
assert_equal "detect prints none without origin remote" "none" "$OUT"

# --- github ops via mock mode ---
printf 'green\n' >"$MOCK_DIR/github-ci-status-42"
printf 'open\n' >"$MOCK_DIR/github-pr-state-42"
printf 'yes\n' >"$MOCK_DIR/github-threads-resolved-42"
printf 'pending\n' >"$MOCK_DIR/github-ci-status-43"

run_forge "$repo_gh" ci-status 42
assert_status "github ci-status exits 0" 0 "$STATUS"
assert_equal "github ci-status prints green" "green" "$OUT"

run_forge "$repo_gh" pr-state 42
assert_status "github pr-state exits 0" 0 "$STATUS"
assert_equal "github pr-state prints open" "open" "$OUT"

run_forge "$repo_gh" threads-resolved 42
assert_status "github threads-resolved exits 0" 0 "$STATUS"
assert_equal "github threads-resolved prints yes" "yes" "$OUT"

run_forge "$repo_gh" ci-status 43
assert_equal "github ci-status prints pending" "pending" "$OUT"

# --- forgejo ops via mock mode ---
printf 'red\n' >"$MOCK_DIR/forgejo-ci-status-7"
printf 'merged\n' >"$MOCK_DIR/forgejo-pr-state-7"
printf 'no\n' >"$MOCK_DIR/forgejo-threads-resolved-7"

run_forge "$repo_fj" ci-status 7
assert_status "forgejo ci-status exits 0" 0 "$STATUS"
assert_equal "forgejo ci-status prints red" "red" "$OUT"

run_forge "$repo_fj" pr-state 7
assert_status "forgejo pr-state exits 0" 0 "$STATUS"
assert_equal "forgejo pr-state prints merged" "merged" "$OUT"

run_forge "$repo_fj" threads-resolved 7
assert_status "forgejo threads-resolved exits 0" 0 "$STATUS"
assert_equal "forgejo threads-resolved prints no" "no" "$OUT"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
