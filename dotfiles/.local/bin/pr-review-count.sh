#!/bin/bash
# pr-review-count.sh
# Key 15: prints the number of open PRs waiting on my review — ambient
# hidden state on the deck. Point a Stateful Executor key here with a
# few-minute poll and matchers on the number.
#
# Requires: gh CLI (authenticated).

# Stream Deck invokes scripts without an interactive shell — load deck
# config (DOJO_REPO_DIR) and pin PATH. Sourced before `set -u` so an unset
# reference in the hand-authored file degrades instead of aborting.
# shellcheck disable=SC1090
[[ -f "$HOME/.streamdeck" ]] && source "$HOME/.streamdeck"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

set -uo pipefail

# The local gh is a two-account routing shim keyed on the cwd's origin, and
# the deck's cwd is arbitrary — cd somewhere deterministic so @me always
# resolves to the work account. Personal-repo review requests are out of
# scope for this key.
cd "${DOJO_REPO_DIR:-$HOME/dojo}" 2>/dev/null || cd "$HOME" || exit 1

gh search prs --review-requested @me --state open --json number --jq 'length' 2>/dev/null || echo "-"
