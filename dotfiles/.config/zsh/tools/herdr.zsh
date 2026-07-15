# Herdr — terminal workspace manager for AI agents
# Completions: bootstrap compinit once (zsh ships no compdef until it runs)
if (( ! ${+functions[compdef]} )); then
  autoload -Uz compinit && compinit -C   # -C: trust cached .zcompdump (fast startup)
fi
command -v herdr >/dev/null && source <(herdr completion zsh)
