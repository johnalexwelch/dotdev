#!/usr/bin/env bash
# ledger.sh — workflow-ledger kernel CLI (D-006 Phase 0).
#
# Moves workflow enforcement from prose the model complies with to a script
# the model cannot silently bypass. Live state lives in the git-dir (survives
# reset --hard, naturally per-worktree); stamp/init/close also write a
# committed snapshot at docs/executions/state.yaml for the PR-visible record.
#
# Spec: docs/executions/plans/2026-08-19-workflow-ledger-spec.md
# Authority: _docs/decision-log.md § D-006 (+ addenda).
#
# Usage:
#   ledger.sh init <run_id> --workflow <w> --kind <k> --steps <csv> [--budget <b>] [--force]
#   ledger.sh set <step> <status> [--evidence "..."] [--reason "..."]
#   ledger.sh stamp <gate> [--attest k=v ...] [--override --reason "..."] [--human] [--gate-type <t>]
#   ledger.sh check <gate>
#   ledger.sh check-snapshot <gate>   (CI mode: committed snapshot, no live state)
#   ledger.sh reconcile [--apply]
#   ledger.sh preflight --skill <name>
#   ledger.sh review-floor [--base <ref>]
#   ledger.sh verify-local
#   ledger.sh show
#   ledger.sh close
#
# Exit codes (the API — tests assert them):
#   0  success / check passed
#   1  check failed (MISSING|STALE), reconcile drift, preflight missing tool,
#      verify-local command failure, usage errors
#   2  stamp refused: one or more checked fields failed
#   3  set refused: required step cannot be skipped
#   4  set refused: terminal status without evidence/reason; override without --reason
#   5  unknown step / unknown skill / unknown gate
#   6  corrupt or schema-invalid state (never silently rewritten)
#   7  init refused: an active run already exists (use --force)
#   8  stamp refused: non-reviewer-validation gate type without --human
#   9  verify-local: no docs/executions/ci-commands.yaml manifest (NO_MANIFEST)
#  10  environment breakage (no python3 with PyYAML; misconfigured
#      LEDGER_PYTHON; not inside a git repo; git HEAD/snapshot-commit
#      failures) — distinct from gate-unmet 1 so hooks can warn-permit

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="${SKILLS_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
FORGE_SH="$SCRIPT_DIR/forge.sh"
BASELINE_SH="$SKILLS_ROOT/setup-worktree/scripts/worktree-baseline.sh"
SNAPSHOT_REL="docs/executions/state.yaml"

TOP=""
LIVE=""
SNAPSHOT=""
PYBIN=""
FAILURES=""
CHECKED=()

die() {
    local code="$1"
    shift
    echo "Error: $*" >&2
    exit "$code"
}

usage() {
    sed -n '/^# Usage:/,/^# Exit codes/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
    exit 1
}

require_repo() {
    TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || die 10 "not inside a git repository"
    local gitdir
    gitdir="$(git rev-parse --absolute-git-dir 2>/dev/null)" || die 10 "cannot resolve the git dir"
    LIVE="$gitdir/ledger/state.yaml"
    SNAPSHOT="$TOP/$SNAPSHOT_REL"
}

# The default `python3` on some machines (mise/pyenv shims, brew) lacks PyYAML;
# probe for one that can import yaml instead of failing at first use.
# Environment breakage is exit 10 — distinct from gate-unmet exit 1 so the
# merge-gate hook warn-permits instead of blocking (batch #2). An explicit
# LEDGER_PYTHON is honored strictly: if it is set but unusable that is a
# config error (exit 10), never a silent fallback.
resolve_python() {
    local cand
    if [ -n "${LEDGER_PYTHON:-}" ]; then
        if command -v "$LEDGER_PYTHON" >/dev/null 2>&1 &&
            "$LEDGER_PYTHON" -c 'import yaml' >/dev/null 2>&1; then
            PYBIN="$LEDGER_PYTHON"
            return 0
        fi
        die 10 "LEDGER_PYTHON ($LEDGER_PYTHON) is not a python3 with PyYAML"
    fi
    for cand in python3 /usr/bin/python3 /opt/homebrew/bin/python3; do
        command -v "$cand" >/dev/null 2>&1 || continue
        if "$cand" -c 'import yaml' >/dev/null 2>&1; then
            PYBIN="$cand"
            return 0
        fi
    done
    die 10 "no python3 with PyYAML found (set LEDGER_PYTHON to one that has it)"
}

