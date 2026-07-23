export XDG_CONFIG_HOME="$HOME/.config"
export ZSH_CONFIG="$XDG_CONFIG_HOME/zsh"

# Recover automatically if the current directory was deleted (e.g., removed worktree).
_recover_invalid_cwd() {
  if [[ ! -d "$PWD" ]]; then
    builtin cd -- "$HOME" 2>/dev/null || builtin cd -- /
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _recover_invalid_cwd
_recover_invalid_cwd

# Source configs
for conf in "$ZSH_CONFIG/configs"/*.zsh; do
  # shellcheck source=/dev/null
  source "$conf"
done

# Source tools
for conf in "$ZSH_CONFIG/tools"/*.zsh; do
  # shellcheck source=/dev/null
  source "$conf"
done

# Source starship
source "$ZSH_CONFIG/themes/starship.zsh"
eval "$(zoxide init zsh)"

# Pin Node 22 LTS for ARIA (Electron 41 / better-sqlite3 12 compatibility)
export PATH="/opt/homebrew/opt/node@22/bin:$PATH"

# GitHub MCP server token - preserve the shared var and expose Codex's expected alias.
if [[ -z "${GITHUB_MCP_PAT:-}" ]]; then
  _github_mcp_pat="$(launchctl getenv GITHUB_MCP_PAT 2>/dev/null)"
  [[ -z "$_github_mcp_pat" ]] && _github_mcp_pat="$(launchctl getenv CODEX_GITHUB_PERSONAL_ACCESS_TOKEN 2>/dev/null)"
  [[ -n "$_github_mcp_pat" ]] && export GITHUB_MCP_PAT="$_github_mcp_pat"
  unset _github_mcp_pat
fi

if [[ -z "${CODEX_GITHUB_PERSONAL_ACCESS_TOKEN:-}" && -n "${GITHUB_MCP_PAT:-}" ]]; then
  export CODEX_GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_MCP_PAT"
fi
export PATH="$HOME/.cargo/bin:$PATH"


# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -f "$HOME/.safe-chain/scripts/init-posix.sh" ] && source "$HOME/.safe-chain/scripts/init-posix.sh"

# Quick idea capture → Obsidian Idea Bin
# Usage: idea <thought>        → AI-enriched note
#        idea -q <thought>     → quick, no AI
idea() {
  local dir="$HOME/Documents/Home/Idea Bin"
  local ts=$(date "+%Y-%m-%d")
  local quick=0

  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    echo "usage: idea            → prompt (safe for parens/special chars)"
    echo "       idea <text>     → inline capture"
    echo "       idea -q <text>  → quick, no AI"
    return
  }
  [[ "$1" == "-q" || "$1" == "--quick" ]] && { quick=1; shift; }

  local title
  if [[ $# -eq 0 ]]; then
    read -r "title?Idea: "
    [[ -z "$title" ]] && return
  else
    title="$*"
  fi

  local safe="${title//[\/:\*\?\"<>\|]/}"
  safe="${safe:0:60}"
  local file="$dir/$(date +%Y-%m-%d) ${safe}.md"

  if [[ $quick -eq 1 ]]; then
    printf '---\ntitle: %s\ncreated: %s\ncategory: other\ndomain: other\nenergy: 0\nstatus: captured\n---\n\n# %s\n\n> (no pitch — quick capture)\n\n## Next Steps\n\n- TBD\n' \
      "$title" "$ts" "$title" > "$file"
    echo "✓ $(basename "$file")"
    return
  fi

  echo "⏳ thinking..." >&2

  local prompt="You are a product thinking assistant. Given an idea, return ONLY this exact format with no extra text:

CATEGORY: <one of: tool, app, content, research, business, experiment, feature, creative, home, health, other>
PITCH: <one crisp sentence — what it is and why it matters>
TAGS: <2-4 obsidian tags like #app-idea #productivity>
STEPS:
- <concrete next step 1>
- <concrete next step 2>
- <concrete next step 3>

Idea: $title"

  local ai_out category pitch tags steps
  ai_out=$(claude -p "$prompt" --model claude-haiku-4-5 2>/dev/null)

  category=$(echo "$ai_out" | grep '^CATEGORY:' | sed 's/CATEGORY: *//'); category=${category:-other}
  pitch=$(echo "$ai_out"    | grep '^PITCH:'    | sed 's/PITCH: *//');    pitch=${pitch:-(no pitch)}
  tags=$(echo "$ai_out"     | grep '^TAGS:'     | sed 's/TAGS: *//');     tags=${tags:-#idea}
  steps=$(echo "$ai_out"    | awk '/^STEPS:/{f=1;next} f && /^- /{print}')

  printf '---\ntitle: %s\ncreated: %s\ncategory: %s\ndomain: %s\nenergy: 0\nstatus: captured\n---\n\n# %s\n\n> %s\n\ntags: #idea %s\n\n## Next Steps\n\n%s\n' \
    "$title" "$ts" "$category" "$category" "$title" "$pitch" "$tags" "$steps" > "$file"

  echo "✓ [$category] $(basename "$file")"
  echo "$pitch"
}

# Idea OS — review, promote, search
ideas() {
  local cmd="$1"; shift
  case "$cmd" in
    review)  python3 ~/projects/idea-os/bin/ideas-review "$@" ;;
    promote) python3 ~/projects/idea-os/bin/ideas-promote "$@" ;;
    search)  grep -ril "$*" "$HOME/Documents/Home/Idea Bin/" "$HOME/Documents/Home/Projects/" 2>/dev/null ;;
    *)       echo "usage: ideas review | promote <file> | search <term>" ;;
  esac
}

# prefix history search: type start of command, arrows cycle only matches
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search    # up
bindkey '^[[B' down-line-or-beginning-search  # down
bindkey '^[OA' up-line-or-beginning-search    # up (app mode)
bindkey '^[OB' down-line-or-beginning-search  # down (app mode)

# fzf fuzzy search: Ctrl-T files, Alt-C cd (Ctrl-R handed to atuin below)
source <(fzf --zsh)
# atuin: SQLite-backed history w/ metadata + cross-machine sync. Loaded AFTER fzf
# so it owns Ctrl-R; --disable-up-arrow keeps Up as normal prefix history.
# Cross-machine sync needs a one-time `atuin register`/`atuin login`.
eval "$(atuin init zsh --disable-up-arrow)"

# Hermes Agent — ensure ~/.local/bin is on PATH
export PATH="$HOME/.local/bin:$PATH"
