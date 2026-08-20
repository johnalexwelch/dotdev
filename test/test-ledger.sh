#!/usr/bin/env bash
set -uo pipefail

# Red-first suite for the workflow-ledger kernel CLI.
# Contract: docs/executions/plans/2026-08-19-workflow-ledger-spec.md
# Interpretations the implementer must honor (also listed in the spec PR):
#   - Steps passed via --steps are required by default.
#   - `--attest lanes=` accepts comma-separated lane=path pairs (explicit
#     lane->file mapping), overriding the /tmp/<lane>-review.md default so
#     tests stay inside the sandbox.
#   - Model ordering for floors: haiku < sonnet < opus < fable; real model ids
#     rank by family substring (R1 MF3).
#   - A stamp's own snapshot commit does not make that stamp stale; the
#     exemption is verified by commit CONTENTS (touches only the snapshot
#     file), never by subject — a chore(ledger)-titled code commit is STALE
#     (R1 MF1, D-006 #4 content-verified refinement).
#   - Committed snapshots are PER-RUN: docs/executions/runs/<run_id>.yaml.
#     init/stamp/close write and commit only the run's own file, so two
#     concurrent runs in different worktrees never touch a shared path (the
#     cross-PR state.yaml conflict class: #167/#174/#180/#181). The freshness
#     exemption covers exactly the run's OWN file — a commit touching a
#     different run's file (or the legacy shared path) is NOT exempt.
#   - docs/executions/state.yaml is a legacy historical record: new runs never
#     create, modify, or read it, and it no longer satisfies any gate.
#   - `stamp finalize --gate-type <gate_type>` selects the gate type
#     (default reviewer-validation); non-reviewer types require --human.
#   - Finalize resolves the branch PR via forge pr-for-branch itself; no_pr
#     only when the lookup finds nothing. Mock forge answers require
#     LEDGER_ALLOW_FORGE_MOCK=1 or the stamp refuses (R1 MF5/MF6).
#   - ci-commands.yaml is a top-level YAML list of command strings.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEDGER="$ROOT/dotfiles/.config/agents/skills/workflow-ledger/scripts/ledger.sh"
BASELINE="$ROOT/dotfiles/.config/agents/skills/setup-worktree/scripts/worktree-baseline.sh"
SKILLS_ROOT_REAL="$ROOT/dotfiles/.config/agents/skills"
TMPDIR_BASE=$(mktemp -d)
PASS=0
FAIL=0
LEDGER_SKILLS_ROOT=""
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