# Single python state engine: all YAML reads/writes/validation go through it so
# a corrupt or schema-invalid document is exit 6 and never silently rewritten.
PYPROG=$(
    cat <<'PYEOF'
import os
import re
import sys
from datetime import datetime, timezone

import yaml

LIVE = os.environ.get("LEDGER_LIVE", "")

# Secret shapes redacted from script-captured output before it is stored
# (batch #4). Checked values only — attested values like repro_cmd must stay
# verbatim because the fix gate re-executes them.
REDACT_PATTERNS = [
    re.compile(r"\b(?:gh[pousr]|github_pat)_[A-Za-z0-9_]{8,}"),
    re.compile(r"\bsk-[A-Za-z0-9_-]{16,}"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{8,}"),
    re.compile(r"\bglpat-[A-Za-z0-9_-]{8,}"),
    re.compile(r"-----BEGIN[A-Z ]*PRIVATE KEY-----"),
    re.compile(r"(authorization:?\s+(?:token|bearer)\s+)\S+", re.IGNORECASE),
    re.compile(r"\b((?:api[_-]?key|token|secret|password|passwd)\s*[=:]\s*)\S+", re.IGNORECASE),
]

# The committed snapshot caps the repro_tail field at this many chars;
# the full (redacted) tail lives only in git-dir live state (batch #4).
SNAPSHOT_TAIL_CAP = 64


def redact(text):
    if not isinstance(text, str):
        return text
    for pattern in REDACT_PATTERNS:
        if pattern.groups:
            text = pattern.sub(lambda m: m.group(1) + "[REDACTED]", text)
        else:
            text = pattern.sub("[REDACTED]", text)
    return text


# Snapshot view: truncate the repro_tail field (in place); returns doc.
# Defensive on shape: also applied to untrusted committed snapshots during
# snapshot_match, which may be arbitrarily malformed.
def cap_tails(doc):
    stamps = doc.get("stamps") or {}
    if not isinstance(stamps, dict):
        return doc
    for stamp in stamps.values():
        if not isinstance(stamp, dict):
            continue
        checked = stamp.get("checked") or {}
        if not isinstance(checked, dict):
            continue
        tail = checked.get("repro_tail")
        if isinstance(tail, str) and len(tail) > SNAPSHOT_TAIL_CAP:
            checked["repro_tail"] = tail[:SNAPSHOT_TAIL_CAP] + "...[truncated]"
    return doc

KINDS = {"feature", "bug", "phase", "docs", "skill"}
BUDGETS = {"direct", "one-reviewer", "multi-lane", "team"}
RUN_STATUSES = {"active", "paused", "done"}
STEP_STATUSES = {"pending", "active", "completed", "skipped", "blocked", "failed"}
TERMINAL = {"completed", "skipped", "blocked", "failed"}
GATES = {"diagnose", "fix", "review", "finalize"}
GATE_TYPES = {
    "reviewer-validation",
    "maintainer-decision",
    "operator-runtime",
    "secret-custody",
}


def now():
    return datetime.now(timezone.utc).isoformat()


def err(code, msg):
    print("Error: " + msg, file=sys.stderr)
    sys.exit(code)


def validate(doc):
    if not isinstance(doc, dict):
        raise ValueError("state is not a mapping")
    for key in ("run_id", "workflow", "kind", "budget", "status", "next", "updated", "steps"):
        if key not in doc:
            raise ValueError("missing key: " + key)
    if doc["kind"] not in KINDS:
        raise ValueError("bad kind: %r" % (doc["kind"],))
    if doc["budget"] not in BUDGETS:
        raise ValueError("bad budget: %r" % (doc["budget"],))
    if doc["status"] not in RUN_STATUSES:
        raise ValueError("bad run status: %r" % (doc["status"],))
    if not isinstance(doc["steps"], list):
        raise ValueError("steps must be a list")
    for step in doc["steps"]:
        if not isinstance(step, dict) or not step.get("id"):
            raise ValueError("bad step entry")
        if step.get("status") not in STEP_STATUSES:
            raise ValueError("bad step status: %r" % (step.get("status"),))
        if not isinstance(step.get("required"), bool):
            raise ValueError("step 'required' must be a bool")
    stamps = doc.get("stamps") or {}
    if not isinstance(stamps, dict):
        raise ValueError("stamps must be a mapping")
    for gate, stamp in stamps.items():
        if gate not in GATES:
            raise ValueError("bad gate: %r" % (gate,))
        if not isinstance(stamp, dict) or not stamp.get("head_sha"):
            raise ValueError("bad stamp for gate %r" % (gate,))
        if stamp.get("gate_type") not in GATE_TYPES:
            raise ValueError("bad gate_type on %r" % (gate,))
        if stamp.get("provenance") not in {"agent", "human"}:
            raise ValueError("bad provenance on %r" % (gate,))
    if not isinstance(doc.get("overrides", []), list):
        raise ValueError("overrides must be a list")


def load():
    if not os.path.exists(LIVE):
        err(1, "no live ledger state at %s (run ledger.sh init)" % LIVE)
    try:
        with open(LIVE) as fh:
            doc = yaml.safe_load(fh)
    except yaml.YAMLError as exc:
        err(6, "live state is not valid YAML (refusing to touch it): %s" % exc)
    try:
        validate(doc)
    except ValueError as exc:
        err(6, "live state failed schema validation (refusing to touch it): %s" % exc)
    return doc


def save(doc):
    doc["updated"] = now()
    try:
        validate(doc)
    except ValueError as exc:
        err(6, "refusing write: resulting state would be schema-invalid: %s" % exc)
    os.makedirs(os.path.dirname(LIVE), exist_ok=True)
    tmp = LIVE + ".tmp"
    with open(tmp, "w") as fh:
        yaml.safe_dump(doc, fh, sort_keys=False, default_flow_style=False, width=4096)
    os.replace(tmp, LIVE)


def split_kv(items):
    out = {}
    for item in items:
        if "=" not in item:
            err(4, "expected key=value, got: %r" % (item,))
        key, _, val = item.partition("=")
        out[key] = val
    return out


def op_init(argv):
    run_id, workflow, kind, steps_csv, budget, force = argv
    force = force == "1"
    prior_note = ""
    if os.path.exists(LIVE):
        old = None
        try:
            with open(LIVE) as fh:
                old = yaml.safe_load(fh)
            validate(old)
        except (yaml.YAMLError, ValueError):
            old = None
            if not force:
                err(6, "existing live state is corrupt; refusing to overwrite without --force")
            prior_note = "corrupt prior state"
        if old is not None:
            if old.get("status") == "active" and not force:
                err(7, "active run %r already exists; re-init refused (use --force)" % old.get("run_id"))
            prior_note = "prior run %s" % old.get("run_id")
    if kind not in KINDS:
        err(6, "invalid kind: %r" % (kind,))
    if budget not in BUDGETS:
        err(6, "invalid budget: %r" % (budget,))
    step_ids = [s.strip() for s in steps_csv.split(",") if s.strip()]
    if kind == "bug":
        # bug runs cannot skip diagnosis: auto-insert required diagnose/fix.
        for required_step in ("fix", "diagnose"):
            if required_step not in step_ids:
                step_ids.insert(0, required_step)
    overrides = []
    if force and prior_note:
        overrides.append(
            {
                "action": "force-init",
                "reason": "--force re-init over %s" % prior_note,
                "timestamp": now(),
            }
        )
    doc = {
        "run_id": run_id,
        "workflow": workflow,
        "kind": kind,
        "budget": budget,
        # Unix epoch of init: lane files older than this are stale artifacts
        # from an earlier session and cannot satisfy `stamp review` (batch #3).
        "initialized_epoch": int(datetime.now(timezone.utc).timestamp()),
        "status": "active",
        "next": step_ids[0] if step_ids else "",
        "updated": now(),
        "steps": [
            {"id": sid, "required": True, "status": "pending", "evidence": ""}
            for sid in step_ids
        ],
        "stamps": {},
        "overrides": overrides,
    }
    save(doc)


def op_set(argv):
    step_id, status, evidence, reason = argv
    doc = load()
    step = next((s for s in doc["steps"] if s["id"] == step_id), None)
    if step is None:
        err(5, "unknown step: %r" % (step_id,))
    if status not in STEP_STATUSES:
        err(6, "invalid step status: %r" % (status,))
    if status == "skipped" and step.get("required"):
        err(3, "step %r is required and cannot be set to that status" % (step_id,))
    if status in TERMINAL and not (evidence or reason):
        err(4, "terminal statuses require --evidence or --reason")
    step["status"] = status
    if evidence or reason:
        step["evidence"] = evidence or reason
    if doc.get("next") == step_id and status in TERMINAL:
        remaining = [s["id"] for s in doc["steps"] if s["status"] == "pending" or s["status"] == "active"]
        doc["next"] = remaining[0] if remaining else ""
    save(doc)


def op_get(argv):
    doc = load()
    print(doc.get(argv[0], "") or "")


def op_set_meta(argv):
    key, value = argv
    doc = load()
    doc[key] = value
    save(doc)


def op_check_info(argv):
    doc = load()
    stamp = (doc.get("stamps") or {}).get(argv[0])
    if not stamp:
        print("exists=0")
        return
    override = stamp.get("override") or {}
    print("exists=1")
    # head_sha is untrusted snapshot text too — same newline escape as the
    # reason below (a multi-line sha then fails cat-file → STALE, fail-closed,
    # without emitting extra key=value lines).
    print("head_sha=" + str(stamp.get("head_sha", "")).replace("\n", "\\n"))
    print("override=" + ("1" if override.get("active") else "0"))
    # The reason is untrusted snapshot text: escape newlines so it can never
    # emit extra key=value lines or a second verdict-shaped output line
    # (Phase 5a review R2, security M2 defence-in-depth).
    print("reason=" + str(override.get("reason", "")).replace("\n", "\\n"))


def op_diagnose_repro(argv):
    doc = load()
    stamp = (doc.get("stamps") or {}).get("diagnose")
    if not stamp:
        sys.exit(1)
    cmd = (stamp.get("attested") or {}).get("repro_cmd", "")
    if not cmd:
        sys.exit(1)
    print(cmd)


def op_write_stamp(argv):
    gate, head, gate_type, provenance, override, reason = argv[:6]
    attested, checked = [], []
    bucket = None
    for item in argv[6:]:
        if item == "--attest":
            bucket = attested
            continue
        if item == "--checked":
            bucket = checked
            continue
        if bucket is None:
            err(4, "unexpected stamp argument: %r" % (item,))
        bucket.append(item)
    doc = load()
    is_override = override == "1"
    stamp = {
        "head_sha": head,
        "timestamp": now(),
        "gate_type": gate_type,
        "provenance": provenance,
        # Checked values are script-captured output — redact secret shapes
        # before anything is stored (batch #4). Attested values stay verbatim
        # (the fix gate re-executes the attested repro_cmd).
        "checked": {k: redact(v) for k, v in split_kv(checked).items()},
        "attested": split_kv(attested),
        "override": {
            "active": is_override,
            "reason": reason if is_override else "",
            "timestamp": now() if is_override else "",
        },
    }
    doc.setdefault("stamps", {})[gate] = stamp
    if is_override:
        doc.setdefault("overrides", []).append(
            {"gate": gate, "reason": reason, "timestamp": now(), "head_sha": head}
        )
    save(doc)


def op_record_verify(argv):
    head, passed = argv[0], argv[1]
    rest = argv[2:]
    results = []
    for i in range(0, len(rest) - 1, 2):
        results.append({"cmd": rest[i + 1], "exit": int(rest[i])})
    doc = load()
    doc["verify_local"] = {"head_sha": head, "passed": passed == "1", "results": results}
    save(doc)


def op_verify_info(argv):
    doc = load()
    info = doc.get("verify_local") or {}
    print("head_sha=" + str(info.get("head_sha", "")))
    print("passed=" + ("1" if info.get("passed") else "0"))


def op_reconcile_apply(argv):
    doc = load()
    remaining = [s["id"] for s in doc["steps"] if s["status"] not in TERMINAL]
    doc["next"] = remaining[0] if remaining else ""
    save(doc)
    print(doc["next"])


def op_close(argv):
    doc = load()
    doc["status"] = "done"
    doc["next"] = ""
    save(doc)
    print(doc["run_id"])


def op_show(argv):
    doc = load()
    print("run_id:   %s" % doc["run_id"])
    print("workflow: %s  kind: %s  budget: %s" % (doc["workflow"], doc["kind"], doc["budget"]))
    print("status:   %s  next: %s" % (doc["status"], doc.get("next") or "-"))
    print("")
    print("steps:")
    for step in doc["steps"]:
        print(
            "  %-20s required=%-5s %-10s %s"
            % (step["id"], str(step["required"]).lower(), step["status"], step.get("evidence") or "-")
        )
    stamps = doc.get("stamps") or {}
    print("")
    print("stamps:")
    if not stamps:
        print("  (none)")
    for gate, stamp in stamps.items():
        override = " OVERRIDE" if (stamp.get("override") or {}).get("active") else ""
        print(
            "  %-10s %-12s %s %s%s"
            % (
                gate,
                str(stamp.get("head_sha", ""))[:12],
                stamp.get("gate_type", ""),
                stamp.get("provenance", ""),
                override,
            )
        )


def op_snapshot_match(argv):
    # Compares the committed snapshot's DURABLE content (run identity, stamps,
    # overrides) against live state (batch #8). Steps and meta keys change
    # between snapshot commits legitimately; stamps/overrides only change via
    # ops that immediately re-commit the snapshot, so a mismatch means the
    # tracked file was rewritten out-of-band (a snapshot-only tamper commit is
    # freshness-exempt by design — this closes that hole). Prints 1 or 0.
    keys = ("run_id", "workflow", "kind", "budget", "stamps", "overrides")
    live = cap_tails(load())
    try:
        with open(argv[0]) as fh:
            snap = yaml.safe_load(fh)
    except (OSError, yaml.YAMLError):
        print("0")
        return
    if not isinstance(snap, dict):
        print("0")
        return
    # Normalize BOTH sides: pre-cap snapshots were byte-copies of live with
    # uncapped tails — benign version skew must not read as tampering
    # (logic lane, R1 should-fix).
    snap = cap_tails(snap)
    live_view = {k: live.get(k) for k in keys}
    snap_view = {k: snap.get(k) for k in keys}
    print("1" if live_view == snap_view else "0")


def op_write_snapshot(argv):
    # Snapshot = live state with repro_tail capped (batch #4): the full
    # redacted tail stays in git-dir live state; the tracked, PR-visible copy
    # carries at most SNAPSHOT_TAIL_CAP chars of it.
    doc = cap_tails(load())
    dest = argv[0]
    dest_dir = os.path.dirname(dest)
    if dest_dir:
        os.makedirs(dest_dir, exist_ok=True)
    tmp = dest + ".tmp"
    with open(tmp, "w") as fh:
        yaml.safe_dump(doc, fh, sort_keys=False, default_flow_style=False, width=4096)
    os.replace(tmp, dest)


def op_manifest(argv):
    try:
        with open(argv[0]) as fh:
            data = yaml.safe_load(fh)
    except (OSError, yaml.YAMLError) as exc:
        err(6, "ci-commands manifest unreadable: %s" % exc)
    if not isinstance(data, list) or not all(isinstance(c, str) and c for c in data):
        err(6, "ci-commands.yaml must be a top-level YAML list of command strings")
    for cmd in data:
        print(cmd)


HANDLERS = {
    "init": op_init,
    "set": op_set,
    "get": op_get,
    "set_meta": op_set_meta,
    "check_info": op_check_info,
    "diagnose_repro": op_diagnose_repro,
    "write_stamp": op_write_stamp,
    "record_verify": op_record_verify,
    "verify_info": op_verify_info,
    "reconcile_apply": op_reconcile_apply,
    "close": op_close,
    "show": op_show,
    "snapshot_match": op_snapshot_match,
    "write_snapshot": op_write_snapshot,
    "manifest": op_manifest,
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in HANDLERS:
        err(1, "unknown state-engine op")
    HANDLERS[sys.argv[1]](sys.argv[2:])


main()
PYEOF
)

py() {
    if [ -z "$PYBIN" ]; then
        resolve_python
    fi
    LEDGER_LIVE="$LIVE" "$PYBIN" -c "$PYPROG" "$@"
}

# ---- shared helpers --------------------------------------------------------

add_failure() {
    FAILURES="${FAILURES}  - $*"$'\n'
}

# Write the snapshot view of live state (repro_tail capped, batch #4)
# to the committed snapshot and commit it. A stamp's own snapshot commit must
# not make that stamp stale; the exemption is verified by commit CONTENTS
# (touches only the snapshot file), never by subject — a subject is
# attacker-controlled (review R1 MF1, D-006 #4).
commit_snapshot() {
    local action="$1" target="$2"
    mkdir -p "$(dirname "$SNAPSHOT")"
    py write_snapshot "$SNAPSHOT" || exit $?
    git -C "$TOP" add -- "$SNAPSHOT_REL" || die 10 "git add failed for $SNAPSHOT_REL"
    if ! git -C "$TOP" diff --quiet HEAD -- "$SNAPSHOT_REL" 2>/dev/null; then
        git -C "$TOP" commit -q -m "chore(ledger): $action $target" -- "$SNAPSHOT_REL" ||
            die 10 "snapshot commit failed"
    fi
    py set_meta last_seen_sha "$(git -C "$TOP" rev-parse HEAD)" || exit $?
}

# Fresh iff every commit after the recorded sha touches ONLY the snapshot
# file (verified by contents via diff-tree, never by subject — subjects are
# attacker-controlled). Also requires sha to be an ancestor of HEAD: a HEAD
# moved backwards (reset) must read STALE, not fresh.
fresh_since() {
    local sha="$1" commits c paths
    [ -n "$sha" ] || return 1
    git -C "$TOP" cat-file -e "${sha}^{commit}" 2>/dev/null || return 1
    git -C "$TOP" merge-base --is-ancestor "$sha" HEAD 2>/dev/null || return 1
    commits="$(git -C "$TOP" log --format=%H "${sha}..HEAD" 2>/dev/null)" || return 1
    [ -n "$commits" ] || return 0
    while IFS= read -r c; do
        paths="$(git -C "$TOP" diff-tree --no-commit-id --name-only -r "$c" 2>/dev/null)"
        [ "$paths" = "$SNAPSHOT_REL" ] || return 1
    done <<<"$commits"
    return 0
}

# Shared verdict shell for `check` (live state) and `check-snapshot`
# (committed snapshot, CI mode). One implementation of the MISSING/STALE/
# OVERRIDE_STALE/OVERRIDDEN/OK rendering so gate wording and logic cannot
# drift between the local and CI checks (Phase 5a review, style S3).
# mode=snapshot points the state engine at the committed snapshot (untrusted
# input — same schema validation, malformed = exit 6) and skips the
# live-vs-snapshot drift compare, which needs live state that CI lacks.
gate_verdict() {
    local gate="$1" mode="$2" info status c_exists c_sha c_override c_reason snap_ok missing_sha
    local LIVE="$LIVE"
    if [ "$mode" = "snapshot" ]; then
        if [ ! -f "$SNAPSHOT" ]; then
            echo "MISSING: no committed snapshot at $SNAPSHOT_REL"
            return 1
        fi
        LIVE="$SNAPSHOT"
    elif [ ! -f "$LIVE" ]; then
        echo "MISSING: no live ledger state (run ledger.sh init)"
        return 1
    fi
    info="$(py check_info "$gate")"
    status=$?
    [ "$status" -eq 0 ] || return "$status"
    c_exists="$(sed -n 's/^exists=//p' <<<"$info")"
    c_sha="$(sed -n 's/^head_sha=//p' <<<"$info")"
    c_override="$(sed -n 's/^override=//p' <<<"$info")"
    c_reason="$(sed -n 's/^reason=//p' <<<"$info")"
    if [ "$c_exists" != "1" ]; then
        if [ "$mode" = "snapshot" ]; then
            echo "MISSING: no '$gate' stamp in committed snapshot"
        else
            echo "MISSING: no '$gate' stamp"
        fi
        return 1
    fi
    if ! fresh_since "$c_sha"; then
        # Distinguish a sha absent from history (forged/foreign snapshot,
        # rewritten branch) from real post-stamp commits — "commits exist
        # after" would be a false diagnostic in a CI step summary. Checked
        # before rendering so the override path gets the honest wording too
        # (Phase 5a review R2, logic NSF1).
        missing_sha=0
        git -C "$TOP" cat-file -e "${c_sha}^{commit}" 2>/dev/null || missing_sha=1
        # A stale override is an expired authorization, not a gate that never
        # passed — say so, and carry the audited reason to the operator.
        if [ "$c_override" = "1" ]; then
            if [ "$missing_sha" = "1" ]; then
                echo "OVERRIDE_STALE: override on '$gate' expired — its stamp sha ($c_sha) not found in history; recorded reason: $c_reason"
            else
                echo "OVERRIDE_STALE: override on '$gate' expired — non-ledger commits exist after its stamp ($c_sha); recorded reason: $c_reason"
            fi
            return 1
        fi
        if [ "$missing_sha" = "1" ]; then
            echo "STALE: '$gate' stamp sha ($c_sha) not found in history"
            return 1
        fi
        echo "STALE: non-ledger commits exist after the '$gate' stamp ($c_sha)"
        return 1
    fi
    # A snapshot-only tamper commit AFTER the stamp is freshness-exempt by
    # design, so the finalize check re-compares the committed snapshot's
    # durable content here (security lane: the stamp-time check alone left
    # post-stamp rewrites invisible to the merge gate). Live mode only — on a
    # CI checkout there is no live ledger to drift against.
    if [ "$gate" = "finalize" ] && [ "$mode" = "live" ]; then
        snap_ok="$(py snapshot_match "$SNAPSHOT")" || snap_ok=""
        if [ "$snap_ok" != "1" ]; then
            echo "SNAPSHOT_DRIFT: committed $SNAPSHOT_REL no longer matches the live ledger (durable identity, stamps, overrides) — rewritten out-of-band after the stamp"
            return 1
        fi
    fi
    if [ "$c_override" = "1" ]; then
        echo "OVERRIDDEN: $c_reason"
        return 0
    fi
    if [ "$mode" = "snapshot" ]; then
        echo "OK: '$gate' snapshot stamp fresh at $c_sha"
    else
        echo "OK: '$gate' stamp fresh at $c_sha"
    fi
    return 0
}

check_gate() {
    gate_verdict "$1" live
}

attest_get() {
    local key="$1" kv
    shift
    for kv in "$@"; do
        case "$kv" in
            "$key="*)
                printf '%s' "${kv#*=}"
                return 0
                ;;
        esac
    done
    return 1
}

# Ranks the base profile word; a +security suffix (batch #7) is a flag,
# not a rank change, so it is stripped before ranking.
profile_rank() {
    case "${1%%+*}" in
        fast) echo 1 ;;
        standard) echo 2 ;;
        full) echo 3 ;;
        *) echo 0 ;;
    esac
}

