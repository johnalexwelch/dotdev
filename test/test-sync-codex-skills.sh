#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/dotfiles/.claude/skills/sync-codex-skills.sh"
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
    local compatible="${3:-true}"

    mkdir -p "$root/$name"
    cat >"$root/$name/SKILL.md" <<EOF
---
name: $name
description: test skill
codex-compatible: $compatible
---

# $name
EOF
}

new_fixture() {
    local name="$1"
    local source="$TMPDIR_BASE/$name/source"
    local runtime="$TMPDIR_BASE/$name/runtime"

    mkdir -p "$source" "$runtime"
    make_skill "$source" active true
    make_skill "$source" incompatible false
    make_skill "$runtime" active true
    make_skill "$runtime" incompatible true
    make_skill "$runtime" runtime-only true
    printf '%s\t%s\n' "$source" "$runtime"
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

assert_path_exists() {
    local name="$1"
    local path="$2"

    if [ -e "$path" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    expected path to exist: $path"
        FAIL=$((FAIL + 1))
    fi
}

assert_path_missing() {
    local name="$1"
    local path="$2"

    if [ ! -e "$path" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    expected path to be absent: $path"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Codex skill sync tests ==="
echo ""

IFS=$'\t' read -r source runtime < <(new_fixture dry_full_prune)
output=$(SOURCE_SKILLS_DIR="$source" CODEX_SKILLS_DIR="$runtime" "$SCRIPT" --prune)
assert_contains "full prune previews incompatible runtime skill" "$output" \
    "would prune runtime-only/incompatible: incompatible"
assert_contains "full prune previews runtime-only skill" "$output" \
    "would prune runtime-only/incompatible: runtime-only"

IFS=$'\t' read -r source runtime < <(new_fixture dry_incompatible_only)
output=$(SOURCE_SKILLS_DIR="$source" CODEX_SKILLS_DIR="$runtime" "$SCRIPT" --prune-incompatible-only)
assert_contains "incompatible-only mode previews incompatible skill" "$output" \
    "would prune incompatible: incompatible"
assert_not_contains "incompatible-only mode preserves runtime-only skill in preview" "$output" \
    "runtime-only"

IFS=$'\t' read -r source runtime < <(new_fixture dry_keep_runtime_only)
output=$(SOURCE_SKILLS_DIR="$source" CODEX_SKILLS_DIR="$runtime" "$SCRIPT" --prune --keep-runtime-only)
assert_contains "keep-runtime-only mode previews incompatible skill" "$output" \
    "would prune incompatible: incompatible"
assert_not_contains "keep-runtime-only mode preserves runtime-only skill in preview" "$output" \
    "runtime-only"

IFS=$'\t' read -r source runtime < <(new_fixture apply_incompatible_only)
SOURCE_SKILLS_DIR="$source" CODEX_SKILLS_DIR="$runtime" "$SCRIPT" --apply --prune-incompatible-only >/dev/null
assert_path_missing "apply incompatible-only removes incompatible runtime skill" "$runtime/incompatible"
assert_path_exists "apply incompatible-only keeps runtime-only skill" "$runtime/runtime-only/SKILL.md"
assert_path_exists "apply incompatible-only syncs active source skill" "$runtime/active/SKILL.md"

IFS=$'\t' read -r source runtime < <(new_fixture dry_allowlisted_runtime_only)
make_skill "$runtime" stale-runtime-only true
allowlist="$TMPDIR_BASE/dry_allowlisted_runtime_only.allowlist"
printf 'runtime-only\n' >"$allowlist"
output=$(SOURCE_SKILLS_DIR="$source" CODEX_SKILLS_DIR="$runtime" CODEX_RUNTIME_ALLOWLIST="$allowlist" "$SCRIPT" --prune)
assert_contains "full prune reports allowed runtime-only skill" "$output" \
    "keep allowlisted runtime-only: runtime-only"
assert_not_contains "full prune does not preview allowed runtime-only skill" "$output" \
    "would prune runtime-only/incompatible: runtime-only"
assert_contains "full prune still previews unlisted runtime-only skill" "$output" \
    "would prune runtime-only/incompatible: stale-runtime-only"

IFS=$'\t' read -r source runtime < <(new_fixture apply_allowlisted_runtime_only)
make_skill "$runtime" stale-runtime-only true
allowlist="$TMPDIR_BASE/apply_allowlisted_runtime_only.allowlist"
printf 'runtime-only\n' >"$allowlist"
SOURCE_SKILLS_DIR="$source" CODEX_SKILLS_DIR="$runtime" CODEX_RUNTIME_ALLOWLIST="$allowlist" "$SCRIPT" --apply --prune >/dev/null
assert_path_exists "apply full prune keeps allowlisted runtime-only skill" "$runtime/runtime-only/SKILL.md"
assert_path_missing "apply full prune removes unlisted runtime-only skill" "$runtime/stale-runtime-only"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
