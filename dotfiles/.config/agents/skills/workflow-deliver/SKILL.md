---
name: workflow-deliver
layer: orchestrator
model: sonnet
reasoning: medium
description: Deliver one unit of work end-to-end (preflight → [diagnose if bug] → triage → implement → review → finalize) with kernel-enforced ledger gates; kind=bug templates required diagnose/fix steps. Use for a ready-for-agent issue, a bug report, a skill change, or a docs change; supersedes workflow-build-one and workflow-debug (D-006 #11).
---

> Hook enforcement: Rule A blocks Agent/subagent dispatch without ROUTE_CARD.

# Workflow Deliver

One delivery orchestrator for single-unit work. The router (or a batch driver) passes a `kind` — `bug|feature|skill|docs` — and `--kind bug` templates extra required steps into the ledger. This skill sequences; the gates are kernel calls (`workflow-ledger`), never prose checks.

## Kind selection — the enforcement

`ledger.sh init <run_id> --workflow workflow-deliver --kind <k> --steps preflight,triage,implement,review,qa,finalize` — use that canonical steps csv so AFK monitors read uniform step records. Only `--kind bug` inserts extra steps: required `diagnose`/`fix`, and the kernel refuses `stamp fix` without a captured red repro from `stamp diagnose`. That kernel check — not routing — is what guarantees bugs get diagnosed (D-006 #11). If mid-run evidence shows the item is actually a bug, you MUST re-init with `--kind bug` before any fix commit; on an active run that is `ledger.sh init <run_id> --kind bug --force` (audited `force-init` override entry; prior stamps are discarded and the bug run re-earns diagnose/fix). Agent-initiated force-init for kind correction is authorized — it is distinct from `stamp --override`, which stays human-instructed. Continuing a non-bug run on a known bug is a gate bypass, not a misroute recovery. Gate contract: `workflow-ledger/SKILL.md`.

## Flow

```
preflight → [diagnose — required iff kind=bug] → triage → implement →
workflow-review → [conditional blocking] user-journey-qa → workflow-finalize
```

## Workflow Progress Reporting

Follow the step-ledger reporting protocol in `workflow-ledger/SKILL.md`: the durable record is `ledger.sh set` at every transition; the table below is a render of the ledger (`ledger.sh show`), emitted at run start, on transitions, and in every halt/handoff/completion.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| Step 0: Preflight | required | pending | - |
| Step 1: Diagnose | required iff kind=bug | pending | kernel-inserted by `init --kind bug` |
| Step 2: Triage | required | pending | - |
| Step 3: Implement | required | pending | - |
| Step 4: Review (workflow-review) | required | pending | - |
| Step 5: User Journey QA | conditional | pending | - |
| Step 6: Finalize (workflow-finalize) | required | pending | - |
```

Transition legality (required steps unskippable, evidence on completion/skip) is enforced by the kernel, not this table.

## Output discipline

Compress routine progress narration to caveman style during the implementation loop (Load and run `caveman/SKILL.md` for the rules). Snap back to full prose for judgment: findings, blockers, scope violations, decisions, and the final summary/handoff.

### Step 0: Preflight

- Read only the issue/report metadata needed to derive the branch/worktree name and spot obvious blockers. If tools required by target skills' `Requires:` are missing, or the work item is ambiguous: **auto-handoff** and halt.
- Cut a fresh isolated worktree via `setup-worktree/scripts/worktree-baseline.sh` — never reuse another issue's worktree, the primary checkout, or a branch off local `main`/`staging`:
  - Root: `worktree-baseline.sh cut --branch <branch> --path <path>`
  - Stacked: add `--parent-branch <parent> --parent-pr <n>` (parent PR must have complete gate evidence; child PR targets the parent branch)
  - The script owns base resolution and prints `WORKFLOW_BASE_GATE` + `WORKTREE_BASELINE_GATE`/`STACKED_WORKTREE_GATE`; record those lines verbatim. Non-zero exit = hard halt on the printed `Blocked:` reason. Already inside a worktree → `worktree-baseline.sh verify --path <path>`; non-PASS means recreate with `cut`.
- Run everything after this from inside that worktree, starting with the ledger: `ledger.sh init <run_id> --workflow workflow-deliver --kind <k> --steps <csv>`.
- **Graphify gate (conditional):** if `graphify-out/graph.json` exists, run one focused `graphify query` for issue-scope context and record `graphify: queried`; else record `graphify: not_available_with_reason: <reason>`. Never rebuild the graph here.
- Load and run `prompt-builder/SKILL.md` from inside the worktree to gather repo/code context, decision-log rationale, files to read, and verification commands. A prompt-builder output produced outside this worktree is bootstrap context only.

### Step 1: Diagnose (required iff kind=bug)

- Load and run `diagnose/SKILL.md`. Mode by bug shape: quick (clear repro), standard, deep (intermittent), production (live system), regression (was working).
- **User changed runtime state?** If the user reports they just fixed credentials/permissions/config/service health, run ONE authoritative live check before repeating the prior blocker analysis — never assume a pre-mutation diagnosis survived the mutation.
- Gate: `ledger.sh stamp diagnose --attest root_cause="..." repro_cmd="..."` — the kernel captures the red repro itself; irreproducible bugs use the audited override on explicit user instruction. Do not restate repro mechanics in prose; the stamp is the discipline.
- Diagnosis routing: **direct-fix** → continue; **follow-up-issue** → create issue, auto-handoff, STOP; **architecture-review** → invoke `improve-codebase-architecture`, auto-handoff, STOP; **needs-human** / **unsafe-for-afk** → auto-handoff with the diagnosis artifact and halt.

### Step 2: Triage (quick)

Confirm the item is well-formed for autonomous execution: clear acceptance criteria, no ambiguous requirements, no human-only decisions. If not AFK-safe: halt with what needs human input.

### Step 3: Implement

- Implement against acceptance criteria; honor decision-log entries — do not re-open settled choices unless implementation evidence invalidates them.
- **TDD decision is a ledger note:** either Load and run `tdd/SKILL.md` (default for bugs and behavior changes) or decide `tdd_not_applicable_with_reason: <reason>`. The decision must be in the implement step's **completion** evidence — `ledger.sh set implement completed --evidence "<summary>; tdd: ran|not_applicable_with_reason: <reason>"` — because each `set` overwrites the step's evidence field, so a decision recorded only at `active` is lost. AFK monitors flag a missing decision as `needs-human`.
- `kind=bug`: write the regression test from the diagnosis artifact, then gate the fix with `ledger.sh stamp fix --attest rationale="..."` — the kernel re-runs the repro (must exit 0) and checks the regression test exists.
- **Ops-backed / secret-runtime work:** exhaust all safe local and remote progress before delegating to a human operator. Before any value movement, build an **AUTHORITY INVENTORY** — read/admin handles, write handles, source-system access method, and host/user/privilege per command — and prove operator auth for both source and target. Auth failure is a blocker (`BLOCKER: operator auth failed on <system>; next: <elevation path>`, label `needs-ops-auth`), never an assumption. Record `tdd_not_applicable_with_reason: ops-backed value movement requires human operator authority`.
- Commit incrementally with issue references.

### Step 4: Review

- Load and run `workflow-review/SKILL.md` — never inline, self-review, or substitute CI/bot reviews. Profile: at least `ledger.sh review-floor`; escalate per workflow-review's judgment guidance (security lane mandatory for auth/data-handling bugs).
- workflow-review is `layer: judgment` — it returns lane files plus a synthesis verdict and never stamps (D-006 #12). This orchestrator records the gate: `ledger.sh stamp review --attest review_profile=<p> verdict=<v> lanes=<lane>=<run-scoped path>,...` — always pass run-scoped lane paths via `lanes=` (the kernel's bare `/tmp/<lane>-review.md` default can pick up a stale file from another run), confirm each lane file's `reviewed_sha` matches HEAD before stamping, and when the chosen profile escalates above a `fast` computed floor add `model_floor=opus` (the kernel's model floor tracks the computed floor, not the chosen profile). The kernel verifies the profile floor, lane files, and per-lane models; a stamp that won't write means the review didn't happen. Applies to every shared multi-agent artifact, not just lanes — `../_docs/CONVENTIONS.md` § Run-scoped artifact paths.
- REQUEST_CHANGES: iterate, max 2 rounds, then auto-handoff with findings. NEEDS_HUMAN: auto-handoff with the flagged decision and halt.

### Step 5: User Journey QA (conditional blocking gate)

Trigger when the change touches frontend code, user-facing behavior, auth/navigation/payment flows, UX acceptance criteria — or when a bug was user-reported rather than CI-caught. Skip (with reason) for purely backend/infrastructure/tooling changes. When triggered: Load and run `user-journey-qa/SKILL.md`; proceed only on PASS or an explicit user waiver; on FAIL/PARTIAL/cannot-run, auto-handoff with the QA blocker and halt.

### Step 6: Finalize

- Load and run `workflow-finalize/SKILL.md` — it owns PR creation/description (`describe-pr`), reviewer-comment resolution, CI monitoring, issue reconciliation, and the repo-policy-controlled final action (`human-only` → draft PR; `auto-merge-eligible` → finalize may mark ready/enable auto-merge). Never replace it with direct `gh pr create`.
- For bugs: PR body references the original report, links the diagnosis artifact, and carries `Fixes #N`.
- Gate: `ledger.sh stamp finalize` — the kernel checks review freshness, clean tree, `verify-local` at HEAD, and forge state (CI, PR, threads). No approve/direct-merge/force-push/destructive git from this workflow.

## Iteration limits

Review iterations: max 2. CI fix attempts: max 3 (watch-ci exhaustion → auto-handoff). Emit progress every 10 minutes on long runs.

## Exit behavior — Partial-Completion Contract

Every halt produces an auto-handoff (Load and run `handoff/SKILL.md`); no exit loses context. Before exiting, the worktree must be in exactly one state, regardless of remaining budget:

- **A. Complete** — all changes committed and pushed.
- **B. WIP-paused** — progress committed with a `wip:` subject naming exactly what remains, pushed.
- **C. Rolled back** — `git reset --hard <baseline>`, clean tree.

Verify with `git status --short` (no `M`/`??` source files) and state the chosen exit state, commit/baseline, and status output in the final response and any handoff.

## Contract

Consumes: one work unit (ready-for-agent issue, bug report, skill/docs change request, or watch-ci handoff artifact) with `kind` from the router or batch driver; codebase
Produces: PR per repo delivery policy, ledger run with diagnose/fix (bugs), review, and finalize stamps, updated issue state; diagnosis artifact for bugs
Requires: gh, git
Side effects: creates worktree/branch, commits (including `chore(ledger):` snapshots via the kernel), PR; may modify issue labels
Human gates: unclear item, NEEDS_HUMAN review, unsafe-for-afk or needs-human diagnosis, QA failure (unless waived), review-iteration/CI exhaustion — all halt with auto-handoff; `--override` stamps only on explicit user instruction

Runtime note: project build/test tools are discovered from repo files (`package.json`, `Makefile`, CI workflows). The per-issue worktree and the ledger init are hard preconditions, not conveniences.

## Context

Typical workflows: standalone (primary delivery workflow); run-backlog / execute-prd / workflow-autonomous-backlog (dispatched per work unit with `kind`)
Pairs well with: workflow-router (routes here with kind), workflow-ledger (owns every gate), diagnose, tdd, workflow-review, workflow-finalize, prompt-builder, handoff
