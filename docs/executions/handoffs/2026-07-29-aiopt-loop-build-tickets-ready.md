# Handoff — IRIS optimization loop: all three halves designed, first build tickets published

Exit: completion with follow-ups
Target: either
Generated: 2026-07-29

## Start here (resuming agent)

> You are resuming multi-session work in `dotdev` (branch `ai-improvement-loop`). Recover state before acting:
>
> 0. **Work happens in `/Users/alexwelch/.herdr/worktrees/dotdev/ai-improvement-loop`.** If your cwd differs, `cd` there first. The GitHub remote is **`johnalexwelch/dotdev`** (the system-under-test is a *separate* repo, `classdojo/iris`). Every `gh` call needs `--repo johnalexwelch/dotdev` (or `--repo classdojo/iris`) — a bare `gh` resolves against the cwd repo.
> 1. **`gh auth switch --user johnalexwelch` FIRST.** The shell keeps reverting to `alexwelch-dojo`, which lacks write perms and silently fails `gh issue edit`/`create`. Re-run the switch at the top of every bash block that calls `gh`.
> 2. Durable state = **GitHub issue #118** (the map) + `docs/decision-log.md` (DL-0017..DL-0024) + `docs/roadmaps/2026-07-28-iris-optimization-loop-roadmap.md`. There is no `state.yaml`.
> 3. Read "Files to read first" (bottom) to rebuild context.
>
> Then do **Next step 1** below. Before working any ticket, VERIFY it is still open: `gh issue view <N> --repo johnalexwelch/dotdev --json state,comments` — a concurrent agent may have moved it.

## Where we are

