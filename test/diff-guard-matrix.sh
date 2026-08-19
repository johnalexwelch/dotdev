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
# an escaped single quote via '\''). Payloads passed through a variable
# (`"$var"`) cannot be recovered textually and are emitted as loud SKIP
# rows rather than tested as literal strings.
#
# SCOPE LIMITATION: a test-derived matrix can only witness regressions on
# shapes the test file already contains — it is NOT evidence of no behavior
# change elsewhere (round-1 tests lane: the `select` fail-open produced no
# DIFF row because no select shape existed in the corpus). Pair --from-tests
# runs with a hand-authored shape corpus when making differential claims.
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
# Resolve hooks to absolute paths NOW: run_one cd's into a temp dir, where a
# relative path would silently resolve to nothing and yield 127 columns that
# read as real verdicts (round-1 style lane footgun).
resolved=()
for h in "${hooks[@]}"; do
    if [ ! -f "$h" ]; then
        echo "hook script not found: $h" >&2
        exit 1
    fi
    resolved+=("$(cd "$(dirname "$h")" && pwd)/$(basename "$h")")
done
hooks=("${resolved[@]}")

# Best-effort extraction of command-argument payloads from run_hook lines
# calling json_bash_jq(...) or json_bash(...) in test-guard-rules.sh.
extract_from_tests() {
    local src="$SCRIPT_DIR/test-guard-rules.sh"
    [ -f "$src" ] || {
        echo "cannot find $src" >&2
        return 1
    }
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
            \$*)
                # Variable-reference payload from --from-tests: untestable
                # textually — emit a loud SKIP row, never a fake verdict.
                local skiprow=""
                for _ in "${hooks[@]}"; do skiprow="${skiprow}SKIP"$'\t'; done
                printf '%sSKIP\t%s\n' "$skiprow" "$line"
                continue
                ;;
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
