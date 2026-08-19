# Workflow Route Map (D-006 system)

> **This file does not route — `workflow-router` does.** The router is the sole
> routing authority (`docs/adr/0002-sole-routing-authority.md`); its
> classification table is the live, golden-eval-pinned source of truth. This
> file is the human-readable **map** of the system the router dispatches into.
> Per the D-005/D-006 drift rule it never restates a skill's procedure — each
> section links its owning skill, and when this map and a `SKILL.md` disagree,
> the skill wins. Skills live in `dotfiles/.config/agents/skills/` (canon),
> active at `~/.claude/skills`.

## The delivery spine

```text
            PLANNING TIER (feeds the spine)
 [wayfinder] ─▶ workflow-feature ─▶ grill-with-docs ─▶ to-prd ─▶ to-issues ─▶ triage
 (optional:      (default entry:     (interrogate the   (PRD on   (vertical    (readiness
  huge/foggy      ambiguous idea      idea; decisions     tracker)  slices)      state machine
  efforts only)   → shaped work)      → decision-log)                            → ready-for-agent)
                                                   │
                                     ready work unit │ bug report │ skill/docs change
                                                   │
                                                   ▼
 any request ──▶ workflow-router ──────▶ workflow-deliver (kind = feature|bug|skill|docs)
                 │ classification         │ one kernel-gated run (workflow-ledger):
                 │ pinned by golden       │
                 │ eval (≥95%, CI:        │   worktree cut (worktree-baseline.sh)
                 │ routing-eval.yml)      │     → [diagnose — required iff kind=bug]
                 │ route card → confirm   │     → implement
                 │ → preflight →          │     → review stamp   (ledger.sh stamp review)
                 │ ledger init            │     → finalize stamp (ledger.sh stamp finalize)
                 │                        ▲
                 │        batch drivers ──┘  execute-prd  (parent PRD tree, dependency order)
                 │                           run-backlog  (independent ready issues, AFK)
                 │                           — each dispatches one deliver-run per work unit
                 ▼
              other routes (see below)      │
                                            ▼
                                    merge — guarded twice:
                                    workflow-guard.sh merge gate (local hook)
                                    + ci.yml finalize-stamp job (server-side snapshot check)
```

Owners: `workflow-router` (classification, route card, preflight, ledger
init), `workflow-deliver` (the single-unit delivery orchestrator — supersedes
`workflow-build-one` and `workflow-debug`, D-006 #11), `workflow-ledger` (every
gate), `setup-worktree` (`scripts/worktree-baseline.sh` cut/verify/emit),
`execute-prd` / `run-backlog` (batch dispatch). Inside a deliver-run, review is
`workflow-review` (judgment — returns lane files + verdict, never stamps) and
closure is `workflow-finalize` (PR body, reviewer comments, CI, reconcile,
repo-policy-controlled final action).

Bugs are a **kind, not a separate workflow**: `ledger.sh init --kind bug`
inserts required `diagnose`/`fix` steps and the kernel refuses `stamp fix`
without a captured red repro — diagnose-first is enforced by the kernel, not by
routing, so a misroute is recoverable (re-init `--kind bug`), not fatal.

## Three layers (D-006 #12)

Every skill on this map's delivery spine carries a `layer:` tag (tagging is
staged — touched skills first, per the D-006 Track C decision; untagged skills
get a lint warn, tagged-but-violating skills a lint error from
`lint-skill-suite.sh`). Determinism means something different at each altitude:

| Layer | Determinism comes from | Example skills |
|---|---|---|
| **kernel** | Scripts + tests. No LLM judgment; state files are script-owned (hooks block hand-edits); behavior fixed by `test/test-ledger.sh` etc. | `workflow-ledger` (`ledger.sh`, `forge.sh`) and its machinery: `setup-worktree`'s `worktree-baseline.sh`, the `workflow-guard.sh` hook |
| **orchestrator** | Thin sequencers whose gates are **kernel calls** — `ledger.sh init/set/stamp/check` — never prose checks or inline bash procedures. | `workflow-router`, `workflow-deliver`, `workflow-finalize`, `execute-prd`, `run-backlog`, `triage` |
| **judgment** | Evals + report contracts — golden-route evals, lane-file contracts (`model:`/`verdict:`/`reviewed_sha:`), A/B via audition. Judgment skills **never stamp**; the invoking orchestrator records the gate. | `workflow-review`, `grill-with-docs`, `wayfinder`, the `*-review` adapters |

## What gates you

