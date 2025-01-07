# In ~/dotdev/home/.zshrc
export XDG_CONFIG_HOME="$HOME/.config"
export ZSH_CONFIG="$XDG_CONFIG_HOME/zsh"

# Source configs
for conf in "$ZSH_CONFIG/configs"/*.zsh; do
  source "$conf"
done

# Source tools
for conf in "$ZSH_CONFIG/tools"/*.zsh; do
  source "$conf"
done

# Source starship
source "$ZSH_CONFIG/themes/starship.zsh"
eval "$(zoxide init zsh)"