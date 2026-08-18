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

# `merge` must be the whole token: `-` is a word boundary, so `merge\b`
# alone false-positives on non-mutating `gh pr merge-queue status`.
is_merge_shape() {
    has '\bgh[[:space:]]+pr[[:space:]]+(merge|ready)($|[^[:alnum:]_-])' ||
        has '\btea[[:space:]]+pr[[:space:]]+merge($|[^[:alnum:]_-])' ||
        has '\bgit-forge\b[^|;&]*\bmerge($|[^[:alnum:]_-])' ||
        has '\bcurl\b[^|;&]*/pulls/[^[:space:]]*/merge'
}

# Segment-scoped: takes one command segment as $1 (rule 3 splits compound
# commands on &&, ||, ;, | and evaluates each segment on its own).
is_mutating_forge_segment() {
    local seg="$1"
    grep -Eiq '\bgit[[:space:]]+(push|commit|merge|rebase)($|[^[:alnum:]_-])' <<<"$seg" ||
        grep -Eiq '\bgh[[:space:]]+pr[[:space:]]+(create|edit|close|merge|ready)($|[^[:alnum:]_-])' <<<"$seg" ||
        grep -Eiq '\bgh[[:space:]]+issue[[:space:]]+edit\b' <<<"$seg" ||
        grep -Eiq '\bgh[[:space:]]+api\b[^|;&]*-X[[:space:]]+(POST|PATCH|DELETE)\b' <<<"$seg" ||
        grep -Eiq '\btea[[:space:]]+pr[[:space:]]+(create|edit|close|merge)($|[^[:alnum:]_-])' <<<"$seg" ||
        grep -Eiq '\bgit-forge\b[^|;&]*\b(merge|create|edit|close)($|[^[:alnum:]_-])' <<<"$seg"
}

# Neutralizes separators (| ; &) INSIDE quoted spans so lexical splitting
# cannot file a suppression under a different segment than its mutation
# (security-lane closure: quoted `|`/`;` in commit messages). Also unfolds
# backslash-newline continuations first. Residual: a backslash-escaped quote
# inside a double-quoted span toggles the tracker; rare, and the failure
# mode collapses toward fewer splits (fail-closed).
mask_quoted_separators() {
    local unfolded="${1//\\$'\n'/ }"
    awk '
    BEGIN { q = "" }
    {
        line = $0
        n = length(line)
        out = ""
        for (i = 1; i <= n; i++) {
            c = substr(line, i, 1)
            if (q != "") {
                if (c == q) q = ""
                else if (c == "|" || c == ";" || c == "&") c = " "
            } else if (c == "\x27" || c == "\"") {
                q = c
            }
            out = out c
        }
        print out
    }' <<<"$unfolded"
}

seg_has_suppression() {
    grep -Eq '2>[[:space:]]*/dev/null|&>[[:space:]]*/dev/null|2>&-' <<<"$1"
}

# Rule 3 core: true iff some segment BOTH suppresses stderr and mutates.
# Suppression on a test/lint segment chained before a push must not block
# (R1/R2 batch #1 — segment scoping; bit us twice live). Split order
# matters: && and || before single | so pipes split last; a lone & (job
# control) is never split so &>/dev/null stays intact inside its segment.
# Compound-redirection shapes — a suppression after `}`, `)`, `done`, or
# `fi` redirects every segment inside the construct — fall back to
# whole-command semantics (fail closed; the pre-segmentation behavior).
has_suppressed_mutating_segment() {
    local masked segs seg whole=0
    masked="$(mask_quoted_separators "$cmd")"
    # `}`/`)` are unambiguous terminators. `done`/`fi` are ordinary words, so
    # they only count as terminators when separator-preceded (`; done`, or at
    # line start) — otherwise `echo done <suppression> && git push` would trip
    # the fallback, which is the very false-positive class batch #1 removed
    # (logic lane R2).
    if grep -Eq '(\}|\))[[:space:]]*(2>|&>)' <<<"$masked" ||
        grep -Eq '(^|[;&|])[[:space:]]*(done|fi)[[:space:]]*(2>|&>)' <<<"$masked"; then
        seg_has_suppression "$masked" && whole=1
    fi
    segs="${masked//"&&"/$'\n'}"
    segs="${segs//"||"/$'\n'}"
    segs="${segs//";"/$'\n'}"
    segs="${segs//"|"/$'\n'}"
    while IFS= read -r seg; do
        [ -n "$seg" ] || continue
        if [ "$whole" -eq 0 ]; then
            seg_has_suppression "$seg" || continue
        fi
        if is_mutating_forge_segment "$seg"; then
            return 0
        fi
    done <<<"$segs"
    return 1
}

# ---- Edit/Write rules (D-006 rules 2 and 4) ---------------------------------

if [ "$event" = "PreToolUse" ] && { [ "$tool" = "Edit" ] || [ "$tool" = "Write" ]; } && [ -n "$file_path" ]; then
    # Rule 2: ledger state files are script-owned; direct edits are blocked.
    if grep -Eq '(^|/)docs/executions/state\.yaml$|(^|/)\.git(/.*)?/ledger/state\.yaml$' <<<"$file_path"; then
        printf 'Blocked: %s is script-owned; use ledger.sh (init/set/stamp/close) instead of editing it directly.\n' "$file_path" >&2
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
    # Evaluated per command segment: only a suppression attached to the
    # MUTATING segment blocks.
    if has_suppressed_mutating_segment; then
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
                # 2 = checked fields failed). Kernel/env breakage — corrupt
                # state (6), missing manifest (9), env breakage such as a
                # missing PyYAML python (10), and anything else — warns and
                # permits: a broken kernel must never brick delivery, since
                # the --override recovery path runs through the same kernel
                # (D-006 #5; review R1 should-fix; batch #2).
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

if has '\bgh[[:space:]]+pr[[:space:]]+(merge|close)($|[^[:alnum:]_-])'; then
    printf '\n[WORKFLOW GUARD] PR merge/close detected. Inventory cleanup before deleting anything:\n'
    git status --short 2>/dev/null || true
    git worktree list --porcelain 2>/dev/null | sed -n '1,40p' || true
    printf '[WORKFLOW GUARD] Load and run cleanup-delivery/SKILL.md for cleanup decisions.\n'
fi
