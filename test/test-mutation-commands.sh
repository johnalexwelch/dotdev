#!/usr/bin/env bash
# test-mutation-commands.sh — Tests for expanded is_mutation_cmd() detection
# All tests here should FAIL RED initially → proving gaps in current detection.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/dotfiles/.claude/hooks/workflow-guard.sh"
PASS=0
FAIL=0

# Test isolation: ensure no routing evidence exists
ROUTING_MARKER="$ROOT/.pi/routing-confirmed"
ORIG_MARKER_BACKUP=""

cleanup() {
    # Restore original state
    if [[ -n "$ORIG_MARKER_BACKUP" && -f "$ORIG_MARKER_BACKUP" ]]; then
        mv "$ORIG_MARKER_BACKUP" "$ROUTING_MARKER"
    fi
}
trap cleanup EXIT

# Backup existing marker if present, then remove
if [[ -f "$ROUTING_MARKER" ]]; then
    ORIG_MARKER_BACKUP="$(mktemp)"
    mv "$ROUTING_MARKER" "$ORIG_MARKER_BACKUP"
fi

# Helper: run a command through workflow-guard and check if BLOCKED (exit 2)
# No routing evidence → mutation should be blocked
run_mutation_test() {
    local name="$1" cmd="$2"
    local input
    input='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"'"$cmd"'"}}'

    set +e
    output="$(printf '%s' "$input" | ROUTING_ENFORCE=block bash "$SCRIPT" 2>&1)"
    status=$?
    set -e

    # Expected: exit 2 (blocked) because it's a mutation without routing
    if [ "$status" -eq 2 ]; then
        echo "  PASS: $name → blocked as mutation"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name → NOT detected as mutation (exit $status)"
        echo "    cmd: $cmd"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Mutation command detection tests (should fail RED initially) ==="
echo ""
echo "--- Gap #1: gh api with POST method ---"
run_mutation_test "gh api POST to issues" \
    "gh api repos/owner/repo/issues -X POST -f title=test"

run_mutation_test "gh api POST to PRs" \
    "gh api /repos/owner/repo/pulls -X POST --field body=test"

run_mutation_test "gh api PATCH (edit)" \
    "gh api /repos/o/r/issues/1 -X PATCH -f state=closed"

echo ""
echo "--- Gap #2: curl to GitHub API ---"
run_mutation_test "curl POST to github API" \
    "curl -X POST https://api.github.com/repos/o/r/issues -d title=test"

run_mutation_test "curl with -XPOST (no space)" \
    "curl -XPOST https://api.github.com/repos/o/r/pulls"

run_mutation_test "curl --request POST" \
    "curl --request POST https://api.github.com/repos/owner/repo/issues/comments"

echo ""
echo "--- Gap #3: hub CLI ---"
run_mutation_test "hub pull-request" \
    "hub pull-request -m 'Fix bug'"

run_mutation_test "hub create (repo)" \
    "hub create myrepo"

run_mutation_test "hub issue create" \
    "hub issue create -m 'Bug report'"

echo ""
echo "--- Gap #4: glab (GitLab CLI) ---"
run_mutation_test "glab mr create" \
    "glab mr create --fill"

run_mutation_test "glab issue create" \
    "glab issue create --title test"

run_mutation_test "glab mr merge" \
    "glab mr merge 42"

echo ""
echo "--- Gap #5: git with -C flag before action ---"
run_mutation_test "git -C /path commit" \
    "git -C /tmp/repo commit -m 'test'"

run_mutation_test "git -C . push" \
    "git -C /other/path push origin main"

run_mutation_test "git --git-dir=... commit" \
    "git --git-dir=/tmp/.git commit -m 'msg'"

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "RED STATE: $FAIL tests show is_mutation_cmd() gaps."
    echo "These commands bypass routing gate without detection."
    exit 1
fi

exit 0
