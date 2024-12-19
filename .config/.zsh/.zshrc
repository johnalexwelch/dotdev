# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"
export ZDOTDIR="$HOME"
export ZSH_CONFIG="$HOME/.zsh"

# Source all configuration files
for conf in "$ZSH_CONFIG"/*.zsh; do
    source "$conf"
done

# Source tool-specific configurations
for conf in "$ZSH_CONFIG"/tools/*.zsh; do
    source "$conf"
done

# Source theme configuration
source "$ZSH_CONFIG/themes/starship.zsh"

# Initialize Oh My Zsh
source $ZSH/oh-my-zsh.sh