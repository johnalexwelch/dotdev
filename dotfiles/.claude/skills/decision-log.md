# Skills Corpus — Decision Log

Accepted decisions for the personal skills corpus (`~/dotdev/dotfiles/.claude/skills`). Append-only; treat entries as settled context unless explicitly reopened.

## D-001 — Extract `review-scaffolding`; reviews become thin adapters (2026-06-01)

**Decision.** Introduce a `review-scaffolding` library (`user-invocable: false`, `disable-model-invocation: true`) holding the shared review **discipline**, **severity vocabulary**, and **report contract**. The single-pass `*-review` skills become thin adapters that declare their own criteria/lens, unit of analysis, persistence, and deltas, and defer to the scaffold for everything else. Mirrors the existing `council-scaffolding` pattern.

**Scope (refined during rollout — 5 analytical adapters).** `clarity-review`, `pacing-review`, `sql-review`, `dashboard-review`, `metric-tree-review`. The dnd trio (`dnd-review`, `dnd-open-thread-review`, `dnd-player-agency-review`) was split out after reading them — see D-002.

**Excluded, with reasons.** `review`, `workflow-review`, `strategic-analysis-review` dispatch subagents → fan-out/gate family, not single-pass review (belong with the council/dispatch pattern). `receive-review` is a different verb (processing incoming PR feedback, not assessing an artifact).

**Alternatives considered.** (b) lighter "link a shared reference, no rigid migration" and (c) "leave reviews independent" were considered and rejected in favor of (a) full scaffold for cross-review consistency. Honest tradeoff accepted: unlike councils (which share a dispatch *engine*), reviews share only a *contract* — the win is consistency + one place to evolve the discipline, not shared machinery.

**Verification.** Per-adapter: criteria preserved verbatim; report shape + discipline sourced from the scaffold; a golden artifact + expected-report pair shows the review output materially unchanged before/after migration.

**Migration / rollback.** Vertical slice: migrate one review first (`clarity-review` — no graph, no persist), confirm unchanged, then the remaining 7. Rollback = revert the single adapter SKILL.md; reviews are independent, blast radius is one skill.

**Second pass.** `not_needed` — the scaffold is one reference doc; no internal submodule earns its own seam.

**Status.** Done: `review-scaffolding` created; `clarity-review` (deep thin-out — it carried the most generic boilerplate), then `sql-review`, `dashboard-review`, `metric-tree-review`, `pacing-review` (lighter touch — already domain-specific, so migration = declare adapter + defer discipline/severity/report-skeleton, keep domain criteria/output/gates). All verified.

**Open follow-up.** Host activation/resolution (linking `review-scaffolding` + adapters into `~/.claude/skills` so the deferral resolves at runtime) is the separate sub-skill-invocation-seam question (improve-codebase-architecture candidate 3), deferred.

## D-002 — dnd review trio held out of `review-scaffolding`; needs its own consolidation decision (2026-06-01)

**Decision.** The three dnd reviews are **not** migrated onto `review-scaffolding`. Reading them showed a different shape: `dnd-open-thread-review` produces a *thread inventory + status classification + `OPEN_THREADS.md` writeback* (not findings-with-fixes), and the dnd reviews use domain verdicts (Critical/High/Opportunity, thread statuses, "Safe to Run?") rather than the shared `[HIGH]/[MED]/[LOW]` severity. Forcing them under the general scaffold would distort them.

**Separate problem found.** `dnd-review` is a 3-mode skill (continuity / threads / agency) whose modes **overlap the standalone `dnd-open-thread-review`, `dnd-player-agency-review`, and `dnd-continuity-check`**. That intra-dnd duplication is its own consolidation question (one multi-mode skill vs. three standalones, or a `dnd-review-scaffolding`), to be decided separately — not bundled into the review-scaffolding work.

**Status.** Deferred; no dnd files changed.

## D-003 — One sub-skill invocation convention + resolution rule + lint (2026-06-01)

