---
name: deep-dive-review
model: opus
reasoning: high
description: Daily AFK codebase-improvement run that scans four lenses — deepen, cut, debt, performance — ranks findings by C3 leverage, and drives the survivors through grill → specialist consensus → the full delivery pipeline. Use for "deep dive review", "daily improvement run", "clean up tech debt", "simplify the codebase", "optimize", "proactive performance", or a scheduled AFK sweep. Cross-repo; auto-detects toolchain.
---

## Contract

Consumes: codebase, git history, CONTEXT.md/ADRs when present, the per-repo ledger, `run-backlog/references/repo-delivery-policy.md`
Produces: a ranked findings report (HTML), one PR per shipped finding, an updated convergence ledger, a session-insight log
Requires: git, gh, a project test runner (auto-detected), pi-lens (for debt scan), subagent dispatch
Side effects: writes/updates `~/.deep-dive/<repo-slug>.md`; creates branches/PRs; may update CONTEXT.md/ADRs during grill (delegated to the grilled skills)
Human gates: `--mode approve` (default) waits before apply; protected repos are always human-only regardless of flag; any lens finding tagged `NEEDS_HUMAN` halts that finding

## Context

Typical workflows: scheduled once-daily AFK sweep to continuously tweak a codebase
Pairs well with: improve-codebase-architecture, ponytail (audit/debt), diagnose, workflow-autonomous-backlog
Reuses (does not reinvent): improve-codebase-architecture (deepen lens + grill + HTML scaffold), ponytail audit/debt (cut lens), pi-lens `lens_diagnostics mode=full` (debt tooling), diagnose (real perf regressions), the whole delivery pipeline below

# Deep Dive Review

One run a day. A run may surface many findings. Each finding earns its own PR or dies in the ledger.

The spine, applied to every lens: **evidence before change** (a profiler trace for perf, a characterization test for a refactor, a C3 signal for debt), **defer to the repo's own linters/tests** (spend tokens on judgment, not on rebuilding lint), **revert don't escalate** on a failed verify, **one PR per finding**. See `references/danger-zones.md` for the hard NEVER-DO list.

Invocation: `/deep-dive-review [--mode approve|auto] [--budget N]`

- `--mode approve` (default): scan, rank, and present; wait for human pick before any apply.
- `--mode auto`: process the top findings unattended, respecting the delivery policy and every `NEEDS_HUMAN` halt.
- `--budget N`: max findings to *process* this run (default 3). Scan/rank always cover the whole set.

## Step 0 — Preflight

Confirm a git repo (else abort) and a clean working tree (else abort — a daily loop never mixes its work with uncommitted human changes). Compute `<repo-slug>` from the repo name. Auto-detect the toolchain from repo files (test runner, benchmark harness, package manager) the way `diagnose`/`run-backlog` do — never assume pytest/React. Read `run-backlog/references/repo-delivery-policy.md`; if this repo is `human-only`, force `--mode approve` and say so in one line. Load the ledger at `~/.deep-dive/<repo-slug>.md` (create empty if absent).

## Step 1 — Scan (read-only, parallel)

Dispatch the four lenses as **read-only Sonnet subagents** (fact-gathering is cheap and parallel). Each returns findings as file:line evidence + verbatim snippets, never prose conclusions. Full per-lens playbooks in `references/lenses.md`.

- **deepen** — `improve-codebase-architecture` exploration: shallow modules, missing seams, untestable interfaces.
- **cut** — `ponytail audit` over the whole tree: over-engineering, dead code, reinvented stdlib, one-impl abstractions, plus `ponytail:` debt markers.
- **debt** — `pi-lens lens_diagnostics mode=full refreshRunners=all` (knip/jscpd/madge/dead-code/gitleaks/CVE) **plus** the AI-slop hunt: duplication, oversized functions, catch-all handlers that swallow errors, fake-success returns (hardcoded values that pass tests).
- **perf** — profiler-driven only. Auto-detected profiler on suspected hot paths; capture a baseline. **No speculative tuning without a trace.** A real regression (known-good state exists) routes to `diagnose`, not here.

## Step 2 — Rank + false-positive filter

