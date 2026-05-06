#!/usr/bin/env bash
# Install / refresh GitHub CLI extensions used by this dotfiles setup.
# Idempotent: skips already-installed extensions, upgrades when re-run.

set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found. Install it first (see Brewfile)." >&2
    exit 1
fi

# Owner/repo of each extension we depend on.
extensions=(
    "dlvhdr/gh-dash"
    "dlvhdr/gh-enhance"
)

installed_list="$(gh extension list 2>/dev/null || true)"

for ext in "${extensions[@]}"; do
    short_name="${ext##*/}"          # e.g. gh-dash
    invoke_name="${short_name#gh-}"  # e.g. dash

    if printf '%s\n' "$installed_list" | grep -qE "[[:space:]]${ext}[[:space:]]"; then
        echo "↻ Upgrading gh ${invoke_name} (${ext})"
        gh extension upgrade "${invoke_name}" || true
    else
        echo "+ Installing gh ${invoke_name} (${ext})"
        gh extension install "${ext}"
    fi
done

echo "GitHub CLI extensions ready."
