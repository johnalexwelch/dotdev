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

## Phase 2 — Hoist skills to neutral source (revised)

- [ ] `git mv dotfiles/.claude/skills dotfiles/.config/agents/skills` (helper scripts
      `sync-codex-skills.sh` + `lint-skill-suite.sh` + `codex-runtime-allowlist.txt`
      move WITH it — they self-locate via their own dirname).
- [ ] `git mv dotfiles/.claude/docs   dotfiles/.config/agents/docs`
- [ ] Committed compat symlinks so existing consumers keep resolving:
      - `dotfiles/.claude/skills → ../.config/agents/skills`  (claude stow + pi read via `~/.claude/skills`)
      - `dotfiles/.claude/docs   → ../.config/agents/docs`
- [ ] **Codex: NO symlink.** Keep `sync-codex-skills.sh` (filtered copy). Only its
      source path changes — self-locates from new dir, no edit needed.
- [ ] Update hardcoded paths: `test/test-sync-codex-skills.sh`,
      `test/test-skill-suite-lint.sh` (SCRIPT=…), `.gitignore` runtime paths
      (`.omc/`, `.skill-observations/`), `install.sh` mkdir.
- [ ] `install.sh`: drop `mkdir ~/.claude/skills` (now a symlink — mkdir would
      block stow), add `mkdir -p ~/.config/agents`.
- [ ] Update docs referencing the old path (AI_ENVIRONMENT.md, SETUP_WRITEUP.md).

## Phase 3 — Per-agent overlays (structure only, no unification)

- [ ] Confirm `.claude/settings.json`, `hooks/`, `commands/` stay in `dotfiles/.claude/`.
- [ ] Create `dotfiles/.codex/prompts/` and `dotfiles/.pi/agent/prompts/` only if/when real content exists (YAGNI — don't scaffold empty dirs).
- [ ] NO shared hooks/commands abstraction — formats diverge per tool.

## Phase 4 — Fix `zoxide-workspace.sh` gap

`~/.config/herdr/zoxide-workspace.sh` symlinks into dotdev but the file isn't committed → fresh install breaks.

- [ ] Locate the real file (main checkout) and `git add dotfiles/.config/herdr/zoxide-workspace.sh`, or delete the dangling link if obsolete.
- [ ] `DRY_RUN=1 ./install.sh` to confirm stow recreates it.

## Phase 5 — README drift

Structure block lists dirs that no longer exist (`arc/ cursor/ ghostty/ git/ …`) and mentions Warp (you use Ghostty).

- [ ] Regenerate the `## Structure` tree from the real layout (or drop the tree, link to this doc).
- [ ] Update Core Components table to match actual tools.

## Phase 6 — install.sh / setup-script hygiene (low priority)

- [ ] Make Application Support `ln -sf` steps idempotent-safe (already mostly are via `-sf`; verify no stacking).
- [ ] Apply the `herdr-setup.sh` pattern uniformly: each `*-setup.sh` states its invariant (idempotent? needs server? needs network?) in a header comment.
- [ ] Consider softening the final "restart your computer" to "restart recommended".

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
