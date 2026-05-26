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
