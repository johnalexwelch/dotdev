# Session Reflection: skill-backlog harvest → dispatch → merge

**Date**: 2026-07-24
**Goal**: Run `/skill-backlog` end-to-end (harvest reflections → cluster → dispatch approved items to `workflow-skill`), then merge the resulting PRs.

## What Went Well

- **Ground-truth over proxy, consistently.** Delegated a ground-truth probe that closed 12 stale-"open" ledger rows against the live filesystem (a later session had implemented them); verified the CI-red condition, the four merges, and the Codex mirror each against `gh`/`diff` rather than assuming. Did **not** blindly merge red CI — surfaced it and let the user decide.
- **Efficient fan-out.** 2 parallel read-only agents (harvest + probe), then 4 `workflow-skill` dispatches bundled to avoid same-file collisions.
- **Pushed back with evidence on a wrong target.** User said "update the session-insight skill" for the swallowed-report fix; read the skill, found it never dispatches subagents (fix would be inert), and routed to `docs/agents/habits.md` instead — confirmed with the user rather than silently complying or overriding.
- **Dogfooded just-merged habits live.** SB-050 (`gh auth switch`) fired 3×; SB-023 (git env/identity check) and SB-046 (PR-state ground-truth) used before writes; reviewing the staged diff before commit caught a silent `cp` no-op.
- **Isolate-edits-into-worktree maneuver** (SB-034) used to keep skill-backlog artifacts off the user's unrelated `#96` branch.

## What Went Wrong / Friction

- **Every subagent's final report was swallowed (6×).** Completion notifications carried empty/placeholder `result` (`—`, `(end)`); recovered each via scoped `jq` over the transcript JSONL. *Already fixed this session* — habit added + merged (#97).
- **`gh` active account rotated to the wrong identity 3×** (keyring-level), breaking a `pr ready`, two merges, and a `pr edit`. The reactive SB-050 habit caught it each time, but the **root cause (auto-rotation) is unaddressed** — every delivery `gh` write is one silent flip away from failing.
- **`cp` silently didn't overwrite** — aliased to `cp -i`, defaulted to "no", so `skill-backlog.md` wasn't copied into the ledger worktree. Same shell-alias family as the C21 grep/find/cat habit, which doesn't mention `cp`/`mv`. Caught only by the staged-diff review.
- **Dispatch-collision I didn't foresee.** Bundled SB-046+049 to avoid a `workflow-finalize` collision, but SB-045 *also* landed in `workflow-finalize` (build-one delegates its gate there) — I'd scoped it to `workflow-build-one` from the ledger's nominal owner. Result: #98/#99 both touched the file → a rebase. I bundled by *nominal* owner, not *actual* target.
- **One executor committed onto the wrong branch.** The SB-028 executor committed the keystone onto the unrelated in-flight `#96` (primary checkout was sitting there); the habits executor correctly cut a fresh worktree off `origin/main`. Two executors, opposite hygiene, same prompt — the dispatch prompt didn't *mandate* worktree-off-`origin/main`.
- **Transient GitHub GraphQL 5xx blocked the ledger PR-create 3×.** Stopped per no-rabbit-hole and handed over a compare URL; branch was already pushed.
- **`gh pr merge` returned no output** on success — had to verify merge state separately (did).

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|--------------------------|------------|-------------------|
| 1 | "update the session-insight skill so that we fix that" → actually belonged in `habits.md` | User named a plausible-but-wrong skill; session-insight never dispatches subagents | (resolved by clarifying, not a skill defect) |

*No hard corrections; the session ran on delegated decisions ("what do you recommend", "admin-override merge").*

## Lessons

1. **Bundle parallel edits by *actual* target file, not nominal owner.** Before parallel-dispatching edits, resolve where each change truly lands (follow delegation/reference chains — build-one's finalize gate lives in `workflow-finalize`). Nominal-owner bundling missed a collision.
2. **Dispatched landing must be branch-safe by construction.** An executor will commit onto whatever branch the primary checkout is on unless the prompt/skill *mandates* cutting a worktree off `origin/main`. Make it a hard rule, not a hope.
3. **Reactive env habits don't remove the hazard.** SB-050 catching the `gh` flip 3× is a win, but the flip keeps happening; a proactive account-assert (or pin) before delivery `gh` writes would stop paying the tax each time.
4. **Shell-alias hazard extends past grep/find/cat.** `cp -i`/`mv -i` silently no-op on conflict; the staged-diff review is what saved it — cheap, keep it.

## Proposed Improvements

- [ ] `dotfiles/.config/agents/skills/workflow-skill/SKILL.md` — landing step must **mandate** cutting a worktree off `origin/main` (never commit in the primary checkout, which may sit on an unrelated branch); cite the #96 keystone-commingling defect this session (priority: high)
- [ ] `dotfiles/.config/agents/skills/skill-backlog/SKILL.md` — Step 6 should cover the **post-merge lifecycle** it currently omits: after dispatched items land as PRs, flip `accepted → implemented` only on merge, run the Codex mirror for skill edits, and clean up worktrees — or explicitly hand off to `workflow-finalize` + `cleanup-delivery` (priority: med)
- [ ] `dotfiles/.config/agents/skills/skill-backlog/SKILL.md` — Step 5 dispatch: resolve each approved item's **actual target file** (follow delegation/reference chains) and bundle same-file edits into one dispatch; note that nominal owner ≠ landing file (priority: med)
- [ ] `docs/agents/habits.md` — extend the shell-alias bullet (C21) to include `cp`/`mv` interactive aliases (`cp -i` defaults to "no" and silently skips the copy); reinforce "review the staged diff before commit" as the backstop (priority: med)
- [ ] `docs/agents/habits.md` (or delivery skills) — **proactive** gh-account assertion: before any `gh` write in a delivery flow, assert the active account matches the repo owner (`gh auth status`), don't just react to the failure (SB-050 is reactive) — the flip recurred 3× this session (priority: med)
- [ ] `dotfiles/.config/agents/skills/workflow-finalize/SKILL.md` — on transient GraphQL 5xx during PR create/merge, retry with short backoff N× then fall back to the compare URL rather than failing hard (priority: low)

## Skill Extraction Candidates
<!-- none: every finding is an enhancement to an existing skill; no new repeatable multi-step workflow cleared the quality gate this session -->
