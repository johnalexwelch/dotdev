# Refactor Proposal — Skill Suite + dotdev (for review)

**Date:** 2026-07-20
**Inputs:** [2026-07-20-skill-suite-audit.md](2026-07-20-skill-suite-audit.md) (F-1…F-8), [2026-07-20-repo-audit.md](2026-07-20-repo-audit.md) (FIND-09…FIND-42, MOD-01…08)
**Status:** PROPOSAL — nothing below has been executed. Per workflow-router, execution routes through `design-plan` (phased) after owner approval; each phase lands via worktree + PR.

## The one-sentence diagnosis

The suite's content is largely sound; the failures are all in the **meta-layer**: three routing authorities that don't defer to each other, a router that can't reach half the corpus, gates written as prose with zero mechanical enforcement, and 2–3 divergent copies of every skill per session — while the repo's own quality machinery (CI, tests, OpenWiki) is silently dead and therefore can't catch any of it.

## Decisions only you can make (blocking)

**D1 — Routing authority model** (fixes F-1/F-2, the "Claude skips my workflows" root cause). Recommended: **hybrid** —
- `workflow-router` keeps sole authority over *delivery* work (anything that mutates code / commits / PRs / AFK), enforced mechanically (D2), not by prose.
- Non-delivery clusters (analytics, incident, docs, discovery, writing) get either router rows or an explicit documented "catalog tier: invoke directly, no routing" — no more silent orphans.
- OMC keyword auto-fires: disable the keyword-detector hook (keep explicit `/oh-my-claudecode:*` invocation) — it mis-fired on this very session's opening prompt.
- `superpowers:using-superpowers`: demote to advisory beneath the router (or disable the plugin) — its "invoke before ANY response, no confirmation" directly contradicts your Route Confirmation Gate.
- Alternatives: (a) router-supreme for everything (max consistency, heavy ceremony for non-delivery work); (b) status quo + docs (rejected — evidence shows prose doesn't hold).

**D2 — Mechanical enforcement posture** (F-3, FIND-31): enable branch protection on `main` (PR required; you merge), make CI hooks check-only so green is achievable, wire `test/run-tests.sh` into CI, implement the already-accepted D-005 worktree script. Cost: no more direct pushes to main.

**D3 — FIND-09 leaked SSH key** (highest severity item anywhere): confirm the ollama key is revoked/rotated, then decide on history rewrite (`git filter-repo` + force-push; destructive, breaks clones). I can verify authorized_keys usage and prep the rewrite, but the decision is yours.

**D4 — Org-inline plugin duplication** (F-4): ~76 duplicate skill exposures come from ClassDojo-org "inline" plugins (no local file to edit). Options: reconcile with org admin (remove personal-skill snapshots from org config), or accept and rename local skills to avoid collisions. Needs your knowledge of who owns that org config.

**D5 — Meta-layer diet** (FIND-37/38 + overkill): pick ONE decision mechanism (recommend: keep `docs/decision-log.md`, fold ADR-0002's content in, delete the two untracked ADR dirs); set a retention policy for `docs/executions/`; enforce-or-drop the "no reflections" rule (currently violated 9×); SB-020 rename (`workflow-effectiveness-audit` → `skill-system-audit`?) — blocked on you picking a name.

## Pre-approved-by-evidence work (no real decision content — will execute once you green-light the plan)

- **Phase 1 — Stop the bleed (repo):** rebuild `better-sqlite3` for OpenWiki + de-mask its "OK" log (FIND-32); fix/delete `test-tmux-dev.sh` (FIND-30); regenerate `.secrets.baseline` (FIND-29); land the in-flight symlink refactor atomically with the `.pre-commit-config.yaml` path fix (FIND-33+34 — must be one commit); drop stashes + `git gc` after review (FIND-35, you confirm stashes are disposable).
- **Phase 2 — Router rewrite (skills):** route to owning orchestrators not mid-chain steps, add ship/finalize row (SB-021); add rows/catalog-tier per D1; fix `writing-beats` + `write-to-obsidian` broken refs; `workflow-executive-doc` → `humanizer-exec` wiring fix (F-7).
- **Phase 3 — Consolidation (skills):** retire the 6 self-declared-dead skills (`v1-idea-grill`, `review`, `pr-review`, `spec-review`, `pr-responder`, `slop-cleaner`) with redirect stubs; empty Codex `deprecated/`; fix Codex `lint-skill-refs.sh` retired-path bug at source; wire `sync-codex-skills.sh --apply` into `ai-setup.sh`; regenerate skills-index; add 3 missing contract sections.
- **Phase 4 — Ship the SB queue:** SB-028 global habits pointer first (2 recurrences, one-line edit), then SB-027/023/024, SB-030–SB-038 per backlog order.
- **Phase 5 — Doc truth (repo):** delete or rewrite the 5 stale template docs (FIND-39); fix README LICENSE link + broken `pr-sizing-policy` symlink (FIND-41); track CONTEXT-MAP + agents CONTEXT.md (FIND-40); apply D5.

## Sequencing & routing

Phase 0 = D3 (security, immediate). Phases 1–5 as above; D1/D2 decisions gate Phase 2. Execution route: `design-plan` on this proposal → per-phase worktree branches → `workflow-review` → `workflow-finalize`, honoring the right-sized-PR policy (300–500 lines/PR) and accepted decisions D-001…D-005.

## Explicitly NOT proposed

- No pruning of skills based on "looks unused" — no usage telemetry exists, and the 2026-06-21 archive-pass reversal set the bar (invocation history + replacement coverage + your approval + rollback).
- No touching the distinct-by-design clusters verified as non-duplicative (handoff/session-insight/post-mortem/incident-retro, diagnose/workflow-debug, implement/build-one/execute-phase/execute-prd, decision-log/decision-memo, herdr pair).
- No re-flagging the deliberate exclusions from the 2026-07-09 audit (dbt absent from Brewfile; no CONTEXT.md for dotdev).
