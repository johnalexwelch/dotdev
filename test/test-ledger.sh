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
assert_file_exists "init writes committed snapshot" "$repoA/docs/executions/state.yaml"
last_msg=$(git -C "$repoA" log -1 --pretty=%s)
assert_contains "init commits snapshot as chore(ledger)" "$last_msg" "chore(ledger): init"

run_ledger "$repoA" init 2026-08-19-demo2 --workflow workflow-build-one \
    --kind feature --steps "plan,impl,review"
assert_status "re-init over active run refused with exit 7" 7 "$STATUS"

run_ledger "$repoA" init 2026-08-19-demo3 --workflow workflow-build-one \
    --kind feature --steps "plan,impl,review" --force
assert_status "re-init --force exits 0" 0 "$STATUS"
assert_file_contains "forced re-init leaves overrides[] audit entry" "$stateA" "force"

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

# --- repro_tail redaction + snapshot cap (batch #4) ---
repoRT=$(new_repo redact_tail)
stateRT=$(live_state "$repoRT")
run_ledger "$repoRT" init 2026-08-18-redact --workflow workflow-deliver \
    --kind bug --steps "impl"
cat >"$repoRT/leaky.sh" <<'LEAK'
#!/usr/bin/env bash
echo "token=supersecretvalue1234 ghp_ABCDEFGHIJKLMNOPQRSTuvwx"
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
    "ghp_ABCDEFGHIJKLMNOPQRSTuvwx"
assert_file_not_contains "live tail redacts the token= value" "$stateRT" \
    "supersecretvalue1234"
assert_file_contains "live tail carries a REDACTED marker" "$stateRT" "REDACTED"
assert_file_not_contains "committed snapshot never carries the secret" \
    "$repoRT/docs/executions/state.yaml" "supersecretvalue1234"
long_run="$(printf 'x%.0s' $(seq 1 100))"
assert_file_contains "live state keeps the full tail" "$stateRT" "$long_run"
assert_file_not_contains "snapshot repro_tail is capped" \
    "$repoRT/docs/executions/state.yaml" "$long_run"
assert_file_contains "snapshot marks the truncation" \
    "$repoRT/docs/executions/state.yaml" "truncated"

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
    "$wt1/docs/executions/state.yaml" "forge_mock"

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
    "$wt2/docs/executions/state.yaml" "standard+security"

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
lanes3="$TMPDIR_BASE/snapshot_drift/lanes"
mkdir -p "$lanes3"
lane3="$lanes3/integrated-review.md"
printf 'none\n' >"$FORGE_MOCK_DIR/forgejo-pr-for-branch-feature_snapshot_drift"

run_ledger "$wt3" init 2026-08-18-snap --workflow workflow-deliver \
    --kind feature --steps "impl,review,finalize"
# Give the run a long repro tail so the legacy-shape (uncapped byte-copy)
# snapshot below exercises the cap-normalized comparison (logic R1).
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

sed -i.bak 's/^run_id: .*/run_id: forged-run/' "$wt3/docs/executions/state.yaml"
rm -f "$wt3/docs/executions/state.yaml.bak"
git -C "$wt3" add -- docs/executions/state.yaml
git -C "$wt3" commit -q -m "chore(ledger): stamp review" -- docs/executions/state.yaml

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
cp "$(live_state "$wt3")" "$wt3/docs/executions/state.yaml"
git -C "$wt3" add -- docs/executions/state.yaml
git -C "$wt3" commit -q -m "chore(ledger): restore snapshot" -- docs/executions/state.yaml
run_ledger "$wt3" stamp finalize --attest post_mortem=docs/pm.md \
    --attest describe_pr=done
assert_status "finalize passes on a legacy byte-copy snapshot of live" 0 "$STATUS"
assert_file_contains "finalize records the snapshot_current checked field" \
    "$wt3/docs/executions/state.yaml" "snapshot_current"

# A tamper AFTER the finalize stamp is freshness-exempt (snapshot-only
# commit), so `check finalize` itself must compare the snapshot (security
# lane): stamps and overrides are the durable keys worth forging.
run_ledger "$wt3" check finalize
assert_status "check finalize OK after the finalize stamp" 0 "$STATUS"

sed -i.bak 's/verdict: approve/verdict: forged/g' "$wt3/docs/executions/state.yaml"
rm -f "$wt3/docs/executions/state.yaml.bak"
git -C "$wt3" add -- docs/executions/state.yaml
git -C "$wt3" commit -q -m "chore(ledger): stamp finalize" -- docs/executions/state.yaml
run_ledger "$wt3" check finalize
assert_status "post-stamp verdict tamper fails check finalize" 1 "$STATUS"
assert_contains "post-stamp tamper reads SNAPSHOT_DRIFT" "$OUT" "SNAPSHOT_DRIFT"

cp "$(live_state "$wt3")" "$wt3/docs/executions/state.yaml"
git -C "$wt3" add -- docs/executions/state.yaml
git -C "$wt3" commit -q -m "chore(ledger): restore snapshot" -- docs/executions/state.yaml
run_ledger "$wt3" check finalize
assert_status "check finalize recovers after restore" 0 "$STATUS"

sed -i.bak 's/^overrides: \[\]/overrides: [{gate: finalize, reason: forged-bypass}]/' \
    "$wt3/docs/executions/state.yaml"
rm -f "$wt3/docs/executions/state.yaml.bak"
git -C "$wt3" add -- docs/executions/state.yaml
git -C "$wt3" commit -q -m "chore(ledger): stamp finalize" -- docs/executions/state.yaml
run_ledger "$wt3" check finalize
assert_status "post-stamp overrides tamper fails check finalize" 1 "$STATUS"
assert_contains "overrides tamper reads SNAPSHOT_DRIFT" "$OUT" "SNAPSHOT_DRIFT"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
