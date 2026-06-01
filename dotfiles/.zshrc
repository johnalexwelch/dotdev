# In ~/dotdev/home/.zshrc
export XDG_CONFIG_HOME="$HOME/.config"
export ZSH_CONFIG="$XDG_CONFIG_HOME/zsh"

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
