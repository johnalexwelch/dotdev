# theme — switch the whole terminal stack in one command.
#
# One profile name maps to each tool's own theme id and applies to:
#   ghostty (theme =)  ·  nvim (colorscheme)  ·  herdr ([theme] name, live reload)
# yazi / hunk / pi inherit the terminal, so they follow ghostty for free.
#
# Usage:
#   theme                 # fzf picker
#   theme tokyonight      # apply a named profile
#   theme --list          # list profiles
#   theme --current       # show what's set now
#
# Writes edit the dotfiles SOURCE files with truncate-in-place (`>`), never
# rename, so stow hardlinks (ghostty) / symlinks (herdr) stay intact.
# (base16 managers like `flavours`/`theme.sh` map palettes, not the named
# themes these tools ship — they wouldn't hit herdr's built-in theme names,
# hence this thin wrapper.)

typeset -gA _THEME_PROFILES
# profile      "ghostty theme|nvim colorscheme|herdr theme"
_THEME_PROFILES=(
  kanagawa   "Kanagawa Wave|kanagawa|kanagawa"
  dragon     "Kanagawa Dragon|kanagawa-dragon|kanagawa"
  tokyonight "TokyoNight Moon|tokyonight-moon|tokyo-night"
  storm      "TokyoNight Storm|tokyonight-storm|tokyo-night"
  nightfox   "Nightfox|nightfox|terminal"
  nordfox    "Nordfox|nordfox|nord"
  duskfox    "Duskfox|duskfox|rose-pine"
  catppuccin "Catppuccin Macchiato|catppuccin-macchiato|catppuccin"
)

_theme_df="$HOME/dotdev/dotfiles/.config"
_theme_ghostty="$_theme_df/ghostty/config"
_theme_nvim="$_theme_df/nvim/lua/plugins/colorscheme.lua"
_theme_herdr="$_theme_df/herdr/config.toml"

# truncate-in-place: keep the existing inode (stow-safe), replace contents
_theme_rewrite() {
  local file="$1" content="$2"
  [[ -f "$file" ]] || return 0
  [[ -z "$content" ]] && { echo "theme: refusing empty write to $file" >&2; return 1; }
  print -r -- "$content" > "$file"
}

# set/replace the `name` line inside herdr's [theme] section, append if absent
_theme_set_herdr() {
  local val="$1" file="$_theme_herdr"
  [[ -f "$file" ]] || return 0
  local out
  out="$(awk -v val="$val" '
    /^\[theme\][ \t]*$/ { print; print "name = \"" val "\""; done=1; insec=1; next }
    /^\[/ { insec=0 }
    insec && /^[ \t]*name[ \t]*=/ { next }
    { print }
    END { if(!done){ print ""; print "[theme]"; print "name = \"" val "\"" } }
  ' "$file")"
  print -r -- "$out" > "$file"
}

theme() {
  case "$1" in
    --list|-l)
      local k
      for k in ${(ko)_THEME_PROFILES}; do printf '  %-11s %s\n' "$k" "${_THEME_PROFILES[$k]%%|*}"; done
      return 0 ;;
    --current|-c)
      echo "ghostty : $(grep -E '^theme = ' "$_theme_ghostty" 2>/dev/null | sed 's/^theme = //')"
      echo "nvim    : $(grep -E '^[[:space:]]+colorscheme = ' "$_theme_nvim" 2>/dev/null | grep -oE '"[^"]*"' | tr -d '\"')"
      echo "herdr   : $(grep -A3 '^\[theme\]' "$_theme_herdr" 2>/dev/null | grep -E '^name = ' | grep -oE '"[^"]*"' | tr -d '\"')"
      return 0 ;;
  esac

  local name="$1"
  if [[ -z "$name" ]]; then
    command -v fzf >/dev/null || { echo "theme: install fzf or pass a name (theme --list)"; return 1; }
    local line
    line=$(for k in ${(ko)_THEME_PROFILES}; do printf '%-11s → %s\n' "$k" "${_THEME_PROFILES[$k]%%|*}"; done \
             | fzf --prompt="theme> " --height=40% --reverse) || return
    name="${line%% *}"
    [[ -z "$name" ]] && return
  fi

  local spec="${_THEME_PROFILES[$name]}"
  if [[ -z "$spec" ]]; then
    echo "theme: unknown profile '$name'" >&2
    echo "available: ${(ko)_THEME_PROFILES}" >&2
    return 1
  fi
  local gt="${spec%%|*}" rest="${spec#*|}"
  local nv="${rest%%|*}" hd="${rest##*|}"

  # ghostty
  if [[ -f "$_theme_ghostty" ]]; then
    _theme_rewrite "$_theme_ghostty" "$(sed -E "s|^theme = .*|theme = ${gt}|" "$_theme_ghostty")"
  fi
  # nvim (anchor on the indented assignment so comments are never touched)
  if [[ -f "$_theme_nvim" ]]; then
    _theme_rewrite "$_theme_nvim" "$(sed -E "s|^([[:space:]]+)colorscheme = \"[^\"]*\"|\\1colorscheme = \"${nv}\"|" "$_theme_nvim")"
  fi
  # herdr — set theme and reload live
  local herdr_live=0
  if [[ -f "$_theme_herdr" ]]; then
    _theme_set_herdr "$hd"
    herdr server reload-config >/dev/null 2>&1 && herdr_live=1
  fi
  # ghostty — reload live via SIGUSR2 (no-op if unsupported)
  local gpid ghostty_live=0
  gpid=$(pgrep -x ghostty 2>/dev/null | head -1)
  [[ -n "$gpid" ]] && kill -SIGUSR2 "$gpid" 2>/dev/null && ghostty_live=1

  print -P "%F{green}theme → ${name}%f"
  if (( ghostty_live )); then
    echo "  ghostty : $gt  (reloaded live — if unchanged, press ⌘⇧,)"
  else
    echo "  ghostty : $gt  (press ⌘⇧, or open a new window)"
  fi
  echo "  nvim    : $nv  (next launch, or :colorscheme $nv now)"
  if (( herdr_live )); then
    echo "  herdr   : $hd  (reloaded live ✓)"
  else
    echo "  herdr   : $hd  (start herdr / herdr server reload-config)"
  fi
}
