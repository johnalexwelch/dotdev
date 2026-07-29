# Execution Report: Workflow-Router Pressure Test

**Date**: 2026-07-29  
**Purpose**: Pressure-test the routing classification table in `workflow-router/SKILL.md` against 7 canonical scenarios (vague feature, repo audit, ready issue, PRD tree, backlog batch, decision-blocked issue, refactor-scale migration). Validate routing logic, identify gaps, and flag architectural inconsistencies.

---

## Test Methodology

For each scenario, verify:

1. The classification table has a row that matches the signal.
2. The listed target skill aligns with the user's intent.
3. The cited evidence is exact and correct.
4. No shortcuts skip required gates.

---

## Scenario Results

| # | Scenario | Expected target | Actual routed target | Verdict | Evidence & notes |
|---|----------|-----------------|---------------------|---------|------------------|
| **S1** | Vague feature (`"what if we..."`, `"I want to build..."`) | `workflow-feature` | `workflow-feature` | ✅ PASS | Table row exact: *`Vague idea → ambiguous feature → workflow-feature`*. Grill → decision-log → PRD chain intact. |
| **S2** | Repo audit (`"audit the repo"`, `"state of repo"`) + must NOT skip to `execute-phase` | `repo-audit` → roadmap/PRD/issues/triage | `repo-audit → workflow-roadmap / to-prd / to-issues` | ✅ PASS | Classification table + Specialized Audit/Refactor Lane both correct. Audit produces *evidence*, not deliverables; next step determined by approver. |
| **S3** | Ready single issue (has `ready-for-agent` label + clear acceptance criteria) | `workflow-build-one` | `workflow-build-one` | ✅ PASS | Confirmed by classification table AND PRD-vs-backlog routing rule. Full execute → review → finalize chain runs. |
| **S4** | PRD parent/child tree (`"execute this PRD"`, `"implement all children of #N"`) | `execute-prd` | `execute-prd` | ✅ PASS | Classification table + PRD-vs-backlog rule both anchor this routing. Dependency ordering + vertical slices. |
| **S5** | Batch of independent ready issues (AFK backlog) | `run-backlog` | `run-backlog` | ✅ PASS | Classification table: `Multiple ready issues → AFK backlog → run-backlog`. Repo policy controls draft vs auto-merge. |
| **S6** | Decision-blocked issue (`maintainer-decision` / `operator-runtime` / `secret-custody` / `reviewer-validation` gate pending; cannot proceed to execute) | `process-needs-human-review` | **No route exists; skill undefined** | ❌ GAP | Skill `process-needs-human-review` appears in `codex-runtime-allowlist.txt` (line 11) but **no `SKILL.md` exists**. Skill directory `dotfiles/.config/agents/skills/process-needs-human-review/` does not exist. Classification table has no row for "decision-blocked" or gate-taxonomy signal matching. Codex may invoke and fail silently. |
| **S7** | Refactor-scale migration (`"multi-phase remediation"`, existing repo with approved migration brief) | `design-plan` → optionally `execute-phase` | `design-plan` (prose-only coverage) | ✅ PASS (caveat) | Specialized Audit/Refactor Lane prose is correct and clear. However, the classification *table* has no direct row for "refactor-scale migration" or "multi-phase remediation" — only prose. A table row would make automated routing tests conclusive for this scenario. |

---

## Critic Verdict

**OVERALL: PASS with CONCERNS**

### Findings summary

| Scenario | Verdict | Confidence | Notes |
|----------|---------|------------|-------|
| S1–S5 | ✅ All PASS | High | Routing logic sound; table rows precise; evidence correct. |
| S6 | ❌ GAP confirmed | High | Skill does not exist. Real routing failure if invoked. |
| S7 | ✅ PASS + caveat | High | Prose-only coverage valid but table completeness lacking. |

### Errors in analysis (corrected here)

**ERROR: Stale DEPENDENCY NOTE (factually false)**

