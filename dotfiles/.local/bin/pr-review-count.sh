#!/bin/bash
# pr-review-count.sh
# Key 15: prints the number of open PRs waiting on my review — ambient
# hidden state on the deck. Point a Stateful Executor key here with a
# few-minute poll and matchers on the number.
#
# Requires: gh CLI (authenticated).

set -uo pipefail

# Stream Deck invokes scripts without an interactive shell — pin PATH.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

gh search prs --review-requested @me --state open --json number --jq 'length' 2>/dev/null || echo "-"
