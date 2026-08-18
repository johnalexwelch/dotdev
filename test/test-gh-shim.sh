#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHIM="$ROOT/dotfiles/.local/bin/gh"
TMPDIR_BASE=$(mktemp -d)
PASS=0
FAIL=0

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
    if grep -Fq "$needle" <<<"$haystack"; then
        echo "  FAIL: $name"
        echo "    expected output NOT to contain: $needle"
        echo "    output was:"
        echo "$haystack"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    fi
}

# --- Fixtures ----------------------------------------------------------------
# Stub gh on a private PATH. Records every invocation (argv + GH_TOKEN value)
# to $GH_STUB_LOG. `auth token --user X` prints a fake token, or fails when
# GH_STUB_FAIL_TOKEN=1. Fake tokens only — nothing here is a live credential.
STUB_DIR="$TMPDIR_BASE/stubbin"
mkdir -p "$STUB_DIR"
cat >"$STUB_DIR/gh" <<'EOF'
#!/usr/bin/env bash
{
    printf 'argv:'
    printf ' %s' "$@"
    printf '\n'
    printf 'GH_TOKEN:%s\n' "${GH_TOKEN:-<unset>}"
} >>"$GH_STUB_LOG"
if [ "${1:-}" = "auth" ] && [ "${2:-}" = "token" ]; then
    if [ "${GH_STUB_FAIL_TOKEN:-0}" = "1" ]; then
        echo "stub: token fetch refused" >&2
        exit 1
    fi
    echo "fake-token-for-${4:-nobody}"
fi
exit 0
EOF
chmod +x "$STUB_DIR/gh"

# Fake HOME with the account map at its canonical location.
HOME_WITH_MAP="$TMPDIR_BASE/home-with-map"
mkdir -p "$HOME_WITH_MAP/.config"
cat >"$HOME_WITH_MAP/.config/gh-accounts.map" <<'EOF'
# test map
johnalexwelch johnalexwelch
github-personal johnalexwelch
EOF

HOME_NO_MAP="$TMPDIR_BASE/home-no-map"
mkdir -p "$HOME_NO_MAP/.config"

# Local git repos whose origin URLs drive cwd-based routing (never contacted).
WORK_REPO="$TMPDIR_BASE/work-repo"
git init -q "$WORK_REPO"
git -C "$WORK_REPO" remote add origin "git@github.com:classdojo/some-repo.git"

PERSONAL_REPO="$TMPDIR_BASE/personal-repo"
git init -q "$PERSONAL_REPO"
git -C "$PERSONAL_REPO" remote add origin "git@github-personal:someorg/side-project.git"

NOT_A_REPO="$TMPDIR_BASE/not-a-repo"
mkdir -p "$NOT_A_REPO"

# Run the shim with a controlled environment. Usage:
#   run_shim <cwd> <home> <extra-env...> -- <shim-args...>
# Captures stdout+stderr into $out, exit status into $status, and resets the
# stub log for each run.
LOG="$TMPDIR_BASE/stub.log"
run_shim() {
    local cwd="$1" home="$2"
    shift 2
    local -a extra_env=()
    while [ "$1" != "--" ]; do
        extra_env+=("$1")
        shift
    done
    shift
    : >"$LOG"
    set +e
    out=$(cd "$cwd" && env -u GH_TOKEN -u GITHUB_TOKEN \
        HOME="$home" PATH="$STUB_DIR:$PATH" GH_STUB_LOG="$LOG" \
        ${extra_env[@]+"${extra_env[@]}"} \
        "$SHIM" "$@" 2>&1)
    status=$?
    set -e
    log=$(cat "$LOG" 2>/dev/null || true)
}

echo "=== gh shim tests ==="
echo ""

# --- Passthrough on work-owner repo ------------------------------------------
run_shim "$WORK_REPO" "$HOME_WITH_MAP" -- pr view 7
assert_status "work-owner repo exits 0" 0 "$status"
assert_contains "work-owner repo passes argv through" "$log" "argv: pr view 7"
assert_contains "work-owner repo does not inject GH_TOKEN" "$log" "GH_TOKEN:<unset>"
assert_not_contains "work-owner repo fetches no token" "$log" "argv: auth token"

# --- Injection on -R personal owner, regardless of cwd ------------------------
run_shim "$NOT_A_REPO" "$HOME_WITH_MAP" -- -R johnalexwelch/x pr view 1
assert_status "-R personal exits 0" 0 "$status"
assert_contains "-R personal fetches a token for the mapped account" "$log" \
    "argv: auth token --user johnalexwelch"
assert_contains "-R personal execs original argv" "$log" "argv: -R johnalexwelch/x pr view 1"
assert_contains "-R personal injects the fetched token" "$log" \
    "GH_TOKEN:fake-token-for-johnalexwelch"
assert_not_contains "shim never prints the token" "$out" "fake-token-for-johnalexwelch"

# --repo= form routes the same way.
run_shim "$NOT_A_REPO" "$HOME_WITH_MAP" -- pr list --repo=johnalexwelch/x
assert_contains "--repo= personal injects the fetched token" "$log" \
    "GH_TOKEN:fake-token-for-johnalexwelch"

# Attached short-flag form -ROWNER/REPO routes the same way.
run_shim "$NOT_A_REPO" "$HOME_WITH_MAP" -- pr list -Rjohnalexwelch/x
assert_contains "-Rvalue attached form injects the fetched token" "$log" \
    "GH_TOKEN:fake-token-for-johnalexwelch"

