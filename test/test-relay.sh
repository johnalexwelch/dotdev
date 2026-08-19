#!/usr/bin/env bash
set -uo pipefail

# Red-first suite for the handoff relay runner
# (dotfiles/.config/agents/skills/workflow-ledger/scripts/relay.sh).
#
# Contract the implementer must honor:
#   - relay.sh --handoff <file> [--max-legs N=5] [--repo <path>] [--stop-file <path>]
#   - One leg = `claude -p "<prompt>" --output-format stream-json --verbose`
#     run from --repo; the leg prompt names the handoff path, demands full
#     D-006 discipline, an explicit exit_reason in the rewritten handoff,
#     and states the leg has NO auto-merge authority ("must NOT merge").
#   - Distinct exit codes: 0 complete, 2 human-gate, 3 no-progress,
#     4 max-legs, 5 stop-file, 6 leg-error; 1 usage error.
#   - Stop-precedence per leg result: leg-error > no-progress > gate scan
#     (NEEDS_HUMAN / maintainer-decision / operator-runtime / secret-custody
#     / 'blocker:', case-insensitive) > ledger-status-done > exit_reason
#     complete > unparseable exit_reason (stop 2) > AFK-eligible whitelist
#     (completion-with-follow-ups, halt-for-continuation) > stop 2.
#     Err toward stopping: complete + 'blocker:' text = exit 2, not 0.
#   - Stop-file and max-legs are checked between legs (and before leg 1).
#   - Ledger-done reads `<git-dir>/ledger/state.yaml` `status: done` in --repo.
#   - Zero real API calls: `claude` is a PATH stub in every test.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELAY="$ROOT/dotfiles/.config/agents/skills/workflow-ledger/scripts/relay.sh"
TMPDIR_BASE=$(mktemp -d)
PASS=0
FAIL=0
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

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    expected '$expected', got '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local name="$1" haystack="$2" needle="$3"
    if grep -qF -- "$needle" <<<"$haystack"; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    output does not contain '$needle'"
        FAIL=$((FAIL + 1))
    fi
}

# --- claude stub -------------------------------------------------------------
# Scripted per test case: on invocation N it copies $CASE_DIR/leg-N.handoff
# over $RELAY_TEST_HANDOFF (if the file exists), records argv to
# $CASE_DIR/argv-N, runs $CASE_DIR/leg-N.hook (if present), and exits with
# the contents of $CASE_DIR/leg-N.exit (default 0). Never calls any API.
STUB_BIN="$TMPDIR_BASE/bin"
mkdir -p "$STUB_BIN"
cat >"$STUB_BIN/claude" <<'STUB'
#!/usr/bin/env bash
set -u
n_file="$CASE_DIR/invocations"
n=$(( $(cat "$n_file" 2>/dev/null || echo 0) + 1 ))
echo "$n" >"$n_file"
printf '%s\n' "$@" >"$CASE_DIR/argv-$n"
if [ -f "$CASE_DIR/leg-$n.handoff" ]; then
    cp "$CASE_DIR/leg-$n.handoff" "$RELAY_TEST_HANDOFF"
fi
if [ -f "$CASE_DIR/leg-$n.hook" ]; then
    bash "$CASE_DIR/leg-$n.hook"
fi
if [ -f "$CASE_DIR/leg-$n.exit" ]; then
    exit "$(cat "$CASE_DIR/leg-$n.exit")"
fi
exit 0
STUB
chmod +x "$STUB_BIN/claude"
export PATH="$STUB_BIN:$PATH"

CASE_N=0
new_case() {
    CASE_N=$((CASE_N + 1))
    CASE_DIR="$TMPDIR_BASE/case-$CASE_N"
    mkdir -p "$CASE_DIR"
    export CASE_DIR
    HANDOFF="$CASE_DIR/handoff.md"
    export RELAY_TEST_HANDOFF="$HANDOFF"
    REPO="$CASE_DIR/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q
}

