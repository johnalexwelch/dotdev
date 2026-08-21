# Handoff — Implement external-snapshot mode

Exit: manual (user-invoked)
exit_reason: handoff-to-next-session
Target: claude
Generated: 2026-08-20

## Start here (resuming agent)

> You are starting new work in `dotdev`. The kernel is complete and verified (PR #195 merged). The task is implementing **external-snapshot mode** — D-006's five requirements for multi-repo adoption.
>
> 0. **Work happens in `/Users/alexwelch/dotdev`** (primary checkout, on `main`). Pushing needs the `github-personal` SSH host; `gh` routes by origin via `~/.local/bin/gh`.
> 1. Read the decision log entry **D-006 multi-repo adoption** (`dotfiles/.config/agents/skills/_docs/decision-log.md`) — it specifies exactly what to build.
> 2. Route through `workflow-router` first, then cut a worktree with an **absolute** `--path`.
> 3. This is `kind=feature` — the five requirements are implementation, not bug fixes.

## What this is

**External-snapshot mode** allows the D-006 enforcement kernel to run in work repos (`taro`, `ml-models`, `chorus`, etc.) without writing any ledger artifacts into those repos. Live state stays in `.git/ledger/state.yaml` (per-worktree, already works). Snapshots commit to **dotdev** at `docs/executions/external/<repo-name>/<run_id>.yaml` instead of the work repo.

This keeps work repos pristine (no merge conflicts on `state.yaml`, no audit trail pollution) while preserving the durable, reviewable snapshot trail in the repo that owns the D-006 system.

## The five requirements (from D-006 decision log)

All five must ship together — partial implementation leaves the system in an inconsistent state.

### R1: Snapshot root indirection in the kernel

**Where:** `ledger.sh` — `set_snapshot_rel` (`:105-106`), `stamp` commit logic (`:667-669`)

**What:** External-root mode needs the write target and the `git -C` target to be the dotdev checkout while `$TOP` stays the work repo. Currently `set_snapshot_rel` resolves the snapshot under the *current* repo's `$TOP`, and `stamp` commits it there.

**Shape:** Env var or flag (`LEDGER_EXTERNAL_ROOT=/path/to/dotdev`) that redirects snapshot writes. When set, `$SNAPSHOT_REL` becomes `docs/executions/external/<repo-name>/<run_id>.yaml` and `git -C` targets the external root.

**Simplification:** Freshness gets simpler — with no snapshot commits in the work repo, the content-verified snapshot-only exemption in `fresh_since` has nothing to exempt.

### R2: Repo allowlist as the sole opt-in signal

**Where:** New file `docs/executions/external/repos.txt` (one path/slug per line); `workflow-guard.sh` opt-in check

**What:** Directory presence (`docs/executions/` existing) cannot be the opt-in signal. `handoff/SKILL.md:17,63,81` writes handoffs to that path in *every* repo, recreating the stale opt-in. The allowlist becomes the only signal.

**Shape:**

```
# repos.txt — one absolute path or remote slug per line
/Users/alexwelch/projects/taro
/Users/alexwelch/projects/ml-models
# ...
```

**Critical:** Directory presence must stop being consulted entirely — leaving it as a fallback re-arms the trap.

### R3: Guard regex extension for external paths

**Where:** `workflow-guard.sh:187` — the block regex

**What:** Current regex matches `docs/executions/state.yaml`, `docs/executions/runs/*.yaml`, `.git/**/ledger/state.yaml`. An external snapshot at `docs/executions/external/<repo>/<run_id>.yaml` matches **none of them** (confirmed by probe).

**Shape:** Extend the regex to include `docs/executions/external/**/*.yaml` in the same change that adds external mode.

### R4: Two-root scoreboard

**Where:** `skill-system-audit/SKILL.md:107-140` — gate-coverage loop

**What:** The scoreboard walks merged PR heads in one repo and reads snapshots off `pull/$pr/head`. For external runs, the snapshot is in dotdev, not on the work-repo head.

**Shape:** For each merged work-repo PR, look up `docs/executions/external/<repo>/<run_id>.yaml` in dotdev and check its stamps. Until this exists, report work-repo coverage as "unmeasured" rather than 0%.

### R5: Migration of seven mis-shaped repos

**Where:** `chorus`, `delphi`, `bookmarks`, `pergamon`, `alexandria`, `circuit`, `insta-scrape`

**What:** These repos have `docs/executions/` without kernel-shaped state. Migration touches **only the legacy `state.yaml`** — never the directory (51 tracked files, 48 not ledger state).

**Steps per repo:**

1. Copy legacy `state.yaml` to `docs/executions/external/<repo>/legacy-state.yaml` in dotdev (historical record)
2. `git rm` that one file where tracked (not the directory)
3. Add repo to `repos.txt` allowlist

**Note:** `alexandria`, `circuit`, `insta-scrape` have no state file — just need the allowlist line.

## Implementation order

1. **R3 first** (guard regex) — smallest, standalone, prevents regression window
2. **R2** (allowlist + opt-in change) — unlocks external mode
3. **R1** (snapshot root indirection) — the core mechanism
4. **R4** (scoreboard) — verification instrument
5. **R5** (migration) — can only run after R1-R4 are working

## Test approach

- Each requirement gets red assertions before green (two-lane TDD per D-006)
- R1/R3: fixture-based tests in `test/test-ledger.sh`
- R2: guard behavior tests in `test/test-guard-rules.sh`
- R4: scoreboard tests (may need new fixture)
- R5: migration verified by running kernel read-only in each repo post-migration

## Files to read first

1. `dotfiles/.config/agents/skills/_docs/decision-log.md` — D-006 multi-repo adoption entry (the spec)
2. `dotfiles/.config/agents/skills/workflow-ledger/scripts/ledger.sh` — `set_snapshot_rel`, `commit_snapshot`, `fresh_since`
3. `dotfiles/.claude/hooks/workflow-guard.sh` — opt-in check, block regex
4. `dotfiles/.config/agents/skills/skill-system-audit/SKILL.md` — scoreboard loop (step 5)

## What was just done this session

- Merged PR #195 (three kernel gaps: verdict enforcement, revocation, flush)
- Merged PR #185 (mlflow reflections)
- Merged PR #189 (streamdeck scripts) — resolved conflicts
- Merged PR #173 (FIND-09 remediation) — resolved conflicts
- Closed #197 (superseded by #195)
- Closed #198, #177 (reflections already in main)
- Closed #154, #145 (stale)
- **PR queue is now empty**

## Blockers requiring human input

None. The decision is made; this is pure implementation.

## Suggested skills

- `workflow-router` — route before starting
- `workflow-deliver` (kind=feature) — five requirements as one deliverable
- `tdd` — two-lane red-first per D-006

## Scheduled

`d006-soak-end-flips` fires **2026-08-25 09:00** — proposes enforcement flips, does not block this work.
