#!/usr/bin/env bash
set -uo pipefail

# Red-first suite for the Phase 5a finalize-stamp CI check (D-006 #6 follow-up:
# closes the server-side auto-merge bypass observed live on PR #167 — the local
# merge-gate hook never sees a server-side merge).
#
# Contract under test:
#   - `ledger.sh check-snapshot <gate> [--file <path>]`: CI-side gate check
#     against a COMMITTED per-run snapshot (docs/executions/runs/<run_id>.yaml)
#     — no live state needed. Resolution without --file: the live run's file
#     when live state exists; else exactly one runs/*.yaml (zero → exit 1
#     MISSING; more than one → exit 1 asking for --file). --file names the
#     run file explicitly (the CI script passes candidates from the PR diff).
#     Freshness is the kernel's content-verified fresh_since (single
#     implementation): the stamp's head_sha must be ancestor-or-equal of HEAD
#     and every commit after it must touch ONLY that run's own snapshot file,
#     verified by diff-tree contents, never by subject. Malformed snapshots
#     are exit 6. The legacy shared docs/executions/state.yaml satisfies
#     nothing — it is a frozen historical record.
#   - `scripts/finalize-stamp-check.sh`: the local script the CI job calls.
#     Exemptions (pass-with-note): repo not opted in (no docs/executions/),
#     head refs matching renovate/* or dependabot/*, docs-only diffs vs --base
#     (docs/* minus docs/executions/*, plus root-level *.md — nested *.md
#     outside docs/ is the skills corpus and stays gated), empty diffs.
#     Candidate discovery: the run files CHANGED vs --base's merge-base
#     (docs/executions/runs/*.yaml present at HEAD); the gate passes iff at
#     least one candidate carries a fresh finalize stamp. Zero candidates on
#     a non-exempt diff is a FAIL (the delivery never stamped). Overridden
#     stamps PASS but the override reason is annotated into the summary.
#     Kernel environment breakage (ledger exit 10) warn-permits with an ERROR
#     note. Everything else requires a fresh finalize stamp (exit 1).
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

