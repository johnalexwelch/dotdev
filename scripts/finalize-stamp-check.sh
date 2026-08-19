#!/usr/bin/env bash
# finalize-stamp-check.sh — D-006 Phase 5a: server-side finalize-stamp gate.
#
# Called by the `finalize-stamp` job in .github/workflows/ci.yml against the
# PR head checkout (full history). Requires a committed PER-RUN ledger
# snapshot (docs/executions/runs/<run_id>.yaml) changed by this PR to carry
# a finalize stamp that is fresh at HEAD by the kernel's content-verified
# rule. Candidates come from the diff vs --base; the check itself is
# `ledger.sh check-snapshot finalize --file <candidate>` — freshness keeps
# exactly one implementation (the kernel's fresh_since), never a
# re-implementation here. The legacy shared docs/executions/state.yaml is a
# frozen historical record and satisfies nothing.
#
# Closes the auto-merge bypass observed live on PR #167: the local merge-gate
# hook (workflow-guard.sh) never sees a server-side merge, so GitHub's
# auto-merge could land a PR whose finalize stamp was missing or stale.
# Threat model: this gate detects OMISSION and STALENESS (honest-actor
# failures like #167), not fabrication — the snapshot is PR-authored,
# unsigned input, so a hand-forged stamp passes; anti-fabrication stays with
# review and the local snapshot-drift check.
#
# Exemptions (pass-with-note, by design — otherwise every deps PR bricks):
#   - repo not opted in: docs/executions/ absent (same opt-in the hooks use)
#   - deps branches: head ref matching renovate/* or dependabot/*
#   - docs-only diffs vs --base: every changed path is docs/* (excluding
#     docs/executions/*, the ledger's own evidence) or a root-level *.md.
#     Nested *.md outside docs/ is NOT exempt — in this repo SKILL.md files
#     are the delivered product, not documentation.
#   - empty diff vs --base
# Overridden stamps PASS, but the override reason is annotated loudly into
# the check output and the GitHub step summary. Kernel environment breakage
# (ledger exit 10) warn-permits with an ERROR note, mirroring the local
# merge-gate hook's posture (D-006 #5) — infra breakage is not a verdict.
#
# Usage: finalize-stamp-check.sh --base <ref-or-sha> [--head-ref <branch>]
# Env:   FINALIZE_CHECK_LEDGER_SH — override the ledger.sh path. Test seam
#        today; at the required-flip it also becomes the production seam for
#        running a base-ref kernel. It pins ONLY the kernel — pinning this
#        script and the workflow file needs separate mechanisms (see the
#        flip preconditions in .github/workflows/ci.yml).
# Exit codes:
#   0  pass (stamp fresh, overridden, exempt-with-note, or kernel
#      environment breakage warn-permitted with an ERROR note)
#   1  gate failed (no stamp, stale stamp, or malformed snapshot)
#   2  usage error / not inside a git repository

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

# Exemption 3: docs-only (or empty) diffs vs the PR base. "Docs" means
# docs/* minus docs/executions/* (the gate's own evidence file must never
# exempt itself) plus root-level *.md — nested *.md outside docs/ is the
# skills corpus, i.e. the product, and stays gated (Phase 5a review,
# security M1 / logic MF1).
merge_base="$(git merge-base "$BASE" HEAD 2>/dev/null)" || merge_base=""
diff_ok=0
changed=""
if [ -n "$merge_base" ]; then
    if changed="$(git diff --name-only "$merge_base" HEAD 2>/dev/null)"; then
        diff_ok=1
        if [ -z "$changed" ]; then
            pass_note "empty diff vs base $BASE"
        fi
        docs_only=1
        while IFS= read -r path; do
            case "$path" in
                docs/executions/*)
                    docs_only=0
                    break
                    ;;
                docs/*) ;;
                */*)
                    docs_only=0
                    break
                    ;;
                *.md) ;;
                *)
                    docs_only=0
                    break
                    ;;
            esac
        done <<<"$changed"
        if [ "$docs_only" -eq 1 ]; then
            pass_note "docs-only diff vs base $BASE (docs/* minus docs/executions/*, plus root-level .md)"
        fi
    else
        # A FAILED diff is not an empty diff: never exempt on a guess — fall
        # through to the stamp check, the conservative direction.
        verdict "note: git diff vs base '$BASE' failed; docs-only exemption skipped"
    fi
