# Handoff — D-006 queue drained; adoption policy + activity metric landed

Exit: manual (user-invoked)
exit_reason: complete
Target: claude
Generated: 2026-08-20 08:00 EDT

## Start here (resuming agent)

> You are resuming multi-session work in `dotdev`. Recover state before acting:
>
> 0. **Work happens in `/Users/alexwelch/dotdev`** (primary checkout, on `main`, fast-forwarded to `9e9e7f7`). Pushing needs the `github-personal` SSH host; `gh` routes by origin via `~/.local/bin/gh` — never run `gh auth switch` while other sessions are active.
> 1. There is **no active ledger run** — every run from this session is closed and merged. `ledger.sh show` will report no live state, which is correct, not an error. Do not try to resume a run.
> 2. Read the paths under "Files to read first" to rebuild context. The decision log is the source of truth for what was decided and why.
>
> Then pick a Next step below. Nothing is blocked and nothing is in flight. If you start delivery work, route through `workflow-router` first and cut a worktree with an **absolute** `--path` (a relative one breaks baseline verify).

## Where we are

The D-006 deterministic-delivery system is fully landed in `dotdev` and its merge queue is empty. Yesterday's session drained nine queued PRs, ran a cross-repo audit, recorded the multi-repo adoption policy, and pinned the audit's activity metric. Nothing of this session's work is open. Three kernel gaps were discovered and recorded but deliberately **not** fixed — they need one red-first run of their own.

## What was done this session

- **Merge queue drained** (all merged, primary at `9e9e7f7`): #183 router v1-vs-feature seam · #182 Phase 5b route evidence · #186 planning-lane consolidation (design-plan → to-prd migration mode, execute-phase retired) · #188 corpus batch 2 · #187 relay runner · #190 golden redirect cases (eval 48/48) · #184 draft-PR finalize reland · #191 per-run snapshots · #192 guard rule 3 on a real tokenizer.
- **Cross-repo audit** (`skill-system-audit`): enforcement is kernel-shaped in `dotdev` only. Seven repos carry `docs/executions/` without kernel state and all return `exit=1 MISSING`, so their next merge from a Claude session hard-blocks. Recorded in the decision log.
- **PR #193 — multi-repo adoption decision.** Work repos never receive ledger artifacts: live state stays in `.git/ledger/`, snapshots commit to `dotdev`'s `docs/executions/external/<repo>/<run_id>.yaml`. Five named implementation requirements; **nothing shipped in any work repo.**
- **PR #194 — activity metric pinned** in `skill-system-audit` step 5, plus corrections to #193's figures. Eight silent-failure doors closed, each proven by fixture rather than argument.
- **Worktree prune**: 40 → 12 (all merged-PR worktrees removed; open-PR and live-session ones kept).
- **Codex mirror synced** (97 skills), skills-index verified in sync.

## What is NOT done

- **Three kernel gaps — recorded, unfixed.** See "Next steps 1". No red-first run has been started.
- **External-snapshot mode is a decision only.** None of #193's five requirements is implemented; no work repo has been touched.
- **`taro` has no gates** and is the busiest ungated repo — 30 commits/week on `origin/staging`, ClassDojo remote, no `docs/executions/`. This is where an adoption pass should start, **not** `ml-models` (my original audit said otherwise and was wrong; see the correction in the decision log).
- Six unrelated PRs remain open and are other sessions' work: #189 (Stream Deck scripts, wants a human merge), #185, #177, #173, #154, #145.

## Blockers requiring human input

None. Nothing is waiting on a decision.

## Key decisions made

- **Work repos stay pristine** — ledger artifacts land in `dotdev` under `docs/executions/external/<repo>/`, never in the audited repo. Supersedes an earlier same-day "local-only, `.git/ledger` only" choice, which lost the audit trail when a branch was deleted.
- **The allowlist must be the sole opt-in signal.** Directory presence cannot work: `handoff/SKILL.md:17,63,81` writes and commits handoffs into `docs/executions/` in *every* repo, so a stale opt-in is recreated by the next `/handoff`.
- **Migration touches only the legacy `state.yaml`** — those seven repos hold 51 tracked files under `docs/executions/`, 48 of them not ledger state.
- **Activity is measured** on the remote-tracking default branch, after `fetch --prune origin`, over an absolute window, with `origin/HEAD` read from `ls-remote --symref` rather than the clone-time cache.