seed_handoff() {
    cat >"$HANDOFF" <<EOF
# Handoff — relay test seed

exit_reason: halt-for-continuation

## Next steps
1. keep going
EOF
}

leg_writes() {
    # leg_writes <n> <exit_reason> [extra body line]
    local n="$1" reason="$2" extra="${3:-}"
    cat >"$CASE_DIR/leg-$n.handoff" <<EOF
# Handoff — relay test leg $n

exit_reason: $reason

## Body
leg $n was here
$extra
EOF
}

run_relay() {
    OUT="$(bash "$RELAY" "$@" 2>&1)"
    STATUS=$?
}

invocations() {
    cat "$CASE_DIR/invocations" 2>/dev/null || echo 0
}

echo "== relay: usage =="

new_case
run_relay
assert_status "no args is a usage error (exit 1)" 1 "$STATUS"

new_case
run_relay --handoff "$CASE_DIR/does-not-exist.md" --repo "$REPO"
assert_status "missing handoff file is a usage error (exit 1)" 1 "$STATUS"
assert_eq "missing handoff runs zero legs" 0 "$(invocations)"

echo "== relay: complete stops with exit 0 =="

new_case
seed_handoff
leg_writes 1 complete
run_relay --handoff "$HANDOFF" --repo "$REPO"
assert_status "exit_reason complete stops with 0" 0 "$STATUS"
assert_eq "complete after exactly one leg" 1 "$(invocations)"
assert_contains "summary names the exit reason" "$OUT" "complete"

echo "== relay: leg invocation contract =="

new_case
seed_handoff
leg_writes 1 complete
run_relay --handoff "$HANDOFF" --repo "$REPO"
argv="$(cat "$CASE_DIR/argv-1")"
assert_contains "leg passes -p" "$argv" "-p"
assert_contains "leg passes --output-format stream-json" "$argv" "stream-json"
assert_contains "leg passes --verbose (mandatory with stream-json)" "$argv" "--verbose"
assert_contains "leg prompt names the handoff path" "$argv" "$HANDOFF"
assert_contains "leg prompt demands D-006 discipline" "$argv" "D-006"
assert_contains "leg prompt demands an explicit exit_reason" "$argv" "exit_reason"
assert_contains "leg prompt denies auto-merge authority" "$argv" "must NOT merge"
assert_contains "summary prints the per-leg log path" "$OUT" "leg-1"

echo "== relay: human-gate stops with exit 2 =="

for term in "NEEDS_HUMAN" "maintainer-decision" "operator-runtime" "secret-custody" "blocker: pick strategy A or B"; do
    new_case
    seed_handoff
    leg_writes 1 halt-for-continuation "gate note: $term"
    run_relay --handoff "$HANDOFF" --repo "$REPO"
    assert_status "handoff naming '$term' stops with 2" 2 "$STATUS"
    assert_eq "gate '$term' stops after one leg" 1 "$(invocations)"
done

new_case
seed_handoff
cat >"$CASE_DIR/leg-1.handoff" <<'EOF'
# Handoff — no exit reason at all
## Body
the leg forgot the contract
EOF
run_relay --handoff "$HANDOFF" --repo "$REPO"
assert_status "missing exit_reason is unparseable -> stop 2" 2 "$STATUS"

new_case
seed_handoff
leg_writes 1 "something-novel-and-unknown"
run_relay --handoff "$HANDOFF" --repo "$REPO"
assert_status "unknown exit_reason is not AFK-eligible -> stop 2" 2 "$STATUS"

new_case
seed_handoff
leg_writes 1 complete "blocker: unresolved decision lurking"
run_relay --handoff "$HANDOFF" --repo "$REPO"
assert_status "complete + 'blocker:' errs toward stopping -> 2, not 0" 2 "$STATUS"

echo "== relay: continue whitelist =="

new_case
seed_handoff
leg_writes 1 completion-with-follow-ups "follow-ups are reviewer-validation only"
leg_writes 2 complete
run_relay --handoff "$HANDOFF" --repo "$REPO"
assert_status "completion-with-follow-ups continues, then complete -> 0" 0 "$STATUS"
assert_eq "whitelist run used two legs" 2 "$(invocations)"

