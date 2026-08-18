#!/usr/bin/env bash
set -uo pipefail

# Red-first suite for the 4 NEW workflow-guard.sh hook rules.
# Contract: docs/executions/plans/2026-08-19-workflow-ledger-spec.md
# Targets the repo-local canonical hook (dotfiles/.claude/hooks/
# workflow-guard.sh — same path test-workflow-guard.sh uses); the deployed
# ~/.claude/hooks copy is a mirror of it.
# Interpretations the implementer must honor:
#   - The hook resolves ledger.sh via the SKILLS_ROOT env var
#     ($SKILLS_ROOT/workflow-ledger/scripts/ledger.sh); tests always set it
#     to the repo-local skills tree, never real $HOME.
#   - Hook JSON carries "cwd" and the hook process cwd is the repo — either
#     source may be used for repo detection.
#   - The stderr-suppression block message contains the word "stderr".
#   - The entry warn message contains "no active run".
#   - LEDGER_ENTRY_ENFORCE=block escalates the entry warn to exit 2 today
#     (Phase 5 merely flips the default).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/dotfiles/.claude/hooks/workflow-guard.sh"
LEDGER="$ROOT/dotfiles/.config/agents/skills/workflow-ledger/scripts/ledger.sh"
SKILLS_ROOT_REAL="$ROOT/dotfiles/.config/agents/skills"
TMPDIR_BASE=$(mktemp -d)
PASS=0
FAIL=0
ENTRY_ENFORCE=""
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

assert_not_contains() {
    local name="$1" haystack="$2" needle="$3"
    if grep -Fq "$needle" <<<"$haystack"; then
        echo "  FAIL: $name"
        echo "    expected output to NOT contain: $needle"
        echo "    output was:"
        echo "$haystack"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    fi
}

# Run the hook with synthesized JSON on stdin from inside a fixture repo;
# captures combined stdout+stderr (entry warn goes to stderr) and STATUS.
run_hook() {
    local dir="$1" json="$2"
    OUT="$(cd "$dir" && printf '%s' "$json" |
        SKILLS_ROOT="$SKILLS_ROOT_REAL" \
            LEDGER_ENTRY_ENFORCE="$ENTRY_ENFORCE" \
            bash "$GUARD" 2>&1)"
    STATUS=$?
}

json_bash() {
    local cwd="$1" cmd="$2"
    printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' \
        "$cwd" "$cmd"
}

json_file_tool() {
    local tool="$1" cwd="$2" path="$3"
    printf '{"hook_event_name":"PreToolUse","tool_name":"%s","cwd":"%s","tool_input":{"file_path":"%s"}}' \
        "$tool" "$cwd" "$path"
}

new_repo() {
    local name="$1" opted="$2"
    local repo="$TMPDIR_BASE/$name"
    mkdir -p "$repo/src"
    git init -q -b main "$repo"
    git -C "$repo" config user.email "t@example.com"
    git -C "$repo" config user.name "Test"
    echo "print('app')" >"$repo/src/app.py"
    if [ "$opted" = "opted" ]; then
        mkdir -p "$repo/docs/executions"
        echo "opted-in" >"$repo/docs/executions/.gitkeep"
        echo "plan" >"$repo/docs/executions/plan.md"
    fi
    git -C "$repo" add -A
    git -C "$repo" commit -q -m init
    printf '%s' "$repo"
}

# Best-effort ledger setup for fixtures; red today (ledger.sh missing) and
# real once the implementation lands. Never asserted directly here.
ledger_try() {
    local dir="$1"
    shift
    (cd "$dir" && SKILLS_ROOT="$SKILLS_ROOT_REAL" bash "$LEDGER" "$@") >/dev/null 2>&1 || true
}

echo "=== Workflow guard new-rule tests ==="
echo ""

# --- Rule 1: merge gate ---
opted_gate=$(new_repo merge_gate opted)
ledger_try "$opted_gate" init 2026-08-19-gate --workflow workflow-build-one \
    --kind feature --steps "impl,review,finalize"

run_hook "$opted_gate" "$(json_bash "$opted_gate" "gh pr merge 42")"
assert_status "gh pr merge blocked without finalize stamp" 2 "$STATUS"
assert_contains "merge block prints the check output" "$OUT" "MISSING"

run_hook "$opted_gate" "$(json_bash "$opted_gate" "gh pr ready 42")"
assert_status "gh pr ready blocked without finalize stamp" 2 "$STATUS"

run_hook "$opted_gate" "$(json_bash "$opted_gate" "tea pr merge 7")"
assert_status "tea pr merge blocked without finalize stamp" 2 "$STATUS"

run_hook "$opted_gate" "$(json_bash "$opted_gate" "curl -X POST https://forge.invalid/api/v1/repos/a/b/pulls/9/merge")"
assert_status "forgejo curl merge blocked without finalize stamp" 2 "$STATUS"

run_hook "$opted_gate" "$(json_bash "$opted_gate" "gh pr view 42")"
assert_status "non-merge pr command not gated" 0 "$STATUS"

plain_gate=$(new_repo merge_gate_plain plain)
run_hook "$plain_gate" "$(json_bash "$plain_gate" "gh pr merge 42")"
assert_status "merge allowed in non-opted-in repo" 0 "$STATUS"

opted_ovr=$(new_repo merge_gate_override opted)
ledger_try "$opted_ovr" init 2026-08-19-ovr --workflow workflow-build-one \
    --kind feature --steps "impl,finalize"
