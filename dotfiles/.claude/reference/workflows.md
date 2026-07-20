# Workflow Routing

> **`workflow-router` is the sole routing authority** (per ADR-0002 + `~/.claude/skills/workflow-router/SKILL.md`). This file is reference documentation only — it does not route. When a session begins or a new task arrives, invoke `workflow-router` first.

## The Canonical Loop

For all product / feature / delivery work:

```
/workflow-router                                                          ← start here
        │
        ▼
   classify task
        │
        ▼
┌──────────────────────────────────────────────────────────────────┐
│  IDEA → BRIEF → ISSUES → TRIAGE → BUILD → REVIEW → FINALIZE      │
└──────────────────────────────────────────────────────────────────┘
        │
        ▼
/grill-with-docs        ← clarify intent, capture decisions, update CONTEXT.md/ADRs
        │
        ▼
/to-prd                 ← turn the grilled idea into a PRD on the issue tracker
        │
        ▼
/to-issues              ← split the PRD into vertical-slice ready-for-agent issues
        │
        ▼
/triage                 ← move each issue through the triage state machine
        │
        ▼
/workflow-build-one     ← implement one ready issue end-to-end (dispatches executor)
   (or /execute-prd     for a parent PRD tree;
       /run-backlog     for AFK batch processing)
        │
        ▼
/workflow-review        ← MANDATORY multi-lane review gate (Security + Logic + Tests + Style + conditional lanes)
        │  • Fresh subagents per round; main session never self-approves
        │  • Verdict must be APPROVE before workflow-finalize
        │  • Up to 3 review rounds; escalate to human after that
        ▼
/workflow-finalize      ← MANDATORY delivery closure (post-mortem? → describe-pr → push → receive-review → watch-ci → reconcile-issues → repo-policy-controlled final action)
        │  • Honors REPO_DELIVERY_POLICY (`human-only` vs `auto-merge-eligible`)
        │  • Emits `WORKFLOW_FINALIZE_GATE` block as evidence
        ▼
   PR ready for human merge (or auto-merged where policy allows)
```

**Gate invariants — these never get skipped:**
- Every non-trivial branch goes through `workflow-review` with dispatched subagents (not inline reasoning, not green CI, not Claude/Bugbot/Codex reviews) — the `WORKFLOW_REVIEW_GATE` block is the only valid evidence.
- Every PR goes through `workflow-finalize` — `WORKFLOW_FINALIZE_GATE` is the only valid evidence.
- The executor never reviews its own code. Reviewer never reviews their own review (each round is a fresh subagent context).
- All non-trivial work starts on a worktree (`setup-worktree` or `using-git-worktrees`); never commit directly to `main`.

## Audit Loop — RETIRED

> The "Audit Loop" (repo-audit → design-plan → execute-phase + standalone /review + /post-mortem + /describe-pr) is **not a routable workflow**. If a prompt, doc, transcript, agent memory, or older `workflows.md` revision mentions running the Audit Loop, translate it into the canonical loop above per `workflow-router`'s **Audit Loop Retirement Rule**:

| Old "Audit Loop" step | Canonical replacement |
|------------------------|------------------------|
| `/repo-audit` as a default loop entry | `/repo-audit` only as evidence input for `workflow-roadmap`, `to-prd`, `to-issues`, or `design-plan` — never as a standalone loop |
| `/design-plan` as the default for refactors | `/design-plan` only for refactor-scale phase plans that cannot be expressed as vertical-slice issues; otherwise go through `/to-prd → /to-issues` |
| `/execute-phase` for issue work | `/workflow-build-one` per issue (or `/execute-prd` for a PRD tree, `/run-backlog` for batch) |
| Standalone `/review` as a code-review gate | `/workflow-review` (multi-lane subagent dispatch) |
| Standalone `/post-mortem` as a separate retro pass | Post-mortem invoked **inside** `/workflow-finalize` Step 0.5 when the work was audit-derived or generated `NEW-NN` findings |
| Standalone `/describe-pr` to write a PR body | `/describe-pr` invoked **inside** `/workflow-finalize` Step 1; never run free-standing |
| Standalone `/watch-ci` | `/watch-ci` invoked **inside** `/workflow-finalize` Step 3 |

If you find yourself reaching for `/repo-audit`, `/design-plan`, or `/execute-phase` outside the contexts above, stop and re-route through `/workflow-router`.

## Specialized Routes

These cover work that doesn't fit the canonical loop and have their own routing rules:

| Task type | Route | Notes |
|-----------|-------|-------|
| Bug fix | `/workflow-debug` (which begins with `superpowers:systematic-debugging`) | Bugs ALWAYS go through diagnose-first; never `workflow-build-one` |
| V1 product idea grilling | `/grill-with-docs` (V1 discovery mode) → produces `V1_IDEA_BRIEF` | Pre-PRD shaping |
| V1 technical system design | `/v1-system-design` (after the V1 grill) | Pre-implementation architecture |
| Product/engineering roadmap | `/workflow-roadmap` | Multi-area sequencing; usually fed by `/repo-audit` |
| Parent-PRD execution | `/execute-prd` | When child issues have dependencies |
| AFK backlog | `/run-backlog` | Independent ready-for-agent issues; batched |
| Quick change, single file, no design decisions | direct action | Rename, typo, config tweak |
| Research / cross-system investigation | RPI chain (`create-research-questions → create-research → create-design-discussion → create-structure-outline → create-plan → ...`) | Unfamiliar codebase or research-heavy task |
| Feature dev in known codebase | Superpowers chain (`brainstorming → writing-plans → using-git-worktrees → subagent-driven-development → finishing-a-development-branch`) | When you don't want to publish a PRD first |
| Executive memo, board update, strategy doc | `/workflow-executive-doc` | Document workflow, not delivery workflow |
| D&D / campaign / session prep | `/dnd-workflow` | Creative routing |
| Receiving review comments | `/receive-review` | Always before implementing reviewer feedback |
| Cleanup after merge / closed / abandoned PR | `/cleanup-delivery` | Worktrees, branches, ticket state |
| Workflow effectiveness audit | `/workflow-effectiveness-audit` | Did skills/workflows actually fire correctly? |
| Session wrap | `/handoff` | At session exit |

