# Reviewer roster, subagent mapping, and progress-ledger spec

Load this only when you need the full lane catalog or the step-ledger format. The profile table in SKILL.md already tells you which lanes a profile requires; this file is the detail.

## Full reviewer roster (lane → focus → default)
- Security Auditor — vulns, injection, auth bypass, data leaks, secrets, OWASP — always for code
- Logic & Edge-Case Reviewer — business logic, edge cases, null/empty/error states — always
- TDD/Test Coverage Agent — behavior-proving tests, regression/integration coverage — always for behavior changes
- Syntax/Style Guide Expert — lint rules, naming, formatting, local idioms — always for code
- Performance Specialist — complexity, queries, hot paths — conditional: loops/queries/large data/jobs/caching
- Documentation Reviewer — docs/docstrings updated — conditional: public APIs, config, non-obvious behavior
- Architecture Reviewer — coupling, cohesion, boundaries, dep direction — conditional: multi-file, new abstractions, shared modules
- Backward Compatibility Reviewer — API contracts, persisted data, migrations — conditional: APIs/schemas/config/migrations
- Concurrency & State Reviewer — races, retries, idempotency, transactions — conditional: async/stateful/jobs/caches/distributed
- Observability Reviewer — logs, metrics, traces, alertability — conditional: prod paths, failure handling, infra
- Release/Rollback Reviewer — flags, rollout safety, revertability — conditional: risky releases, migrations, infra
- Dependency/Supply-Chain Reviewer — new packages, lockfile, licenses — conditional: dependency/lockfile changes
- Product/Acceptance Reviewer — meets issue/PRD acceptance, no scope drift — conditional: issue/PRD-backed work
- Frontend/UX/A11y Reviewer — accessibility, responsive, UX consistency — conditional: frontend/user-facing
- Integrated Reviewer — security+logic+tests+style+acceptance in one — `fast` profile only

## Recommended subagent mapping
Security→security-reviewer; Logic→code-reviewer; Tests→test-engineer; Syntax/Style→code-reviewer/code-simplifier; Performance→code-reviewer(perf brief)/architect; Docs→writer; Architecture→architect/code-architect; BackCompat→code-reviewer(compat brief); Concurrency→debugger/tracer/code-reviewer(concurrency brief); Observability→architect/code-reviewer(observability brief); Release→verifier/architect; Dependency→security-reviewer; Product→verifier; Frontend→designer/code-reviewer; Integrated→code-reviewer/verifier.

## Progress-ledger format
At run start, before dispatching, print a ledger and keep it updated:
```
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
```
Initialize every step `pending`; update to completed/skipped/blocked/failed/not_applicable with a reason. Never mark a required gate `skipped`; if it can't run, mark `blocked`/`failed` and halt. Include the final ledger at every halt/handoff/completion.
