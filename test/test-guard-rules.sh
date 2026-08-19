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

# jq-built variant for commands carrying quotes/newlines that printf-splicing
# cannot legally embed in JSON.
json_bash_jq() {
    local cwd="$1" cmd="$2"
    jq -Rn --arg cwd "$cwd" --arg c "$cmd" \
        '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:$cwd,tool_input:{command:$c}}'
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

# `gh pr merge-queue status` is a non-mutating query; `merge\b` alone
# false-positives on it because `-` is a word boundary (R1/R2 batch #1).
run_hook "$opted_gate" "$(json_bash "$opted_gate" "gh pr merge-queue status")"
assert_status "gh pr merge-queue status is not a merge shape" 0 "$STATUS"

# Kernel ENV breakage (exit 10: missing PyYAML python etc.) must warn-permit
# like corrupt state (6) and missing manifest (9) — a broken kernel must not
# brick delivery, and env errors must not masquerade as gate-unmet exit 1
# (R1/R2 batch #2).
export LEDGER_PYTHON=/nonexistent-python-e93f
run_hook "$opted_gate" "$(json_bash "$opted_gate" "gh pr merge 42")"
assert_status "kernel env breakage warn-permits the merge" 0 "$STATUS"
assert_contains "env-breakage permit says the gate ERRORED" "$OUT" "ERRORED"
unset LEDGER_PYTHON

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

# Worktree-baseline sidecars are script-owned too (D-006 hardening; PR #166
# post_mortem forged-baseline pattern). They live OUTSIDE the repo as siblings
# of the worktree path, so the block matches the filename pattern anywhere.
run_hook "$opted_state" "$(json_file_tool Edit "$opted_state" "$TMPDIR_BASE/.worktree-baseline.wt1.state")"
assert_status "Edit of worktree-baseline sidecar blocked" 2 "$STATUS"
assert_contains "sidecar block says script-owned" "$OUT" "script-owned"
assert_contains "sidecar block names the owning script" "$OUT" "worktree-baseline.sh"

run_hook "$opted_state" "$(json_file_tool Write "$opted_state" "$TMPDIR_BASE/nested/dir/.worktree-baseline.my-feature.state")"
assert_status "Write of worktree-baseline sidecar blocked" 2 "$STATUS"

run_hook "$opted_state" "$(json_file_tool Edit "$opted_state" "$opted_state/src/worktree-baseline-notes.state")"
assert_status "non-sidecar .state file not blocked" 0 "$STATUS"
assert_not_contains "non-sidecar .state carries no block message" "$OUT" "script-owned"

# macOS APFS is case-insensitive: a case-variant spelling writes the real
# sidecar (or state.yaml), so the pattern match must be case-insensitive.
run_hook "$opted_state" "$(json_file_tool Write "$opted_state" "$TMPDIR_BASE/.Worktree-Baseline.wt1.state")"
assert_status "case-variant sidecar spelling blocked" 2 "$STATUS"

run_hook "$opted_state" "$(json_file_tool Write "$opted_state" "$opted_state/docs/executions/State.YAML")"
assert_status "case-variant state.yaml spelling blocked" 2 "$STATUS"

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

# Rule 3 is statement-scoped (R1/R2 batch #1, bit us twice live): suppression
# on a NON-mutating statement chained with a mutating one must pass. The
# tokenizer attributes each redirect to the statement carrying it, so the
# block fires only when the suppression sits on the mutation's own scope
# chain.
run_hook "$plain_sup" "$(json_bash "$plain_sup" "bash test.sh 2>/dev/null && git push origin main")"
assert_status "suppressed test segment before push allowed (&&)" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "npm run lint 2>/dev/null; git commit -m wip")"
assert_status "suppressed lint segment before commit allowed (;)" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "git log --oneline 2>/dev/null | head -5 && git push origin main")"
assert_status "suppressed non-mutating pipe segment before push allowed" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "git push origin main 2>/dev/null && echo pushed")"
assert_status "suppression on the mutating segment still blocked (&&)" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "bash test.sh && git commit -m wip 2>/dev/null")"
assert_status "suppression on trailing mutating segment still blocked" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "gh pr create --fill &>/dev/null || echo failed")"
assert_status "&>/dev/null on the mutating segment still blocked (||)" 2 "$STATUS"

# Whole-token boundaries everywhere `-` is a word boundary (style R1):
# merge-base / commit-graph / git-forge merge-queue are non-mutating.
run_hook "$plain_sup" "$(json_bash "$plain_sup" "git merge-base HEAD origin/main 2>/dev/null")"
assert_status "git merge-base with suppression allowed" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "git commit-graph write 2>/dev/null")"
assert_status "git commit-graph with suppression allowed" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "git-forge merge-queue status 2>/dev/null")"
assert_status "git-forge merge-queue status with suppression allowed" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "git merge feature-x 2>/dev/null")"
assert_status "real git merge with suppression still blocked" 2 "$STATUS"