assert_status_not() {
    local name="$1" forbidden="$2" actual="$3"
    if [ "$actual" -ne "$forbidden" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    exit must not be $forbidden, got $actual"
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
    if grep -Fq "$needle" <<<"$haystack"; then
        echo "  FAIL: $name"
        echo "    output must NOT contain: $needle"
        echo "    output was:"
        echo "$haystack"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    fi
}

assert_equal() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    expected: $expected"
        echo "    actual:   $actual"
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

assert_file_not_exists() {
    local name="$1" path="$2"
    if [ ! -e "$path" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    UNEXPECTEDLY PRESENT: $path"
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

assert_file_not_contains() {
    local name="$1" path="$2" needle="$3"
    if [ -f "$path" ] && ! grep -Fq "$needle" "$path"; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        if [ -f "$path" ]; then
            echo "    expected $path to NOT contain: $needle"
        else
            echo "    MISSING: $path"
        fi
        FAIL=$((FAIL + 1))
    fi
}

assert_file_matches() {
    local name="$1" path="$2" regex="$3"
    if [ -f "$path" ] && grep -Eq "$regex" "$path"; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        if [ -f "$path" ]; then
            echo "    expected $path to match: $regex"
        else
            echo "    MISSING: $path"
        fi
        FAIL=$((FAIL + 1))
    fi
}

# Run ledger.sh from inside a repo/worktree; captures OUT and STATUS.
# SKILLS_ROOT always points at the repo-local skills tree (never real $HOME);
# individual tests override via LEDGER_SKILLS_ROOT for preflight mocks.
run_ledger() {
    local dir="$1"
    shift
    OUT="$(cd "$dir" && SKILLS_ROOT="${LEDGER_SKILLS_ROOT:-$SKILLS_ROOT_REAL}" bash "$LEDGER" "$@" 2>&1)"
    STATUS=$?
}

live_state() {
    local dir="$1"
    printf '%s/ledger/state.yaml' "$(git -C "$dir" rev-parse --absolute-git-dir)"
}

# Per-run committed snapshot path for a run id.
run_snap() {
    local dir="$1" run_id="$2"
    printf '%s/docs/executions/runs/%s.yaml' "$dir" "$run_id"
}

commit_all() {
    local dir="$1" msg="$2"
    git -C "$dir" add -A
    git -C "$dir" commit -q -m "$msg"
}

# Hand-tamper live state the way an agent with Bash access can: inject a
# `stamps` entry the kernel's stamp path never validated or published.
# Only matches an empty `stamps: {}` map, so the caller must assert the
# injection landed before relying on it.
inject_forged_stamp() {
    local state="$1" gate="$2" head="$3" tmp="$1.forged"
    awk -v gate="$gate" -v head="$head" -v q="'" '
        /^stamps: \{\}$/ {
            print "stamps:"
            print "  " gate ":"
            print "    head_sha: " q head q
            print "    gate_type: reviewer-validation"
            print "    provenance: agent"
            print "    checked:"
            print "      forged: " q "forged-by-hand" q
            next
        }
        { print }
    ' "$state" >"$tmp" && mv "$tmp" "$state"
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

# Bare origin + clone + baseline-cut worktree, same shape as
# test-worktree-baseline.sh, so `worktree-baseline.sh verify` can pass
# inside the worktree (a checked field of the review gate).
new_wt_fixture() {
    local name="$1"
    local fixture="$TMPDIR_BASE/$name"
    local origin="$fixture/origin.git"
    local seed="$fixture/seed"
    local work="$fixture/work"
    local wt="$fixture/wt"

    mkdir -p "$fixture"
    git init --bare -q "$origin"
    git -C "$origin" symbolic-ref HEAD refs/heads/main

    git clone -q "$origin" "$seed"
    git -C "$seed" config user.email "t@example.com"
    git -C "$seed" config user.name "Test"
    mkdir -p "$seed/docs/executions" "$seed/src" "$seed/auth"
    echo "seed" >"$seed/README.md"
    echo "opted-in" >"$seed/docs/executions/.gitkeep"
    echo "print('app')" >"$seed/src/app.py"
    echo "token = None" >"$seed/auth/token.py"
    git -C "$seed" add -A
    git -C "$seed" commit -q -m init
    git -C "$seed" push -q origin main
    rm -rf "$seed"

    git clone -q "$origin" "$work"
    git -C "$work" config user.email "t@example.com"
    git -C "$work" config user.name "Test"
    (cd "$work" && bash "$BASELINE" cut --branch "feature/$name" --path "$wt" >/dev/null 2>&1)
    git -C "$wt" config user.email "t@example.com" 2>/dev/null
    git -C "$wt" config user.name "Test" 2>/dev/null

    printf '%s' "$wt"
}

echo "=== ledger.sh tests ==="
echo ""

assert_file_exists "ledger.sh exists at spec'd path" "$LEDGER"

# --- init: happy path, refusal, --force ---
repoA=$(new_repo init_lifecycle)
stateA=$(live_state "$repoA")

run_ledger "$repoA" init 2026-08-19-demo --workflow workflow-build-one \
    --kind feature --steps "plan,impl,review" --budget one-reviewer
assert_status "init happy path exits 0" 0 "$STATUS"
assert_file_exists "init creates live state in git-dir" "$stateA"
assert_file_contains "live state records run_id" "$stateA" "run_id: 2026-08-19-demo"
assert_file_contains "live state is active" "$stateA" "status: active"
assert_file_exists "init writes committed per-run snapshot" \
    "$(run_snap "$repoA" 2026-08-19-demo)"
assert_file_not_exists "init does not write the legacy shared snapshot" \
    "$repoA/docs/executions/state.yaml"
last_msg=$(git -C "$repoA" log -1 --pretty=%s)
assert_contains "init commits snapshot as chore(ledger)" "$last_msg" "chore(ledger): init"
init_paths=$(git -C "$repoA" diff-tree --no-commit-id --name-only -r HEAD)
assert_equal "init snapshot commit touches only its own run file" \
    "docs/executions/runs/2026-08-19-demo.yaml" "$init_paths"

run_ledger "$repoA" init 2026-08-19-demo2 --workflow workflow-build-one \
    --kind feature --steps "plan,impl,review"
assert_status "re-init over active run refused with exit 7" 7 "$STATUS"

run_ledger "$repoA" init 2026-08-19-demo3 --workflow workflow-build-one \
    --kind feature --steps "plan,impl,review" --force
assert_status "re-init --force exits 0" 0 "$STATUS"
assert_file_contains "forced re-init leaves overrides[] audit entry" "$stateA" "force"
assert_file_exists "forced re-init writes its own run file" \
    "$(run_snap "$repoA" 2026-08-19-demo3)"
assert_file_exists "prior run file remains as historical record" \
    "$(run_snap "$repoA" 2026-08-19-demo)"

# run_id doubles as a tracked filename: path-hostile and glob shapes are
# refused at init (exit 6, nothing written) — the only guard keeping a run
# from writing or sweeping paths outside docs/executions/runs/.
for bad in '../evil' 'a/b' '.hidden' 'run*id' 'run?id' 'with space' ''; do
    run_ledger "$repoA" init "$bad" --workflow workflow-deliver \
        --kind feature --steps "plan" --force
    assert_status "path-hostile run_id '$bad' exits 6" 6 "$STATUS"
done
assert_contains "run_id refusal names the reason" "$OUT" \
    "unusable as a snapshot filename"
run_ledger "$repoA" init 'run*id' --workflow workflow-deliver \
    --kind feature --steps "plan" --force
assert_contains "charset refusal names the allowlist" "$OUT" "allowed: A-Za-z0-9._-"
assert_file_contains "refused run_ids write nothing (demo3 still live)" \
    "$stateA" "run_id: 2026-08-19-demo3"

# Reusing a run_id whose committed run file already exists would silently
# overwrite a prior delivery's PR-visible audit record: refused without
# --force even when the prior run is closed.
repoCol=$(new_repo run_collision)
run_ledger "$repoCol" init 2026-08-19-col --workflow workflow-deliver \
    --kind feature --steps "impl"
run_ledger "$repoCol" set impl completed --evidence "done"
run_ledger "$repoCol" close
run_ledger "$repoCol" init 2026-08-19-col --workflow workflow-deliver \
    --kind feature --steps "impl"
assert_status "re-init reusing a committed run_id refused (exit 7)" 7 "$STATUS"
assert_contains "collision refusal names the existing run file" "$OUT" "2026-08-19-col"
run_ledger "$repoCol" init 2026-08-19-col --workflow workflow-deliver \
    --kind feature --steps "impl" --force
assert_status "collision re-init with --force exits 0" 0 "$STATUS"
assert_file_contains "forced collision re-init leaves an overrides audit entry" \
    "$(live_state "$repoCol")" "existing committed run file"

# --- set: transition rules ---
run_ledger "$repoA" set nosuchstep completed --evidence "x"
assert_status "set on unknown step exits 5" 5 "$STATUS"

run_ledger "$repoA" set plan completed
assert_status "set completed with empty evidence exits 4" 4 "$STATUS"
assert_file_not_contains "refused set writes nothing" "$stateA" "completed"

updated_before=$(grep -E '^updated:' "$stateA" 2>/dev/null || true)
sleep 1
run_ledger "$repoA" set plan completed --evidence "plan doc committed"
assert_status "valid set with evidence exits 0" 0 "$STATUS"
assert_file_contains "valid set writes new status" "$stateA" "completed"
updated_after=$(grep -E '^updated:' "$stateA" 2>/dev/null || true)
if [ -n "$updated_after" ] && [ "$updated_before" != "$updated_after" ]; then
    echo "  PASS: valid set bumps updated timestamp"
    PASS=$((PASS + 1))
else
    echo "  FAIL: valid set bumps updated timestamp"
    echo "    before: $updated_before"
    echo "    after:  $updated_after"
    FAIL=$((FAIL + 1))
fi

run_ledger "$repoA" set impl skipped --reason "not needed"
assert_status "required step to skipped exits 3" 3 "$STATUS"
assert_file_not_contains "refused skip writes nothing" "$stateA" "skipped"

run_ledger "$repoA" set impl bogus-status --evidence "x"
assert_status "schema-invalid status exits 6" 6 "$STATUS"
assert_file_not_contains "schema-invalid set writes nothing" "$stateA" "bogus-status"

run_ledger "$repoA" check review
assert_status "check on unstamped gate exits 1" 1 "$STATUS"
assert_contains "unstamped check says MISSING" "$OUT" "MISSING"

# --- durability: live state survives git reset --hard ---
echo "junk" >>"$repoA/src/app.py"
git -C "$repoA" reset --hard -q
assert_file_exists "live state survives reset --hard" "$stateA"
assert_file_contains "live state still active after reset" "$stateA" "status: active"
run_ledger "$repoA" show
assert_status "show exits 0 after reset" 0 "$STATUS"
assert_contains "show renders steps" "$OUT" "plan"

# --- reconcile: clean, drift, --apply ---
run_ledger "$repoA" reconcile
assert_status "reconcile clean exits 0" 0 "$STATUS"

echo "drift work" >>"$repoA/src/app.py"
commit_all "$repoA" "feat: work outside the ledger"
run_ledger "$repoA" reconcile
assert_status "reconcile detects drift with exit 1" 1 "$STATUS"

run_ledger "$repoA" reconcile --apply
run_ledger "$repoA" reconcile
assert_status "reconcile clean again after --apply" 0 "$STATUS"

# --- reconcile ground truth: branch/worktree/pending-step comparisons (batch #6) ---
repoG=$(new_repo reconcile_truth)
run_ledger "$repoG" init 2026-08-18-truth --workflow workflow-deliver \
    --kind feature --steps "impl"
run_ledger "$repoG" reconcile
assert_status "ground-truth fixture clean right after init" 0 "$STATUS"

git -C "$repoG" checkout -q -b feature/elsewhere
run_ledger "$repoG" reconcile
assert_status "branch change since init is drift (exit 1)" 1 "$STATUS"
assert_contains "branch drift names the recorded branch" "$OUT" "recorded 'main'"
run_ledger "$repoG" reconcile --apply
run_ledger "$repoG" reconcile
assert_status "reconcile --apply adopts the new branch" 0 "$STATUS"

echo "work" >>"$repoG/src/app.py"
commit_all "$repoG" "feat: commits while step still pending"
run_ledger "$repoG" reconcile
assert_status "commit drift still exits 1" 1 "$STATUS"
assert_contains "commit drift names the pending step" "$OUT" "impl"
run_ledger "$repoG" reconcile --apply

mv "$repoG" "${repoG}-moved"
run_ledger "${repoG}-moved" reconcile
assert_status "worktree path change is drift (exit 1)" 1 "$STATUS"
# The needle must be the RECORDED (old) path phrase — the frontier line
# always prints the current worktree, which contains the old path as a
# substring (tests-lane vacuity fix). Symlink-agnostic: match the phrase
# ending at the old basename, which the -moved path cannot produce.
assert_contains "worktree drift names the recorded path" "$OUT" \
    "reconcile_truth' but is running in"
run_ledger "${repoG}-moved" reconcile --apply
run_ledger "${repoG}-moved" reconcile
assert_status "reconcile --apply adopts the new worktree path" 0 "$STATUS"

# Pre-field (legacy) live states skip the new ground-truth comparisons
# instead of erroring (tests-lane back-compat pin).
repoL=$(new_repo legacy_fields)
run_ledger "$repoL" init 2026-08-18-legacy --workflow workflow-deliver \
    --kind feature --steps "impl"
stateL=$(live_state "$repoL")
sed -i.bak '/^initialized_epoch:/d; /^branch:/d; /^worktree:/d' "$stateL"
rm -f "$stateL.bak"
run_ledger "$repoL" reconcile
assert_status "legacy state without new fields reconciles clean" 0 "$STATUS"

# --- legacy shared snapshot is a historical record: new runs never touch it ---
repoLG=$(new_repo legacy_snapshot)
printf 'legacy historical snapshot content — frozen\n' >"$repoLG/docs/executions/state.yaml"
commit_all "$repoLG" "chore: pre-existing legacy snapshot"
run_ledger "$repoLG" init 2026-08-19-postlegacy --workflow workflow-deliver \
    --kind feature --steps "impl"
assert_status "init beside a legacy state.yaml exits 0" 0 "$STATUS"
assert_file_exists "init beside legacy writes its per-run file" \
    "$(run_snap "$repoLG" 2026-08-19-postlegacy)"
assert_file_contains "legacy state.yaml left byte-identical by init" \
    "$repoLG/docs/executions/state.yaml" "legacy historical snapshot content — frozen"
legacy_diff=$(git -C "$repoLG" diff HEAD~1..HEAD --name-only -- docs/executions/state.yaml)
assert_equal "init commit never touches the legacy path" "" "$legacy_diff"

# --- corrupt live state is exit 6, never silently rewritten ---
repoH=$(new_repo corrupt_state)
run_ledger "$repoH" init 2026-08-19-corrupt --workflow workflow-build-one \
    --kind feature --steps "plan"
stateH=$(live_state "$repoH")
echo "::: not yaml [ {" >"$stateH"
run_ledger "$repoH" show
assert_status "corrupt live state exits 6 on show" 6 "$STATUS"
run_ledger "$repoH" set plan active
assert_status "corrupt live state exits 6 on set" 6 "$STATUS"
assert_file_contains "corrupt live state not silently rewritten" "$stateH" "::: not yaml ["

# --- env breakage is exit 10, distinct from gate-unmet exit 1 (batch #2) ---
repoEnv=$(new_repo env_error)
run_ledger "$repoEnv" init 2026-08-18-env --workflow workflow-deliver \
    --kind feature --steps "impl"
assert_status "env fixture init exits 0" 0 "$STATUS"
export LEDGER_PYTHON=/nonexistent-python-e93f
run_ledger "$repoEnv" show
assert_status "misconfigured LEDGER_PYTHON exits 10 on show" 10 "$STATUS"
run_ledger "$repoEnv" check finalize
assert_status "check with broken python env exits 10, not 1" 10 "$STATUS"
unset LEDGER_PYTHON

# Git/repo breakage is env-shaped too (style R1): running outside a git
# repository is exit 10, not the gate-unmet/usage exit 1.
norepo="$TMPDIR_BASE/norepo"
mkdir -p "$norepo"
run_ledger "$norepo" show
assert_status "outside a git repository exits 10" 10 "$STATUS"

# --- kind: bug template + diagnose/fix gates ---
repoB=$(new_repo bug_template)
stateB=$(live_state "$repoB")
run_ledger "$repoB" init 2026-08-19-bugfix --workflow workflow-debug \
    --kind bug --steps "impl"
assert_status "bug init exits 0" 0 "$STATUS"
assert_file_contains "bug kind auto-inserts diagnose step" "$stateB" "id: diagnose"
assert_file_contains "bug kind auto-inserts fix step" "$stateB" "id: fix"

run_ledger "$repoB" set diagnose skipped --reason "skip it"
assert_status "auto-inserted diagnose is required (skip refused, exit 3)" 3 "$STATUS"

run_ledger "$repoB" stamp fix --attest regression_test=test/regress.sh --attest rationale=r
assert_status "stamp fix before diagnose exits 2" 2 "$STATUS"
assert_contains "fix-before-diagnose names the unmet gate" "$OUT" "diagnose"

printf '#!/usr/bin/env bash\ntest -f fixed.txt\n' >"$repoB/repro.sh"
commit_all "$repoB" "test: add repro script"

run_ledger "$repoB" stamp diagnose --attest repro_cmd="bash repro.sh" \
    --attest root_cause="fixed.txt marker missing"
assert_status "stamp diagnose with red repro exits 0" 0 "$STATUS"

run_ledger "$repoB" check diagnose
assert_status "check diagnose fresh after stamp" 0 "$STATUS"

echo "note" >>"$repoB/src/app.py"
commit_all "$repoB" "docs: unrelated commit"
run_ledger "$repoB" check diagnose
assert_status "commit after stamp makes check exit 1" 1 "$STATUS"
assert_contains "stale check says STALE" "$OUT" "STALE"

run_ledger "$repoB" stamp fix --attest regression_test=test/regress.sh \
    --attest rationale="not fixed yet"
assert_status "stamp fix while repro still red exits 2" 2 "$STATUS"

echo "fixed" >"$repoB/fixed.txt"
mkdir -p "$repoB/test"
printf '#!/usr/bin/env bash\ntest -f fixed.txt\n' >"$repoB/test/regress.sh"
commit_all "$repoB" "fix: create marker + regression test"

run_ledger "$repoB" stamp fix --attest regression_test=test/nope.sh \
    --attest rationale="wrong path"
assert_status "stamp fix with missing regression file exits 2" 2 "$STATUS"
assert_contains "missing regression failure names the path" "$OUT" "test/nope.sh"

run_ledger "$repoB" stamp fix --attest regression_test=test/regress.sh \
    --attest rationale="marker created, regression added"
assert_status "stamp fix green repro + regression exits 0" 0 "$STATUS"
run_ledger "$repoB" check fix
assert_status "check fix fresh after stamp" 0 "$STATUS"

# The freshness exemption is the run's OWN file only: a commit touching a
# DIFFERENT run's snapshot (e.g. arriving via merge) is a real commit and
# must read STALE — cross-run files never share each other's exemption.
mkdir -p "$repoB/docs/executions/runs"
printf 'foreign: true\n' >"$repoB/docs/executions/runs/2026-08-19-foreign-run.yaml"
git -C "$repoB" add -- docs/executions/runs/2026-08-19-foreign-run.yaml
git -C "$repoB" commit -q -m "chore(ledger): stamp fix" \
    -- docs/executions/runs/2026-08-19-foreign-run.yaml
run_ledger "$repoB" check fix
assert_status "commit touching another run's file is NOT exempt" 1 "$STATUS"
assert_contains "foreign-run-file commit reads STALE" "$OUT" "STALE"
git -C "$repoB" rm -q -- docs/executions/runs/2026-08-19-foreign-run.yaml
git -C "$repoB" commit -q -m "chore: drop foreign run file"

# The narrowing pin: under the old kernel a commit touching only the shared
# docs/executions/state.yaml was the exempt shape; it must now read STALE.
run_ledger "$repoB" stamp fix --attest regression_test=test/regress.sh \
    --attest rationale="restamp for legacy-path pin"
assert_status "fix re-stamp for legacy-path pin exits 0" 0 "$STATUS"
printf 'legacy touch\n' >"$repoB/docs/executions/state.yaml"
git -C "$repoB" add -- docs/executions/state.yaml
git -C "$repoB" commit -q -m "chore(ledger): stamp fix" -- docs/executions/state.yaml
run_ledger "$repoB" check fix
assert_status "commit touching only legacy state.yaml is NOT exempt" 1 "$STATUS"
assert_contains "legacy-path commit reads STALE" "$OUT" "STALE"

# --- repro_tail redaction + snapshot cap (batch #4) ---
repoRT=$(new_repo redact_tail)
stateRT=$(live_state "$repoRT")
run_ledger "$repoRT" init 2026-08-18-redact --workflow workflow-deliver \
    --kind bug --steps "impl"
cat >"$repoRT/leaky.sh" <<'LEAK'
#!/usr/bin/env bash
echo "token=supersecretvalue1234 ghp_ABCDEFGHIJKLMNOPQRSTuvwx" # pragma: allowlist secret
printf 'x%.0s' $(seq 1 120)
echo ""
exit 1
LEAK
commit_all "$repoRT" "test: leaky red repro"
run_ledger "$repoRT" stamp diagnose --attest repro_cmd="bash leaky.sh" \
    --attest root_cause="token=attested-stays-verbatim by design"
assert_status "diagnose stamp with leaky repro exits 0" 0 "$STATUS"
# Attested values must stay verbatim (the fix gate re-executes repro_cmd);
# redaction covers only script-captured checked values (tests-lane pin).
assert_file_contains "attested values are not redacted" "$stateRT" \
    "token=attested-stays-verbatim"
assert_file_not_contains "live tail redacts the ghp_ token" "$stateRT" \
    "ghp_ABCDEFGHIJKLMNOPQRSTuvwx" # pragma: allowlist secret
assert_file_not_contains "live tail redacts the token= value" "$stateRT" \
    "supersecretvalue1234"
assert_file_contains "live tail carries a REDACTED marker" "$stateRT" "REDACTED"
snapRT="$(run_snap "$repoRT" 2026-08-18-redact)"
assert_file_not_contains "committed snapshot never carries the secret" \
    "$snapRT" "supersecretvalue1234"
long_run="$(printf 'x%.0s' $(seq 1 100))"
assert_file_contains "live state keeps the full tail" "$stateRT" "$long_run"
assert_file_not_contains "snapshot repro_tail is capped" "$snapRT" "$long_run"
assert_file_contains "snapshot marks the truncation" "$snapRT" "truncated"

# --- override flow ---
run_ledger "$repoB" stamp diagnose --attest repro_cmd="bash repro.sh" \
    --attest root_cause="restamp after fix"
assert_status "stamp diagnose with green repro fails checked field (exit 2)" 2 "$STATUS"

run_ledger "$repoB" stamp diagnose --override --attest repro_cmd="bash repro.sh"
assert_status "override without --reason exits 4" 4 "$STATUS"

run_ledger "$repoB" stamp diagnose --override --reason "post-fix restamp" \
    --attest repro_cmd="bash repro.sh"
assert_status "override with reason exits 0" 0 "$STATUS"
assert_contains "override stamp warns loudly with the reason" "$OUT" "post-fix restamp"
assert_file_contains "overrides[] audit trail records the reason" "$stateB" "post-fix restamp"

run_ledger "$repoB" check diagnose
assert_status "check passes on overridden gate" 0 "$STATUS"
assert_contains "overridden check prints OVERRIDDEN with reason" "$OUT" "OVERRIDDEN: post-fix restamp"

# --- override freshness: an expired override is not standing authorization ---
repoOS=$(new_repo override_stale)
run_ledger "$repoOS" init 2026-08-18-ovstale --workflow workflow-debug \
    --kind bug --steps "diagnose,fix,review,finalize"
run_ledger "$repoOS" stamp finalize --override --reason "audited bypass: repro window"
assert_status "finalize override stamp exits 0" 0 "$STATUS"

run_ledger "$repoOS" check finalize
assert_status "fresh override check exits 0" 0 "$STATUS"
assert_contains "fresh override prints OVERRIDDEN with reason" "$OUT" \
    "OVERRIDDEN: audited bypass: repro window"

echo "drift" >"$repoOS/src/drift.py"
commit_all "$repoOS" "feat: non-snapshot commit after the override"

run_ledger "$repoOS" check finalize
assert_status "stale override check exits 1" 1 "$STATUS"
assert_contains "stale override prints the distinct OVERRIDE_STALE prefix" "$OUT" "OVERRIDE_STALE:"
assert_contains "stale override output carries the recorded reason" "$OUT" \
    "audited bypass: repro window"

# --- verify-local ---
repoF=$(new_repo verify_local)
run_ledger "$repoF" init 2026-08-19-verify --workflow workflow-build-one \
    --kind feature --steps "impl"
run_ledger "$repoF" verify-local
assert_status "verify-local without manifest exits 9" 9 "$STATUS"
assert_contains "missing manifest says NO_MANIFEST" "$OUT" "NO_MANIFEST"

printf -- '- "true"\n- "echo ok"\n' >"$repoF/docs/executions/ci-commands.yaml"
commit_all "$repoF" "chore: add ci manifest"
run_ledger "$repoF" verify-local
assert_status "verify-local all-pass exits 0" 0 "$STATUS"

printf -- '- "true"\n- "false"\n' >"$repoF/docs/executions/ci-commands.yaml"
commit_all "$repoF" "chore: break ci manifest"
run_ledger "$repoF" verify-local
assert_status "verify-local with failing command exits 1" 1 "$STATUS"
assert_contains "verify-local echoes the failing command" "$OUT" "false"

# --- preflight (mock SKILLS_ROOT only; never the real one) ---
mock_skills="$TMPDIR_BASE/skillsroot"
mkdir -p "$mock_skills/goodskill" "$mock_skills/badskill"
printf '# goodskill\n\n## Contract\n\nRequires: git, bash\n' >"$mock_skills/goodskill/SKILL.md"
printf '# badskill\n\n## Contract\n\nRequires: git, absolutely-missing-tool-93af\n' >"$mock_skills/badskill/SKILL.md"

repoP=$(new_repo preflight)
LEDGER_SKILLS_ROOT="$mock_skills"
run_ledger "$repoP" preflight --skill goodskill
assert_status "preflight all tools present exits 0" 0 "$STATUS"
run_ledger "$repoP" preflight --skill badskill
assert_status "preflight missing tool exits 1" 1 "$STATUS"
assert_contains "preflight lists the missing tool" "$OUT" "absolutely-missing-tool-93af"
run_ledger "$repoP" preflight --skill ghostskill
assert_status "preflight unknown skill exits 5" 5 "$STATUS"
LEDGER_SKILLS_ROOT=""

# --- review-floor: size + pattern triggers, determinism, repo override ---
repoE=$(new_repo review_floor)
run_ledger "$repoE" init 2026-08-19-floor --workflow workflow-build-one \
    --kind feature --steps "impl"
git -C "$repoE" tag t0
for i in $(seq 1 16); do echo "file $i" >"$repoE/src/gen_$i.txt"; done
commit_all "$repoE" "feat: add sixteen files"
run_ledger "$repoE" review-floor --base t0
assert_status "review-floor >15 files exits 0" 0 "$STATUS"
assert_equal "review-floor >15 files prints full" "full" "$OUT"

git -C "$repoE" tag t1
seq 1 600 >"$repoE/src/bigfile.txt"
commit_all "$repoE" "feat: add 600-line file"
run_ledger "$repoE" review-floor --base t1
assert_equal "review-floor >500 LOC prints full" "full" "$OUT"

git -C "$repoE" tag t2
echo "small tweak" >>"$repoE/src/app.py"
commit_all "$repoE" "fix: small tweak"
run_ledger "$repoE" review-floor --base t2
assert_equal "review-floor small diff prints fast" "fast" "$OUT"
floor_first="$OUT"
run_ledger "$repoE" review-floor --base t2
assert_equal "review-floor is deterministic (same diff, same word)" "$floor_first" "$OUT"

git -C "$repoE" tag t3
mkdir -p "$repoE/auth"
echo "token = 'x'" >"$repoE/auth/token.py"
commit_all "$repoE" "feat: touch auth path"
# Pattern hits are security-flagged (batch #7): the floor word carries a
# +security suffix so the flag is recorded, not silently dropped.
run_ledger "$repoE" review-floor --base t3
assert_equal "review-floor auth path pattern prints standard+security" \
    "standard+security" "$OUT"

echo "frobnicate" >"$repoE/docs/executions/review-patterns.txt"
commit_all "$repoE" "chore: add repo review-pattern override"
git -C "$repoE" tag t4
mkdir -p "$repoE/frobnicate"
echo "hit" >"$repoE/frobnicate/x.txt"
commit_all "$repoE" "feat: touch override pattern path"
run_ledger "$repoE" review-floor --base t4
assert_equal "review-floor repo override pattern prints standard+security" \
    "standard+security" "$OUT"

# --- review gate in a baseline-cut worktree ---
wt1=$(new_wt_fixture review_gate)
lanes1="$TMPDIR_BASE/review_gate/lanes"
mkdir -p "$lanes1"
lane1="$lanes1/integrated-review.md"

run_ledger "$wt1" init 2026-08-19-rev --workflow workflow-build-one \
    --kind feature --steps "impl,review,finalize"
printf -- '- "true"\n' >"$wt1/docs/executions/ci-commands.yaml"
echo "tweak" >>"$wt1/src/app.py"
commit_all "$wt1" "feat: small change under review"

run_ledger "$wt1" review-floor --base origin/main
assert_equal "worktree small diff floor is fast" "fast" "$OUT"

run_ledger "$wt1" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$lane1" \
    --attest model_floor=sonnet
assert_status "stamp review with missing lane file exits 2" 2 "$STATUS"
assert_contains "missing lane failure names the lane" "$OUT" "integrated"

printf 'model: opus\nnotes: looks fine\n' >"$lane1"
run_ledger "$wt1" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$lane1" \
    --attest model_floor=sonnet
assert_status "lane file without verdict line exits 2" 2 "$STATUS"
assert_contains "verdict-less lane failure names verdict" "$OUT" "verdict"

printf 'model: haiku\nverdict: approve\n' >"$lane1"
run_ledger "$wt1" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$lane1" \
    --attest model_floor=sonnet
assert_status "lane model below floor exits 2" 2 "$STATUS"
assert_contains "below-floor failure names model" "$OUT" "model"

# Lane freshness binding (batch #3, bit us twice live): a lane file whose
# mtime predates this run's init is a stale artifact from an earlier
# session and must not satisfy the stamp.
printf 'model: opus\nverdict: approve\n' >"$lane1"
touch -t 202001010000 "$lane1"
run_ledger "$wt1" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$lane1" \
    --attest model_floor=sonnet
assert_status "lane file predating run init exits 2" 2 "$STATUS"
assert_contains "stale lane failure says predates" "$OUT" "predates"

printf 'model: opus\nverdict: approve\n' >"$lane1"
run_ledger "$wt1" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$lane1" \
    --attest model_floor=sonnet
assert_status "valid review stamp exits 0" 0 "$STATUS"

run_ledger "$wt1" check review
assert_status "check review fresh after stamp" 0 "$STATUS"

run_ledger "$wt1" verify-local
assert_status "verify-local passes in worktree" 0 "$STATUS"

# --- finalize gate ---
# Finalize now resolves the branch PR via forge itself (R1 MF5); the fixture
# has a file-path origin (detects as forgejo), so provide a mock lookup
# answering "none" and the test sentinel that permits mock in stamps.
FORGE_MOCK_DIR="$TMPDIR_BASE/review_gate/forge-mock"
mkdir -p "$FORGE_MOCK_DIR"
# Slashed branch names sanitize to flat mock filenames (batch #8).
printf 'none\n' >"$FORGE_MOCK_DIR/forgejo-pr-for-branch-feature_review_gate"
export FORGE_MOCK_DIR
export LEDGER_ALLOW_FORGE_MOCK=1

echo "scratch" >"$wt1/scratch.tmp"
run_ledger "$wt1" stamp finalize --attest post_mortem=docs/pm.md \
    --attest describe_pr=done
assert_status "stamp finalize with dirty tree exits 2" 2 "$STATUS"
rm -f "$wt1/scratch.tmp"

run_ledger "$wt1" stamp finalize --gate-type maintainer-decision \
    --attest post_mortem=docs/pm.md --attest describe_pr=done
assert_status "non-reviewer gate type without --human exits 8" 8 "$STATUS"

run_ledger "$wt1" stamp finalize --attest post_mortem=docs/pm.md \
    --attest describe_pr=done
assert_status "finalize happy path (no PR yet) exits 0" 0 "$STATUS"
# R2 MF1: a mock-sourced stamp must be self-evident in the committed snapshot.
assert_file_contains "mock-allowed stamp carries forge_mock marker" \
    "$(run_snap "$wt1" 2026-08-19-rev)" "forge_mock"

run_ledger "$wt1" check finalize
assert_status "check finalize fresh after stamp" 0 "$STATUS"

echo "more" >>"$wt1/src/app.py"
commit_all "$wt1" "feat: commit after finalize stamp"
run_ledger "$wt1" check finalize
assert_status "finalize goes stale after new commit" 1 "$STATUS"
assert_contains "stale finalize says STALE" "$OUT" "STALE"

run_ledger "$wt1" stamp finalize --gate-type maintainer-decision --human \
    --attest post_mortem=docs/pm.md --attest describe_pr=done
assert_status_not "--human path is accepted (never exit 8)" 8 "$STATUS"

# R1 MF1 negative test: a code commit with a spoofed ledger subject must NOT
# count as fresh — the exemption is content-verified, not subject-verified.
# Re-establish the full fresh chain at current HEAD first.
run_ledger "$wt1" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$lane1"
assert_status "review re-stamp at current HEAD exits 0" 0 "$STATUS"
run_ledger "$wt1" verify-local
assert_status "verify-local re-run at current HEAD exits 0" 0 "$STATUS"
run_ledger "$wt1" stamp finalize --attest post_mortem=docs/pm.md \
    --attest describe_pr=done
assert_status "finalize re-stamp for spoof test exits 0" 0 "$STATUS"
echo "sneak" >>"$wt1/src/app.py"
commit_all "$wt1" "chore(ledger): sneaky non-snapshot commit"
run_ledger "$wt1" check finalize
assert_status "chore(ledger)-titled code commit is NOT exempt" 1 "$STATUS"
assert_contains "subject-spoofed commit reads STALE" "$OUT" "STALE"

# Mock refusal without the sentinel (R1 MF6): same env minus the allowance.
unset LEDGER_ALLOW_FORGE_MOCK
run_ledger "$wt1" stamp finalize --attest post_mortem=docs/pm.md \
    --attest describe_pr=done
assert_status "stamp finalize refuses mock forge without sentinel" 2 "$STATUS"
assert_contains "mock refusal names FORGE_MOCK_DIR" "$OUT" "FORGE_MOCK_DIR"
export LEDGER_ALLOW_FORGE_MOCK=1

# --- finalize accepts a draft PR (Phase 3 review F3) ---
# Default REPO_DELIVERY_POLICY (human-only) keeps the PR draft through the
# stamp, and forge.sh maps isDraft to "draft" — so draft must stamp like open
# (recording the actual state), while any other reported state still refuses.
# (A real merged/closed PR usually resolves to no_pr at the open-PR lookup;
# the refusal cases below cover the forge answering a non-open/draft state.)
run_ledger "$wt1" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$lane1"
assert_status "review re-stamp for draft-PR test exits 0" 0 "$STATUS"
run_ledger "$wt1" verify-local
assert_status "verify-local re-run for draft-PR test exits 0" 0 "$STATUS"

# Sanitized flat mock name (batch #8): branch feature/review_gate.
printf '7\n' >"$FORGE_MOCK_DIR/forgejo-pr-for-branch-feature_review_gate"
printf 'green\n' >"$FORGE_MOCK_DIR/forgejo-ci-status-7"
printf 'draft\n' >"$FORGE_MOCK_DIR/forgejo-pr-state-7"
printf 'yes\n' >"$FORGE_MOCK_DIR/forgejo-threads-resolved-7"

run_ledger "$wt1" stamp finalize --attest post_mortem=docs/pm.md \
    --attest describe_pr=done
assert_status "finalize stamp accepts a draft PR" 0 "$STATUS"
assert_file_contains "draft stamp records actual pr_state" \
    "$(run_snap "$wt1" 2026-08-19-rev)" "pr_state: draft"

printf 'closed\n' >"$FORGE_MOCK_DIR/forgejo-pr-state-7"
run_ledger "$wt1" stamp finalize --attest post_mortem=docs/pm.md \
    --attest describe_pr=done
assert_status "finalize stamp still refuses a closed PR" 2 "$STATUS"
assert_contains "closed refusal names the state" "$OUT" "is not open or draft: closed"

printf 'merged\n' >"$FORGE_MOCK_DIR/forgejo-pr-state-7"
run_ledger "$wt1" stamp finalize --attest post_mortem=docs/pm.md \
    --attest describe_pr=done
assert_status "finalize stamp still refuses a merged PR" 2 "$STATUS"
assert_contains "merged refusal names the state" "$OUT" "is not open or draft: merged"

# Restore the pre-block mock invariant (lookup answers none, no PR-7 files).
printf 'none\n' >"$FORGE_MOCK_DIR/forgejo-pr-for-branch-feature_review_gate"
rm -f "$FORGE_MOCK_DIR/forgejo-ci-status-7" "$FORGE_MOCK_DIR/forgejo-pr-state-7" \
    "$FORGE_MOCK_DIR/forgejo-threads-resolved-7"

run_ledger "$wt1" close
assert_status "close exits 0" 0 "$STATUS"
state_wt1=$(live_state "$wt1")
assert_file_contains "close sets status done" "$state_wt1" "status: done"
assert_file_matches "close empties next" "$state_wt1" "^next: *(''|\"\")?$"
last_msg=$(git -C "$wt1" log -1 --pretty=%s)
assert_contains "close commits snapshot as chore(ledger)" "$last_msg" "chore(ledger): close"

# --- profile below floor (auth-flagged diff forces standard) ---
wt2=$(new_wt_fixture profile_floor)
lanes2="$TMPDIR_BASE/profile_floor/lanes"
mkdir -p "$lanes2"
lane2="$lanes2/integrated-review.md"
printf 'model: opus\nverdict: approve\n' >"$lane2"

run_ledger "$wt2" init 2026-08-19-authrev --workflow workflow-build-one \
    --kind feature --steps "impl,review"
echo "token = 'changed'" >"$wt2/auth/token.py"
commit_all "$wt2" "feat: auth-path change"

run_ledger "$wt2" review-floor --base origin/main
assert_equal "auth diff floor is standard+security in worktree" \
    "standard+security" "$OUT"

run_ledger "$wt2" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$lane2" \
    --attest model_floor=sonnet
assert_status "chosen profile below floor exits 2" 2 "$STATUS"
assert_contains "below-floor failure names profile" "$OUT" "profile"

# Security-flagged floor requires a security lane even when the profile's
# base lane set does not include one (batch #7).
lane2_logic="$lanes2/logic-review.md"
lane2_tests="$lanes2/tests-review.md"
lane2_sec="$lanes2/security-review.md"
printf 'model: opus\nverdict: approve\n' >"$lane2_logic"
printf 'model: opus\nverdict: approve\n' >"$lane2_tests"
run_ledger "$wt2" stamp review --attest verdict=approve \
    --attest review_profile=standard \
    --attest "lanes=logic=$lane2_logic,tests=$lane2_tests"
assert_status "security-flagged floor without security lane exits 2" 2 "$STATUS"
assert_contains "missing security lane is named" "$OUT" "security"

printf 'model: opus\nverdict: approve\n' >"$lane2_sec"
run_ledger "$wt2" stamp review --attest verdict=approve \
    --attest review_profile=standard \
    --attest "lanes=logic=$lane2_logic,tests=$lane2_tests,security=$lane2_sec"
assert_status "security lane present satisfies the flagged floor" 0 "$STATUS"
assert_file_contains "checked review_floor records the security flag" \
    "$(run_snap "$wt2" 2026-08-19-authrev)" "standard+security"

# The attested profile is exactly fast|standard|full (logic R1 must-fix): a
# suffixed value like full+security must be rejected, not rank as full while
# collapsing required_lanes to its default.
run_ledger "$wt2" stamp review --attest verdict=approve \
    --attest review_profile=full+security \
    --attest "lanes=integrated=$lane2_logic,logic=$lane2_logic,tests=$lane2_tests,security=$lane2_sec"
assert_status "suffixed attested review_profile is rejected" 2 "$STATUS"
assert_contains "invalid profile failure names review_profile" "$OUT" "review_profile"

# --- snapshot_current: committed snapshot must match live at finalize (batch #8) ---
# A hand-crafted commit that touches ONLY the snapshot file is
# freshness-exempt by design, so the PR-visible record could be rewritten
# without staling any stamp. Finalize closes the hole by comparing the
# committed snapshot's durable content (run identity, stamps, overrides)
# against live state.
wt3=$(new_wt_fixture snapshot_drift)
snap3_rel="docs/executions/runs/2026-08-18-snap.yaml"
snap3="$wt3/$snap3_rel"
lanes3="$TMPDIR_BASE/snapshot_drift/lanes"
mkdir -p "$lanes3"
lane3="$lanes3/integrated-review.md"
printf 'none\n' >"$FORGE_MOCK_DIR/forgejo-pr-for-branch-feature_snapshot_drift"

run_ledger "$wt3" init 2026-08-18-snap --workflow workflow-deliver \
    --kind feature --steps "impl,review,finalize"
# Give the run a long repro tail so the legacy-shape (uncapped byte-copy)
# snapshot below exercises the cap-normalized comparison (logic R1).
# shellcheck disable=SC2016 # the $(seq) must land literally in the script.
printf '#!/usr/bin/env bash\nprintf "y%%.0s" $(seq 1 120)\nexit 1\n' >"$wt3/long.sh"
commit_all "$wt3" "test: long-output red repro"
run_ledger "$wt3" stamp diagnose --attest repro_cmd="bash long.sh" \
    --attest root_cause="long tail fixture"
assert_status "wt3 diagnose stamp exits 0" 0 "$STATUS"
printf -- '- "true"\n' >"$wt3/docs/executions/ci-commands.yaml"
echo "tweak" >>"$wt3/src/app.py"
commit_all "$wt3" "feat: change under review"
printf 'model: opus\nverdict: approve\n' >"$lane3"
run_ledger "$wt3" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$lane3"
assert_status "snapshot fixture review stamp exits 0" 0 "$STATUS"

sed -i.bak 's/^run_id: .*/run_id: forged-run/' "$snap3"
rm -f "$snap3.bak"
git -C "$wt3" add -- "$snap3_rel"
git -C "$wt3" commit -q -m "chore(ledger): stamp review" -- "$snap3_rel"

run_ledger "$wt3" check review
assert_status "snapshot-only tamper commit keeps stamps fresh (the hole)" 0 "$STATUS"

run_ledger "$wt3" verify-local
assert_status "verify-local passes in snapshot fixture" 0 "$STATUS"
run_ledger "$wt3" stamp finalize --attest post_mortem=docs/pm.md \
    --attest describe_pr=done
assert_status "finalize refuses a tampered committed snapshot" 2 "$STATUS"
assert_contains "snapshot mismatch failure is the snapshot check itself" "$OUT" \
    "does not match live ledger state"

# Deliberate legacy-shape restore: a byte-copy of live state (pre-cap
# snapshots were exactly this). snapshot_match must normalize both sides,
# so benign version skew is never misdiagnosed as tampering (logic R1).
cp "$(live_state "$wt3")" "$snap3"
git -C "$wt3" add -- "$snap3_rel"
git -C "$wt3" commit -q -m "chore(ledger): restore snapshot" -- "$snap3_rel"
run_ledger "$wt3" stamp finalize --attest post_mortem=docs/pm.md \
    --attest describe_pr=done
assert_status "finalize passes on a legacy byte-copy snapshot of live" 0 "$STATUS"
assert_file_contains "finalize records the snapshot_current checked field" \
    "$snap3" "snapshot_current"

# A tamper AFTER the finalize stamp is freshness-exempt (snapshot-only
# commit), so `check finalize` itself must compare the snapshot (security
# lane): stamps and overrides are the durable keys worth forging.
run_ledger "$wt3" check finalize
assert_status "check finalize OK after the finalize stamp" 0 "$STATUS"

sed -i.bak 's/verdict: approve/verdict: forged/g' "$snap3"
rm -f "$snap3.bak"
git -C "$wt3" add -- "$snap3_rel"
git -C "$wt3" commit -q -m "chore(ledger): stamp finalize" -- "$snap3_rel"
run_ledger "$wt3" check finalize
assert_status "post-stamp verdict tamper fails check finalize" 1 "$STATUS"
assert_contains "post-stamp tamper reads SNAPSHOT_DRIFT" "$OUT" "SNAPSHOT_DRIFT"

cp "$(live_state "$wt3")" "$snap3"
git -C "$wt3" add -- "$snap3_rel"
git -C "$wt3" commit -q -m "chore(ledger): restore snapshot" -- "$snap3_rel"
run_ledger "$wt3" check finalize
assert_status "check finalize recovers after restore" 0 "$STATUS"

sed -i.bak 's/^overrides: \[\]/overrides: [{gate: finalize, reason: forged-bypass}]/' \
    "$snap3"
rm -f "$snap3.bak"
git -C "$wt3" add -- "$snap3_rel"
git -C "$wt3" commit -q -m "chore(ledger): stamp finalize" -- "$snap3_rel"
run_ledger "$wt3" check finalize
assert_status "post-stamp overrides tamper fails check finalize" 1 "$STATUS"
assert_contains "overrides tamper reads SNAPSHOT_DRIFT" "$OUT" "SNAPSHOT_DRIFT"

# Route is a durable snapshot key: forging one into the tracked snapshot
# (live state has none) is tampering (D-006 Phase 5b).
cp "$(live_state "$wt3")" "$snap3"
printf 'route: forged|other-flow|confirmed\n' >>"$snap3"
git -C "$wt3" add -- "$snap3_rel"
git -C "$wt3" commit -q -m "chore(ledger): stamp finalize" -- "$snap3_rel"
run_ledger "$wt3" check finalize
assert_status "forged snapshot route fails check finalize" 1 "$STATUS"
assert_contains "forged snapshot route reads SNAPSHOT_DRIFT" "$OUT" "SNAPSHOT_DRIFT"

# --- init --route: route evidence (D-006 Phase 5b) ------------------------
# Contract: `init --route "<classification>|<selected-flow>|confirmed"` records
# a top-level `route:` field. Absent route: init succeeds but WARNs (default),
# or exits 11 under LEDGER_REQUIRE_ROUTE=block (same flip pattern as
# LEDGER_ENTRY_ENFORCE). Malformed route strings are schema-invalid (exit 6),
# both at init time and when loading tampered state.

repoR=$(new_repo route_evidence)
stateR=$(live_state "$repoR")

run_ledger "$repoR" init 2026-08-19-routed --workflow workflow-deliver \
    --kind feature --steps "plan,impl" \
    --route "ready issue|workflow-deliver|confirmed"
assert_status "init with --route exits 0" 0 "$STATUS"
assert_file_contains "live state records top-level route field" "$stateR" \
    "route: ready issue|workflow-deliver|confirmed"
assert_file_contains "committed snapshot carries route field" \
    "$(run_snap "$repoR" 2026-08-19-routed)" \
    "route: ready issue|workflow-deliver|confirmed"

run_ledger "$repoR" set plan completed --evidence "routed run step"
assert_status "set after routed init exits 0" 0 "$STATUS"
assert_file_contains "route field round-trips through subsequent writes" \
    "$stateR" "route: ready issue|workflow-deliver|confirmed"

run_ledger "$repoR" show
assert_contains "show renders the route evidence" "$OUT" \
    "ready issue|workflow-deliver|confirmed"

run_ledger "$repoR" init 2026-08-19-unrouted --workflow workflow-deliver \
    --kind feature --steps "plan" --force
assert_status "init without --route exits 0 (default is warn)" 0 "$STATUS"
assert_contains "unrouted init warns: no route evidence" "$OUT" \
    "no route evidence — invoke workflow-router"
assert_file_not_contains "unrouted init records no route field" "$stateR" "route:"

OUT="$(cd "$repoR" && LEDGER_REQUIRE_ROUTE=block SKILLS_ROOT="$SKILLS_ROOT_REAL" \
    bash "$LEDGER" init 2026-08-19-blocked --workflow workflow-deliver \
    --kind feature --steps "plan" --force 2>&1)"
STATUS=$?
assert_status "LEDGER_REQUIRE_ROUTE=block escalates absent route to exit 11" 11 "$STATUS"
assert_contains "blocked init names the missing route evidence" "$OUT" "no route evidence"
assert_file_contains "blocked init writes nothing (prior run intact)" "$stateR" \
    "run_id: 2026-08-19-unrouted"

OUT="$(cd "$repoR" && LEDGER_REQUIRE_ROUTE=block SKILLS_ROOT="$SKILLS_ROOT_REAL" \
    bash "$LEDGER" init 2026-08-19-routed2 --workflow workflow-deliver \
    --kind bug --steps "plan" --route "bug|workflow-deliver|confirmed" --force 2>&1)"
STATUS=$?
assert_status "block env with --route present exits 0" 0 "$STATUS"
assert_file_contains "block env records the route field" "$stateR" \
    "route: bug|workflow-deliver|confirmed"

for bad in "no-pipes-here" "a|b" "a|b|maybe" "|b|confirmed" "a||confirmed" \
    "a|b|confirmed|extra"; do
    run_ledger "$repoR" init 2026-08-19-badroute --workflow workflow-deliver \
        --kind feature --steps "plan" --route "$bad" --force
    assert_status "malformed route '$bad' exits 6" 6 "$STATUS"
done
assert_file_contains "malformed route writes nothing (prior run intact)" "$stateR" \
    "run_id: 2026-08-19-routed2"

# Schema layer: a malformed route smuggled into existing state fails load.
printf 'route: tampered-no-pipes\n' >>"$stateR"
run_ledger "$repoR" show
assert_status "schema rejects malformed route on load with exit 6" 6 "$STATUS"
assert_contains "load rejection names the bad route" "$OUT" "bad route"

# --- cross-run non-interference: concurrent runs share no committed path ---
# The defect this design fix removes: two concurrent stamped PRs both
# committing docs/executions/state.yaml merge-conflicted on it every time
# (#167 twice, #174, #180, #181 within 24h), forcing keep-ours resolutions
# plus full restamp ceremonies. Per-run files make the conflict structurally
# impossible: each run commits only docs/executions/runs/<run_id>.yaml, so
# two branches carrying two runs merge cleanly into the same base.
fixtureX="$TMPDIR_BASE/concurrent"
originX="$fixtureX/origin.git"
seedX="$fixtureX/seed"
workX="$fixtureX/work"
wtA="$fixtureX/wtA"
wtB="$fixtureX/wtB"

mkdir -p "$fixtureX"
git init --bare -q "$originX"
git -C "$originX" symbolic-ref HEAD refs/heads/main
git clone -q "$originX" "$seedX"
git -C "$seedX" config user.email "t@example.com"
git -C "$seedX" config user.name "Test"
mkdir -p "$seedX/docs/executions" "$seedX/src"
echo "opted-in" >"$seedX/docs/executions/.gitkeep"
echo "print('app')" >"$seedX/src/app.py"
git -C "$seedX" add -A
git -C "$seedX" commit -q -m init
git -C "$seedX" push -q origin main
rm -rf "$seedX"

git clone -q "$originX" "$workX"
git -C "$workX" config user.email "t@example.com"
git -C "$workX" config user.name "Test"
(cd "$workX" && bash "$BASELINE" cut --branch feature/lane-a --path "$wtA" >/dev/null 2>&1)
(cd "$workX" && bash "$BASELINE" cut --branch feature/lane-b --path "$wtB" >/dev/null 2>&1)
for wt in "$wtA" "$wtB"; do
    git -C "$wt" config user.email "t@example.com" 2>/dev/null
    git -C "$wt" config user.name "Test" 2>/dev/null
done

run_ledger "$wtA" init 2026-08-19-lane-a --workflow workflow-deliver \
    --kind feature --steps "impl" --route "ready issue|workflow-deliver|confirmed"
assert_status "lane-a init exits 0" 0 "$STATUS"
run_ledger "$wtB" init 2026-08-19-lane-b --workflow workflow-deliver \
    --kind feature --steps "impl" --route "ready issue|workflow-deliver|confirmed"
assert_status "lane-b init exits 0" 0 "$STATUS"

assert_file_exists "lane-a writes only its own run file" "$(run_snap "$wtA" 2026-08-19-lane-a)"
assert_file_not_exists "lane-a never sees lane-b's run file" "$(run_snap "$wtA" 2026-08-19-lane-b)"
assert_file_not_exists "lane-a never writes the legacy shared path" \
    "$wtA/docs/executions/state.yaml"

echo "lane a work" >"$wtA/src/lane_a.py"
commit_all "$wtA" "feat: lane a work"
echo "lane b work" >"$wtB/src/lane_b.py"
commit_all "$wtB" "feat: lane b work"
git -C "$wtA" push -q origin feature/lane-a
git -C "$wtB" push -q origin feature/lane-b

mergeX="$fixtureX/merge"
git clone -q "$originX" "$mergeX"
git -C "$mergeX" config user.email "t@example.com"
git -C "$mergeX" config user.name "Test"
git -C "$mergeX" merge -q --no-edit origin/feature/lane-a >/dev/null 2>&1
mergeA=$?
assert_status "lane-a merges into main cleanly" 0 "$mergeA"
git -C "$mergeX" merge -q --no-edit origin/feature/lane-b >/dev/null 2>&1
mergeB=$?
assert_status "lane-b merges after lane-a with NO conflict (the design goal)" 0 "$mergeB"
assert_file_exists "merged main carries lane-a's run file" \
    "$(run_snap "$mergeX" 2026-08-19-lane-a)"
assert_file_exists "merged main carries lane-b's run file" \
    "$(run_snap "$mergeX" 2026-08-19-lane-b)"

# ============================================================================
# Kernel gaps (recorded 2026-08-20 handoff, unfixed until this run):
#   G1  `stamp review` records lane_<n>_verdict into CHECKED but never tests
#       its value — a REQUEST_CHANGES lane stamps clean whenever the agent
#       attests verdict=approve. Inverts D-006 #3 (a stamp is writable only
#       when all CHECKED fields pass) and falsifies workflow-review's own
#       claim that "the stamp's checks refuse to record it regardless".
#   G2  No revocation path: `set <step> pending` leaves stamps.<gate> intact
#       and check_gate reads the stamp, so `check review` still returns OK
#       after an explicit unwind.
#   G3  `set --evidence` corrections are unpublishable: commit_snapshot runs
#       only from init/stamp/close, so a run that finds a false evidence
#       string cannot ship the correction without passing a gate.
# Every assertion below checks the COMMITTED snapshot as well as live state
# where the gap is observable there — all three bugs are "live state is one
# thing, the PR-visible record is another".
# ============================================================================
echo ""
echo "--- G1: lane verdict is a checked field ---"

wtV=$(new_wt_fixture verdict_gate)
lanesV="$TMPDIR_BASE/verdict_gate/lanes"
mkdir -p "$lanesV"
laneV="$lanesV/integrated-review.md"
laneV_logic="$lanesV/logic-review.md"
laneV_tests="$lanesV/tests-review.md"

run_ledger "$wtV" init 2026-08-20-verdict --workflow workflow-deliver \
    --kind bug --steps "diagnose,fix,review,finalize"
assert_status "verdict fixture inits" 0 "$STATUS"
printf -- '- "true"\n' >"$wtV/docs/executions/ci-commands.yaml"
echo "tweak" >>"$wtV/src/app.py"
commit_all "$wtV" "fix: small change under review"
stateV=$(live_state "$wtV")
snapV="$(run_snap "$wtV" 2026-08-20-verdict)"

# The exact live scenario: reviewer said REQUEST_CHANGES, agent attests
# approve. The lane file is the ground truth and must refuse the stamp.
#
# R2 tests lane T6: a bare "integrated" / "REQUEST_CHANGES" needle also
# matches the lane FILE PATH echoed by unrelated exit-2 refusals (missing or
# stale lane file), so every verdict refusal greps the whole discriminating
# phrase and asserts the refusal is not the usage text.
printf 'model: opus\nverdict: REQUEST_CHANGES\n' >"$laneV"
run_ledger "$wtV" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$laneV" \
    --attest model_floor=sonnet
assert_status "REQUEST_CHANGES lane refuses the review stamp" 2 "$STATUS"
assert_contains "refusal names the lane and its rejecting verdict" "$OUT" \
    "lane 'integrated' verdict 'REQUEST_CHANGES'"
assert_not_contains "verdict refusal is not a usage error" "$OUT" "Usage:"
run_ledger "$wtV" check review
assert_status "check review MISSING after a refused stamp" 1 "$STATUS"
run_ledger "$wtV" check-snapshot review
assert_status "check-snapshot review MISSING after a refused stamp" 1 "$STATUS"
assert_file_not_contains "refused verdict never reaches the committed snapshot" \
    "$snapV" "REQUEST_CHANGES"

printf 'model: opus\nverdict: NEEDS_HUMAN\n' >"$laneV"
run_ledger "$wtV" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$laneV" \
    --attest model_floor=sonnet
assert_status "NEEDS_HUMAN lane refuses the review stamp" 2 "$STATUS"
assert_contains "NEEDS_HUMAN refusal names the lane and its verdict" "$OUT" \
    "lane 'integrated' verdict 'NEEDS_HUMAN'"

# Fail CLOSED on an unrecognized verdict, exactly as an unrecognized model
# ranks 0 and refuses: a denylist of rejection words would let a typo
# ("aproved", "LGTM") through.
printf 'model: opus\nverdict: LGTM\n' >"$laneV"
run_ledger "$wtV" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$laneV" \
    --attest model_floor=sonnet
assert_status "unrecognized lane verdict refuses the stamp" 2 "$STATUS"
assert_contains "unrecognized-verdict refusal names the lane and value" "$OUT" \
    "lane 'integrated' verdict 'LGTM'"

printf 'model: opus\nverdict:\n' >"$laneV"
run_ledger "$wtV" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$laneV" \
    --attest model_floor=sonnet
assert_status "empty verdict value refuses the stamp" 2 "$STATUS"
assert_contains "empty-verdict refusal reports the value as missing" "$OUT" \
    "lane 'integrated' verdict 'missing'"

# One approving lane cannot carry a rejecting sibling (multi-lane profile).
printf 'model: opus\nverdict: APPROVE\n' >"$laneV_logic"
printf 'model: opus\nverdict: REQUEST_CHANGES\n' >"$laneV_tests"
run_ledger "$wtV" stamp review --attest verdict=approve \
    --attest review_profile=standard \
    --attest "lanes=logic=$laneV_logic,tests=$laneV_tests" \
    --attest model_floor=opus
assert_status "one REQUEST_CHANGES lane sinks a multi-lane stamp" 2 "$STATUS"
assert_contains "multi-lane refusal names the rejecting lane and its verdict" \
    "$OUT" "lane 'tests' verdict 'REQUEST_CHANGES'"

# Accepted spellings. The contract token is APPROVE (reviewer-briefs.md
# Shared Output Contract); existing lane fixtures and live reviews write
# lowercase, and trailing whitespace / CRLF must not decide a gate.
printf 'model: opus\nverdict: APPROVE\n' >"$laneV"
run_ledger "$wtV" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$laneV" \
    --attest model_floor=sonnet
assert_status "uppercase APPROVE stamps" 0 "$STATUS"
run_ledger "$wtV" check review
assert_status "check review OK after an approving stamp" 0 "$STATUS"

# First `verdict:` line wins (the documented `head -1` rule, pinned
# deliberately): a reviewer who QUOTES `verdict: REQUEST_CHANGES` in the prose
# of an approving lane must not sink their own lane.
printf 'model: opus\nverdict: APPROVE\nnotes: the brief says to write\nverdict: REQUEST_CHANGES\nwhen a finding blocks\n' >"$laneV"
run_ledger "$wtV" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$laneV" \
    --attest model_floor=sonnet
assert_status "first verdict line wins over a quoted rejection" 0 "$STATUS"

run_ledger "$wtV" set review completed --evidence "review round 1 approved"
assert_status "review step completes alongside its stamp" 0 "$STATUS"

# Negative control for the revocation consequence asserted in G2: with the
# review gate standing, finalize refuses for OTHER reasons and must not blame
# the review gate. Without this control, "review gate" in the G2 refusal could
# be an artifact of the fixture rather than of the revocation.
run_ledger "$wtV" stamp finalize --attest post_mortem=docs/pm.md \
    --attest describe_pr=done
# Pin the exit too: if this probe ever SUCCEEDS, $OUT carries no failure list,
# the control below passes vacuously, and the probe silently writes a finalize
# stamp + snapshot commit that changes G2's starting state.
assert_status "the finalize probe still refuses for other reasons" 2 "$STATUS"
assert_not_contains "a standing review gate is not a finalize failure" "$OUT" \
    "review gate"

echo ""
echo "--- G2: stamp revocation ---"

head_before_unstamp=$(git -C "$wtV" rev-parse HEAD)
run_ledger "$wtV" unstamp review --reason "tests lane reopened its finding"
assert_status "unstamp review exits 0" 0 "$STATUS"
# L2 (logic R1): the same-named step stays `completed`, so `show` would report
# the step done while `check` says MISSING. Advisory only — exit stays 0.
assert_contains "unstamp warns about the still-completed step" "$OUT" "WARNING"
assert_contains "unstamp warning names the command that unwinds the step" "$OUT" \
    "set review pending"
if [ "$head_before_unstamp" = "$(git -C "$wtV" rev-parse HEAD)" ]; then
    unstamp_committed=no
else
    unstamp_committed=yes
fi
assert_equal "unstamp commits the revocation" "yes" "$unstamp_committed"
# R2 tests lane T5: `diff-tree HEAD` alone passes with a STALE head (pre-fix
# there is no unstamp commit at all and HEAD is the previous stamp commit), so
# anchor to the captured range AND to the commit subject.
assert_equal "unstamp commit subject names the revocation" \
    "chore(ledger): unstamp review" \
    "$(git -C "$wtV" log -1 --pretty=%s)"
unstamp_paths=$(git -C "$wtV" diff-tree --no-commit-id --name-only -r \
    "$head_before_unstamp..HEAD")
assert_equal "unstamp commit touches only its own run file" \
    "docs/executions/runs/2026-08-20-verdict.yaml" "$unstamp_paths"
run_ledger "$wtV" check review
assert_status "check review MISSING after unstamp" 1 "$STATUS"
assert_contains "check names the missing stamp" "$OUT" "MISSING"
run_ledger "$wtV" check-snapshot review
assert_status "check-snapshot review MISSING after unstamp" 1 "$STATUS"
assert_file_contains "unstamp records the reason in overrides[]" "$stateV" \
    "tests lane reopened its finding"
assert_file_contains "unstamp records the action in overrides[]" "$stateV" \
    "action: unstamp"
assert_file_contains "unstamp publishes the revocation to the snapshot" \
    "$snapV" "tests lane reopened its finding"

# The CONSEQUENCE the whole revocation feature exists to produce: a revoked
# review gate must sink the next gate's stamp (checked_finalize opens with
# check_gate review). Nothing proved this before (R2 tests lane).
run_ledger "$wtV" stamp finalize --attest post_mortem=docs/pm.md \
    --attest describe_pr=done
assert_status "a revoked review sinks the finalize stamp" 2 "$STATUS"
assert_contains "the finalize refusal blames the review gate" "$OUT" "review gate"

# R2 tests lane T2: exit 1 is shared by "no stamp to revoke" and EVERY usage
# error, and the usage text itself contains `review-floor`, so a bare `grep -F
# review` matched pre-fix. Anchor on the refusal sentence and rule out usage.
run_ledger "$wtV" unstamp review --reason "nothing left to revoke"
assert_status "unstamp with no stamp to revoke exits 1" 1 "$STATUS"
assert_contains "no-stamp refusal names the gate and the absent stamp" "$OUT" \
    "no 'review' stamp to revoke"
assert_not_contains "no-stamp refusal is not a usage error" "$OUT" "Usage:"
run_ledger "$wtV" unstamp review
assert_status "unstamp without --reason exits 4" 4 "$STATUS"
run_ledger "$wtV" unstamp bogus --reason "x"
assert_status "unstamp of an unknown gate exits 5" 5 "$STATUS"
assert_contains "unknown-gate refusal names the gate" "$OUT" "unknown gate: bogus"

# Revocation is not terminal: the gate can be re-earned.
printf 'model: opus\nverdict: approve   \n' >"$laneV"
run_ledger "$wtV" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$laneV" \
    --attest model_floor=sonnet
assert_status "lowercase approve with trailing spaces re-stamps" 0 "$STATUS"
run_ledger "$wtV" check review
assert_status "check review OK after re-stamp" 0 "$STATUS"

# The step-side coupling: a gate stamp may only stand while its same-named
# step is completed. Unwinding the step revokes the gate.
#
# R2 tests lane T1: `--reason` also lands in the STEP's own evidence field
# (op_set does `step["evidence"] = evidence or reason`) and step evidence is
# published, so grepping the reason string proved only "something published
# the snapshot". Grep the coupling's own `action:` value instead — nothing but
# the overrides[] append can produce it.
run_ledger "$wtV" set review pending --reason "reopening review after new finding"
assert_status "set review pending exits 0" 0 "$STATUS"
run_ledger "$wtV" check review
assert_status "check review MISSING after the step is unwound" 1 "$STATUS"
assert_file_contains "step unwind records its own action in live state" \
    "$stateV" "action: unstamp-via-set"
assert_file_contains "step unwind publishes its own action to the snapshot" \
    "$snapV" "action: unstamp-via-set"
run_ledger "$wtV" check-snapshot review
assert_status "check-snapshot review MISSING after the step is unwound" 1 "$STATUS"

printf 'model: opus\r\nverdict: APPROVE\r\n' >"$laneV"
run_ledger "$wtV" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$laneV" \
    --attest model_floor=sonnet
assert_status "CRLF lane file stamps (verdict normalized)" 0 "$STATUS"
run_ledger "$wtV" set review completed --evidence "review round 2 approved"
assert_status "set review completed exits 0" 0 "$STATUS"
run_ledger "$wtV" check review
assert_status "completing the step leaves its stamp intact" 0 "$STATUS"

echo ""
echo "--- G2b: revocation on non-review gates, and its atomicity ---"

# R2 tests lane: `unstamp` and the `set` coupling are documented for
# diagnose|fix|review|finalize and were tested for `review` only — narrowing
# either allowlist to `review)` left the suite green. This fixture drives a
# non-review gate through both entry points, and is also where H2 (revocation
# must not leave live state and the committed record disagreeing) is
# constructed, because a bug run reaches a real stamp with no forge mocks.
repoR=$(new_repo revoke_gates)
stateR=$(live_state "$repoR")
gitdirR="$(git -C "$repoR" rev-parse --absolute-git-dir)"
run_ledger "$repoR" init 2026-08-20-revoke --workflow workflow-deliver \
    --kind bug --steps "impl"
assert_status "non-review revocation fixture inits" 0 "$STATUS"
snapR="$(run_snap "$repoR" 2026-08-20-revoke)"
headblobR="$TMPDIR_BASE/revoke-head-blob.yaml"
printf '#!/usr/bin/env bash\ntest -f fixed.txt\n' >"$repoR/repro.sh"
commit_all "$repoR" "test: add repro script"
run_ledger "$repoR" stamp diagnose --attest repro_cmd="bash repro.sh" \
    --attest root_cause="fixed.txt marker missing"
assert_status "diagnose stamp for the revocation fixture exits 0" 0 "$STATUS"
run_ledger "$repoR" set diagnose completed --evidence "root cause identified"
assert_status "diagnose step completes alongside its stamp" 0 "$STATUS"

# H2 (logic R1), explicit-unstamp entry point. `py unstamp` deleted the live
# stamp BEFORE publishing, so a failed publish left live state MISSING while
# the committed blob CI reads still carried a fresh stamp — the reviewer got
# FINALIZE_STAMP_CHECK: PASS on that branch. A stale index.lock forces the
# publish failure. Contract: live state and the record still AGREE, and the
# message says the revocation did not apply.
: >"$gitdirR/index.lock"
assert_file_exists "index.lock is in place to force a publish failure" \
    "$gitdirR/index.lock"
head_pre_lock=$(git -C "$repoR" rev-parse HEAD)
run_ledger "$repoR" unstamp diagnose --reason "publish is going to fail here"
assert_status_not "unstamp with an unwritable index does not report success" \
    0 "$STATUS"
assert_status "unstamp with a failed publish exits 10" 10 "$STATUS"
assert_contains "failed-publish message says the revocation did not apply" \
    "$OUT" "revocation"
assert_not_contains "failed-publish message is not a usage error" "$OUT" "Usage:"
rm -f "$gitdirR/index.lock"
assert_equal "a failed revocation makes no commit" "$head_pre_lock" \
    "$(git -C "$repoR" rev-parse HEAD)"
run_ledger "$repoR" check diagnose
assert_status "a failed revocation leaves the live stamp intact" 0 "$STATUS"
run_ledger "$repoR" check-snapshot diagnose
assert_status "a failed revocation leaves the snapshot stamp intact" 0 "$STATUS"
git -C "$repoR" show "HEAD:docs/executions/runs/2026-08-20-revoke.yaml" \
    >"$headblobR" 2>/dev/null || : >"$headblobR"
assert_file_contains "a failed revocation leaves the committed record's stamp intact" \
    "$headblobR" "repro_exit"
assert_file_not_contains "a failed revocation records no override in live state" \
    "$stateR" "publish is going to fail here"

# H2, `set`-coupled entry point (where `py set` has additionally already
# written live state before the coupling runs). Re-establish the stamp
# explicitly: pre-fix the case above has already destroyed it, and a coupling
# that no-ops because there is no stamp left would red for the wrong reason.
run_ledger "$repoR" set diagnose completed --evidence "root cause identified"
assert_status "diagnose step completed before the set-coupled failure" 0 "$STATUS"
run_ledger "$repoR" stamp diagnose --attest repro_cmd="bash repro.sh" \
    --attest root_cause="fixed.txt marker missing"
assert_status "diagnose re-stamped before the set-coupled failure" 0 "$STATUS"
: >"$gitdirR/index.lock"
assert_file_exists "index.lock is in place for the set-coupled failure" \
    "$gitdirR/index.lock"
head_pre_lock2=$(git -C "$repoR" rev-parse HEAD)
run_ledger "$repoR" set diagnose failed --reason "set-side publish fails here"
assert_status "set-coupled revocation with a failed publish exits 10" 10 "$STATUS"
assert_contains "set-coupled failure says the revocation did not apply" "$OUT" \
    "revocation"
rm -f "$gitdirR/index.lock"
assert_equal "a failed set-coupled revocation makes no commit" "$head_pre_lock2" \
    "$(git -C "$repoR" rev-parse HEAD)"
run_ledger "$repoR" check diagnose
assert_status "a failed set-coupled revocation leaves the live stamp intact" \
    0 "$STATUS"
run_ledger "$repoR" check-snapshot diagnose
assert_status "a failed set-coupled revocation leaves the snapshot stamp intact" \
    0 "$STATUS"

run_ledger "$repoR" set diagnose completed --evidence "root cause identified"
assert_status "diagnose step restored to completed" 0 "$STATUS"

# The `set` coupling on a gate other than `review`. Assert the precondition:
# without it, `check diagnose` = 1 afterwards is satisfied by there being no
# stamp to revoke in the first place.
run_ledger "$repoR" check diagnose
assert_status "a diagnose stamp stands before the coupling fires" 0 "$STATUS"
run_ledger "$repoR" set diagnose failed --reason "diagnose reopened by the fix lane"
assert_status "set diagnose failed exits 0" 0 "$STATUS"
run_ledger "$repoR" check diagnose
assert_status "the set coupling revokes a non-review gate" 1 "$STATUS"
assert_contains "the coupled revocation reads MISSING, not STALE" "$OUT" "MISSING"
assert_file_contains "non-review coupling records its own action" "$stateR" \
    "action: unstamp-via-set"
run_ledger "$repoR" check-snapshot diagnose
assert_status "the set coupling revokes a non-review gate in the record too" \
    1 "$STATUS"
assert_contains "the coupled record revocation reads MISSING, not STALE" "$OUT" \
    "MISSING"

# `unstamp` happy path on a gate other than `review`, plus S2 (security R1):
# the revocation entry must record the REVOKED stamp's own identity, not just
# the revocation-time HEAD. A code commit between the stamp and the revocation
# makes the two shas distinguishable.
run_ledger "$repoR" set diagnose completed --evidence "re-diagnosed"
assert_status "diagnose step completed for the re-stamp" 0 "$STATUS"
diag_stamp_head=$(git -C "$repoR" rev-parse HEAD)
run_ledger "$repoR" stamp diagnose --attest repro_cmd="bash repro.sh" \
    --attest root_cause="marker still missing"
assert_status "diagnose re-stamp exits 0" 0 "$STATUS"
echo "unrelated" >>"$repoR/src/app.py"
commit_all "$repoR" "docs: a commit between the stamp and the revocation"
head_before_unstampR=$(git -C "$repoR" rev-parse HEAD)
run_ledger "$repoR" unstamp diagnose --reason "diagnose revoked for a second look"
assert_status "unstamp of a non-review gate exits 0" 0 "$STATUS"
assert_equal "non-review unstamp commit subject names the gate" \
    "chore(ledger): unstamp diagnose" "$(git -C "$repoR" log -1 --pretty=%s)"
run_ledger "$repoR" check diagnose
assert_status "unstamp revokes a non-review gate in live state" 1 "$STATUS"
# A code commit sits between the stamp and the revocation (so the two shas S2
# records are distinguishable), which makes exit 1 reachable as STALE as well
# as MISSING — name the verdict.
assert_contains "the revoked non-review gate reads MISSING, not STALE" "$OUT" \
    "MISSING"
run_ledger "$repoR" check-snapshot diagnose
assert_status "unstamp revokes a non-review gate in the record" 1 "$STATUS"
assert_contains "the record's revoked gate reads MISSING, not STALE" "$OUT" \
    "MISSING"
assert_file_contains "revocation records the revoked stamp's own head_sha" \
    "$stateR" "revoked_head_sha: $diag_stamp_head"
assert_file_contains "revocation still records the revocation-time head_sha" \
    "$stateR" "head_sha: $head_before_unstampR"
assert_file_contains "revocation records the revoked stamp's gate_type" \
    "$stateR" "gate_type: reviewer-validation"
assert_file_contains "revocation preserves the revoked stamp's checked digests" \
    "$stateR" "revoked_checked"
assert_file_contains "the preserved digests still carry the diagnose evidence" \
    "$stateR" "repro_exit"
assert_file_contains "the revocation audit reaches the committed record" \
    "$snapR" "revoked_head_sha: $diag_stamp_head"

echo ""
echo "--- G3: flush publishes non-gate corrections ---"

# R2 tests lane: G3 gets its own fixture. Chained onto G1/G2's fixture, a
# verdict-allowlist regression reported as ~30 unrelated flush failures.
wtF=$(new_wt_fixture flush_gate)
lanesF="$TMPDIR_BASE/flush_gate/lanes"
mkdir -p "$lanesF"
laneF="$lanesF/integrated-review.md"
run_ledger "$wtF" init 2026-08-20-flush --workflow workflow-deliver \
    --kind bug --steps "diagnose,fix,review,finalize"
assert_status "flush fixture inits" 0 "$STATUS"
printf -- '- "true"\n' >"$wtF/docs/executions/ci-commands.yaml"
echo "tweak" >>"$wtF/src/app.py"
commit_all "$wtF" "fix: small change under review"
stateF=$(live_state "$wtF")
snapF="$(run_snap "$wtF" 2026-08-20-flush)"
printf 'model: opus\nverdict: APPROVE\n' >"$laneF"
run_ledger "$wtF" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$laneF" \
    --attest model_floor=sonnet
assert_status "flush fixture stamps review" 0 "$STATUS"

run_ledger "$wtF" set fix completed --evidence "regression test at tests/wrong-path.sh"
assert_status "set records the first (wrong) evidence" 0 "$STATUS"
# Publishing it needs a gate — that is the whole gap. Re-stamp to commit it.
run_ledger "$wtF" stamp review --attest verdict=approve \
    --attest review_profile=fast --attest "lanes=integrated=$laneF" \
    --attest model_floor=sonnet
assert_status "re-stamp publishes the wrong evidence" 0 "$STATUS"
assert_file_contains "snapshot carries the wrong evidence" "$snapF" \
    "tests/wrong-path.sh"

run_ledger "$wtF" set fix completed --evidence "regression test at test/test-ledger.sh"
assert_status "set records the corrected evidence" 0 "$STATUS"
assert_file_contains "live state carries the correction" "$stateF" \
    "test/test-ledger.sh"
assert_file_contains "snapshot still carries the stale evidence before flush" \
    "$snapF" "tests/wrong-path.sh"

head_before_flush=$(git -C "$wtF" rev-parse HEAD)
run_ledger "$wtF" flush
assert_status "flush exits 0" 0 "$STATUS"
assert_file_contains "flush publishes the correction" "$snapF" \
    "test/test-ledger.sh"
assert_file_not_contains "flush removes the stale evidence" "$snapF" \
    "tests/wrong-path.sh"
# R2 tests lane T5: anchor to the captured range and the commit subject, not
# to whatever commit happens to be at HEAD.
assert_equal "flush commit subject names the run" \
    "chore(ledger): flush 2026-08-20-flush" "$(git -C "$wtF" log -1 --pretty=%s)"
flush_paths=$(git -C "$wtF" diff-tree --no-commit-id --name-only -r \
    "$head_before_flush..HEAD")
assert_equal "flush commit touches only its own run file" \
    "docs/executions/runs/2026-08-20-flush.yaml" "$flush_paths"
if [ "$head_before_flush" = "$(git -C "$wtF" rev-parse HEAD)" ]; then
    flush_committed=no
else
    flush_committed=yes
fi
assert_equal "flush created a commit" "yes" "$flush_committed"

# flush carries no gate semantics: it must neither create nor stale a stamp.
run_ledger "$wtF" check review
assert_status "flush does not stale the review stamp" 0 "$STATUS"
run_ledger "$wtF" check finalize
assert_status "flush does not conjure an unstamped gate" 1 "$STATUS"
# flush's whole purpose is the record CI reads, and only NEGATIVE
# check-snapshot assertions existed (R2 tests lane).
run_ledger "$wtF" check-snapshot review
assert_status "flush leaves the snapshot CI-readable" 0 "$STATUS"

head_before_noop=$(git -C "$wtF" rev-parse HEAD)
run_ledger "$wtF" flush
assert_status "flush with nothing to publish exits 0" 0 "$STATUS"
assert_equal "no-op flush makes no commit" "$head_before_noop" \
    "$(git -C "$wtF" rev-parse HEAD)"

# flush must not launder drift: last_seen_sha drives reconcile's
# "commits outside the ledger" detection, so advancing it on a
# no-gate publish would erase evidence of real code commits. The
# snapshot commit is already content-exempt in that loop.
echo "unledgered code change" >>"$wtF/src/app.py"
commit_all "$wtF" "feat: a commit the ledger has not seen"
run_ledger "$wtF" reconcile
assert_status "reconcile reports the unledgered commit" 1 "$STATUS"
run_ledger "$wtF" set fix completed --evidence "note after the code commit"
run_ledger "$wtF" flush
assert_status "flush after a code commit exits 0" 0 "$STATUS"
run_ledger "$wtF" reconcile
assert_status "flush does not launder drift" 1 "$STATUS"
assert_contains "drift still names the unledgered commit" "$OUT" \
    "the ledger has not seen"

# H1 (security R1): snapshot_match's durable tuple INCLUDES stamps and
# overrides, and cmd_flush wrote all of live state — so injecting a fabricated
# stamp into live state and running flush made it canonical, flipped
# check-snapshot from MISSING to OK, and silenced the snapshot_current control
# in stamp finalize entirely. flush's job is steps/meta: a divergent durable
# tuple must REFUSE (exit 6), never be repaired or published.
repoH=$(new_repo flush_tamper)
stateH1=$(live_state "$repoH")
run_ledger "$repoH" init 2026-08-20-tamper --workflow workflow-deliver \
    --kind feature --steps "impl"
assert_status "tamper fixture inits" 0 "$STATUS"
snapH1="$(run_snap "$repoH" 2026-08-20-tamper)"
run_ledger "$repoH" check-snapshot review
assert_status "no review stamp in the record before tampering" 1 "$STATUS"
inject_forged_stamp "$stateH1" review "$(git -C "$repoH" rev-parse HEAD)"
assert_file_contains "the forged stamp reached live state" "$stateH1" \
    "forged-by-hand"
head_before_tamper=$(git -C "$repoH" rev-parse HEAD)
run_ledger "$repoH" flush
assert_status "flush refuses a hand-tampered durable tuple" 6 "$STATUS"
assert_contains "tamper refusal names the divergent key" "$OUT" "stamps"
assert_contains "tamper refusal points at the legitimate path" "$OUT" "unstamp"
assert_not_contains "tamper refusal is not a usage error" "$OUT" "Usage:"
assert_equal "a refused flush makes no commit" "$head_before_tamper" \
    "$(git -C "$repoH" rev-parse HEAD)"
assert_file_not_contains "the forged stamp never reaches the snapshot file" \
    "$snapH1" "forged-by-hand"
run_ledger "$repoH" check-snapshot review
assert_status "the forged stamp never becomes CI-readable" 1 "$STATUS"

# T10: flush on a closed run re-committed the snapshot of a finished audit
# record. Decided deliberately: refuse (exit 1).
repoC=$(new_repo flush_closed)
run_ledger "$repoC" init 2026-08-20-shut --workflow workflow-deliver \
    --kind feature --steps "impl"
assert_status "closed-run fixture inits" 0 "$STATUS"
run_ledger "$repoC" set impl completed --evidence "implemented"
assert_status "closed-run fixture completes its step" 0 "$STATUS"
run_ledger "$repoC" close
assert_status "closed-run fixture closes" 0 "$STATUS"
head_before_closed_flush=$(git -C "$repoC" rev-parse HEAD)
run_ledger "$repoC" flush
assert_status "flush on a closed run exits 1" 1 "$STATUS"
assert_contains "closed-run refusal says the run is closed" "$OUT" "closed"
assert_not_contains "closed-run refusal is not a usage error" "$OUT" "Usage:"
assert_equal "flush on a closed run makes no commit" \
    "$head_before_closed_flush" "$(git -C "$repoC" rev-parse HEAD)"

repoF=$(new_repo flush_no_run)
run_ledger "$repoF" flush
assert_status "flush without a live run exits 1" 1 "$STATUS"
assert_contains "no-run flush names the missing state" "$OUT" "no live ledger state"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
