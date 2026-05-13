# Post-Mortem — Skills Updates (core-loop authoring)
**Date:** 2026-04-21
**Plan:** `~/.claude/skills/2026-04-21-skills-updates-design.md`
**Audit:** n/a — plan §0 declares "no `/repo-audit` was run, because this is skill authoring, not a repo refactor." Uses a lightweight `GAP-NN` ID scheme instead of `FIND-NN`.
**Git range:** pre-git execution; evidence drawn from tarball snapshots (`~/.claude/skills.pre-phase-{0..5}.tgz`) and `docs/executions/.phase-runs/*.md`. Post-execution commits: `b9a579e baseline` → `019414d gitignore` → `552c8f2 audit trail` (git-init happened *after* phase execution, to enable the downstream `/repo-audit` + `/design-plan` run).
**Scope:** partial — Phases 0–4 fully executed; Phase 5 preflight only, halted at Task 1 `[human]` (target-repo selection). In lieu of the planned external-repo dogfood, the skills dir was git-init'd in-place and a recursive self-audit + new plan were produced (`docs/audits/2026-04-21-repo-audit.md` + `docs/plans/2026-04-21-design.md`) — covered under §Outstanding work.

## Summary

The plan set out to close the audit → plan → retro loop by porting three Desktop skills (`/execute-phase`, `/describe-pr`, `/setup-worktree`) into globals and folding two inline fixes into `/design-plan`. Phases 0–4 landed on scope: all five `GAP-NN` items (GAP-01..05) are substantively resolved, all six SKILL.md files strict-YAML-parse, and every phase's verification passed green. Phase 5 — the integration dogfood on a real target repo — did not happen as scoped. It halted immediately at its `[human]` Task 1 gate (no target repo selected) and was substituted with a recursive self-audit of the skills dir itself, producing a fresh 15-finding audit and a follow-on 7-phase plan. That substitution is a meaningful smoke test of the full loop but it is *not* the external-repo dogfood the plan called for — six of the core loop's load-bearing contracts (`dry_run=true`, cluster grouping, `/setup-worktree` env copy, `/describe-pr` live PR apply path, full `/execute-phase` commit schema parse by `/post-mortem`) remain specification-only. Blameless framing: the substitution is the right call given the absence of a suitable target at the time; the plan's only avoidable miss was not naming the target in advance so Phase 5 could auto-proceed.

## Findings addressed

Plan used `GAP-NN` IDs (pre-audit era). Phase-by-gap resolution:

| GAP | Severity | Addressed by | Status |
|---|---|---|---|
| GAP-01 — No execution skill | high | Phase 1 pilot + Phase 2 production port → `execute-phase/SKILL.md` (527 lines) | **resolved** (spec-complete; 4 of 5 acceptance checks green; `dry_run=true` live exercise still pending per NEW-06) |
| GAP-02 — No vertical-slicing guidance | medium | Phase 4 Task 1 + Task 3 → `design-plan/SKILL.md` Step 2 bullet + self-review checklist item | **resolved** |
| GAP-03 — Trusting revise mode | medium | Phase 4 Task 2 → `design-plan/SKILL.md` Step 2 revise-mode paragraph | **resolved** |
| GAP-04 — No PR-description skill | medium | Phase 3 Tasks 1–7 → `describe-pr/SKILL.md` (290 lines) | **resolved** (spec-complete; live PR apply path pending Phase 5) |
| GAP-05 — No worktree-setup skill | low | Phase 3 Tasks 8–13 → `setup-worktree/SKILL.md` (234 lines) | **resolved** (spec-complete; live worktree creation pending Phase 5) |

All five gaps closed at the specification level. Three (GAP-01, 04, 05) have live-verification deferred — tracked as NEW-06 and the §Outstanding-work items.

## What went as planned

- **Phase 0 — Preflight.** Tarball backup, SKILL.md catalog, Desktop-source catalog, `.phase-runs/` collision check. In-phase bonus: NEW-03 (pre-existing strict-YAML bug in `design-plan` + `post-mortem` frontmatter) caught and fixed before it could bite Phase 4.
- **Phase 1 — Pilot.** 152-line stripped `/execute-phase` scaffold + contrived `/tmp/pilot-plan.md` exercised the core mechanic end-to-end against a real plan file. Both `[auto]` tasks landed; the `[human]` task was correctly surfaced, not executed. Pilot shape was the right size — big enough to surface NEW-04 and NEW-05 before production port, small enough to iterate cheaply.
- **Phase 2 — Production port.** Expanded pilot to 527 lines covering 11 procedure steps, 16 error-handling rows, 2 Example Invocation blocks, auto-proceed, scope-based isolation with orchestrator-side `git status --porcelain` diff, commit schema `phase-<N>: <Goal> (addresses <IDs>)`. NEW-04 and NEW-05 folded in as part of the port (not deferred). Strict-YAML passed on first write.
- **Phase 3 — Parallel port.** `/describe-pr` (290 lines) and `/setup-worktree` (234 lines) ported in parallel — two Write calls in one message, disjoint file scopes — following the §7 architecture rule the plan had just baked in. Zero scope violations. Both parsed strict-YAML on first write.
- **Phase 4 — Cross-skill tune.** 9 `[auto]` tasks landed as 8 targeted Edits across 3 files (design-plan: 5, repo-audit: 1, post-mortem: 2). All cross-reference greps green, all strict-YAML still parses, pairing diagrams consistent across all six skills.

