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
# Detection: `git config forge.type` (github|forgejo) wins when set; origin
# URLs containing github.com are github; ssh-style origins (scp-like or
# ssh://) resolve their host through `ssh -G` HostName so ~/.ssh/config
# aliases (git@github-personal:...) classify by destination, not alias
# spelling; any other origin URL is forgejo; no origin remote is none.
# FORGE_SSH_CONFIG substitutes the ssh config consulted (test seam).
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

# Extracts the ssh host from scp-like (user@host:path) and ssh:// origin
# URLs; prints nothing for other schemes (their hostname is already literal).
ssh_host_of() {
    local url="$1" host=""
    case "$url" in
        ssh://*)
            host="${url#ssh://}"
            host="${host%%/*}"
            host="${host##*@}"
            host="${host%%:*}"
            ;;
        *://*) ;;
        *@*:*)
            host="${url#*@}"
            host="${host%%:*}"
            ;;
    esac
    printf '%s' "$host"
}

# Prints the HostName ssh would actually connect to for a host alias.
# `ssh -G` only evaluates config — no network, no key exchange.
resolve_ssh_hostname() {
    local host="$1"
    if [ -n "${FORGE_SSH_CONFIG:-}" ]; then
        ssh -G -F "$FORGE_SSH_CONFIG" -- "$host" 2>/dev/null
    else
        ssh -G -- "$host" 2>/dev/null
    fi | awk '/^hostname /{print $2; exit}'
}

detect_forge() {
    local url override host resolved
    override="$(git config --get forge.type 2>/dev/null)" || override=""
    case "$override" in
        "") ;;
        github | forgejo)
            echo "$override"
            return 0
            ;;
        *) die "invalid forge.type: $override (expected github|forgejo)" ;;
    esac
    url="$(git remote get-url origin 2>/dev/null)" || url=""
    case "$url" in
        "")
            echo none
            return 0
            ;;
        *github.com*)
            echo github
            return 0
            ;;
    esac
    host="$(ssh_host_of "$url")"
    if [ -n "$host" ]; then
        resolved="$(resolve_ssh_hostname "$host")"
        case "$resolved" in
            github.com | *.github.com)
                echo github
                return 0
                ;;
        esac
    fi
    echo forgejo
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
    [ -n "${FORGE_TOKEN:-}" ] || die "FORGE_TOKEN not set for Forgejo API access (refusing to send an unauthenticated request)"
    # The token travels via a curl config read from stdin (-K -), never argv,
    # so it cannot leak through process listings (batch #5). curl config
    # quoting: a token containing '"' or a newline would break the config
    # line; forge tokens are URL-safe strings, so this is not reachable with
    # a real token.
    printf 'header = "Authorization: token %s"\n' "$FORGE_TOKEN" |
        curl -sSf -K - "${FORGE_URL%/}/api/v1$1"
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
    # detect_forge dies inside the substitution's subshell (e.g. invalid
    # forge.type); propagate that instead of cascading into bogus errors.
    forge="$(detect_forge)" || exit 1
    [ "$forge" != "none" ] || die "no origin remote; cannot dispatch $op"
    if [ -n "${FORGE_MOCK_DIR:-}" ]; then
        # Branch names may carry slashes (pr-for-branch feature/x); sanitize
        # so mock answers are flat files, never nested dirs (batch #8).
        local safe_pr="${pr//\//_}"
        local mock="$FORGE_MOCK_DIR/$forge-$op-$safe_pr"
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
