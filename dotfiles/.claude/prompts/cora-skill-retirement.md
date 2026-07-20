# CORA Task: Skill Retirement Audit

You are running a periodic audit of Alex's personal Claude Code skill tree to identify candidates for retirement, archive them safely, and keep the skill map in sync. This is a **conservative janitor task** — when in doubt, do NOT delete; flag for human review instead.

## Mission

1. Detect skills that are stale, unused, duplicate, broken, or superseded.
2. Classify each candidate: archive | deprecate | delete | leave-alone.
3. Execute the chosen action with full reversibility (archive first, never hard-delete on first pass).
4. Update the skill map (`~/.claude/SKILLS-MAP.md` and `~/Documents/Home/Personal Skills Map.md`) in sync.
5. Produce a structured report Alex can read in under 60 seconds.

## Inputs

| Source | What it tells you |
|---|---|
| `~/.claude/skills/` (single symlink to `~/.config/agents/skills`) | Live skills, what's currently discoverable |
| `~/dotdev/dotfiles/.config/agents/skills/` | Actual skill files for skills owned by Alex (canon, stowed into `~/.config/agents/skills`) |
| `~/.claude/SKILLS-MAP.md` | Canonical "what should exist" map |
| `~/Documents/Home/Personal Skills Map.md` | Obsidian-synced copy of the map |
| Session transcripts at `~/.claude/projects/*/` | Recent invocations (use `grep` for skill names in `.jsonl` files) |
| Git log on `~/dotdev/dotfiles/.config/agents/skills/` | When each skill was last edited |
| `~/.claude/skills/_archive/` | Where previously-retired skills live |

## Detection rules

A skill becomes a **retirement candidate** when ANY of these fire:

1. **Stale**: No invocation found in the last 90 days of session transcripts, AND last edited > 90 days ago.
2. **Orphaned canon entry**: a directory under `~/dotdev/dotfiles/.config/agents/skills/<name>` has no resolvable `SKILL.md` (there is no per-skill symlink anymore — `~/.claude/skills` is one symlink to `~/.config/agents/skills`, so "broken" now means malformed/missing content in canon, not a dangling link).
3. **Empty SKILL.md**: SKILL.md exists but is < 200 bytes or has no `description:` frontmatter.
4. **Duplicate**: Two skills' `description:` frontmatter overlap by > 70% semantic similarity, AND one is clearly the newer / preferred one (mentioned in SKILLS-MAP.md, the other isn't).
5. **Orphan**: Listed in SKILLS-MAP.md but no longer exists on disk (the reverse — also flag).
6. **Superseded**: A SKILL.md's frontmatter contains `deprecated: true` or `superseded_by: <name>`.
7. **Unreachable**: A skill referenced ONLY by another retired skill and not used standalone.

## Decision rubric

For each candidate:

| Action | Use when |
|---|---|
| **leave-alone** | Foundation libraries (`_personas/`, `_council-scaffolding/`, `_graph-first/`) — never retire these. Or: candidate has been edited in the last 30 days (signal of active development). Or: explicitly listed as "required" in any `roster.yml`. |
| **deprecate** | Skill is still useful but superseded by a newer one. Add `deprecated: true` + `superseded_by: <name>` to frontmatter. Leave it in canon. Will be revisited next audit. |
| **archive** | Skill is unused / duplicate / orphan but might have referential value. Move the canon directory to `~/.claude/skills/_archive/<YYYY-MM-DD>-<skill-name>/`. Update map. Reversible. |
| **delete** | Only for orphaned canon entries with no real content — these are noise, not artifacts. Document each deletion. |

**Never hard-delete a skill that has real content on first pass.** Archive first. If after 2 archive cycles (~6 months) it hasn't been resurrected, the next audit can recommend hard deletion for human approval.

## Safety rails