# Rank by family substring so real ids (anthropic/claude-opus-4-5,
# claude-fable-5) rank correctly, not just bare aliases (R1 MF3).
model_rank() {
    case "$1" in
        *fable*) echo 4 ;;
        *opus*) echo 3 ;;
        *sonnet*) echo 2 ;;
        *haiku*) echo 1 ;;
        *) echo 0 ;;
    esac
}

required_lanes() {
    case "$1" in
        fast) echo "integrated" ;;
        standard) echo "logic tests" ;;
        full) echo "security logic tests style" ;;
        *) echo "integrated" ;;
    esac
}

# lanes attestation: comma-separated lane=path pairs; default /tmp/<lane>-review.md.
lane_path_for() {
    local lane="$1" spec="$2" pair
    if [ -n "$spec" ]; then
        while IFS= read -r pair; do
            case "$pair" in
                "$lane="*)
                    printf '%s' "${pair#*=}"
                    return 0
                    ;;
            esac
        done <<<"$(tr ',' '\n' <<<"$spec")"
    fi
    printf '/tmp/%s-review.md' "$lane"
}

file_sha256() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        sha256sum "$1" | awk '{print $1}'
    fi
}

# GNU order first: BSD `stat -c` fails cleanly (illegal option), while GNU
# `stat -f` is filesystem mode and can print a non-mtime value with exit 0
# (security lane). Callers must numeric-guard the output regardless.
file_mtime() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

