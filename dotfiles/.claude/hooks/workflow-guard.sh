#!/usr/bin/env bash
# workflow-guard.sh — PreToolUse/PostToolUse guard rails for delivery workflows.
# D-006 additions: merge gate (ledger check finalize), state.yaml write block,
# stderr-suppression block on mutating forge/git commands, and entry
# enforcement (warn-only in Phase 0; LEDGER_ENTRY_ENFORCE=block escalates).
set -euo pipefail

input="$(cat)"
event="$(jq -r '.hook_event_name // ""' <<<"$input" 2>/dev/null || true)"
tool="$(jq -r '.tool_name // ""' <<<"$input" 2>/dev/null || true)"
cmd="$(jq -r '.tool_input.command // ""' <<<"$input" 2>/dev/null || true)"
file_path="$(jq -r '.tool_input.file_path // ""' <<<"$input" 2>/dev/null || true)"
cwd="$(jq -r '.cwd // ""' <<<"$input" 2>/dev/null || true)"
[ -n "$cwd" ] || cwd="$PWD"

SKILLS_ROOT="${SKILLS_ROOT:-$HOME/.config/agents/skills}"
LEDGER_SH="$SKILLS_ROOT/workflow-ledger/scripts/ledger.sh"

has() {
    grep -Eiq "$1" <<<"$cmd"
}

adds_ready_for_agent() {
    has '(^|[[:space:]])--(add-)?label([=[:space:]][^;&|]*)?ready-for-agent' ||
        has '(^|[[:space:]])-l([=[:space:]][^;&|]*)?ready-for-agent'
}

prd_like_text() {
    grep -Eiq '(^|[^[:alnum:]_-])(PRD|spec|specification|parent[[:space:]]+(PRD|spec|issue)|Problem Statement|User Stories|AFK Readiness)([^[:alnum:]_-]|$)' <<<"$1"
}

existing_issue_text() {
    local issue
    issue="$(grep -Eo '\bgh[[:space:]]+issue[[:space:]]+edit[[:space:]]+[0-9]+' <<<"$cmd" | awk '{print $4}' | head -1)"
    [ -n "$issue" ] || return 1
    gh issue view "$issue" --json title,body --jq '.title + "\n" + (.body // "")' 2>/dev/null || true
}

is_merge_shape() {
    has '\bgh[[:space:]]+pr[[:space:]]+(merge|ready)\b' ||
        has '\btea[[:space:]]+pr[[:space:]]+merge\b' ||
        has '\bgit-forge\b[^|;&]*\bmerge\b' ||
        has '\bcurl\b[^|;&]*/pulls/[^[:space:]]*/merge'
}

is_mutating_forge_cmd() {
    has '\bgit[[:space:]]+(push|commit|merge|rebase)\b' ||
        has '\bgh[[:space:]]+pr[[:space:]]+(create|edit|close|merge|ready)\b' ||
        has '\bgh[[:space:]]+issue[[:space:]]+edit\b' ||
        has '\bgh[[:space:]]+api\b[^|;&]*-X[[:space:]]+(POST|PATCH|DELETE)\b' ||
        has '\btea[[:space:]]+pr[[:space:]]+(create|edit|close|merge)\b' ||
        has '\bgit-forge\b[^|;&]*\b(merge|create|edit|close)\b'
}

# ---- Edit/Write rules (D-006 rules 2 and 4) ---------------------------------

if [ "$event" = "PreToolUse" ] && { [ "$tool" = "Edit" ] || [ "$tool" = "Write" ]; } && [ -n "$file_path" ]; then
    # Rule 2: ledger state files are script-owned; direct edits are blocked.
    # Case-insensitive: APFS is case-insensitive, so a case-variant spelling
    # writes the real file.
    if grep -Eiq '(^|/)docs/executions/state\.yaml$|(^|/)\.git(/.*)?/ledger/state\.yaml$' <<<"$file_path"; then
        printf 'Blocked: %s is script-owned; use ledger.sh (init/set/stamp/close) instead of editing it directly.\n' "$file_path" >&2
        exit 2
    fi

    # Rule 2b: worktree-baseline sidecars are script-owned as well — written
    # by `worktree-baseline.sh cut`, cross-checked by `verify`. They live
    # outside any repo (sibling of the worktree path), so match the filename
    # pattern anywhere (D-006 hardening; PR #166 forged-baseline pattern).
    if grep -Eiq '(^|/)\.worktree-baseline\.[^/]+\.state$' <<<"$file_path"; then
        printf 'Blocked: %s is script-owned; it is written by worktree-baseline.sh cut and cross-checked by verify — never write it by hand.\n' "$file_path" >&2
        exit 2
    fi

    # Rule 4: entry enforcement — tracked-code edit in an opted-in repo with no
    # active ledger run. Warn-only in Phase 0; LEDGER_ENTRY_ENFORCE=block
    # escalates to a hard block (the Phase 5 default flip).
    if ! grep -Eq '(^|/)docs/executions/' <<<"$file_path"; then
        repo_top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
        if [ -n "$repo_top" ] && [ -d "$repo_top/docs/executions" ] &&
            git -C "$cwd" ls-files --error-unmatch -- "$file_path" >/dev/null 2>&1; then
            git_dir="$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null || true)"
            live_state="$git_dir/ledger/state.yaml"
            if [ ! -f "$live_state" ] || ! grep -q '^status: active' "$live_state" 2>/dev/null; then
                printf '[WORKFLOW GUARD] no active run — route via workflow-router or ledger.sh init before editing tracked code.\n' >&2
                if [ "${LEDGER_ENTRY_ENFORCE:-}" = "block" ]; then
                    exit 2
                fi
            fi
        fi
    fi
    exit 0
