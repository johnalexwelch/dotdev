#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/test/test-commit-normalize.sh"
bash "$ROOT/test/test-tmux-dev.sh"
bash "$ROOT/test/test-sync-codex-skills.sh"
