# Workflow Effectiveness Audit — Skill Suite Structure & Compliance

**Date:** 2026-07-20
**Requested by:** Alex ("evaluate my skill suite — structure, connectivity, duplication, and why Claude keeps not following my workflows")

## Scope

- **Window:** 2026-07-09 → 2026-07-19 execution artifacts + current skill definitions (2026-07-20 state)
- **Sources:** all 16 `docs/executions/reflections/*.md`, 8 `docs/executions/handoffs/*.md`, `skill-backlog.md` (SB-001–SB-038), `2026-07-15-agent-agnostic-refactor-plan.md`, `architecture-reviews/2026-07-17-workflow-skills.html`, `docs/adr/0002`, both decision logs, `_docs/{AUDIT_REPORT,CONVENTIONS,decision-log}.md`, canonical skill source (`dotfiles/.config/agents/skills/`, 93 skills), `~/.codex/skills`, plugin caches, both lint scripts (run), `call_dag.py` (run), OMC keyword-detector source, `using-superpowers` source
- **Workflows audited:** router coverage + connectivity of the full suite; step compliance from documented sessions; sync health across the three runtime surfaces

## Scorecard

| Dimension | Rating | Evidence | Recommended fix |
|-----------|--------|----------|-----------------|
| Routing accuracy | **RED** | 48/93 skills (52%) unreachable from `workflow-router`; router routes to mid-chain steps (`receive-review`, `prompt-builder`) skipping owner gates (SB-021 open); no ship/finalize row; keyword-detector false fires (incl. this session: audit request mis-routed to `ai-slop-cleaner`) | Router table rewrite + one-authority decision (see F-1, F-2) |
| Step compliance | **RED** | `workflow-finalize` loaded then skipped entirely (2026-07-19 reflection, 4 user challenges to reach root cause); `cleanup-delivery` hand-rolled → destroyed own cwd (2026-07-17) | Mechanical gates over prose (see F-3) |
| Verification quality | YELLOW | Proxy-over-ground-truth twice in the window (toon "unused" disproved by live warning; handoff "proof" disproved in edge contexts) | Already captured as habits; needs global CLAUDE.md pointer (SB-028) |
| Handoff quality | YELLOW | Handoffs exist and are structured, but 2 of 3 2026-07-17 handoffs contain stale claims (candidate-1 grill actually done per D-005; candidate-3 already landed) | Handoffs should record decision-log refs, not restate status |
| Sync health | **RED** | Codex copy: 6+ stale files incl. `workflow-router` (checksum mismatch) and a real bug in its `lint-skill-refs.sh` (checks retired path, silently degrades); org-inline plugins re-expose ≥76 duplicate skills with no on-disk manifest; the router copy served to this very session lacks the Route Confirmation Gate present in stow | One canonical source + explicit sync policy (see F-4, F-5) |
| Review coverage / resolution, issue hygiene, autonomous backlog safety | not assessed | No PR/AFK-run evidence pulled in this window (audit focused on structure per request) | Re-run scoped audit after refactor if desired |

Lint ground truth: `lint-skill-refs.sh` — 22 refs, 0 dangling. `lint-skill-suite.sh` — 0 failures, 4 warnings (`find-skills`/`rowan`/`herdr` missing contract sections; `_docs/skills-index.md` stale).

## Findings

### RED

**F-1 — The router can't route half the suite.** 45/93 skills reachable (32 direct + 12 chain + router itself); 48 orphans. Entire clusters have zero router rows: analytics (metric/dashboard/SQL/experiment/lineage ×14), incident response (`incident-retro`, `incident-triage`), docs (`docs-audit`), discovery (`wayfinder`, `find-skills`, `setup-skills`), workspace (`herdr`, `herdr-launch`). Some orphans are by design (shared infra like `review-scaffolding`, `council-scaffolding`, `graph-first`, `_personas`), but "analyze this metric" or "there's an incident" currently has no route at all. *Why it matters:* ADR-0002 declares the router the sole authority while its table covers 48% of the corpus — the system guarantees off-router behavior for half of real requests.

