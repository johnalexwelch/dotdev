# History — managed by atuin (cross-session SQLite, fuzzy search)
# Falls back to zsh native history if atuin not installed.

HISTFILE=$HOME/.zhistory
SAVEHIST=50000
HISTSIZE=50000

setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt EXTENDED_HISTORY

if command -v atuin &>/dev/null; then
  eval "$(atuin init zsh --disable-up-arrow)"
  # ponytail: --disable-up-arrow keeps native up-arrow completion;
  # remove flag if you prefer atuin's full-context search on up-arrow too
else
  setopt SHARE_HISTORY
  setopt INC_APPEND_HISTORY
  bindkey '^[[A' history-search-backward
  bindkey '^[[B' history-search-forward
fi