else
    # No merge-base (shallow or disjoint history): same conservative
    # direction — skip the exemption, run the gate.
    verdict "note: could not resolve merge-base with '$BASE'; docs-only exemption skipped"
fi

# The gate: a per-run committed snapshot changed by THIS PR must carry a
# fresh finalize stamp. Candidates are the FLAT docs/executions/runs/*.yaml
# files in the diff vs base that still exist at HEAD — a delivery's own
# stamps are by construction commits on its branch, so its run file is always
# in the diff. Nested runs/ paths are never candidates: the kernel cannot
# author one (run_ids reject separators), and bash case globs cross '/', so
# an unqualified runs/*.yaml arm would accept a hand-written nested file the
# write-block guard is also asked to cover (review round: security H1 /
# logic F1). At least one candidate must pass `check-snapshot finalize
# --file` (a superseded force-re-init sibling may legitimately be stale).
# Zero candidates on a non-exempt diff = the delivery never stamped. When
# the diff itself could not be computed (no merge-base, failed diff), the
# fallback enumerates the flat run files present at HEAD and runs the same
# loop — resolvable and fail-closed, never the kernel's single-file tier,
# which reads AMBIGUOUS forever once run files accumulate (logic F2).
candidates=()
deleted_candidates=0
nested_candidates=0
if [ "$diff_ok" -eq 1 ]; then
    candidate_source="changed vs base $BASE"
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        # ?* (not *): a case glob's * matches the empty string, which would
        # accept the dotfile basenames '.yaml'/'.yml' the kernel can never
        # author (review round 2: security).
        case "$path" in
            docs/executions/runs/*/*)
                nested_candidates=$((nested_candidates + 1))
                ;;
            docs/executions/runs/?*.yaml | docs/executions/runs/?*.yml)
                if [ -f "$TOP/$path" ]; then
                    candidates+=("$path")
                else
                    deleted_candidates=$((deleted_candidates + 1))
                fi
                ;;
        esac
    done <<<"$changed"
else
    candidate_source="present at HEAD (diff vs base unavailable)"
    for f in "$TOP"/docs/executions/runs/*.yaml "$TOP"/docs/executions/runs/*.yml; do
        [ -f "$f" ] || continue
        candidates+=("${f#"$TOP"/}")
    done
fi

out=""
status=1
malformed=""
if [ "${#candidates[@]}" -eq 0 ]; then
    out="no run snapshot (docs/executions/runs/*.yaml) ${candidate_source} — the delivery never stamped, or the run file was not committed"
    if [ "$deleted_candidates" -gt 0 ]; then
        out="$out, or every changed run file was deleted at HEAD ($deleted_candidates skipped)"
    fi
    if [ "$nested_candidates" -gt 0 ]; then
        out="$out, or the run file is nested and was ignored ($nested_candidates skipped — the kernel only authors docs/executions/runs/<run_id>.yaml)"
    fi
    status=1
else
    # Scan every candidate (no early break) so schema-invalid siblings are
    # collected even when another candidate passes. Precedence: any pass wins;
    # else kernel environment breakage (exit 10) outranks plain failures so
    # the warn-permit posture survives the loop. Exit 6 (corrupt snapshot) is
    # tracked separately — a corrupt PR-visible record must never merge
    # unannotated (logic F4).
    pass_out=""
    env_out=""
    env_seen=0
    fail_out=""
    for cand in "${candidates[@]}"; do
        cand_out="$(bash "$LEDGER_SH" check-snapshot finalize --file "$cand" 2>&1)"
        cand_status=$?
        case "$cand_status" in
            0)
                [ -n "$pass_out" ] || pass_out="$cand_out"
                continue
                ;;
            6)
                malformed="${malformed:+$malformed, }$cand"
                ;;
            10)
                if [ "$env_seen" -eq 0 ]; then
                    env_seen=1
                    env_out="$cand_out"
                fi
                ;;
        esac
        fail_out="${fail_out}candidate $cand: $(printf '%s\n' "$cand_out" | tail -n 1)"$'\n'
    done
    if [ -n "$pass_out" ]; then
        out="$pass_out"
        status=0
    elif [ "$env_seen" -eq 1 ]; then
        out="$env_out"
        status=10
    else
        out="${fail_out%$'\n'}"
        status=1
    fi
fi

# Schema-invalid siblings stay loud even on PASS ($malformed is single-line —
# candidate paths come from diff/glob lines, no embedded newlines survive the
# read loop).
if [ -n "$malformed" ] && [ "$status" -eq 0 ]; then
    verdict "note: schema-invalid run snapshot(s) in this PR (kernel exit 6): $malformed — corrupt PR-visible record; fix before merge"
    echo "::warning::schema-invalid run snapshot(s): $malformed"
fi

# The kernel's verdict is the LAST line on the single-check paths — stderr
# noise (python warnings, resolver chatter) merged into $out must not break
# the match (security S2). On the aggregate multi-candidate FAIL path $out is
# script-synthesized ("candidate <path>: <kernel tail>" lines) and is never
# verdict-matched: verdict_line is only consumed under status 0, where $out
# is raw kernel output for the passing candidate.
verdict_line="$(printf '%s\n' "$out" | tail -n 1)"
# $out is kernel output that interpolates untrusted snapshot text; collapse
# newlines AND carriage returns before any log/annotation write so it can
# never smuggle a forged verdict line or a GitHub workflow command
# (::stop-commands::) into the audit surface (security S6).
out_1line="$(printf '%s' "$out" | tr '\n\r' '  ')"

if [ "$status" -eq 0 ]; then
    # Kernel PASS only: the OVERRIDDEN render must never be reachable on a
    # non-zero kernel status — a crafted multi-line override reason could
    # otherwise place an OVERRIDDEN-shaped last line under a kernel FAIL and
    # flip the script verdict (security M2).
    case "$verdict_line" in
        OVERRIDDEN:*)
            reason="${verdict_line#OVERRIDDEN: }"
            reason="${reason//$'\r'/}"
            reason="${reason//\`/}"
            verdict "FINALIZE_STAMP_CHECK: PASS (OVERRIDDEN) — finalize stamp carries an audited override"
            verdict "override reason: $reason"
            summary ""
            summary "> **Audited override.** This PR's finalize gate was overridden, not passed. Reason: \`$reason\`"
            echo "::warning::finalize-stamp gate passed via audited override: $reason"
            exit 0
            ;;
    esac
    verdict "FINALIZE_STAMP_CHECK: PASS — $out_1line"
    exit 0
fi

# Kernel exit 10 is environment breakage, not a gate verdict — the kernel's
# own API separates it from gate-unmet 1 precisely so gates can warn-permit
# (mirrors the local merge-gate hook's posture on kernel breakage, D-006 #5).
if [ "$status" -eq 10 ]; then
    verdict "FINALIZE_STAMP_CHECK: ERROR — kernel environment breakage (exit 10), not a stamp verdict: $out_1line"
    summary ""
    summary "> **Infra, not governance.** The ledger kernel could not run (missing python3/PyYAML or similar). Warn-permitting per D-006 #5; fix the runner environment."
    echo "::warning::finalize-stamp check could not run (kernel exit 10): $out_1line"
    exit 0
fi

verdict "FINALIZE_STAMP_CHECK: FAIL — $out_1line"
echo "::error::finalize-stamp gate failed: $out_1line"
summary ""
summary "> **This PR has no fresh finalize stamp.** Run the delivery workflow's"
summary "> finalize gate (\`ledger.sh stamp finalize\`) and push the snapshot"
summary "> commit, or record an audited override. Non-blocking during the soak"
summary "> week; this job is slated to become required."
exit 1
