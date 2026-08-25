#!/usr/bin/env bash
# workflow-guard.sh — PreToolUse/PostToolUse guard rails for delivery workflows.
# D-006 additions: merge gate (ledger check finalize), ledger state write
# block (git-dir live state, per-run snapshots, legacy state.yaml),
# worktree-baseline sidecar write block, stderr-suppression block on mutating
# forge/git commands, and entry enforcement (warn-only in Phase 0;
# LEDGER_ENTRY_ENFORCE=block escalates).
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

# Rule 3: shell tokenizer (D-006, PR #174 rebuild). The prior regex-over-
# lexically-split-segments model is retired (see git history and PR #174's
# 11-round review for the 11 defect shapes it accumulated — chiefly that it
# could not represent WHERE a redirection applies, since that's shell
# grammar, not a regex-splittable property). Rule 3 is now delegated to
# guard-rule3-tokenizer.py: a hand-rolled lexer + recursive-descent parser +
# fd-state walker (python3 stdlib only), sitting next to this script.
#
# DECLARED BOUNDARY (the goal is precision WITHIN this boundary, not closing
# it — PR #174's recorded decision):
#
#   Rule 3 sees a mutation only when its text sits as LITERAL
#   (expansion-free) text in command position, in the same scope-chain as
#   the suppression. Any mechanism that carries command text across that
#   boundary — name binding (aliases, functions, a script invoked by name),
#   parameter expansion, eval of a variable, a here-document body, a file
#   read at runtime — is out of scope and FAILS OPEN. Tokenizer/parse
#   errors FAIL CLOSED (block).
#
# "Literal (expansion-free)" is the round-1 fail-closed refinement of the
# original "unquoted" criterion: quoting that preserves the execve (\git,
# git "push") no longer blinds detection — words are judged by their
# quote-removed value, and command names by basename. Only expansion-
# carrying text (whose value is unknowable at guard time) fails open.
#
# See dotfiles/.claude/hooks/guard-rule3-tokenizer.py for the full spec and
# test/test-guard-rules.sh's Rule 3 section for the acceptance matrix.

