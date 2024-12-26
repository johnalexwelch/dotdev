#!/usr/bin/env zsh
# Main zsh configuration file

# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"
export ZDOTDIR="$HOME"
export ZSH_CONFIG="$HOME/.zsh"

# Source all configuration files
for conf in "$ZSH_CONFIG"/*.zsh; do
    # shellcheck source=/dev/null
    source "$conf"
done

# Source tool-specific configurations
for conf in "$ZSH_CONFIG"/tools/*.zsh; do
    # shellcheck source=/dev/null
    source "$conf"
done

# Source theme configuration
# shellcheck source=.config/.zsh/themes/starship.zsh
source "$ZSH_CONFIG/themes/starship.zsh"

# Initialize Oh My Zsh
# shellcheck source=${HOME}/.oh-my-zsh/oh-my-zsh.sh
source $ZSH/oh-my-zsh.sh