## What drifted

- **Phase 5 — Integration dogfood.** *Planned:* `/repo-audit` → `/design-plan` → `/execute-phase` → `/describe-pr` → `/post-mortem` on a real small target repo, with `/setup-worktree` side-car exercise. *Actual:* preflight tarball + SKILL.md load-check only; halted immediately at Task 1 `[human]` gate (no target repo on hand). *Why:* the plan scoped "pick a small, real target repo with low-stakes pending changes" as a `[human]` decision but didn't name a candidate, so the chain couldn't auto-proceed and no decision was made in-session. *Cost:* six live-verification checks still specification-only — `dry_run=true` (NEW-06), cluster grouping (NEW-07), `/setup-worktree` env-file copy + worktree creation, `/describe-pr` `gh pr edit` apply path, `/post-mortem` FIND-NN parsing on real commits, end-to-end commit-schema round-trip.
- **Post-Phase-5 substitution — Self-audit.** Instead of an external target, the user git-init'd the skills dir itself and ran `/repo-audit` → `/design-plan` against it, producing `docs/audits/2026-04-21-repo-audit.md` (15 FIND-NN) and `docs/plans/2026-04-21-design.md` (7 phases, 47 auto + 11 human, resolves 9/15 findings). This IS a meaningful loop exercise — arguably more recursive than random — but it was not what §5.5 scoped, and it cannot validate `/execute-phase` commit-hash parsing or `/describe-pr` PR-apply paths because no phases of the new plan have executed yet. Tracked below.
- **`[human]` gates were conservative.** Phases 1/2/3 each halted on a single Task 14 "review SKILL.md" gate. In all three cases, verification had passed and auto-proceed would have been safe. For skill-authoring plans, review gates might live better as post-commit asynchronous reviews rather than chain halts.

## New findings (NEW-NN)

Nine NEW items surfaced during execution. Four resolved in-flight, five remain open:

