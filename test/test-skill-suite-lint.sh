#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/dotfiles/.config/agents/skills/lint-skill-suite.sh"
TMPDIR_BASE=$(mktemp -d)
PASS=0
FAIL=0

cleanup() {
    rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

# make_skill <root> <name> [layer]
# layer defaults to "orchestrator"; pass "" to omit the layer line entirely.
make_skill() {
    local root="$1"
    local name="$2"
    local layer="${3-orchestrator}"
    local layer_line=""

    if [ -n "$layer" ]; then
        layer_line="layer: $layer
"
    fi
    mkdir -p "$root/$name"
    cat >"$root/$name/SKILL.md" <<EOF
---
name: $name
${layer_line}description: test skill
---

# $name

## Contract

Consumes: test input
Produces: test output
Requires: none
Side effects: none
Human gates: none
EOF
}

assert_contains() {
    local name="$1"
    local haystack="$2"
    local needle="$3"

    if grep -Fq "$needle" <<<"$haystack"; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    expected output to contain: $needle"
        echo "    output was:"
        echo "$haystack"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local name="$1"
    local haystack="$2"
    local needle="$3"

    if grep -Fq "$needle" <<<"$haystack"; then
        echo "  FAIL: $name"
        echo "    expected output not to contain: $needle"
        echo "    output was:"
        echo "$haystack"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    fi
}

echo "=== Skill suite lint tests ==="
echo ""

source="$TMPDIR_BASE/source"
runtime="$TMPDIR_BASE/runtime"
allowlist="$TMPDIR_BASE/codex-runtime-allowlist.txt"
mkdir -p "$source" "$runtime"
make_skill "$source" active
make_skill "$runtime" active
make_skill "$runtime" allowed-runtime-only
make_skill "$runtime" stale-runtime-only
printf 'allowed-runtime-only\n' >"$allowlist"

set +e
output=$(CHECK_CODEX_RUNTIME=1 CODEX_SKILLS_DIR="$runtime" CODEX_RUNTIME_ALLOWLIST="$allowlist" "$SCRIPT" "$source" 2>&1)
status=$?
set -e

if [ "$status" -ne 0 ]; then
    echo "  PASS: lint fails for unlisted runtime-only skill"
    PASS=$((PASS + 1))
else
    echo "  FAIL: lint fails for unlisted runtime-only skill"
    echo "    expected non-zero exit"
    echo "    output was:"
    echo "$output"
    FAIL=$((FAIL + 1))
fi
assert_contains "lint warns for allowlisted runtime-only skill" "$output" \
    "WARN: Codex runtime has allowlisted runtime-only skill: allowed-runtime-only"
assert_contains "lint reports unlisted runtime-only skill" "$output" \
    "FAIL: Codex runtime has skill not present in active source: stale-runtime-only"
assert_not_contains "lint does not fail allowlisted runtime-only skill" "$output" \
    "FAIL: Codex runtime has skill not present in active source: allowed-runtime-only"

rm -rf "$runtime/stale-runtime-only"
output=$(CHECK_CODEX_RUNTIME=1 CODEX_SKILLS_DIR="$runtime" CODEX_RUNTIME_ALLOWLIST="$allowlist" "$SCRIPT" "$source" 2>&1)
assert_contains "lint succeeds with only allowlisted runtime-only skill" "$output" \
    "skill-suite lint: failures=0 warnings=1"

echo ""
echo "=== Layer rules (D-006 #12) ==="
echo ""

layers="$TMPDIR_BASE/layers"
mkdir -p "$layers"
make_skill "$layers" tagged-orchestrator
make_skill "$layers" untagged ""
make_skill "$layers" judgment-clean judgment
make_skill "$layers" judgment-stamper judgment
printf '\nRun `ledger.sh stamp review` at the gate.\n' >>"$layers/judgment-stamper/SKILL.md"
make_skill "$layers" kernel-no-scripts kernel
make_skill "$layers" kernel-with-scripts kernel
mkdir -p "$layers/kernel-with-scripts/scripts"
make_skill "$layers" mislabeled sideways

set +e
output=$("$SCRIPT" "$layers" 2>&1)
status=$?
set -e

if [ "$status" -ne 0 ]; then
    echo "  PASS: lint fails when tagged skills violate layer rules"
    PASS=$((PASS + 1))
else
    echo "  FAIL: lint fails when tagged skills violate layer rules"
    echo "    expected non-zero exit"
    echo "    output was:"
    echo "$output"
    FAIL=$((FAIL + 1))
fi
assert_contains "missing layer is warn-mode" "$output" \
    "WARN: untagged lacks layer frontmatter"
assert_contains "judgment skill with ledger.sh stamp fails" "$output" \
    "FAIL: judgment-stamper is layer: judgment but references ledger.sh stamp"
assert_contains "kernel skill without scripts/ fails" "$output" \
    "FAIL: kernel-no-scripts is layer: kernel but has no scripts/ directory"
assert_contains "unknown layer value fails" "$output" \
    "FAIL: mislabeled has unknown layer: sideways"
assert_not_contains "clean judgment skill does not fail" "$output" \
    "FAIL: judgment-clean"
assert_not_contains "kernel skill with scripts/ does not fail" "$output" \
    "FAIL: kernel-with-scripts"
assert_not_contains "tagged orchestrator gets no layer warn" "$output" \
    "WARN: tagged-orchestrator lacks layer frontmatter"
assert_not_contains "missing layer alone is not a failure" "$output" \
    "FAIL: untagged"

rm -rf "$layers/untagged" "$layers/judgment-stamper" "$layers/kernel-no-scripts" "$layers/mislabeled"
output=$("$SCRIPT" "$layers" 2>&1)
assert_contains "fully tagged, rule-clean tree lints green" "$output" \
    "skill-suite lint: failures=0 warnings=0"

echo ""
echo "=== Tombstone revival check (D-006 #11; planning-lane consolidation 2026-08-19) ==="
echo ""

tombs="$TMPDIR_BASE/tombs"
mkdir -p "$tombs"
# Revived under a tombstoned name with no disable-model-invocation at all.
make_skill "$tombs" execute-phase
# Tombstoned name with the key present but not 'true' — the value-blind trap.
mkdir -p "$tombs/design-plan"
cat >"$tombs/design-plan/SKILL.md" <<'EOF'
---
name: design-plan
disable-model-invocation: false
description: test tombstone with false value
---

# design-plan — superseded
EOF
# Valid tombstone: key present and true.
mkdir -p "$tombs/workflow-debug"
cat >"$tombs/workflow-debug/SKILL.md" <<'EOF'
---
name: workflow-debug
disable-model-invocation: true
description: test tombstone
---

# workflow-debug — superseded
EOF

set +e
output=$("$SCRIPT" "$tombs" 2>&1)
status=$?
set -e

if [ "$status" -ne 0 ]; then
    echo "  PASS: lint fails when tombstoned names are revived"
    PASS=$((PASS + 1))
else
    echo "  FAIL: lint fails when tombstoned names are revived"
    echo "    expected non-zero exit"
    echo "    output was:"
    echo "$output"
    FAIL=$((FAIL + 1))
fi
assert_contains "revived tombstone without the key fails" "$output" \
    "FAIL: execute-phase is a tombstone but disable-model-invocation is not 'true'"
assert_contains "tombstone with disable-model-invocation: false fails" "$output" \
    "FAIL: design-plan is a tombstone but disable-model-invocation is not 'true'"
assert_not_contains "valid tombstone (true) does not fail" "$output" \
    "FAIL: workflow-debug"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
