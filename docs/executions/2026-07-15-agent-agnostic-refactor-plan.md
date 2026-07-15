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

## Phase 1 — Reconcile drift (do FIRST, before collapsing sources)

Losing a diverged fork silently is the only real risk here.

- [ ] Diff every skill that exists in both `~/.claude/skills` and `~/.codex/skills`:
      `for d in ~/.codex/skills/*/; do n=$(basename "$d"); diff -q ~/.claude/skills/$n/SKILL.md "$d/SKILL.md" 2>/dev/null; done`
- [ ] For each difference, pick the correct version (manual review). Known: `brain-ops`.
- [ ] Record decisions in `docs/decision-log.md`.

## Phase 2 — Hoist skills to neutral source

- [ ] `git mv dotfiles/.claude/skills dotfiles/.config/agents/skills`
- [ ] `git mv dotfiles/.claude/docs   dotfiles/.config/agents/docs`
- [ ] Add committed symlinks (stow recreates them at each home):
      - `dotfiles/.claude/skills   → ../.config/agents/skills`
      - `dotfiles/.codex/skills    → ../.config/agents/skills`
      - `dotfiles/.pi/agent/skills → ../../.config/agents/skills`  (only if pi should read the shared set; today it reads `.claude/skills` — point it at the neutral dir instead)
- [ ] `install.sh`: add `mkdir -p "$HOME/.config/agents"` before stow so items link, not tree-fold.
- [ ] Remove the codex real-copy: `rm -rf ~/.codex/skills` prior to re-stow (one-time, document in install notes).

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
