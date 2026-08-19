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

# Stub bin used by the fail-closed probe: an awk that always fails.
mkdir -p "$TMPDIR_BASE/broken-bin"
printf '#!/usr/bin/env bash\nexit 127\n' >"$TMPDIR_BASE/broken-bin/awk"
chmod +x "$TMPDIR_BASE/broken-bin/awk"

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

# Rule 3 is segment-scoped (R1/R2 batch #1, bit us twice live): suppression
# on a NON-mutating segment chained with a mutating one must pass; the block
# fires only when 2>/dev/null attaches to the mutating segment itself.
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
# loop, or conditional redirects everything inside it — lexical splitting must
# not file it under the closing token's segment. Fail closed: these fall back
# to whole-command semantics (the pre-batch behavior).
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

# A mutation INSIDE a substitution is still judged in its own segment: the
# masking is used only to identify terminators, never to hide mutations.
# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $(git push origin main) 2>/dev/null')"
assert_status "mutation inside a substitution stays blocked" 2 "$STATUS"

# Negative coverage for the fail-closed fallback boundary (tests lane R2):
# these benign compounds are DELIBERATELY blocked — a group redirect cannot
# be attributed to one segment lexically, so the fallback errs toward
# blocking. Pinned so the choice is visible if anyone narrows it later.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '{ npm run lint; } 2>/dev/null && git push origin main')"
assert_status "benign brace group before a push blocks (fail-closed, pinned)" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'if true; then npm run lint; fi 2>/dev/null && git push origin main')"
assert_status "benign conditional before a push blocks (fail-closed, pinned)" 2 "$STATUS"

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

# `exec cmd 2>/dev/null` REPLACES the shell, so no later segment runs — the
# redirect-first requirement must exclude it rather than arm the whole command.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'exec mytool --flag 2>/dev/null && git push origin main')"
assert_status "exec replacing the shell does not arm" 0 "$STATUS"

# A bare exec redirect with no mutation anywhere stays permitted.
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'exec 2>/dev/null; npm run lint')"
assert_status "exec redirect without a mutation permits" 0 "$STATUS"

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

# Rule 3 must fail CLOSED if the masking helper breaks (security lane R2
# note): an empty mask previously emptied every segment and permitted.
OUT="$(cd "$plain_sup" && printf '%s' "$(json_bash_jq "$plain_sup" 'git push origin main 2>/dev/null')" |
    SKILLS_ROOT="$SKILLS_ROOT_REAL" LEDGER_ENTRY_ENFORCE="" \
        PATH="$TMPDIR_BASE/broken-bin:$PATH" bash "$GUARD" 2>&1)"
STATUS=$?
assert_status "broken awk fails closed (still blocks)" 2 "$STATUS"

# The terminator detector must accept ANY redirect after the terminator, not
# only 2>/&> — a construct suppressed via stdout-dup otherwise falls through
# the fallback and its internal separators split the mutation into a segment
# carrying no suppression of its own (security lane R2, second pass).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" '{ git push origin main; } >/dev/null 2>&1')"
assert_status "brace group suppressed via stdout-dup blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'for i in 1; do git push origin main; done >/dev/null 2>&1')"
assert_status "loop suppressed via stdout-dup blocks" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'if true; then git push origin main; fi >/dev/null 2>&1')"
assert_status "conditional suppressed via stdout-dup blocks" 2 "$STATUS"

# Widening the alternation must not make a PAREN-FREE arithmetic expansion a
# terminator. The masker's inner classes are [^()], so it collapses only
# substitutions and arithmetic containing no literal parens — the pins below
# fix the boundary so this one case is not read as general support.
# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $((1+2)) >/dev/null 2>&1 && git push origin main')"
assert_status "paren-free arithmetic expansion is not a terminator" 0 "$STATUS"

# Beyond that boundary the masker leaves parens standing and the fallback
# arms, blocking a benign command (tests lane R3). Every shape below is
# fail-closed and pinned so the limitation is visible rather than inferred
# from the happy case above. Provenance, corrected by the security lane in
# R5: under the `2>/dev/null` spelling these were blocked on main too, so
# that much is preserved behavior — but main never recognized
# `>/dev/null 2>&1`, so the stdout-dup variants are NEW false positives
# introduced by this batch, not inherited ones.
# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $(( (1+2)*3 )) 2>/dev/null && git push origin main')"
assert_status "nested-paren arithmetic blocks (fail-closed, pinned)" 2 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'diff <(echo a) <(echo b) 2>/dev/null && git push origin main')"
assert_status "process substitution blocks (fail-closed, pinned)" 2 "$STATUS"

# shellcheck disable=SC2016
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo $(grep "x)y" f) 2>/dev/null && git push origin main')"
assert_status "paren inside a quoted substitution arg blocks (fail-closed, pinned)" 2 "$STATUS"

# ...whereas a quoted paren NOT inside a substitution never arms: its closing
# quote sits between the paren and the redirect (style lane R5 counterexample,
# pinned so the two shapes are not conflated again).
run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'echo "a)" 2>/dev/null && git push origin main')"
assert_status "bare quoted paren does not arm the fallback" 0 "$STATUS"

run_hook "$plain_sup" "$(json_bash_jq "$plain_sup" 'xs=(a b) 2>/dev/null; git push origin main')"
assert_status "array assignment blocks (fail-closed, pinned)" 2 "$STATUS"

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
