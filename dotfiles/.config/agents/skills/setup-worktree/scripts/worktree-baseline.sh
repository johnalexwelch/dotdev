#!/usr/bin/env bash
# worktree-baseline.sh — D-005: one testable cut/verify/emit interface for the
# Worktree Baseline Gate. Extracts base-branch resolution (per
# references/base-branch-policy.md), fetch --prune, stacked-parent ancestry
# checks, path/branch derivation, and env-file copy behind three subcommands
# so callers stop restating the procedure inline.
#
# Usage:
#   worktree-baseline.sh cut    --branch <name> --path <path> [--parent-branch <name> --parent-pr <n>]
#   worktree-baseline.sh verify --path <path> [--base <ref>] [--parent-branch <name>]
#     (--base is caller-trusted: it skips base re-resolution and the sidecar's
#      RESOLVED_BASE cross-check, and the PASS line names it caller-supplied)
#   worktree-baseline.sh emit   --path <path> [--branch <name> --base <ref> --preferred <ref> \
#                                --fallback-reason <reason> --stacked --parent-branch <name> --parent-pr <n>]
#
# Exit codes:
#   1  usage error
#   2  worktree not found (verify)
#   3  path already exists (cut)
#   4  branch already exists (cut)
#   5  working tree is dirty (verify)
#   6  ancestry check failed (verify)
#   7  base branch could not be resolved (neither origin/staging nor remote default)
#   8  parent branch does not exist (cut, stacked)
#   9  git worktree add failed
#  10  git fetch origin --prune failed (cut; verify degrades to a stale-base warning)
#  11  state sidecar does not match git ground truth (verify, emit)
#  12  worktree is in detached HEAD state (verify)

set -euo pipefail

ENV_FILES=(
    ".env"
    ".env.local"
    ".env.development"
    ".env.production"
    ".env.test"
    ".envrc"
    ".nvmrc"
    ".python-version"
    ".tool-versions"
    ".ruby-version"
    ".node-version"
)

die() {
    local code="$1"
    shift
    echo "Blocked: $*" >&2
    exit "$code"
}

usage() {
    echo "Usage: $0 {cut|verify|emit} [options]" >&2
    exit 1
}

# Resolve the workflow base branch per base-branch-policy.md:
#   1. git fetch origin --prune
#   2. prefer origin/staging when it exists
#   3. else resolve the remote default branch and use origin/<default>
#   4. else halt
#
# Sets the script-scope globals PREFERRED_BASE, RESOLVED_BASE,
# RESOLVED_BASE_REF, FALLBACK_REASON, STALE_BASE (true when the fetch was
# degraded, so the base may be stale), and FETCHED directly (rather than
# printing KEY=VALUE for a caller to eval) so shellcheck can see the
# assignment — an eval'd assignment is invisible to static analysis and
# trips SC2154 at every read site.
# Refs are checked and returned fully qualified (refs/remotes/origin/...):
# short-name resolution tries refs/tags/ and refs/heads/ before
# refs/remotes/, so a local tag or branch literally named "origin/staging"
# would otherwise shadow the remote-tracking ref and silently retarget the
# base. RESOLVED_BASE keeps the short display name for messages and state;
# RESOLVED_BASE_REF carries the qualified ref for ancestry/checkout use.
#
# allow_stale=true (verify) degrades a failed fetch to a loud warning and
# resolves from the existing remote-tracking refs — re-checking ancestry
# offline is still git ground truth, just possibly stale, and a hard stop
# here would brick every review gate on network loss. cut keeps the hard
# failure: cutting a new worktree from an unfetchable base is different.
resolve_base() {
    local dir="${1:-.}" allow_stale="${2:-false}"
    local fetch_ok=true
    if ! git -C "$dir" fetch origin --prune >/dev/null 2>&1; then
        if [ "$allow_stale" = "true" ]; then
            fetch_ok=false
            echo "WARNING: git fetch origin --prune failed; resolving base from existing remote-tracking refs (possibly stale)." >&2
        else
            die 10 "git fetch origin --prune failed."
        fi
    fi

    local preferred="origin/staging"
    local resolved="" resolved_ref="" fallback="not_applicable"

    if git -C "$dir" rev-parse --verify --quiet "refs/remotes/$preferred" >/dev/null 2>&1; then
        resolved="$preferred"
        resolved_ref="refs/remotes/$preferred"
    else
        # Default-branch detection: the remote's own answer (`remote show
        # origin`) is authoritative whenever the network works. The local
        # origin/HEAD symref is strictly an offline fallback — it is a plain
        # hand-settable pointer that git never refreshes on fetch, so it can
        # be retargeted to select a different base and it goes stale on
        # default-branch renames; it must never outrank a live remote.
        local default_branch=""
        if [ "$fetch_ok" = "true" ]; then
            default_branch="$(git -C "$dir" remote show origin 2>/dev/null | sed -n '/HEAD branch/s/.*: //p' || true)"
        fi
        if [ -z "$default_branch" ] || [ "$default_branch" = "(unknown)" ] ||
            ! git -C "$dir" rev-parse --verify --quiet "refs/remotes/origin/$default_branch" >/dev/null 2>&1; then
            default_branch="$(git -C "$dir" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/origin/||' || true)"
        fi
        if [ -n "$default_branch" ] && [ "$default_branch" != "(unknown)" ] &&
            git -C "$dir" rev-parse --verify --quiet "refs/remotes/origin/$default_branch" >/dev/null 2>&1; then
            resolved="origin/$default_branch"
            resolved_ref="refs/remotes/origin/$default_branch"
            fallback="origin/staging_absent"
        else
            die 7 "neither origin/staging nor a valid remote default branch ref could be resolved. Ask the user for the workflow base."
        fi
    fi

    PREFERRED_BASE="$preferred"
    RESOLVED_BASE="$resolved"
    RESOLVED_BASE_REF="$resolved_ref"
    FALLBACK_REASON="$fallback"
    if [ "$fetch_ok" = "true" ]; then
        STALE_BASE=false
    else
        STALE_BASE=true
    fi
    FETCHED=true
}

