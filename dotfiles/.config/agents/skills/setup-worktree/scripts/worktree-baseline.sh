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
#  10  git fetch origin --prune failed

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
  local code="$1"; shift
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
# FALLBACK_REASON, FETCHED directly (rather than printing KEY=VALUE for a
# caller to eval) so shellcheck can see the assignment — an eval'd
# assignment is invisible to static analysis and trips SC2154 at every
# read site.
resolve_base() {
  if ! git fetch origin --prune >/dev/null 2>&1; then
    die 10 "git fetch origin --prune failed."
  fi

  local preferred="origin/staging"
  local resolved="" fallback="not_applicable"

  if git rev-parse --verify --quiet "$preferred" >/dev/null 2>&1; then
    resolved="$preferred"
  else
    local default_branch
    default_branch="$(git remote show origin | sed -n '/HEAD branch/s/.*: //p')"
    if [ -n "$default_branch" ] && [ "$default_branch" != "(unknown)" ] \
      && git rev-parse --verify --quiet "origin/$default_branch" >/dev/null 2>&1; then
      resolved="origin/$default_branch"
      fallback="origin/staging_absent"
    else
      die 7 "neither origin/staging nor a valid remote default branch ref could be resolved. Ask the user for the workflow base."
    fi
  fi

  PREFERRED_BASE="$preferred"
  RESOLVED_BASE="$resolved"
  FALLBACK_REASON="$fallback"
  FETCHED=true
}

# Emit the exact WORKFLOW_BASE_GATE block plus WORKTREE_BASELINE_GATE or
# STACKED_WORKTREE_GATE line, matching the format hand-written by existing
# callers (base-branch-policy.md, workflow-build-one/SKILL.md,
# workflow-router/SKILL.md).
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

# Load a previously-written state file into the current shell's variables.
# Safe: the file is our own generated KEY=VALUE output, not external input.
load_state() {
  local path="$1"
  local state_file
  state_file="$(state_file_path "$path")"
  [ -f "$state_file" ] || return 1
  # shellcheck disable=SC1090
  . "$state_file"
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
    cp "$source_root/.claude/settings.local.json" "$dest/.claude/settings.local.json" \
      && copied+=(".claude/settings.local.json")
  fi

  if [ "${#copied[@]}" -gt 0 ]; then
    (IFS=,; echo "Copied: ${copied[*]}")
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
      --branch) branch="$2"; shift 2 ;;
      --path) path="$2"; shift 2 ;;
      --parent-branch) parent_branch="$2"; shift 2 ;;
      --parent-pr) parent_pr="$2"; shift 2 ;;
      *) usage ;;
    esac
  done

  [ -n "$branch" ] && [ -n "$path" ] || usage

  if [ -e "$path" ]; then
    die 3 "path already exists: $path"
  fi

  if git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null 2>&1; then
    die 4 "branch '$branch' already exists. Choose a different branch name, or remove/resume the existing one."
  fi

  resolve_base
  # PREFERRED_BASE, RESOLVED_BASE, FALLBACK_REASON, FETCHED now set.

  local stacked="false"
  local git_base_ref="$RESOLVED_BASE"

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
      --path) path="$2"; shift 2 ;;
      --base) base_override="$2"; shift 2 ;;
      --parent-branch) parent_branch_override="$2"; shift 2 ;;
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

  local resolved_base="$base_override" stacked="false" parent_branch=""
  if load_state "$path"; then
    resolved_base="${resolved_base:-$RESOLVED_BASE}"
    stacked="${STACKED:-false}"
    parent_branch="${PARENT_BRANCH:-}"
  fi

  # An explicit --parent-branch on the command line always wins: it forces
  # an ancestry check against that branch regardless of what (if anything)
  # the state file recorded. This lets verify be used standalone, without a
  # prior cut, against a caller-supplied parent.
  local ancestry_base
  if [ -n "$parent_branch_override" ]; then
    ancestry_base="$parent_branch_override"
  elif [ "$stacked" = "true" ] && [ -n "$parent_branch" ]; then
    ancestry_base="$parent_branch"
  else
    ancestry_base="$resolved_base"
  fi

  [ -n "$ancestry_base" ] || die 1 "no base ref available to verify ancestry against; pass --base or --parent-branch."

  if ! git -C "$path" merge-base --is-ancestor "$ancestry_base" HEAD 2>/dev/null; then
    die 6 "worktree at $path is not a descendant of $ancestry_base"
  fi

  echo "PASS: $path is clean and descends from $ancestry_base"
}

cmd_emit() {
  local path="" branch="" base="" preferred="" fallback="" \
    stacked="" parent_branch="" parent_pr=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --path) path="$2"; shift 2 ;;
      --branch) branch="$2"; shift 2 ;;
      --base) base="$2"; shift 2 ;;
      --preferred) preferred="$2"; shift 2 ;;
      --fallback-reason) fallback="$2"; shift 2 ;;
      --stacked) stacked="true"; shift ;;
      --parent-branch) parent_branch="$2"; shift 2 ;;
      --parent-pr) parent_pr="$2"; shift 2 ;;
      *) usage ;;
    esac
  done

  [ -n "$path" ] || usage

  if load_state "$path"; then
    branch="${branch:-$BRANCH}"
    base="${base:-$RESOLVED_BASE}"
    preferred="${preferred:-$PREFERRED_BASE}"
    fallback="${fallback:-$FALLBACK_REASON}"
    stacked="${stacked:-$STACKED}"
    parent_branch="${parent_branch:-$PARENT_BRANCH}"
    parent_pr="${parent_pr:-$PARENT_PR}"
  fi

  preferred="${preferred:-origin/staging}"
  fallback="${fallback:-not_applicable}"
  stacked="${stacked:-false}"

  [ -n "$branch" ] && [ -n "$base" ] || usage

  emit_gates "$branch" "$path" "$preferred" "$base" "$fallback" "$stacked" "$parent_branch" "$parent_pr"
}

main() {
  [ $# -ge 1 ] || usage
  local sub="$1"; shift
  case "$sub" in
    cut) cmd_cut "$@" ;;
    verify) cmd_verify "$@" ;;
    emit) cmd_emit "$@" ;;
    *) usage ;;
  esac
}

main "$@"
