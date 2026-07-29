# Session Reflection: deep-dive-review build & certification
**Date**: 2026-07-29
**Goal**: Build the deep-dive-review skill and certify it (structure, triggers, discipline).

## What Went Well
- Applied `skill-evaluator` correctly to a multi-phase orchestrator: routed to trigger-accuracy + pressure-battery instead of a single-run delta.
- Trigger/routing eval: 32/32 correct across 8 should-fire + 8 keyword-sharing near-misses, 2 cold raters, perfect agreement. The two hardest seams held (proactive-perf vs regression→diagnose; daily-sweep vs single-shot→improve-codebase-architecture).
- Pressure battery exposed real value: baseline (no-rules) agents **deleted an auth-check trust seam** and **stashed-around a dirty tree** under authority+convergence pressure; with-skill runs held 24/24. The rules earn their load where damage is highest.
- Closed loop: the perf-baseline-before-recommendation change made earlier this session was independently validated by Scenario B (with-skill 3/3 parked instead of speculatively optimizing).

## What Went Wrong / Friction
- **Drift**: session started as "build the skill" and sprawled into running it on iris plus hours polishing the HTML dashboard. User flagged it explicitly ("work had drifted from the original goal").
- **No goal pinned**: `get_goal` returned none for a multi-hour, multi-artifact build. Nothing anchored scope, so drift was invisible until called out.
- **Dogfood violated the skill's own NEVER**: the iris run bundled 4 findings (history cap + CI hardening + JWT scrub + dead-code) into **one PR**, contradicting deep-dive-review's "one PR per finding." The skill did not prevent this under manual drive.
- **Proxy reliance**: `gh` could not resolve iris this turn (active account switched to johnalexwelch) → leaned on session memory for PR #1589's shape. Earlier same pattern: the skill first existed only under `~/.codex` and not `~/dotdev`, caught only by an authoritative filesystem check.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | Session drifted from the build goal | No goal pin; scope creep into dogfood + dashboard | `docs/agents/habits.md` (goal-pin habit) |
| 2 | Perf baseline before the *recommendation*, not just before the change | Perf-lens wording too loose | `deep-dive-review/references/lenses.md` (fixed this session) |
| 3 | Decision reasoning required on *anything* demoted/deferred, not just card A | html-report spec too narrow | `deep-dive-review/references/html-report.md` (fixed) |
| 4 | Add test/doc reconciliation + a final necessity gate | Pipeline missing steps | `deep-dive-review/SKILL.md` (fixed) |

## Lessons
1. **Pin a goal for multi-hour builds.** Drift is invisible without an anchor; `get_goal` returning none was the tell. Create the goal up front, re-check on any scope shift.
2. **Certify orchestrators with trigger-routing + baseline-vs-skill pressure battery.** Cheap, and the baseline arm is what proves the rules matter (it deleted an auth seam). A with-skill-only run would have looked perfect and proven nothing.
3. **A dogfood run must obey the skill's own NEVER list or it is invalid evidence.** Bundling 4 findings broke one-PR-per-finding, so the integration run can't certify the delivery discipline it violated.

## Proposed Improvements
- [ ] `deep-dive-review/SKILL.md` — add a hard pre-finalize assertion: **one finding = one branch/PR**; if bundling is attempted, HALT `needs_human`. The only real run violated this. (priority: high)
- [ ] `skill-evaluator/SKILL.md` — add two named orchestrator recipes proven here: (a) cold N-rater trigger-routing accuracy over the skill catalog with keyword-sharing near-misses; (b) with-skill vs no-rules pressure battery for NEVER lists, scored as a delta. (priority: med)
- [ ] `docs/agents/habits.md` — `create_goal` at the start of any multi-hour or multi-artifact build; re-check `get_goal` when the task shifts (build → run → polish). (priority: med)

## Skill Extraction Candidates
<!-- none: the trigger-routing and pressure-battery recipes belong to skill-evaluator (fold in), not a new skill. Fails the "new skill" gate because an owner already exists. -->