- **Confirmation required before any archive or delete on skills listed as "required" in any `roster.yml` in `~/.claude/skills/*-council/`.** These are load-bearing.
- **Never modify `_personas/`, `_council-scaffolding/`, `_graph-first/`** — these are foundations, not skills.
- **Never touch plugin-installed skills** (those under `~/.claude/plugins/cache/` or namespaced like `oh-my-claudecode:*`, `data-engineering:*`, `figma:*`, etc.) — those are managed by their plugins.
- **Always update both copies of the skill map** (`~/.claude/SKILLS-MAP.md` and `~/Documents/Home/Personal Skills Map.md`) in sync, or update neither.
- **Always commit changes** to `~/dotdev/dotfiles/` (if it's a git repo) with a descriptive message: `chore(skills): archive <name> (reason: <reason>)`.
- **Dry-run by default** — if invoked without `--execute`, produce the report only, do not modify anything.

## Process

### 1. Inventory

```bash
# Enumerate live skills (~/.claude/skills is one symlink to ~/.config/agents/skills)
ls -la ~/.claude/skills/ > /tmp/skill-inventory.txt

# Enumerate actual files (canon)
find ~/dotdev/dotfiles/.config/agents/skills/ -name "SKILL.md" -mtime +90 > /tmp/stale-by-mtime.txt
find ~/dotdev/dotfiles/.config/agents/skills/ -name "SKILL.md" -mtime -30 > /tmp/recent-edits.txt

# Check the root symlink itself isn't broken (there is no per-skill symlink farm anymore)
[ -e ~/.claude/skills ] || echo "BROKEN: ~/.claude/skills -> $(readlink ~/.claude/skills)" > /tmp/broken-symlinks.txt

# Existing archive
ls ~/.claude/skills/_archive/ 2>/dev/null > /tmp/already-archived.txt
```

### 2. Usage analysis (90-day window)

For each skill, grep the last 90 days of session transcripts for invocations:

```bash
# Find session files from the last 90 days
find ~/.claude/projects/ -name "*.jsonl" -mtime -90 > /tmp/recent-sessions.txt

# For each skill, count mentions across recent sessions
for skill in $(ls ~/.claude/skills/); do
  count=$(xargs -a /tmp/recent-sessions.txt grep -c "\"name\": \"$skill\"" 2>/dev/null | awk '{s+=$1} END {print s+0}')
  echo "$count $skill"
done | sort -n > /tmp/usage-counts.txt
```

Skills with `count = 0` are usage-stale. Cross-reference with mtime-stale list to find true retirement candidates.

### 3. Duplicate detection

Read each `SKILL.md`'s frontmatter `description:` field. Compute pairwise semantic similarity (any reasonable approach — string overlap, embedding similarity, or LLM judgment). Flag pairs above 70% overlap.

For each flagged pair: which one is canonical?
- Listed in `~/.claude/SKILLS-MAP.md` wins
- More recent edits win
- More complete SKILL.md wins
- If tied, flag for human review

### 4. Build candidate list

| Skill | Reason flagged | Last invoked | Last edited | Proposed action |
|---|---|---|---|---|
| <name> | stale / duplicate / broken / orphan | <date or "never"> | <date> | leave-alone / deprecate / archive / delete |

### 5. Apply safety rails

Cross-check candidates against `roster.yml` files and the foundation-library list. Demote any false positives to `leave-alone`.

### 6. Execute (only if `--execute` flag passed)

For each candidate with proposed action ≠ `leave-alone`:

```bash
# Archive (canon is dotfiles/.config/agents/skills; ~/.claude/skills is a single
# symlink to ~/.config/agents/skills, so there is no per-skill symlink to separately rm —
# moving it out of canon removes it from the active root too)
mv ~/dotdev/dotfiles/.config/agents/skills/<name>/ ~/.claude/skills/_archive/$(date +%Y-%m-%d)-<name>/

# Deprecate (frontmatter edit)
# Add to SKILL.md frontmatter:
#   deprecated: true
#   superseded_by: <other-skill>

# Delete (orphaned/empty directory only — no separate symlink step)
rm -rf ~/dotdev/dotfiles/.config/agents/skills/<name>/
```

### 7. Update the map

Edit `~/.claude/SKILLS-MAP.md`:
- Remove archived/deleted skills from the "When you want to..." tables
- Remove from "Trigger phrases"
- Remove from "Persona library" if it's a persona
- Remove from "Pipelines" if referenced
- Add a "## Recently retired" section at the bottom (or update the existing one) with one line per retirement: `<date>: <name> — archived (reason: <reason>)`

Copy the updated map to `~/Documents/Home/Personal Skills Map.md`.

### 8. Commit

```bash
cd ~/dotdev/dotfiles
git add .config/agents/skills/
git commit -m "chore(skills): retirement audit $(date +%Y-%m-%d) — N archived, M deprecated"
```

### 9. Report

Output a markdown summary:

```markdown
# Skill Retirement Audit — <date>

## Summary
- Total skills inventoried: <N>
- Candidates flagged: <M>
- Archived: <A>
- Deprecated: <D>
- Deleted (broken symlinks): <X>
- Left alone (safety rail): <Y>
- Flagged for human review: <Z>

## Archived
| Skill | Reason | Restored from |
|---|---|---|
| <name> | <reason> | `~/.claude/skills/_archive/<date>-<name>/` |

## Deprecated (still discoverable, marked stale)
| Skill | Superseded by |
|---|---|
| <name> | <other> |

## Flagged for human review
- <name>: <reason> — recommend <action> but <safety rail / ambiguity> requires Alex's call

## Map sync
- ✓ `~/.claude/SKILLS-MAP.md` updated
- ✓ `~/Documents/Home/Personal Skills Map.md` updated
- ✓ Git committed: <sha>

## Next audit recommended: <date + 90 days>
```

## Invocation modes

- **Dry-run (default)**: `Run the audit. Report only. Do not modify anything.`
- **Execute**: `Run the audit with --execute. Apply changes per the rubric. Commit.`
- **Aggressive**: `Run the audit with --execute --aggressive. Lower the staleness threshold to 60 days and treat ambiguous duplicates as archive candidates.` (Use sparingly.)
- **Resurrect**: `Restore skill <name> from _archive/. Move back, recreate symlink, restore in SKILLS-MAP.md.`

## Cadence

Recommended quarterly (every 90 days). Can be scheduled via Claude Code's `/schedule` skill or invoked manually when Alex notices the skill tree feels cluttered.

## Notes for CORA

- This task involves filesystem mutation outside CWD. If sandbox restrictions block any operation, use `dangerouslyDisableSandbox: true` after explaining the specific operation.
- The skill map is the source of truth for "what should exist." When in tension between the map and the on-disk reality, prefer the map's intent but flag the discrepancy in the report.
- `~/.claude/skills` is a single symlink to `~/.config/agents/skills`, so any skill directory present in canon is automatically discoverable — there's no per-skill linking step left to go stale. If you discover a skill that exists in canon but the symlink itself is broken or missing, that's a host-setup problem (flag it), not a per-skill issue.
- Foundation libraries (`_personas/`, `_council-scaffolding/`, `_graph-first/`) are never candidates for retirement. They can have individual personas / patterns within them deprecated, but the libraries themselves stay.
- After the audit, recommend Alex run `analysis-council --fast "is the skill tree still well-shaped after this retirement audit?"` if more than 5 skills were retired in one pass — sanity check that the system still composes.