# Emit the exact WORKFLOW_BASE_GATE block plus WORKTREE_BASELINE_GATE or
# STACKED_WORKTREE_GATE line, matching the gate format documented in
# base-branch-policy.md and workflow-router/SKILL.md (workflow-deliver
# calls this script rather than hand-writing the lines).
emit_gates() {
    local branch="$1" path="$2" preferred="$3" resolved="$4" fallback="$5" \
        stacked="$6" parent_branch="$7" parent_pr="$8"

    echo "WORKFLOW_BASE_GATE:"
    echo "  preferred_base: $preferred"
    echo "  resolved_base: $resolved"
    echo "  fallback_reason: $fallback"
    echo "  fetched: true"

    if [ "$stacked" = "true" ]; then
        echo "STACKED_WORKTREE_GATE: $resolved -> $parent_branch -> $branch @ $path; parent_pr: #${parent_pr}; parent_gates: complete"
    else
        echo "WORKTREE_BASELINE_GATE: $resolved -> $branch @ $path"
    fi
}

# State lives as a sibling of the worktree directory, not inside it — a file
# inside the worktree would show up as untracked in `git status --porcelain`
# and make `verify` report a false-positive dirty tree.
state_file_path() {
    local path="$1"
    local parent base
    parent="$(cd "$(dirname "$path")" 2>/dev/null && pwd || dirname "$path")"
    base="$(basename "$path")"
    echo "$parent/.worktree-baseline.$base.state"
}

write_state() {
    local path="$1" branch="$2" preferred="$3" resolved="$4" fallback="$5" \
        stacked="$6" parent_branch="$7" parent_pr="$8"
    local state_file
    state_file="$(state_file_path "$path")"
    {
        echo "BRANCH=$branch"
        echo "WT_PATH=$path"
        echo "PREFERRED_BASE=$preferred"
        echo "RESOLVED_BASE=$resolved"
        echo "FALLBACK_REASON=$fallback"
        echo "STACKED=$stacked"
        echo "PARENT_BRANCH=$parent_branch"
        echo "PARENT_PR=$parent_pr"
    } >"$state_file"
}

# Load a previously-written state file into STATE_*-prefixed variables.
# Parsed strictly as KEY=VALUE for the known keys — never sourced. The file
# is hand-writable by anyone, so sourcing it would hand a forged sidecar
# arbitrary shell execution inside verify; any line that isn't a known
# KEY=VALUE is treated as tampering and fails loudly. The distinct STATE_
# namespace keeps sidecar values from ever aliasing resolve_base's globals
# (RESOLVED_BASE etc.), so no code-motion can quietly turn the sidecar back
# into the ancestry source. Every known key is required: omitting one must
# not let its cross-check pass vacuously.
STATE_KEYS=(BRANCH WT_PATH PREFERRED_BASE RESOLVED_BASE FALLBACK_REASON STACKED PARENT_BRANCH PARENT_PR)

