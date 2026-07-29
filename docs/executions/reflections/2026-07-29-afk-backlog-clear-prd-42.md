# Session Reflection: AFK backlog clear (PRD #42 + siblings)

**Date**: 2026-07-29
**Goal**: Autonomously clear the open johnalexwelch/dotdev backlog — implement/review/merge all actionable issues until only explicitly-parked items remain.

## What Went Well

- **Ground-truth over proxy, repeatedly.** Verified `process-needs-human-review` does not exist before "aligning" to it (#47); verified `human-gate-taxonomy.md` *does* exist, contradicting the router's own "not yet merged" claim (GAP #4 → #142); verified the AUDIT_REPORT "retirement-leaning" list was faithfully grounded in `workflow-router` line 233 rather than fabricated; ran `python3 -c "import cora"` to confirm the CLI was actually broken instead of assuming.
- **Concurrent-actor discipline.** Another process was committing to local `main` mid-session. Branching every PR from `origin/main` in a fresh worktree and running **no git in the primary checkout** avoided all conflicts and data loss.
- **Proportionality correction on delivery.** Caught and removed a disproportionate 181-line committed doc (#47) and skipped an unneeded router table-row addition (S7, YAGNI) — kept merges scoped to the actual change.
- **Verified AC-2 preservation.** Before merging #45, confirmed each deleted `Requires:` entry was genuinely moved to a "Runtime note:", not silently dropped.

## What Went Wrong / Friction

- **markdownlint auto-fix broke CI twice.** Executors committed markdown before the `markdownlint` pre-commit hook's auto-fix was re-staged; CI Lint failed with "files were modified by this hook" (#138, and the generated `skills-index.md`). Had to fix + force-push manually each time.
- **Over-investigated broken tooling before delegating.** Spent several `grep`/`find` rounds spelunking the `cora`/lint mechanism; user corrected: *"you are spinning on grep."* Should have dispatched the executor with "cora may be broken; use the pre-commit hooks" and let it discover specifics.
- **`cora` CLI is broken in this environment** (`ModuleNotFoundError: No module named 'cora'`), yet #45's ACs and several skills lean on a "focused CORA audit". Wasted time confirming; the enforced equivalent is `lint-skill-suite.sh` + `lint-skill-refs.sh`.
- **Stale issue briefs.** #45/#47/#48/#49 briefs specified `origin/staging` as the worktree baseline (repo base is `origin/main`); #47 required aligning a non-existent skill. Overridden per-dispatch, but the defect originated at issue-authoring time.
- **Generated file fails its own linter.** `skills-index.sh` emits markdown that `markdownlint` then rewrites (1 line) — a standing generator-vs-lint conflict: any `--write` regen re-introduces the lint failure / staleness.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "you are spinning on grep" | Over-investigating environment/tooling details before delegating; discovery that belonged inside the executor's context | `run-backlog` / `workflow-autonomous-backlog` (dispatch-first discipline) + `docs/agents/habits.md` |

## Lessons

1. **Delegate the discovery, not just the doing.** When a tool's exact mechanism is unknown, hand the executor a hypothesis ("cora may be broken; fall back to the pre-commit hooks") instead of resolving every detail in the orchestrator context first. Cheaper and keeps the orchestrator lean.
2. **A pre-commit run isn't "green" until a second run is clean.** Auto-fixing hooks (markdownlint) exit non-zero and modify files on first run; the commit must include those fixes. Verify-until-idempotent before committing, or CI Lint will fail.
3. **Generated docs must satisfy the linters that gate them,** or the generator and CI fight forever.
4. **Issue briefs are proxies too.** Baseline branch and referenced-skill existence should be validated at authoring time, not discovered at execution.

## Proposed Improvements

- [ ] `docs/agents/habits.md` — Add: "`cora` CLI is currently broken in this env (`import cora` fails); the enforced CORA-equivalent skill gates are `lint-skill-suite.sh` + `lint-skill-refs.sh`. Don't spelunk cora — run those." (priority: high)
- [ ] `docs/agents/habits.md` — Add: "Pre-commit is only green when a re-run is clean. After auto-fixing hooks (markdownlint) modify files, re-stage and re-run before committing, or CI Lint fails with 'files were modified by this hook'." (priority: high)
- [ ] `dotfiles/.config/agents/skills/_docs/skills-index.sh` — Make generated output markdownlint-clean (or add the file to a markdownlint ignore), so `--write` regen doesn't re-introduce a Lint failure. (priority: med)
- [ ] `dotfiles/.config/agents/skills/to-issues/SKILL.md` — Add an authoring check: worktree baseline branch must be a real branch (default `origin/main`), and any skill named in ACs must exist (or be explicitly flagged as to-be-created). Prevents `origin/staging` / non-existent-skill briefs. (priority: med)
- [ ] `dotfiles/.config/agents/skills/workflow-finalize/SKILL.md` (or executor dispatch guidance) — Note: when an AC asks for a *pressure scenario / validation*, put the proof in the PR body, don't commit a large standalone doc unless the AC's deliverable is the doc itself. (priority: low)
- [ ] `docs/agents/habits.md` — Reinforce the concurrent-actor rule already used well here: "In a repo with a concurrent committer, never run git in the primary checkout; branch every PR from `origin/main` in a fresh worktree." (priority: low)