# Compound-redirection shapes (logic lane): a suppression on a group, subshell,
# loop, or conditional redirects everything inside it. The tokenizer attributes
# a construct's redirect list to the construct's whole body (construct-scoped
# redirect attribution), so a mutation anywhere inside is suppressed and blocks.
run_hook "$plain_sup" "$(json_bash "$plain_sup" "{ git push origin main; } 2>/dev/null")"
assert_status "brace-group suppression over a push still blocked" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "( git push origin main ; ) 2>/dev/null")"
assert_status "subshell suppression over a push still blocked" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash "$plain_sup" "for b in a b; do git push origin b; done 2>/dev/null")"
assert_status "loop-body suppression over a push still blocked" 2 "$STATUS"

# Fail-open shapes found by the security lane: line-continuation folding and
# separators inside quoted arguments must not move the suppression into a
# different segment from the mutation.
lc_cmd="$(printf 'git push origin main \\\n  2>/dev/null')"
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" "$lc_cmd")"
assert_status "line-continuation folded suppression still blocked" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git commit -m "fix: a | b" 2>/dev/null')"
assert_status "quoted pipe does not split the mutating segment" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" "git commit -m 'wip; more' 2>/dev/null")"
assert_status "quoted semicolon does not split the mutating segment" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo "a|b" 2>/dev/null && git push origin main')"
assert_status "quoted pipe in a non-mutating segment still allowed" 0 "$STATUS"

# Alternate suppression spellings (security lane note).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main 2> /dev/null')"
assert_status "spaced /dev/null suppression blocked" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main 2>&-')"
assert_status "fd-close suppression blocked" 2 "$STATUS"

# The compound fallback keys on loop/conditional TERMINATORS, so `done`/`fi`
# must be separator-preceded (`; done`, newline) — as bare arguments they are
# ordinary words and must not trip the whole-command fallback (logic lane R2).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo done 2>/dev/null && git push origin main')"
assert_status "bare 'done' argument does not trip the fallback" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo fi 2>/dev/null && git push origin main')"
assert_status "bare 'fi' argument does not trip the fallback" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'if true; then git push origin main; fi 2>/dev/null')"
assert_status "real 'fi' terminator still trips the fallback" 2 "$STATUS"

# A command substitution's closing paren is not a construct terminator
# (tests lane R2): `echo $(date) <sup> && git push` has no compound
# redirection at all and must not trip the whole-command fallback.
# Single quotes throughout this block are deliberate: the substitution must
# reach the hook payload literally, which is the property under test.
# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $(date) 2>/dev/null && git push origin main')"
assert_status "command-substitution paren does not trip the fallback" 0 "$STATUS"

# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $(basename $(pwd)) 2>/dev/null && git push origin main')"
assert_status "nested command substitution does not trip the fallback" 0 "$STATUS"

# A mutation INSIDE a substitution is still caught: substitution contents are
# walked in the enclosing scope (post-redirect inheritance, PR #174 recorded
# conservative choice), so the enclosing suppression covers the inner push.
# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $(git push origin main) 2>/dev/null')"
assert_status "mutation inside a substitution stays blocked" 2 "$STATUS"

# RECORDED FLIP (tokenizer rebuild, PR #174 recorded decision): the awk-lexer
# branch could not attribute a construct's own redirect to the construct's
# contents alone, so a group/conditional redirect fell back to whole-command
# semantics and blocked these benign compounds. The tokenizer parses real
# construct-scoped redirect attribution — the suppression on `{ … }`/`if…fi`
# applies only inside that construct, and the push is a sibling segment with
# its own (visible) stderr. PR #174 called this compound-fallback narrowing
# "a visible choice" for whoever built the tokenizer to make explicitly; this
# flip is that choice.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '{ npm run lint; } 2>/dev/null && git push origin main')"
assert_status "brace group scoped to its own contents; push unsuppressed" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'if true; then npm run lint; fi 2>/dev/null && git push origin main')"
assert_status "conditional scoped to its own contents; push unsuppressed" 0 "$STATUS"

# Suppression spellings beyond 2>/dev/null (security lane R2). The first is
# the most common idiom in shell and was missed on origin/main too.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main >/dev/null 2>&1')"
assert_status "stdout-to-null plus 2>&1 is suppression" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main 2>>/dev/null')"
assert_status "appending stderr redirect is suppression" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" "git push origin main 2>'/dev/null'")"
assert_status "quoted /dev/null path is suppression" 2 "$STATUS"

# A redirect attached to the preceding token with no space is valid bash and
# really does suppress, so it must be recognized (style lane R5). This is
# pre-existing — main permits these too — but the branch pins the spaced
# forms as must-block, so leaving the unspaced twin open is incoherent.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main>/dev/null 2>&1')"
assert_status "unspaced stdout-dup suppression blocked" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '{ git push origin main; }>/dev/null 2>&1')"
assert_status "unspaced suppression on a construct blocked" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main 2>|/dev/null')"
assert_status "force-clobber stderr redirect blocked" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main>>/dev/null 2>&1')"
assert_status "unspaced appending stdout-dup blocked" 2 "$STATUS"

