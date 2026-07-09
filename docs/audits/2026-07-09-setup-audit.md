# dotdev Setup Audit — 2026-07-09

Continuation of `2026-07-02-repo-audit.md` (which ran FIND-01…FIND-08). Findings here are FIND-09 onward. Produced by a six-specialist parallel audit of the whole dotdev setup (skills, hooks, scripts, credentials, docs, multi-harness wiring, pi packages). This doc is the intended **fog** for a `/wayfinder` charting session — destination TBD with the user.

## Overall state

The installed sets are healthier than the docs claim, but there is real breakage in the macOS install path, one genuine secret exposure in history, systematic doc drift, and several dangling/uncaptured tools. Nothing here is yet fixed unless noted.

## Findings summary

| ID | Severity | Area | Title |
|----|----------|------|-------|
| FIND-09 | **high** | security | SSH private key committed then deleted without history rewrite (still extractable) |
| FIND-10 | medium | security | pre-commit / git-secrets configured but never installed locally (CI is the only backstop) |
| FIND-11 | **high** | scripts | `scripts/macos/terminal.sh` crashes every run — `DOTFILES` required but never exported by `install.sh` |
| FIND-12 | medium | scripts | `terminal.sh` stow targets nonexistent `~/dotdev/.config` (real path is `dotfiles/.config`) |
| FIND-13 | medium | scripts/docs | `terminal.sh` installs oh-my-zsh; `SETUP_WRITEUP.md §12` says it was removed — script and doc disagree |
| FIND-14 | low | scripts | macOS scripts run twice per install (`defaults.sh` sources them, `install.sh` re-invokes) |
| FIND-15 | medium | scripts | `scripts/macos/general.sh` (undocumented) renames any machine to `awelch` via `sudo scutil` |
| FIND-16 | medium | scripts | guardian clone uses `github-personal` SSH host alias that `github.sh` never creates — fresh-machine failure |
| FIND-17 | medium | scripts | `github.sh` re-adds SSH key to GitHub on every re-run — breaks "safe to re-run" |
| FIND-18 | low | scripts | Brewfile `go`/`cargo`/`uv`/`npm` stanzas are not native Bundle DSL — may fail to parse (dry-run to confirm) |
| FIND-19 | medium | portability | `dotfiles/.config/mcp/mcp.json` hardcodes `/Users/alexwelch/.local/bin/github-mcp-pi` (stowed as-is) |
| FIND-20 | medium | docs | `AI_ENVIRONMENT.md` / `SETUP_WRITEUP.md` disagree with each other and reality on ~10 facts (skill count, pi package count+contents, default model, plugin list, hooks dir, Brewfile count, phantom `better-messages-cache`) |
| FIND-21 | low | routing | "workflow-router is the sole entry point" is false — 13 internal skills lack `disable-model-invocation` |
| FIND-22 | medium | tooling | `cursor` assumed by alias + `.config/cursor` + docs, but Brewfile installs `visual-studio-code`, not cursor |
| FIND-23 | low | tooling | `hunk` (moving lazygit→hunk for diffing) not captured anywhere; needs Brewfile + gitconfig difftool wiring |
| FIND-24 | low | tooling | `trino` CLI missing though `~/.trino` creds exist; `opencode` referenced by herdr but not installed |
| FIND-25 | medium | mcp | `mcp.json` has one broken server (hardcoded/uninstalled `github-mcp-pi`); the real MCP fleet (Slack/Asana/Notion/Google/Datadog/dbt) is uncaptured |
| FIND-26 | low | pi | Context-stack overlap: 6 packages, 2 redundant pairs — `headroom`↔`hypa` (both compress tool output), `cache-optimizer`↔`pix-optimizer`; deconflict, don't add |
| FIND-27 | medium | multi-harness | Codex + opencode have zero skill wiring; `.claude/skills/{herdr,find-skills}`→`.agents/skills` symlink precedent exists to universalize from |
| FIND-28 | low | nvim | Extensive old nvim config lives in `johnalexwelch/dotfiles` (chezmoi, `master`, `dot_config/nvim/lua/awelch/*`, ~45 plugins); current tracked nvim is a stock LazyVim starter |
| FIND-29 | medium | ci | `Lint` job fails on **every** PR (and `main`): `detect-secrets` reports false-positive "Hex High Entropy String" on `dotfiles/.config/nvim/lazy-lock.json:12–42` (git SHAs in a lock file). Fix by regenerating `.secrets.baseline` or excluding the lock file — blocks green CI repo-wide. |

