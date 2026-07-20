#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/test/test-commit-normalize.sh"
bash "$ROOT/test/test-sync-codex-skills.sh"
bash "$ROOT/test/test-skill-suite-lint.sh"
bash "$ROOT/test/test-workflow-guard.sh"
