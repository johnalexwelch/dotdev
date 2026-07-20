# Workflows: Overview

All work flows through the **workflow-router**, which classifies the task, confirms the route, and dispatches to the appropriate skill.

---

## Routing Map

```
┌─ Any incoming request ──────────────────────────────────────────┐
│                                                                   │
│  workflow-router                                                │
│  ├─ Check for in-progress run (state-cockpit)                 │
│  ├─ Classify request type                                       │
│  ├─ Emit ROUTE_CARD (task, workflow, preflight, budget)       │
│  └─ Wait for human confirmation                                 │
│                                                                   │
└─ Routes request to one of: ──────────────────────────────────────┘
         │
    ┌────┼────────────────────────────────────────┐
    │    │                                         │
    ▼    ▼                                         ▼
SIMPLE DEFINED                                  COMPLEX
  │      │                                       │
  │      ├─ Single ready-for-agent issue       │
  │      │    → workflow-build-one              │
  │      │       (implement → review → merge)   │
  │      │                                       │
  │      ├─ Batch of ready-for-agent issues    │
  │      │    → run-backlog (AFK)               │
  │      │       (dispatch via Codex)           │
  │      │                                       │
  │      ├─ Full PRD tree                       │
  │      │    → execute-prd                     │
  │      │       (order → iterate → close)      │
  │      │                                       │
  │      ├─ Bug report                          │
  │      │    → workflow-debug                  │
  │      │       (diagnose → fix → test)        │
  │      │                                       │
  │      ├─ Refactor / migration                │
  │      │    → design-plan → execute-phase     │
  │      │       (phased execution)             │
  │      │                                       │
  │      └─ Codebase evidence needed            │
  │           → repo-audit                      │
  │              (feeds roadmap/PRD)            │
  │                                              │
  └─ Vague feature / idea                       │
       → workflow-feature                       │
          (grill → roadmap → PRD)               │
                                                 │
                                    (AFK or interactive)
                                                 │
                                                 ▼
                                            Multi-phase
                                            delivery with
                                            human gates
```

---

## Workflow Types

### 1. Trivial / Direct Execution

**When**: Add a comment, tweak wording, generate docs, simple local inspection.

**Route**: Direct execution (no worktree, no workflow-review/finalize unless code is committed).

**Approval gates**: None for non-committed work. If code is committed, must go through workflow-review + workflow-finalize.

---

### 2. Single Issue: `workflow-build-one`

**When**: You have a single `ready-for-agent` issue and want to build it end-to-end.

**Route**: Setup worktree → Preflight → Triage → Execute (Sonnet) → Review (Opus) → User-journey QA (if UI) → Finalize → Cleanup

**Step ledger**:

```markdown
| Step | Required? | Status |
|------|-----------|--------|
| 0: Preflight | required | pending |
| 1: Triage | required | pending |
| 2: Execute | required | pending |
| 3: Review (workflow-review) | required | pending |
| 4: User Journey QA | conditional | pending |
| 5: Finalize (workflow-finalize) | required | pending |
```

**Key gates**:
- WORKTREE_BASELINE_GATE (from setup-worktree)
- WORKFLOW_REVIEW_GATE (from workflow-review, must be APPROVE)
- WORKFLOW_FINALIZE_GATE (from workflow-finalize, confirms merge + cleanup)

**Approval gates**:
- workflow-review is independent (never author reviewing own work)
- workflow-finalize is mandatory before merge

---

### 3. Batch: `run-backlog`

**When**: Multiple `ready-for-agent` issues and you want AFK execution (unattended).

**Route**: Load policy → Fetch issues → Dispatch via Codex (one context per issue) → Check outage risk → Auto-merge or draft

**Dispatch modes**:
- **AFK default**: Each issue gets its own Codex context (natural isolation, parallel-safe)
- **Interactive**: Sequential workflow-build-one for each issue

**Approval gates**:
- outage-risk-policy determines if AFK-safe; high-risk issues are flagged for human review
- repo-policy determines auto-merge vs draft
- Each issue still requires workflow-review + workflow-finalize internally

