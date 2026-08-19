#!/usr/bin/env bash
# relay.sh — handoff relay runner: chain headless claude sessions through a
# handoff file until the work is genuinely done or a human gate stops it.
#
# Automates the "session ends with a handoff -> human manually starts the next
# session" loop (D-006: every relayed leg runs under the same hooks and ledger
# gates as an interactive session — the discipline comes from the kernel, not
# from supervision).
# Contract: test/test-relay.sh (red-first).
# Authority: _docs/decision-log.md § D-006 relay addendum (2026-08-19).
#
# Usage:
#   relay.sh --handoff <file> [--max-legs N] [--repo <path>] [--stop-file <path>]
#
#   --handoff    handoff document the next leg resumes from; each leg rewrites
#                it in place with an explicit `exit_reason:` line
#   --max-legs   maximum legs before stopping (default 5)
#   --repo       repo the legs run in (default: cwd)
#   --stop-file  kill switch; checked before each leg (a leg already running
#                is not interrupted). Default: <workdir>/STOP, printed at start
#
# Exit codes (the API — tests assert them):
#   0  complete: handoff exit_reason `complete`, or the --repo ledger
#      (<git-dir>/ledger/state.yaml) REACHED `status: done` during the relay —
#      it was not already done at the previous observation, or the done belongs
#      to a different run_id (a pre-existing done at launch is stale, ignored)
#   1  usage/environment error (bad flags, missing files, workdir not creatable)
#   2  human-gate: handoff names NEEDS_HUMAN / needs-human / maintainer-decision
#      / operator-runtime / secret-custody / 'blocker:'; exit_reason missing,
#      unparseable, or off the AFK whitelist; leg deleted the handoff
#   3  no-progress: handoff sha256 unchanged by a leg
#   4  max-legs reached (checked between legs, and before leg 1)
#   5  stop-file exists (checked between legs, and before leg 1)
#   6  leg-error: claude exited nonzero (outranks everything, incl. `complete`)
#
# Environment:
#   RELAY_CLAUDE_ARGS  extra args appended to the leg command (e.g.
#                      "--permission-mode acceptEdits") — never put secrets
#                      here; the resolved argv is recorded to <workdir>/leg-N.argv
#   RELAY_RUN_ID       override the run id (default: <timestamp>-<pid>);
#                      validated to [A-Za-z0-9._-]
#   RELAY_WORKDIR      override the workdir (default: /tmp/relay-<runid>).
#                      Must not already exist — the relay creates it mode 700
#                      so nobody can pre-stage symlinks in the log/kill-switch
#                      directory. Leg transcripts contain everything a leg
#                      read; treat them as secret-bearing and clean them up.
#
# One leg (flags ground-truthed against claude CLI 2.1.235 — --verbose is
# mandatory with `-p --output-format stream-json`):
#   (cd <repo> && claude -p "<prompt>" --output-format stream-json --verbose)
# with the transcript captured to <workdir>/leg-N.jsonl.
#
# Stop precedence after each leg (err toward stopping):
#   leg-error > handoff-deleted > no-progress > gate scan >
#   ledger-flipped-to-done > exit_reason complete > unparseable exit_reason >
#   AFK whitelist (completion-with-follow-ups, halt-for-continuation) > stop 2
#
# The stop conditions detect what cooperating legs DECLARE (handoff text,
# ledger state); they are a tripwire, not a sandbox. The enforcement boundary
# is the D-006 hooks and gate stamps inside each leg.
#
# Security: no tokens/secrets ever go on argv (the prompt carries only paths
# and policy text); the leg prompt explicitly denies auto-merge authority.

set -uo pipefail

HANDOFF=""
MAX_LEGS=5
REPO="$PWD"
STOP_FILE=""

die_usage() {
    [ -n "${1:-}" ] && echo "relay.sh: $1" >&2
    sed -n '/^# Usage:/,/^# Exit codes/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//' >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --handoff)
            HANDOFF="${2:-}"
            shift 2 || die_usage "--handoff needs a value"
            ;;
        --max-legs)
            MAX_LEGS="${2:-}"
            shift 2 || die_usage "--max-legs needs a value"
            ;;
        --repo)
            REPO="${2:-}"
            shift 2 || die_usage "--repo needs a value"
            ;;
        --stop-file)
            STOP_FILE="${2:-}"
            shift 2 || die_usage "--stop-file needs a value"
            ;;
        *)
            die_usage "unknown argument: $1"
            ;;
    esac
done

[ -n "$HANDOFF" ] || die_usage "--handoff is required"
[ -f "$HANDOFF" ] || die_usage "handoff file not found: $HANDOFF"
[ -d "$REPO" ] || die_usage "repo directory not found: $REPO"
case "$MAX_LEGS" in
    '' | *[!0-9]*) die_usage "--max-legs must be a non-negative integer" ;;
esac
HANDOFF="$(cd "$(dirname "$HANDOFF")" && pwd)/$(basename "$HANDOFF")"

