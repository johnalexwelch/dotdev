#!/usr/bin/env bash
# Invariant: idempotent, host-agnostic openwiki doc refresh. Reads repos.conf,
# regenerates code docs per repo in a throwaway worktree (never touches the live
# checkout), and pushes an openwiki/update branch. Safe to run repeatedly and on
# any git host — GitHub PR creation is best-effort and skipped elsewhere.
# Driven by launchd (see com.alexwelch.openwiki.plist); missed runs fire on wake.
set -euo pipefail

CONF="${OPENWIKI_REPOS_CONF:-$HOME/.config/openwiki/repos.conf}"
LOG="${OPENWIKI_LOG:-/tmp/openwiki-scheduled.log}"
BRANCH="openwiki/update"

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >>"$LOG"; }

command -v openwiki >/dev/null || { log "FATAL openwiki not on PATH"; exit 127; }
[ -f "$HOME/.openwiki/.env" ] || { log "FATAL ~/.openwiki/.env missing — run 'openwiki --init'"; exit 78; }
[ -f "$CONF" ] || { log "no $CONF — nothing to do"; exit 0; }

log "=== run start ==="
while IFS= read -r repo || [ -n "$repo" ]; do
  repo="${repo%%#*}"; repo="${repo#"${repo%%[![:space:]]*}"}"; repo="${repo%"${repo##*[![:space:]]}"}"
  [ -z "$repo" ] && continue
  repo="${repo/#\~/$HOME}"
  [ -d "$repo/.git" ] || { log "SKIP $repo (not a git repo)"; continue; }

  base="$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  base="${base:-$(git -C "$repo" symbolic-ref --short HEAD)}"
  wt="$(mktemp -d)/wt"
  # ponytail: throwaway worktree off the live base ref; no clone, no checkout churn.
  if ! git -C "$repo" worktree add -q --detach "$wt" "$base" 2>>"$LOG"; then
    log "SKIP $repo (worktree add failed)"; rm -rf "$(dirname "$wt")"; continue
  fi

  ( cd "$wt" && openwiki code --update --print ) >>"$LOG" 2>&1 || log "WARN $repo openwiki exited nonzero"

  if [ -z "$(git -C "$wt" status --porcelain)" ]; then
    log "OK   $repo docs already current"
  else
    git -C "$wt" add -A openwiki AGENTS.md CLAUDE.md 2>/dev/null || true
    git -C "$wt" commit -q -m "docs: update OpenWiki" || true
    git -C "$wt" branch -f "$BRANCH" HEAD
    if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
      if git -C "$wt" push -f -q origin "$BRANCH" 2>>"$LOG"; then log "PUSHED $repo -> $BRANCH"; else log "WARN $repo push failed"; fi
      # ponytail: GitHub PR is best-effort; drops silently on non-GitHub hosts.
      if command -v gh >/dev/null && git -C "$repo" remote get-url origin | grep -qi github; then
        gh -R "$(git -C "$repo" remote get-url origin)" pr view "$BRANCH" >/dev/null 2>&1 \
          || ( cd "$repo" && gh pr create --head "$BRANCH" --base "$base" \
                 --title "docs: update OpenWiki" --body "Automated OpenWiki doc update." ) >>"$LOG" 2>&1 || true
      fi
    else
      log "LOCAL $repo committed to $BRANCH (no remote)"
    fi
  fi

  git -C "$repo" worktree remove --force "$wt" 2>>"$LOG" || true
  rm -rf "$(dirname "$wt")"
done <"$CONF"
log "=== run done ==="