ledger_try "$opted_ovr" stamp finalize --override --reason "guard bypass test" \
    --attest post_mortem=docs/pm.md --attest describe_pr=done

run_hook "$opted_ovr" "$(json_bash "$opted_ovr" "gh pr merge 42")"
assert_status "merge passes when check finalize succeeds via override" 0 "$STATUS"
assert_contains "override pass-through echoes OVERRIDDEN" "$OUT" "OVERRIDDEN"

# An expired override must block the merge gate loudly, naming the bypass
# that lapsed — not read as standing authorization or as a never-passed gate.
echo "drift" >"$opted_ovr/src/drift.py"
git -C "$opted_ovr" add -A
git -C "$opted_ovr" commit -q -m "feat: work after the override"

run_hook "$opted_ovr" "$(json_bash "$opted_ovr" "gh pr merge 42")"
assert_status "merge blocked once the override is stale" 2 "$STATUS"
assert_contains "stale-override block prints OVERRIDE_STALE" "$OUT" "OVERRIDE_STALE"
assert_contains "stale-override block carries the recorded reason" "$OUT" "guard bypass test"

# --- Rule 2: state.yaml write block ---
opted_state=$(new_repo state_block opted)

run_hook "$opted_state" "$(json_file_tool Edit "$opted_state" "$opted_state/docs/executions/state.yaml")"
assert_status "Edit of committed snapshot blocked" 2 "$STATUS"
assert_contains "snapshot block says script-owned" "$OUT" "script-owned"

run_hook "$opted_state" "$(json_file_tool Write "$opted_state" "$opted_state/docs/executions/state.yaml")"
assert_status "Write of committed snapshot blocked" 2 "$STATUS"

run_hook "$opted_state" "$(json_file_tool Write "$opted_state" "$opted_state/.git/ledger/state.yaml")"
assert_status "Write of live git-dir state blocked" 2 "$STATUS"

run_hook "$opted_state" "$(json_file_tool Edit "$opted_state" "$opted_state/.git/worktrees/wt1/ledger/state.yaml")"
assert_status "Edit of worktree git-dir live state blocked" 2 "$STATUS"

run_hook "$opted_state" "$(json_file_tool Edit "$opted_state" "$opted_state/config/state.yaml")"
assert_status "unrelated state.yaml not blocked" 0 "$STATUS"
assert_not_contains "unrelated state.yaml carries no block message" "$OUT" "script-owned"

# --- Rule 3: stderr suppression on mutating forge/git commands ---
plain_sup=$(new_repo suppression plain)

run_hook "$plain_sup" "$(json_bash "$plain_sup" "git push origin main 2>/dev/null")"
assert_status "git push with 2>/dev/null blocked" 2 "$STATUS"
assert_contains "suppression block names stderr" "$OUT" "stderr"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "gh pr create --fill &>/dev/null")"
assert_status "gh pr create with &>/dev/null blocked" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "git commit -m wip 2>/dev/null")"
assert_status "git commit with 2>/dev/null blocked" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "gh api -X POST repos/a/b/issues 2>/dev/null")"
assert_status "gh api POST with 2>/dev/null blocked" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "tea pr merge 7 2>/dev/null")"
assert_status "tea merge with 2>/dev/null blocked" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "git status 2>/dev/null")"
assert_status "non-mutating git with 2>/dev/null allowed" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "git push origin main")"
assert_status "mutating command without suppression allowed" 0 "$STATUS"

# --- Rule 4: entry enforcement (warn-only in Phase 0) ---
opted_entry=$(new_repo entry_warn opted)

run_hook "$opted_entry" "$(json_file_tool Edit "$opted_entry" "$opted_entry/src/app.py")"
assert_status "tracked edit without active run stays exit 0" 0 "$STATUS"
assert_contains "tracked edit without active run warns" "$OUT" "no active run"

echo "scratch" >"$opted_entry/untracked.py"
run_hook "$opted_entry" "$(json_file_tool Edit "$opted_entry" "$opted_entry/untracked.py")"
assert_status "untracked edit stays exit 0" 0 "$STATUS"
assert_not_contains "untracked edit does not warn" "$OUT" "no active run"

run_hook "$opted_entry" "$(json_file_tool Edit "$opted_entry" "$opted_entry/docs/executions/plan.md")"
assert_status "docs/executions edit stays exit 0" 0 "$STATUS"
assert_not_contains "docs/executions edit does not warn" "$OUT" "no active run"

plain_entry=$(new_repo entry_plain plain)
run_hook "$plain_entry" "$(json_file_tool Edit "$plain_entry" "$plain_entry/src/app.py")"
assert_status "non-opted-in repo edit stays exit 0" 0 "$STATUS"
assert_not_contains "non-opted-in repo edit does not warn" "$OUT" "no active run"

opted_active=$(new_repo entry_active opted)
ledger_try "$opted_active" init 2026-08-19-active --workflow workflow-build-one \
    --kind feature --steps "impl"
run_hook "$opted_active" "$(json_file_tool Edit "$opted_active" "$opted_active/src/app.py")"
assert_status "edit with active run stays exit 0" 0 "$STATUS"
assert_not_contains "edit with active run does not warn" "$OUT" "no active run"

ENTRY_ENFORCE="block"
run_hook "$opted_entry" "$(json_file_tool Edit "$opted_entry" "$opted_entry/src/app.py")"
assert_status "LEDGER_ENTRY_ENFORCE=block escalates warn to exit 2" 2 "$STATUS"
assert_contains "escalated entry block keeps the message" "$OUT" "no active run"
ENTRY_ENFORCE=""

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