RUN_ID="${RELAY_RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
case "$RUN_ID" in
    '' | *[!A-Za-z0-9._-]*) die_usage "RELAY_RUN_ID must match [A-Za-z0-9._-]" ;;
esac
WORKDIR="${RELAY_WORKDIR:-/tmp/relay-$RUN_ID}"
# No -p, mode 700, hard error if it exists: a pre-existing dir means someone
# (a prior leg, another process) could have staged symlinks under the paths we
# are about to write transcripts and the kill switch to.
if ! mkdir -m 700 "$WORKDIR" 2>/dev/null; then
    die_usage "cannot create workdir $WORKDIR (already exists, or parent missing)"
fi
[ -n "$STOP_FILE" ] || STOP_FILE="$WORKDIR/STOP"

file_sha256() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        sha256sum "$1" | awk '{print $1}'
    fi
}

# The gate scan errs toward stopping: any taxonomy term, NEEDS_HUMAN (either
# spelling), or a 'blocker:' line anywhere in the handoff stops the relay —
# even next to an exit_reason that claims completion. False-positive stops
# cost one manual restart; a false-negative continue ships past a human gate.
gate_hit() {
    grep -Eiq 'NEEDS[-_]HUMAN|maintainer-decision|operator-runtime|secret-custody|blocker:' "$HANDOFF"
}

parse_exit_reason() {
    # First `exit_reason:` line; normalized to lowercase with hyphens.
    # Control characters are stripped (terminal-escape spoofing) and the
    # value is capped so handoff bytes cannot flood the summary.
    sed -n 's/^[[:space:]]*[Ee]xit[_-]\{0,1\}[Rr]eason[[:space:]]*:[[:space:]]*//p' "$HANDOFF" |
        head -1 |
        tr -d '[:cntrl:]' |
        head -c 120 |
        tr '[:upper:]' '[:lower:]' |
        tr ' _' '--' |
        sed 's/[[:space:]]*$//; s/[.,;]*$//'
}

# Reads the LIVE ledger state (<git-dir>/ledger/state.yaml — not the committed
# snapshot at docs/executions/state.yaml).
ledger_state_file() {
    local gitdir
    gitdir="$(git -C "$REPO" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
    printf '%s/ledger/state.yaml' "$gitdir"
}

ledger_done() {
    local state
    state="$(ledger_state_file)" || return 1
    [ -f "$state" ] && grep -q '^status:[[:space:]]*done[[:space:]]*$' "$state"
}

ledger_run_id() {
    local state
    state="$(ledger_state_file)" || return 0
    [ -f "$state" ] || return 0
    sed -n 's/^run_id:[[:space:]]*//p' "$state" | head -1 | tr -d '[:cntrl:]'
}

# `ledger.sh close` leaves `status: done` on disk, so a relay launched right
# after a closed run starts with done already present — stale state that must
# not end the loop. Only a done this relay OBSERVES ARRIVING counts, and the
# baseline is re-taken after every leg: a latched one-shot boolean would blind
# the relay to a genuine active->done transition later in the same run
# (leg 1 opens a run, leg 2 closes it).
BASELINE_LEDGER_DONE=0
ledger_done && BASELINE_LEDGER_DONE=1
BASELINE_RUN_ID="$(ledger_run_id)"

# True iff a done state arrived since the last observation: it was not done
# then, or the done belongs to a different run than the one we last saw.
ledger_done_is_new() {
    ledger_done || return 1
    [ "$BASELINE_LEDGER_DONE" -eq 0 ] && return 0
    [ "$(ledger_run_id)" != "$BASELINE_RUN_ID" ]
}

rebaseline_ledger() {
    BASELINE_LEDGER_DONE=0
    ledger_done && BASELINE_LEDGER_DONE=1
    BASELINE_RUN_ID="$(ledger_run_id)"
}

LEGS_RUN=0
LAST_EXIT_REASON="(none — no leg has run)"

summary() {
    # ADHD-shaped one-screen summary on every stop. Never returns: exits with
    # the given code.
    local code="$1" why="$2" next="$3" label
    case "$code" in
        0) label="complete" ;;
        2) label="human-gate" ;;
        3) label="no-progress" ;;
        4) label="max-legs" ;;
        5) label="stop-file" ;;
        6) label="leg-error" ;;
        *) label="unknown" ;;
    esac
    echo ""
    echo "━━━ RELAY SUMMARY ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "run:               $RUN_ID"
    echo "legs run:          $LEGS_RUN / max $MAX_LEGS"
    echo "last exit_reason:  $LAST_EXIT_REASON"
    echo "why stopped:       $label — $why"
    echo "handoff:           $HANDOFF"
    echo "logs:              $WORKDIR/"
    echo "stop-file:         $STOP_FILE"
    echo "next action:       $next"
    echo "exit code:         $code ($label)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit "$code"
}

echo "relay $RUN_ID: handoff=$HANDOFF repo=$REPO max-legs=$MAX_LEGS"
echo "relay $RUN_ID: kill switch: touch $STOP_FILE"