# `exec 2>/dev/null` redirects the CURRENT SHELL for every later segment, so
# the suppression lands in a different segment from the mutation with no
# terminator token for the per-construct arming logic to hang on (logic lane
# R3). main blocked these under whole-command semantics — a fail-open
# regression, which is why it is fixed rather than recorded like the
# fail-closed notes.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'exec 2>/dev/null; git push origin main')"
assert_status "exec stderr redirect then push blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'exec >/dev/null 2>&1; git commit -am wip')"
assert_status "exec stdout-dup then commit blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'exec 3>&1 2>/dev/null; gh pr create --fill')"
assert_status "exec with an fd then pr create blocks" 2 "$STATUS"

# `exec cmd 2>/dev/null` replaces the shell so nothing later runs, but the
# inverted burden does not try to prove that lexically — it is a carrier and
# blocks. Fail-closed and matches main.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'exec mytool --flag 2>/dev/null && git push origin main')"
assert_status "exec with a command word blocks (over-block, matches main)" 2 "$STATUS"

# A bare exec redirect with no mutation anywhere stays permitted.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'exec 2>/dev/null; npm run lint')"
assert_status "exec redirect without a mutation permits" 0 "$STATUS"

# Splitting on `;` leaves a construct's opening token attached to the segment,
# so a segment-start anchor misses a wrapped exec (style lane R7). Verified as
# genuine suppression by substituting a `>&2` write for the push and observing
# no leak; main blocks all three, so these are fail-open regressions.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '( exec 2>/dev/null; git push origin main )')"
assert_status "exec inside a subshell blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '{ exec 2>/dev/null; git push origin main; }')"
assert_status "exec inside a brace group blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'if true; then exec 2>/dev/null; git push origin main; fi')"
assert_status "exec after then blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'for i in 1; do exec 2>/dev/null; git push origin main; done')"
assert_status "exec after do blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'X=1 exec 2>/dev/null; git push origin main')"
assert_status "exec behind an assignment prefix blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'if false; then :; else exec 2>/dev/null; git push origin main; fi')"
assert_status "exec after else blocks" 2 "$STATUS"

# The exec carrier only counts when suppression is actually present. Without
# that conjunct an `exec` token alone blocks a mutation, and the block's
# message tells the operator to remove a suppression that isn't there —
# unactionable, and `docker exec` is as common as delivery commands get
# (style lane R8). main permits all of these.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'docker exec -it app bash && git push origin main')"
assert_status "docker exec with no suppression permits" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'kubectl exec pod -- ls && git commit -m x')"
assert_status "kubectl exec with no suppression permits" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git commit -m "add exec wrapper"')"
assert_status "exec inside a commit message permits" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main # exec')"
assert_status "exec in a trailing comment permits" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" "ssh host 'exec bash' && git push origin main")"
assert_status "exec in a quoted ssh payload with no suppression permits" 0 "$STATUS"

# An exec redirecting to a REAL FILE preserves the output, so it is not
# suppression and must not arm (tests lane R8).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'exec 2>errors.log; git push origin main')"
assert_status "exec redirecting to a real file permits" 0 "$STATUS"

# An exec replacing the shell with no redirect at all carries no suppression.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'exec git push origin main')"
assert_status "exec with a command word and no redirect permits" 0 "$STATUS"

# Word-boundary control: a longer word containing exec is not a carrier.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git commit -m "refactor execution path"')"
assert_status "execution is not the exec token" 0 "$STATUS"

# RECORDED FLIP (tokenizer rebuild, PR #174 recorded decision): the awk-lexer
# branch treated ANY `exec` token as a carrier because it could not tell a
# command-word `exec` from an argument or a quoted payload — the enumeration
# problem that produced three fail-opens. The tokenizer knows command
# position: `echo exec` puts `exec` in argument position, not command
# position, so it is not the exec builtin at all. And `bash -c "exec
# 2>/dev/null"` recurses the literal `-c` payload in an ISOLATED scope — the
# inner exec redirects the child shell's stderr, never the outer shell's, so
# the outer push stays unsuppressed.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo exec 2>/dev/null && git push origin main')"
assert_status "exec as an echo argument is not the exec builtin" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'bash -c "exec 2>/dev/null"; git push origin main')"
assert_status "exec inside a -c payload redirects the child shell only" 0 "$STATUS"

# The exclusion that keeps &> on its own branch must survive the widening.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main &>/dev/null')"
assert_status "ampersand-redirect suppression still blocked" 2 "$STATUS"

# 2>&1 without a /dev/null stdout target is NOT suppression — it merges
# stderr into a stream the caller still sees.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main 2>&1 | tee push.log')"
assert_status "2>&1 into a visible stream is not suppression" 0 "$STATUS"

# Escaped quote inside a double-quoted span must not desynchronize the quote
# tracker and move the suppression off the mutating segment (security lane
# R2: a surviving member of the MF2 class, and a regression vs origin/main).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git commit -m "a \" ; b" 2>/dev/null')"
assert_status "escaped quote does not split the mutating segment" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git commit -m "a \" | b" 2>/dev/null')"
assert_status "escaped quote with a pipe stays one segment" 2 "$STATUS"