# Hand-craft a schema-valid committed per-run snapshot carrying a finalize
# stamp at the given sha. Legitimate here: check-snapshot treats the snapshot
# as untrusted input (that is the point of the CI-side check), so the tests
# exercise the reader, not the writer.
write_snapshot() {
    local repo="$1" sha="$2" override_active="${3:-false}" reason="${4:-}" run_id="${5:-test-run}"
    mkdir -p "$repo/docs/executions/runs"
    cat >"$repo/docs/executions/runs/$run_id.yaml" <<EOF
run_id: $run_id
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
    local repo="$1" run_id="${2:-test-run}"
    git -C "$repo" add -- "docs/executions/runs/$run_id.yaml"
    git -C "$repo" commit -q -m "chore(ledger): stamp finalize" \
        -- "docs/executions/runs/$run_id.yaml"
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
sed -i.bak 's/^kind: skill/kind: bogus-kind/' "$repoE/docs/executions/runs/test-run.yaml"
rm -f "$repoE/docs/executions/runs/test-run.yaml.bak"
commit_snapshot_only "$repoE"
run_ledger "$repoE" check-snapshot finalize
assert_status "schema-invalid snapshot exits 6" 6 "$STATUS"

# --- check-snapshot resolution: --file and the multi-run fallback ---
run_ledger "$repoB" check-snapshot finalize --file docs/executions/runs/test-run.yaml
assert_status "check-snapshot --file names the run file explicitly" 1 "$STATUS"
assert_contains "--file verdict is the same STALE as bare resolution" "$OUT" "STALE"

repoMulti=$(new_repo cs_multi)
echo "work" >"$repoMulti/src/feature.py"
commit_all "$repoMulti" "feat: work"
shaMulti=$(git -C "$repoMulti" rev-parse HEAD)
write_snapshot "$repoMulti" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" false "" old-run
commit_snapshot_only "$repoMulti" old-run
shaMulti=$(git -C "$repoMulti" rev-parse HEAD)
write_snapshot "$repoMulti" "$shaMulti" false "" new-run
commit_snapshot_only "$repoMulti" new-run
run_ledger "$repoMulti" check-snapshot finalize
assert_status "multiple run files without --file exits 1" 1 "$STATUS"
assert_contains "multi-run fallback asks for --file" "$OUT" "pass --file"
run_ledger "$repoMulti" check-snapshot finalize --file docs/executions/runs/new-run.yaml
assert_status "explicit --file passes on the fresh run" 0 "$STATUS"
assert_contains "explicit --file verdict says OK" "$OUT" "OK"
run_ledger "$repoMulti" check-snapshot finalize --file "$repoMulti/docs/executions/runs/new-run.yaml"
assert_status "absolute --file inside the repo passes" 0 "$STATUS"
run_ledger "$repoMulti" check-snapshot finalize --file docs/executions/runs/old-run.yaml
assert_status "--file checks the NAMED file, not any fresh sibling" 1 "$STATUS"
assert_contains "--file on the stale run reads its own verdict" "$OUT" "not found in history"
run_ledger "$repoMulti" check-snapshot finalize --file docs/executions/runs/absent-run.yaml
assert_status "--file on a missing path exits 1" 1 "$STATUS"
assert_contains "missing --file target says MISSING" "$OUT" "MISSING"
assert_contains "missing --file verdict names the requested path" "$OUT" \
    "docs/executions/runs/absent-run.yaml"

# --file is shape-validated like a kernel-authored run file: nested paths,
# out-of-repo paths, dotfile-shaped basenames, and the legacy shared path are
# all refused (INVALID).
run_ledger "$repoMulti" check-snapshot finalize --file docs/executions/runs/nested/x.yaml
assert_status "nested --file path rejected" 1 "$STATUS"
assert_contains "nested --file rejection says INVALID" "$OUT" "INVALID"
run_ledger "$repoMulti" check-snapshot finalize --file /tmp/outside-foreign.yaml
assert_status "--file outside the repo rejected" 1 "$STATUS"
assert_contains "outside --file rejection says INVALID" "$OUT" "INVALID"
run_ledger "$repoMulti" check-snapshot finalize --file docs/executions/state.yaml
assert_status "--file naming the legacy path rejected" 1 "$STATUS"
assert_contains "legacy --file rejection says INVALID" "$OUT" "INVALID"
run_ledger "$repoMulti" check-snapshot finalize --file docs/executions/runs/.yaml
assert_status "dotfile-shaped --file basename rejected" 1 "$STATUS"
assert_contains "dotfile --file rejection says INVALID" "$OUT" "INVALID"

# "Committed snapshot" means in a COMMIT: an untracked run file is refused,
# and staging alone (git add, no commit) must not satisfy the check either —
# nor may an untracked name reach a tracked sibling via pathspec globbing.
printf 'stray: true\n' >"$repoMulti/docs/executions/runs/stray-run.yaml"
run_ledger "$repoMulti" check-snapshot finalize --file docs/executions/runs/stray-run.yaml
assert_status "untracked run file rejected" 1 "$STATUS"
assert_contains "untracked rejection says INVALID" "$OUT" "INVALID"
git -C "$repoMulti" add -- docs/executions/runs/stray-run.yaml
run_ledger "$repoMulti" check-snapshot finalize --file docs/executions/runs/stray-run.yaml
assert_status "staged-but-uncommitted run file rejected" 1 "$STATUS"
assert_contains "staged-only rejection says INVALID" "$OUT" "INVALID"
git -C "$repoMulti" rm -q --cached -- docs/executions/runs/stray-run.yaml
rm -f "$repoMulti/docs/executions/runs/stray-run.yaml"

# The legacy shared snapshot satisfies nothing: a repo whose ONLY committed
# snapshot is a fresh old-style state.yaml has no run file to check.
repoLeg=$(new_repo cs_legacy_only)
echo "work" >"$repoLeg/src/feature.py"
commit_all "$repoLeg" "feat: work"
shaLeg=$(git -C "$repoLeg" rev-parse HEAD)
write_snapshot "$repoLeg" "$shaLeg" false "" legacy-shape
mv "$repoLeg/docs/executions/runs/legacy-shape.yaml" "$repoLeg/docs/executions/state.yaml"
rmdir "$repoLeg/docs/executions/runs" 2>/dev/null
git -C "$repoLeg" add -- docs/executions/state.yaml
git -C "$repoLeg" commit -q -m "chore(ledger): stamp finalize" -- docs/executions/state.yaml
run_ledger "$repoLeg" check-snapshot finalize
assert_status "legacy state.yaml alone no longer satisfies the gate" 1 "$STATUS"
assert_contains "legacy-only repo reads MISSING" "$OUT" "MISSING"

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

# Candidate discovery: the changed run files vs base are the candidates; the
# gate passes iff at least one is fresh. A superseded run (force re-init) may
# leave a stale sibling on the same branch — the fresh final run still passes.
repoK2=$(new_repo gate_two_runs)
baseK2=$(git -C "$repoK2" rev-parse HEAD)
echo "work" >"$repoK2/src/feature.py"
commit_all "$repoK2" "feat: work"
write_snapshot "$repoK2" "$(git -C "$repoK2" rev-parse HEAD)" false "" superseded-run
commit_snapshot_only "$repoK2" superseded-run
echo "more" >>"$repoK2/src/feature.py"
commit_all "$repoK2" "feat: more work (stales superseded-run)"
write_snapshot "$repoK2" "$(git -C "$repoK2" rev-parse HEAD)" false "" final-run
commit_snapshot_only "$repoK2" final-run
run_check "$repoK2" --base "$baseK2" --head-ref feat/two-runs
assert_status "one fresh candidate among two changed run files passes" 0 "$STATUS"
assert_contains "two-candidate pass reports PASS" "$OUT" "PASS"

# A PR that changes code plus ONLY the legacy shared snapshot has zero run
# candidates: the old-style state.yaml must not satisfy the migrated gate.
repoK3=$(new_repo gate_legacy_shape)
baseK3=$(git -C "$repoK3" rev-parse HEAD)
echo "work" >"$repoK3/src/feature.py"
commit_all "$repoK3" "feat: work"
write_snapshot "$repoK3" "$(git -C "$repoK3" rev-parse HEAD)" false "" legacy-move
mv "$repoK3/docs/executions/runs/legacy-move.yaml" "$repoK3/docs/executions/state.yaml"
rmdir "$repoK3/docs/executions/runs" 2>/dev/null
git -C "$repoK3" add -- docs/executions/state.yaml
git -C "$repoK3" commit -q -m "chore(ledger): stamp finalize" -- docs/executions/state.yaml
run_check "$repoK3" --base "$baseK3" --head-ref feat/legacy-shape
assert_status "legacy state.yaml diff has zero candidates and fails" 1 "$STATUS"
assert_contains "zero-candidate failure names the runs path" "$OUT" "docs/executions/runs"

# A nested run file is a shape the kernel can never author (run_ids reject
# separators) — the candidate filter must not accept it (bash case globs
# cross '/', so a bare runs/*.yaml arm would).
repoNest=$(new_repo gate_nested)
baseNest=$(git -C "$repoNest" rev-parse HEAD)
echo "work" >"$repoNest/src/feature.py"
commit_all "$repoNest" "feat: work"
write_snapshot "$repoNest" "$(git -C "$repoNest" rev-parse HEAD)" false "" tmp-nest
mkdir -p "$repoNest/docs/executions/runs/nested"
mv "$repoNest/docs/executions/runs/tmp-nest.yaml" \
    "$repoNest/docs/executions/runs/nested/forged.yaml"
git -C "$repoNest" add -- docs/executions/runs/nested/forged.yaml
git -C "$repoNest" commit -q -m "chore(ledger): stamp finalize" \
    -- docs/executions/runs/nested/forged.yaml
run_check "$repoNest" --base "$baseNest" --head-ref feat/nested
assert_status "nested run file is not an accepted candidate" 1 "$STATUS"
assert_contains "nested-only diff fails as zero candidates" "$OUT" "docs/executions/runs"
assert_contains "zero-candidate diagnosis names the ignored nested path count" "$OUT" "nested"

# Dotfile-shaped candidate (.yaml as the whole basename): the accept arm must
# not match an empty prefix (review round 2: security).
repoDotf=$(new_repo gate_dotfile)
baseDotf=$(git -C "$repoDotf" rev-parse HEAD)
echo "work" >"$repoDotf/src/feature.py"
commit_all "$repoDotf" "feat: work"
write_snapshot "$repoDotf" "$(git -C "$repoDotf" rev-parse HEAD)" false "" tmp-dotf
mv "$repoDotf/docs/executions/runs/tmp-dotf.yaml" "$repoDotf/docs/executions/runs/.yaml"
git -C "$repoDotf" add -f -- docs/executions/runs/.yaml
git -C "$repoDotf" commit -q -m "chore(ledger): stamp finalize" -- docs/executions/runs/.yaml
run_check "$repoDotf" --base "$baseDotf" --head-ref feat/dotfile
assert_status "dotfile-shaped run file is not an accepted candidate" 1 "$STATUS"

# Unresolvable merge-base: the fallback enumerates the run files present at
# HEAD and runs the same candidate loop — resolvable and fail-closed, instead
# of delegating to the kernel's single-file tier (which reads AMBIGUOUS
# forever once run files accumulate).
repoFB=$(new_repo gate_fallback)
echo "work" >"$repoFB/src/feature.py"
commit_all "$repoFB" "feat: work"
write_snapshot "$repoFB" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" false "" stale-old
commit_snapshot_only "$repoFB" stale-old
write_snapshot "$repoFB" "$(git -C "$repoFB" rev-parse HEAD)" false "" fresh-new
commit_snapshot_only "$repoFB" fresh-new
run_check "$repoFB" --base deadbeefdeadbeefdeadbeefdeadbeefdeadbeef --head-ref feat/fallback
assert_status "unresolvable base falls back to HEAD run files and passes" 0 "$STATUS"
assert_contains "fallback pass notes the skipped exemption" "$OUT" "could not resolve merge-base"
assert_contains "fallback pass reports PASS" "$OUT" "PASS"

# A schema-invalid (kernel exit 6) sibling must stay visible even when a
# fresh candidate passes — a corrupt PR-visible record must never merge
# unannotated.
repoBadSib=$(new_repo gate_bad_sibling)
baseBadSib=$(git -C "$repoBadSib" rev-parse HEAD)
echo "work" >"$repoBadSib/src/feature.py"
commit_all "$repoBadSib" "feat: work"
write_snapshot "$repoBadSib" "$(git -C "$repoBadSib" rev-parse HEAD)" false "" bad-run
sed -i.bak 's/^kind: skill/kind: bogus-kind/' "$repoBadSib/docs/executions/runs/bad-run.yaml"
rm -f "$repoBadSib/docs/executions/runs/bad-run.yaml.bak"
commit_snapshot_only "$repoBadSib" bad-run
write_snapshot "$repoBadSib" "$(git -C "$repoBadSib" rev-parse HEAD)" false "" good-run
commit_snapshot_only "$repoBadSib" good-run
run_check "$repoBadSib" --base "$baseBadSib" --head-ref feat/bad-sibling
assert_status "fresh candidate still passes beside a malformed sibling" 0 "$STATUS"
assert_contains "malformed sibling is annotated on PASS" "$OUT" "bad-run"

# Every changed run file deleted at HEAD is a distinct cause and the
# zero-candidate diagnosis must say so.
repoDel=$(new_repo gate_deleted)
write_snapshot "$repoDel" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" false "" doomed
commit_snapshot_only "$repoDel" doomed
baseDel=$(git -C "$repoDel" rev-parse HEAD)
echo "work" >"$repoDel/src/feature.py"
commit_all "$repoDel" "feat: work"
git -C "$repoDel" rm -q -- docs/executions/runs/doomed.yaml
git -C "$repoDel" commit -q -m "chore: retire run file"
run_check "$repoDel" --base "$baseDel" --head-ref feat/deleted
assert_status "deleted-run-file diff still fails" 1 "$STATUS"
assert_contains "zero-candidate diagnosis mentions deletion" "$OUT" "deleted at HEAD"

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
sed -i.bak 's/^kind: skill/kind: bogus-kind/' "$repoM/docs/executions/runs/test-run.yaml"
rm -f "$repoM/docs/executions/runs/test-run.yaml.bak"
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
