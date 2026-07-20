#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/dotfiles/.config/agents/skills/lint-skill-suite.sh"
TMPDIR_BASE=$(mktemp -d)
PASS=0
FAIL=0

cleanup() {
    rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

make_skill() {
    local root="$1"
    local name="$2"

    mkdir -p "$root/$name"
    cat >"$root/$name/SKILL.md" <<EOF
---
name: $name
description: test skill
---

# $name

## Contract

Consumes: test input
Produces: test output
Requires: none
Side effects: none
Human gates: none
EOF
}

assert_contains() {
    local name="$1"
    local haystack="$2"
    local needle="$3"

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

assert_not_contains() {
    local name="$1"
    local haystack="$2"
    local needle="$3"

    if grep -Fq "$needle" <<<"$haystack"; then
        echo "  FAIL: $name"
        echo "    expected output not to contain: $needle"
        echo "    output was:"
        echo "$haystack"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    fi
}

echo "=== Skill suite lint tests ==="
echo ""

source="$TMPDIR_BASE/source"
runtime="$TMPDIR_BASE/runtime"
allowlist="$TMPDIR_BASE/codex-runtime-allowlist.txt"
mkdir -p "$source" "$runtime"
make_skill "$source" active
make_skill "$runtime" active
make_skill "$runtime" allowed-runtime-only
make_skill "$runtime" stale-runtime-only
printf 'allowed-runtime-only\n' >"$allowlist"

set +e
output=$(CHECK_CODEX_RUNTIME=1 CODEX_SKILLS_DIR="$runtime" CODEX_RUNTIME_ALLOWLIST="$allowlist" "$SCRIPT" "$source" 2>&1)
status=$?
set -e

if [ "$status" -ne 0 ]; then
    echo "  PASS: lint fails for unlisted runtime-only skill"
    PASS=$((PASS + 1))
else
    echo "  FAIL: lint fails for unlisted runtime-only skill"
    echo "    expected non-zero exit"
    echo "    output was:"
    echo "$output"
    FAIL=$((FAIL + 1))
fi
assert_contains "lint warns for allowlisted runtime-only skill" "$output" \
    "WARN: Codex runtime has allowlisted runtime-only skill: allowed-runtime-only"
assert_contains "lint reports unlisted runtime-only skill" "$output" \
    "FAIL: Codex runtime has skill not present in active source: stale-runtime-only"
assert_not_contains "lint does not fail allowlisted runtime-only skill" "$output" \
    "FAIL: Codex runtime has skill not present in active source: allowed-runtime-only"

rm -rf "$runtime/stale-runtime-only"
output=$(CHECK_CODEX_RUNTIME=1 CODEX_SKILLS_DIR="$runtime" CODEX_RUNTIME_ALLOWLIST="$allowlist" "$SCRIPT" "$source" 2>&1)
assert_contains "lint succeeds with only allowlisted runtime-only skill" "$output" \
    "skill-suite lint: failures=0 warnings=1"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