## Worktree Rules

- All non-trivial work MUST start on a worktree cut from `origin/staging` (or `origin/main` when `staging` is stale and the substitution is documented).
- Use `setup-worktree` (canonical loop / Audit-derived) or `superpowers:using-git-worktrees` (Superpowers chain) — never commit directly to `main` or work in the primary checkout.
- Every workflow that mutates code must emit a `WORKTREE_BASELINE_GATE` line.

## Author / Review / Retro Separation (mandatory)

Three distinct subagent contexts, no overlap:

1. **Executor** (writes code) — dispatched by `workflow-build-one` or other implementation skills. Never reviews its own output.
2. **Reviewer** (evaluates code) — dispatched by `workflow-review` as multiple parallel lanes (`security-reviewer`, `code-reviewer`, `test-engineer`, etc.). Fresh subagent per round. Never reviews their own prior review.
3. **Post-mortem** (writes the retro) — dispatched inside `workflow-finalize` Step 0.5 when audit-derived or NEW-NN findings exist. Reads the plan, phase-run outcomes, and git range; writes `docs/executions/<date>-post-mortem.md`. The PR body (Step 1, `describe-pr`) then cites the retro.

The main session orchestrates; it does not write production code, review its own work, or self-author retros.

## OMC Integration

OMC (oh-my-claudecode) is the **runtime** — it provides agent dispatch, model routing, team pipelines, and execution infrastructure.

Skills are the **curriculum** — they define *what* to do, while OMC provides *how* to execute it.

- `team-exec` (OMC pipeline stage) executes `workflow-build-one`.
- `team-verify` (OMC pipeline stage) executes `workflow-review`.
- OMC keyword triggers (`autopilot`, `ralph`, `ultrawork`, etc.) bypass `workflow-router`'s classification step only. Any mutating code, commit, PR, or delivery action reached through those shortcuts must still satisfy `WORKTREE_BASELINE_GATE`, `WORKFLOW_REVIEW_GATE`, and `WORKFLOW_FINALIZE_GATE`. The gates are non-negotiable regardless of dispatch path.
- When OMC and a skill overlap: OMC provides the mechanics, the skill provides the domain logic. Example: `code-reviewer` is the OMC subagent type, dispatched BY `workflow-review` the skill.

## Loop Progress Board (mandatory visual confirmation)

Every transition through the canonical loop emits a progress board so the workflow is visible end-to-end. This makes skipped steps obvious and creates an audit trail in the transcript.

### Template

```
✅ /workflow-router    → routed to <classification>
✅ /grill-with-docs    → <N> decisions, <M> batches; CONTEXT.md updated
✅ /to-prd             → PRD #<N> published
⏭️ /to-issues          ← decomposing into <N> vertical-slice ready-for-agent issues
   /triage             → move each issue through the triage state machine
   /workflow-build-one → implement one ready issue end-to-end
   /workflow-review    → multi-lane subagent dispatch (fresh per round)
   /workflow-finalize  → describe-pr → CI → reconcile → final action
```

### Conventions

- `✅` for completed steps, with a one-line outcome summary after `→` (numbers, IDs, artifact names, gate-block status).
- `⏭️` for the currently active step, with `←` describing what it's about to do.
- No icon (plain text) for upcoming steps.
- Emit the board at every transition:
  - **Before** invoking the next skill (active = next skill, with `← <what it'll do>`)
  - **After** completing a step (flip the active marker to `✅ <skill> → <outcome>`)
- One board per transition. Don't spam multiple in a row; combine into a single rendering.
- Substitute the alternative implementation skill (`/execute-prd` for PRD trees; `/run-backlog` for AFK batches; `/workflow-debug` for bugs) when the route diverges from `/workflow-build-one`.
- Gate evidence (`WORKTREE_BASELINE_GATE`, `WORKFLOW_REVIEW_GATE`, `WORKFLOW_FINALIZE_GATE`) is the verbose audit trail. The Loop Progress Board is the at-a-glance dashboard. Both are required.

The owning agent (the main session orchestrating the loop) emits the board — not the skill itself. The agent has the state; the skill has the work.

## Quick Reference

- **Don't know where to start?** → `/workflow-router`
- **Have a vague idea?** → `/workflow-router` → it'll route to `/workflow-feature` or `/v1-workflow`
- **Have a clear `ready-for-agent` issue?** → `/workflow-router` → `/workflow-build-one`
- **Have a parent PRD with children?** → `/workflow-router` → `/execute-prd`
- **Have a bug?** → `/workflow-router` → `/workflow-debug`
- **Implementation done, need review?** → `/workflow-review`
- **Review passed, need to ship?** → `/workflow-finalize`
- **Someone says "do the audit loop"?** → translate per the table above, then route via `/workflow-router`

When in doubt, ask `workflow-router`. Don't re-derive the routing yourself from memory.
