ZSH_THEME=""  # We're using starship instead
COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=60'

# Plugins
plugins=(
    git                     # Git aliases and functions
    gh                      # GitHub CLI
    pyenv                   # Python version manager
    zsh-autocomplete       # Advanced auto-completion
    zsh-syntax-highlighting # Syntax highlighting
    zsh-autosuggestions    # Fish-like autosuggestions
    history                # History aliases
    copypath              # Copy current directory path
    copyfile              # Copy file contents
    dirhistory            # Directory navigation
    fzf                   # Fuzzy finder integration
    docker-compose        # Docker compose completions
    kubectl              # Kubernetes completions
    terraform            # Terraform completions
    aws                  # AWS CLI completions
    colored-man-pages    # Colorized man pages
)

# Plugin configurations
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=60'
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
