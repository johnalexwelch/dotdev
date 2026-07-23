# Herdr — terminal workspace manager for AI agents
# Completions: bootstrap compinit once (zsh ships no compdef until it runs)
if (( ! ${+functions[compdef]} )); then
  autoload -Uz compinit && compinit -C   # -C: trust cached .zcompdump (fast startup)
fi
command -v herdr >/dev/null && source <(herdr completion zsh)

# ponytail: launchd-supervised server instead of a bare foreground process,
# so sleep/OOM/crash kills get auto-restarted instead of silent "lost connection"
herdr-up() { brew services start herdr && brew services info herdr; }
herdr-down() { brew services stop herdr; }
herdr-status() { brew services info herdr; }
herdr-restart() { brew services restart herdr && brew services info herdr; }
herdr-logs() { tail -f /opt/homebrew/var/log/herdr.log; }
