# shellcheck disable=SC2154
# File operations
alias ls="eza --color=always --git --no-filesize --icons=always --no-time --no-user --no-permissions"
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias lt='eza --tree --icons --group-directories-first'
alias cat='bat'
# NOTE: do NOT alias grep->rg or find->fd. rg/fd are not flag-compatible with
# grep/find (different -E/-A/-name/-maxdepth semantics, different stdin/pipe
# behavior), which silently breaks scripts and piped commands. Use rg/fd by
# their real names instead.
alias g='rg'
alias f='fd'
alias j='z'
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
alias piup='pi update && pi update --extensions'


# Directory shortcuts
hash -d docs=~/Documents
hash -d dl=~/Downloads
hash -d code=~/Code

# Add docker cleanup aliases
alias dprune='docker system prune -af'
alias dclean='docker rm -f $(docker ps -aq)'

# Data tools
alias redshift='lazysql "$REDSHIFT_URL"'

# Add network tools
alias myip='curl ifconfig.me'
alias ports='netstat -tulanp'

# pi — load heavy agent-browser package on demand (kept out of default sessions)
alias pib='pi -e npm:pi-agent-browser-native'

# Editor aliases
alias code="cursor"  # Make 'code' command open Cursor
alias cur="cursor"   # Shorter alias for Cursor

# Projects — herdr workspaces
alias hdev='bash ~/dotdev/scripts/hdev.sh'
alias hlog='bash ~/dotdev/scripts/hlog.sh'
alias chorus='hdev ~/projects/chorus'
alias coraws='hdev ~/projects/chorus/cora'  # CORA repo workspace; bare `cora` = the CLI binary
alias miraws='hdev ~/projects/agents/mira'  # Mira agent workspace; bare `mira` = the Hermes profile wrapper

# Hermes dashboard — headless (detached) but UI still served at http://127.0.0.1:9119
# Usage: hdash [up] | stop | status | log | open
hdash() {
  local url="http://127.0.0.1:9119/"
  case "${1:-up}" in
    up)
      if hermes dashboard --status 2>/dev/null | grep -q .; then
        echo "already running → $url"
      else
        nohup hermes dashboard --no-open > ~/.hermes/dashboard.log 2>&1 &
        disown
        echo "✓ spun up (detached) → $url"
      fi
      ;;
    stop)   hermes dashboard --stop ;;
    status) hermes dashboard --status ;;
    log)    tail -f ~/.hermes/dashboard.log ;;
    open)   open "$url" ;;
    *)      echo "usage: hdash [up] | stop | status | log | open" ;;
  esac
}