# (The old "broken awk fails closed" probe and its stub bin were deleted in
# round-1 review closure — rule 3 no longer uses awk, so the probe had become
# a vacuous duplicate of the plain block assertion; the REAL fail-closed
# probe for the tokenizer dependency is N18 below. Style lane finding.)

# A construct suppressed via stdout-dup (a null stdout redirect plus 2>&1
# after the closing token) is redirected just as thoroughly as one using 2>:
# the tokenizer's ordered-fd model resolves the construct's own redirect list
# before walking its body, so spelling parity holds (security lane R2,
# second pass).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '{ git push origin main; } >/dev/null 2>&1')"
assert_status "brace group suppressed via stdout-dup blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'for i in 1; do git push origin main; done >/dev/null 2>&1')"
assert_status "loop suppressed via stdout-dup blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'if true; then git push origin main; fi >/dev/null 2>&1')"
assert_status "conditional suppressed via stdout-dup blocks" 2 "$STATUS"

# Arithmetic expansion is parsed as real grammar: `$((…))` is an expansion
# inside a word, never a construct terminator, so no suppression attaches to
# the sibling push — paren-free and nested-paren alike (see the RECORDED
# FLIP block below).
# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $((1+2)) >/dev/null 2>&1 && git push origin main')"
assert_status "paren-free arithmetic expansion is not a terminator" 0 "$STATUS"

# RECORDED FLIP (tokenizer rebuild, PR #174 recorded decision): the awk-lexer
# branch masked command substitutions with a paren-balanced heuristic that
# broke on nested parens, process substitution, and quotes inside a
# substitution — so these benign shapes tripped the compound-fallback and
# blocked. The tokenizer parses arithmetic expansion, process substitution,
# and substitution contents as real shell grammar (quotes tracked by the
# lexer, not paren-counted), so none of them can arm a fallback that no
# longer exists as a heuristic. There is no paren-matching pass left to trip.
# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $(( (1+2)*3 )) 2>/dev/null && git push origin main')"
assert_status "arithmetic is parsed, not paren-matched; push unsuppressed" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'diff <(echo a) <(echo b) 2>/dev/null && git push origin main')"
assert_status "process substitutions are parsed words; push unsuppressed" 0 "$STATUS"

# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $(grep "x)y" f) 2>/dev/null && git push origin main')"
assert_status "quotes inside a substitution are lexer-tracked, not paren-counted" 0 "$STATUS"

# ...and a quoted paren NOT inside a substitution never armed even the old
# heuristic: its closing quote sits between the paren and the redirect
# (style lane R5 counterexample, still true under the tokenizer).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo "a)" 2>/dev/null && git push origin main')"
assert_status "bare quoted paren does not arm the fallback" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'xs=(a b) 2>/dev/null; git push origin main')"
assert_status "array assignment is a statement; push is a sibling segment" 0 "$STATUS"

# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $(date) >/dev/null 2>&1 && git push origin main')"
assert_status "substitution before a stdout-dup redirect is not a terminator" 0 "$STATUS"

# The load-bearing discriminator for widening the terminator alternation:
# arming the fallback is decided by whether the CONSTRUCT'S OWN redirect list
# is suppression, so a construct whose output lands in a real file stays
# permitted — including when unrelated suppression appears elsewhere in the
# command (style lane R4: scoping this to the whole command re-blocked the
# very class batch #1 exists to permit).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '{ git push origin main; } >push.log 2>&1')"
assert_status "construct redirected to a real file is not suppression" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '{ npm run build; } > build.log && bash t.sh 2>/dev/null && git push origin main')"
assert_status "file-redirected construct plus suppressed test segment permits" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '( echo x ) > out.log && bash t.sh 2>/dev/null && git push origin main')"
assert_status "file-redirected subshell plus suppressed test segment permits" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '( cd s && npm test ) >> test.log && npm run lint 2>/dev/null && git push origin main')"
assert_status "appending file redirect plus suppressed lint segment permits" 0 "$STATUS"

# ...while a construct whose own redirect list IS suppression still arms the
# fallback, even though the same command also redirects to a file.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '{ npm run build; } > build.log && { git push origin main; } >/dev/null 2>&1')"
assert_status "suppressed construct still blocks alongside a file-redirected one" 2 "$STATUS"

# A parameter expansion's `}` is not a brace-group terminator (security lane
# R5). A brace group's `}` is always separator-preceded; an expansion's never
# is — so the discriminator is the same one `done`/`fi` already use. Without
# it, ordinary commands using ${VAR} before a suppression get blocked, which
# is the batch #1 false-positive class arriving through a new door.
# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'mkdir -p ${DIR} 2>/dev/null && git commit -m wip')"
assert_status "parameter expansion before a suppression permits" 0 "$STATUS"

# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo ${#items[@]} 2>/dev/null && git push origin main')"
assert_status "array-length expansion before a suppression permits" 0 "$STATUS"

# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo ${a[$((1+1))]} >/dev/null 2>&1 && git push origin main')"
assert_status "subscripted expansion before a stdout-dup permits" 0 "$STATUS"

# `esac` is a terminator like done/fi (security lane R5); main blocked this.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'case x in a) git push origin main;; esac 2>/dev/null')"
assert_status "case statement suppressed as a whole blocks" 2 "$STATUS"

# fd-close on a construct: the one suppression spelling with no construct-
# level coverage until now (security lane R5).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '{ git push origin main; } 2>&-')"
assert_status "fd-close on a construct blocks" 2 "$STATUS"

# A compound construct wrapped in a substitution must not lose its terminator
# to the masker (security lane R5 — fail-open vs both main and 82b6249).
# Terminator detection falls back to the unmasked view when a substitution
# span is itself mutating; a benign span (see the $(date) pin above) does not
# trigger that, so the batch #1 permits are untouched.
# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $(true; { git push origin main; } 2>/dev/null)')"
assert_status "mutating brace group inside a substitution blocks" 2 "$STATUS"

# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $(for i in 1; do git push origin main; done 2>/dev/null)')"
assert_status "mutating loop inside a substitution blocks" 2 "$STATUS"

# --- Rule 3 tokenizer rebuild (PR #174 recorded decision) ---
# The regex-over-lexically-split-segments model above is being replaced by a
# python3 stdlib shell tokenizer that parses real shell grammar: quotes,
# ordered-fd redirections, construct-scoped redirect attribution, command
# substitution, arithmetic, process substitution, heredocs (bodies = data),
# `exec` fd persistence, newlines as statement separators, and bounded
# recursion into `eval "<literal>"` (current-shell scope) and
# `bash|sh|zsh -c "<literal>"` (isolated scope). Declared boundary
# (unchanged): name-binding indirection (functions, aliases, `./script.sh`,
# `eval "$VAR"`, variable expansion carrying command text) stays OUT OF
# SCOPE and fails open. Tokenizer errors and missing python3 fail CLOSED for
# any command whose text could possibly match rule 3; a conservative
# prefilter permits commands that provably cannot match without invoking
# python3 at all.

# N1: a quoted redirect-lookalike is a word, not redirect syntax (S9
# quoted-literal residual); a bare 2>&1 alone is not suppression.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git commit -m "see docs>/dev/null" 2>&1')"
assert_status "quoted redirect-lookalike in a commit message is a word" 0 "$STATUS"

# N2: a quoted argument is not a command (S13 mention over-block). It
# permits because the quoted value is ONE word — `git push origin main` with
# the spaces inside a single argument, which can never match the multi-word
# mutation patterns — NOT because quoting exempts a word from matching. Any
# quoting fix that compares quote-removed values must keep this green
# (round-1 security lane, C-pin).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo "git push origin main" 2>/dev/null')"
assert_status "quoted mention of a mutation is not the mutation" 0 "$STATUS"

# N3: ordered fd semantics — fd2 dups the ORIGINAL (visible) stdout before
# stdout moves to /dev/null, so stderr genuinely reaches the caller. Probed
# locally: `bash -c 'echo err >&2' 2>&1 >/dev/null` prints err.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main 2>&1 >/dev/null')"
assert_status "fd2 dups original stdout before it moves; stderr visible" 0 "$STATUS"

# N4: positional exec tracking — the push runs BEFORE the shell's stderr
# moves. PR #174's "arming is order-insensitive" residual, now separable.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main && exec 2>/dev/null')"
assert_status "push runs before the later exec redirect arms anything" 0 "$STATUS"

# N5: a subshell's exec redirects the subshell only. Probed locally:
# `( exec 2>/dev/null ); echo err >&2` prints err.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '( exec 2>/dev/null ); git push origin main')"
assert_status "subshell exec does not leak into the parent shell" 0 "$STATUS"

# N6: newlines are statement separators — the common multi-line Bash-tool
# shape the old single-segment lexing over-blocked in other shapes.
nl_cmd="$(printf 'bash test.sh 2>/dev/null\ngit push origin main')"
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" "$nl_cmd")"
assert_status "newline-separated suppressed test then unsuppressed push permits" 0 "$STATUS"

# N7: a heredoc body is data, not command text — mutation text inside a
# heredoc body is out-of-scope per the declared boundary.
heredoc_cmd="$(printf 'cat <<EOF 2>/dev/null\ngit push origin main\nEOF')"
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" "$heredoc_cmd")"
assert_status "mutation text inside a heredoc body is data, not command" 0 "$STATUS"

# Precision gains in the fail-closed/blocking direction: the old hook
# permits some of these on an argv[0]-only or adjacency basis; pin the
# tokenizer's closure so a future detector can never regress it.

# N8: git global options before the subcommand no longer hide the push (old
# adjacency regex failed open here).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git -C /tmp push origin main 2>/dev/null')"
assert_status "git global option before the subcommand still blocks" 2 "$STATUS"

