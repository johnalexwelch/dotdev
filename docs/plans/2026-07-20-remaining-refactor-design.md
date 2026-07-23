# Design Plan — dotdev remaining refactor (post PR #80-84)
**Date:** 2026-07-20
**Audit:** `docs/audits/2026-07-20-skill-suite-audit.md`, `docs/audits/2026-07-20-repo-audit.md`, `docs/audits/2026-07-20-refactor-proposal.md` (brief-mode, drawing on prior audits rather than a fresh `/repo-audit`)
**Mode:** draft

## §0 For Claude Code — read this first

Start at Phase 0. `main` carries an active ruleset (`main-protection`, id 19215668) — every phase lands via `git worktree add -b <branch> <path> origin/main` + draft PR, never a direct push. Cross-reference: `docs/decision-log.md` DL-0005 (worktree cut/verify/emit design), DL-0008 (routing hybrid), DL-0010 (meta-layer diet), DL-0011/0012 (branch protection, prior lock reconciliation). `[auto]` = execute without asking; `[human]` = stop and get Alex's decision before proceeding. Phases are ordered by urgency and by what unblocks what — do not reorder without re-checking dependencies noted per phase.

**Ground-truth correction versus the source audits (verified today, not assumed):** FIND-34 (pre-commit hardcoded `dotfiles/.claude/skills` path) does **not** currently reproduce — `.pre-commit-config.yaml` already references the correct `dotfiles/.config/agents/skills/` path. It is dropped from this plan's scope; do not re-fix it. Also, FIND-37's "reflection-write rule violated" premise is **stale**: `session-insight/SKILL.md` at current `HEAD` (post commits `4cb36e3`/`2703dc5`) already reverted the 2026-07-16 no-persist rule (`77a7c62`) back to "persist a reflection file at `docs/executions/reflections/`" as designed, documented behavior — there is no contradiction to resolve. Phase 5 scope narrows accordingly to retention policy + ADR consolidation only.

## §1 Purpose

This plan sequences the four remaining items from the 2026-07-20 skill-suite and repo audits, after PRs #80–84 already landed the mechanical fixes (dead CI/tests/OpenWiki gates, 5 skill retirements, step-ledger collapse, 31 skills locked to catalog tier, audits and decisions recorded). It supersedes the "pre-approved work" and "decisions" sections of `docs/audits/2026-07-20-refactor-proposal.md` for the four items below; that document's D1–D5 decisions remain the settled rationale this plan builds on.

No canary waiver is needed — Phase 1 (symlink resolution) serves as the pilot: it is the smallest, most time-bound, most fully-decided-once-Alex-answers-one-question of the four workstreams, and it validates the worktree+PR flow under the new branch-protection ruleset before the larger REQ-1/REQ-3 work commits to it.

## §2 Problem

Four structural gaps remain open from the audits:

- **REQ-1 (F-1/F-2, skill-suite audit):** `workflow-router`'s classification table routes to mid-chain steps instead of owning orchestrators (no ship/finalize row exists at all), and has zero rows for the 47 skills now locked to catalog tier (PR #83) — they're invocable by name but undocumented in the router's own text.
- **REQ-2 (FIND-33, repo audit):** the working tree currently has 4 tracked symlinks deleted-but-uncommitted (`dotfiles/.claude/docs`, `dotfiles/.claude/skills`, `dotfiles/.config/agents/skills/find-skills`, `dotfiles/.config/agents/skills/herdr`), with `find-skills`/`herdr` materialized as real untracked `SKILL.md` files where the symlinks used to resolve. Verified via `git ls-files -s` (all 4 still mode `120000` in the index) and `git status --porcelain` (all 4 shown `D`, plus 2 new `??` files). Committed as-is, a fresh `install.sh` would stop producing `~/.claude/skills` entirely.
- **REQ-3 (F-8, skill-suite audit; DL-0005, decision-log):** the accepted `cut/verify/emit` worktree-baseline interface has no implementation — confirmed via `find` for any script matching the name, none exists — while ~20 skills still duplicate the Worktree Baseline Gate prose inline (`workflow-router` itself included, per the snippet at `workflow-router/SKILL.md:257-270`).
- **REQ-4 (FIND-38, repo audit; DL-0010):** two decision-record mechanisms exist — `docs/decision-log.md` (tracked, canonical per DL-0010) and `docs/adr/` (1 file, untracked) — plus a third, disjoint `~/.claude/docs/adr/` (3 files, live-only, confirmed still present via `ls`). `docs/executions/reflections/` has 16 files with no retention policy (confirmed via `ls`).

