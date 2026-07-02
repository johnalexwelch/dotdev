#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
event="$(jq -r '.hook_event_name // ""' <<<"$input" 2>/dev/null || true)"
tool="$(jq -r '.tool_name // ""' <<<"$input" 2>/dev/null || true)"
cmd="$(jq -r '.tool_input.command // ""' <<<"$input" 2>/dev/null || true)"

[ "$tool" = "Bash" ] || exit 0
[ -n "$cmd" ] || exit 0

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

if [ "$event" = "PreToolUse" ]; then
    if has '\bgh[[:space:]]+issue[[:space:]]+(create|edit)\b' &&
        adds_ready_for_agent &&
        { prd_like_text "$cmd" || prd_like_text "$(existing_issue_text)"; }; then
        printf 'Blocked: PRD/spec parent issues must not be labeled ready-for-agent. Use child implementation issues from to-issues.\n' >&2
        exit 2
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