**F-2 — Three routing authorities with no arbitration, and each has drifted from its own spec.** (a) `workflow-router` (route card + confirmation gate); (b) `superpowers:using-superpowers` ("MUST invoke any ≥1%-relevant skill before ANY response" — no confirmation, different bug entry point than the router's mandated `workflow-debug`); (c) OMC keyword-detector regex hooks with their own parallel escalation logic (`applyRalplanGate`), firing on bare words. Observed consequences: this session opened with a false `ai-slop-cleaner` fire on an audit request; deployed CLAUDE.md documents a `deslop` trigger that doesn't exist in the installed detector (spec/implementation drift within layer c). *Why it matters:* this is the primary structural cause of "Claude opted not to follow my workflows" — the layers disagree about who fires first and none defers to the others.

**F-3 — Skill prose is advisory; nothing mechanical enforces gates.** Root-caused in `reflections/2026-07-19-skill-compliance-no-mechanical-enforcement.md`: agent loaded `workflow-finalize` (whose first instruction is the step ledger) and skipped straight to merge checks; `main` had zero branch protection at the time (live 404 on the protection API). Companion case: `cleanup-delivery` skipped in favor of hand-rolled commands that removed the shell's own cwd (2026-07-17). *Why it matters:* structure/duplication fixes won't change compliance unless load-bearing gates move from markdown into mechanical enforcement (branch protection + required checks; real scripts like the accepted-but-unimplemented D-005 worktree script).

**F-4 — Duplicate exposure: one skill, up to three divergent copies per session.** 93 canonical skills → 116 in Codex (+ unmanaged `deprecated/` cruft: 11 dirs not covered by the allowlist policy) → ~218 plugin-cache copies → 143 org-inline plugin skills with **no on-disk file**, of which ≥76 (~53%) duplicate a skill already exposed in the same session (`humanizer` ×3; `workflow-router` ×3 with one copy divergent; `dojo-brain` and `anthropic-skills` duplicate 14 skills *between themselves*). *Why it matters:* the model picks among near-identical names; which copy loads determines which gates exist (demonstrated this session — the served router copy had no Route Confirmation Gate).

### YELLOW

**F-5 — Codex sync is manual, one-way, and stale.** `sync-codex-skills.sh` is not wired into `ai-setup.sh`; real drift confirmed in `brain-ops`, `session-insight`, `slack-update`, `workflow-router`, 17/18 persona files, and a genuine bug in Codex's `lint-skill-refs.sh` (checks the retired `dotfiles/.claude/skills` path). Claude side is drift-proof by construction (symlink chain verified).

**F-6 — Confirmed dead/duplicate skills to retire or fold** (consolidation candidates; no usage telemetry exists, and the 2026-06-21 archive-pass reversal warns against pruning on structure alone — these are the ones whose *own text* declares them superseded):
- `v1-idea-grill` — frontmatter says DEPRECATED, superseded by `grill-with-docs`
- `review` — self-declared deprecated → `workflow-review`
- `pr-review`, `spec-review` — single-shot reviewers superseded by `workflow-review` (architecture candidate 6)
- `pr-responder` — restates `receive-review` step 4 (candidate 5)
- `slop-cleaner` — claims "canonical" but orphaned; `humanizer` owns the route
- Codex `deprecated/` folder — 11 stale dirs, several now living as `core:*` plugin skills

**F-7 — Wiring bugs (small, concrete):** `workflow-executive-doc` Flow calls `humanizer` where its design doc says `humanizer-exec`; `workflow-router` references nonexistent `writing-beats`; 4 skills reference `write-to-obsidian` which is absent from the canonical source (exists only as an org plugin skill); `_docs/skills-index.md` stale; 3 skills missing contract sections.

**F-8 — Accepted designs not implemented (the refactor backlog that already exists):** D-005 worktree `cut/verify/emit` script (grill done, 0 code; ~20 callers duplicate the invariant), Step Ledger collapse (~17 copies, analysis only), Gate Evidence schema unification (not started), plus open SB items: SB-028 global habits pointer (2 recurrences), SB-027, SB-023, SB-021 router table, SB-024, SB-020 rename (blocked on user naming decision), SB-030–SB-038.

### GREEN

- Claude runtime symlink chain (`~/.claude/skills → ~/.config/agents/skills → dotdev stow source`) — verified drift-proof; the 2026-07-16/17 path-confusion fixes landed.
- The 2026-07-15 agent-agnostic refactor is fully complete (all 6 phases DONE, verified against commits).
- Cross-skill reference lint: 0 dangling among active skills; conventions (D-003 invocation grammar) exist and are mostly followed.
- The reflection/handoff/decision-log pipeline itself works — this audit was largely assembled from evidence the system captured about its own failures, which is the system working as designed.
- Distinct-by-design clusters verified as NOT duplicative: handoff/session-insight/post-mortem/incident-retro; diagnose/workflow-debug; implement/build-one/execute-phase/execute-prd; decision-log/decision-memo; herdr/herdr-launch.

## Repeated Corrections (pattern → owner to update)

1. **Unscoped filesystem searches / ignoring already-read context** — 2+ sessions (SB-028, SB-036 folded in). Fix location: global `~/.claude/CLAUDE.md`, not repo-local habits (the pointer never shipped globally).
2. **Silent multi-path exploration reading as "stuck"** — 2 sessions (SB-031). Fix: narration rule in the searching skills.
3. **Proxy-over-ground-truth verdicts** — 2 consecutive sessions. Fix: already a habits rule; needs the same global pointer as (1).
4. **Descriptive-not-causal answers to "why didn't you…"** — 2 sessions; no owner yet.

## Follow-up Work (input to the joint refactor plan — user review required before any edits)

1. **Decide the one-authority model** (F-2): either demote `using-superpowers` + OMC keywords to advisory-only beneath the router, or shrink the router's claim to delivery workflows only and give the rest of the corpus a lighter catalog. This is the load-bearing decision; everything else follows.
2. **Rewrite the router table** (F-1, SB-021): route to owners not mid-chain steps; add ship/finalize row; add rows (or an explicit "catalog, not routed" tier) for analytics/incident/docs clusters.
3. **Mechanical gates** (F-3): branch protection on `main`, implement D-005 script, convert step-ledger prose to a required check where feasible.
4. **Collapse duplicates** (F-6): retire the 6 self-declared-dead skills; empty Codex `deprecated/`; reconcile the org-inline plugin snapshot with ClassDojo admin or accept and document it.
5. **Fix sync** (F-5): wire `sync-codex-skills.sh --apply` into `ai-setup.sh` (or a hook), fix Codex linter path at source, re-sync.
6. **Small wiring fixes** (F-7): one PR.
7. **Ship the open SB queue** in backlog order (SB-028 first — one-line edit, 2 recurrences).
