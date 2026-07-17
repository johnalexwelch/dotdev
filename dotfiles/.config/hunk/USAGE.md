# Hunk

Terminal diff review UI (Bun/OpenTUI). Replaces reading raw `git diff` for
anything non-trivial: multi-file review stream, sidebar, inline AI/agent
notes, split/stack layout. Not a structural/semantic diff tool (no AST diffing
— see `difftastic` if you need that).

## Our setup

- Default git pager stays **delta** (`~/.gitconfig` → `pager = delta`).
  Hunk is **opt-in**, not the pager, via aliases:

  ```bash
  git hdiff   # git diff  through hunk pager
  git hshow   # git show  through hunk pager
  ```

- Direct commands (preferred over the aliases for real reviews — full TUI,
  not pager mode):

  ```bash
  hunk diff              # working tree, includes untracked files
  hunk diff --watch       # auto-reload as files change
  hunk show               # last commit
  hunk show HEAD~1        # older commit / any ref
  ```

- Config: `~/.config/hunk/config.toml` (this dir). Repo-local override:
  `.hunk/config.toml` in any project takes precedence over the global one.
- `vcs = "git"` pinned explicitly — most of our work is git, and pinning
  skips hunk's jj/Sapling auto-detect probe on every invocation.
- `exclude_untracked = true` — hunk's working-tree loader shows untracked
  files by default (`hunk diff` = `git status` minus the noise git already
  filters via `.gitignore`, i.e. it does NOT show ignored files — if ignored
  files show up as untracked, they're probably already tracked in git from
  before the `.gitignore` rule existed; check with `git status --ignored`
  and `git rm --cached <file>` if so). We turned this off anyway to keep
  review sessions to intentional changes only. Per-session override:
  `hunk diff --exclude-untracked` / `--no-exclude-untracked`, or
  `hunk session reload --repo . -- diff --exclude-untracked` on a live
  session.

Current `config.toml`:

```toml
theme = "auto"
mode = "auto"
vcs = "git"
line_numbers = true
wrap_lines = false
menu_bar = true
agent_notes = true
exclude_untracked = true
```

## Commands

| Command | Use |
| --- | --- |
| `hunk diff [target] [-- pathspec]` | working tree vs target (or HEAD) |
| `hunk diff --staged` / `--cached` | staged changes only |
| `hunk diff <left> <right>` | compare two concrete files |
| `hunk show [ref]` | review a commit |
| `hunk stash show [ref]` | review a stash entry (git only) |
| `hunk patch [file]` | review a patch file, or `git diff \| hunk patch -` |
| `hunk pager` | pager-mode wrapper (what `git hdiff`/`git hshow` use) |
| `hunk difftool <left> <right> [path]` | `git difftool` backend |
| `hunk session <subcommand>` | control a *live* hunk window from the CLI |
| `hunk daemon serve` | local session daemon (auto-starts; rarely called by hand) |

Useful flags on any review command: `--mode split|stack|auto`,
`--no-line-numbers`, `--wrap`, `--no-hunk-headers`, `--no-agent-notes`,
`--theme <id>`.

## Agents driving a live Hunk session

Agents must **not** launch `hunk diff`/`hunk show` themselves — those are
interactive TUI, meant for the human's terminal. Instead they talk to an
already-open session over the local daemon:

```bash
hunk session list                              # find live sessions
hunk session get --repo .                      # confirm repo/path
hunk session review --repo . --json            # inspect structure (cheap)
hunk session navigate --repo . --file <f> --hunk <n>
hunk session comment add --repo . --file <f> --new-line <n> --summary "..."
```

Full protocol lives in the bundled skill — load it, don't reinvent it:

```bash
hunk skill path   # -> .../libexec/skills/hunk-review/SKILL.md
```

Prompt an agent with: *"Load the Hunk skill and use it for this review. Run
`hunk skill path` to get the skill path."*

## Themes

`theme = "auto"` reads the terminal background and picks
`github-light-default` / `github-dark-default`. Press `t` in-app for the
picker. Custom themes go in `[custom_theme]` — see the [README config
section](https://github.com/modem-dev/hunk#config) if we ever need one.

## Gotchas

- `hunk pager` (i.e. plain `git diff`/`git show` through it) never shows
  untracked files — Git decides pager content, not hunk. Only `hunk diff`'s
  own working-tree loader includes untracked files.
- jj/Sapling auto-detection is off here (`vcs = "git"`). Remove that line if
  a repo under this machine starts using jj/sl.
