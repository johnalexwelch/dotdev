# Plan: Agent-Agnostic Agent Config + Repo Enhancements

**Date:** 2026-07-15
**Scope:** De-`.claude` the shared agent config, wire multi-agent (claude/codex/pi) to one source, fix drift, and clear the small repo-hygiene backlog surfaced during review.

## Problem

- `.claude/` conflates two concerns: **agnostic content** (93 skills, docs — plain markdown every agent reads) and **Claude-specific** content (settings, hooks, commands).
- Skills are copied per-agent. `~/.codex/skills/` is a separate real copy and has **already drifted** (`brain-ops/SKILL.md` differs from `.claude`). pi reads `~/.claude/skills` directly (good), codex does not (bad).
- The name `.claude` misleads: pi + codex consume it too. Future hooks/commands will be genuinely per-agent, so the boundary needs to be explicit, not accidental.
- Side findings during review: README structure drift, a dangling/untracked `zoxide-workspace.sh` symlink, non-uniform setup-script invariants.

## Design principle

One test per file: **"does another agent read this verbatim?"**

- Yes → agnostic → `~/.config/agents/` (neutral, XDG).
- No (per-tool schema) → stays in that agent's own dir.

Shared = `skills/`, `docs/`. Per-agent = `settings`, `hooks`, `commands`/`prompts`.

## Target layout

```
dotfiles/
├── .config/agents/          # NEUTRAL shared source → ~/.config/agents/
│   ├── skills/              # single skills source (was .claude/skills)
│   └── docs/                # shared reference (was .claude/docs)
├── .claude/
│   ├── skills → ../.config/agents/skills
│   ├── settings.json  hooks/  commands/     # Claude-specific
├── .codex/
│   ├── skills → ../.config/agents/skills
│   └── prompts/
└── .pi/agent/
    ├── skills → ../../.config/agents/skills
    ├── settings.json                        # already tracked
    └── prompts/
```

---

## Phase 1 — Reconcile drift — DISSOLVED (finding, 2026-07-15)

**The premise was wrong.** Codex's divergence is **by design**, not drift:

- `dotfiles/.claude/skills/sync-codex-skills.sh` already syncs source → codex runtime
  with **compatibility filtering**: skips skills whose frontmatter has
  `codex-compatible: false` (6 skills), and preserves a codex runtime allowlist
  (`codex-runtime-allowlist.txt`, 6 codex-only skills).
- The sync is **tested** (`test/test-sync-codex-skills.sh`, run by `test/run-tests.sh`).
- The SKILL.md diffs seen during review (`brain-ops`, `cleanup-delivery`, …) were
  **worktree-vs-main branch noise** (`~/.claude/skills` → `~/dotdev` main checkout;
  work happens in a worktree), not accidental fork loss.

**Consequence for Phase 2:** codex must stay a **filtered copy** (keep the sync
script). The original "symlink codex → shared source" step is REMOVED — it would
bypass compatibility filtering and drag in incompatible skills. No manual
reconciliation needed.

## Phase 2 — Hoist skills to neutral source (revised) — DONE (ad2f538)

- [x] `git mv dotfiles/.claude/skills dotfiles/.config/agents/skills` (helper scripts
      `sync-codex-skills.sh` + `lint-skill-suite.sh` + `codex-runtime-allowlist.txt`
      move WITH it — they self-locate via their own dirname).
- [x] `git mv dotfiles/.claude/docs   dotfiles/.config/agents/docs`
- [x] Committed compat symlinks so existing consumers keep resolving:
      - `dotfiles/.claude/skills → ../.config/agents/skills`  (claude stow + pi read via `~/.claude/skills`)
      - `dotfiles/.claude/docs   → ../.config/agents/docs`
- [x] **Codex: NO symlink.** Keep `sync-codex-skills.sh` (filtered copy). Only its
      source path changes — self-locates from new dir, no edit needed.
- [x] Update hardcoded paths: `test/test-sync-codex-skills.sh`,
      `test/test-skill-suite-lint.sh` (SCRIPT=…), `.gitignore` runtime paths
      (`.omc/`, `.skill-observations/`), `install.sh` mkdir.
- [x] `install.sh`: drop `mkdir ~/.claude/skills` (now a symlink — mkdir would
      block stow), add `mkdir -p ~/.config/agents`.
- [x] Update docs referencing the old path (AI_ENVIRONMENT.md, SETUP_WRITEUP.md).

## Phase 3 — Per-agent overlays (structure only, no unification) — DONE (verify-only, no code change)

Finding: structure already correct. Shared → `.config/agents/{skills,docs}`; claude-specific →
`.claude/{hooks/workflow-guard.sh, settings.json, settings.local.template.json}`; pi-specific →
`.pi/agent/settings.json`; codex → runtime-synced filtered copy (no tracked config). No `commands/`
or `prompts/` authored anywhere → per YAGNI, nothing scaffolded.

- [x] Confirm `.claude/settings.json`, `hooks/`, `commands/` stay in `dotfiles/.claude/`.
- [x] Create `dotfiles/.codex/prompts/` and `dotfiles/.pi/agent/prompts/` only if/when real content exists (YAGNI — none exists, none created).
- [x] NO shared hooks/commands abstraction — formats diverge per tool.

## Phase 4 — Fix `zoxide-workspace.sh` gap — DONE (non-issue on integration)

Finding: the "gap" was a worktree-behind-main artifact. The file was already committed on main
(`0737026`); the refactor branch simply predated it. Merging the branch into main preserved it, and
it is now live-verified at `~/.config/herdr/zoxide-workspace.sh` after re-stow. No file to add.

- [x] Locate the real file (main checkout) — already tracked on main; no `git add` needed.
- [x] `DRY_RUN=1 ./install.sh` clean; live stow recreates `~/.config/herdr/zoxide-workspace.sh`.

## Phase 5 — README drift — DONE (a78f86a)

- [x] Regenerate the `## Structure` tree from the real layout (shows `.config/agents` shared source + per-agent dirs).
- [x] Update Core Components table (Warp → Ghostty).

## Phase 6 — install.sh / setup-script hygiene — DONE (6f41c22)

- [x] Application Support `ln -sf` steps already idempotent via `-sf` (verified no stacking).
- [x] Apply the `herdr-setup.sh` invariant-header pattern to `ai/brew/github/herdr-setup.sh`; `gh-extensions.sh` already had one. Added `agents/`+`herdr/` to `config-init.sh` pre-created dirs.
- [x] Softened final message to "restart is recommended".

---

## Verification (per phase)

- After Phase 2: `DRY_RUN=1 stow -d "$DOTFILES" -nv -R -t "$HOME" dotfiles` → zero conflicts.
- After Phase 2: `readlink ~/.claude/skills ~/.codex/skills ~/.pi/agent/skills` all resolve to `~/.config/agents/skills`.
- Cross-agent parity: `diff -r ~/.claude/skills ~/.codex/skills` → identical (same target).
- Full dry run: `DRY_RUN=1 ./install.sh` clean.
- `./test/run-tests.sh` passes.

## Explicitly out of scope (YAGNI)

- Neutral **settings** layer — schemas (`CLAUDE_CODE_*`, opencode JSON, pi) never converge; unifying = fighting the tools.
- Shared hooks/commands bodies — add only when two agents share an identical body verbatim.
- Migrating off GNU Stow (nix/chezmoi) — Stow works; migrate only for multi-machine reproducibility guarantees.

## Rollback

Each phase is a separate commit. `git revert` the phase commit; re-run `./install.sh`. Skills hoist is a `git mv` + symlinks — reversible by moving back and deleting links.
