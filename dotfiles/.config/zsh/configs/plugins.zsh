# zsh plugin config — vars consumed if plugins are sourced via Homebrew
# ponytail: oh-my-zsh removed (not installed); add zsh-autosuggestions +
#   zsh-syntax-highlighting to Brewfile and source them here when needed

# zsh-autosuggestions
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=60'

# zsh-syntax-highlighting
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
