#!/usr/bin/env bash
# lint-skill-refs.sh — detect hollow sub-skill references.
#
# A skill that invokes another via the canonical form
#   Load and run `<name>/SKILL.md`   /   Load and execute `<name>/SKILL.md`   /   follow `<name>`
# must point at a skill that is ACTIVE in the skills root (linked into it), not merely
# present in canon. An active skill referencing an inactive one = a hollow loop
# (the failure mode where /workflow-debug dies at "Step 1: diagnose" because diagnose
# isn't linked). See decision-log.md D-003.
#
# Usage: lint-skill-refs.sh [skills-root]   (default: ~/.claude/skills)
# Exit:  0 = clean, 1 = dangling refs found.

set -uo pipefail
root="${1:-$HOME/.claude/skills}"
[ -d "$root" ] || {
    echo "skills root not found: $root" >&2
    exit 2
}

# Active skills = directories under root with a resolvable SKILL.md (follows symlinks).
is_active() { [ -f "$root/$1/SKILL.md" ]; }

dangling=0
checked=0
# Iterate active skills only — an inactive skill's refs don't run on this host.
for d in "$root"/*/; do
    name="$(basename "$d")"
    is_active "$name" || continue
    f="$root/$name/SKILL.md"
    # Extract referenced skill names from the canonical invocation forms.
    refs="$({
        grep -oE 'Load and (run|execute) `?[a-z][a-z0-9-]+/SKILL\.md' "$f" 2>/dev/null |
            sed -E 's#^Load and (run|execute) `?##; s#/SKILL\.md$##'
        grep -oE 'follow `[a-z][a-z0-9-]+`' "$f" 2>/dev/null |
            sed -E 's#^follow `##; s#`$##'
    } | sort -u)"
    [ -z "$refs" ] && continue
    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        [ "$ref" = "$name" ] && continue
        checked=$((checked + 1))
        if ! is_active "$ref"; then
            incanon="(not in canon either)"
            [ -e "$HOME/dotdev/dotfiles/.claude/skills/$ref/SKILL.md" ] && incanon="(in canon, NOT linked)"
            printf '  DANGLING: %-26s → %-22s %s\n' "$name" "$ref" "$incanon"
            dangling=$((dangling + 1))
        fi
    done <<<"$refs"
done

echo
echo "checked $checked explicit refs across active skills; dangling: $dangling"
[ "$dangling" -eq 0 ] && {
    echo "OK — no hollow references."
    exit 0
} || exit 1
