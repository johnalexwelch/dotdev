# Agent Habits

Recurring correction patterns across sessions — check these before diving in.

This file is the **durable source of truth** for agent habits. OpenWiki may regenerate `AGENTS.md` / `CLAUDE.md`; those stubs only point here. Edit this file when a session teaches a new durable habit.

- **Ground truth over speculation.** Before hunting for how something is configured/installed (a plugin, a marketplace, a mechanism), check what's already visible in context (system prompt's skill/package list, settings.json) before searching the filesystem for it.
- **Scope filesystem searches.** Always pass `path`/`maxdepth` (or the `find`/`grep` tool's `path` param) — don't run repo- or filesystem-wide unscoped searches as a first move.
- **Check newly-wired capabilities before falling back to manual work** for an adjacent task — if a skill, tool, or generator was just set up, use it rather than reinventing the adjacent step by hand.
- **Treat live-checkout runs of mutating/regenerating third-party tools** (doc generators, codegen, scaffolders) like destructive git ops: dry-run in an isolated copy, or diff immediately after — never assume success.
- **After bulk path/string rewrites, do a semantic sanity pass** — string replacement can leave sentences that still parse but no longer mean the intended thing; spot-check wording before calling the migration done.
- **Close the loop with real execution output.** Every claim about behavior is backed by a command you actually ran and its pasted output — "I ran X → output Y", never "this should work." Post-edit, run the check/build/test and report the actual result, not the intended one.
- **Label claims by evidence tier.** Distinguish **verified** (ran or read it), **inferred** (deduced from evidence), and **assumed** (no evidence yet). Say "unsure" when unsure — an accurate "I don't know" beats a confident wrong answer. No evidence → cap confidence, don't upgrade a guess to a fact.
- **Read before you describe.** Don't characterize code you haven't opened this session — use `module_report`/`read_symbol`/`read` first. This is the accuracy analog of read-before-edit: cheap grounding, no hallucinated APIs.
- **Compress prose, never compress evidence.** Terse/caveman/ponytail modes strip explanation, hedging, and filler — they must NOT strip the evidence trail. File:line references, command output, and exact error strings stay verbatim; brevity that removes verifiability is a regression.
- **Don't assume POSIX coreutils in agent/non-interactive shells.** User rc may alias `grep`→`rg`, `find`→`fd`, `cat`→`bat` etc., which are NOT flag-compatible (`-E`/`-A`/`-name`/`-maxdepth`, stdin/pipe behavior differ). When output looks wrong (recursive results, file paths from a pipe), suspect an alias; use `command <bin>` or absolute paths (`/usr/bin/grep`) for diagnostics that must behave POSIX.