tail_str() {
    printf '%s' "$1" | tail -c 200 | tr '\n' ' '
}

default_base() {
    local ref
    for ref in origin/staging \
        "$(git -C "$TOP" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)" \
        origin/main origin/master main master; do
        [ -n "$ref" ] || continue
        if git -C "$TOP" rev-parse --verify --quiet "${ref}^{commit}" >/dev/null 2>&1; then
            printf '%s' "$ref"
            return 0
        fi
    done
    return 1
}

review_patterns() {
    local override_file="$TOP/docs/executions/review-patterns.txt"
    if [ -f "$override_file" ]; then
        grep -Ev '^[[:space:]]*(#|$)' "$override_file" | paste -s -d '|' -
    else
        printf '%s' 'auth|secret|migration|infra|\.github/workflows'
    fi
}

# Deterministic: same diff (base...HEAD) always yields the same word. A
# path-pattern hit appends +security (batch #7): the flag rides the floor so
# stamp review can require a security lane instead of silently dropping it.
compute_floor() {
    local base="$1" numstat files=0 loc=0 added deleted path patterns hit=0 floor
    if [ -z "$base" ]; then
        base="$(default_base)" || die 1 "cannot resolve a default base ref; pass --base <ref>"
    fi
    git -C "$TOP" rev-parse --verify --quiet "${base}^{commit}" >/dev/null 2>&1 ||
        die 1 "base ref not found: $base"
    numstat="$(git -C "$TOP" diff --numstat "${base}...HEAD" 2>/dev/null)"
    if [ -n "$numstat" ]; then
        while read -r added deleted path; do
            [ -n "$path" ] || continue
            files=$((files + 1))
            case "$added" in '' | *[!0-9]*) ;; *) loc=$((loc + added)) ;; esac
            case "$deleted" in '' | *[!0-9]*) ;; *) loc=$((loc + deleted)) ;; esac
        done <<<"$numstat"
    fi
    patterns="$(review_patterns)"
    if [ -n "$patterns" ] &&
        git -C "$TOP" diff --name-only "${base}...HEAD" 2>/dev/null | grep -Eq "$patterns"; then
        hit=1
    fi
    if [ "$files" -gt 15 ] || [ "$loc" -gt 500 ]; then
        floor=full
    elif [ "$hit" -eq 1 ]; then
        floor=standard
    else
        floor=fast
    fi
    if [ "$hit" -eq 1 ]; then
        echo "${floor}+security"
    else
        echo "$floor"
    fi
}