# Resolves the tokenizer path from THIS script's real (symlink-resolved)
# location, since the deployed hook at ~/.claude/hooks/workflow-guard.sh is
# a per-file symlink into the repo -- the sibling .py only exists next to
# the resolved target, not next to the symlink itself.
_guard_rule3_tokenizer_path() {
    local src="${BASH_SOURCE[0]}"
    while [ -L "$src" ]; do
        local link
        link="$(readlink "$src")"
        case "$link" in
        /*) src="$link" ;;
        *) src="$(dirname "$src")/$link" ;;
        esac
    done
    printf '%s/guard-rule3-tokenizer.py' "$(cd "$(dirname "$src")" && pwd)"
}

# Conservative prefilter (latency + blast-radius control): rule 3 can only
# ever match when the command contains BOTH (i) a mutation-verb substring —
# push|commit|merge|rebase|create|edit|close|ready|api, case-insensitive —
# AND (ii) suppression-capable text — /dev/null, or & followed by an
# optionally-spaced - (the fd-close operand may be spaced: `2>& -`).
#
# Both clauses run against a NORMALIZED copy of the command with backslash,
# single-quote, double-quote, dollar, and newline characters deleted
# (round-1 + round-2 security/logic/style lanes). Why: the tokenizer
# matches QUOTE-REMOVED word values, folds ANSI-C ($'…') and locale ($"…")
# wrappers into those values, and joins backslash-newline continuations —
# so a quote-split (`pu"sh"`, `2>&"-"`), ANSI-C-split (`p$'ush'`,
# `2>&$'-'`), or continuation-split spelling is a real candidate the raw
# text does not show. Deleting those five characters mirrors each of those
# transformations, and deleting can only CREATE grep matches, never
# destroy one (no pattern below contains any deleted character), so the
# normalized grep matches a superset of the raw one. Deleting `$` also
# strips genuine expansions (`$VAR`) — again only widening the match set.
#
# Conservativeness, stated precisely: every mutation pattern the tokenizer
# recognizes contains one of the clause-(i) verbs as a substring of a
# quote-removed word value, and every NULL/CLOSED fd classification
# requires a quote-removed `/dev/null` target or a `-` dup operand after
# an `&` operator — all of which survive in the normalized text.
#
# Residual, MEASURED (round 2, after adding `$` to the deletion set): the
# tokenizer does NOT decode ANSI-C escape SEQUENCES — probed directly:
# an escape-encoded dup operand and escape-encoded /dev/null spellings
# (hex `\x2d`-style and octal `\055`-style dash; `\x2f`/`\057`-encoded
# slashes and letters in the target) all PERMIT at the tokenizer too, so
# both layers are consistent and the value-level residual search came up
# empty. Escape DECODING is therefore the first place a future gap would
# open: if the tokenizer ever decodes `$'\x..'` escapes, those spellings
# become detector-visible while staying prefilter-invisible — revisit this
# prefilter IN THE SAME CHANGE. The payoff: python3 is never invoked for
# commands failing either clause, so a broken/missing interpreter cannot
# brick delivery for the vast majority of Bash calls.
rule3_prefilter_candidate() {
    local normalized
    normalized="$(tr -d "\\\\\"'\$\n" <<<"$cmd")"
    grep -Eiq '(push|commit|merge|rebase|create|edit|close|ready|api)' <<<"$normalized" &&
        grep -Eq '/dev/null|&[[:space:]]*-' <<<"$normalized"
}

# Returns 0 (block) / 1 (permit) for a NORMAL tokenizer verdict, setting
# RULE3_REASON on block. On a tokenizer/interpreter failure it exits the
# whole hook directly (fail closed) with a message naming the tokenizer,
# rather than returning, since that path's message intentionally does not
# share the normal block's "stderr" wording contract.
rule3_tokenizer_blocks() {
    rule3_prefilter_candidate || return 1
    local tokenizer python_out python_status
    tokenizer="$(_guard_rule3_tokenizer_path)"
    if [ ! -f "$tokenizer" ]; then
        printf 'Blocked: rule 3 tokenizer missing at %s -- failing closed. Restore it from the dotfiles repo (git checkout -- dotfiles/.claude/hooks/guard-rule3-tokenizer.py, or re-run the dotfiles deploy) to re-enable rule 3.\n' "$tokenizer" >&2
        exit 2
    fi
    set +e
    python_out="$(printf '%s' "$cmd" | python3 -S "$tokenizer" 2>&1)"
    python_status=$?
    set -e
    case "$python_status" in
    0)
        return 1
        ;;
    1)
        RULE3_REASON="$python_out"
        return 0
        ;;
    *)
        printf 'Blocked: rule 3 tokenizer errored (exit %s) -- failing closed:\n%s\nRule 3 blocks all candidate commands until this is fixed: check that python3 is on PATH and working, and report this command shape if the tokenizer itself errored.\n' \
            "$python_status" "$python_out" >&2
        exit 2
        ;;
    esac
}

# ---- Edit/Write rules (D-006 rules 2 and 4) ---------------------------------

if [ "$event" = "PreToolUse" ] && { [ "$tool" = "Edit" ] || [ "$tool" = "Write" ]; } && [ -n "$file_path" ]; then
    # Rule 2: ledger state files are script-owned; direct edits are blocked.
    # Covers the git-dir live state, the per-run committed snapshots
    # (docs/executions/runs/<run_id>.yaml — the current record), and the
    # legacy shared docs/executions/state.yaml (frozen historical record).
    # Case-insensitive: APFS is case-insensitive, so a case-variant spelling
    # writes the real file.
    # runs/ matches ANY depth and ANY basename prefix (.*, not .+ — a dotfile
    # basename like '.yaml' IS the extension, leaving nothing for .+ to eat):
    # the kernel only authors flat non-dotfile files, so anything else under
    # runs/ is by definition hand-written — exactly what this rule blocks; the
    # block set must never be narrower than what the CI gate could be asked to
    # read (review rounds: security H1, security r2).
    if grep -Eiq '(^|/)docs/executions/state\.yaml$|(^|/)docs/executions/runs/.*\.ya?ml$|(^|/)\.git(/.*)?/ledger/state\.yaml$' <<<"$file_path"; then
        printf 'Blocked: %s is script-owned; use ledger.sh (init/set/stamp/unstamp/flush/close) instead of editing it directly.\n' "$file_path" >&2
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

    # Rule 2c: routing-confirmed marker is script-owned — written by
    # routing-confirm.sh on explicit user confirmation. Direct writes bypass
    # the routing gate (P0 vulnerability: agent could forge evidence).
    if grep -Eiq '(^|/)(\.pi/)?routing-confirmed$' <<<"$file_path"; then
        printf 'Blocked: %s is script-owned; it is written by routing-confirm.sh on user confirmation — never write it by hand.\n' "$file_path" >&2
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

# RULE A: Agent/subagent dispatch requires routing evidence in opted-in repos
# This is the HARD gate that would have caught the Aug 2026 $729 session
# where 102 subagents were spawned without ROUTE_CARD.
# D-006 learning: exploring/planning work that escalates into execution
# must re-route through workflow-router, not spawn agents directly.
case "$tool" in
Agent | subagent | Task | Dispatch | spawn_agent | TaskDispatch | dispatch_agent)
    repo_top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
    # Only enforce in opted-in repos (docs/executions/ present)
    if [ -n "$repo_top" ] && [ -d "$repo_top/docs/executions" ]; then
        # Reuse has_routing_evidence if available (defined later for Bash)
        # For now, check .pi/routing-confirmed file directly
        routing_file=""
        if [ -f "$repo_top/.pi/routing-confirmed" ]; then
            routing_file="$repo_top/.pi/routing-confirmed"
        elif [ -f "$cwd/.pi/routing-confirmed" ]; then
            routing_file="$cwd/.pi/routing-confirmed"
        elif [ -f "$HOME/.pi/routing-confirmed" ]; then
            routing_file="$HOME/.pi/routing-confirmed"
        fi

        if [ -z "$routing_file" ]; then
            if [ "${ROUTING_ENFORCE:-}" = "block" ]; then
                printf '\n' >&2
                printf '╔════════════════════════════════════════════════════════════════╗\n' >&2
                printf '║  🚨 BLOCKED: Agent/subagent dispatch without ROUTE_CARD       ║\n' >&2
                printf '╠════════════════════════════════════════════════════════════════╣\n' >&2
                printf '║  Load workflow-router → emit ROUTE_CARD → get confirmation    ║\n' >&2
                printf '║                                                                ║\n' >&2
                printf '║  Baseline: Aug 2026 session spawned 102 subagents ($729)       ║\n' >&2
                printf '║  without routing through workflow-router.                      ║\n' >&2
                printf '╚════════════════════════════════════════════════════════════════╝\n' >&2
                exit 2
            else
                printf '\n[WORKFLOW GUARD] ⚠️ Agent/subagent dispatch without ROUTE_CARD.\n' >&2
                printf '[WORKFLOW GUARD] Load workflow-router and emit ROUTE_CARD first.\n' >&2
                printf '[WORKFLOW GUARD] Baseline: Aug 2026 session spawned 102 subagents ($729) without routing.\n' >&2
            fi
        fi
    fi

    # RULE E: Model routing — warn when using Opus for non-judgment tasks
    # Sonnet should be default; Opus is 5x more expensive per token
    # Cost evidence: Aug 2026 claude-opus-5 $12,262 vs claude-sonnet-5 $1,882
    agent_model="$(jq -r '.tool_input.model // ""' <<<"$input" 2>/dev/null || true)"
    agent_task="$(jq -r '.tool_input.task // .tool_input.prompt // ""' <<<"$input" 2>/dev/null || true)"
    if [[ "$agent_model" =~ opus ]] && [ -n "$agent_task" ]; then
        # Check if task looks like judgment work (synthesis, architecture, security)
        is_judgment_task=false
        if echo "$agent_task" | grep -Eiq '(synthesize|synthesis|judge|judgment|decide|decision|architect|security|review.*security|concurrency|final.*review|arbiter)'; then
            is_judgment_task=true
        fi
        if [ "$is_judgment_task" = false ]; then
            # Check for fact-gathering patterns that should use Sonnet
            if echo "$agent_task" | grep -Eiq '(gather|collect|scan|audit|explore|discover|find|list|enumerate|check|verify|validate|test|eval)'; then
                printf '\n[WORKFLOW GUARD] 💰 Opus model for fact-gathering task. Consider Sonnet.\n' >&2
                printf '[WORKFLOW GUARD] Task: %.80s...\n' "$agent_task" >&2
                printf '[WORKFLOW GUARD] Opus costs 5x more. Reserve for synthesis/judgment.\n' >&2
            fi
        fi
    fi

    # RULE B: Parallelism cap — no session may spawn >10 subagents
    # Track spawns in a session-scoped counter file
    # Baseline: Aug 2026 session spawned 102 subagents ($729)
    session_id="${CLAUDE_SESSION_ID:-${PI_SESSION_ID:-$$}}"
    count_file="/tmp/.agent-spawn-count-$session_id"
    count=$(cat "$count_file" 2>/dev/null || echo 0)
    if [ "$count" -ge 10 ]; then
        if [ "${PARALLELISM_ENFORCE:-}" = "block" ]; then
            printf '\n' >&2
            printf '╔════════════════════════════════════════════════════════════════╗\n' >&2
            printf '║  🚨 BLOCKED: Parallelism cap (10 subagents) exceeded          ║\n' >&2
            printf '╠════════════════════════════════════════════════════════════════╣\n' >&2
            printf '║  Checkpoint, handoff, or split into multiple sessions.        ║\n' >&2
            printf '║  Current count: %d / 10                                        ║\n' "$count" >&2
            printf '╚════════════════════════════════════════════════════════════════╝\n' >&2
            exit 2
        else
            printf '\n[WORKFLOW GUARD] ⚠️ Parallelism cap (10 subagents) exceeded. Count: %d\n' "$count" >&2
            printf '[WORKFLOW GUARD] Checkpoint, handoff, or split into multiple sessions.\n' >&2
        fi
    fi
    echo $((count + 1)) >"$count_file"
    exit 0
    ;;
esac

[ "$tool" = "Bash" ] || exit 0
[ -n "$cmd" ] || exit 0

# RULE C: describe-pr gate — block gh pr create without PR body file
# workflow-finalize requires describe-pr to write a body file before PR creation
is_pr_create() {
    has '\bgh[[:space:]]+pr[[:space:]]+create\b'
}

if is_pr_create; then
    repo_top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$repo_top" ] && [ -d "$repo_top/docs/executions" ]; then
        pr_bodies_dir="$repo_top/docs/executions/.pr-bodies"
        # Check for any recent PR body file (modified in last 2 hours)
        recent_body=""
        if [ -d "$pr_bodies_dir" ]; then
            recent_body="$(find "$pr_bodies_dir" -name '*.md' -mmin -120 2>/dev/null | head -1)"
        fi
        if [ -z "$recent_body" ]; then
            if [ "${PR_BODY_ENFORCE:-}" = "block" ]; then
                printf '\n' >&2
                printf '╔════════════════════════════════════════════════════════════════╗\n' >&2
                printf '║  🚨 BLOCKED: gh pr create without describe-pr body file     ║\n' >&2
                printf '╠════════════════════════════════════════════════════════════════╣\n' >&2
                printf '║  Run describe-pr first to generate PR body.                  ║\n' >&2
                printf '║  Expected: docs/executions/.pr-bodies/*.md                   ║\n' >&2
                printf '╚════════════════════════════════════════════════════════════════╝\n' >&2
                exit 2
            else
                printf '\n[WORKFLOW GUARD] ⚠️ gh pr create without describe-pr body file.\n' >&2
                printf '[WORKFLOW GUARD] Run describe-pr first. Expected: docs/executions/.pr-bodies/*.md\n' >&2
            fi
        fi
    fi
fi

# RULE D: Large diff warning — warn on PRs with >500 lines changed
# Helps catch unintentional scope creep before PR creation
is_pr_create_or_ready() {
    has '\bgh[[:space:]]+pr[[:space:]]+(create|ready)\b'
}

if is_pr_create_or_ready; then
    repo_top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$repo_top" ]; then
        # Get default branch
        default_branch="$(git -C "$repo_top" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo main)"
        # Count lines changed
        diff_stats="$(git -C "$repo_top" diff --stat "origin/$default_branch"...HEAD 2>/dev/null | tail -1 || true)"
        if [ -n "$diff_stats" ]; then
            # Extract insertions and deletions
            insertions="$(echo "$diff_stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)"
            deletions="$(echo "$diff_stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)"
            total_lines=$((${insertions:-0} + ${deletions:-0}))
            if [ "$total_lines" -gt 500 ]; then
                printf '\n[WORKFLOW GUARD] ⚠️ Large diff detected: %d lines changed (threshold: 500)\n' "$total_lines" >&2
                printf '[WORKFLOW GUARD] Consider splitting into smaller PRs if changes are logically independent.\n' >&2
                printf '[WORKFLOW GUARD] If logically atomic, note the size in PR description.\n' >&2
            fi
        fi
    fi
fi

# Routing enforcement: block mutations without routing evidence
# This is the HARD gate — documentation/habits are soft.
is_mutation_cmd() {
    # Original patterns
    has '\bgh[[:space:]]+issue[[:space:]]+create\b' ||
        has '\bgh[[:space:]]+pr[[:space:]]+(create|merge|ready)\b' ||
        has '\bgit[[:space:]]+(commit|push)\b' ||
        has '\bgit-forge\b[^|;&]*\b(create|merge)\b' ||
        # Gap #1: gh api -X POST/PATCH/DELETE
        has '\bgh[[:space:]]+api\b[^|;&]*(-X|--method)[[:space:]]*(POST|PUT|PATCH|DELETE)' ||
        # Gap #2: curl to github API with mutating methods
        has '\bcurl\b[^|;&]*(-X[[:space:]]*|--request[[:space:]]+)(POST|PUT|PATCH|DELETE)[^|;&]*github' ||
        has '\bcurl\b[^|;&]*github[^|;&]*(-X[[:space:]]*|--request[[:space:]]+)(POST|PUT|PATCH|DELETE)' ||
        # Gap #3: hub CLI
        has '\bhub[[:space:]]+(pull-request|create|issue)\b' ||
        # Gap #4: glab (GitLab CLI)
        has '\bglab[[:space:]]+(mr|issue)[[:space:]]+(create|merge)\b' ||
        # Gap #5: git -C <path> or --git-dir before commit/push
        has '\bgit[[:space:]]+(-C[[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]+)[[:space:]]+(commit|push)\b'
}

# Validate routing marker: check expires_at and session_pid
# Returns 0 if valid, 1 if invalid/missing/expired
validate_routing_marker() {
    local marker_path="$1"
    [[ -f "$marker_path" ]] || return 1
    [[ -s "$marker_path" ]] || return 1 # empty file

    # Parse YAML fields (grep-based, no deps)
    local expires_at session_pid
    expires_at="$(grep -E '^expires_at:' "$marker_path" 2>/dev/null | sed 's/^expires_at:[[:space:]]*//' | tr -d '[:space:]')"
    session_pid="$(grep -E '^session_pid:' "$marker_path" 2>/dev/null | sed 's/^session_pid:[[:space:]]*//' | tr -d '[:space:]')"

    # Reject if expires_at missing
    [[ -n "$expires_at" ]] || return 1

    # Reject if expired
    local now
    now="$(date +%s)"
    [[ "$expires_at" =~ ^[0-9]+$ ]] || return 1
    ((expires_at > now)) || return 1

    # Reject if session_pid missing or doesn't match process tree
    [[ -n "$session_pid" && "$session_pid" =~ ^[0-9]+$ ]] || return 1

    # Check if session_pid is current process or ancestor
    local check_pid=$$
    while [[ "$check_pid" -gt 1 ]]; do
        [[ "$check_pid" == "$session_pid" ]] && return 0
        # Get parent PID (portable: ps)
        check_pid="$(ps -o ppid= -p "$check_pid" 2>/dev/null | tr -d '[:space:]')"
        [[ -n "$check_pid" && "$check_pid" =~ ^[0-9]+$ ]] || break
    done

    return 1
}

