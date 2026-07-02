#!/bin/bash
# Thin wrapper — canonical setup is install.sh.
# Kept for muscle memory; exec avoids double-process overhead.
# ponytail: security-init.sh is per-repo (scans cwd) — run manually inside each repo
exec "$(dirname "${BASH_SOURCE[0]}")/../install.sh" "$@"