---

### 4. Feature from Idea: `workflow-feature`

**When**: You have a vague idea ("dark mode toggle") and want to turn it into ready-to-implement issues.

**Route**: Grill → Roadmap (human gate) → to-prd → to-issues → Triage → Ready-for-agent labels assigned

**Step ledger**:

```markdown
| Step | Required? | Status |
|------|-----------|--------|
| 0: Grill with docs | required | pending |
| 1: Decision log | optional | pending |
| 2: Quick spike | optional | pending |
| 3: workflow-roadmap | required | pending | ← HUMAN APPROVAL
| 4: to-prd | required | pending |
| 5: to-issues | required | pending |
| 6: Triage | required | pending |
```

**Approval gates**:
- workflow-roadmap: Human decides to proceed, pause, or reject
- to-prd: PRD is written and posted as GitHub issue
- to-issues: Decomposed into vertical slices, each with clear acceptance criteria
- Triage: Issues labeled, briefs written

**Output**: Multiple `ready-for-agent` issues ready for workflow-build-one or run-backlog.

---

### 5. Bug: `workflow-debug`

**When**: Bug report with uncertain root cause.

**Route**: Diagnose → Fix → Regression test → Review → Finalize

**Diagnosis modes**:
- **Quick**: Single likely cause, skip ranking, jump to fix
- **Standard**: Full loop (reproduce → minimize → rank → test → fix)
- **Production**: Read-only first, rollback plan required
- **Regression**: Use git bisect between known-good and broken

**Output**: Diagnosis artifact (`docs/diag-<date>-<slug>.md`) that proves understanding, then normal code review.

**Approval gates**:
- workflow-review: Independent reviewer verifies fix
- workflow-finalize: Merge + regression test deployed

---

### 6. Full PRD Tree: `execute-prd`

