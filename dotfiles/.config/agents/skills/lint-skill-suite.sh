#!/usr/bin/env bash
# Validate the local skill corpus for workflow-hardening invariants.

set -euo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
runtime_root="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
runtime_allowlist="${CODEX_RUNTIME_ALLOWLIST:-$root/codex-runtime-allowlist.txt}"
check_runtime="${CHECK_CODEX_RUNTIME:-0}"
failures=0
warnings=0

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    failures=$((failures + 1))
}

warn() {
    printf 'WARN: %s\n' "$*" >&2
    warnings=$((warnings + 1))
}

has_frontmatter_key() {
    local file="$1" key="$2"
    awk -v key="$key" '
        BEGIN { fm = 0; found = 0 }
        /^---$/ { fm++; next }
        fm == 1 && $0 ~ "^" key ":" { found = 1 }
        END { exit found ? 0 : 1 }
    ' "$file"
}

frontmatter_value() {
    local file="$1" key="$2"
    awk -v key="$key" '
        /^---$/ { fm++; next }
        fm == 1 && $0 ~ "^" key ":" {
            sub("^" key ":[[:space:]]*", "")
            print
            exit
        }
    ' "$file"
}

is_runtime_allowlisted() {
    local skill="$1"

    [ -f "$runtime_allowlist" ] || return 1
    awk -v skill="$skill" '
        /^[[:space:]]*($|#)/ { next }
        {
            name = $1
            if (name == skill) {
                found = 1
            }
        }
        END { exit found ? 0 : 1 }
    ' "$runtime_allowlist"
}

is_top_level_skill() {
    local dir="$1"
    [ -f "$dir/SKILL.md" ]
}

contract_has_field() {
    local file="$1" field="$2"
    awk -v field="$field" '
        /^## Contract$/ { in_contract = 1; next }
        in_contract && /^## / { in_contract = 0 }
        in_contract && $0 ~ "^" field ":" { found = 1 }
        END { exit found ? 0 : 1 }
    ' "$file"
}

needs_ledger() {
    case "$1" in
        workflow-* | run-backlog | watch-ci | execute-prd | execute-phase) return 0 ;;
        *) return 1 ;;
    esac
}

[ -d "$root" ] || {
    echo "skills root not found: $root" >&2
    exit 2
}
# Resolve symlinks (the skills dir is stow-symlinked). Without this, find on a
# symlinked root descends into nothing and the whole lint passes vacuously.
root="$(cd "$root" && pwd -P)"

while IFS= read -r -d '' file; do
    skill="${file#"$root"/}"
    skill="${skill%/SKILL.md}"
    case "$skill" in
        deprecated/* | docs/* | _personas/*) continue ;;
    esac

    if ! has_frontmatter_key "$file" name; then
        fail "$skill missing frontmatter name"
    fi
    if ! has_frontmatter_key "$file" description; then
        fail "$skill missing frontmatter description"
    fi
    if awk 'BEGIN { fm = 0 } /^---$/ { fm++; next } fm == 1 && /^[[:space:]]+codex-compatible:/ { found = 1 } END { exit found ? 0 : 1 }' "$file"; then
        fail "$skill has nested codex-compatible frontmatter; use top-level codex-compatible"
    fi

    if grep -q 'Status: standalone use deprecated' "$file" && ! has_frontmatter_key "$file" disable-model-invocation; then
        fail "$skill is standalone-deprecated but lacks disable-model-invocation"
    fi

    if needs_ledger "$skill" && ! grep -q '^WORKFLOW_STEPS:' "$file"; then
        fail "$skill lacks WORKFLOW_STEPS ledger"
    fi

    if grep -q '^## Contract$' "$file"; then
        for field in Consumes Produces Requires "Side effects" "Human gates"; do
            if ! contract_has_field "$file" "$field"; then
                fail "$skill contract missing field: $field"
            fi
        done
    else
        warn "$skill lacks contract section"
    fi

    # Orphaned tooling: a shipped script that no doc references and no sibling
    # script calls is dead weight (the humanizer check_tells.py bug class).
    skill_dir="$root/$skill"
    if [ -d "$skill_dir/scripts" ]; then
        while IFS= read -r -d '' script; do
            base="$(basename "$script")"
            # Skip compiled/junk and tests. A test file is self-justifying
            # (it's the check behind another script, which we want to exist).
            case "$base" in
                *.pyc | test_* | *_test.* | *.test.*) continue ;;
            esac
            # referenced by any markdown in the skill?
            grep -rqIF --include='*.md' "$base" "$skill_dir" 2>/dev/null && continue
            # called by a sibling script (shared helper)?
            grep -rqIF --exclude="$base" "$base" "$skill_dir/scripts" 2>/dev/null && continue
            warn "$skill ships scripts/$base but nothing references or invokes it (orphaned tooling)"
        done < <(find "$skill_dir/scripts" -type f -not -path '*/__pycache__/*' -print0)
    fi
done < <(find "$root" -mindepth 2 -maxdepth 2 -name SKILL.md -print0)

# Generated skills index must be fresh (openwiki thesis: generate from source,
# don't let it drift). Deterministic and one-command-fixable.
if [ -x "$root/_docs/skills-index.sh" ]; then
    "$root/_docs/skills-index.sh" --check >/dev/null 2>&1 \
        || warn "_docs/skills-index.md is stale — run _docs/skills-index.sh --write"
fi

if [ "$check_runtime" = "1" ] && [ -d "$runtime_root" ]; then
    while IFS= read -r -d '' runtime_file; do
        skill="${runtime_file#"$runtime_root"/}"
        skill="${skill%/SKILL.md}"
        source_file="$root/$skill/SKILL.md"
        if [ ! -f "$source_file" ]; then
            if is_runtime_allowlisted "$skill"; then
                warn "Codex runtime has allowlisted runtime-only skill: $skill"
                continue
            fi
            fail "Codex runtime has skill not present in active source: $skill"
            continue
        fi
        if [ "$(frontmatter_value "$source_file" codex-compatible)" = "false" ]; then
            fail "Codex runtime exposes codex-compatible:false source skill: $skill"
        fi
    done < <(find "$runtime_root" -mindepth 2 -maxdepth 2 -name SKILL.md -print0)
fi

printf 'skill-suite lint: failures=%s warnings=%s\n' "$failures" "$warnings"
[ "$failures" -eq 0 ]
