#!/usr/bin/env bash
# Sync dotdev skill source into the Codex runtime. Dry-run by default.

set -euo pipefail

source_root="${SOURCE_SKILLS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
runtime_root="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
apply=0
prune=0

usage() {
    cat <<'USAGE'
Usage: sync-codex-skills.sh [--apply] [--prune]

Default is dry-run. --apply copies active source skills to the Codex runtime.
--prune includes runtime skills that are not active source skills or are
codex-incompatible in the dry run; with --apply, those skills are removed.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --apply) apply=1 ;;
        --prune) prune=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

[ -d "$source_root" ] || {
    echo "source skills root not found: $source_root" >&2
    exit 2
}

mkdir -p "$runtime_root"

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

copy_count=0
skip_count=0
while IFS= read -r -d '' skill_file; do
    skill="${skill_file#"$source_root"/}"
    skill="${skill%/SKILL.md}"
    case "$skill" in
        deprecated/*|docs/*|_personas/*) continue ;;
    esac
    if [ "$(frontmatter_value "$skill_file" codex-compatible)" = "false" ]; then
        printf 'skip codex-incompatible: %s\n' "$skill"
        skip_count=$((skip_count + 1))
        continue
    fi
    action="would sync"
    [ "$apply" = "1" ] && action="sync"
    printf '%s %s -> %s\n' "$action" "$skill" "$runtime_root/$skill"
    if [ "$apply" = "1" ]; then
        rm -rf "${runtime_root:?}/$skill"
        cp -R "$source_root/$skill" "${runtime_root:?}/$skill"
    fi
    copy_count=$((copy_count + 1))
done < <(find "$source_root" -mindepth 2 -maxdepth 2 -name SKILL.md -print0)

if [ "$prune" = "1" ]; then
    while IFS= read -r -d '' runtime_file; do
        skill="${runtime_file#"$runtime_root"/}"
        skill="${skill%/SKILL.md}"
        if [ ! -f "$source_root/$skill/SKILL.md" ] ||
            [ "$(frontmatter_value "$source_root/$skill/SKILL.md" codex-compatible)" = "false" ]; then
            action="would prune"
            [ "$apply" = "1" ] && action="prune"
            printf '%s runtime-only/incompatible: %s\n' "$action" "$skill"
            if [ "$apply" = "1" ]; then
                rm -rf "${runtime_root:?}/$skill"
            fi
        fi
    done < <(find "$runtime_root" -mindepth 2 -maxdepth 2 -name SKILL.md -print0)
fi

printf 'codex skill sync complete: copy_candidates=%s skipped=%s apply=%s prune=%s runtime=%s\n' \
    "$copy_count" "$skip_count" "$apply" "$prune" "$runtime_root"