# N9: a prefix word does not hide the mutation (matches old behavior;
# pinned so an argv[0]-only detector can never regress it).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'env git push origin main 2>/dev/null')"
assert_status "env-prefixed push still blocks" 2 "$STATUS"

# N10: a LITERAL eval string is command text by definition — recursed in
# the current-shell scope (old blocked via text presence; pinned so
# quote-stripping doesn't fail it open).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'eval "git push origin main" 2>/dev/null')"
assert_status "literal eval payload recurses and blocks" 2 "$STATUS"

# N11: literal -c payloads recurse in an isolated scope — the inner push is
# suppressed inside that scope.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'bash -c "git push origin main 2>/dev/null"')"
assert_status "literal bash -c payload recurses and blocks" 2 "$STATUS"

# N12: a heredoc attached to a suppressed mutation (outside the body) still
# blocks — the boundary is the body, not any nearby redirect.
heredoc2_cmd="$(printf 'git push origin main 2>/dev/null <<EOF\nnotes\nEOF')"
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" "$heredoc2_cmd")"
assert_status "suppressed mutation with a trailing heredoc still blocks" 2 "$STATUS"

# N13: backtick substitution parity with the $() pin above — a mutation
# inside a substitution inherits the enclosing command's suppression.
# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo `git push origin main` 2>/dev/null')"
assert_status "mutation inside a backtick substitution still blocks" 2 "$STATUS"

# Boundary and regression pins: match current, deliberately-scoped behavior
# so the tokenizer rebuild cannot silently drift it.

# N14: name-binding indirection is the declared boundary (PR #174) — an
# accepted fail-open regression, deliberately not chased.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'f() { git push origin main; }; f 2>/dev/null')"
assert_status "function name-binding indirection stays out of scope" 0 "$STATUS"

# N15: a variable redirect target is unknowable at guard time — fail-open
# within the declared boundary.
# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main 2>"$LOGFILE"')"
assert_status "variable redirect target permits" 0 "$STATUS"

# N16: a real-file target keeps output retrievable, so it is not
# suppression.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main >push.log 2>&1')"
assert_status "real-file redirect target permits" 0 "$STATUS"

# N17: an arithmetic command statement parses cleanly; no suppression lands
# on the push. ANOMALY (recorded in the red-phase lane summary): the retired
# awk-lexer hook returned exit 2 here — its command-substitution masker
# recognized `$((...))`/`$(...)` but not bare `((...))`, so the literal `))`
# survived as an unmatched terminator and armed the whole-command fallback.
# The tokenizer-correct answer is 0; pinned as such rather than adjusted to
# match that accidental block.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '(( 1 > 0 )) 2>/dev/null && git push origin main')"
assert_status "bare arithmetic command statement does not arm anything" 0 "$STATUS"

# Fail-closed-on-tokenizer-error probes (mirror the broken-awk stub pattern
# above, but for the python3 dependency the tokenizer introduces).
mkdir -p "$TMPDIR_BASE/broken-python-bin"
printf '#!/usr/bin/env bash\nexit 127\n' >"$TMPDIR_BASE/broken-python-bin/python3"
chmod +x "$TMPDIR_BASE/broken-python-bin/python3"

# N18: a command whose text COULD match rule 3 must fail CLOSED when the
# tokenizer errors or python3 is missing — never silently permit a mutation
# just because the parser broke.
OUT="$(cd "$plain_sup" && printf '%s' "$(json_bash_jq "$plain_sup" 'git push origin main 2>/dev/null')" |
    SKILLS_ROOT="$SKILLS_ROOT_REAL" LEDGER_ENTRY_ENFORCE="" \
        PATH="$TMPDIR_BASE/broken-python-bin:$PATH" bash "$GUARD" 2>&1)"
STATUS=$?
assert_status "broken python3 fails closed on a candidate command" 2 "$STATUS"
assert_contains "broken python3 block names the tokenizer" "$OUT" "tokenizer"

# N19: the prefilter is a conservative HEURISTIC (mutation-verb substring
# plus suppression-capable text), not a proof: quote-split spellings of both
# conjuncts used to slip past its raw-text grep until the hook normalized
# quotes/escapes before grepping — the round-1 red pins below cover that gap.
# What the heuristic buys: a broken interpreter must not brick every git
# command, only genuine rule 3 candidates.
OUT="$(cd "$plain_sup" && printf '%s' "$(json_bash_jq "$plain_sup" 'git status 2>/dev/null')" |
    SKILLS_ROOT="$SKILLS_ROOT_REAL" LEDGER_ENTRY_ENFORCE="" \
        PATH="$TMPDIR_BASE/broken-python-bin:$PATH" bash "$GUARD" 2>&1)"
STATUS=$?
assert_status "prefilter permits a non-mutating command despite broken python3" 0 "$STATUS"

