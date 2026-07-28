# Handoff — AI-optimization loop: assess iris-eval before locking #120

Exit: halt — next step is an AFK audit, paused for session boundary
Target: either (next step #124 is AFK; #121 is HITL)
Generated: 2026-07-28

Chains off `/Users/alexwelch/.herdr/worktrees/dotdev/ai-improvement-loop/docs/executions/handoffs/2026-07-28-aiopt-loop-map-charted.md` — only changes since are documented here. Durable state = **wayfinder map issue #118** (GitHub), not `state.yaml` (none exists).

## Start here (resuming agent)

> You are resuming multi-session **wayfinder** work. The map/issues live in GitHub repo **johnalexwelch/dotdev**; your cwd worktree is `/Users/alexwelch/.herdr/worktrees/dotdev/ai-improvement-loop` (repo `dotdev`).
>
> 0. **Set gh account first** (it flips): `gh auth switch --user johnalexwelch` then confirm active. Every tracker `gh` call targets `johnalexwelch/dotdev` (cwd remote already is this — but assert).
> 1. No `state.yaml`. SOURCE OF TRUTH = **map #118**: `gh issue view 118 --json title,body`. Read it for Destination/Decisions/fog.
> 2. Recommended next ticket: **#124** (research, AFK) — assess iris-eval. VERIFY still open + unclaimed first: `gh issue view 124 --json state,assignees`. Then claim: `gh issue edit 124 --add-assignee @me`.
> 3. **#124's work is a read-only audit of a DIFFERENT repo:** `/Users/alexwelch/projects/agents/iris` (the IRIS data-analyst agent). Not the cwd repo. Read `backend/src/iris/eval/` + `backend/eval/golden_sql/seed.yml` there.
>
> Then resolve #124 (verdict → comment → close → index on #118 → mirror via /decision-log → unblock #120). One ticket per session.

## Where we are

Wayfinder map **#118** charted (daily, manually-run loop that eval-scores AI-response quality → morning report → issues/PRs/reflections). #119 (eval-harness research) resolved last session. This session grilled #120 and discovered the first target — **IRIS** — already ships a full eval stack, which *would* answer #120 by reuse, **but Alex has low confidence in iris-eval's rigor**. So #120 is now blocked on assessing that harness (#124).

## What was done this session

- Grilled #120; surfaced first target = **IRIS** (`/Users/alexwelch/projects/agents/iris`), a data-analyst agent (NL query → SQL/Redshift → adversarial-debate answer).
- Found IRIS's existing eval: `iris-eval` CLI (`backend/src/iris/eval/cli.py`), 25-pair golden set (`backend/eval/golden_sql/seed.yml`), production-replay, CI `eval.yml` delta comments; dims = `pass_rate`/`similarity`/`answer_quality`. Baseline `eval/baseline.json` is **null** (IRIS's own issue #945).
- Created ticket **#124** (`wayfinder:research`, AFK) — assess iris-eval trustworthiness; attached as sub-issue of #118.
- **Blocked #120 on #124** (body line + `wayfinder:blocked` label), released my claim on #120.
- Posted grilling-progress comment on #120; updated map #118 fog (iris-eval-trust + null-baseline prerequisites).

## What is NOT done

- **#124** (assess iris-eval) — created, unclaimed, not started. The recommended next step.
- **#120** (eval unit + dimensions) — open, **blocked by #124**, claim released. Locks once #124 gives go/no-go.
- **#121** (bound optimization surface) — open, HITL, untouched.
- Loop scope decision (per-project generic w/ IRIS first, vs IRIS-only) — Alex has not answered; pending.

## Key decisions made

- #119 provisional harness pick is **superseded for IRIS** — reuse `iris-eval`, don't adopt promptfoo/Inspect/Harbor (those revive only if #124 says iris-eval is untrustworthy). See DL-0017.
- Can't adopt an unvetted eval as the loop's signal (Goodhart risk) → #124 gates #120.

## Next steps

1. **#124** (AFK): audit iris-eval → verdict (trust as-is / trust-with-fixes / augment / don't-trust-yet) + go/no-go. Unblocks #120.
2. Then **#120**: lock IRIS's eval unit + dimensions (as-is or augmented), or fall back to external judge.
3. **#121** (HITL): bound the optimization surface. Needs Alex live.
4. Get Alex's loop-scope answer (per-project vs IRIS-only).

## Suggested skills

- `/repo-audit` or a deep read — driving #124 (assess iris-eval).
- `/grill-with-docs` + `/domain-modeling` — #120 lock and #121 (both HITL).
- `/decision-log` — mirror #124's verdict.

## Files to read first

- Map: <https://github.com/johnalexwelch/dotdev/issues/118>
- Tickets: <https://github.com/johnalexwelch/dotdev/issues/124> · /issues/120 · /issues/121
- /Users/alexwelch/.herdr/worktrees/dotdev/ai-improvement-loop/docs/executions/handoffs/2026-07-28-aiopt-loop-map-charted.md
- /Users/alexwelch/.herdr/worktrees/dotdev/ai-improvement-loop/docs/research/2026-07-28-eval-harness-options.md
- /Users/alexwelch/.herdr/worktrees/dotdev/ai-improvement-loop/docs/decision-log.md (DL-0017)
- IRIS eval (audit target): /Users/alexwelch/projects/agents/iris/backend/src/iris/eval/ · /Users/alexwelch/projects/agents/iris/backend/eval/golden_sql/seed.yml · /Users/alexwelch/projects/agents/iris/eval/baseline.json
