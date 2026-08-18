#!/usr/bin/env bash
set -uo pipefail

# Suite for the Skill-invocation PreToolUse logging hook defined inline in
# dotfiles/.claude/settings.json (matcher "Skill"). Regression coverage for
# the 2026-08-18 corpus-optimization audit's blank-log-line finding: 14% of
# skill-invocations.log entries carried a timestamp and no skill name.
#
# Root cause: `.tool_input.skill // "unknown"` never reaches the `//`
# fallback when `.tool_input` is a non-object (string/array) or stdin is not
# valid JSON — jq raises an error (exit 5, empty stdout) and the command
# substitution logs an empty name. Contract under test: every logged line
# carries a non-empty name; unparseable shapes log `unknown:<raw>`.
#
# The command is extracted from settings.json itself (not duplicated here),
# so the test always exercises the deployed hook text.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$ROOT/dotfiles/.claude/settings.json"
PASS=0
FAIL=0

TMP_HOME=$(mktemp -d)
cleanup() {
    rm -rf "$TMP_HOME"
}
trap cleanup EXIT

LOG="$TMP_HOME/.claude/logs/skill-invocations.log"

HOOK_CMD=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Skill") | .hooks[0].command' "$SETTINGS")
if [ -z "$HOOK_CMD" ] || [ "$HOOK_CMD" = "null" ]; then
    echo "FAIL: could not extract Skill PreToolUse hook command from $SETTINGS" >&2
    exit 1
fi

run_hook() {
    # Runs the extracted hook command exactly as the harness would: JSON on
    # stdin, sh -c, with HOME sandboxed so the real log is never touched.
    printf '%s' "$1" | HOME="$TMP_HOME" sh -c "$HOOK_CMD"
}

last_logged_name() {
    tail -n 1 "$LOG" | cut -f2-
}

check() {
    local name="$1" input="$2" want="$3" got=""
    run_hook "$input"
    got="$(last_logged_name)"
    if [ "$got" = "$want" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (want '$want', got '$got')"
        FAIL=$((FAIL + 1))
    fi
}

check_prefix() {
    local name="$1" input="$2" want_prefix="$3" got=""
    run_hook "$input"
    got="$(last_logged_name)"
    case "$got" in
        "$want_prefix"*)
            echo "  PASS: $name"
            PASS=$((PASS + 1))
            ;;
        *)
            echo "  FAIL: $name (want prefix '$want_prefix', got '$got')"
            FAIL=$((FAIL + 1))
            ;;
    esac
}

echo "test-skill-log-hook.sh"

check "normal shape logs the skill name" \
    '{"tool_input":{"skill":"clarity-review"}}' \
    "clarity-review"

check "skill key absent logs unknown:<raw tool_input>" \
    '{"tool_input":{"args":"x"}}' \
    'unknown:{"args":"x"}'

check "string tool_input logs unknown:<raw> (was blank)" \
    '{"tool_input":"graphify"}' \
    'unknown:"graphify"'

check "array tool_input logs unknown:<raw> (was blank)" \
    '{"tool_input":["graphify"]}' \
    'unknown:["graphify"]'

check_prefix "invalid JSON logs unknown:<raw> (was blank)" \
    'not json at all' \
    "unknown:"

check "empty-string skill logs unknown:<raw> (was blank)" \
    '{"tool_input":{"skill":""}}' \
    'unknown:{"skill":""}'

check "non-string skill value logs unknown:<raw>" \
    '{"tool_input":{"skill":{"nested":true}}}' \
    'unknown:{"skill":{"nested":true}}'

check "embedded newline in skill name stays a single log line (M1)" \
    '{"tool_input":{"skill":"bad\nname"}}' \
    "bad name"

# Cross-cutting invariant: no line in the log may have an empty name field.
blank_lines=$(awk -F'\t' '$2 == "" || NF < 2' "$LOG" | wc -l | tr -d ' ')
if [ "$blank_lines" -eq 0 ]; then
    echo "  PASS: no blank name fields across all logged shapes"
    PASS=$((PASS + 1))
else
    echo "  FAIL: $blank_lines blank name field(s) in the log"
    FAIL=$((FAIL + 1))
fi

echo "test-skill-log-hook.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
