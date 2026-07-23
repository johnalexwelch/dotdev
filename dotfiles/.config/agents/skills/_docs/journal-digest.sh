#!/usr/bin/env bash
# journal-digest — harvest deterministic AI-journey facts and prepend a dated
# block to the journal. Sources: git history of the skills repo (skills
# added/modified/deprecated) + `rtk gain` (token/cache savings). No LLM, no tokens.
#
#   journal-digest.sh            # prepend a digest to the journal, advance the watermark
#   journal-digest.sh --dry      # print the block to stdout, change nothing
#
# Qualitative notes (why you switched models, tools tried, articles) stay manual.
set -euo pipefail

JOURNAL="${JOURNAL:-$HOME/Documents/Home/AI History.md}"
SKILLS_REPO="${SKILLS_REPO:-$HOME/.claude/skills}"
# The skills dir is stow-symlinked from the dotfiles repo; resolve its real root
# so we can also harvest config/tooling/model changes tracked there.
REPO="$(git -C "$SKILLS_REPO" rev-parse --show-toplevel 2>/dev/null || echo "$SKILLS_REPO")"
STATE="${STATE:-$SKILLS_REPO/_docs/.journal-last}"
DRY=false
[ "${1:-}" = "--dry" ] && DRY=true

# Watermark: last run time + last rtk snapshot. Default window = 7 days.
since="7 days ago"
prev_saved="(first run)"
prev_cmds="(first run)"
if [ -f "$STATE" ]; then
    # shellcheck disable=SC1090
    . "$STATE"
    since="${last_run:-$since}"
    prev_saved="${rtk_saved:-n/a}"
    prev_cmds="${rtk_cmds:-n/a}"
fi
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
today="$(date +%Y-%m-%d)"

# --- Skill evolution from git (A=new, M=changed, D=deprecated) ---
skill_changes() {
    # Stow layout: real paths are deep (…/skills/<name>/SKILL.md), so key on the
    # dir segment immediately before SKILL.md, not the first path segment.
    git -C "$REPO" log --since="$since" --pretty=format: --name-status \
        -- '*/SKILL.md' 2>/dev/null | awk '
    function skill(path){ sub(/\/SKILL\.md$/,"",path); n=split(path,p,"/"); return p[n] }
    /^[AMD]/ { s=skill($2); if ($1=="A") add[s]=1; else if ($1=="D") del[s]=1; else mod[s]=1 }
    /^R/     { mod[skill($3)]=1 }
    END {
      for (s in del) { delete add[s]; delete mod[s] } # removed trumps add/mod
      for (s in add) delete mod[s];                    # new trumps modified
      la=""; for (s in add) la=la" "s;
      ld=""; for (s in del) ld=ld" "s;
      lm=""; for (s in mod) if (!(s in add)) lm=lm" "s;
      print "ADD:"la; print "DEL:"ld; print "MOD:"lm }'
}
raw="$(skill_changes)"
join() { xargs -n1 2>/dev/null | sort -u | paste -sd, - | sed 's/,/, /g'; }
added="$(printf '%s\n' "$raw" | sed -n 's/^ADD://p' | join)"
deleted="$(printf '%s\n' "$raw" | sed -n 's/^DEL://p' | join)"
modified="$(printf '%s\n' "$raw" | sed -n 's/^MOD://p' | join)"
total_skills="$(find -L "$SKILLS_REPO" -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')"

# --- Config / tooling / model changes (settings, MCP, Brewfile, hooks, themes) ---
# Model + provider choices live in settings.json / mcp.json, so a diff here is the
# deterministic "I changed models/tools" signal. The 'why' stays a manual note.
config="$(git -C "$REPO" log --since="$since" --pretty=format: --name-only -- \
    '*settings.json' '*mcp*.json' 'Brewfile' '*/hooks/*' '*keybind*' '*theme*' '*/.pi/agent/*' 2>/dev/null |
    awk 'NF' | sed 's#^dotfiles/##; s#\.config/##' | sort -u | paste -sd, - | sed 's/,/, /g')"

# --- Token / cache savings from rtk ---
saved="n/a"
cmds="n/a"
if command -v rtk >/dev/null 2>&1; then
    g="$(rtk gain 2>/dev/null || true)"
    saved="$(printf '%s\n' "$g" | sed -n 's/.*Tokens saved:[[:space:]]*//p' | head -1)"
    cmds="$(printf '%s\n' "$g" | sed -n 's/.*Total commands:[[:space:]]*//p' | head -1)"
fi

block="$(
    cat <<EOF
$today — auto-digest (since ${since})
- **Skills** (repo total: ${total_skills})
	- New: ${added:-none}
	- Changed: ${modified:-none}
	- Deprecated/removed: ${deleted:-none}
- **Config / tooling / models** (settings, MCP, Brewfile, hooks, themes — model/provider changes show up here)
	- Changed: ${config:-none}
- **Token/cache (rtk gain, cumulative)**
	- Tokens saved: ${saved:-n/a} (prev snapshot: ${prev_saved})
	- Commands wrapped: ${cmds:-n/a} (prev: ${prev_cmds})
- _Add qualitative notes below: models used + why, tools tried (pi/herdr/etc.), cache/context strategy changes, articles/videos._

EOF
)"

if $DRY; then
    printf '%s\n' "$block"
    exit 0
fi

# Prepend (journal is newest-first) then advance the watermark.
tmp="$(mktemp)"
printf '%s\n' "$block" >"$tmp"
[ -f "$JOURNAL" ] && cat "$JOURNAL" >>"$tmp"
mkdir -p "$(dirname "$JOURNAL")"
mv "$tmp" "$JOURNAL"
{
    echo "last_run='$now'"
    echo "rtk_saved='${saved:-n/a}'"
    echo "rtk_cmds='${cmds:-n/a}'"
} >"$STATE"
echo "digest written to $JOURNAL"
