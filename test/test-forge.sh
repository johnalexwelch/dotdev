#!/usr/bin/env bash
set -uo pipefail

# Red-first suite for the origin-detecting forge shim.
# Contract: docs/executions/plans/2026-08-19-workflow-ledger-spec.md
# Mock-mode file contract defined by this suite (implementer must honor):
#   FORGE_MOCK_DIR=<dir> => forge.sh reads the canned normalized answer from
#   "$FORGE_MOCK_DIR/<forge>-<op>-<pr>" (e.g. github-ci-status-42) instead of
#   touching gh or the Forgejo API. Zero network in mock mode — FORGE_URL is
#   pointed at an .invalid host so any real call fails loudly.
# Detect interpretation: `git config forge.type` (github|forgejo) wins when
# set; origin URLs containing github.com => github; ssh-style origins (scp-like
# or ssh://) resolve their host through `ssh -G` HostName so ~/.ssh/config
# aliases (git@github-personal:...) classify by destination; any other origin
# URL => forgejo; no origin remote => none. FORGE_SSH_CONFIG substitutes the
# ssh config consulted, keeping these tests hermetic to the runner's ~/.ssh.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORGE="$ROOT/dotfiles/.config/agents/skills/workflow-ledger/scripts/forge.sh"
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

# Run forge.sh from inside a repo; captures OUT and STATUS. Mock mode is
# always on and FORGE_URL points at an .invalid host so any accidental
# network path fails instead of leaving the sandbox.
run_forge() {
    local dir="$1"
    shift
    OUT="$(cd "$dir" && FORGE_MOCK_DIR="$MOCK_DIR" \
        FORGE_URL="https://forge.invalid" FORGE_TOKEN="dummy-token" \
        FORGE_SSH_CONFIG="$SSH_CFG" \
        bash "$FORGE" "$@" 2>&1)"
    STATUS=$?
}

new_repo() {
    local name="$1" remote="${2:-}"
    local repo="$TMPDIR_BASE/$name"
    mkdir -p "$repo"
    git init -q -b main "$repo"
    git -C "$repo" config user.email "t@example.com"
    git -C "$repo" config user.name "Test"
    echo "seed" >"$repo/README.md"
    git -C "$repo" add README.md
    git -C "$repo" commit -q -m init
    if [ -n "$remote" ]; then
        git -C "$repo" remote add origin "$remote"
    fi
    printf '%s' "$repo"
}

MOCK_DIR="$TMPDIR_BASE/mock"
mkdir -p "$MOCK_DIR"

# Hermetic ssh config: alias resolution must come from here, never the
# runner's real ~/.ssh/config.
SSH_CFG="$TMPDIR_BASE/ssh_config"
cat >"$SSH_CFG" <<'EOF'
Host github-personal
    HostName github.com
Host forge-personal
    HostName code.example.org
EOF

echo "=== forge.sh tests ==="
echo ""

assert_file_exists "forge.sh exists at spec'd path" "$FORGE"

# --- detect: three remote shapes ---
repo_gh=$(new_repo gh_repo "git@github.com:acme/widgets.git")
repo_fj=$(new_repo fj_repo "https://code.example.org/acme/widgets.git")
repo_none=$(new_repo none_repo)

run_forge "$repo_gh" detect
assert_status "detect exits 0 on github remote" 0 "$STATUS"
assert_equal "detect prints github for github.com ssh remote" "github" "$OUT"

run_forge "$repo_fj" detect
assert_status "detect exits 0 on forgejo remote" 0 "$STATUS"
assert_equal "detect prints forgejo for non-github https remote" "forgejo" "$OUT"

run_forge "$repo_none" detect
assert_status "detect exits 0 with no origin remote" 0 "$STATUS"
assert_equal "detect prints none without origin remote" "none" "$OUT"