# ---- checked-field runners (one per gate) ----------------------------------

checked_diagnose() {
    local repro out rc
    if ! repro="$(attest_get repro_cmd "$@")" || [ -z "$repro" ]; then
        add_failure "diagnose requires --attest repro_cmd=<command>"
        return
    fi
    out="$( (cd "$TOP" && bash -c "$repro") 2>&1)"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        add_failure "repro_cmd exited 0 — diagnose needs a red (non-zero) repro: $repro"
        return
    fi
    CHECKED+=("repro_exit=$rc")
    CHECKED+=("repro_tail=$(tail_str "$out")")
}

checked_fix() {
    local repro="" out rc="" regression=""
    if ! repro="$(py diagnose_repro 2>/dev/null)" || [ -z "$repro" ]; then
        add_failure "diagnose gate unmet: stamp diagnose (with repro_cmd) before stamp fix"
        return
    fi
    out="$( (cd "$TOP" && bash -c "$repro") 2>&1)"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        add_failure "stored repro_cmd still exits $rc — fix requires it green: $repro ($(tail_str "$out"))"
    fi
    if ! regression="$(attest_get regression_test "$@")" || [ -z "$regression" ]; then
        add_failure "fix requires --attest regression_test=<path>"
    elif [ ! -f "$TOP/$regression" ]; then
        add_failure "regression test file missing: $regression"
    fi
    CHECKED+=("repro_exit=$rc")
    CHECKED+=("regression_test=$regression")
}