**Decision.** Adopt a single cross-skill invocation form — `Load and run \`<name>/SKILL.md\`` (workflow steps) and `follow \`<name>\``(libraries) — resolving against the **active skills root** (`~/.claude/skills`, canon behind the links). Flow-arrow prose is a map, not an invocation.`lint-skill-refs.sh` guards against hollow references (a linked skill pointing at an unlinked one). Convention documented in `CONVENTIONS.md`.

**Why.** Grounded measurement: only 3 skills used the explicit form; 30 used arrow-only prose that names skills without an invocation or a resolution rule — the gap that made `/workflow-debug` and `/grill-with-docs` hollow earlier this session.

**Status.** Shipped: `CONVENTIONS.md` + `lint-skill-refs.sh`. Lint is **clean** on the active root — the core delivery loop's explicit refs (`workflow-build-one`/`-debug`/`-finalize` → their sub-steps) all resolve, because the 14 closure links added earlier fixed them.

**Deferred (lint-driven).** Converting the ~30 arrow-only orchestrators to explicit refs (expands lint coverage); linking `CONVENTIONS.md` from `write-a-skill`; activating the review adapters (`review-scaffolding` + chosen reviews) into the active root.

## D-004 — Adopt 5 capability upgrades from the MagickPen template review (2026-06-10)

**Decision.** After mapping 173 MagickPen templates against the corpus, adopt the 5 highest-value ideas — but in the *cheapest fit form*, not all as standalone skills:

1. **`review-scaffolding` + tracked-changes** — added an opt-in **tracked-changes output** mechanic to the scaffold (not to one review), so every `*-review` adapter inherits a consistent inline-edit view. Source idea: MagickPen `article-polishing`.
2. **`clarity-review`** — opted into tracked-changes; added **protected elements** (don't edit code/tables/LaTeX) and **readability as an advisory signal only**. Explicitly **rejected** the source template's "strictness / rewrite-aggressiveness" knob — it contradicts clarity-review's stated non-rewrite philosophy.
3. **`bias-auditor` persona + `cognitive-bias-catalog.md`** — built the cognitive-bias capability as an **analysis-council persona + reference**, *not* a standalone skill, to avoid overlap with `decision-scientist`/`counterfactual-check`/`skeptical-data-scientist` and routing ambiguity. Wired into `analysis-council/roster.yml` (optional + dispatch signal + overlay).
4. **`product-launch-checklist`** — new standalone skill (clean whitespace; `workflow-roadmap` plans what to build, nothing covered shipping). Tier-sized (T1/T2/T3), guardrail-first, hands off to `report-metrics` / `post-mortem`.
5. **`okr-generator`** — new standalone skill, decision-first; **delegates KR definition + Goodhart check to `metric-design`** rather than reinventing metric rigor.
6. **`mock-data-generator`** — new standalone utility skill with a working, dependency-light Python generator (FK topological resolve, deterministic seed, dialect-aware SQL) + passing smoke test.

**Alternatives considered & rejected.** Building bias-identifier, NL→formula, commit-message, and several others as standalone skills — rejected to protect the corpus from bloat/routing ambiguity (95→ skills already). Importing the MagickPen *form* (FastAPI/SQLite scaffolding) — rejected; only the rubric/checklist ideas were taken, rendered in the decision-first house style. Legal/compliance and personal-life templates — rejected (liability + out of scope).

**Verification.** `lint-skill-refs.sh` clean for new cross-skill refs; `mock-data-generator` smoke test passes (FK integrity, determinism, cycle-detect, SQL export). Per-skill: SKILL.md under house line budget, description has "Use when" triggers, references one level deep.

**Activation (host-side, pending).** New skills authored in canon. Must be symlinked into the active root (`~/.claude/skills`) and `okr-generator` + `product-launch-checklist` added to `workflow-router` (done in canon) before they resolve at runtime — see apply/activation commands in the session handoff.

**Status.** Authored in canon; activation + git commit pending on host.