# --- detect: ssh host aliases resolve to their real HostName ---
repo_gh_alias=$(new_repo gh_alias_repo "git@github-personal:johnalexwelch/dotdev.git")
repo_fj_alias=$(new_repo fj_alias_repo "git@forge-personal:acme/widgets.git")
repo_gh_alias_scheme=$(new_repo gh_alias_scheme_repo "ssh://git@github-personal/johnalexwelch/dotdev.git")
repo_unknown_alias=$(new_repo unknown_alias_repo "git@no-such-alias:acme/widgets.git")

run_forge "$repo_gh_alias" detect
assert_status "detect exits 0 on github ssh-alias remote" 0 "$STATUS"
assert_equal "detect resolves scp-like alias to github" "github" "$OUT"

run_forge "$repo_fj_alias" detect
assert_status "detect exits 0 on forgejo ssh-alias remote" 0 "$STATUS"
assert_equal "detect resolves scp-like alias to forgejo" "forgejo" "$OUT"

run_forge "$repo_gh_alias_scheme" detect
assert_status "detect exits 0 on ssh:// alias remote" 0 "$STATUS"
assert_equal "detect resolves ssh:// alias to github" "github" "$OUT"

run_forge "$repo_unknown_alias" detect
assert_status "detect exits 0 on unresolvable ssh alias" 0 "$STATUS"
assert_equal "detect falls back to forgejo for unresolvable alias" "forgejo" "$OUT"

# --- detect: git config forge.type override wins in both directions ---
repo_forced_gh=$(new_repo forced_gh_repo "https://code.example.org/acme/widgets.git")
git -C "$repo_forced_gh" config forge.type github
repo_forced_fj=$(new_repo forced_fj_repo "git@github.com:acme/widgets.git")
git -C "$repo_forced_fj" config forge.type forgejo
repo_bad_override=$(new_repo bad_override_repo "git@github.com:acme/widgets.git")
git -C "$repo_bad_override" config forge.type gitlab

run_forge "$repo_forced_gh" detect
assert_status "detect exits 0 with forge.type=github override" 0 "$STATUS"
assert_equal "forge.type=github overrides non-github remote" "github" "$OUT"

run_forge "$repo_forced_fj" detect
assert_status "detect exits 0 with forge.type=forgejo override" 0 "$STATUS"
assert_equal "forge.type=forgejo overrides github remote" "forgejo" "$OUT"

run_forge "$repo_bad_override" detect
assert_status "detect fails loudly on invalid forge.type" 1 "$STATUS"

run_forge "$repo_bad_override" ci-status 42
assert_status "ops fail on invalid forge.type" 1 "$STATUS"
assert_equal "invalid forge.type does not cascade to a mock-missing error" \
    "0" "$(printf '%s\n' "$OUT" | grep -c 'mock answer missing')"

# --- github ops via mock mode ---
printf 'green\n' >"$MOCK_DIR/github-ci-status-42"
printf 'open\n' >"$MOCK_DIR/github-pr-state-42"
printf 'yes\n' >"$MOCK_DIR/github-threads-resolved-42"
printf 'pending\n' >"$MOCK_DIR/github-ci-status-43"

run_forge "$repo_gh" ci-status 42
assert_status "github ci-status exits 0" 0 "$STATUS"
assert_equal "github ci-status prints green" "green" "$OUT"

run_forge "$repo_gh" pr-state 42
assert_status "github pr-state exits 0" 0 "$STATUS"
assert_equal "github pr-state prints open" "open" "$OUT"

run_forge "$repo_gh" threads-resolved 42
assert_status "github threads-resolved exits 0" 0 "$STATUS"
assert_equal "github threads-resolved prints yes" "yes" "$OUT"

run_forge "$repo_gh" ci-status 43
assert_equal "github ci-status prints pending" "pending" "$OUT"

# --- forgejo ops via mock mode ---
printf 'red\n' >"$MOCK_DIR/forgejo-ci-status-7"
printf 'merged\n' >"$MOCK_DIR/forgejo-pr-state-7"
printf 'no\n' >"$MOCK_DIR/forgejo-threads-resolved-7"

run_forge "$repo_fj" ci-status 7
assert_status "forgejo ci-status exits 0" 0 "$STATUS"
assert_equal "forgejo ci-status prints red" "red" "$OUT"

