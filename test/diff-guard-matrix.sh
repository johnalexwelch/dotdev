#!/usr/bin/env bash
# Differential runner for workflow-guard.sh candidates.
#
# Usage:
#   bash test/diff-guard-matrix.sh HOOK_A [HOOK_B ...] < shapes.txt
#   bash test/diff-guard-matrix.sh --from-tests HOOK_A [HOOK_B ...]
#
# Reads one bash command per line on stdin (blank lines and lines starting
# with `#` are skipped), feeds each line to every named hook script as a
# PreToolUse Bash tool_input JSON payload, and prints a TSV:
#   exit_A<TAB>exit_B<TAB>...<TAB>DIFF?<TAB>command
# The DIFF column reads "DIFF" when the hooks' exit codes disagree, else "".
#
# --from-tests extracts candidate shapes from test/test-guard-rules.sh
# instead of stdin: it greps for `run_hook ... json_bash_jq(...)`/
# `json_bash(...)` call lines and best-effort pulls the trailing quoted
# command argument out of each. This is a sed/grep scrape, not a shell
# parser — it assumes the command argument is the LAST quoted argument on
# the line and does not handle a payload containing its own quote-type
# escaped the same as the wrapper (e.g. a single-quoted payload containing
# an escaped single quote via '\''). Lines it cannot confidently parse are
# silently skipped, so --from-tests is a coverage aid, not a source of
# truth — cross-check against test-guard-rules.sh itself for anything that
# looks missing.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_ROOT="$ROOT/dotfiles/.config/agents/skills"

from_tests=0
hooks=()
for arg in "$@"; do
    if [ "$arg" = "--from-tests" ]; then
        from_tests=1
    else
        hooks+=("$arg")
    fi
done

if [ "${#hooks[@]}" -eq 0 ]; then
    echo "usage: $0 [--from-tests] HOOK_A [HOOK_B ...] [< shapes.txt]" >&2
    exit 1
fi
for h in "${hooks[@]}"; do
    if [ ! -f "$h" ]; then
        echo "hook script not found: $h" >&2
        exit 1
    fi
done

# Best-effort extraction of command-argument payloads from run_hook lines
# calling json_bash_jq(...) or json_bash(...) in test-guard-rules.sh.
extract_from_tests() {
    local src="$SCRIPT_DIR/test-guard-rules.sh"
    [ -f "$src" ] || { echo "cannot find $src" >&2; return 1; }
    grep -E 'run_hook .*json_bash(_jq)? ' "$src" |
        sed -E 's/^.*json_bash(_jq)? "\$[A-Za-z_]+" //' |
        sed -E 's/\)"[[:space:]]*$//' |
        sed -E "s/^'(.*)'\$/\\1/" |
        sed -E 's/^"(.*)"$/\1/'
}

run_one() {
    local hook="$1" cmd="$2" cwd="$3" json
    json=$(jq -Rn --arg cwd "$cwd" --arg c "$cmd" \
        '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:$cwd,tool_input:{command:$c}}')
    (cd "$cwd" && printf '%s' "$json" | SKILLS_ROOT="$SKILLS_ROOT" bash "$hook" >/dev/null 2>&1)
    echo "$?"
}

cwd=""
cleanup() { [ -z "$cwd" ] || rm -rf "$cwd"; }
trap cleanup EXIT

main() {
    cwd="$(mktemp -d)"

    local read_shapes
    if [ "$from_tests" -eq 1 ]; then
        read_shapes="$(extract_from_tests)"
    else
        read_shapes="$(cat)"
    fi

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        case "$line" in
            \#*) continue ;;
        esac
        local codes=() first="" diff="" code
        for h in "${hooks[@]}"; do
            code="$(run_one "$h" "$line" "$cwd")"
            codes+=("$code")
            if [ -z "$first" ]; then
                first="$code"
            elif [ "$code" != "$first" ]; then
                diff="DIFF"
            fi
        done
        local row=""
        for code in "${codes[@]}"; do
            row="${row}${code}"$'\t'
        done
        printf '%s%s\t%s\n' "$row" "$diff" "$line"
    done <<<"$read_shapes"
}

main
