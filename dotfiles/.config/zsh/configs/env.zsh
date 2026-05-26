# shellcheck disable=SC1090
# Path configuration
export PATH="$HOME/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/Applications/Cursor.app/Contents/MacOS:$PATH"

# XDG Base Directory specification
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# Credential files
for cred in .redshift .metabase .trino .asana .slack .readwise .anthropic .todoist .google .chief-of-staff-env .openai; do
  [[ -f "$HOME/$cred" ]] && source "$HOME/$cred"
done

# Environment variables
export EDITOR='code'
export VISUAL='code'
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Vault
export VAULT_ADDR=https://vault.internal.classdojo.com

# CORA
export CORA_AUTO_UNINSTALL_DISABLED_CASKS=true
export CORA_PR_MONITOR_REPOS="classdojo/iris, classdojo/astronomer"
export CORA_PR_MONITOR_GITHUB_MENTION="@alexwelch-dojo"
export CORA_PR_MONITOR_NOTIFY_MACOS=true
export CORA_AUTO_PR_REVIEW_FIXES=true