run_forge "$repo_fj" pr-state 7
assert_status "forgejo pr-state exits 0" 0 "$STATUS"
assert_equal "forgejo pr-state prints merged" "merged" "$OUT"

run_forge "$repo_fj" threads-resolved 7
assert_status "forgejo threads-resolved exits 0" 0 "$STATUS"
assert_equal "forgejo threads-resolved prints no" "no" "$OUT"

# --- pr-for-branch: direct coverage (batch #8) ---
printf '31\n' >"$MOCK_DIR/github-pr-for-branch-mybranch"
printf 'none\n' >"$MOCK_DIR/forgejo-pr-for-branch-mybranch"

run_forge "$repo_gh" pr-for-branch mybranch
assert_status "github pr-for-branch exits 0" 0 "$STATUS"
assert_equal "github pr-for-branch prints the PR number" "31" "$OUT"

run_forge "$repo_fj" pr-for-branch mybranch
assert_status "forgejo pr-for-branch exits 0" 0 "$STATUS"
assert_equal "forgejo pr-for-branch prints none when no open PR" "none" "$OUT"

# Slashed branch names must sanitize to flat mock filenames, not nested
# directories (batch #8: feature/x previously required a feature/ subdir).
printf '77\n' >"$MOCK_DIR/github-pr-for-branch-feature_login-flow"
run_forge "$repo_gh" pr-for-branch feature/login-flow
assert_status "slashed-branch pr-for-branch exits 0" 0 "$STATUS"
assert_equal "slashed branch reads a sanitized flat mock filename" "77" "$OUT"

# --- FORGE_TOKEN hygiene (batch #5) ---
# Stub curl (PATH-prepended) records argv and stdin; every real-mode probe in
# this section runs through it so no probe can leave the sandbox.
STUB_BIN="$TMPDIR_BASE/stub-bin"
mkdir -p "$STUB_BIN"
cat >"$STUB_BIN/curl" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$TMPDIR_BASE/curl-argv"
[ -t 0 ] || cat >"$TMPDIR_BASE/curl-stdin"
printf '{"merged":false,"draft":false,"state":"open"}'
STUB
chmod +x "$STUB_BIN/curl"

# Runs forge.sh in real (non-mock) Forgejo mode behind the stub curl.
run_forge_stubbed() {
    local dir="$1" token="$2"
    shift 2
    OUT="$(cd "$dir" && PATH="$STUB_BIN:$PATH" FORGE_URL="https://forge.invalid" \
        FORGE_TOKEN="$token" FORGE_SSH_CONFIG="$SSH_CFG" bash "$FORGE" "$@" 2>&1)"
    STATUS=$?
}

# Empty FORGE_TOKEN must fail loudly BEFORE any request: the stub proves
# curl is never invoked (tests-lane fix: the exit code alone was vacuous).
rm -f "$TMPDIR_BASE/curl-argv"
run_forge_stubbed "$repo_fj" "" ci-status 7
assert_status "empty FORGE_TOKEN fails loudly (no unauthenticated call)" 1 "$STATUS"
assert_contains "empty-token failure names FORGE_TOKEN" "$OUT" "FORGE_TOKEN"
assert_equal "curl is never invoked on an empty token" "missing" \
    "$([ -f "$TMPDIR_BASE/curl-argv" ] && echo present || echo missing)"

# The token must never travel on curl argv (visible in process listings);
# it goes via a curl config read from stdin.
run_forge_stubbed "$repo_fj" "hunter2-token-value" pr-state 9
assert_status "forgejo pr-state via stub curl exits 0" 0 "$STATUS"
assert_equal "stub-backed pr-state prints open" "open" "$OUT"
assert_equal "token never appears on curl argv" "0" \
    "$(grep -c 'hunter2-token-value' "$TMPDIR_BASE/curl-argv")"
assert_equal "token reaches curl via non-argv channel" "1" \
    "$(grep -c 'hunter2-token-value' "$TMPDIR_BASE/curl-stdin" 2>/dev/null || echo 0)"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