# N20: no mutation verb text at all — the prefilter permits without ever
# touching python3.
OUT="$(cd "$plain_sup" && printf '%s' "$(json_bash_jq "$plain_sup" 'ls /dev/null && echo hi')" |
    SKILLS_ROOT="$SKILLS_ROOT_REAL" LEDGER_ENTRY_ENFORCE="" \
        PATH="$TMPDIR_BASE/broken-python-bin:$PATH" bash "$GUARD" 2>&1)"
STATUS=$?
assert_status "prefilter permits a mutation-verb-free command" 0 "$STATUS"

# --- Round-1 review closure (4-lane review of 589ae61) ---
# Red pins for the fail-open regressions the review found, over-block flips
# the pipeline model owes, boundary/regression green pins, and tokenizer-
# level pins for shapes the hook's prefilter short-circuits. Each cites the
# lane that found it. Real-bash semantics for every pin were re-probed with
# a stderr-marking stub before pinning (results in the lane summary).

# RC1 (tests lane, Must-fix): `select` is a real bash compound; its
# done-redirect covers the body (probed: body stderr genuinely suppressed).
# Absent from the parser's construct dispatch it degraded FAIL-OPEN — an
# unenumerated regression vs both base and origin/main that the test-derived
# differential structurally could not see.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'select x in a; do git push origin main; break; done 2>/dev/null')"
assert_status "select construct suppressed as a whole blocks" 2 "$STATUS"

# RC2 (tests lane): a definition-site redirect applies at INVOCATION, so a
# suppressed definition means every later call runs suppressed (probed). The
# `function` keyword spelling failed open while its posix twin blocked —
# pin BOTH so the two spellings can never diverge again.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'function f { git push origin main; } 2>/dev/null; f')"
assert_status "function-keyword def-site suppression blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'f() { git push origin main; } 2>/dev/null; f')"
assert_status "posix def-site suppression blocks (spelling-parity pin)" 2 "$STATUS"

# RC3 (security lane, High): vacuous quoting — quoting that does not change
# the execve — must not blind the detector. The tokenizer already computes
# the quote-removed literal value for redirect targets (why 2>"/dev/null"
# blocks); command words must get the same treatment. All five probed as
# genuine suppressed executions in real bash.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '\git push origin main 2>/dev/null')"
assert_status "backslash-escaped command word still blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '""git push origin main 2>/dev/null')"
assert_status "empty-quotes-prefixed command word still blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git "push" origin main 2>/dev/null')"
assert_status "quoted subcommand word still blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '"exec" 2>/dev/null; git push origin main')"
assert_status "quoted exec builtin still arms fd persistence" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" "\"eval\" 'git push origin main 2>/dev/null'")"
assert_status "quoted eval with a literal payload still recurses" 2 "$STATUS"

# RC4 (security lane, High): bash backtracks a failed arithmetic parse at
# command position to a nested subshell, so `((cmd) redirect)` really
# executes with stderr hidden (probed both forms). The tokenizer must mirror
# the fallback instead of discarding the span as arithmetic data.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '((git push origin main) 2>/dev/null)')"
assert_status "arithmetic-backtracked subshell with inner suppression blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '((git push origin main) ) 2>/dev/null')"
assert_status "arithmetic-backtracked subshell with outer suppression blocks" 2 "$STATUS"

# ...and the control: GENUINE arithmetic stays arithmetic — the fallback must
# not reintroduce the nested-paren over-block this rebuild removed. The
# suppressed push after it blocks on its own statement.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '((1+1)); git push origin main 2>/dev/null')"
assert_status "genuine arithmetic then suppressed push still blocks" 2 "$STATUS"

# RC5 (security lane, Medium): path-qualified invocation carries the mutation
# lexically, as a command, in the suppression's scope — the boundary items
# all share the property that the text is ABSENT or runtime-determined,
# which a path prefix is not. Base blocked both.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '/usr/bin/git push origin main 2>/dev/null')"
assert_status "absolute-path git invocation still blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" './git push origin main 2>/dev/null')"
assert_status "relative-path git invocation still blocks" 2 "$STATUS"

# RC6 (logic lane, Low): construct-header words (case subject, for word
# list) must have their substitutions walked like any other word — a
# mutation inside them is command text in the enclosing scope, not data.
# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'case $(git push origin main 2>/dev/null) in *) echo hi;; esac')"
assert_status "suppressed mutation in a case subject blocks" 2 "$STATUS"

# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'for x in $(git push origin main 2>/dev/null); do echo $x; done')"
assert_status "suppressed mutation in a for word list blocks" 2 "$STATUS"

# RC7 (logic lane, Low): clustered short flags — `-ec`, `-lc` — carry the
# same fully-literal -c payload; recursion must not require the exact word
# `-c`.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" "sh -ec 'git push origin main 2>/dev/null'")"
assert_status "clustered -ec flag payload recurses and blocks" 2 "$STATUS"