checked_review() {
    local verify_out profile floor model_floor lanes_spec lane lane_file lane_model verdict
    local worktree_ok=1
    if ! verify_out="$(bash "$BASELINE_SH" verify --path "$TOP" 2>&1)"; then
        worktree_ok=0
        add_failure "worktree baseline verify failed: $verify_out"
    fi

    if ! profile="$(attest_get review_profile "$@")" || [ -z "$profile" ]; then
        add_failure "review requires --attest review_profile=<fast|standard|full>"
        return
    fi
    # The attested profile is exactly one of the three words (logic/security
    # lanes, R1 must-fix): a suffixed value like full+security would rank as
    # full via profile_rank's suffix strip while required_lanes fell through
    # to its single-lane default — silently collapsing the lane set.
    case "$profile" in
        fast | standard | full) ;;
        *)
            add_failure "attested review_profile must be exactly fast|standard|full (got '$profile')"
            return
            ;;
    esac
    if ! floor="$(compute_floor "" 2>/dev/null)"; then
        add_failure "cannot compute the review floor (no resolvable base ref)"
        return
    fi
    if [ "$(profile_rank "$profile")" -lt "$(profile_rank "$floor")" ]; then
        add_failure "chosen review profile '$profile' is below the computed floor '$floor'"
    fi

    # Floor derives from the computed profile; an attested value may only
    # escalate it — the checked party cannot lower or blank its own floor
    # (R1 MF3): fast=sonnet, standard/full=opus baseline.
    case "${floor%%+*}" in
        fast) model_floor="sonnet" ;;
        *) model_floor="opus" ;;
    esac
    attested_floor="$(attest_get model_floor "$@")" || attested_floor=""
    if [ -n "$attested_floor" ] &&
        [ "$(model_rank "$attested_floor")" -gt "$(model_rank "$model_floor")" ]; then
        model_floor="$attested_floor"
    fi
    lanes_spec="$(attest_get lanes "$@")" || lanes_spec=""

    # A security-flagged floor (batch #7) requires a security lane even when
    # the chosen profile's base lane set does not include one.
    local lanes_list
    lanes_list="$(required_lanes "$profile")"
    case "$floor" in
        *+security)
            case " $lanes_list " in
                *" security "*) ;;
                *) lanes_list="$lanes_list security" ;;
            esac
            ;;
    esac

    # Lane freshness binding (batch #3): lane files must postdate this run's
    # init — a stale /tmp file from an earlier session cannot satisfy the
    # stamp. Runs initialized before this field existed skip the check
    # (non-numeric stored epochs are treated as absent for the same reason).
    local init_epoch lane_mtime
    init_epoch="$(py get initialized_epoch)" || init_epoch=""
    case "$init_epoch" in *[!0-9]* | '') init_epoch="" ;; esac

    for lane in $lanes_list; do
        lane_file="$(lane_path_for "$lane" "$lanes_spec")"
        if [ ! -f "$lane_file" ]; then
            add_failure "required lane '$lane' review file missing: $lane_file"
            continue
        fi
        if [ -n "$init_epoch" ]; then
            lane_mtime="$(file_mtime "$lane_file")"
            # Fail CLOSED on a non-numeric mtime: a broken stat must not
            # silently disable the freshness binding (security lane).
            case "$lane_mtime" in
                *[!0-9]* | '')
                    add_failure "cannot determine mtime for lane '$lane' review file (stat gave '${lane_mtime:-nothing}'): $lane_file"
                    continue
                    ;;
            esac
            if [ "$lane_mtime" -lt "$init_epoch" ]; then
                add_failure "lane '$lane' review file predates this run's init (stale artifact from an earlier session): $lane_file"
                continue
            fi
        fi
        if ! grep -Eq '^verdict:' "$lane_file"; then
            add_failure "lane '$lane' review file has no verdict: line ($lane_file)"
            continue
        fi
        # Accept both `model:` and workflow-review's `model_used:` field.
        lane_model="$(sed -n -e 's/^model:[[:space:]]*//p' -e 's/^model_used:[[:space:]]*//p' "$lane_file" | head -1)"
        if [ "$(model_rank "$lane_model")" -eq 0 ]; then
            add_failure "lane '$lane' model '${lane_model:-missing}' is unrecognized (rank 0); cannot verify floor"
            continue
        fi
        if [ "$(model_rank "$lane_model")" -lt "$(model_rank "$model_floor")" ]; then
            add_failure "lane '$lane' model '${lane_model:-missing}' is below the model floor '$model_floor'"
            continue
        fi
        verdict="$(sed -n 's/^verdict:[[:space:]]*//p' "$lane_file" | head -1)"
        CHECKED+=("lane_${lane}_sha256=$(file_sha256 "$lane_file")")
        CHECKED+=("lane_${lane}_lines=$(wc -l <"$lane_file" | tr -d ' ')")
        CHECKED+=("lane_${lane}_verdict=$verdict")
        CHECKED+=("lane_${lane}_model=$lane_model")
    done
    CHECKED+=("review_floor=$floor")
    CHECKED+=("worktree_verify=$([ "$worktree_ok" -eq 1 ] && echo pass || echo fail)")
}

checked_finalize() {
    local review_out porcelain vinfo v_sha v_pass pr ci prstate threads
    if ! review_out="$(check_gate review)"; then
        add_failure "review gate: $review_out"
    fi

    porcelain="$(git -C "$TOP" status --porcelain)"
    if [ -n "$porcelain" ]; then
        add_failure "working tree not clean: $(tr '\n' ' ' <<<"$porcelain")"
    fi

    vinfo="$(py verify_info)" || vinfo=""
    v_sha="$(sed -n 's/^head_sha=//p' <<<"$vinfo")"
    v_pass="$(sed -n 's/^passed=//p' <<<"$vinfo")"
    if [ "$v_pass" != "1" ] || ! fresh_since "$v_sha"; then
        add_failure "verify-local has no green record at HEAD (run ledger.sh verify-local)"
    fi

    # snapshot_current (batch #8): the committed snapshot's durable content
    # must match live state — a snapshot-only commit is freshness-exempt, so
    # without this check the PR-visible record could be rewritten silently.
    local snap_ok
    snap_ok="$(py snapshot_match "$SNAPSHOT")" || snap_ok=""
    if [ "$snap_ok" != "1" ]; then
        add_failure "committed snapshot ($SNAPSHOT_REL) does not match live ledger state — the tracked snapshot was rewritten out-of-band"
    else
        CHECKED+=("snapshot_current=1")
    fi

    # Mock forge answers must never reach a real finalize stamp (R1 MF6),
    # and when the test sentinel permits them the stamp must say so — a
    # mock-sourced stamp with no marker is a silent bypass (R2 MF1).
    if [ -n "${FORGE_MOCK_DIR:-}" ]; then
        CHECKED+=("forge_mock=1")
        if [ "${LEDGER_ALLOW_FORGE_MOCK:-0}" != "1" ]; then
            add_failure "FORGE_MOCK_DIR is set — forge checks would be fabricated (unset it; tests set LEDGER_ALLOW_FORGE_MOCK=1)"
            return
        fi
    fi

    # The gated party does not choose whether forge checks run (R1 MF5):
    # resolve the branch's open PR ourselves; an attested pr_number must match.
    local branch looked_up
    branch="$(git -C "$TOP" branch --show-current 2>/dev/null)"
    looked_up="$(bash "$FORGE_SH" pr-for-branch "$branch" 2>&1)" || {
        add_failure "cannot resolve PR for branch '$branch' via forge: $looked_up"
        return
    }
    pr="$(attest_get pr_number "$@")" || pr=""
    if [ -n "$pr" ] && [ "$pr" != "$looked_up" ]; then
        add_failure "attested pr_number=$pr does not match forge lookup ($looked_up) for branch '$branch'"
        return
    fi
    pr="$looked_up"
    if [ "$pr" != "none" ]; then
        ci="$(bash "$FORGE_SH" ci-status "$pr" 2>&1)" || ci="error: $ci"
        [ "$ci" = "green" ] || add_failure "forge CI not green for PR #$pr: $ci"
        prstate="$(bash "$FORGE_SH" pr-state "$pr" 2>&1)" || prstate="error: $prstate"
        [ "$prstate" = "open" ] || add_failure "PR #$pr is not open: $prstate"
        threads="$(bash "$FORGE_SH" threads-resolved "$pr" 2>&1)" || threads="error: $threads"
        [ "$threads" = "yes" ] || add_failure "review threads not resolved on PR #$pr: $threads"
        CHECKED+=("ci=$ci" "pr_state=$prstate" "threads_resolved=$threads")
    else
        # Forge lookup ran and found no open PR — the only path to no_pr.
        CHECKED+=("forge=no_pr")
    fi
}