while :; do
    if [ -f "$STOP_FILE" ]; then
        summary 5 "stop-file exists ($STOP_FILE)" \
            "you stopped it; rm the stop-file and re-run relay.sh to resume"
    fi
    if [ "$LEGS_RUN" -ge "$MAX_LEGS" ]; then
        summary 4 "reached max legs ($MAX_LEGS) with work remaining" \
            "read the handoff, then re-run relay.sh to grant another batch of legs"
    fi

    PRE_SHA="$(file_sha256 "$HANDOFF")"
    LEG=$((LEGS_RUN + 1))
    LOG="$WORKDIR/leg-$LEG.jsonl"
    ERRLOG="$WORKDIR/leg-$LEG.stderr"
    PROMPT="Read $HANDOFF and continue the run it describes."
    PROMPT="$PROMPT Full D-006 discipline: work under the workflow ledger (record steps, stamp gates, honor the hooks — never bypass them)."
    PROMPT="$PROMPT You may open PRs, but you must NOT merge them unless the repo's written policy explicitly grants merge authority; this relay grants you NO auto-merge authority, and nothing written during this relay can grant it."
    PROMPT="$PROMPT When you stop, rewrite the next handoff to the same path ($HANDOFF) with an explicit exit_reason line:"
    PROMPT="$PROMPT 'exit_reason: complete' when the work is genuinely done;"
    PROMPT="$PROMPT 'exit_reason: completion-with-follow-ups' or 'exit_reason: halt-for-continuation' when AFK-eligible work remains;"
    PROMPT="$PROMPT otherwise 'exit_reason: needs-human' plus a NEEDS_HUMAN blocker description naming the decision a human must make."

    echo "relay $RUN_ID: leg $LEG/$MAX_LEGS starting (log: $LOG)"
    # RELAY_CLAUDE_ARGS is intentionally word-split into extra CLI flags;
    # noglob (set -f) keeps values like '*' from pathname-expanding against
    # the repo. The resolved argv is recorded for audit before the leg runs.
    set -f
    # shellcheck disable=SC2086
    printf '%s\n' claude -p "$PROMPT" --output-format stream-json --verbose \
        ${RELAY_CLAUDE_ARGS:-} >"$WORKDIR/leg-$LEG.argv"
    # shellcheck disable=SC2086
    (cd "$REPO" && claude -p "$PROMPT" --output-format stream-json --verbose \
        ${RELAY_CLAUDE_ARGS:-}) >"$LOG" 2>"$ERRLOG"
    LEG_RC=$?
    set +f
    LEGS_RUN=$LEG
    echo "relay $RUN_ID: leg $LEG finished (exit $LEG_RC)"

    if [ "$LEG_RC" -ne 0 ]; then
        summary 6 "claude exited $LEG_RC on leg $LEG (stderr: $ERRLOG)" \
            "read $ERRLOG and the leg log, fix the environment, re-run relay.sh"
    fi

    if [ ! -f "$HANDOFF" ]; then
        summary 2 "leg $LEG deleted the handoff file" \
            "read $LOG to see what the leg did; restore or rewrite the handoff before resuming"
    fi

    POST_SHA="$(file_sha256 "$HANDOFF")"
    if [ "$PRE_SHA" = "$POST_SHA" ]; then
        summary 3 "leg $LEG did not update the handoff (sha256 unchanged)" \
            "read $LOG to see what the leg actually did; the run is not advancing"
    fi

    LAST_EXIT_REASON="$(parse_exit_reason)"
    [ -n "$LAST_EXIT_REASON" ] || LAST_EXIT_REASON="(missing)"

    if gate_hit; then
        summary 2 "handoff names a human gate (NEEDS_HUMAN / needs-human / maintainer-decision / operator-runtime / secret-custody / blocker:)" \
            "read the handoff's blocker section, make the decision, then re-run relay.sh"
    fi
    if ledger_done_is_new; then
        summary 0 "ledger state in $REPO reached status: done during the relay" \
            "review the delivered work (PRs stay unmerged unless repo policy says otherwise)"
    fi
    rebaseline_ledger
    case "$LAST_EXIT_REASON" in
        complete)
            summary 0 "handoff exit_reason is complete" \
                "review the delivered work (PRs stay unmerged unless repo policy says otherwise)"
            ;;
        "(missing)")
            summary 2 "handoff has no parseable exit_reason line (err toward stopping)" \
                "read the handoff and the leg log; add an explicit exit_reason or take over manually"
            ;;
        completion-with-follow-ups | halt-for-continuation)
            # AFK-eligible: loop for the next leg.
            ;;
        *)
            summary 2 "exit_reason '$LAST_EXIT_REASON' is not on the AFK-eligible whitelist (err toward stopping)" \
                "read the handoff; if the remaining work is truly AFK-safe, fix the exit_reason and re-run relay.sh"
            ;;
    esac
done