- **NEW-01 (low, closed)** — Target-repo collision check deferred. *Source:* phase-0.md. *Status:* moot after Phase 5 substitution; the skills-dir self-audit didn't create `.phase-runs/` collisions.
- **NEW-02 (low, closed)** — Per-phase tarballs planned. *Source:* phase-0.md. *Status:* executed — `skills.pre-phase-{1..5}.tgz` all created.
- **NEW-03 (medium, resolved in-phase)** — Pre-existing strict-YAML bug in `design-plan` + `post-mortem` frontmatter (unquoted embedded quotes in `inputs:` descriptions). *Source:* phase-0.md. *Resolution:* single-quoted both offending values; all three original SKILL.md files now pass `yaml.safe_load`. Became a hard Phase 4 invariant.
- **NEW-04 (low, folded)** — `ls`-style command output truncated in subagent tool-output pipeline. *Source:* pilot-phase-1.md. *Resolution:* Phase 2 Step 5 added orchestrator-side `git status --porcelain` diff (can't be spoofed by cluster subagents), plus Tuning-note bullet advising absolute-path evidence commands. **Candidate close** after Phase 5 dogfood confirms the mechanic on a real repo.
- **NEW-05 (medium, folded)** — Outcome-file path collision when multiple plans both have a Phase N. *Source:* pilot-phase-1.md. *Resolution:* Phase 2 added `plan_slug` input with default-derivation (strip date prefix + `-design` suffix), so filename becomes `<date>[-<plan-slug>]-phase-<N>.md`, backward-compatible. **Candidate close** after Phase 5 dogfood.
- **NEW-06 (low, open)** — `dry_run=true` path never live-exercised on production `/execute-phase`. *Source:* phase-2.md. *Recommendation:* cheap close — one `/execute-phase phase=1 dry_run=true` on `/tmp/pilot-plan.md` before any real dogfood relies on it. Promote to `FIND-NN` in next audit cycle if still untested.
- **NEW-07 (low, open)** — Cluster-grouping heuristic in `/execute-phase` Step 2 is informal. *Source:* phase-2.md. *Recommendation:* watch during next real multi-file phase execution; tighten prose if orchestrator default-serializes plans that could parallelize.
- **NEW-08 (low, open)** — Duplicated branch-slug derivation between `/execute-phase` Step 1 and `/setup-worktree` Step 0. *Source:* phase-3.md. *Recommendation:* promote to a `/design-plan` §11 canonical spec; both skills reference spec instead of copy-pasting the rule. Deferrable.
- **NEW-09 (low, open)** — `/describe-pr` cannot distinguish "phase skipped intentionally" from "phase accidentally missed." *Source:* phase-3.md. *Recommendation:* `/design-plan` grows a `**Status:**` line per phase in revise mode; `/describe-pr` reads it. Deferrable to a targeted `/design-plan` enhancement plan.

## Outstanding work

- **GAP-01/04/05 live verification deferred** — not a gap in *spec*, a gap in *evidence*. Phase 5 is the place; it did not run.
- **Plan §9 Open questions:** all four resolved in-plan (Q1–Q4 marked `(Resolved.)`). No leftover decisions.
- **Phase 5 Task 1 `[human]` gate never resolved.** Open on paper; superseded by the self-audit substitution for practical purposes.
- **Six live checks still spec-only:** `dry_run=true` path (NEW-06), cluster grouping (NEW-07), `/setup-worktree` env copy + worktree creation, `/describe-pr` `gh pr edit` apply path, `/execute-phase` commit-schema round-trip under `/post-mortem`, `/describe-pr` `.phase-runs/` → PR body mapping. All surface naturally the first time `docs/plans/2026-04-21-design.md` (the new plan) executes Phase 0.
- **New plan awaiting execution.** `docs/plans/2026-04-21-design.md` (7 phases, 47 `[auto]` + 11 `[human]`, resolves 9/15 `FIND-NN`) is drafted and un-run. Its §9 has two open questions that *do* need pre-execution decisions: FIND-01 fix path (A: switch Explore → general-purpose, or B: formalize orchestrator-fallback) and Phase 4 target-repo (skills dir again vs. different repo). Defaults recorded in RESUME.md: A, skills dir.

## What I'd change in the next plan

1. **Name the target repo in the plan itself.** The single biggest avoidable cost was Phase 5 halting at an unspecified target. If `/design-plan` had forced a concrete target-repo input at plan-authoring time (or made it a required `[human]` pre-phase-0 decision), the chain could have auto-proceeded. The new plan at `docs/plans/2026-04-21-design.md` already avoids this — its Phase 4 names the target explicitly, and §9 flags the open question for pre-execution resolution.
2. **Relax "review SKILL.md" `[human]` gates to post-commit.** Three of six phases halted on identical Task 14 review gates where verification had already passed. For skill-authoring plans specifically, review is better handled asynchronously (read the diff after commit) than as a blocking chain halt. Keep `[human]` gates for *decisions* (target selection, scope changes), not for *reviews* that could be post-facto.
3. **Treat strict-YAML parse as a preflight invariant, not a Phase 4 acceptance criterion.** NEW-03 caught two bugs that had been latent in shipped SKILL.md files. The new plan's FIND-03 pre-commit hook implements this — it should stay as the long-term gate.
4. **Fold live-verification checks directly into their host phase instead of deferring to a single "dogfood" phase.** The live exercises for `dry_run`, cluster grouping, and worktree creation all bundled into Phase 5 and got stranded when Phase 5 halted. If each skill's port phase had included its own minimal live invocation (even against a scratch fixture), the loss from a dogfood halt would be smaller.
5. **Conservative `[auto]`/`[human]` tagging has a cost.** Phase 4's 9 `[auto]` tasks ran cleanly; the Phase 1/2/3 Task 14 halts each cost a session round-trip. Default `[auto]` unless there's a decision that needs judgment — errs closer to how the plan actually wanted to flow.

## Recommendations for next audit

The next audit already ran (`docs/audits/2026-04-21-repo-audit.md`, 15 `FIND-NN`). Recommendations apply to the *subsequent* audit cycle — after `docs/plans/2026-04-21-design.md` executes:

- **Focus next audit on `execute-phase/`, `describe-pr/`, `setup-worktree/`.** NEW-06/07/08/09 all cluster there; their first real execution will surface the load-bearing behaviors that this post-mortem couldn't verify.
- **Promote NEW-06 → `FIND-NN`** if `dry_run=true` remains untested after the new plan's Phase 0.
- **Re-check NEW-04 and NEW-05** — both "folded" but candidate-close; next audit's `scope=complete` check should confirm the mechanics held across a real execution.
- **Add `focus=commit-schema` scan** to next `/repo-audit`. The contract `phase-<N>: <Goal> (addresses <IDs>)` is load-bearing for `/post-mortem` and `/describe-pr`; its first real round-trip should be audited.
- **Audit the self-audit.** The recursive `/repo-audit` against the skills dir itself produced 15 findings (which informed the new plan). After the new plan lands, a third audit pass would reveal whether the first two were producing stable IDs or whether findings mutate across cycles — a core-loop health check.
