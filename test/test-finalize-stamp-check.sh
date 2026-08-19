#!/usr/bin/env bash
set -uo pipefail

# Red-first suite for the Phase 5a finalize-stamp CI check (D-006 #6 follow-up:
# closes the server-side auto-merge bypass observed live on PR #167 — the local
# merge-gate hook never sees a server-side merge).
#
# Contract under test:
#   - `ledger.sh check-snapshot <gate>`: CI-side gate check against the
#     COMMITTED snapshot (docs/executions/state.yaml) — no live state needed.
#     Freshness is the kernel's content-verified fresh_since (single
#     implementation): the stamp's head_sha must be ancestor-or-equal of HEAD
#     and every commit after it must touch ONLY the snapshot file, verified by
#     diff-tree contents, never by subject. Malformed snapshots are exit 6.
#   - `scripts/finalize-stamp-check.sh`: the local script the CI job calls.
#     Exemptions (pass-with-note): repo not opted in (no docs/executions/),
#     head refs matching renovate/* or dependabot/*, docs-only diffs vs --base
#     (docs/* minus docs/executions/*, plus root-level *.md — nested *.md
#     outside docs/ is the skills corpus and stays gated), empty diffs.
#     Overridden stamps PASS but the override reason is annotated into the
#     summary. Kernel environment breakage (ledger exit 10) warn-permits with
#     an ERROR note. Everything else requires a fresh finalize stamp (exit 1).
#   - Workflow wiring: .github/workflows/ci.yml parses as YAML and carries a
#     `finalize-stamp` job that checks out the PR head with full history and
#     calls the script from a step with step-level continue-on-error (soak
#     week — REQUIRED-shaped but non-blocking; the flip plan mirrors
#     routing-eval.yml, whose continue-on-error sits at job level instead).
#     NOTE for the post-soak flip: the wiring test asserts continue-on-error
#     is True, so dropping it will red this suite until that assertion is
#     inverted — deliberate, so the flip cannot happen silently.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEDGER="$ROOT/dotfiles/.config/agents/skills/workflow-ledger/scripts/ledger.sh"
CHECK="$ROOT/scripts/finalize-stamp-check.sh"
CI_YML="$ROOT/.github/workflows/ci.yml"
TMPDIR_BASE=$(mktemp -d)
PASS=0
FAIL=0
OUT=""
STATUS=0