# ---- subcommands ------------------------------------------------------------

cmd_init() {
    [ $# -ge 1 ] || usage
    local run_id="$1" workflow="" kind="" steps="" budget="one-reviewer" force=0
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --workflow)
                workflow="$2"
                shift 2
                ;;
            --kind)
                kind="$2"
                shift 2
                ;;
            --steps)
                steps="$2"
                shift 2
                ;;
            --budget)
                budget="$2"
                shift 2
                ;;
            --force)
                force=1
                shift
                ;;
            *) usage ;;
        esac
    done
    [ -n "$workflow" ] && [ -n "$kind" ] && [ -n "$steps" ] || usage
    py init "$run_id" "$workflow" "$kind" "$steps" "$budget" "$force" || exit $?
    # Ground-truth anchors for reconcile (batch #6): where the run lives.
    py set_meta branch "$(git -C "$TOP" branch --show-current 2>/dev/null)" || exit $?
    py set_meta worktree "$TOP" || exit $?
    commit_snapshot init "$run_id"
    echo "initialized run $run_id ($kind via $workflow); live state: $LIVE"
}

cmd_set() {
    [ $# -ge 2 ] || usage
    local step="$1" status="$2" evidence="" reason=""
    shift 2
    while [ $# -gt 0 ]; do
        case "$1" in
            --evidence)
                evidence="$2"
                shift 2
                ;;
            --reason)
                reason="$2"
                shift 2
                ;;
            *) usage ;;
        esac
    done
    py set "$step" "$status" "$evidence" "$reason" || exit $?
    echo "step '$step' -> $status"
}

cmd_stamp() {
    [ $# -ge 1 ] || usage
    local gate="$1" gate_type="reviewer-validation" human=0 override=0 reason=""
    local attests=()
    shift
    case "$gate" in
        diagnose | fix | review | finalize) ;;
        *) die 5 "unknown gate: $gate (expected diagnose|fix|review|finalize)" ;;
    esac
    while [ $# -gt 0 ]; do
        case "$1" in
            --attest)
                attests+=("$2")
                shift 2
                ;;
            --gate-type)
                gate_type="$2"
                shift 2
                ;;
            --human)
                human=1
                shift
                ;;
            --override)
                override=1
                shift
                ;;
            --reason)
                reason="$2"
                shift 2
                ;;
            *) usage ;;
        esac
    done

    case "$gate_type" in
        reviewer-validation | maintainer-decision | operator-runtime | secret-custody) ;;
        *) die 6 "invalid gate type: $gate_type" ;;
    esac
    if [ "$gate_type" != "reviewer-validation" ] && [ "$human" -ne 1 ]; then
        die 8 "gate type '$gate_type' requires --human provenance (only reviewer-validation gates are agent-stampable)"
    fi

    [ -f "$LIVE" ] || die 1 "no live ledger state (run ledger.sh init)"
    py get run_id >/dev/null || exit $?

    local provenance="agent" head_sha
    [ "$human" -eq 1 ] && provenance="human"
    head_sha="$(git -C "$TOP" rev-parse HEAD)" || die 10 "cannot resolve HEAD"

    if [ "$override" -eq 1 ]; then
        [ -n "$reason" ] || die 4 "--override requires a non-empty --reason"
        py write_stamp "$gate" "$head_sha" "$gate_type" "$provenance" 1 "$reason" \
            --attest ${attests[@]+"${attests[@]}"} --checked || exit $?
        commit_snapshot stamp "$gate"
        printf 'WARNING: OVERRIDE stamp on %s gate — checked fields bypassed: %s\n' \
            "$gate" "$reason" >&2
        return 0
    fi

    FAILURES=""
    CHECKED=()
    case "$gate" in
        diagnose) checked_diagnose ${attests[@]+"${attests[@]}"} ;;
        fix) checked_fix ${attests[@]+"${attests[@]}"} ;;
        review) checked_review ${attests[@]+"${attests[@]}"} ;;
        finalize) checked_finalize ${attests[@]+"${attests[@]}"} ;;
    esac

    if [ -n "$FAILURES" ]; then
        printf 'stamp %s refused; checked fields failed:\n%s' "$gate" "$FAILURES"
        exit 2
    fi

    py write_stamp "$gate" "$head_sha" "$gate_type" "$provenance" 0 "" \
        --attest ${attests[@]+"${attests[@]}"} --checked ${CHECKED[@]+"${CHECKED[@]}"} || exit $?
    commit_snapshot stamp "$gate"
    echo "stamped $gate at $head_sha"
}