has_routing_evidence() {
    # Find routing-confirmed file (repo > cwd > home)
    local routing_file=""
    local repo_top
    repo_top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"

    if [[ -n "$repo_top" && -f "$repo_top/.pi/routing-confirmed" ]]; then
        routing_file="$repo_top/.pi/routing-confirmed"
    elif [[ -f "$cwd/.pi/routing-confirmed" ]]; then
        routing_file="$cwd/.pi/routing-confirmed"
    elif [[ -f "$HOME/.pi/routing-confirmed" ]]; then
        routing_file="$HOME/.pi/routing-confirmed"
    fi

    # Method 1: env var — must validate against stored evidence
    # ponytail: grep for line match; upgrade to proper YAML parse if format changes
    if [[ -n "${ROUTED_SESSION:-}" ]]; then
        [[ -n "$routing_file" ]] && grep -q "^session_pid: ${ROUTED_SESSION}$" "$routing_file" 2>/dev/null && return 0
        return 1 # env var set but no matching evidence → reject
    fi

    if [[ -n "${ROUTE_CARD_ID:-}" ]]; then
        [[ -n "$routing_file" ]] && grep -q "^route_id: ${ROUTE_CARD_ID}$" "$routing_file" 2>/dev/null && return 0
        return 1 # env var set but no matching evidence → reject
    fi

    # Method 2: marker file alone (no env var)
    if [[ -n "$routing_file" ]]; then
        # When ROUTING_ENFORCE=block, validate TTL and session binding
        if [[ "${ROUTING_ENFORCE:-}" = "block" ]]; then
            validate_routing_marker "$routing_file" && return 0
            return 1
        fi
        # Default: trust existence
        return 0
    fi

    return 1
}