# Cobra's -R=OWNER/REPO form routes the same way (leading = stripped).
run_shim "$NOT_A_REPO" "$HOME_WITH_MAP" -- pr list -R=johnalexwelch/x
assert_contains "-R=value form injects the fetched token" "$log" \
    "GH_TOKEN:fake-token-for-johnalexwelch"

# -R work owner from inside a personal-origin repo: explicit -R wins over cwd.
run_shim "$PERSONAL_REPO" "$HOME_WITH_MAP" -- -R classdojo/x pr view 1
assert_contains "-R work owner overrides personal cwd (no injection)" "$log" "GH_TOKEN:<unset>"
assert_not_contains "-R work owner fetches no token" "$log" "argv: auth token"

# --- Injection on cwd repo with github-personal origin ------------------------
run_shim "$PERSONAL_REPO" "$HOME_WITH_MAP" -- pr status
assert_status "github-personal origin exits 0" 0 "$status"
assert_contains "github-personal origin fetches a token" "$log" \
    "argv: auth token --user johnalexwelch"
assert_contains "github-personal origin injects the token" "$log" \
    "GH_TOKEN:fake-token-for-johnalexwelch"

# --- No injection when GH_TOKEN pre-set ---------------------------------------
run_shim "$NOT_A_REPO" "$HOME_WITH_MAP" GH_TOKEN=caller-pinned -- -R johnalexwelch/x pr view 1
assert_status "pre-set GH_TOKEN exits 0" 0 "$status"
assert_not_contains "pre-set GH_TOKEN fetches no token" "$log" "argv: auth token"
assert_contains "pre-set GH_TOKEN reaches gh unchanged" "$log" "GH_TOKEN:caller-pinned"

run_shim "$NOT_A_REPO" "$HOME_WITH_MAP" GITHUB_TOKEN=caller-pinned -- -R johnalexwelch/x pr view 1
assert_not_contains "pre-set GITHUB_TOKEN fetches no token" "$log" "argv: auth token"

# --- gh auth subcommands always pass through -----------------------------------
run_shim "$PERSONAL_REPO" "$HOME_WITH_MAP" -- auth status
assert_status "gh auth exits 0" 0 "$status"
assert_contains "gh auth passes argv through" "$log" "argv: auth status"
assert_contains "gh auth does not inject GH_TOKEN" "$log" "GH_TOKEN:<unset>"
assert_not_contains "gh auth triggers no token fetch" "$log" "argv: auth token"

# --- Fail-open on token-fetch failure ------------------------------------------
run_shim "$PERSONAL_REPO" "$HOME_WITH_MAP" GH_STUB_FAIL_TOKEN=1 -- pr view 3
assert_status "token-fetch failure still exits 0 (fail open)" 0 "$status"
assert_contains "token-fetch failure warns on stderr" "$out" \
    "token fetch for account 'johnalexwelch' failed"
assert_contains "token-fetch failure still execs the command" "$log" "argv: pr view 3"
assert_contains "token-fetch failure runs without injection" "$log" "GH_TOKEN:<unset>"

# --- Missing map = passthrough, never an error ----------------------------------
run_shim "$NOT_A_REPO" "$HOME_NO_MAP" -- -R johnalexwelch/x pr view 1
assert_status "missing map exits 0" 0 "$status"
assert_contains "missing map passes argv through" "$log" "argv: -R johnalexwelch/x pr view 1"
assert_not_contains "missing map fetches no token" "$log" "argv: auth token"
assert_contains "missing map does not inject GH_TOKEN" "$log" "GH_TOKEN:<unset>"

# --- Self-skip resolution ---------------------------------------------------------
# A symlink to the shim named `gh` sits FIRST on PATH; the shim must skip
# every PATH entry that resolves to itself and land on the stub.
LINK_DIR="$TMPDIR_BASE/linkbin"
mkdir -p "$LINK_DIR"
ln -s "$SHIM" "$LINK_DIR/gh"
: >"$LOG"
set +e
out=$(cd "$NOT_A_REPO" && env -u GH_TOKEN -u GITHUB_TOKEN \
    HOME="$HOME_WITH_MAP" PATH="$LINK_DIR:$STUB_DIR:$PATH" GH_STUB_LOG="$LOG" \
    "$LINK_DIR/gh" -R johnalexwelch/x pr view 1 2>&1)
status=$?
set -e
log=$(cat "$LOG")
assert_status "self-skip: symlinked shim exits 0" 0 "$status"
assert_contains "self-skip: resolves past itself to the stub" "$log" \
    "argv: -R johnalexwelch/x pr view 1"
assert_contains "self-skip: still injects the token" "$log" \
    "GH_TOKEN:fake-token-for-johnalexwelch"

# No real gh anywhere on PATH: clear error, exit 127.
EMPTY_PATH_DIR="$TMPDIR_BASE/onlyshim"
mkdir -p "$EMPTY_PATH_DIR"
ln -s "$SHIM" "$EMPTY_PATH_DIR/gh"
set +e
out=$(cd "$NOT_A_REPO" && env -u GH_TOKEN -u GITHUB_TOKEN \
    HOME="$HOME_WITH_MAP" PATH="$EMPTY_PATH_DIR:/usr/bin:/bin" \
    "$EMPTY_PATH_DIR/gh" pr view 1 2>&1)
status=$?
set -e
assert_status "no real gh on PATH exits 127" 127 "$status"
assert_contains "no real gh message names the problem" "$out" "no real gh binary found on PATH"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
