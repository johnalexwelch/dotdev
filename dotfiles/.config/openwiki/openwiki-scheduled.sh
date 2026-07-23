#!/usr/bin/env bash
# Invariant: idempotent, host-agnostic openwiki doc refresh. Reads repos.conf,
# regenerates code docs per repo in a throwaway worktree (never touches the live
# checkout), and pushes an openwiki/update branch. Safe to run repeatedly and on
# any git host — GitHub PR creation is best-effort and skipped elsewhere.
# Driven by launchd (see com.alexwelch.openwiki.plist); missed runs fire on wake.
set -euo pipefail

# ponytail: launchd runs this with a bare PATH (no zshrc, no shell env) —
# add Homebrew + user bin dirs so openwiki/git/gh resolve.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/.local/bin:$PATH"

CONF="${OPENWIKI_REPOS_CONF:-$HOME/.config/openwiki/repos.conf}"
LOG="${OPENWIKI_LOG:-/tmp/openwiki-scheduled.log}"
BRANCH="openwiki/update"

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >>"$LOG"; }

command -v openwiki >/dev/null || {
    log "FATAL openwiki not on PATH"
    exit 127
}
[ -f "$HOME/.openwiki/.env" ] || {
    log "FATAL ~/.openwiki/.env missing — run 'openwiki --init'"
    exit 78
}
# ponytail: launchd doesn't inherit shell exports, so pull the API key from
# the untracked, chmod-600, outside-the-repo env file (never committed).
set -a
source "$HOME/.openwiki/.env"
set +a
[ -f "$CONF" ] || {
    log "no $CONF — nothing to do"
    exit 0
}

log "=== run start ==="
while IFS= read -r repo || [ -n "$repo" ]; do
    repo="${repo%%#*}"
    repo="${repo#"${repo%%[![:space:]]*}"}"
    repo="${repo%"${repo##*[![:space:]]}"}"
    [ -z "$repo" ] && continue
    repo="${repo/#\~/$HOME}"
    [ -d "$repo/.git" ] || {
        log "SKIP $repo (not a git repo)"
        continue
    }

    base="$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
    base="${base:-$(git -C "$repo" symbolic-ref --short HEAD)}"
    wt="$(mktemp -d)/wt"
    # ponytail: throwaway worktree off the live base ref; no clone, no checkout churn.
    if ! git -C "$repo" worktree add -q --detach "$wt" "$base" 2>>"$LOG"; then
        log "SKIP $repo (worktree add failed)"
        rm -rf "$(dirname "$wt")"
        continue
    fi

    # ponytail: a failed generation must never fall through to the "docs already
    # current" OK line — a crash leaves no diff, which is indistinguishable from
    # genuinely-current docs. Log ERROR and skip publish; cleanup still runs.
    if ! (cd "$wt" && openwiki code --update --print) >>"$LOG" 2>&1; then
        log "ERROR $repo generation failed (see above)"
        git -C "$repo" worktree remove --force "$wt" 2>>"$LOG" || true
        rm -rf "$(dirname "$wt")"
        continue
    fi
    # ponytail: openwiki treats its own scaffolded GH workflow as fair game to
    # revert hand-hardening (pinned actions, disabled cron, persist-credentials).
    # Restore it before diffing so a stray revert can never reach the PR, even
    # if the add-paths below ever widens. Upgrade: drop this once openwiki ships
    # a real exclude/ignore mechanism (checked, doesn't exist as of v0.1.2).
    git -C "$wt" checkout -- .github/workflows/openwiki-update.yml 2>/dev/null || true

    # ponytail: OpenWiki regenerates AGENTS.md/CLAUDE.md stubs and can wipe
    # content outside the OPENWIKI markers. Re-append the Agent Habits pointer
    # (durable habits live in docs/agents/habits.md) if the regen dropped it.
    # realpath: this script is reached via a stow symlink; logical dirname would
    # miss habits-pointer.md sitting next to the real script in dotfiles.
    _habits_ptr="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)/habits-pointer.md"
    if [ -f "$_habits_ptr" ]; then
        for _stub in AGENTS.md CLAUDE.md; do
            _stub_path="$wt/$_stub"
            [ -f "$_stub_path" ] || continue
            if ! grep -qF 'docs/agents/habits.md' "$_stub_path" 2>/dev/null; then
                printf '\n' >>"$_stub_path"
                cat "$_habits_ptr" >>"$_stub_path"
                log "RESTORED habits pointer -> $repo/$_stub"
            fi
        done
    fi

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
                gh -R "$(git -C "$repo" remote get-url origin)" pr view "$BRANCH" >/dev/null 2>&1 ||
                    (cd "$repo" && gh pr create --head "$BRANCH" --base "$base" \
                        --title "docs: update OpenWiki" --body "Automated OpenWiki doc update.") >>"$LOG" 2>&1 || true
            fi
        else
            log "LOCAL $repo committed to $BRANCH (no remote)"
        fi
    fi

    git -C "$repo" worktree remove --force "$wt" 2>>"$LOG" || true
    rm -rf "$(dirname "$wt")"
done <"$CONF"
log "=== run done ==="