new_case
seed_handoff
leg_writes 1 halt-for-continuation
leg_writes 2 complete
run_relay --handoff "$HANDOFF" --repo "$REPO"
assert_status "halt-for-continuation continues, then complete -> 0" 0 "$STATUS"
assert_eq "halt-for-continuation run used two legs" 2 "$(invocations)"

echo "== relay: no-progress guard =="

new_case
seed_handoff
# no leg-1.handoff: the stub leaves the handoff untouched
run_relay --handoff "$HANDOFF" --repo "$REPO"
assert_status "unchanged handoff between legs stops with 3" 3 "$STATUS"
assert_eq "no-progress stops after one leg" 1 "$(invocations)"

echo "== relay: max-legs =="

new_case
seed_handoff
leg_writes 1 halt-for-continuation
leg_writes 2 halt-for-continuation
leg_writes 3 halt-for-continuation
run_relay --handoff "$HANDOFF" --repo "$REPO" --max-legs 2
assert_status "max-legs reached stops with 4" 4 "$STATUS"
assert_eq "max-legs 2 runs exactly two legs" 2 "$(invocations)"

echo "== relay: stop-file kill switch =="

new_case
seed_handoff
touch "$CASE_DIR/STOP"
run_relay --handoff "$HANDOFF" --repo "$REPO" --stop-file "$CASE_DIR/STOP"
assert_status "pre-existing stop-file stops with 5" 5 "$STATUS"
assert_eq "pre-existing stop-file runs zero legs" 0 "$(invocations)"

new_case
seed_handoff
leg_writes 1 halt-for-continuation
cat >"$CASE_DIR/leg-1.hook" <<EOF
touch "$CASE_DIR/STOP"
EOF
run_relay --handoff "$HANDOFF" --repo "$REPO" --stop-file "$CASE_DIR/STOP"
assert_status "stop-file appearing between legs stops with 5" 5 "$STATUS"
assert_eq "between-legs stop-file stops after one leg" 1 "$(invocations)"

echo "== relay: leg error =="

new_case
seed_handoff
leg_writes 1 halt-for-continuation
echo 1 >"$CASE_DIR/leg-1.exit"
run_relay --handoff "$HANDOFF" --repo "$REPO"
assert_status "claude exiting nonzero stops with 6" 6 "$STATUS"

echo "== relay: ledger-done stop =="

new_case
seed_handoff
leg_writes 1 halt-for-continuation
gitdir="$(git -C "$REPO" rev-parse --absolute-git-dir)"
mkdir -p "$gitdir/ledger"
cat >"$gitdir/ledger/state.yaml" <<'EOF'
run_id: relay-test
status: done
EOF
run_relay --handoff "$HANDOFF" --repo "$REPO"
assert_status "ledger status done stops with 0" 0 "$STATUS"
assert_eq "ledger-done stops after one leg" 1 "$(invocations)"

new_case
seed_handoff
leg_writes 1 halt-for-continuation "gate note: NEEDS_HUMAN"
gitdir="$(git -C "$REPO" rev-parse --absolute-git-dir)"
mkdir -p "$gitdir/ledger"
cat >"$gitdir/ledger/state.yaml" <<'EOF'
run_id: relay-test
status: done
EOF
run_relay --handoff "$HANDOFF" --repo "$REPO"
assert_status "gate scan outranks ledger-done (err toward stopping)" 2 "$STATUS"

echo "== relay: summary shape =="

new_case
seed_handoff
leg_writes 1 halt-for-continuation "gate note: NEEDS_HUMAN"
run_relay --handoff "$HANDOFF" --repo "$REPO"
assert_contains "summary reports legs run" "$OUT" "legs run"
assert_contains "summary reports why it stopped" "$OUT" "human-gate"
assert_contains "summary reports a next action" "$OUT" "next action"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
