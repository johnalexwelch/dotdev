# Agent Habits

Recurring correction patterns across sessions — check these before diving in.

This file is the **durable source of truth** for agent habits. OpenWiki may regenerate `AGENTS.md` / `CLAUDE.md`; those stubs only point here. Edit this file when a session teaches a new durable habit.

- **Ground truth over speculation.** Before hunting for how something is configured/installed (a plugin, a marketplace, a mechanism), check what's already visible in context (system prompt's skill/package list, settings.json) before searching the filesystem for it.
- **Scope filesystem searches.** Always pass `path`/`maxdepth` (or the `find`/`grep` tool's `path` param) — don't run repo- or filesystem-wide unscoped searches as a first move.
- **Check newly-wired capabilities before falling back to manual work** for an adjacent task — if a skill, tool, or generator was just set up, use it rather than reinventing the adjacent step by hand.
- **Treat live-checkout runs of mutating/regenerating third-party tools** (doc generators, codegen, scaffolders) like destructive git ops: dry-run in an isolated copy, or diff immediately after — never assume success.
- **After bulk path/string rewrites, do a semantic sanity pass** — string replacement can leave sentences that still parse but no longer mean the intended thing; spot-check wording before calling the migration done.
- **Don't assume POSIX coreutils in agent/non-interactive shells.** `grep`/`find`/`cat` may be shadowed by ripgrep/fd/bat as aliases OR shell functions — not just flag-incompatible (`-E`/`-A`/`-name`/`-maxdepth`), a shadowed `grep` can silently ignore piped stdin (`cmd | grep x` returns nothing, no error). Use `command <bin>` or absolute paths (`/usr/bin/grep`) for anything that must behave POSIX. Note: the ClassDojo dotfiles already removed the `grep=rg`/`find=fd` aliases (verified clean 2026-07-24) — residual breakage is typically the *harness's* captured shell snapshot still defining `function grep`, which agents can't fix; treat this as defensive coding, not a dotfiles bug to chase.
- **Before any git write (commit/push), verify git env + identity.** Unset or check `GIT_DIR`, `GIT_INDEX_FILE`, `GIT_WORK_TREE`, `GIT_COMMON_DIR`, then confirm `git rev-parse --show-toplevel` and the commit author identity — stale `GIT_*` env vars from a prior session/worktree can silently point commands at the wrong repo. One session nearly committed as the wrong author this way.
- **`gh` command that worked minutes ago suddenly fails on the same repo** with "Could not resolve to a Repository" or not-found → suspect an auth-account flip first, not a repo/permissions problem. Run `gh auth status`, then `gh auth switch --user <correct>` before digging further.