The **IRIS optimization loop** (a daily loop in `dotdev` that evaluates + optimizes the IRIS analyst agent in `classdojo/iris`) is **decision-complete**. All three design halves are locked by multi-round specialist consensus: **measure** = eval (DL-0022), **explore** = candidate-generator (DL-0023), **drive** = loop-driver/report/routing (DL-0024, locked this session after 5 rounds). The four M3 open decisions (OD-1..OD-4) were resolved from `classdojo/iris` ground truth. The first **build** tickets (#127-#131) are published. Remaining work is implementation, not design.

## What was done this session

- **M3 loop-driver design LOCKED** — 5-round `m3-loopdriver-consensus` panel → consensus. Spec: `docs/design/iris-loop-driver-report-routing-v1.md`. Recorded as **DL-0024**. #118 updated (report-format + pipeline-wiring fog items resolved).
- **OD-1..OD-4 resolved** from live `classdojo/iris` (DL-0024 addendum):
  - OD-1 prompt paths: `system_prefix`/`findings_prose` → `backend/src/iris/analyst/prompts.py` constants; `sql_generation` → `mcp-servers/iris/skills/iris-query/SKILL.md`.
  - **OD-2 = DESIGN AMENDMENT:** habits/notes are **DB-backed** (`AgentNote` model, `NoteScope` user/table/domain/global == DL-0023 {scope,scope_key}, `NoteApprovalStatus` pending/approved, `memory/notes.py::append`). **Type 2 no longer routes as a PR** — it appends a `pending` note; landing = human approves it in IRIS's existing note workflow. Spec §E/§F amended.
  - OD-3: `.github/CODEOWNERS` pins `/mcp-servers/iris/skills/` → **@zach-dojo**, so `sql_generation` (Type-1 skill) PRs need his review before merge.
  - OD-4: **local runner** for v1.
- **Corrected a propagated ground-truth error** (critic-caught): **DL-0021 REJECTED Inspect AI** ("thin owned driver + cherry-picked iris-eval, no Inspect") — my recent artifacts had mislabeled the harness "Inspect AI". Fixed roadmap heading + line 9 + #118 line 41. Historical DL-0019 records left intact.
- **DL-0020 corpus wording corrected** — "real dotdev failures" → IRIS golden set; "private" = optimizer-holdout, not private-from-iris.
- **Published 5 build tickets** on #118 (checklist-linked; native sub-issue API is FORBIDDEN for the loop token):
  - **#127 P0a** — gradable golden facts (schema/model change + `required` numeric fact + negative test per pair). HITL · target `classdojo/iris`.
  - **#128 P0b** — canonical query-pattern tag per fixture, distinct from domain tags. AFK+review · target `classdojo/iris`.
  - **#129 M1-1** — harness scores one fixture's L1 SQL-execution correctness → score card (thin owned driver + cherry-picked `comparator.py`/loader, column-sum boost removed). HITL (secrets) · blocked by #127.
  - **#130 M1-1b** — harness gates one fixture on the L2a anti-hallucination check (needs full findings stack: `EndToEndRunner` + `MCPClientManager` + Postgres + MCP servers). HITL · blocked by #129, #127.
  - **#131 M1-2** — score card surfaces L2b advisory fact-coverage, non-gating, threshold=null until P0c. AFK+review · blocked by #130.
- Commits on `ai-improvement-loop` (pushed): `1429ce2` (Inspect fix), `c6a996c` (OD resolutions), `a671adf` (DL-0020 fix), plus earlier `e4c0fb1` (DL-0024 lock).

## What is NOT done

- **#127-#131 not started** — these are the ready build slices. #128 and #131 are AFK (`ready-for-agent`); #127/#129/#130 are HITL (schema judgment / runtime secrets).
- **P0c baseline capture** — not ticketed. Needs M1 built (#129+#130) + warehouse/LLM access + pinned IRIS commit + pinned judge + P0a (#127). This is the gate for everything downstream.
- **M2 generator build** (Slices 3-4, DL-0023) — blocked on P0c.
- **M3 driver build** — design locked (DL-0024) but not implemented; blocked on M1/M2.
- **P0d judge calibration** (κ≥0.6/0.7) — blocked on P0a + P0c; until it passes, L2b stays advisory.

## Blockers requiring human input

- **Runtime access (OD-4 = local):** #129/#130 need warehouse creds + LLM keys (+ Postgres + MCP servers for #130) provisioned to the operator's local machine before the M1 slices can run. Folded into the M1 HITL gate — no separate ticket.
- **@zach-dojo review** is required to merge any `sql_generation` skill-file PR the loop later proposes (OD-3). Not a blocker for M0/M1.
- **`gh` account:** must stay `johnalexwelch`; it silently reverts to `alexwelch-dojo` (no write perms).

## Next steps

1. **Start the two AFK slices** — #128 (P0b query-pattern taxonomy) and #131 (M1-2 L2b advisory) are the most independent. #128 has no deps; #131 is blocked by #130, so #128 first. Alternatively begin **#127 P0a** (HITL, unblocks the whole M1 chain) — highest-leverage but needs `classdojo/iris` write + domain judgment on required facts.
2. **After #127 + #129 + #130 land:** provision local runtime access and do **P0c baseline capture** (two runs, Δ≤2pp) — this unblocks M2 + M3.
3. Consider whether P0c/P0d/M2/M3-build warrant their own tickets now or after M1 proves out.

## Files to read first

- `docs/decision-log.md` — DL-0021 (harness = thin owned driver, NOT Inspect), DL-0022 (eval layers L1/L2a/L2b), DL-0023 (candidate-generator), DL-0024 + addendum (loop-driver + OD resolutions).
- `docs/roadmaps/2026-07-28-iris-optimization-loop-roadmap.md` — milestone sequencing; "Startable now" section.
- `docs/design/iris-loop-driver-report-routing-v1.md` — full M3 spec (state/report/approval/routing/reconcile + §E/§F Type-2 amendment).
- `docs/design/iris-eval-v1-selections.md` (DL-0022) and `docs/design/iris-loop-candidate-generator-v1.md` (DL-0023).
- GitHub **#118** (map, durable state) + sub-issues #127-#131.
- SUT repo: `/Users/alexwelch/projects/agents/iris` @ `staging` — fixtures at `backend/eval/golden_sql/seed.yml`; comparator/loader at `backend/src/iris/eval/`; prompts at `backend/src/iris/analyst/prompts.py`; notes at `backend/src/iris/memory/notes.py`.
