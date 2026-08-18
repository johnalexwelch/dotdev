## Summary

Phase 0 of D-006 (deterministic workflow enforcement): the `workflow-ledger` kernel. Gates stop being prose the model complies with and become script-verified stamps hooks can block on.

- **`workflow-ledger` library skill** (`layer: kernel`) — `ledger.sh` (init / set / stamp / check / reconcile / preflight / review-floor / verify-local / show / close) with validated step transitions, checked-vs-attested gate fields, content-verified freshness, audited overrides, gate-type/AFK enum. Live state in the git dir (survives `reset --hard`); committed snapshots at stamp points. Absorbs `_docs/step-ledger.md` + `state-cockpit.md` + `human-gate-taxonomy.md` (pointer lines added).
- **`forge.sh`** — origin-detecting shim (gh / Forgejo / offline mock): ci-status, pr-state, threads-resolved, pr-for-branch.
- **4 workflow-guard rules** — merge blocked without a fresh finalize stamp (fail-open on kernel *breakage*, per D-006 #5); state.yaml writes blocked (script-owned); stderr-suppression on mutating git/gh blocked; entry warn on tracked-code edits with no active run (block-escalation deferred to Phase 5). `Edit|Write` matcher registered in settings.
- **Two-lane TDD build**: red suite first (`fdbfc29`), implementer forbidden from `test/**`; every test-lane change human-approved and separately committed (`a421aee`, `e2bbe8e`, assert in `6b1cb86`).
- **Baselines committed** (pre-change): gate coverage **0%** across last 40 merged PRs; router golden eval **90%** (failure mode: collapse-to-direct). D-006 + addenda + ratified #4 refinement in the decision log.

## Review

Independent `workflow-review`, `full` profile: 6 opus lanes (security, logic, tests, style, architecture, acceptance) → R1 REQUEST_CHANGES (6 must-fixes, all independently reproduced) → fixes → R2 (1 residual) → R3 **APPROVE**. Final gate block:

```
WORKFLOW_REVIEW_GATE:
  workflow_base: main @ 915ab21 (branch cut from local main; origin/main at 63bc55f)
  worktree_baseline: 915ab21 -> claude/skills-workflows-deterministic-fa06ac @ .claude/worktrees/skills-workflows-deterministic-fa06ac
  skill_loaded: true
  review_profile: full (R1/R2) + fast delta confirmation (R3, scoped to 6b1cb86)
  independent_review: true
  model_used: R1 lanes anthropic/claude-opus-4-5 (pinned); R2/R3 delta verification + synthesis claude-fable-5
  required_lanes: security/logic/tests/style returned (R1) + closures repro-verified (R2/R3)
  conditional_lanes: architecture + acceptance returned (R1), verified closed (R2)
  verdict: APPROVE
```

**Bootstrap exception (D-006 #16):** this PR carries no ledger stamp by design — Phase 0 is reviewed under prose workflow-review; the exception expires when this merges. Every later phase PR must carry stamps.

## Test plan

- `test/run-tests.sh`: 7 suites, 250 assertions, 0 failed (ledger 102, forge 20, guard-rules 36 + priors)
- shellcheck clean at repo gate config; `lint-skill-suite` failures=0; `lint-skill-refs` 0 dangling
- Adversarial repros verified by three review rounds: subject-spoofed commits read STALE; mixed commits STALE; reset-backwards STALE; mock stamps refused without sentinel and self-marked with it; preflight catches hidden tools; model floors reject downgrades and unknown ids

## Notes

- Two pre-existing local-main commits ride along (`915ab21` mlops-engineer patterns, `b7aea54` reflections doc) — they were ahead of origin/main when this branch was cut.
- **Merge order**: this PR first, then #157 (cites D-006 d14), then #158/#159.
- Follow-ups (tracked, non-blocking, land through the ledger once merged): stale-lane-file binding, repro_tail redaction, FORGE_TOKEN argv, reconcile ground-truth comparisons, security lane on pattern-raised floors, distinct env-error exit code for the hook permit class, direct pr-for-branch forge tests, mock-filename slash handling, preflight prose false-fails, guard rule 3 segment scoping, skills-index generator emphasis style.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
