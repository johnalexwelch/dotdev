---
name: workflow-router
layer: orchestrator
model: sonnet
reasoning: high
description: Use when a request may need routing to a project workflow, AFK execution path, planning/grill flow, review/finalize loop, or skill/workflow audit
---

# Workflow Router

## Purpose

The single routing authority for all incoming work. Classifies the task, presents a route card for confirmation, runs preflight checks, and dispatches to the appropriate workflow skill only after the user confirms the route. Replaces ad-hoc routing decisions with a consistent classification system.

## Canonical Workflow Chain

```
grill-with-docs → to-prd → to-issues → triage → tdd → workflow-deliver → workflow-review → workflow-finalize
```

This is the **default product flow**. Most work follows this chain or enters at a specific step. Deviations require explicit justification in the ROUTE_CARD.

## Authority

This skill is the **sole routing authority**. Per `docs/adr/0002-sole-routing-authority.md`:

- `workflows.md` is reference documentation only — it does not route
- OMC keyword triggers (`autopilot`, `ralph`, `ultrawork`, etc.) bypass this router's classification step only. Any mutating code, commit, PR, or delivery action reached through those shortcuts must still satisfy `WORKTREE_BASELINE_GATE`, `workflow-review`, and `workflow-finalize`.
- All other work goes through this router
- **Naming a skill is a load-and-gate instruction, not a verb.** When any goal, plan, prompt, or handoff names a workflow skill (e.g. `workflow-review`, `workflow-finalize`), load that skill's `SKILL.md` and follow it — including emitting its required gate block. A prose claim that the skill ran (or "basically ran") without its gate block present in the evidence means it did **not** run; treat it as unrun. Do not reconstruct a skill's intent from memory in place of loading it.
- The router owns classification, confirmation, preflight, and learning notes. Target workflow skills own the actual workflow behavior. Do not copy target workflow procedures into this skill.

## Pre-Dispatch Self-Check (Hook-Enforced)

> Hook enforcement: Rules 0, A, B, C, D, E in `workflow-guard.sh` block/warn on:
>
> - Rule 0: git commit/push, gh issue/pr create/merge without routing evidence
> - Rule A: Agent/subagent dispatch without ROUTE_CARD
> - Rule B: >10 subagents per session (parallelism cap)
> - Rule C: `gh pr create` without describe-pr body file
> - Rule D: >500 line diffs (warning)
> - Rule E: Opus for fact-gathering tasks (warning)
>
> Enable hard blocks: `ROUTING_ENFORCE=block PARALLELISM_ENFORCE=block PR_BODY_ENFORCE=block`

## Imperative Trigger Patterns (MUST Route, Never Execute Literally)

These phrases trigger routing classification, not literal execution:

| Phrase Pattern | Why It Routes | Classification |
|----------------|---------------|----------------|
| "spin up sub-agents for X" | Multi-agent dispatch = orchestration | team budget |
| "dispatch workers to Y" | Parallel execution = orchestration | team budget |
| "run agents across Z" | Fan-out = orchestration | team budget |
| "parallelize work on W" | Concurrent execution = orchestration | team budget |
| "have agents do X" | Delegation = orchestration | one-reviewer or team |
| "batch process these issues" | AFK batch = orchestration | run-backlog |

**Literal interpretation of these phrases is always wrong.** They describe WHAT to accomplish, not HOW to accomplish it. The router determines the how.

> Baseline evidence: 2026-08-20 postmortem — "spin up sub-agents for each lane" executed literally, skipping all gates.

## Audit Loop Retirement Rule

The old "Audit Loop" is not an execution route. If a prompt, transcript, repo doc, or agent memory says to run the Audit Loop, translate it into the workflow system:

- Code review gate → `workflow-review`
- Delivery closure, PR body, reviewer comments, CI, reconciliation, and final PR action → `workflow-finalize`
- Broad repo evidence gathering → direct investigation, then route findings through `to-prd` (migration mode for refactor-scale findings) or `to-issues`
- Multi-phase refactor execution → `to-prd` (migration mode) → `to-issues` → `triage` → `execute-prd`, whose children carry `workflow-review` and `workflow-finalize`