**When**: Parent PRD issue (#N) with dependent child issues.

**Route**: Analyze children → Order by dependency → For each child: setup-worktree → Implement → Review → Finalize → Reconcile parent → Final handoff

**Dependency handling**:
- **Linear**: Execute children in sequence
- **Parallel**: Execute independent children in parallel (AFK mode uses Codex dispatch)
- **Blocked**: Child waits for parent completion before starting

**Approval gates**:
- Each child issue goes through workflow-review + workflow-finalize
- Parent issue status updated by reconcile-issues
- On halt: handoff artifact with all PRs + evidence for resumption

---

### 7. Refactor / Migration: `design-plan` + `execute-phase`

**When**: Large refactor, migration, or architecture change.

**Route**: 
1. **design-plan**: Turn requirement into phased plan with FIND/PLAN/EXECUTE structure
2. **execute-phase**: Run one or more phases end-to-end
3. Repeat for each phase until complete

**Phased structure**:

```markdown
## Phase 1: Prepare
- Task 1: Set up infrastructure
- Task 2: Data migration dry-run

## Phase 2: Migrate
- Task 3: Cutover primary
- Task 4: Verify integrity

## Phase 3: Cleanup
- Task 5: Remove old code
- Task 6: Deprecate APIs
```

**Approval gates**:
- design-plan: Architecture decision reviewed
- Per-phase: Separate worktrees and review gates
- execute-phase: Requires decision-ref integrity gate

---

### 8. Codebase Audit: `repo-audit`

**When**: You need evidence about repo state (code quality, coverage, architecture debt, test gaps).

**Route**: repo-audit → Feeds roadmap/PRD/design-plan (not a delivery workflow)

**Output**: Audit report with findings, risk categories, and prioritized improvement opportunities.

**Key**: repo-audit is discovery, not execution. Its output informs which workflows to run next.

---

## Decision Framework

### Budget: Choosing Execution Size

| Budget | When | Review Profile | Agent Count |
|--------|------|---|---|
| **direct** | Trivial, no delivery gate | none | 1 |
| **one-reviewer** | Standard code change, skill/config update | fast or standard | 1 |
| **multi-lane** | Auth, data, infra, migrations, public APIs, broad refactors, dependencies, UX | full | 2+ |
| **team** | Two+ independent workstreams benefit from parallelism | per-lane | 3+ |

**Independence matters more than agent count.** Don't use multi-lane just because the workflow mentions "review"; use the right review profile within one-reviewer.

### Risk-Sized Review Profiles

| Profile | Reviewers | Model | When |
|---------|-----------|-------|------|
| **fast** | 1 Sonnet | sonnet | Docs, comments, config, wording |
| **standard** | 1 Opus (independent) | opus | Normal code, internal APIs, features |
| **full** | Multi-lane Opus | opus | Auth, data, infra, migrations, public APIs, large diffs, concurrency |

**Independent review rule**: The reviewer must never be the author. If you implemented it, someone else reviews it.

---

## Common Paths

### "I have an idea"
```
workflow-feature
  → grill-with-docs (stress-test against docs)
  → workflow-roadmap (human gate)
  → to-prd (write as GitHub issue)
  → to-issues (decompose into slices)
  → triage (label + brief)
  → workflow-build-one (or run-backlog) for each issue
```

### "I have a ready issue"
```
workflow-build-one
  → setup-worktree
  → preflight
  → execute (Sonnet)
  → workflow-review (independent, Opus)
  → user-journey-qa (if UI)
  → workflow-finalize
  → cleanup-delivery
```

### "Bug report with unknown root cause"
```
workflow-debug
  → diagnose (reproduce → minimize → rank → test → fix)
  → docs/diag-*.md (diagnosis artifact)
  → workflow-review
  → workflow-finalize
```

### "Large refactor"
```
design-plan
  → phases: [Prepare, Execute, Cleanup, ...]
  → execute-phase (for each phase)
    → setup-worktree
    → implement tasks
    → workflow-review
    → workflow-finalize
  → repeat until all phases done
```

### "Multiple ready issues, unattended"
```
run-backlog
  → dispatch via Codex (one context per issue)
  → each issue: workflow-build-one (internal)
  → auto-merge or draft (per repo-policy)
```

---

## Approval Gates Summary

| Gate | When | Who | Can block? |
|------|------|-----|-----------|
| **ROUTE_CARD** | workflow-router | Human | Yes (don't proceed if not ready) |
| **WORKFLOW_REVIEW_GATE** | workflow-review | Independent reviewer (Opus) | Yes (REQUEST CHANGES halts) |
| **WORKFLOW_FINALIZE_GATE** | workflow-finalize | Delivery automation (checks CI, repo-policy) | Yes (CI failure halts) |
| **workflow-roadmap (feature)** | workflow-feature step 3 | Human | Yes (approves roadmap or rejects) |
| **outage-risk-policy** | run-backlog | Policy file (per-repo) | Yes (flags risky issues for human) |
| **repo-policy** | run-backlog | Policy file (per-repo) | No (determines auto-merge vs draft) |

---

## State Tracking

Every workflow records its progress in `docs/executions/state.yaml`:

```yaml
run_id: wf-20260115-feature-dark-mode
status: active|paused|completed|failed
workflow: workflow-feature
issue: 123
steps:
  - name: grill-with-docs
    status: completed
    evidence: docs/decision-log.md
  - name: workflow-roadmap
    status: pending
    evidence: null
  - name: to-prd
    status: blocked
    reason: "awaiting roadmap approval"
```

If a session is interrupted, the next run checks this file and offers to resume from the frontier (verifying against git to detect stale state).

---

## See Also

- [Architecture: System Design](/openwiki/architecture/system-design.md) — Hooks, gates, skills, concurrency
- [Skills Guide](/openwiki/skills-guide/overview.md) — All ~90 skills and categories
- [Decision Log](/docs/decision-log.md) — Architectural decisions made during design
- [AI_ENVIRONMENT.md](/AI_ENVIRONMENT.md) — Original overview (this wiki is derived from it)

