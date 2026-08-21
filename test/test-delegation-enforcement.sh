#!/usr/bin/env bash
# test-delegation-enforcement.sh
# RED state: Tests for delegation enforcement when team budget is selected
# These tests should FAIL until the prohibition text is added to the relevant files

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

test_file_contains() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    if [[ ! -f "$file" ]]; then
        echo "FAIL: $description"
        echo "      File not found: $file"
        ((FAIL++))
        return 1
    fi

    if grep -qi "$pattern" "$file" 2>/dev/null; then
        echo "PASS: $description"
        ((PASS++))
        return 0
    else
        echo "FAIL: $description"
        echo "      Pattern not found: $pattern"
        ((FAIL++))
        return 1
    fi
}

echo "=== Delegation Enforcement Tests ==="
echo ""

# Test 1: habits.md contains explicit prohibition against direct implementation with team budget
test_file_contains \
    "$PROJECT_ROOT/docs/agents/habits.md" \
    "team.*budget.*must.*delegate\|team.*budget.*prohibit.*direct\|team-budget.*requires.*delegation" \
    "habits.md contains team budget delegation requirement"

# Test 2: workflow-router SKILL.md documents team budget requires delegation
# Use repo path (works in CI), fall back to deployed path
SKILL_PATH="$PROJECT_ROOT/dotfiles/.config/agents/skills/workflow-router/SKILL.md"
if [[ ! -f "$SKILL_PATH" ]]; then
    SKILL_PATH="$HOME/.claude/skills/workflow-router/SKILL.md"
fi
test_file_contains \
    "$SKILL_PATH" \
    "team.*budget.*delegate\|team-budget.*multi-agent\|team.*budget.*spawn.*subagent" \
    "workflow-router SKILL.md documents team budget delegation"

# Test 3: golden-routes.yaml has cases where team-budget prompts route to multi-agent flows
test_file_contains \
    "$PROJECT_ROOT/test/golden-routes.yaml" \
    "team-budget.*taskflow\|team-budget.*subagent\|budget:.*team.*flow:" \
    "golden-routes.yaml has team-budget multi-agent cases"

# Test 4: AGENTS.md mentions delegation requirement for team budget
test_file_contains \
    "$PROJECT_ROOT/AGENTS.md" \
    "team.*budget.*delegate\|team-budget.*spawn\|team.*budget.*must.*not.*implement.*directly" \
    "AGENTS.md mentions team budget delegation requirement"

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "Tests failed (expected in RED state)"
    exit 1
else
    echo "All tests passed"
    exit 0
fi
