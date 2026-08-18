#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Auto-discover suites: every test/test-*.sh runs, no hand-maintained list.
# A registry line per suite was a standing merge-conflict magnet whenever
# parallel lanes each added a suite (bitten 2026-08-18, PR #160 vs #156).
found=0
for suite in "$ROOT"/test/test-*.sh; do
    [ -f "$suite" ] || continue
    found=1
    bash "$suite"
done
[ "$found" -eq 1 ] || {
    echo "no test suites found under $ROOT/test" >&2
    exit 1
}