# RC8 (logic lane, Medium): non-blank leftover input after the parse must
# fail CLOSED (exit 3 -> hook exit 2), not silently permit everything after
# the point the parser stopped. Reached via a `)` inside a comment within
# $( … ): comment-blind paren scanning ends the substitution early, strands
# the real `)`, and the old tolerate-and-truncate policy never examined the
# suppressed push on the next line — valid, executing bash (probed).
# shellcheck disable=SC2016
trunc_cmd="$(printf 'X=$(echo hi # note )\n)\ngit push origin main 2>/dev/null')"
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" "$trunc_cmd")"
assert_status "comment-paren truncation fails closed on the trailing push" 2 "$STATUS"

# RC9 (security+logic+style lanes): quote/escape-split spellings of the
# prefilter's two conjuncts must still reach the tokenizer — the prefilter
# greps raw text while the tokenizer compares quote-removed values, so
# normalization must happen before the grep. All probed as genuine
# suppressed executions in real bash.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main 2>/dev/nul"l"')"
assert_status "quote-split null target still blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main 2>&"-"')"
assert_status "quote-split fd-close still blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git pu"sh" origin main 2>/dev/null')"
assert_status "quote-split mutation verb still blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main 2>& -')"
assert_status "spaced fd-close operand still blocks" 2 "$STATUS"

# RC10 (tests lane): `>&word` is the exact bash synonym of `&>word` (probed:
# genuinely silent), and the branch's own coherence principle — pinning one
# spelling while leaving its twin open is incoherent — applies verbatim.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main >&/dev/null')"
assert_status "legacy ampersand-redirect synonym blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main >& /dev/null')"
assert_status "spaced legacy ampersand-redirect synonym blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '{ git push origin main; } >&/dev/null')"
assert_status "legacy ampersand-redirect on a construct blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'exec >&/dev/null; git push origin main')"
assert_status "exec with the legacy ampersand-redirect blocks" 2 "$STATUS"

# ...and the discriminator: `>&2` is a NUMERIC fd dup (stdout onto stderr,
# both visible — probed), not the legacy file-redirect form. The `>&word`
# fix must key on the operand being a non-numeric word.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main >&2')"
assert_status "numeric fd dup via >&2 permits" 0 "$STATUS"

# RC11 (tests lane G1/G2): fd-relay suppression through a third descriptor —
# blocked by the tokenizer, failed open on base AND origin/main. Green pins
# recording the flip so the precision gain can never silently regress.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main 3>/dev/null 2>&3')"
assert_status "same-command fd relay to null blocks (recorded flip)" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'exec 3>/dev/null; git push origin main 2>&3')"
assert_status "exec-persisted fd relay to null blocks (recorded flip)" 2 "$STATUS"

# RC12 (logic lane, Low): `|&` pipes stderr INTO the pipeline — the implicit
# 2>&1 lands AFTER the command's own redirects, so a previously-nulled fd2
# is re-merged into a visible stream (zsh-probed: marker visible; local
# bash 3.2 cannot parse |&). The acceptance criterion names |&; these flips
# make the code and the criterion agree.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'git push origin main 2>/dev/null |& cat')"
assert_status "stderr re-merged into a visible pipe permits" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'exec 2>/dev/null; git push origin main |& cat')"
assert_status "exec-suppressed stderr re-merged by a pipe permits" 0 "$STATUS"

# RC13 (tests lane): nested-subshell exec — an UNENUMERATED behavior flip
# the review found by hand-probing (base blocked; the tokenizer correctly
# permits, since a subshell's exec never leaks to the parent — the N5
# principle one level deeper; probed: marker visible). Recorded here as a
# green pin so the flip is enumerated, not accidental.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '( ( exec 2>/dev/null ) ); git push origin main')"
assert_status "nested-subshell exec does not leak (recorded flip)" 0 "$STATUS"

# Tokenizer-level pins (tests lane): the hook's prefilter short-circuits
# shapes carrying no suppression-capable text, so their hook-level tests
# pass without python3 ever running and pin nothing about tokenizer
# semantics. These assert the tokenizer's own verdict directly (0 permit /
# 1 block), bypassing the hook and its prefilter.
TOKENIZER="$ROOT/dotfiles/.claude/hooks/guard-rule3-tokenizer.py"
assert_tokenizer() {
    local name="$1" expected="$2" payload="$3" actual
    printf '%s' "$payload" | python3 -S "$TOKENIZER" >/dev/null 2>&1
    actual=$?
    assert_status "$name" "$expected" "$actual"
}

assert_tokenizer "tokenizer: construct to a real file is not suppression" 0 \
    '{ git push origin main; } >push.log 2>&1'
assert_tokenizer "tokenizer: 2>&1 into a visible pipe is not suppression" 0 \
    'git push origin main 2>&1 | tee push.log'
assert_tokenizer "tokenizer: exec to a real file is not suppression" 0 \
    'exec 2>errors.log; git push origin main'
# shellcheck disable=SC2016
assert_tokenizer "tokenizer: variable redirect target permits" 0 \
    'git push origin main 2>"$LOGFILE"'
assert_tokenizer "tokenizer: real-file stdout-dup permits" 0 \
    'git push origin main >push.log 2>&1'

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
