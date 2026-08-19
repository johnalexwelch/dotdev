#!/usr/bin/env bash
# finalize-stamp-check.sh — D-006 Phase 5a: server-side finalize-stamp gate.
#
# Called by the `finalize-stamp` job in .github/workflows/ci.yml against the
# PR head checkout (full history). Requires the committed ledger snapshot
# (docs/executions/state.yaml) to carry a finalize stamp that is fresh at
# HEAD by the kernel's content-verified rule. The check itself is
# `ledger.sh check-snapshot finalize` — freshness keeps exactly one
# implementation (the kernel's fresh_since), never a re-implementation here.
#
# Closes the auto-merge bypass observed live on PR #167: the local merge-gate
# hook (workflow-guard.sh) never sees a server-side merge, so GitHub's
# auto-merge could land a PR whose finalize stamp was missing or stale.
#
# Exemptions (pass-with-note, by design — otherwise every deps PR bricks):
#   - repo not opted in: docs/executions/ absent (same opt-in the hooks use)
#   - deps branches: head ref matching renovate/* or dependabot/*
#   - docs-only diffs: every changed path vs --base matches ^docs/ or \.md$
#   - empty diff vs --base
# Overridden stamps PASS, but the override reason is annotated loudly into
# the check output and the GitHub step summary.
#
# Usage: finalize-stamp-check.sh --base <ref-or-sha> [--head-ref <branch>]
# Exit codes:
#   0  pass (stamp fresh, overridden, or exempt-with-note)
#   1  gate failed (no stamp, stale stamp, or malformed snapshot)
#   2  usage error

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEDGER_SH="${FINALIZE_CHECK_LEDGER_SH:-$SCRIPT_DIR/../dotfiles/.config/agents/skills/workflow-ledger/scripts/ledger.sh}"

BASE=""
HEAD_REF=""

usage() {
    echo "Usage: $0 --base <ref-or-sha> [--head-ref <branch>]" >&2
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --base)
            [ $# -ge 2 ] || usage
            BASE="$2"
            shift 2
            ;;
        --head-ref)
            [ $# -ge 2 ] || usage
            HEAD_REF="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done
[ -n "$BASE" ] || usage

# Every verdict goes to stdout AND (when running in Actions) the step summary,
# so a soak-week non-blocking failure is still loud on the PR checks page.
summary() {
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        printf '%s\n' "$*" >>"$GITHUB_STEP_SUMMARY"
    fi
}

verdict() {
    printf '%s\n' "$*"
    summary "$*"
}

pass_note() {
    verdict "FINALIZE_STAMP_CHECK: PASS-WITH-NOTE — $*"
    exit 0
}

TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: not inside a git repository" >&2
    exit 2
}

summary "## Finalize stamp check (D-006)"

# Exemption 1: repo not opted in to ledger enforcement.
if [ ! -d "$TOP/docs/executions" ]; then
    pass_note "repo not opted in (no docs/executions/); ledger gates do not apply"
fi

# Exemption 2: dependency-update branches (renovate/dependabot never carry
# ledger runs; requiring stamps would brick every deps PR).
case "$HEAD_REF" in
    renovate/* | dependabot/*)
        pass_note "deps branch '$HEAD_REF' is exempt from the finalize-stamp gate"
        ;;
esac

# Exemption 3: docs-only (or empty) diffs vs the PR base.
merge_base="$(git merge-base "$BASE" HEAD 2>/dev/null)" || merge_base=""
if [ -n "$merge_base" ]; then
    changed="$(git diff --name-only "$merge_base" HEAD 2>/dev/null)" || changed=""
    if [ -z "$changed" ]; then
        pass_note "empty diff vs base $BASE"
    fi
    docs_only=1
    while IFS= read -r path; do
        case "$path" in
            docs/* | *.md) ;;
            *)
                docs_only=0
                break
                ;;
        esac
    done <<<"$changed"
    if [ "$docs_only" -eq 1 ]; then
        pass_note "docs-only diff vs base $BASE (all paths match ^docs/ or .md)"
    fi
else
    # No merge-base (shallow or disjoint history): never exempt on a guess —
    # fall through to the stamp check, which is the conservative direction.
    verdict "note: could not resolve merge-base with '$BASE'; docs-only exemption skipped"
fi

# The gate: committed snapshot must carry a fresh finalize stamp.
out="$(bash "$LEDGER_SH" check-snapshot finalize 2>&1)"
status=$?

case "$out" in
    OVERRIDDEN:*)
        reason="${out#OVERRIDDEN: }"
        verdict "FINALIZE_STAMP_CHECK: PASS (OVERRIDDEN) — finalize stamp carries an audited override"
        verdict "override reason: $reason"
        summary ""
        summary "> **Audited override.** This PR's finalize gate was overridden, not passed."
        exit 0
        ;;
esac

if [ "$status" -eq 0 ]; then
    verdict "FINALIZE_STAMP_CHECK: PASS — $out"
    exit 0
fi

verdict "FINALIZE_STAMP_CHECK: FAIL — $out"
summary ""
summary "> **This PR has no fresh finalize stamp.** Run the delivery workflow's"
summary "> finalize gate (\`ledger.sh stamp finalize\`) and push the snapshot"
summary "> commit, or record an audited override. Non-blocking during the soak"
summary "> week; this job is slated to become required."
exit 1