## Notes on the higher-severity items

**FIND-09** — key added in `449613f`, removed in `3d0a778` (delete only, no rewrite). Extractable via `git show 449613f:dotfiles/config/ollama/id_ed25519`. Rotate/revoke regardless; history rewrite (filter-repo/BFG) is a separate destructive decision (breaks existing clones).

**FIND-11–13** — the macOS install path is effectively broken today: `terminal.sh` aborts on the unset var, and even fixed, its stow call targets a path that doesn't exist. Fix: export `DOTFILES` from `install.sh`, correct the stow path to `dotfiles/.config`, and reconcile the oh-my-zsh contradiction (doc says removed; script installs it).

**FIND-20** — same failure mode repeated ~10×: numbers/lists copy-pasted into two narrative docs, then one changes. Recommendation: hybrid — one canonical page per fact under `docs/wiki/`, both writeups link instead of restating; **generate** the pi-package and skill lists from source (settings.json / frontmatter) rather than hand-maintaining. Do NOT fold into `brain-ops` (personal vault, separate concern).

**FIND-25** — Tier-1 MCP adds (highest fit): dbt MCP (semantic layer/lineage — pairs with metric-tree/lineage skills, no collision with work dbt), a warehouse query MCP (Redshift/Trino — creds exist), Datadog MCP (feeds incident skills). Tier-2: Notion/Slack/Asana/Google. Needs user endpoints/creds to wire.

**FIND-28** — recommended path is **not** wholesale restore. It's a navigation-first rebuild on modern foundations (native `vim.lsp`, blink.cmp or nvim-cmp, which-key v3, treesitter `main`), dropping `lazygit.nvim` (moving to hunk), salvaging `core/keymaps.lua` + `core/options.lua` verbatim, and wiring hunk as a git difftool. User is moving to nvim for docs-reading + codebase navigation; the diff workflow is leaving nvim for hunk.

## Deliberate exclusions (do NOT re-flag in future audits)

- **dbt is intentionally absent from the Brewfile** — installed via a separate work process; adding it here would collide.
- **`setup-skills` Section C (CONTEXT.md / domain docs) intentionally skipped for dotdev** — a dotfiles repo has no DDD domain to model; forcing CONTEXT.md would be a category error. The de-facto domain lives in `AI_ENVIRONMENT.md` / `SETUP_WRITEUP.md` / `docs/decision-log.md`.

## Decisions made this session (context for the next)

- **wayfinder** installed as top-of-funnel, explicit-invoke only; decisions mirror to `decision-log`; cleared route hands off per-effort (to-prd / design-plan / decision). Map is never `ready-for-agent`.
- **Skill layout stays flat** — the only cross-harness-safe option (pi recursive, Claude Code one-level, Codex own root; SKILL.md is a vendor-neutral standard).
- **PR #67** (draft) reconciled skill-pack drift vs mattpocock/skills and added `git-guardrails` + `spec-review`; this session added wayfinder to the same branch/PR.
- **`docs/agents/issue-tracker.md` created** (GitHub tracker + triage labels + Wayfinding operations) — partial `setup-skills` for dotdev (Sections A+B; C excluded per above).

## Already partly actioned

- `docs/agents/issue-tracker.md` — created this session.
- `git-guardrails` skill — added (PR #67); note its blocklist overlaps the hard-denied `git push --force` in `settings.json` and does nothing for pi (`pi-dirty-repo-guard`/`pi-permission-gate` cover pi — enforcement semantics unverified).
