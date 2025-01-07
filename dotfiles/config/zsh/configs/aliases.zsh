# File operations
alias ls="eza --color=always --git --no-filesize --icons=always --no-time --no-user --no-permissions"
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias lt='eza --tree --icons --group-directories-first'
alias cat='bat'
alias grep='rg'
alias find='fd'
alias cd='z'
alias top='htop'
alias du='dust'
alias df='duf'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias mkdir='mkdir -p'
alias cp='cp -i'
alias mv='mv -i'
alias vim='nvim'

# Configuration
alias zshconfig="code ~/.zshrc"
alias reload="source ~/.zshrc"

alias ohmyzsh="code ~/.oh-my-zsh"

# Directory shortcuts
hash -d docs=~/Documents
hash -d dl=~/Downloads
hash -d code=~/Code

# Add docker cleanup aliases
alias dprune='docker system prune -af'
alias dclean='docker rm -f $(docker ps -aq)'

# Add network tools
alias myip='curl ifconfig.me'
alias ports='netstat -tulanp'

# Editor aliases
alias code="cursor"  # Make 'code' command open Cursor
alias cur="cursor"   # Shorter alias for Cursor