fi

[ "$tool" = "Bash" ] || exit 0
[ -n "$cmd" ] || exit 0

if [ "$event" = "PreToolUse" ]; then
    if has '\bgh[[:space:]]+issue[[:space:]]+(create|edit)\b' &&
        adds_ready_for_agent &&
        { prd_like_text "$cmd" || prd_like_text "$(existing_issue_text)"; }; then
        printf 'Blocked: PRD/spec parent issues must not be labeled ready-for-agent. Use child implementation issues from to-issues.\n' >&2
        exit 2
    fi

    # Rule 3: stderr suppression on mutating git/gh/tea/git-forge commands
    # hides failures the workflow depends on seeing (D-006, closes C36).
    if has '2>/dev/null|&>/dev/null' && is_mutating_forge_cmd; then
        printf 'Blocked: stderr suppression on a mutating git/gh/tea/git-forge command hides failures. Re-run it without 2>/dev/null (or &>/dev/null).\n' >&2
        exit 2
    fi

    # Rule 1: merge gate — in opted-in repos (docs/executions/ present) a merge
    # needs a fresh finalize stamp. Short-circuits cheaply when the repo is not
    # opted in or the ledger kernel is absent.
    if is_merge_shape; then
        repo_top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
        if [ -n "$repo_top" ] && [ -d "$repo_top/docs/executions" ] && [ -f "$LEDGER_SH" ]; then
            set +e
            check_out="$( (cd "$cwd" && bash "$LEDGER_SH" check finalize) 2>&1)"
            check_status=$?
            set -e
            if [ "$check_status" -ne 0 ]; then
                # Block only on a working kernel's verdict (1 = gate unmet,
                # 2 = checked fields failed). Kernel/env breakage (corrupt
                # state 6, missing manifest 9, python/env errors) warns and
                # permits — a broken kernel must never brick delivery, since
                # the --override recovery path runs through the same kernel
                # (D-006 #5; review R1 should-fix).
                case "$check_status" in
                    1 | 2)
                        printf 'Blocked: merge gate — ledger check finalize failed:\n%s\n' "$check_out" >&2
                        exit 2
                        ;;
                    *)
                        printf '[WORKFLOW GUARD] merge gate ERRORED (exit %s) — permitting merge, but the ledger kernel needs repair:\n%s\n' "$check_status" "$check_out" >&2
                        ;;
                esac
            fi
            # Override stamps pass, but the bypass stays loud.
            case "$check_out" in
                *OVERRIDDEN*) printf '%s\n' "$check_out" ;;
            esac
        fi
    fi
    exit 0
fi

[ "$event" = "PostToolUse" ] || exit 0

if has '\bgh[[:space:]]+issue[[:space:]]+(create|edit)\b' && adds_ready_for_agent; then
    printf '\n[WORKFLOW GUARD] ready-for-agent issue changed. Verify triage fields: acceptance criteria, dependencies, verification, rollback, AFK/HITL, outage risk, worktree/review/finalize gates, and human-review semantics.\n'
fi

if has '\bgh[[:space:]]+pr[[:space:]]+(create|ready)\b'; then
    printf '\n[WORKFLOW GUARD] PR action detected. Do not claim CI/deploy success from command exit alone. If checks are absent or disabled, record local validation evidence and keep the PR draft/pending as policy requires.\n'
    printf '[WORKFLOW GUARD] Also verify WORKFLOW_REVIEW_GATE and WORKFLOW_FINALIZE_GATE before completion.\n'
fi

if has '\bgh[[:space:]]+pr[[:space:]]+(merge|close)\b'; then
    printf '\n[WORKFLOW GUARD] PR merge/close detected. Inventory cleanup before deleting anything:\n'
    git status --short 2>/dev/null || true
    git worktree list --porcelain 2>/dev/null | sed -n '1,40p' || true
    printf '[WORKFLOW GUARD] Load and run cleanup-delivery/SKILL.md for cleanup decisions.\n'
fi