Do not dispatch `/post-mortem`, `/describe-pr`, or `/watch-ci` as a standalone default loop unless the owning workflow explicitly calls that skill.

## Session Cost Guardrail

Track cumulative estimated session cost. Emit a warning at $25 and require explicit confirmation to continue at $50:

| Threshold | Action |
|-----------|--------|
| $25 | Emit warning: "Session cost approaching $25. Consider checkpointing." |
| $50 | Hard pause: "Session cost at $50. Continue? (y/N)" |
| $100 | Halt: "Session exceeded $100. Handoff required." |

Subagent spawns count toward parent session budget. This guardrail exists because a single Aug 2026 session spawned 102 subagents and spent $729 — way beyond any skill's configured limits. The issue was ad-hoc orchestration during exploratory work that escalated into execution without re-routing.

> ponytail: Estimated cost only — no live API integration. Upgrade path: hook into usage-cache when available.

## Agent Budget Rule

Choose the smallest execution shape that preserves quality:

| Budget | Use when | Default review profile |
|--------|----------|------------------------|
| `direct` | Only when **ALL** of these hold: (a) the action is read-only or produces only an immediate conversational answer; (b) no tracked file is mutated; (c) the deliverable is not a polish/rewrite/transform of text the user will use. **Never `direct` if the task will commit or push tracked code** — that is at least `one-reviewer` and must satisfy the worktree + `workflow-review` + `workflow-finalize` gates. | none |
| `one-reviewer` | Normal single-issue work, narrow code edits, and most skill/config changes | `fast` or `standard` |
| `multi-lane` | Auth, data, infra, migrations, public APIs, dependencies, broad refactors, concurrency/state, user-facing UX, or large diffs | `full` |
| `team` | Two or more independent workstreams benefit from parallel execution more than coordination costs | per child workflow |

**Team Budget Delegation Requirement:** When `team` budget is selected, you MUST delegate each workstream via taskflow. Direct implementation by the orchestrating agent is prohibited.

**Parallelism Cap:** No single session may spawn more than 10 concurrent subagents. If the work requires more parallelism, checkpoint, handoff, or split into multiple sessions. This cap exists because uncontrolled fan-out is the primary cost driver — 102 subagents in one session cost $729.

Independence matters more than agent count. Do not use multiple agents merely
because a workflow says "review"; use `workflow-review`'s risk-sized
`review_profile`.

## Model Selection by Task Type

Default to Sonnet unless judgment is the primary value. Opus costs 5x more per token.

| Task Type | Model | Reasoning |
|-----------|-------|-----------|
| Fact gathering, exploration | Sonnet | Cheap, parallelizable |
| Code review lanes | Sonnet | Adequate for checklists |
| Corpus/batch evaluation | Sonnet | Volume > depth |
| Skill testing/eval reps | Sonnet | Statistical coverage |
| Synthesis, judgment | Opus | Worth the cost |
| Architecture decisions | Opus | Judgment-heavy |
| Security/concurrency review | Opus | Risk-sensitive |

**Cost evidence:** Aug 2026 analysis showed claude-opus-5 at $12,262 vs claude-sonnet-5 at $1,882. The 6.5x ratio means model selection is the highest-leverage cost control after parallelism caps.

> ponytail: This table is advisory prose. Upgrade path: frontmatter `model:` enforcement in skill lints.

**Inline-doable is not a routing signal.** A request to transform, polish, or
rewrite TEXT the user will actually use — "de-AI this paragraph", "humanize
this draft", "rewrite this work-order so the AFK agent can execute it" —
routes to the owning skill (`humanizer`, `prompt-builder`), never to `direct`,
even though the model could plausibly produce the rewrite inline. The output
is a deliverable with an owning skill, and the skill's method is the point of
the route. Baseline evidence (2026-08-19 golden-eval failures, cases 2 and
35): "De-AI this paragraph before I post it." and "Rewrite this work-order so
the AFK agent can execute it — just give me the text back." both collapsed to
`direct`; the correct routes are `humanizer` and `prompt-builder`. "Just give
me the text back" scopes the *output format*, not the route.

