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
# backslash-newline continuations first, and honors backslash escapes inside
# double-quoted spans so an escaped quote does not desynchronize the tracker
# and leave a real separator unmasked (security lane R2).
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
            # Inside a double-quoted span a backslash escapes the next
            # character (including a quote); single quotes take no escapes.
            if (q == "\"" && c == "\\" && i < n) {
                out = out c substr(line, i + 1, 1)
                i++
                continue
            }
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

# Suppression spellings that hide stderr from the caller:
#   2>/dev/null, 2>>/dev/null, &>/dev/null (spaces and quotes tolerated),
#   2>&- (close), and `>/dev/null … 2>&1` — the most common idiom of all,
#   which matched on neither this branch nor main until the security lane's
#   R2 pass. A bare 2>&1 is NOT suppression: it merges stderr into a stream
#   the caller still sees, so it counts only alongside a /dev/null stdout.
seg_has_suppression() {
    local seg="$1"
    grep -Eq "2>>?\|?[[:space:]]*['\"]?/dev/null|&>\|?[[:space:]]*['\"]?/dev/null|2>&-" <<<"$seg" && return 0
    # Branch 2: stdout to /dev/null combined with a stderr merge. The leading
    # class excludes `&` (so `&>` stays on branch 1, which already handles it)
    # and `>` (so the second `>` of `>>` cannot start a match) — but NOT
    # whitespace: `cmd>/dev/null 2>&1` is valid bash and really does suppress,
    # and anchoring on whitespace let it through (style lane R5).
    grep -Eq '2>&1' <<<"$seg" &&
        grep -Eq "(^|[^&>])[0-9]*>>?\|?[[:space:]]*['\"]?/dev/null" <<<"$seg"
}

# Blanks out command substitutions (`$( … )`, innermost-first so nesting
# collapses, plus backticks) so their closing paren is not mistaken for a
# subshell/group terminator (tests lane R2). Used ONLY for terminator
# detection — segment mutation matching always runs on the unmasked text, so
# a mutation inside a substitution is still caught in its own segment.
#
# LIMITATION (tests lane R3, sharpened by the style lane in R5): the inner
# classes are `[^()]`, so this masks only substitutions and arithmetic whose
# contents carry no literal paren. Nested-paren arithmetic, process
# substitution `<( … )`, array assignment, and a quoted paren INSIDE a
# substitution (`$(grep "x)y" f)`) leave parens standing, arm the fallback,
# and block a benign command — all fail-closed, all pinned in
# test-guard-rules.sh so the boundary stays visible. A quoted paren on its
# own (`echo "a)" …`) does NOT arm: the closing quote sits between it and the
# redirect, so the terminator pattern cannot match. Fixing the real ones
# needs a paren-matching pass, not a wider character class.
mask_command_substitutions() {
    local s="$1" prev=""
    # Arithmetic expansion first: its `))` is not a subshell close, and the
    # substitution pattern below cannot consume it (nested parens).
    s="$(sed -E 's/\$\(\([^()]*\)\)/__ARITH__/g' <<<"$s")"
    while [ "$s" != "$prev" ]; do
        prev="$s"
        s="$(sed -E 's/\$\([^()]*\)/__SUBST__/g' <<<"$s")"
    done
    printf '%s' "${s//\`/ }"
}

# Prints the text of every `$( … )` span, innermost-first. Used to decide
# whether masking substitutions would hide a compound construct that mutates
# (security lane R5): a construct wrapped in a substitution otherwise loses
# its terminator and the fallback never arms.
substitution_spans() {
    local s="$1" prev="" spans=""
    s="$(sed -E 's/\$\(\([^()]*\)\)/__ARITH__/g' <<<"$s")"
    while [ "$s" != "$prev" ]; do
        prev="$s"
        spans="${spans}$(grep -oE '\$\([^()]*\)' <<<"$s")"$'\n'
        s="$(sed -E 's/\$\([^()]*\)/__SUBST__/g' <<<"$s")"
    done
    printf '%s' "$spans"
}

