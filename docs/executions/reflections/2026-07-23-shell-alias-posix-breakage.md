# Session Reflection: Stale git lock + non-POSIX shell aliases

**Date**: 2026-07-23
**Goal**: Unblock `git` (stale `index.lock`), then fix the root cause of flooded/garbled command output (`grep`/`find` aliased to `rg`/`fd`).

## What Went Well
- Stale-lock call was evidence-gated, not reflexive: checked lock mtime (0 bytes, 32 min old) + `pgrep` for mutating git procs before `rm`. The only live git procs were GitLens read-only `git diff --numstat` + MCP servers — none hold `index.lock`.
- Traced the output-flood symptom to its cause instead of working around it: `ps ... | grep -E` was returning file paths → `grep` was recursive → aliased to `rg`.
- Ground-truth check before declaring the fix durable: confirmed `~/.config/zsh` is a Stow dir symlink → `~/dotdev/dotfiles/.config/zsh`, so the alias edit wrote through to the **canonical tracked source**, not a runtime mirror.

## What Went Wrong / Friction
- Two of my own diagnostic commands were wasted: the tool bash shell inherited interactive aliases (`grep=rg`, `find=fd`), so `ps | grep -E ...` flooded with a repo-wide `rg` scan and a `for … do … done` loop errored under the shell wrapper.
- Recovered by falling back to absolute binaries (`/usr/bin/grep`, `/bin/cat`, `/usr/bin/find`) and `command git` — reliable, but only after burning calls discovering the aliases were active.

## Corrections
None. User never redirected; session was smooth. (Pass B still run per skill.)

## Lessons
1. **Agent shells can inherit non-POSIX coreutil aliases**: `grep→rg`, `find→fd`, `cat→bat` etc. break flag-compat (`-E`/`-A`/`-name`/`-maxdepth`) and pipe/stdin behavior. When output looks wrong (recursive results, file paths from a pipe), suspect an alias before debugging the command.
2. **Absolute binary paths + `command <x>` bypass aliases/functions** — the robust default for agent diagnostics that must behave POSIX.
3. **Verify a config edit hits canonical source, not a mirror**, before calling it durable. A Stow symlink means the edit is tracked; a plain file may be runtime-only.

## Proposed Improvements
- [ ] Commit the dotfiles fix from `~/dotdev`: `dotfiles/.config/zsh/configs/aliases.zsh` (removed `grep=rg`/`find=fd`, added `g`/`f`). Currently uncommitted. (priority: high — user action)
- [ ] `docs/agents/habits.md` — add one line: in non-interactive/agent shells, prefer `command <bin>` or absolute paths for `grep`/`find`/`cat`; do not assume POSIX flags survive user aliases. (priority: low — behavior guard; root cause already removed for this machine)

<!-- No Skill Extraction Candidates: both the stale-lock recovery and the alias fix are 5-min-googleable → fail the quality gate. -->
