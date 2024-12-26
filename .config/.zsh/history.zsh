# History configuration
HISTFILE=$HOME/.zhistory
SAVEHIST=10000
HISTSIZE=10000


# History options
setopt SHARE_HISTORY          # Share history between sessions
setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicates first when trimming history
setopt HIST_IGNORE_DUPS       # Don't record duplicates
setopt HIST_VERIFY            # Show command with history expansion to user before running it
setopt HIST_IGNORE_ALL_DUPS   # Don't record duplicates
setopt HIST_SAVE_NO_DUPS      # Don't save duplicates
setopt HIST_REDUCE_BLANKS     # Remove blank lines
setopt EXTENDED_HISTORY       # Add timestamps to history
setopt HIST_FIND_NO_DUPS      # Don't show duplicates in search
setopt HIST_SAVE_BY_COPY      # Save history safely
setopt INC_APPEND_HISTORY     # Add commands as they are typed

# Key bindings
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