The original analysis claimed that `human-gate-taxonomy.md` (referenced in router SKILL.md as unavailable, "not yet merged, PR #105") is a blocker for S6-A work. **The file exists and is fully authored** at `dotfiles/.config/agents/skills/_docs/human-gate-taxonomy.md`. The gate taxonomy is available now. The analysis read the stale comment in the SKILL.md itself and reported it as ground truth without file-system verification (ground-truth-over-speculation failure; see `docs/agents/habits.md`).

**Consequence**: the DEPENDENCY NOTE is not blocking. S6-A work (authoring `process-needs-human-review` skill + adding classification row) can proceed immediately using the gate taxonomy.

**Secondary issue (durable bug)**: the SKILL.md itself contains stale text at lines 237 and 248 stating that the gate taxonomy is unmerged. This is a live documentation error that will mislead future agents. **This should be corrected** (see Gaps & Follow-ups, item #4).

### Corrected findings

1. **S6 gaps are real**: skill missing, table row missing, no discoverable routing behaviour.
2. **S6 is not blocked by unavailable taxonomy** — gate taxonomy exists.
3. **S7 caveat is real**: prose-only table coverage works but isn't auditable by automated tests.
4. **SKILL.md stale text is a separate correctness hazard** and should be cleaned up.

---

## Gaps & Follow-ups

### GAP #1 (S6-A): Skill `process-needs-human-review` does not exist

**Status**: Confirmed blocker.  
**Action**: Either author the skill (describing how to triage and hand off a decision-blocked issue to a human) **or** remove the allowlist entry and document which existing mechanism (e.g., `triage`'s `needs-human-review` label flow) covers this case.  
**Dependency**: None. The `human-gate-taxonomy.md` file is available at `dotfiles/.config/agents/skills/_docs/human-gate-taxonomy.md`.  
**Follow-up Issue**: #140 (see below).

### GAP #2 (S6-B): No classification table row for decision-blocked signals

**Status**: Confirmed.  
**Action**: Add a row to the classification table in `workflow-router/SKILL.md` with precise signal wording (e.g., *`"Decision-blocked (maintainer-decision, operator-runtime, secret-custody, reviewer-validation gate), cannot execute"` → **human decision-gate** → `process-needs-human-review` or `triage` (TBD based on #50)`*) alongside skill authoring.

### GAP #3 (S7): Classification table missing row for refactor-scale migration

**Status**: Low risk (prose is clear) but reduces auditability.  
**Action**: Add a table row (e.g., *`"Multi-phase remediation", "refactor-scale migration", "broad architecture change"` → **refactor audit** → `repo-audit` or `design-plan` (if plan exists)`*) to make`workflow-router` fully table-auditable.

### GAP #4 (DURABLE BUG): SKILL.md contains stale text about `human-gate-taxonomy.md`

**Status**: Live correctness hazard.  
**Action**: In `dotfiles/.config/agents/skills/workflow-router/SKILL.md`, remove stale language at lines 237 and 248 that claims the gate taxonomy is "not yet merged". Replace with a note that `human-gate-taxonomy.md` is available at `dotfiles/.config/agents/skills/_docs/human-gate-taxonomy.md`.  
**Owner**: workflow-router skill maintainer.

### GAP #5: Allowlist / skill registry consistency (secondary)

**Status**: Design intent documented but not enforced.  
**Note**: `codex-runtime-allowlist.txt` header explicitly allows entries for "Codex-side skills with no dotdev source." This is intentional. However, if `process-needs-human-review` is intended to have behavioural specs (as S6 routing depends on it), those specs should be discoverable. Either the skill is authored here, or the router should route to an alternative that exists.

---

## Related Issues

- **#140**: `process-needs-human-review` skill is undefined; routes to it fail (opened as follow-up).

---

## Validation Status

- ✅ S1–S5 routing confirmed sound by independent cross-check.
- ✅ S6 and S7 gaps identified and documented.
- ✅ Stale SKILL.md text flagged for correction.
- ✅ Blocking dependency resolved (gate taxonomy is available).