## Resume Check (Step 0)

Before classifying, `Load and run` `workflow-ledger/SKILL.md`: run
`workflow-ledger/scripts/ledger.sh reconcile` — it compares the live ledger
against git ground truth and prints the true frontier (`--apply` updates
`next`); never trust the raw state file's claim over its output.

- If an `active|paused` run exists: show `ledger.sh show` and ask
  `Resume "<run_id>" at <next>? (or start fresh)`; on resume, dispatch to the
  reconciled frontier.
- On **start fresh** for unrelated work: overwrite (`ledger.sh init --force`)
  only after checking for a shared-resource conflict (same file, branch,
  worktree, or AFK issue/PR target); on conflict, report it and ask which run
  takes priority.

Skip the resume check when there is no project repo (ephemeral session) — the
ledger is an optimization, never a gate.

## Workflow Progress Reporting

Follow the step-ledger reporting protocol in `workflow-ledger/SKILL.md`: emit the `WORKFLOW_STEPS` ledger before executing or dispatching any step, update it at every status transition, and include the final ledger in every halt, handoff, and completion response.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| Step 0: Classify Request | required | pending | - |
| Step 1: Select Budget | required | pending | - |
| Step 2: Emit Route Card | required | pending | - |
| Step 3: Confirmation Gate | conditional | pending | Required for non-direct routes |
| Step 4: Target Preflight | conditional | pending | Runs after confirmation |
| Step 5: Dispatch Or Halt | conditional | pending | Runs after preflight |
| Step 6: Learning Note | conditional | pending | Required for confirmed non-trivial routes, halts, or corrections |
```

Skill-specific rules (extend the step-ledger protocol):

- A conditional step may be `skipped` only when the route is direct/read-only and no dispatch occurs; record the reason.
- Do not dispatch before the ledger shows route confirmation and target preflight complete or not applicable.
- **Persist the ledger via the kernel.** In a project repo, after route
  confirmation run `workflow-ledger/scripts/ledger.sh init <run_id> --workflow
  <target> --kind <k> --steps <csv> --route "<classification>|<selected-flow>|confirmed"`
  (route evidence from the confirmed ROUTE_CARD — init warns without it) and
  `ledger.sh set <step> <status>` at each transition. Never hand-write the
  committed per-run snapshot (`docs/executions/runs/<run_id>.yaml`), the legacy
  `docs/executions/state.yaml`, or the live state —
  they are script-owned (a guard hook blocks direct Edit/Write). The
  `WORKFLOW_STEPS` table above is a render of the ledger (`ledger.sh show`),
  not the durable record.

## Route Confirmation Gate

Before dispatching any non-trivial workflow, mutating workflow, scaffold, AFK run, GitHub issue/PR action, project document generation, or delivery loop, emit a `ROUTE_CARD` and wait for the user's confirmation.

Skip the confirmation gate only when all are true:

- Budget is `direct`
- The action is read-only or produces only an immediate conversational answer
- The user explicitly asked for the immediate action
- No workflow dispatch, file mutation, repo scaffold, issue creation, PR action, or AFK execution will occur

If the user explicitly names a workflow and says to run it, still emit the route card first when the workflow can mutate files, create artifacts, create issues/PRs, run AFK, or perform delivery actions.

### Route Card

Use this exact shape:

```markdown
ROUTE_CARD:
- Request:
- Classification:
- Selected flow:
- Confidence: high|medium|low
- Why this flow:
- Budget: direct|one-reviewer|multi-lane|team
- Will mutate/create:
- Human gates:
- Expected artifacts:
- Follow-up audit:
- Alternatives considered:
- Confirmation needed:
```

Rules:

- `Will mutate/create` must explicitly say `none` for read-only routes.
- `Human gates` must include every known approval point before implementation, AFK execution, PR action, or cleanup.
- `Follow-up audit` should say whether `skill-system-audit` is expected at the end and why.
- If confidence is `low`, ask one clarifying question instead of asking the user to approve a route.
- If confidence is `medium`, recommend the best route and include the closest alternative.
- Do not perform target workflow preflight, create a worktree, scaffold a repo, write docs, create issues, or dispatch agents until the route is confirmed.
- Schema validator: `scripts/validate-route-card.sh` reads a route card on stdin and asserts all 12 required fields plus legal `Confidence`/`Budget` values — pipe the emitted card through it when a workflow needs checked (not attested) route-card evidence.

### Routing regression eval (D-006 Track B)

Classification behavior is measured, not rules-engined: `references/golden-routes.yaml` holds the golden prompt→route set (log-harvested + synthetic adversarial; every future misroute adds a case), and `test/routing-eval.sh` runs it headless against this SKILL.md with a deterministic string-match judge (pass gate ≥95%). CI: `.github/workflows/routing-eval.yml`, path-filtered to this skill. Update the golden set whenever the classification table changes.

### Confirmation Language

End the route card with one concise confirmation request:

```markdown
Confirm this route and I will start `<selected-flow>`.
```

If the route is read-only and low-risk, use:

```markdown
Confirm this route and I will proceed.
```

If the user corrects the route, treat that correction as fresh routing input and produce a revised route card.

## Classification table

| Signal | Routes to |
|--------|----------|
| New product, V1, MVP, feature, idea, roadmap, capability | `grill-with-docs` → `to-prd` → `to-issues` → `triage` → implementation |
| Bug, error, regression | `workflow-deliver` with `kind=bug` |
| Ready issue with `ready-for-agent` | `workflow-deliver` |
| Parent PRD with children, "execute PRD" | `execute-prd` |
| Multiple ready issues, AFK batch | `run-backlog` |
| Refactor/migration plan | `to-prd` (migration mode) → `to-issues` → `execute-prd` |
| "Review this", code review | `workflow-review` |
| Writing clarity, "proofread" | `clarity-review` |
| "Ship this", finalize, merge | `workflow-finalize` |
| Address review comments | `workflow-finalize` (invokes `receive-review`) |
| Research, investigate | Direct investigation → findings to `to-prd` or `to-issues` |
| Cleanup branches/worktrees | `cleanup-delivery` or `git-worktree-audit` |
| Skill authoring | `skill-backlog` → `to-issues` → `workflow-deliver` with `kind=skill` |
| Skill/workflow audit | `skill-system-audit` or `session-insight` |
| "Grill me", challenge plan | `grill-with-docs` |
| Humanize, de-AI | `humanizer` |
| Handoff, wrap up | `handoff` |
| Prompt generation | `prompt-builder` |
| D&D, creative writing | Switch to **Wren** agent |

**Default:** If unclear, use the canonical chain: `grill-with-docs` → `to-prd` → `to-issues` → `triage` → implementation.

## Routing Rules (compressed)

**Owner vs sub-step:** Route to owning orchestrator by default. Exception: imperative skill name ("Run receive-review on #17") → dispatch directly.

**Bugs:** Always `workflow-deliver` with `kind=bug`. Ledger enforces diagnose-first.

**PRD vs backlog:** Parent PRD with children → `execute-prd`. Independent issues → `run-backlog`. Single issue → `workflow-deliver`.

## Kernel Skills (disabled from auto-routing)

7 skills have `disable-model-invocation: true` — they are helpers called by other workflows, not direct entry points: `describe-pr`, `setup-skills`, `setup-worktree`, `watch-ci`, `wayfinder`, `workflow-ledger`, `workflow-router`. Invoke by name (`/skill-name`) when explicitly needed.

Reference docs live in `_docs/`: council-scaffolding, review-scaffolding, graph-first, write-a-skill, omc-reference, herdr, find-skills, caveman, codebase-design, domain-modeling.

## Human-Gate Taxonomy

See `_docs/human-gate-taxonomy.md`. Gates 1-3 (maintainer-decision, operator-runtime, secret-custody) block AFK. Gate 4 (reviewer-validation) does not.

## Preflight

Run `workflow-ledger/scripts/ledger.sh preflight --skill <target>` to check requirements. Halt if missing.

### Gates (compressed)

- **Canonicality:** For path/layout mutations, confirm: canonicality (one source of truth) vs compatibility (keep shims).
- **Prior-Art:** Check `docs/roadmap.md`, `docs/adr/`, open issues before build/design routes. Halt if already exists.
- **Worktree Baseline:** Mutating workflows require `worktree-baseline.sh cut --branch <name> --path <path>`. Parallel lanes get separate worktrees. Never run delivery from primary checkout.

## Canonical Flow

```
grill-with-docs → to-prd → to-issues → triage → [workflow-deliver | execute-prd | run-backlog] → workflow-review → workflow-finalize → cleanup-delivery
```

All issues are vertical slices with AFK readiness criteria. No horizontal issue creation.

## Migration / Refactor Lane

`to-prd` migration mode handles repo-wide refactors, migrations, or multi-phase remediation:

- **Route findings** based on type:
  - Product/feature gaps → `grill-with-docs` → `to-prd` → `to-issues` (canonical chain)
  - Already-clear vertical slices → `to-issues` or `triage` directly
  - Repo-wide refactors/migrations → `to-prd` **migration mode** (FIND-NN/REQ-NN anchors, parent + ordered children, pilot/canary, rollback) → `to-issues` → `triage` → `execute-prd`
- **Do not route findings straight to execution** — human-approved PRD required first
- **Key constraint:** PRD/spec parent issues must not be labeled `ready-for-agent` — only triaged child issues may receive that label

## Planning Gate Rule

For product/feature planning that will produce PRDs and implementation issues, require passage through the canonical chain (`grill-with-docs` → `to-prd` → `to-issues`) before implementation.

- If a grilled and approved PRD exists: proceed to `to-issues`.
- If no PRD exists: start with `grill-with-docs`.
- Only an explicit user waiver may bypass this gate.
- **Migration-mode exception (in-rule, not a waiver):** `to-prd` migration mode satisfies this gate with its input artifact instead — a **human-approved** migration brief. The scope there is already settled.

### Roadmap Doc Invariant (drift guard)

If a `docs/roadmap.md` exists, it is a **capability-altitude** artifact, not a status tracker:

- **Exactly one canonical `docs/roadmap.md`.** Never create a dated/named roadmap sibling. Update the canonical, or move superseded planning to `docs/roadmaps/archive/`.
- **Never restate execution state in the roadmap** — per-issue status lives in GitHub. The roadmap holds capabilities ordered by `depends on` (bands Now/Next/Later), each with `outcome` · `unlocks` · `effort` · `priority`.
- New idea → append a capability (or backlog-pool entry) with its deps; do not renumber or fork the doc.

## Process

1. Resume check: `ledger.sh reconcile`; if active/paused run exists, offer to resume
2. Classify using signal table
3. If ambiguous: ask ONE clarifying question (max 1)
4. Select smallest safe agent budget
5. Emit ROUTE_CARD
6. Wait for user confirmation unless route qualifies for direct/read-only skip
7. Run `ledger.sh preflight --skill <target>`; persist via `ledger.sh init`
8. If preflight passes: dispatch to target workflow
9. If preflight fails: report missing requirements

## Contract

Consumes: work description (user input, issue body, automated trigger), existing ledger run state via `workflow-ledger/scripts/ledger.sh reconcile|show` (resume)
Produces: route card, confirmed workflow invocation, preflight report (if failed), router learning note, persisted run ledger via `ledger.sh init`/`set`
Requires: git
Side effects: initializes/updates the workflow-ledger run state in project repos (via `ledger.sh`, which commits `chore(ledger):` snapshots); none otherwise
Human gates: route confirmation before non-trivial dispatch; ambiguous classification asks one clarifying question; prior-art/roadmap scan before any build/implement/design/ADR dispatch (halt on conflict/duplicate)

Runtime note: the router itself only needs git-aware workspace context; target workflows declare their own `Requires` fields.

## Context

Typical workflows: entry point (invoked implicitly or explicitly for all new work)
Pairs well with: all workflow skills (it routes to them), preflight validates their contracts