# Declared at script scope so shellcheck sees an assignment for every read
# site — load_state's printf -v writes are invisible to static analysis
# (same rationale as resolve_base's direct global assignment).
STATE_BRANCH=""
STATE_WT_PATH=""
STATE_PREFERRED_BASE=""
STATE_RESOLVED_BASE=""
STATE_FALLBACK_REASON=""
STATE_STACKED=""
STATE_PARENT_BRANCH=""
STATE_PARENT_PR=""

load_state() {
    local path="$1"
    local state_file line key seen=" "
    state_file="$(state_file_path "$path")"
    [ -f "$state_file" ] || return 1
    for key in "${STATE_KEYS[@]}"; do
        printf -v "STATE_$key" '%s' ""
    done
    # Exact-match key whitelist, never substring/glob: a compound key like
    # "BRANCH WT_PATH" must die here, not reach printf -v (whose failure a
    # caller's if-guard would swallow, failing open).
    local k known
    while IFS= read -r line || [ -n "$line" ]; do
        [ -n "$line" ] || continue
        key="${line%%=*}"
        known=false
        for k in "${STATE_KEYS[@]}"; do
            if [ "$key" = "$k" ]; then
                known=true
                break
            fi
        done
        if [ "$known" = "true" ]; then
            [ "$key" != "$line" ] || die 11 "state file $state_file has an unrecognized line (no '='): $line"
            printf -v "STATE_$key" '%s' "${line#*=}"
            seen="$seen$key "
        else
            die 11 "state file $state_file has an unrecognized line: $line"
        fi
    done <"$state_file"
    for key in "${STATE_KEYS[@]}"; do
        case "$seen" in
            *" $key "*) ;;
            *) die 11 "state file $state_file is missing required key: $key" ;;
        esac
    done
    case "$STATE_STACKED" in
        true | false) ;;
        *) die 11 "state file $state_file has invalid STACKED value: '$STATE_STACKED' (must be true or false)" ;;
    esac
    return 0
}

copy_env_files() {
    local source_root="$1" dest="$2"
    local copied=()

    for f in "${ENV_FILES[@]}"; do
        if [ -f "$source_root/$f" ]; then
            cp "$source_root/$f" "$dest/$f" 2>/dev/null && copied+=("$f")
        fi
    done

    if [ -f "$source_root/.claude/settings.local.json" ] && [ -d "$dest/.claude" ]; then
        cp "$source_root/.claude/settings.local.json" "$dest/.claude/settings.local.json" &&
            copied+=(".claude/settings.local.json")
    fi

    if [ "${#copied[@]}" -gt 0 ]; then
        (
            IFS=,
            echo "Copied: ${copied[*]}"
        )
    else
        echo "Copied: none"
    fi
}

# Known artifact paths cut() intentionally copies into a fresh worktree.
# These are untracked by design (that's the whole point of copying them
# from the source checkout's working tree), so verify's dirty-check must
# not treat their presence as evidence of a dirty tree.
is_known_artifact() {
    local candidate="$1" p
    for p in "${ENV_FILES[@]}" ".claude/settings.local.json"; do
        [ "$candidate" = "$p" ] && return 0
    done
    return 1
}

# Filter `git status --porcelain` output, dropping untracked ("??") lines
# whose path is a known cut-copied artifact. Anything else — modified,
# staged, or genuinely unexpected untracked files — passes through so the
# dirty-check still catches real dirtiness.
filter_known_artifacts() {
    local input="$1" line status path
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        status="${line:0:2}"
        path="${line:3}"
        if [ "$status" = "??" ] && is_known_artifact "$path"; then
            continue
        fi
        printf '%s\n' "$line"
    done <<<"$input"
}

