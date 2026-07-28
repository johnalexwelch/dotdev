#!/usr/bin/env bash
# Validate a captured idea file has the required frontmatter keys.
# ponytail: plain grep check, no YAML parser. Upgrade to `yq` if frontmatter
# grows structured (nested keys, lists) beyond flat `key: value`.
set -euo pipefail

file="${1:?usage: check.sh <idea-file.md>}"
[[ -f "$file" ]] || {
	echo "✗ not found: $file" >&2
	exit 1
}

required=(title created category domain energy status)
missing=()
for key in "${required[@]}"; do
	grep -qE "^${key}:" "$file" || missing+=("$key")
done

if ((${#missing[@]})); then
	echo "✗ $file missing frontmatter: ${missing[*]}" >&2
	exit 1
fi
echo "✓ $file has all required frontmatter keys"
