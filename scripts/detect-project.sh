#!/bin/bash
# Detect project traits from marker files in a directory.
# Usage: detect-project.sh [directory]
# Output: one trait per line to stdout

set -euo pipefail

PROJECT_DIR="${1:-.}"

traits=()

# Language traits
[[ -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/setup.py" || -f "$PROJECT_DIR/setup.cfg" ]] && traits+=(python)
[[ -f "$PROJECT_DIR/package.json" ]] && traits+=(node)
[[ -f "$PROJECT_DIR/go.mod" ]] && traits+=(go)
[[ -f "$PROJECT_DIR/Cargo.toml" ]] && traits+=(rust)

# Infrastructure traits
[[ -f "$PROJECT_DIR/docker-compose.yml" || -f "$PROJECT_DIR/docker-compose.yaml" || -f "$PROJECT_DIR/Dockerfile" ]] && traits+=(docker)
[[ -f "$PROJECT_DIR/dbt_project.yml" ]] && traits+=(dbt)
[[ -d "$PROJECT_DIR/.git" ]] && traits+=(git)
[[ -f "$PROJECT_DIR/Brewfile" && -d "$PROJECT_DIR/dotfiles" ]] && traits+=(dotfiles)

# Web trait: package.json must contain a frontend framework dependency
if [[ -f "$PROJECT_DIR/package.json" ]]; then
  if grep -qE '"(next|react|vue|svelte|angular|nuxt|vite)"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    traits+=(web)
  fi
fi

# Override: .project-type file wins for trait lines (ignore key=value lines)
if [[ -f "$PROJECT_DIR/.project-type" ]]; then
  traits=()
  while IFS= read -r line; do
    line="${line%%#*}"        # strip comments
    line="$(echo "$line" | xargs)" # trim whitespace
    [[ -z "$line" ]] && continue
    [[ "$line" == *=* ]] && continue  # skip key=value pairs
    traits+=("$line")
  done < "$PROJECT_DIR/.project-type"
fi

# Output traits
for trait in "${traits[@]}"; do
  echo "$trait"
done