## Next steps

1. **Fix the three kernel gaps in one red-first run** (all in `checked_review` / `check_gate` / `commit_snapshot`, `ledger.sh`):
   - `stamp review` records `lane_<n>_verdict` into CHECKED but never tests its value — a REQUEST_CHANGES lane stamps clean if the agent attests approve. Inverts D-006's founding rule. Refuse on non-approval rather than enumerating rejection words.
   - No stamp revocation path: `set <step> pending` leaves `stamps.<gate>` intact and `check_gate` reads the stamp, so `check review` still returns OK after an explicit unwind. Either have `set` clear the gate's stamp, or add `ledger.sh unstamp <gate> --reason` recording it in `overrides[]`.
   - `set --evidence` corrections are unpublishable: `commit_snapshot` (`ledger.sh:663`) runs only from `init`/`stamp`/`close`, and `reconcile --apply` doesn't commit either — so a run that finds a false evidence string cannot ship the fix without passing a gate. Wants a `ledger.sh flush` with no gate semantics.
2. **Implement external-snapshot mode** (#193's five requirements) — snapshot-root indirection, the allowlist, the guard regex extension for `docs/executions/external/**`, the two-root scoreboard, and the seven-repo migration.
3. **Adoption pass on `taro` first**, then `ml-models`.
4. Nothing else. The Aug 25 reminder handles the enforcement flips on its own.

## Suggested skills

- `workflow-deliver` (kind=bug, two-lane TDD) — for the three kernel gaps; test-author commits red first, and test changes need explicit human approval.
- `workflow-router` — before any of the above; it threads `--route` into `ledger.sh init`.

## Scheduled

`d006-soak-end-flips` fires **2026-08-25 09:00** as a one-time task. It gathers soak evidence and proposes four enforcement flips (`LEDGER_ENTRY_ENFORCE=block`, router-eval CI required, finalize-stamp CI required, `LEDGER_REQUIRE_ROUTE=block`). It proposes only — it does not flip anything.

## What this session cost, and the lesson worth keeping

PR #194 was two files and took ~10 review rounds. Two reviewers found **eight silent-failure doors** in the recipe and **thirteen unverified claims of mine** — three of them inside sentences about verification discipline, one a fabricated 40-character SHA, and the last three in the CI watcher built to verify the fix. **Zero wrong numbers** in any derivation; every failure was a claim *about* the numbers.

The durable finding, from the reviewers: claims fail three ways, and **all three produce a clean verification report** —

1. never checked;
2. checked against the **wrong artifact** (a draft instead of `origin/main`; live `.git/ledger/state.yaml` instead of the committed `docs/executions/runs/<run>.yaml`);
3. checked with the **wrong technique** (reading a file to clear a code path that only a failure fixture exposes).

Reading catches claims about what a document says. Constructing the case catches claims about what code does under failure. Neither substitutes for the other. Corollary, learned three times in twenty minutes: **never hand-roll a CI completion predicate** — a counter cannot distinguish "no results" from "no failures"; `gh pr checks <n> --watch --fail-fast` returns 0/1/8 and owns the state machine.

## Files to read first

- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/_docs/decision-log.md` — the D-006 multi-repo adoption entry is the newest; read its "Problem, measured" and the three corrections.
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/skill-system-audit/SKILL.md` — step 5, the pinned Repo activity metric and its five failure modes.
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-ledger/scripts/ledger.sh` — the kernel; `checked_review` ≈ :1040-1075, `commit_snapshot` :663, `check_gate` :706.
- `/Users/alexwelch/dotdev/docs/executions/runs/` — three committed run snapshots from this session.
- <https://github.com/johnalexwelch/dotdev/pull/193> and <https://github.com/johnalexwelch/dotdev/pull/194> — PR bodies carry the full review narratives.
- `/Users/alexwelch/dotdev/docs/executions/handoffs/` — previous handoffs in this chain.