if [ "$event" = "PreToolUse" ]; then
    # RULE -1: Block Bash writes to routing-confirmed marker (prevents forge)
    # ponytail: simple pattern match; upgrade to AST tokenizer if evasion found
    if has 'routing-confirmed' &&
        { has '(>|>>)[[:space:]]*(\./)?(\.pi/)?routing-confirmed' ||
            has '(cat|echo|printf|tee)[[:space:]]' && has '(>|>>)' ||
            has '\b(cp|mv|install)\b.*(\.pi/)?routing-confirmed'; }; then
        printf 'Blocked: cannot write routing-confirmed via Bash — use routing-confirm.sh\n' >&2
        exit 2
    fi

    # RULE 0: Routing gate — mutations require routing evidence
    # This catches: gh issue create, gh pr create/merge, git commit/push
    # Bypass: ROUTED_SESSION=1 or .pi/routing-confirmed file
    # Warn-only in Phase 0; ROUTING_ENFORCE=block escalates to a hard block.
    if is_mutation_cmd && ! has_routing_evidence; then
        if [ "${ROUTING_ENFORCE:-}" = "block" ]; then
            printf '\n' >&2
            printf '╔════════════════════════════════════════════════════════════════╗\n' >&2
            printf '║  🛑 BLOCKED: No routing evidence for mutation                  ║\n' >&2
            printf '╠════════════════════════════════════════════════════════════════╣\n' >&2
            printf '║  Load workflow-router → emit ROUTE_CARD → get confirmation    ║\n' >&2
            printf '║                                                                ║\n' >&2
            printf '║  Bypass: ROUTED_SESSION=1 <command>                            ║\n' >&2
            printf '╚════════════════════════════════════════════════════════════════╝\n' >&2
            exit 2
        fi
    fi

    if has '\bgh[[:space:]]+issue[[:space:]]+(create|edit)\b' &&
        adds_ready_for_agent &&
        { prd_like_text "$cmd" || prd_like_text "$(existing_issue_text)"; }; then
        printf 'Blocked: PRD/spec parent issues must not be labeled ready-for-agent. Use child implementation issues from to-issues.\n' >&2
        exit 2
    fi

    # Rule 3: stderr suppression on mutating git/gh/tea/git-forge commands
    # hides failures the workflow depends on seeing (D-006, closes C36).
    # Delegated to guard-rule3-tokenizer.py (see the boundary comment above
    # rule3_tokenizer_blocks) behind a conservative prefilter.
    RULE3_REASON=""
    if rule3_tokenizer_blocks; then
        printf 'Blocked: stderr suppression on a mutating git/gh/tea/git-forge command hides failures. Re-run it without 2>/dev/null (or &>/dev/null). (%s)\n' \
            "${RULE3_REASON:-suppressed mutation}" >&2
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