# Rule 3 core. The burden is INVERTED (coordinator design call, R8): when a
# command contains both a mutation and suppression, it blocks unless
# segmentation can prove they are independent. The earlier shape — block only
# when a recognized carrier links the two — made every gap in the carrier
# enumeration a fail-open, and eight review rounds showed that enumeration is
# open-ended: three fail-opens shipped to declared freezes (construct
# redirect, bare exec, opener-prefixed exec), each found by measuring against
# main rather than by the suite. Provable independence is a small closed set;
# carriers are not. So misses now land fail-closed, the direction D-006 #5
# permits this guard to err. The recorded path to narrowing the resulting
# over-blocks is a tokenizer that tracks redirection scope, never a further
# widening of the predicate.
#
# Rule 3 core: true iff some segment BOTH suppresses stderr and mutates.
# Suppression on a test/lint segment chained before a push must not block
# (R1/R2 batch #1 — segment scoping; bit us twice live). Split order
# matters: && and || before single | so pipes split last; a lone & (job
# control) is never split so &>/dev/null stays intact inside its segment.
# Compound-redirection shapes — a suppression after `}`, `)`, `done`, or
# `fi` redirects every segment inside the construct — fall back to
# whole-command semantics (fail closed; the pre-segmentation behavior).
# Arming is decided per construct, from that construct's own redirect list.
has_suppressed_mutating_segment() {
    local masked terminator_view segs seg whole=0
    masked="$(mask_quoted_separators "$cmd")"
    # Fail CLOSED if a masking helper breaks: an empty mask would empty every
    # segment and permit the command outright (security lane R2 note).
    [ -n "$masked" ] || masked="$cmd"
    # `>|` is force-clobber, not a pipe: normalize it away before splitting so
    # segmentation does not cut a redirect in half and strand the suppression
    # in a segment of its own (style lane R5).
    masked="${masked//">|"/>}"
    # Terminator detection runs on a substitution-masked view so a `$( … )`
    # close-paren is not read as a subshell terminator (tests lane R2).
    # Mutation matching below always uses the unmasked segments.
    terminator_view="$(mask_command_substitutions "$masked")"
    [ -n "$terminator_view" ] || terminator_view="$masked"
    # ...unless masking would swallow a MUTATING construct along with its
    # terminator, in which case judge terminators unmasked (security lane R5).
    # A benign span never triggers this, so `echo $(date) 2>/dev/null && git
    # push` still permits.
    if is_mutating_forge_segment "$(substitution_spans "$masked")"; then
        terminator_view="$masked"
    fi
    # `)` is an unambiguous terminator once substitutions are masked. `}`,
    # `done`, `fi`, and `esac` are not: a brace group's `}` is always
    # separator-preceded while a parameter expansion's `${VAR}` never is, and
    # the word terminators appear as ordinary arguments. Requiring a preceding
    # separator (or line start) keeps `mkdir -p ${DIR} <suppression> && git
    # commit` and `echo done <suppression> && git push` out of the fallback —
    # the batch #1 false-positive class (logic lane R2, security lane R5).
    # ANY redirect after the terminator is a candidate — a construct
    # suppressed via stdout-dup (`} >/dev/null 2>&1`) is redirected just as
    # thoroughly as one using `2>` (security lane R2). What decides arming is
    # whether the CONSTRUCT'S OWN redirect list is suppression, so a construct
    # redirecting to a real file never arms the fallback, even when unrelated
    # suppression appears elsewhere in the command. Testing the whole command
    # here re-blocked a suppressed lint/test segment chained before a push —
    # the exact class batch #1 exists to permit (style lane R4).
    # The captured tail must swallow `2>&1` / `2>&-` / `&>` (whose `&` is part
    # of the redirect) while still stopping at a `&&` that starts the next
    # segment — hence `&` is admitted only before a digit, `-`, or `>`.
    local redirect_lists
    redirect_lists="$(grep -oE '(\)|(^|[;&|])[[:space:]]*(\}|done|fi|esac))[[:space:]]*([0-9]*>>?|&>)([^;&|]|&[0-9-]|&>)*' <<<"$terminator_view")"
    while IFS= read -r seg; do
        [ -n "$seg" ] || continue
        if seg_has_suppression "$seg"; then
            whole=1
            break
        fi
    done <<<"$redirect_lists"

    # `exec` redirects the CURRENT SHELL for every later segment. Deciding
    # whether a given `exec` is a command word — rather than an argument or
    # quoted text — is the same open-ended enumeration that produced three
    # fail-opens across rounds R3–R7 (bare, then opener-prefixed, then
    # assignment-prefixed). Under the inverted burden any `exec` token is a
    # carrier and the command blocks. That over-blocks `echo exec …` and
    # `bash -c "exec …"`, both of which main blocked too, so the over-block
    # costs nothing against main and the misses land fail-closed.
    if grep -Eqw 'exec' <<<"$masked"; then
        whole=1
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
