#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/dotfiles/.claude/hooks/workflow-guard.sh"
TMPDIR_BASE="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() {
    rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

run_case() {
    local name="$1" expected="$2" input="$3" expected_text="${4:-}"

    set +e
    output="$(printf '%s' "$input" | bash "$SCRIPT" 2>&1)"
    status=$?
    set -e

    if [ "$status" -eq "$expected" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    expected status $expected, got $status"
        echo "    output: $output"
        FAIL=$((FAIL + 1))
        return
    fi

    if [ -n "$expected_text" ] && ! grep -Fq "$expected_text" <<<"$output"; then
        echo "  FAIL: $name"
        echo "    expected output to contain: $expected_text"
        echo "    output: $output"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Workflow guard tests ==="
echo ""

run_case "blocks PRD parent ready-for-agent label" 2 \
    '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"gh issue create --title \"PRD: Roadmap\" --label ready-for-agent --body \"## Problem Statement\""}}' \
    "Blocked: PRD/spec parent issues must not be labeled ready-for-agent."

run_case "allows child ready-for-agent issue" 0 \
    '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"gh issue create --title \"Implement login slice\" --label ready-for-agent --body \"## Acceptance criteria\""}}'

run_case "allows domain use of parent" 0 \
    '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"gh issue create --title \"Parent engagement daily slice\" --label ready-for-agent --body \"## Acceptance criteria\""}}'

run_case "allows ready-for-agent removal from PRD" 0 \
    '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"gh issue edit 123 --remove-label ready-for-agent --body \"PRD: Roadmap\""}}'

mock_bin="$TMPDIR_BASE/bin"
mkdir -p "$mock_bin"
cat >"$mock_bin/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "issue" ] && [ "$2" = "view" ] && [ "$3" = "123" ]; then
    printf 'PRD: Existing roadmap\n## Problem Statement\n'
    exit 0
fi
exit 1
EOF
chmod +x "$mock_bin/gh"

PATH="$mock_bin:$PATH" run_case "blocks existing PRD issue label add" 2 \
    '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"gh issue edit 123 --add-label ready-for-agent"}}' \
    "Blocked: PRD/spec parent issues must not be labeled ready-for-agent."

run_case "post PR action reminder is non-blocking" 0 \
    '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"gh pr create --draft --fill"}}' \
    "[WORKFLOW GUARD] PR action detected."

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