Score every finding by **C3 × benefit ÷ effort** — churn × complexity ÷ coverage as the leverage signal, benefit and effort as in `improve-codebase-architecture`. Command + formula in `references/lenses.md`.

Then filter against the ledger (Step 0): drop anything already `done`, `rejected`, or `deferred`-not-yet-due — this is what makes a daily loop **converge instead of oscillate**. Add a **"looks bad but is actually fine"** section (from `tech-debt-skill`): findings you considered and deliberately reject, with the reason, so tomorrow's run doesn't re-raise them.

If nothing clears the bar: write the ledger, print **"Lean already. Ship."**, and stop.

Then render the ranked survivors as a **self-contained HTML dashboard** — reuse `improve-codebase-architecture`'s `HTML-REPORT.md` scaffold (Tailwind + Mermaid CDN, before/after cards, effort×benefit matrix), widened to the four lenses. Card-type deltas + the outcome row are in `references/html-report.md`. Write to `<tmpdir>/deep-dive-<repo-slug>-<ts>.html`, auto-open it, print the absolute path. This file is the run's living report: written now, **stamped with outcomes in Step 5**.

In `--mode approve`, present the dashboard and ask which findings to process. In `--mode auto`, take the top `--budget N`.

## Step 3 — Grill + specialist consensus (per selected finding)

For each selected finding, run the owning skill's grill in accept-recommended mode (`improve-codebase-architecture` Step 3 for deepen/cut; a lightweight grill for debt/perf). **Then do not accept the recommendation until an independent specialist panel signs off.** Full protocol in `references/pipeline.md`; it extends `workflow-autonomous-backlog` §3.1 (bounded rounds, `NEEDS_HUMAN` halt) from one critic to a role panel:

- Panel roles (read-only, no edits, no artifacts): **architecture/depth**, **ponytail (lazy/YAGNI)** — runs the ponytail audit lens over the proposed fix to keep the change minimal — **security+risk**, **performance**.
- Each reviews the accepted grill answers against evidence quality only and returns `APPROVE` / `REJECT (specific evidence gap)` / `NEEDS_HUMAN`.
- **Loop until consensus** (all `APPROVE`). Bounded: `max_rounds: 3`, no override. Same rejection class twice → `NEEDS_HUMAN`. Any `NEEDS_HUMAN` from any reviewer halts this finding and parks it in the ledger.
- Only a fully-approved finding becomes implementation work.

## Step 4 — Deliver (mandatory pipeline, in order)

Every consensus-approved finding flows through this chain **in this exact order**. `workflow-review` and `workflow-finalize` are **not skippable** — no finding merges without both.

```
/workflow-router            route the finding to the correct execution path
  → /to-prd                 turn the finding + grill decisions into a PRD
  → /to-issues              slice the PRD into grabbable vertical-slice issues
  → /triage                 label/state the issues (redundancy check first)
  → /workflow-autonomous-backlog   implement (pin behavior → apply → verify)
  → /workflow-review        MUST — independent review gate, risk-sized
  → /workflow-finalize      MUST — PR body → CI → reconcile → policy-gated final action
  → /session-insight        LOG ONLY — record META suggestions, do NOT build them
  → /cleanup-delivery       tear down branches/worktrees/labels for shipped work
```

Delivery mode: `--mode approve` stops at draft PR and waits; `--mode auto` lets `workflow-finalize` mark-ready/auto-merge only when the policy allows and all gates pass. Protected repos stay human-only.

`/session-insight` runs in **log-only** mode: it appends improvement suggestions to the skill/session ledger and never triggers a build this run — those become candidates for a *future* run, keeping today's loop bounded.

## Step 5 — Update ledger + stop

**Stamp the HTML** from Step 2: patch each card with its outcome row (`consensus`, `verdict`, `pr`) and re-open the file so the daily report shows what shipped, what parked, and what was rejected — the "once all reviews are done" view. Then write every processed finding to `~/.deep-dive/<repo-slug>.md` with its verdict (`done` / `rejected` / `deferred` / `needs_human`), evidence, and PR link. Schema in `references/pipeline.md`. The ledger is the loop's only long-term memory — a fresh run tomorrow reads it and skips settled ground. One run, done.