cmd_check() {
    [ $# -ge 1 ] || usage
    local out status
    out="$(check_gate "$1")"
    status=$?
    printf '%s\n' "$out"
    exit "$status"
}

# CI-side gate check against the COMMITTED snapshot — no live state required
# (D-006 Phase 5a: server-side merge gates run on a fresh checkout where the
# git-dir ledger does not exist). Shares the whole verdict shell with `check`
# via gate_verdict (snapshot mode): same schema validation on the untrusted
# snapshot (malformed = exit 6), same content-verified fresh_since, same
# message strings — minus the live-vs-snapshot drift compare, which needs
# live state that CI lacks.
cmd_check_snapshot() {
    [ $# -ge 1 ] || usage
    local out status
    out="$(gate_verdict "$1" snapshot)"
    status=$?
    printf '%s\n' "$out"
    exit "$status"
}

cmd_reconcile() {
    local apply=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --apply)
                apply=1
                shift
                ;;
            *) usage ;;
        esac
    done
    [ -f "$LIVE" ] || die 1 "no live ledger state (run ledger.sh init)"
    local last head drift next_step branch rec_branch rec_wt pending_step truth=""
    last="$(py get last_seen_sha)" || exit $?
    head="$(git -C "$TOP" rev-parse HEAD)"
    branch="$(git -C "$TOP" branch --show-current 2>/dev/null)"
    rec_branch="$(py get branch)" || exit $?
    rec_wt="$(py get worktree)" || exit $?
    pending_step="$(py get next)" || exit $?
    drift=""
    if [ -n "$last" ] && git -C "$TOP" cat-file -e "${last}^{commit}" 2>/dev/null; then
        # Content-verified: a commit is ledger-internal only if it touches
        # exactly the snapshot file (same rule as fresh_since; R1 MF1).
        drift=""
        while IFS= read -r _c; do
            [ -n "$_c" ] || continue
            _paths="$(git -C "$TOP" diff-tree --no-commit-id --name-only -r "$_c" 2>/dev/null)"
            if [ "$_paths" != "$SNAPSHOT_REL" ]; then
                drift="${drift}$(git -C "$TOP" log -1 --format='%h %s' "$_c")"$'\n'
            fi
        done <<<"$(git -C "$TOP" log --format=%H "${last}..HEAD" 2>/dev/null)"
        drift="${drift%$'\n'}"
    fi
    # Ground-truth comparisons (batch #6): the run's recorded branch and
    # worktree must still be where the run actually lives. Runs initialized
    # before these fields existed ("" recorded) skip the comparison.
    if [ -n "$rec_branch" ] && [ "$rec_branch" != "$branch" ]; then
        if git -C "$TOP" show-ref --verify --quiet "refs/heads/$rec_branch"; then
            truth="${truth}branch: run recorded '$rec_branch' but HEAD is on '${branch:-detached}'"$'\n'
        else
            truth="${truth}branch: run recorded '$rec_branch' which no longer exists (HEAD is on '${branch:-detached}')"$'\n'
        fi
    fi
    if [ -n "$rec_wt" ] && [ "$rec_wt" != "$TOP" ]; then
        truth="${truth}worktree: run recorded '$rec_wt' but is running in '$TOP'"$'\n'
    fi
    truth="${truth%$'\n'}"
    if [ "$apply" -eq 1 ]; then
        next_step="$(py reconcile_apply)" || exit $?
        py set_meta last_seen_sha "$head" || exit $?
        py set_meta branch "$branch" || exit $?
        py set_meta worktree "$TOP" || exit $?
        echo "reconciled: next='${next_step}' last_seen_sha=$head branch=${branch:-detached} worktree=$TOP"
        return 0
    fi
    if [ -n "$drift" ] || [ -n "$truth" ]; then
        echo "DRIFT:"
        if [ -n "$truth" ]; then
            echo "$truth"
        fi
        if [ -n "$drift" ]; then
            echo "commits outside the ledger since $last:"
            echo "$drift"
            if [ -n "$pending_step" ]; then
                echo "step '$pending_step' is still pending while those commits exist"
            fi
        fi
        echo "true frontier: HEAD=$head branch=${branch:-detached} worktree=$TOP; run 'ledger.sh reconcile --apply' to adopt"
        exit 1
    fi
    echo "clean: ledger frontier matches git (HEAD=$head branch=${branch:-detached})"
}

cmd_preflight() {
    local skill=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --skill)
                skill="$2"
                shift 2
                ;;
            *) usage ;;
        esac
    done
    [ -n "$skill" ] || usage
    local skill_md="$SKILLS_ROOT/$skill/SKILL.md"
    [ -f "$skill_md" ] || die 5 "unknown skill: $skill (no SKILL.md under $SKILLS_ROOT)"
    local requires missing="" tool
    requires="$(sed -n 's/^Requires:[[:space:]]*//p' "$skill_md" | head -1)"
    if [ -z "$requires" ] || [ "$requires" = "none" ]; then
        echo "preflight OK: $skill declares no required CLI tools"
        return 0
    fi
    # Strip ALL parenthetical notes first (a segment-leading paren must not
    # swallow the rest of the line — R1 MF4), split on ',' AND ';'/' or ',
    # then check the first word of each segment when it is CLI-shaped.
    # Non-CLI-shaped segments (prose) are reported, never silently dropped.
    local skipped=""
    while IFS= read -r tool; do
        tool="$(sed -E 's/^[[:space:]]+//; s/[[:space:]].*$//' <<<"$tool")"
        [ -n "$tool" ] || continue
        [ "$tool" = "none" ] && continue
        if ! grep -Eq '^[a-z][a-z0-9_.-]*$' <<<"$tool"; then
            skipped="$skipped $tool"
            continue
        fi
        command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
    done <<<"$(sed -E 's/\([^)]*\)//g; s/ or /\n/g' <<<"$requires" | tr ',;' '\n')"
    [ -n "$skipped" ] && echo "preflight note: unparsed segments (not checked):$skipped"
    if [ -n "$missing" ]; then
        echo "preflight FAILED for $skill: missing tools:$missing"
        exit 1
    fi
    echo "preflight OK: $skill requires ($requires) — all present"
}

cmd_review_floor() {
    local base=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --base)
                base="$2"
                shift 2
                ;;
            *) usage ;;
        esac
    done
    compute_floor "$base"
}

cmd_verify_local() {
    local manifest="$TOP/docs/executions/ci-commands.yaml"
    if [ ! -f "$manifest" ]; then
        echo "NO_MANIFEST: $manifest not found — callers decide policy"
        exit 9
    fi
    local cmds head_sha failed=0 failing="" cmd rc passed
    local results=()
    cmds="$(py manifest "$manifest")" || exit $?
    head_sha="$(git -C "$TOP" rev-parse HEAD)"
    while IFS= read -r cmd; do
        [ -n "$cmd" ] || continue
        (cd "$TOP" && bash -c "$cmd") >/dev/null 2>&1
        rc=$?
        results+=("$rc" "$cmd")
        if [ "$rc" -ne 0 ]; then
            failed=1
            failing="$cmd"
            echo "FAIL ($rc): $cmd"
        else
            echo "PASS: $cmd"
        fi
    done <<<"$cmds"
    passed=1
    [ "$failed" -eq 0 ] || passed=0
    if [ -f "$LIVE" ]; then
        py record_verify "$head_sha" "$passed" ${results[@]+"${results[@]}"} || exit $?
    fi
    if [ "$failed" -ne 0 ]; then
        echo "verify-local FAILED: $failing"
        exit 1
    fi
    echo "verify-local PASSED at $head_sha"
}

cmd_show() {
    py show
    exit $?
}

cmd_close() {
    local run_id
    run_id="$(py close)" || exit $?
    commit_snapshot close "$run_id"
    echo "closed run $run_id"
}

main() {
    [ $# -ge 1 ] || usage
    local sub="$1"
    shift
    require_repo
    case "$sub" in
        init) cmd_init "$@" ;;
        set) cmd_set "$@" ;;
        stamp) cmd_stamp "$@" ;;
        check) cmd_check "$@" ;;
        check-snapshot) cmd_check_snapshot "$@" ;;
        reconcile) cmd_reconcile "$@" ;;
        preflight) cmd_preflight "$@" ;;
        review-floor) cmd_review_floor "$@" ;;
        verify-local) cmd_verify_local "$@" ;;
        show) cmd_show "$@" ;;
        close) cmd_close "$@" ;;
        *) usage ;;
    esac
}

main "$@"