cleanup() {
    rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

assert_status() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" -eq "$expected" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    expected exit $expected, got $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local name="$1" haystack="$2" needle="$3"
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
    local name="$1" haystack="$2" needle="$3"
    if ! grep -Fq "$needle" <<<"$haystack"; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    expected output to NOT contain: $needle"
        echo "    output was:"
        echo "$haystack"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_exists() {
    local name="$1" path="$2"
    if [ -f "$path" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    MISSING: $path"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_contains() {
    local name="$1" path="$2" needle="$3"
    if [ -f "$path" ] && grep -Fq "$needle" "$path"; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        if [ -f "$path" ]; then
            echo "    expected $path to contain: $needle"
        else
            echo "    MISSING: $path"
        fi
        FAIL=$((FAIL + 1))
    fi
}

# Run ledger.sh from inside a repo; captures OUT and STATUS.
run_ledger() {
    local dir="$1"
    shift
    OUT="$(cd "$dir" && bash "$LEDGER" "$@" 2>&1)"
    STATUS=$?
}

# Run finalize-stamp-check.sh from inside a repo; captures OUT and STATUS.
run_check() {
    local dir="$1"
    shift
    OUT="$(cd "$dir" && bash "$CHECK" "$@" 2>&1)"
    STATUS=$?
}

commit_all() {
    local dir="$1" msg="$2"
    git -C "$dir" add -A
    git -C "$dir" commit -q -m "$msg"
}

new_repo() {
    local name="$1"
    local repo="$TMPDIR_BASE/$name"
    mkdir -p "$repo/docs/executions" "$repo/src"
    git init -q -b main "$repo"
    git -C "$repo" config user.email "t@example.com"
    git -C "$repo" config user.name "Test"
    echo "opted-in" >"$repo/docs/executions/.gitkeep"
    echo "print('code')" >"$repo/src/app.py"
    commit_all "$repo" "chore: seed"
    printf '%s' "$repo"
}

# Hand-craft a schema-valid committed snapshot carrying a finalize stamp at
# the given sha. Legitimate here: check-snapshot treats the snapshot as
# untrusted input (that is the point of the CI-side check), so the tests
# exercise the reader, not the writer.
write_snapshot() {
    local repo="$1" sha="$2" override_active="${3:-false}" reason="${4:-}"
    mkdir -p "$repo/docs/executions"
    cat >"$repo/docs/executions/state.yaml" <<EOF
run_id: test-run
workflow: workflow-deliver
kind: skill
budget: multi-lane
status: active
next: ''
updated: '2026-08-18T00:00:00+00:00'
steps:
- id: implement
  required: true
  status: completed
  evidence: test evidence
stamps:
  finalize:
    head_sha: $sha
    timestamp: '2026-08-18T00:00:00+00:00'
    gate_type: reviewer-validation
    provenance: agent
    checked:
      ci: green
    attested:
      pr_number: '999'
    override:
      active: $override_active
      reason: "$reason"
      timestamp: ''
overrides: []
EOF
}

commit_snapshot_only() {
    local repo="$1"
    git -C "$repo" add -- docs/executions/state.yaml
    git -C "$repo" commit -q -m "chore(ledger): stamp finalize" -- docs/executions/state.yaml
}

echo "=== finalize-stamp-check tests ==="
echo ""

assert_file_exists "finalize-stamp-check.sh exists at spec'd path" "$CHECK"

# --- ledger.sh check-snapshot: committed-snapshot gate check (no live state) ---
repoA=$(new_repo cs_missing)
run_ledger "$repoA" check-snapshot finalize
assert_status "check-snapshot without snapshot exits 1" 1 "$STATUS"
assert_contains "check-snapshot without snapshot says MISSING" "$OUT" "MISSING"

repoB=$(new_repo cs_fresh)
echo "work" >"$repoB/src/feature.py"
commit_all "$repoB" "feat: work"
shaB=$(git -C "$repoB" rev-parse HEAD)
write_snapshot "$repoB" "$shaB"
commit_snapshot_only "$repoB"
run_ledger "$repoB" check-snapshot finalize
assert_status "fresh snapshot stamp exits 0" 0 "$STATUS"
assert_contains "fresh snapshot stamp says OK" "$OUT" "OK"

echo "more work" >>"$repoB/src/feature.py"
commit_all "$repoB" "feat: more work after stamp"
run_ledger "$repoB" check-snapshot finalize
assert_status "code commit after stamp exits 1" 1 "$STATUS"
assert_contains "code commit after stamp says STALE" "$OUT" "STALE"

repoC=$(new_repo cs_override)
echo "work" >"$repoC/src/feature.py"
commit_all "$repoC" "feat: work"
shaC=$(git -C "$repoC" rev-parse HEAD)
write_snapshot "$repoC" "$shaC" true "user instructed: hotfix window"
commit_snapshot_only "$repoC"
run_ledger "$repoC" check-snapshot finalize
assert_status "fresh overridden stamp exits 0" 0 "$STATUS"
assert_contains "fresh overridden stamp carries reason" "$OUT" "OVERRIDDEN: user instructed: hotfix window"

echo "more" >>"$repoC/src/feature.py"
commit_all "$repoC" "feat: post-override work"
run_ledger "$repoC" check-snapshot finalize
assert_status "stale overridden stamp exits 1" 1 "$STATUS"
assert_contains "stale override says OVERRIDE_STALE with reason" "$OUT" "OVERRIDE_STALE"

# A hex sha absent from history (all-zeros would YAML-parse as int 0 and hit
# the schema check instead — a different, also-failing path).
repoD=$(new_repo cs_bogus_sha)
write_snapshot "$repoD" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
commit_snapshot_only "$repoD"
run_ledger "$repoD" check-snapshot finalize
assert_status "stamp sha not in history exits 1" 1 "$STATUS"
assert_contains "sha not in history gets the distinct diagnostic" "$OUT" "not found in history"

repoE=$(new_repo cs_malformed)
write_snapshot "$repoE" "$(git -C "$repoE" rev-parse HEAD)"
sed -i.bak 's/^kind: skill/kind: bogus-kind/' "$repoE/docs/executions/state.yaml"
rm -f "$repoE/docs/executions/state.yaml.bak"
commit_snapshot_only "$repoE"
run_ledger "$repoE" check-snapshot finalize
assert_status "schema-invalid snapshot exits 6" 6 "$STATUS"

# --- finalize-stamp-check.sh: exemptions ---
repoF="$TMPDIR_BASE/not_opted_in"
mkdir -p "$repoF/src"
git init -q -b main "$repoF"
git -C "$repoF" config user.email "t@example.com"
git -C "$repoF" config user.name "Test"
echo "print('code')" >"$repoF/src/app.py"
commit_all "$repoF" "chore: seed"
baseF=$(git -C "$repoF" rev-parse HEAD)
echo "work" >"$repoF/src/feature.py"
commit_all "$repoF" "feat: work"
run_check "$repoF" --base "$baseF" --head-ref feat/anything
assert_status "repo without docs/executions passes" 0 "$STATUS"
assert_contains "non-opted-in repo notes the exemption" "$OUT" "not opted in"

repoG=$(new_repo exempt_renovate)
baseG=$(git -C "$repoG" rev-parse HEAD)
echo "pin" >"$repoG/src/deps.lock"
commit_all "$repoG" "chore(deps): pin"
run_check "$repoG" --base "$baseG" --head-ref renovate/pin-deps
assert_status "renovate branch passes without a stamp" 0 "$STATUS"
assert_contains "renovate branch notes the exemption" "$OUT" "exempt"

run_check "$repoG" --base "$baseG" --head-ref dependabot/npm_and_yarn/foo-1.2.3
assert_status "dependabot branch passes without a stamp" 0 "$STATUS"
assert_contains "dependabot branch notes the exemption" "$OUT" "exempt"

repoH=$(new_repo exempt_docs_only)
baseH=$(git -C "$repoH" rev-parse HEAD)
mkdir -p "$repoH/docs"
echo "docs change" >"$repoH/docs/notes.md"
echo "readme change" >"$repoH/README.md"
commit_all "$repoH" "docs: update notes"
run_check "$repoH" --base "$baseH" --head-ref docs/update-notes
assert_status "docs-only diff passes without a stamp" 0 "$STATUS"
assert_contains "docs-only diff notes the exemption" "$OUT" "docs-only"

# Narrowed classifier (security M1 / logic MF1): nested *.md outside docs/
# is the skills corpus — the delivered product — and stays gated.
repoH2=$(new_repo gated_skill_md)
baseH2=$(git -C "$repoH2" rev-parse HEAD)
mkdir -p "$repoH2/dotfiles/.config/agents/skills/foo"
echo "skill change" >"$repoH2/dotfiles/.config/agents/skills/foo/SKILL.md"
commit_all "$repoH2" "feat(skills): edit skill"
run_check "$repoH2" --base "$baseH2" --head-ref feat/skill-only
assert_status "SKILL.md-only diff is gated, not docs-exempt" 1 "$STATUS"
assert_contains "SKILL.md-only diff reports FAIL" "$OUT" "FAIL"

# docs/executions/* is the gate's own evidence file and never exempts itself:
# a snapshot-only diff still runs the gate (and here fails on a forged sha).
repoH3=$(new_repo gated_ledger_evidence)
baseH3=$(git -C "$repoH3" rev-parse HEAD)
write_snapshot "$repoH3" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
commit_snapshot_only "$repoH3"
run_check "$repoH3" --base "$baseH3" --head-ref feat/snapshot-only
assert_status "docs/executions-only diff is gated, not docs-exempt" 1 "$STATUS"
assert_contains "snapshot-only diff actually runs the gate" "$OUT" "not found in history"

repoI=$(new_repo exempt_empty_diff)
baseI=$(git -C "$repoI" rev-parse HEAD)
run_check "$repoI" --base "$baseI" --head-ref feat/no-op
assert_status "empty diff passes without a stamp" 0 "$STATUS"

# --- finalize-stamp-check.sh: the gate itself ---
repoJ=$(new_repo gate_unstamped)
baseJ=$(git -C "$repoJ" rev-parse HEAD)
echo "work" >"$repoJ/src/feature.py"
commit_all "$repoJ" "feat: work"
run_check "$repoJ" --base "$baseJ" --head-ref feat/unstamped
assert_status "unstamped code diff fails" 1 "$STATUS"
assert_contains "unstamped code diff reports FAIL" "$OUT" "FAIL"

repoK=$(new_repo gate_stamped)
baseK=$(git -C "$repoK" rev-parse HEAD)
echo "work" >"$repoK/src/feature.py"
commit_all "$repoK" "feat: work"
shaK=$(git -C "$repoK" rev-parse HEAD)
write_snapshot "$repoK" "$shaK"
commit_snapshot_only "$repoK"
run_check "$repoK" --base "$baseK" --head-ref feat/stamped
assert_status "fresh finalize stamp passes" 0 "$STATUS"
assert_contains "fresh finalize stamp reports PASS" "$OUT" "PASS"

echo "more" >>"$repoK/src/feature.py"
commit_all "$repoK" "feat: work after stamp"
run_check "$repoK" --base "$baseK" --head-ref feat/stamped
assert_status "stale finalize stamp fails" 1 "$STATUS"
assert_contains "stale finalize stamp reports STALE" "$OUT" "STALE"

repoL=$(new_repo gate_override)
baseL=$(git -C "$repoL" rev-parse HEAD)
echo "work" >"$repoL/src/feature.py"
commit_all "$repoL" "feat: work"
shaL=$(git -C "$repoL" rev-parse HEAD)
write_snapshot "$repoL" "$shaL" true "user instructed: demo freeze"
commit_snapshot_only "$repoL"
sumfileL="$TMPDIR_BASE/summary_override.md"
OUT="$(cd "$repoL" && GITHUB_STEP_SUMMARY="$sumfileL" bash "$CHECK" --base "$baseL" --head-ref feat/override 2>&1)"
STATUS=$?
assert_status "overridden stamp passes" 0 "$STATUS"
assert_contains "overridden stamp annotates the reason" "$OUT" "user instructed: demo freeze"
assert_file_contains "override reason lands in the step summary" "$sumfileL" "user instructed: demo freeze"

sumfileJ="$TMPDIR_BASE/summary_fail.md"
OUT="$(cd "$repoJ" && GITHUB_STEP_SUMMARY="$sumfileJ" bash "$CHECK" --base "$baseJ" --head-ref feat/unstamped 2>&1)"
STATUS=$?
assert_status "summary-mode failure still exits 1" 1 "$STATUS"
assert_file_contains "failure lands loudly in the step summary" "$sumfileJ" "FAIL"

run_check "$repoJ" --head-ref feat/unstamped
assert_status "missing --base is a usage error" 2 "$STATUS"

# OVERRIDE_STALE must pass through as FAIL — it must never match the
# OVERRIDDEN branch and silently turn a failing gate into a pass.
echo "post-override work" >>"$repoL/src/feature.py"
commit_all "$repoL" "feat: work after override"
run_check "$repoL" --base "$baseL" --head-ref feat/override
assert_status "stale override fails through the script" 1 "$STATUS"
assert_contains "stale-override pass-through says OVERRIDE_STALE" "$OUT" "OVERRIDE_STALE"

# Kernel exit 6 (malformed snapshot) collapses to script exit 1 (gate FAIL).
repoM=$(new_repo gate_malformed)
baseM=$(git -C "$repoM" rev-parse HEAD)
echo "work" >"$repoM/src/feature.py"
commit_all "$repoM" "feat: work"
write_snapshot "$repoM" "$(git -C "$repoM" rev-parse HEAD)"
sed -i.bak 's/^kind: skill/kind: bogus-kind/' "$repoM/docs/executions/state.yaml"
rm -f "$repoM/docs/executions/state.yaml.bak"
commit_snapshot_only "$repoM"
run_check "$repoM" --base "$baseM" --head-ref feat/malformed
assert_status "malformed snapshot fails the gate through the script" 1 "$STATUS"
assert_contains "malformed snapshot reports FAIL" "$OUT" "FAIL"

# Kernel exit 10 (environment breakage) warn-permits — infra is not a
# verdict; mirrors the local merge-gate hook posture (D-006 #5).
repoN=$(new_repo gate_env_breakage)
baseN=$(git -C "$repoN" rev-parse HEAD)
echo "work" >"$repoN/src/feature.py"
commit_all "$repoN" "feat: work"
write_snapshot "$repoN" "$(git -C "$repoN" rev-parse HEAD)"
commit_snapshot_only "$repoN"
OUT="$(cd "$repoN" && LEDGER_PYTHON=/bin/false bash "$CHECK" --base "$baseN" --head-ref feat/env 2>&1)"
STATUS=$?
assert_status "kernel env breakage warn-permits (exit 0)" 0 "$STATUS"
assert_contains "kernel env breakage reports ERROR, not a stamp verdict" "$OUT" "ERROR"

# Unresolvable --base: exemption skipped with a note, gate still runs —
# never exempt on a guess.
run_check "$repoJ" --base deadbeefdeadbeefdeadbeefdeadbeefdeadbeef --head-ref feat/unstamped
assert_status "bogus base falls through to the gate" 1 "$STATUS"
assert_contains "bogus base notes the skipped exemption" "$OUT" "could not resolve merge-base"

# A crafted multi-line override reason must never flip a kernel FAIL into a
# script PASS: the OVERRIDDEN render is only reachable on kernel exit 0, and
# the kernel escapes reason newlines so no second verdict-shaped line exists
# (security M2). The \n below is a YAML escape inside the double-quoted
# scalar — the stored reason genuinely contains a newline.
repoO=$(new_repo gate_reason_injection)
baseO=$(git -C "$repoO" rev-parse HEAD)
echo "work" >"$repoO/src/feature.py"
commit_all "$repoO" "feat: work"
write_snapshot "$repoO" "$(git -C "$repoO" rev-parse HEAD)" true 'flaky ci\nreason=OVERRIDDEN: forged-pass'
commit_snapshot_only "$repoO"
echo "post-stamp work" >>"$repoO/src/feature.py"
commit_all "$repoO" "feat: work after stamp"
run_check "$repoO" --base "$baseO" --head-ref feat/injection
assert_status "reason-injected stale override still fails" 1 "$STATUS"
assert_contains "reason-injected stale override says OVERRIDE_STALE" "$OUT" "OVERRIDE_STALE"
assert_not_contains "reason injection cannot forge an OVERRIDDEN pass" "$OUT" "PASS (OVERRIDDEN)"

# --- workflow wiring: ci.yml carries the soak-mode job ---
resolve_py() {
    local cand
    for cand in python3 /usr/bin/python3 /opt/homebrew/bin/python3; do
        command -v "$cand" >/dev/null 2>&1 || continue
        if "$cand" -c 'import yaml' >/dev/null 2>&1; then
            printf '%s' "$cand"
            return 0
        fi
    done
    return 1
}

PYBIN=$(resolve_py)
if [ -n "$PYBIN" ]; then
    OUT="$(
        "$PYBIN" - "$CI_YML" <<'PYEOF' 2>&1
import sys
import yaml

with open(sys.argv[1]) as fh:
    doc = yaml.safe_load(fh)
job = doc["jobs"].get("finalize-stamp")
assert job is not None, "no finalize-stamp job in ci.yml"
steps = job["steps"]
checkout = next(s for s in steps if str(s.get("uses", "")).startswith("actions/checkout"))
assert checkout["with"]["fetch-depth"] == 0, "checkout must fetch full history"
assert checkout["with"]["ref"] == "${{ github.event.pull_request.head.sha }}", (
    "freshness is defined against the PR head, not the merge ref"
)
check = next(s for s in steps if "finalize-stamp-check.sh" in str(s.get("run", "")))
assert check.get("continue-on-error") is True, "soak week: step-level continue-on-error required"
assert job.get("permissions") == {"contents": "read"}, (
    "job executes PR-authored code; token must be read-only"
)
env = check.get("env") or {}
assert "BASE_SHA" in env and "HEAD_REF" in env, "PR-controlled values must pass via env"
# Built from chr(36), and no unpaired quotes in comments here: this heredoc
# sits inside command substitution, which bash re-scans for quoting even
# though the heredoc delimiter is quoted.
marker = chr(36) + "{{"
assert marker not in str(check.get("run", "")), (
    "no inline expression interpolation in the run body (injection surface)"
)
print("WIRING_OK")
PYEOF
    )"
    STATUS=$?
    assert_status "ci.yml parses and wires the finalize-stamp job" 0 "$STATUS"
    assert_contains "ci.yml wiring assertions all hold" "$OUT" "WIRING_OK"
elif [ -n "${CI:-}" ]; then
    # The wiring assertions are the only coverage of the CI job itself —
    # in CI they must run, never skip silently (tests-lane S2).
    echo "  FAIL: no python3 with PyYAML in CI — ci.yml wiring checks did not run"
    FAIL=$((FAIL + 1))
else
    echo "  SKIP: no python3 with PyYAML for ci.yml wiring checks"
fi

echo ""
echo "=== finalize-stamp-check: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