Enforcement is mechanical, not honor-system. Every escape is an **audited
override** — loud, recorded, human-instructed — never a silent bypass
(D-006 #5). Owners: `workflow-ledger/SKILL.md` (ledger gates),
`dotfiles/.claude/hooks/workflow-guard.sh` (guard rules), `.github/workflows/ci.yml`
(CI check). Rules 1 and 4 bite only in opted-in repos (`docs/executions/`
present); rules 2/2b and 3 fire everywhere.

| Gate | Trigger | Escape |
|---|---|---|
| **Guard rule 1 — merge gate** | Any merge shape (`gh pr merge\|ready`, `tea`/`git-forge` merge, curl `/pulls/*/merge`) without a fresh finalize stamp → exit 2 | `stamp finalize --override --reason` on explicit user instruction; a broken kernel warns-and-permits (never bricks delivery) |
| **Guard rule 2 (+2b) — script-owned files** | Direct Edit/Write to `state.yaml` (live or snapshot) or `.worktree-baseline.*.state` sidecars → blocked | None — use `ledger.sh` / `worktree-baseline.sh`; the files are the kernel's, not yours |
| **Guard rule 3 — stderr suppression** | `2>/dev/null` (or `&>`) attached to a mutating `git`/`gh`/`tea`/`git-forge` segment → blocked | None — re-run without suppression; failures must be visible |
| **Guard rule 4 — entry enforcement** | Tracked-code edit with no active ledger run → warn (`LEDGER_ENTRY_ENFORCE=block` escalates to exit 2) | Enter the system: route via `workflow-router` / `ledger.sh init` |
| **Ledger `diagnose`** (kind=bug) | `stamp diagnose` refuses unless `repro_cmd` runs now and exits non-zero (captured) | `--override --reason` for irreproducible bugs, user-instructed |
| **Ledger `fix`** (kind=bug) | `stamp fix` refuses unless the same repro now exits 0 and a regression test exists | `--override --reason`, user-instructed |
| **Ledger `review`** | `stamp review` refuses unless: worktree verifies, chosen profile ≥ `review-floor`, every lane file exists (run-scoped path, fresh mtime) with `verdict:` line, per-lane model ≥ floor | `--override --reason`, user-instructed; escalating above floor is always legal |
| **Ledger `finalize`** | `stamp finalize` refuses unless: review stamp fresh (strict SHA, snapshot-only commits exempt), tree clean, `verify-local` green at HEAD, forge state good (CI, PR, threads) | `--override --reason`, user-instructed; stale overrides fail `check` as `OVERRIDE_STALE` |
| **CI finalize-stamp check** | `ci.yml` `finalize-stamp` job runs `scripts/finalize-stamp-check.sh` against the committed snapshot (`check-snapshot`) on every PR — catches server-side merges that never consult the local hook | Overrides ride the snapshot and stay visible in the PR; job is non-blocking during the soak week, then required |

## Other routes (pointers, not the table)

The **authoritative** classification table lives in
`workflow-router/SKILL.md` — do not extend this list, extend that table (and
its golden set). Representative lanes:

- **Ambiguous feature idea** → `workflow-feature` (default planning-tier entry; `wayfinder` only for efforts too big/foggy for a single session)
- **V1 product idea** → `v1-workflow` (gated pipeline; owns grill → design → issues)
- **Refactor-scale / migration** → `design-plan` → `execute-phase` — a specialized lane, never the default product flow
- **Repo evidence** → `repo-audit`, findings routed onward (roadmap / to-prd / to-issues) — never a standalone loop
- **Roadmap / sequencing** → `workflow-roadmap`
- **Review-only requests** → `workflow-review` (code) or the artifact-specific adapters (`sql-review`, `clarity-review`, …)
- **Ship / close out a PR** → `workflow-finalize`; **cleanup after merge** → `cleanup-delivery`
- **Skill authoring/revision** → `workflow-skill`; **skill effectiveness** → `skill-system-audit` (owns the D-006 scoreboard)
- **Session exit** → `handoff`; **reflection** → `session-insight`

## Tombstones (do not resurrect)

- `workflow-build-one` and `workflow-debug` → **`workflow-deliver`** with
  `kind=feature` / `kind=bug` (D-006 #11). The router carries legacy-name
  redirect rows; any doc or prompt naming the old skills means deliver.
- The **"Audit Loop"** is not a routable workflow. The router owns the
  translation rule (`workflow-router/SKILL.md` § Audit Loop Retirement Rule).
- Prose gate blocks (`WORKFLOW_REVIEW_GATE`, `WORKFLOW_FINALIZE_GATE`) are
  replaced by **ledger stamps** — the only valid review/finalize evidence is
  `ledger.sh stamp review` / `stamp finalize` (and their committed snapshots).
  Worktree evidence remains the `WORKFLOW_BASE_GATE` +
  `WORKTREE_BASELINE_GATE` block, but only as printed by
  `worktree-baseline.sh` — never hand-written.

When in doubt, ask `workflow-router`. Don't re-derive routing from memory — or
from this file.