cmd_cut() {
    local branch="" path="" parent_branch="" parent_pr=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --branch)
                branch="$2"
                shift 2
                ;;
            --path)
                path="$2"
                shift 2
                ;;
            --parent-branch)
                parent_branch="$2"
                shift 2
                ;;
            --parent-pr)
                parent_pr="$2"
                shift 2
                ;;
            *) usage ;;
        esac
    done

    [ -n "$branch" ] && [ -n "$path" ] || usage

    # Absolutize a relative --path up front: everything downstream (sidecar
    # WT_PATH, gate lines, verify from another cwd) needs one canonical
    # spelling. A verbatim relative path pushed agents toward hand-patching
    # sidecars after the fact (the forged-baseline-adjacent pattern; #171
    # made verify recompute ground truth, so cut just does this itself).
    case "$path" in
        /*) ;;
        *) path="$PWD/$path" ;;
    esac

    if [ -e "$path" ]; then
        die 3 "path already exists: $path"
    fi

    if git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null 2>&1; then
        die 4 "branch '$branch' already exists. Choose a different branch name, or remove/resume the existing one."
    fi

    resolve_base
    # PREFERRED_BASE, RESOLVED_BASE, RESOLVED_BASE_REF, FALLBACK_REASON,
    # FETCHED now set. The qualified ref feeds git; the short name feeds
    # messages and state.

    local stacked="false"
    local git_base_ref="$RESOLVED_BASE_REF"

    if [ -n "$parent_branch" ]; then
        stacked="true"
        if ! git rev-parse --verify --quiet "$parent_branch" >/dev/null 2>&1; then
            die 8 "parent branch '$parent_branch' does not exist."
        fi
        git_base_ref="$parent_branch"
    fi

    local source_root
    source_root="$(git rev-parse --show-toplevel)"

    if ! git worktree add -b "$branch" "$path" "$git_base_ref" >/dev/null 2>&1; then
        die 9 "git worktree add failed for branch '$branch' at '$path' from '$git_base_ref'."
    fi

    # The directory exists now: collapse any lexical dot-dot segments from
    # the up-front join so the recorded WT_PATH and gate lines are canonical.
    path="$(cd "$path" && pwd)"

    copy_env_files "$source_root" "$path"

    write_state "$path" "$branch" "$PREFERRED_BASE" "$RESOLVED_BASE" "$FALLBACK_REASON" \
        "$stacked" "$parent_branch" "$parent_pr"

    echo "Worktree created at $path on branch $branch."
    emit_gates "$branch" "$path" "$PREFERRED_BASE" "$RESOLVED_BASE" "$FALLBACK_REASON" \
        "$stacked" "$parent_branch" "$parent_pr"
}

cmd_verify() {
    local path="" base_override="" parent_branch_override=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --path)
                path="$2"
                shift 2
                ;;
            --base)
                base_override="$2"
                shift 2
                ;;
            --parent-branch)
                parent_branch_override="$2"
                shift 2
                ;;
            *) usage ;;
        esac
    done

    [ -n "$path" ] || usage

    if ! git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        die 2 "worktree not found at $path"
    fi

    local dirty
    dirty="$(filter_known_artifacts "$(git -C "$path" status --porcelain)")"
    if [ -n "$dirty" ]; then
        die 5 "worktree at $path is dirty:
$dirty"
    fi

    # Ground truth comes from git, never from the sidecar: an explicit --base
    # wins (caller-trusted, named as such in the PASS line), else the workflow
    # base is re-resolved per base-branch-policy.md. The sidecar used to pick
    # the ancestry target here, which let a hand-written one steer verify at
    # any ref the checkout happened to descend from (PR #166 post_mortem,
    # forged-baseline pattern).
    local effective_base="$base_override" effective_base_ref="$base_override"
    if [ -z "$effective_base" ]; then
        resolve_base "$path" true
        effective_base="$RESOLVED_BASE"
        effective_base_ref="$RESOLVED_BASE_REF"
    fi

    if ! git -C "$path" merge-base --is-ancestor "$effective_base_ref" HEAD 2>/dev/null; then
        die 6 "worktree at $path is not a descendant of $effective_base"
    fi

    local actual_branch
    actual_branch="$(git -C "$path" rev-parse --abbrev-ref HEAD)"
    if [ "$actual_branch" = "HEAD" ]; then
        die 12 "worktree at $path is in detached HEAD state; check out the workflow branch"
    fi

    # The sidecar is a cross-check only. A mismatch against what git actually
    # has is a loud failure, not a value to prefer — its only trusted role
    # left is carrying the stacked-parent relationship, and even that ref is
    # then ancestry-checked against real history below. The RESOLVED_BASE
    # cross-check is skipped under an explicit --base: the caller has named
    # the ground truth, so a recorded-base difference is not tampering.
    local stacked="false" parent_branch=""
    if load_state "$path"; then
        if [ "$STATE_BRANCH" != "$actual_branch" ]; then
            die 11 "state file for $path does not match git ground truth: BRANCH is '$STATE_BRANCH' but the checked-out branch is '$actual_branch'"
        fi
        # WT_PATH pins the sidecar to this worktree so a complete, internally
        # valid sidecar cut for another worktree can't be transplanted here
        # (which would silently swap in that cut's stacked/parent fields).
        # Compare canonicalized paths — trailing slashes and relative
        # spellings of the same directory are the same worktree.
        local canon_path canon_state_path
        canon_path="$(cd "$path" && pwd -P)"
        canon_state_path="$(cd "$STATE_WT_PATH" 2>/dev/null && pwd -P || printf '%s' "$STATE_WT_PATH")"
        if [ "$canon_state_path" != "$canon_path" ]; then
            die 11 "state file for $path does not match the verified worktree: WT_PATH is '$STATE_WT_PATH' but the worktree being verified is '$canon_path'"
        fi
        if [ -z "$base_override" ] && [ "$STATE_RESOLVED_BASE" != "$effective_base" ]; then
            die 11 "state file for $path does not match git ground truth: RESOLVED_BASE is '$STATE_RESOLVED_BASE' but the resolved workflow base is '$effective_base'"
        fi
        stacked="$STATE_STACKED"
        parent_branch="$STATE_PARENT_BRANCH"
    fi

    # An explicit --parent-branch on the command line always wins: it forces
    # an ancestry check against that branch regardless of what (if anything)
    # the state file recorded. This lets verify be used standalone, without a
    # prior cut, against a caller-supplied parent.
    local parent_to_check=""
    if [ -n "$parent_branch_override" ]; then
        parent_to_check="$parent_branch_override"
    elif [ "$stacked" = "true" ] && [ -n "$parent_branch" ]; then
        parent_to_check="$parent_branch"
    fi

    # The staleness marker must live in the stdout PASS line, not only the
    # stderr warning: callers (ledger.sh) record stdout evidence on success
    # and discard stderr, so a stale pass must be visibly stale in evidence.
    local base_label="$effective_base"
    if [ -n "$base_override" ]; then
        base_label="caller-supplied base $base_override"
    elif [ "${STALE_BASE:-false}" = "true" ]; then
        base_label="$effective_base (possibly stale: fetch failed)"
    fi

    if [ -n "$parent_to_check" ]; then
        if ! git -C "$path" merge-base --is-ancestor "$parent_to_check" HEAD 2>/dev/null; then
            die 6 "worktree at $path is not a descendant of $parent_to_check"
        fi
        echo "PASS: $path is clean, descends from $base_label, and descends from parent $parent_to_check"
    else
        echo "PASS: $path is clean and descends from $base_label"
    fi
}

cmd_emit() {
    local path="" branch="" base="" preferred="" fallback="" \
        stacked="" parent_branch="" parent_pr=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --path)
                path="$2"
                shift 2
                ;;
            --branch)
                branch="$2"
                shift 2
                ;;
            --base)
                base="$2"
                shift 2
                ;;
            --preferred)
                preferred="$2"
                shift 2
                ;;
            --fallback-reason)
                fallback="$2"
                shift 2
                ;;
            --stacked)
                stacked="true"
                shift
                ;;
            --parent-branch)
                parent_branch="$2"
                shift 2
                ;;
            --parent-pr)
                parent_pr="$2"
                shift 2
                ;;
            *) usage ;;
        esac
    done

    [ -n "$path" ] || usage

    if load_state "$path"; then
        branch="${branch:-$STATE_BRANCH}"
        base="${base:-$STATE_RESOLVED_BASE}"
        preferred="${preferred:-$STATE_PREFERRED_BASE}"
        fallback="${fallback:-$STATE_FALLBACK_REASON}"
        stacked="${stacked:-$STATE_STACKED}"
        parent_branch="${parent_branch:-$STATE_PARENT_BRANCH}"
        parent_pr="${parent_pr:-$STATE_PARENT_PR}"
    fi

    preferred="${preferred:-origin/staging}"
    fallback="${fallback:-not_applicable}"
    stacked="${stacked:-false}"

    [ -n "$branch" ] && [ -n "$base" ] || usage

    emit_gates "$branch" "$path" "$preferred" "$base" "$fallback" "$stacked" "$parent_branch" "$parent_pr"
}

main() {
    [ $# -ge 1 ] || usage
    local sub="$1"
    shift
    case "$sub" in
        cut) cmd_cut "$@" ;;
        verify) cmd_verify "$@" ;;
        emit) cmd_emit "$@" ;;
        *) usage ;;
    esac
}

main "$@"