## §3 Goals and non-goals

**Goals**
- Router table routes every mutating/delivery request to its owning orchestrator, includes a ship/finalize row, and documents the catalog tier — measurable via a coverage re-check (target: 0 "no route exists" cases for delivery-shaped requests).
- The primary checkout's dirty symlink state is resolved one way or the other (restored or intentionally materialized) and committed — measurable via `git status --porcelain` showing 0 pending changes on these 4 paths.
- One working, tested `cut/verify/emit` script exists and has at least 2 real callers (`workflow-build-one` Step 0, `workflow-router`'s own Worktree Baseline Gate) — measurable via the script's test harness passing and both callers invoking it instead of inline `git worktree` commands.
- One canonical decision-record location; a stated, applied retention rule for `docs/executions/reflections/`.

**Non-goals**
- Migrating all ~20 Worktree Baseline Gate callers to the new script — only the first 2 land here; the rest are explicitly deferred (§9).
- Rebuilding the router's full classification table from scratch — this plan amends it, it does not replace the Route Confirmation Gate or Agent Budget Rule machinery, which are out of scope and working.
- Multi-harness (`find-skills`/`herdr` universalization to Codex/opencode, FIND-27) — REQ-2 only resolves the *current dirty state*; a full multi-harness symlink strategy is a separate future decision, noted in §9.

## §4 Current state

- `workflow-router/SKILL.md`: classification table (~lines 159+) has 32 direct routes + 12 chain-reachable, 47 skills now correctly locked (PR #83) but undocumented in the table; no ship/finalize row (confirmed absent by grep).
- Working tree: `git ls-files -s` shows `dotfiles/.claude/docs`, `dotfiles/.claude/skills`, `dotfiles/.config/agents/skills/find-skills`, `dotfiles/.config/agents/skills/herdr` all still indexed as symlinks (mode 120000); `git status --porcelain` shows all 4 as unstaged deletions (`D`), plus `dotfiles/.config/agents/skills/find-skills/SKILL.md` and `.../herdr/SKILL.md` as new untracked real files. The 2026-07-09 audit's FIND-27 recorded this symlink-to-`.agents/skills` pattern as an intentional "precedent to universalize" for multi-harness — so this is not accidental drift with no rationale, but neither is it a finished decision; no decision-log entry documents completing or abandoning it.
- `docs/decision-log.md`: 12 entries (DL-0001–0012), tracked, canonical per DL-0010's own stated intent.
- `docs/adr/`: 1 file (`0002-sole-routing-authority.md`), untracked (confirmed `git status` shows it as `??` from earlier session state — verify again in Phase 0).
- `~/.claude/docs/adr/`: 3 files (`0001-stow-plus-cora-dual-layer-installation.md`, `0002-workflow-router-as-single-routing-authority.md`, `0003-hard-soft-contract-split.md`), live-only, outside any repo.
- `docs/executions/reflections/`: 16 files, no pruning script or policy.
- No `cut/verify/emit` or similarly-named worktree script exists anywhere in `dotfiles/.config/agents/skills/` (confirmed via `find`).

## §5 Execution plan

### §5.0 Phase 0 — Preflight
**Goal:** Baseline is clean and the plan's ground-truth claims are re-verified immediately before work starts.
**Tasks:**
1. [auto] `git -C ~/dotdev fetch origin --prune`; confirm `origin/main` is the latest merge of PR #84.
2. [auto] Re-run `git status --porcelain` scoped to the 4 REQ-2 paths and the ADR paths; confirm they match §4's description (nothing has changed since drafting).
3. [auto] Run `bash test/run-tests.sh` on current `origin/main` via a scratch worktree; record baseline pass count (expect 70/70 per PR #83's last report).
4. [human] Confirm `.gitignore` still correctly excludes anything local-only that shouldn't land in Phase 1-5 commits (spot-check, not exhaustive).
**Addresses:** n/a (hygiene, not a finding)
**Verification:** Tests pass on current `origin/main`; ground-truth claims in §4 re-confirmed or the plan is halted and revised before Phase 1 starts.
**Rollback:** n/a.
**Deletes:** none.

### §5.1 Phase 1 — Pilot: Resolve the dirty symlink state (REQ-2 / FIND-33)
**Goal:** Eliminate all in-repo symlinks per Alex's decision ("dotdev is my canonical source of configs — I don't want ANY symlinks"), landing one clean, committed end-state for the 4 paths, and proving the worktree+PR flow works end-to-end under the new ruleset before bigger phases depend on it.
**Decisions (settled 2026-07-20, no longer open):**
- `dotfiles/.claude/docs` and `dotfiles/.claude/skills`: **confirm deletion, do not restore.** Ground-truthed: `ai-setup.sh:23` already documents this exact retirement in a comment ("Not a Stow item since dotfiles/.claude/skills no longer exists (retired indirection)") and creates `~/.claude/skills` directly via `ln -sfn "$HOME/.config/agents/skills" "$HOME/.claude/skills"` (line 24), bypassing these two paths entirely. `install.sh` never stows either path. The working-tree deletions were correct and intentional; they just need committing.
- `dotfiles/.config/agents/skills/find-skills` and `.../herdr`: **materialize as normal tracked directories**, matching every other skill in the corpus. No external `~/.agents/skills/...` symlink targets are created or required.
**Tasks:**
1. [auto] In a worktree off `origin/main`: commit the deletion of `dotfiles/.claude/docs` and `dotfiles/.claude/skills` (`git rm` the symlink entries — they are already deleted in the working tree, so this stages the deletion cleanly).
2. [auto] `git rm` the `find-skills`/`herdr` symlink entries and `git add` the existing real `SKILL.md` files already sitting on disk in their place (content is already correct — PR #83 added their Contract sections to the machine-local copies; verify content matches before adding, do not silently regenerate).
3. [auto] Grep the whole repo (skills, scripts, docs) for any remaining reference expecting `dotfiles/.claude/skills`, `dotfiles/.claude/docs`, or a `~/.agents/skills/...` target for find-skills/herdr, and fix or remove those references — the goal is zero remaining symlink expectations anywhere in the corpus.
4. [auto] Run `install.sh` in a scratch/dry-run mode if one exists (check `install.sh --help` or a `--dry-run` flag) to confirm the fresh-machine path produces `~/.claude/skills` correctly with zero in-repo symlinks; if no dry-run mode exists, at minimum verify the stow target paths in `install.sh` still match reality post-change.
5. [auto] Run `lint-skill-refs.sh`, `lint-skill-suite.sh`, `test/run-tests.sh` — all must pass.
6. [human] Review and merge the resulting draft PR.
**Addresses:** FIND-33 (repo audit)
**Verification:** `git status --porcelain` on `origin/main` post-merge shows 0 pending changes for the 4 paths; `lint-skill-refs.sh`/`lint-skill-suite.sh`/`test/run-tests.sh` all pass; a fresh clone + `install.sh` produces a working `~/.claude/skills`.
**Rollback:** Revert the phase's merge commit on `main`; the pre-phase dirty state in the primary checkout is unaffected (this phase operates in an isolated worktree, not the primary checkout — the primary checkout's separate in-progress work, e.g. the SSH-key fix, remains untouched regardless of this phase's outcome).
**Deletes:** none (symlink entries are either restored or converted to regular tracked files — content is preserved either way).

### §5.2 Phase 2 — Build and land the worktree `cut/verify/emit` script (REQ-3, part A)
**Goal:** The accepted DL-0005 interface exists as a real, tested script — the first vertical slice of the worktree-baseline deepening, standalone and independently verifiable before any caller is migrated.

**Exact spec, ground-truthed from `dotfiles/.config/agents/skills/_docs/decision-log.md` D-005 (corpus decision-log — distinct from the root `docs/decision-log.md`) — do not deviate:**
- Script path: `dotfiles/.config/agents/skills/setup-worktree/scripts/worktree-baseline.sh` (not a generic name — this is the path D-005 names).
- Three subcommands: `cut`, `verify`, `emit`.
- Must cover, per D-005's exact scope line: base-branch resolution, `git fetch --prune`, stacked-parent ancestry check (for `STACKED_WORKTREE_GATE`), path/branch derivation, and env-file copy.
- `emit` must produce both `WORKFLOW_BASE_GATE` and `WORKTREE_BASELINE_GATE`/`STACKED_WORKTREE_GATE` evidence lines — the exact two gate-block formats callers currently hand-write inline.
- Test harness: `test/test-worktree-baseline.sh`, same shape/pattern as the existing `test/test-workflow-guard.sh` (tmp-git-repo local-substitutable adapter, per D-005's own testability rationale — this is why a script was required over prose in the first place).
- D-005 explicitly names `workflow-build-one` Step 0 as the sole first-slice caller for Phase 3; the other 19 callers (`setup-worktree`, `execute-phase`, `execute-prd` + template, `prompt-builder`, `run-backlog` + 2 policy refs, `to-issues`, `to-prd`, `triage` + brief template, `workflow-autonomous-backlog`, `workflow-debug`, `workflow-effectiveness-audit`, `workflow-executive-doc`, `workflow-feature`, `workflow-finalize`, `workflow-review`, and `workflow-router` itself) are confirmed out of scope for this plan (§9.1) — this plan's Phase 3 migrates `workflow-build-one` plus `workflow-router` (2 total, per this plan's own goal of the router adopting its own gate mechanics), leaving 18 for the deferred follow-up.

**Tasks:**
1. [auto] Implement `worktree-baseline.sh` per the exact spec above.
2. [auto] Write `test/test-worktree-baseline.sh` covering: happy path, missing base ref, dirty existing worktree, already-existing branch name, stacked-parent ancestry check.
3. [auto] Add the harness to `test/run-tests.sh`.
4. [auto] Run full test suite; confirm green.
**Addresses:** F-8 (skill-suite audit), D-005 (`dotfiles/.config/agents/skills/_docs/decision-log.md`)
**Verification:** New test harness passes; `bash worktree-baseline.sh cut ...` produces a real worktree matching the resolved base; `bash worktree-baseline.sh verify ...` correctly fails on a dirty/wrong-base worktree in a manufactured test case; `emit` output matches the exact gate-block string format currently hand-written by at least one existing caller (diff against `workflow-build-one`'s current inline text).
**Rollback:** Revert the phase's merge commit; no existing caller has been touched yet (script is net-new, unused until Phase 3), so rollback has zero blast radius.
**Deletes:** none.

### §5.3 Phase 3 — Migrate first 2 callers to the new script (REQ-3, part B)
**Goal:** Prove the `cut/verify/emit` interface end-to-end with real callers, per DL-0005's own plan ("`workflow-build-one` Step 0 is the first vertical slice").
**Tasks:**
1. [auto] Migrate `workflow-build-one` Step 0 (the per-issue worktree creation) to call the new script instead of its inline `git worktree add` sequence; confirm output/gate evidence format is unchanged from the caller's perspective (skills downstream of `workflow-build-one` should not need changes).
2. [auto] Migrate `workflow-router`'s own "Worktree Baseline Gate" section (`workflow-router/SKILL.md:257-270`) to reference the script instead of the inline `git fetch`/`git worktree add` snippet — this makes the router the second real caller and starts eating into the ~20-caller duplication this was meant to fix.
3. [auto] Run `lint-skill-refs.sh`, `lint-skill-suite.sh`, `test/run-tests.sh`.
4. [human] Spot-check one real `workflow-build-one` invocation end-to-end (or a dry run) to confirm no behavioral regression before merging.
**Addresses:** F-8 (skill-suite audit), DL-0005
**Verification:** Both callers produce the same gate evidence shape as before migration (diff the emitted `WORKTREE_BASELINE_GATE`/`WORKFLOW_BASE_GATE` line format pre/post); full test suite green.
**Rollback:** Revert the phase's merge commit; both callers' prior inline implementations are restored verbatim from git history — no data loss, this is a pure code-path swap.
**Deletes:** none (old inline snippets are removed from the 2 migrated skills, but this is a same-phase replacement, not a stale-code deletion — no separate delete-list entry needed since the replacement is verified in the same phase per the Delete List rule).

### §5.4 Phase 4 — Router table rewrite (REQ-1)
**Goal:** `workflow-router`'s classification table routes to owning orchestrators (not mid-chain steps), includes a ship/finalize row, and documents the catalog tier — closing the "half the corpus has no route" gap from the skill-suite audit.
**Tasks:**
1. [auto] Add a "ship this" / "finalize this PR" / "merge this" classification row routing to `workflow-finalize` (currently absent — confirmed by grep).
2. [auto] Audit existing direct-to-mid-chain-step routes (e.g., any row routing straight to `receive-review` or `prompt-builder` rather than their owning orchestrator `workflow-finalize`/`run-backlog`/`workflow-build-one`) and repoint them to the owner, per SB-021 in `docs/executions/skill-backlog.md`.
3. [auto] Add a documented "catalog tier" section listing the 47 `disable-model-invocation: true` skills (from PR #83) by category (analytics, incident, library, knowledge/utility), each with its invoke-by-name form (e.g. `/sql-review`) — cross-reference the pointer already added to `dotfiles/.claude/CLAUDE.md` in PR #83/#84 rather than duplicating the full list in two places; link between them.
4. [auto] Regenerate `_docs/skills-index.md` if it reflects routing state.
5. [auto] Run `lint-skill-refs.sh`, `lint-skill-suite.sh`, `test/run-tests.sh`.
6. [human] Review the full amended classification table for any routing case Alex disagrees with before merging (this is the most judgment-heavy phase — the router is the single most load-bearing skill in the corpus).
**Addresses:** F-1, F-2 (skill-suite audit), SB-021 (skill-backlog)
**Verification:** Manual coverage re-check — pick 10 representative request phrasings spanning delivery, analytics, and catalog-tier work; confirm each maps to exactly one row and that row names the owning orchestrator, not a mid-chain step.
**Rollback:** Revert the phase's merge commit; `workflow-router/SKILL.md` returns to its pre-phase table. No other skill's behavior depends on this table's exact wording (routing is advisory text, not code), so rollback has no downstream side effects.
**Deletes:** none.

### §5.5 Phase 5 — Meta-layer diet: decision records + retention (REQ-4)
**Goal:** One canonical decision-record mechanism; a stated, applied retention rule for `docs/executions/reflections/`.
**Tasks:**
1. [auto] Fold `docs/adr/0002-sole-routing-authority.md`'s content into a new `docs/decision-log.md` entry (next `DL-NNNN` after the current tail), preserving its rationale; then `git rm docs/adr/0002-sole-routing-authority.md` and the now-empty `docs/adr/` dir.
2. [auto] **Decision settled 2026-07-20:** delete `~/.claude/docs/adr/` (3 files, live-only, outside this repo) — Alex: "those can likely be cleaned up." Before deleting, quickly skim each of the 3 files for any rationale not already captured elsewhere (decision-log, ADR-0002, this plan); if any unique content surfaces, fold it into `docs/decision-log.md` first, then delete the directory. This is machine-local cleanup, not a repo commit.
3. [auto] Write a short retention policy as a new section in `docs/decision-log.md` or `dotfiles/.config/agents/skills/_docs/CONVENTIONS.md` (pick the location matching existing convention for corpus-wide policy — check which file already hosts similar policy text before choosing): e.g., "reflections older than N days with no inbound reference from an active skill-backlog item get archived to `docs/executions/reflections/archive/` or deleted" — pick a concrete N (recommend 60 days, aligned with the skill-invocation telemetry's 30-day review cycle plus a buffer) rather than leaving it open-ended.
4. [auto] Apply the retention rule once to the current 16 files as a one-time cleanup (archive or delete per the rule, not ad hoc).
5. [auto] Run `lint-skill-refs.sh`, `lint-skill-suite.sh`, `test/run-tests.sh`.
**Addresses:** FIND-38 (repo audit), DL-0010 (decision-log)
**Verification:** `docs/adr/` no longer exists; exactly one decision-record file (`docs/decision-log.md`) remains authoritative in-repo; the retention policy is written down and has been applied once (file count in `docs/executions/reflections/` reflects the rule, not the pre-phase count of 16 unconditionally).
**Rollback:** Revert the phase's merge commit; ADR content and reflection files are recoverable from git history (nothing is force-deleted from reflog-reachable history).
**Deletes:** `docs/adr/0002-sole-routing-authority.md` (folded into decision-log, no separate replacement file needed); any reflection files the retention rule prunes (archived or deleted per the rule chosen in task 3 — no replacement, they're superseded by the pattern captured in skill-backlog/decision-log if load-bearing).

## §6 Authoring standard

Follow the existing corpus conventions: `dotfiles/.config/agents/skills/_docs/CONVENTIONS.md` for skill-file structure, `_docs/decision-log.md`'s DL-NNNN format for the corpus-level decision log (distinct from the root `docs/decision-log.md` — do not conflate the two logs when writing Phase 5 entries; Phase 5 targets the root log per DL-0010's own scope).

## §7 Architecture rules

- No skill body exceeds ~200 lines without a `references/` split (per the design-plan/workflow-effectiveness-audit precedent from PR #82).
- `disable-model-invocation: true` skills remain fully invocable by name and by other skills' Flow — locking only removes them from the ambient per-session listing.
- All git-mutating work happens in an isolated worktree off `origin/main`, never the primary checkout, never a direct push (ruleset-enforced).

## §8 Delete list

| File | Phase | Why | Replacement |
|---|---|---|---|
| `docs/adr/0002-sole-routing-authority.md` | 5 | Folded into canonical `docs/decision-log.md` per DL-0010 | New DL-NNNN entry in `docs/decision-log.md` |
| Pruned files under `docs/executions/reflections/` | 5 | Retention policy applied for the first time | Archived under `reflections/archive/` (if archival chosen) or superseded by any load-bearing content already captured in `skill-backlog.md`/`decision-log.md` |
| Old inline `git worktree add` snippets in `workflow-build-one` and `workflow-router` | 3 | Replaced by shared `cut-verify-emit.sh` script | The script itself (`setup-worktree/scripts/cut-verify-emit.sh`) |

No file is deleted before its replacement is verified live in the same phase.

## §9 Open questions

All four Phase 1/Phase 5 decisions were settled by Alex on 2026-07-20 (see §5.1 and §5.5 task 2) — no open decisions block execution. Remaining forward-looking items:

1. **Remaining ~18 Worktree Baseline Gate callers** beyond the 2 migrated in Phase 3 — explicitly deferred to a future plan; not in this plan's scope. Owner: defer until a follow-up `/design-plan brief="migrate remaining worktree-baseline callers"` is run, informed by how Phase 3's 2 callers perform in practice first.
2. **Retention window: 60 days, time-based** — confirmed by Alex ("that's fine"). Applied as-is in §5.5 task 3.
3. **FIND-27 multi-harness universalization** (the old find-skills/herdr symlink-to-`~/.agents/skills` pattern) is now fully abandoned per Alex's "no ANY symlinks" decision — if multi-harness skill sharing is wanted later, it needs a non-symlink mechanism (e.g., a sync script like `sync-codex-skills.sh`), decided as its own future initiative, not by resurrecting this pattern.

## §10 Definition of done

- [ ] FIND-33 addressed: symlink state committed, one decided end-state, `install.sh` verified.
- [ ] F-8/DL-0005 addressed: script exists, tested, and has exactly 2 real callers (`workflow-build-one`, `workflow-router`); remaining callers explicitly deferred (§9.3), not silently dropped.
- [ ] F-1/F-2/SB-021 addressed: router table has a ship/finalize row, routes to owners not mid-chain steps, documents the 47-skill catalog tier.
- [ ] FIND-38/DL-0010 addressed: `docs/adr/` no longer exists in-repo; one canonical decision log; retention policy for `docs/executions/reflections/` written and applied once.
- [ ] All `[auto]` tasks completed; all `[human]` decisions made and recorded (in PR bodies and, where a decision-log entry is warranted, in `docs/decision-log.md`).
- [ ] Every phase's PR merged to `main` via the ruleset-enforced worktree+PR flow; `test/run-tests.sh` green after each merge.

## §11 Sync-gate mechanics

- Branch naming: `refactor/phase-N-<slug>` for Phases 2-4 (worktree script, router rewrite); `fix/phase-1-<slug>` for the symlink resolution (it's a correctness fix, not a refactor); `docs/phase-5-<slug>` for the meta-layer diet.
- Each phase: `git worktree add -b <branch> ../dotdev-worktrees/<slug> origin/main`, do the work, push, open a **draft PR**, get Alex's review/merge before starting the next phase — `main` must be clean (no open, unmerged phase PR) before the next phase's worktree is cut, since later phases may touch overlapping files (e.g. Phase 3 and Phase 4 both touch `workflow-router/SKILL.md`).
- If a phase fails mid-way: leave the worktree and its branch in place (don't delete), report the exact failure and blocker, and wait for Alex's direction rather than improvising a workaround.
- Use `GH_TOKEN="$(gh auth token --user johnalexwelch)"` for PR creation if the active `gh` account lacks collaborator rights on `johnalexwelch/dotdev` (recurring issue across PRs #80-84).
