#!/usr/bin/env bash
# forge.sh — origin-detecting forge shim (D-006 addendum #20). Normalizes CI,
# PR state, and review-thread status across GitHub (gh) and Forgejo (curl API)
# into one-word answers so ledger.sh checked fields stay forge-agnostic.
#
# Usage:
#   forge.sh detect                  -> github|forgejo|none
#   forge.sh ci-status <pr>          -> green|red|pending
#   forge.sh pr-state <pr>           -> open|merged|closed|draft
#   forge.sh threads-resolved <pr>   -> yes|no
#
# Detection: origin URLs containing github.com are github; any other origin
# URL is forgejo; no origin remote is none.
#
# Mock mode: FORGE_MOCK_DIR=<dir> reads the canned normalized answer from
# "$FORGE_MOCK_DIR/<forge>-<op>-<pr>" (e.g. github-ci-status-42) — zero
# network. Forgejo real mode requires FORGE_URL and FORGE_TOKEN.

set -uo pipefail

die() {
    echo "Error: $*" >&2
    exit 1
}

usage() {
    sed -n '/^# Usage:/,/^# Detection:/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
    exit 1
}

detect_forge() {
    local url
    url="$(git remote get-url origin 2>/dev/null)" || url=""
    case "$url" in
        "") echo none ;;
        *github.com*) echo github ;;
        *) echo forgejo ;;
    esac
}

repo_path() {
    git remote get-url origin 2>/dev/null |
        sed -E 's#^[a-zA-Z+]+://[^/]+/##; s#^[^@/]+@[^:]+:##; s#\.git$##; s#/+$##'
}

# ---- GitHub via gh ----------------------------------------------------------

gh_ci_status() {
    local pr="$1" states
    states="$(gh pr view "$pr" --json statusCheckRollup \
        --jq '[.statusCheckRollup[]? | (.conclusion // .state // "")] | join(" ")')" ||
        return 1
    case "$states" in
        *FAILURE* | *ERROR* | *CANCELLED* | *TIMED_OUT* | *ACTION_REQUIRED*) echo red ;;
        *PENDING* | *IN_PROGRESS* | *QUEUED* | *WAITING* | *EXPECTED*) echo pending ;;
        *) echo green ;;
    esac
}

gh_pr_state() {
    local pr="$1"
    gh pr view "$pr" --json state,isDraft \
        --jq 'if .isDraft then "draft" else (.state | ascii_downcase) end'
}

# Prints the open PR number for a branch, or "none" when no open PR exists.
gh_pr_for_branch() {
    local branch="$1" n
    n="$(gh pr list --head "$branch" --state open --json number --jq '.[0].number // "none"')" ||
        return 1
    echo "$n"
}

gh_threads_resolved() {
    local pr="$1" repo owner name unresolved
    repo="$(repo_path)"
    owner="${repo%%/*}"
    name="${repo##*/}"
    # shellcheck disable=SC2016 # GraphQL variables, not shell expansions.
    unresolved="$(gh api graphql \
        -f query='query($owner:String!,$name:String!,$pr:Int!){repository(owner:$owner,name:$name){pullRequest(number:$pr){reviewThreads(first:100){nodes{isResolved}}}}}' \
        -F owner="$owner" -F name="$name" -F pr="$pr" \
        --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)] | length')" ||
        return 1
    if [ "$unresolved" = "0" ]; then
        echo yes
    else
        echo no
    fi
}

# ---- Forgejo via curl + python3 (no jq dependency) --------------------------

fj_api() {
    [ -n "${FORGE_URL:-}" ] || die "FORGE_URL not set for Forgejo API access"
    curl -sSf -H "Authorization: token ${FORGE_TOKEN:-}" "${FORGE_URL%/}/api/v1$1"
}

fj_ci_status() {
    local pr="$1" repo sha state
    repo="$(repo_path)"
    sha="$(fj_api "/repos/$repo/pulls/$pr" |
        python3 -c 'import json,sys; print(json.load(sys.stdin)["head"]["sha"])')" || return 1
    state="$(fj_api "/repos/$repo/commits/$sha/status" |
        python3 -c 'import json,sys; print(json.load(sys.stdin).get("state",""))')" || return 1
    case "$state" in
        success) echo green ;;
        failure | error) echo red ;;
        *) echo pending ;;
    esac
}

fj_pr_state() {
    local pr="$1" repo
    repo="$(repo_path)"
    fj_api "/repos/$repo/pulls/$pr" | python3 -c '
import json, sys

d = json.load(sys.stdin)
if d.get("merged"):
    print("merged")
elif d.get("draft"):
    print("draft")
else:
    print(d.get("state", "closed"))
'
}

# Prints the open PR number for a branch, or "none" when no open PR exists.
fj_pr_for_branch() {
    local branch="$1" repo
    repo="$(repo_path)"
    fj_api "/repos/$repo/pulls?state=open" | python3 -c '
import json, sys

branch = sys.argv[1]
for pr in json.load(sys.stdin) or []:
    if (pr.get("head") or {}).get("ref") == branch:
        print(pr.get("number"))
        break
else:
    print("none")
' "$branch"
}

fj_threads_resolved() {
    # Forgejo/Gitea has no first-class thread-resolution flag; approximate with
    # the latest review verdict per reviewer — any standing REQUEST_CHANGES
    # counts as unresolved (audited-override philosophy: honest, not perfect).
    local pr="$1" repo
    repo="$(repo_path)"
    fj_api "/repos/$repo/pulls/$pr/reviews" | python3 -c '
import json, sys

reviews = json.load(sys.stdin) or []
latest = {}
for review in reviews:
    user = (review.get("user") or {}).get("login", "")
    latest[user] = review.get("state", "")
print("no" if "REQUEST_CHANGES" in latest.values() else "yes")
'
}

# ---- dispatch ----------------------------------------------------------------

run_op() {
    local op="$1" pr="$2" forge
    forge="$(detect_forge)"
    [ "$forge" != "none" ] || die "no origin remote; cannot dispatch $op"
    if [ -n "${FORGE_MOCK_DIR:-}" ]; then
        local mock="$FORGE_MOCK_DIR/$forge-$op-$pr"
        [ -f "$mock" ] || die "mock answer missing: $mock"
        head -n 1 "$mock"
        return 0
    fi
    case "$forge-$op" in
        github-ci-status) gh_ci_status "$pr" ;;
        github-pr-state) gh_pr_state "$pr" ;;
        github-threads-resolved) gh_threads_resolved "$pr" ;;
        github-pr-for-branch) gh_pr_for_branch "$pr" ;;
        forgejo-ci-status) fj_ci_status "$pr" ;;
        forgejo-pr-state) fj_pr_state "$pr" ;;
        forgejo-threads-resolved) fj_threads_resolved "$pr" ;;
        forgejo-pr-for-branch) fj_pr_for_branch "$pr" ;;
        *) die "unsupported op: $op" ;;
    esac
}

main() {
    [ $# -ge 1 ] || usage
    local sub="$1"
    shift
    case "$sub" in
        detect) detect_forge ;;
        ci-status | pr-state | threads-resolved | pr-for-branch)
            [ $# -ge 1 ] || usage
            run_op "$sub" "$1"
            ;;
        *) usage ;;
    esac
}

main "$@"
