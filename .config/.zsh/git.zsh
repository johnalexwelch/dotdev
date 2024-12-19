# Git aliases
alias g='git'
alias gs='git status -sb'     # Short status with branch info
alias ga='git add'
alias gaa='git add --all'     # Add all changes
alias gc='git commit'
alias gcm='git commit -m'     # Commit with message
alias gca='git commit --amend'  # Amend last commit
alias gb='git branch'
alias gba='git branch -a'     # List all branches
alias gbd='git branch -d'     # Delete branch
alias gbD='git branch -D'     # Force delete branch
alias gco='git checkout'
alias gcb='git checkout -b'   # Create and checkout new branch
alias gct='git checkout --track' # Checkout remote branch
alias gf='git fetch'          # Fetch changes
alias gfa='git fetch --all'   # Fetch from all remotes
alias gl='git pull'           # Pull changes
alias gp='git push'           # Push changes
alias gpo='git push origin'   # Push to origin
alias gpf='git push --force-with-lease' # Force push safely
alias gst='git stash'         # Stash changes
alias gsta='git stash apply'  # Apply stash
alias gstp='git stash pop'    # Pop stash
alias gstl='git stash list'   # List stashes
alias gd='git diff'           # View changes
alias gds='git diff --staged' # View staged changes
alias glog='git log --oneline --decorate --graph' # Pretty log
alias gloga='git log --oneline --decorate --graph --all' # Log all branches
alias grb='git rebase'
alias grbi='git rebase -i'    # Interactive rebase
alias gm='git merge'
alias gcp='git cherry-pick'
alias gce="gitmoji -c"        # Commit with emoji
alias gel="gitmoji -l"        # List emojis

# Git functions
# Create and switch to a new branch
gnb() {
    if [ -z "$1" ]; then
        echo "Please provide a branch name"
        return 1
    fi
    git checkout -b "$1" && git push -u origin "$1"
}

# Clean up local branches that have been merged
gclean() {
    git branch --merged | egrep -v "(^\*|master|main|dev)" | xargs git branch -d
}

# Interactive git add using fzf
ga-fzf() {
    git ls-files -m -o --exclude-standard | fzf -m --preview 'git diff --color=always {}' | xargs -I {} git add {}
}

# Interactive git checkout branch using fzf
gco-fzf() {
    git branch --all | grep -v HEAD | fzf --preview 'git log --oneline --graph --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed "s/.* //" <<< {})' | sed "s/.* //" | xargs git checkout
}

# Show git history with fzf
gh-fzf() {
    git log --graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" | \
    fzf --ansi --no-sort --reverse --tiebreak=index --preview \
    'f() { set -- $(echo -- "$@" | grep -o "[a-f0-9]\{7\}"); [ $# -eq 0 ] || git show --color=always $1; }; f {}' \
    --bind "ctrl-m:execute:
            (grep -o '[a-f0-9]\{7\}' | head -1 |
            xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
            {}
    FZF-EOF"
}
