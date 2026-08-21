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

## Authority

This skill is the **sole routing authority**. Per `docs/adr/0002-sole-routing-authority.md`:

- `workflows.md` is reference documentation only — it does not route
- OMC keyword triggers (`autopilot`, `ralph`, `ultrawork`, etc.) bypass this router's classification step only. Any mutating code, commit, PR, or delivery action reached through those shortcuts must still satisfy `WORKTREE_BASELINE_GATE`, `workflow-review`, and `workflow-finalize`.
- All other work goes through this router
- **Naming a skill is a load-and-gate instruction, not a verb.** When any goal, plan, prompt, or handoff names a workflow skill (e.g. `workflow-review`, `workflow-finalize`), load that skill's `SKILL.md` and follow it — including emitting its required gate block. A prose claim that the skill ran (or "basically ran") without its gate block present in the evidence means it did **not** run; treat it as unrun. Do not reconstruct a skill's intent from memory in place of loading it.
- The router owns classification, confirmation, preflight, and learning notes. Target workflow skills own the actual workflow behavior. Do not copy target workflow procedures into this skill.

## Pre-Dispatch Self-Check (Hard Gate)

**Before ANY of these actions, verify a ROUTE_CARD was emitted in this session:**

- Creating GitHub issues (`gh issue create`, `mcp github create_issue`)
- Spawning subagents/workers (`subagent`, `taskflow` with agent phases)
- Running taskflow with multiple phases or parallel execution
- Committing code (`git commit`)
- Creating or merging PRs (`gh pr create`, `gh pr merge`)
- Running `workflow-deliver`, `execute-prd`, `run-backlog`
- Closing issues (`gh issue close`, `issue_close`)

**If no ROUTE_CARD exists in context → STOP and emit one before proceeding.**

This gate catches the failure mode where imperative phrasing ("spin up sub-agents for X") bypasses routing entirely. The check is a reflex, not a research project: scan recent context for `ROUTE_CARD:`, and if absent, load this skill and emit one.

> ponytail: Single grep-like check. Upgrade path: structured route-card registry if cross-session tracking needed.

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
- Broad repo evidence gathering → `repo-audit`, then route findings through `workflow-roadmap`, `to-prd` (migration mode for refactor-scale findings), or `to-issues`
- Multi-phase refactor execution → `to-prd` (migration mode) → `to-issues` → `triage` → `execute-prd`, whose children carry `workflow-review` and `workflow-finalize`

Do not dispatch `/post-mortem`, `/describe-pr`, or `/watch-ci` as a standalone default loop unless the owning workflow explicitly calls that skill.

## Agent Budget Rule

Choose the smallest execution shape that preserves quality:

| Budget | Use when | Default review profile |
|--------|----------|------------------------|
| `direct` | Only when **ALL** of these hold: (a) the action is read-only or produces only an immediate conversational answer; (b) no tracked file is mutated; (c) the deliverable is not a polish/rewrite/transform of text the user will use. **Never `direct` if the task will commit or push tracked code** — that is at least `one-reviewer` and must satisfy the worktree + `workflow-review` + `workflow-finalize` gates. | none |
| `one-reviewer` | Normal single-issue work, narrow code edits, and most skill/config changes | `fast` or `standard` |
| `multi-lane` | Auth, data, infra, migrations, public APIs, dependencies, broad refactors, concurrency/state, user-facing UX, or large diffs | `full` |
| `team` | Two or more independent workstreams benefit from parallel execution more than coordination costs | per child workflow |

**Team Budget Delegation Requirement:** When `team` budget is selected, you MUST delegate each workstream via taskflow. Direct implementation by the orchestrating agent is prohibited.

Independence matters more than agent count. Do not use multiple agents merely
because a workflow says "review"; use `workflow-review`'s risk-sized
`review_profile`.

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

| Signal | Classification | Routes to |
|--------|---------------|-----------|
| "build a V1", "turn this idea into a V1", "shape this product idea", "define the MVP", "new app/tool for <audience>" — a **new product for end users**, with its own users, promise, and success metrics, needing a V1_IDEA_BRIEF and system design; loose idea for such a product needing functionality details, "design the system for this V1", "turn this V1 brief into architecture", "design the architecture for this approved V1 brief" | **V1** | `v1-workflow` (full gated pipeline: idea grill via `grill-with-docs` → approval → decision-log → system design → roadmap → issues). Do NOT route directly to `v1-system-design` — **even when the brief is already approved**: `v1-workflow` resumes at the right stage, while `v1-system-design` alone skips the roadmap/issue gates that follow design |
| "roadmap", "what should we build next", "feature gaps", "implementation gaps", "hardening roadmap", "product and implementation plan", multi-area sequencing across product/security/infrastructure | **product/engineering roadmap** | workflow-roadmap |
| "turn this roadmap into PRDs/issues", "roadmap to backlog", "break milestones into PRDs", "break PRDs into issues", approved roadmap needing issue queue | **roadmap-to-backlog transition** | `workflow-roadmap` if no approved roadmap -> `to-prd` for spec parents -> `to-issues` with `references/issue-dependency-audit.md` -> `execute-prd` for parent/dependent trees or `run-backlog` only for independent ready issues |
| "write OKRs", "set quarterly goals", "objectives and key results", "turn strategy into OKRs", "review these OKRs" | **OKRs** | okr-generator |
| "we're launching X", "launch plan", "launch checklist", "go-to-market checklist", "are we ready to ship", "go-live readiness" | **product launch** | product-launch-checklist |
| "autonomous module discovery", "find modules and create PRDs", "action the backlog AFK", "run backlog without outages", "autonomous backlog" | **autonomous backlog workflow** | workflow-autonomous-backlog |
| Bug report, error, "it's broken", regression | **bug** | workflow-deliver with `kind=bug` |
| Vague idea, "what if we...", "I want to build...", "I want to set up...", "standardize how we..." — capability work within an existing system or internal tooling/infrastructure (templates, standardized workflows, checks, developer/DS tooling, features of existing products), even when large, vague, or multi-part | **ambiguous feature** | workflow-feature — downstream, workflow-feature may escalate to `wayfinder` on grill evidence (user-confirmed); the router itself never routes to wayfinder, which is explicit-invocation only (`/wayfinder`) |
| "improve the wording", "the error message is confusing", "reword this label/tooltip/notification", any change to user-facing product copy or UX text | **UX copy change (tracked code)** | workflow-feature — user-visible copy lives in tracked source, so a copy edit is a code commit carrying the full worktree/review/finalize gates; never `direct` even when nothing is "broken" (baseline case 21: bug-ish phrasing, feature-shaped change) |
| Issue with `ready-for-agent` + clear acceptance criteria | **ready issue** | workflow-deliver with `kind=feature` (`skill`/`docs` when the issue is a skill or docs change) |
| A prompt/plan/handoff names `workflow-build-one` (superseded) | **ready issue (legacy name)** | workflow-deliver with `kind=feature` — tombstone redirect, D-006 #11 |
| A prompt/plan/handoff names `workflow-debug` (superseded) | **bug (legacy name)** | workflow-deliver with `kind=bug` — tombstone redirect, D-006 #11 |
| Parent PRD issue with child issues, "execute this PRD", "implement all children of #N", "work through this parent issue", "execute the issue tree" | **PRD execution** | execute-prd |
| A prompt/plan/handoff names `design-plan` (superseded), "turn this audit into a plan", "create a refactor plan", refactor/migration/governance brief needing a phased plan | **refactor/migration planning** | to-prd (migration mode) — tombstone redirect, D-006 planning-lane consolidation 2026-08-19; then to-issues → triage → execute-prd |
| A prompt/plan/handoff names `execute-phase` (retired), "execute phase N", "run phase", "land phase" | **phase execution (legacy name)** | execute-prd against the migration-mode parent issue tree; a lone slice routes to workflow-deliver — tombstone redirect, D-006 planning-lane consolidation 2026-08-19 |
| Multiple ready issues, "run the backlog", AFK batch | **AFK backlog** | run-backlog |
| "Audit the repo", "state of repo", broad evidence gathering needed | **repo evidence audit** | repo-audit → workflow-roadmap / to-prd / to-issues; refactor-scale findings take to-prd migration mode |
| Research question, "investigate how...", "what does X look like in the codebase", "investigate Y" | **research** | `repo-audit` (for codebase evidence) or `improve-codebase-architecture` (for deepening opportunities); findings feed `workflow-roadmap`, `to-prd` (migration mode for refactor-scale), or `to-issues` |
| "Review this", "review my changes" | **review** | workflow-review — **exception:** if the review scope is SQL/dbt models, dashboards, metric trees, or executive-facing analyses (even inside a PR), route to the artifact-specific skill (`sql-review`, `dashboard-review`, `metric-tree-review`, `strategic-analysis-review`); ask which is intended when both PR and artifact signals are present. Per-model correctness/performance concerns on a SQL or dbt model — join fanout, NULL handling, window pitfalls — are `sql-review`, not `dbt-project-evaluator` (that is a whole-project structure/conventions audit, never a per-model review) |
| "review this doc/email/Slack post/memo for clarity", "tighten this writing", "make this clearer", "proofread this", feedback wanted on HOW prose is written | **writing clarity review** | clarity-review — **carve-out vs `workflow-review`:** when the artifact is prose (doc, email, post, memo, spec text) and the concern is communication clarity rather than change correctness, route `clarity-review` even if the prose lives in a PR; `workflow-review` owns code/change correctness only |
| "Address review comments", "handle the feedback", "respond to review", PR has unresolved comments | **receive review** | `workflow-finalize` (its Step 2 invokes `receive-review` for reviewer-comment resolution) — **carve-out:** if the user explicitly wants only the comment-resolution sub-step (e.g. "just address the review comments on #42, don't finalize/merge yet") **or names the skill imperatively** (e.g. "Run receive-review on PR #17"), dispatch `receive-review` directly per the owner-vs-sub-step rule below — an imperative verb+skill-name is the explicit scope, not an ambiguity |
| "review diff against spec", "does the branch match the PRD", "standards conformance", "spec drift", "review since <ref>" | **spec/standards conformance** | spec-review (two-axis: repo coding-standards + spec/PRD conformance of a HEAD-to-ref diff; distinct from `workflow-review`, which checks correctness only) |
| "ship this", "finalize this PR", "merge this", "close this out", "land this", ready-to-merge / delivery-closure request | **ship / finalize** | workflow-finalize |
| "cleanup", "clean up tickets", "delete branches", "remove worktrees", "stale local branches", merged/closed/abandoned delivery residue | **delivery cleanup** | cleanup-delivery |
| "audit branches", "clean up worktrees", "prune stale worktrees", branch/worktree sprawl across many repos on the machine (not one delivery's residue) | **git worktree audit** | git-worktree-audit |
| "Evaluate workflow effectiveness", "audit skill effectiveness", "find workflow gaps", "audit recent agent transcripts", "did this workflow skip steps" | **skill system audit** | skill-system-audit |
| "reflect", "what did we learn", "how could this have gone better", "skillify", "turn this into a skill", "improve the skills based on this" | **session reflection / skill extraction** | session-insight |
| "process the skill backlog", "review skill improvements", "turn reflections into skill changes", accumulated reflections needing triage | **skill backlog** | skill-backlog |
| "write a skill", "create a skill", "revise this skill", "fix this skill's description", implement an approved skill-backlog item | **skill authoring/revision** | workflow-skill |
| "evaluate this skill", "benchmark a skill", "pressure-test a skill", "is this skill any good", "is the new version of this skill better" | **skill evaluation** | skill-evaluator |
| "route this", "choose the workflow", "what flow do we need", "single wrapper", "intake", "which skill should run", "start the right workflow" | **workflow intake** | workflow-router route card, then confirmed target workflow |
| D&D, campaign, session prep, mystery, encounter, NPC, worldbuilding | **creative/D&D → Wren** | Switch to the **Wren** agent (`~/projects/agents/wren`); creative/D&D skills (`dnd-workflow`, etc.) live in Wren's kit, not here |
| Executive memo, board update, strategy doc, leadership recommendation, org analysis, product engagement analysis | **executive document** | workflow-executive-doc |
| "prototype this", "try it out", "play with it", "sanity-check the model" | **prototype** | prototype |
| "grill me", "stress test this", "poke holes in this plan", "challenge this design", design/plan interrogation outside the V1 pipeline | **plan grill** | grill-with-docs (standalone; the V1 row above owns idea grills only when they run inside the `v1-workflow` pipeline) |
| "write an article", "blog post", "draft", "write about" | **writing → Wren** | Switch to the **Wren** agent (`~/projects/agents/wren`); the writing pipeline (`writing-fragments` → `writing-shape` (beats mode) → humanizer) lives in Wren's kit |
| "humanize", "de-AI", "make it sound human", "remove AI patterns" | **polish** | humanizer |
| "handoff", "wrap up session", "save context for next time" | **session exit** | handoff |
| "generate prompt for", "prep for codex", "prep for AFK" — a standalone prompt-text request, not a request to run the batch/dispatch; also "evaluate this prompt", "rewrite this work-order", "check this brief" — prompt or work-order evaluation/rewrite with **NO repo-artifact mutation** | **prompt generation or evaluation** | `prompt-builder` whenever any generated or rewritten prompt/work-order text is returned — "just give me the text back" scopes output format, not the route (baseline case 35 collapsed exactly this to `direct`); `direct` **only** for pure evaluation that returns judgment with no rewritten text. Emit a full non-direct route card and dispatch only if the user asks to create/update project artifacts, issues, PRDs, roadmaps, or other repo-tracked deliverables; for prompt-only work, return the result as a conversational response or markdown block without a route card (legitimate standalone entry point per prompt-builder's own contract's "manual Codex task" use case) |

**V1-vs-feature boundary:** `v1-workflow` is reserved for a NEW PRODUCT for end users — its own users, promise, and success metrics, needing a V1_IDEA_BRIEF and system design — while capability work within an existing system or internal tooling/infrastructure (templates, standardized workflows, checks, developer/DS tooling — e.g. "a standardized ML workflow so data scientists go from EDA to deployment with checks built in, plus agent skills to help build models" is internal ML tooling → `workflow-feature`) stays **workflow-feature** no matter how large or vague; scale is handled downstream by workflow-feature's own grill evidence (which may escalate to `wayfinder` — never a router route), not by upgrading the classification to `v1-workflow`.

## Owner vs. sub-step routing rule (SB-021 / SB-022)

**Routes-to names the owning orchestrator, not the first-mentioned or most-obviously-matching skill — unless the user explicitly asks for that sub-step alone.** A request that only superficially matches a mid-chain skill's own trigger wording (e.g. `receive-review`'s description literally says "address/respond to the review comments") still routes to the owner by default, because the owner's precondition and sequencing exist for a reason — `workflow-finalize` gates on a prior `workflow-review` APPROVE before its Step 2 runs `receive-review`. Route to the sub-step directly only when the user's own words scope the request to that step alone (explicit "just," "only," an imperative naming the skill, or an unambiguous statement that the rest of the pipeline already ran or isn't wanted).

**The carve-out beats the owner-default when the user's verb+skill-name form is imperative.** An imperative that names a skill — "Run receive-review on PR #17", "run clarity-review on this doc" — IS the explicit sub-step scope: the user has already routed, and the router's job is dispatch, not second-guessing (baseline case 24: this exact form lost to the owner-default and misrouted to `workflow-finalize`). Ambiguity exists only when the skill name appears *descriptively* ("the receive-review step probably applies here", "this needs review-comment handling") — there, and only there, prefer the owner and let its own gates decide whether the sub-step is reachable yet.

This is why `receive-review` and `prompt-builder` are handled differently above: `receive-review` has no independent use outside a review-gate context (default: route to the owner, `workflow-finalize`, with the explicit-sub-step carve-out); `prompt-builder`'s own contract documents standalone "manual Codex task" use as a first-class case (default: route directly, since the owner-vs-sub-step question is already answered in the skill's own contract).

## Bug routing rule

Bugs route to `workflow-deliver` with `kind=bug`, even if the fix appears obvious. Prefer correct classification — but the diagnose-first guarantee no longer lives in routing: `ledger.sh init --kind bug` inserts required `diagnose`/`fix` steps and the kernel refuses `stamp fix` without a captured red repro. A bug discovered mid-run MUST be corrected by re-initing with `--kind bug` before any fix commit (`init --force` on an active run — audited force-init; prior stamps discarded), not by re-routing; a misroute is therefore recoverable, not fatal (D-006 #11; the old "never route bugs to workflow-build-one" rule is superseded). Diagnosis-first still prevents:

- Fixing symptoms instead of root causes
- Missing regression tests
- Incorrect assumptions about "simple" bugs

## PRD vs backlog routing rule

**Use `execute-prd` when issues have a parent PRD and dependencies between them.** Use `run-backlog` only when the `to-issues` dependency audit says issues are independent and can be processed in any order.

| Signal | Route |
|--------|-------|
| "Execute PRD #N" / "implement all children" / parent issue with child task list | execute-prd |
| "Run the backlog" / batch of independent `ready-for-agent` issues | run-backlog |
| Single issue, no parent context | workflow-deliver (kind per issue label) |

If unclear: check whether the issues reference a parent. If yes → execute-prd. If no → run-backlog.

## Catalog tier (model-invocation-locked skills)

47 skills carry `disable-model-invocation: true` (DL-0008, applied in PR #83) — they never appear in the ambient per-session skill listing, but remain fully invocable by name (`/skill-name`) or by path from another skill's Flow. The classification table above intentionally carries no per-skill routing row for them. If a request clearly matches one of these, that **is** the route — treat it as catalog tier, not "no route exists," and invoke it directly by name (or ask which one, if more than one plausibly matches).

Full one-line descriptions: `_docs/skills-index.md`. Global pointer (same list, shorter): `dotfiles/.claude/CLAUDE.md` § "Skill catalog (locked skills)". This section is the router-side cross-reference — do not re-copy full descriptions here; category + invoke pattern only.

**Analytics** (16) — e.g. `/sql-review`: `analysis-council`, `analysis-design`, `dashboard-design`, `dashboard-review`, `data-quality-audit`, `data-readiness-check`, `decision-memo`, `experiment-design`, `lineage-audit`, `metric-council`, `metric-design`, `metric-tree-review`, `sql-review`, `strategic-analysis-review`, `vendor-council`, `viz-integrity`

**Incident** (2) — e.g. `/incident-triage`: `incident-retro`, `incident-triage`

**Library/infra** (13) — shared scaffolding, reference protocols, and repo tooling; e.g. `/setup-worktree`: `council-scaffolding`, `describe-pr`, `docs-audit`, `git-guardrails`, `graph-first`, `herdr-launch`, `omc-reference`, `post-mortem`, `review-scaffolding`, `runbook-author`, `setup-skills`, `setup-worktree`, `watch-ci`

**Knowledge/utility** (6) — general-purpose personal-knowledge and dev-utility skills; e.g. `/wayfinder`: `codebase-design`, `domain-modeling`, `implement`, `mock-data-generator`, `wayfinder`, `zoom-out`

**Retired** (directories deleted, git history is the tombstone): 2026-08-18 D-006 decision 14 — `pr-responder` → `receive-review`, `pr-review` / `review` → `workflow-review`, `slop-cleaner` → `humanizer`, `v1-idea-grill` → `grill-with-docs`; 2026-08-18 corpus-optimization audit batch 1 (Alex-approved) — `brain-ops` → `rowan` (PR #149 had already deprecated brain-ops in rowan's favor; rowan is the live knowledge-OS skill). If a retired skill is invoked by name, use the successor.

## Human-Gate Taxonomy Preflight

When a workflow or execution describes a human gate or approval point, classify it using the gate taxonomy in `dotfiles/.config/agents/skills/_docs/human-gate-taxonomy.md` (cite the relative path). The taxonomy distinguishes four gate types:

| Gate Type | Blocks AFK? | How Satisfied |
|-----------|-------------|---------------|
| **maintainer-decision** | ✅ YES | User/maintainer approves the PR or issue before merge |
| **operator-runtime** | ✅ YES | Operator confirms or executes a runtime action in the workflow |
| **secret-custody** | ✅ YES | Human custody/audit before secret is deployed |
| **reviewer-validation** | ❌ NO | Independent reviewers reach consensus via `workflow-review` + checks pass |

Only the first three gate types block AFK execution by default. When a route card or execution mentions "needs human review," classify which type applies before emitting the gate. If only `reviewer-validation` applies, the route is AFK-eligible (subject to `workflow-review` and merge authority). If any of the first three apply, AFK is blocked until satisfied.

**Path:** Reference the taxonomy by relative path from the repo root: `dotfiles/.config/agents/skills/_docs/human-gate-taxonomy.md`.

## Preflight

Before dispatching, `Load and run` `workflow-ledger/SKILL.md`: run
`workflow-ledger/scripts/ledger.sh preflight --skill <target>` — it parses the
target's `Requires:` field and checks each CLI tool (exit 0 all present,
exit 1 listing missing, exit 5 unknown skill; unparsed prose is reported, not
dropped). MCP-server and project-config requirements it cannot check remain a
manual verification. If anything required is missing: report what and why,
suggest installation or an alternative, and do NOT proceed.

### Canonicality Gate (path/layout mutations)

**Before dispatching any route that mutates filesystem layout** (symlinks, path moves, "source of truth" / Stow / mirror changes, bulk path rewrites), ask and record in the route card:

> Is canonicality required over compatibility?

- **Canonicality** → eliminate indirection (symlinks, duplicate mirrors); one source of truth; preserve behavior by rewriting callers.
- **Compatibility** → keep shims/symlinks that older tooling still needs; document the dual path.

Default to the user's stated intent. If they said "source of truth" / "no symlinks" / "canonical," do not optimize for compatibility first. Skip only for read-only routes that mutate no paths.

### Prior-Art & Roadmap Gate

**Before dispatching any build, implement, design, ADR, or scaffold route, check for existing or planned work first.** This is a hard gate — it prevents conflicts and double work.

Scan the target repo (when one exists) for prior art matching the request:

1. `docs/roadmap.md` — the **single canonical** capability roadmap. Is this already a capability/band? (Legacy plans live only in `docs/roadmaps/archive/`.)
2. `docs/adr/` + `docs/decision-log.md` — is the decision already recorded?
3. `protocol/`, `libs/`, `docs/prd*/`, `docs/contracts/` — does the thing already exist (built or specced)?
4. Open issues (`gh issue list`) — is it already tracked?

Outcome:

- **Already built/specced** → halt the design/build route. Report where it lives. Redirect to the real gap (wiring, hardening, the existing roadmap phase), not net-new.
- **Planned but not built** → route to the existing roadmap item / issue, not a fresh plan.
- **Genuinely absent** → proceed, and cite in the route card that prior art was checked.

**Spec vs built:** before classifying a conflict as blocking, distinguish specced from implemented — inspect code/tests, not just docs. When a charter/spec doc and running code disagree, prefer the running code as ground truth. A doc-level contradiction is often resolved (or its real shape revealed) by what is actually built.

Record the check in the route card `Why this flow` line (e.g. "prior-art scan: no existing roadmap/ADR/lib"). Skip only for read-only or `direct` routes that mutate nothing.

### Worktree Baseline Gate

Before dispatching any workflow that mutates code, commits, creates a PR, or runs a delivery loop, create or require a fresh isolated worktree from the resolved workflow base via `setup-worktree/scripts/worktree-baseline.sh` (D-005's `cut`/`verify`/`emit` interface):

```bash
setup-worktree/scripts/worktree-baseline.sh cut --branch <workflow-branch> --path <worktree-path>
```

`cut` resolves the workflow base per `base-branch-policy.md` (fetch + prefer `origin/staging`, fall back to the remote default), creates the worktree, and prints the `WORKFLOW_BASE_GATE` block plus the `WORKTREE_BASELINE_GATE` line — record that output verbatim as gate evidence; do not hand-write or reformat it. The workflow must run inside that worktree. Do not run mutating delivery workflows from the primary checkout or from a branch based on local `main`/`staging`. If the script halts (non-zero exit, e.g. code 7 when neither `origin/staging` nor the remote default branch can be resolved), halt and ask the user for the replacement base.

**Parallel/`team` fan-out — one isolated worktree per lane (precondition, not recovery).** When two or more lanes run concurrently (`team` budget, parallel phases, AFK drive-to-done), each lane gets its OWN fresh worktree — invoke `worktree-baseline.sh cut` separately per lane — cut from the resolved base *before* any lane is dispatched — never share a worktree or reuse an existing checkout across lanes. Independent lanes branch off `origin/main`/base directly; a dependent lane stacks explicitly on its parent's commit (`cut --parent-branch <parent> --parent-pr <n>`). Resolving "which repo/worktree am I in" mid-fan-out is a signal the gate was skipped.

Read-only workflows (`workflow-review`, `skill-system-audit`, repo audits, document workflows) do not create the worktree themselves, but if they are reviewing or finalizing code changes they must verify the change branch/worktree was cut from the resolved workflow base — `setup-worktree/scripts/worktree-baseline.sh verify --path <worktree-path>` confirms this.

## Default Product Flow (Canonical Vertical-Slice Workflow)

The authoritative workflow for all product work follows this sequence:

```
workflow-feature → grill-with-docs → decision-log → to-prd →
to-issues → triage →
[execution: workflow-deliver | execute-prd | run-backlog] →
workflow-review → workflow-finalize → cleanup-delivery
```

**Key characteristics of this flow:**

- **Vertical slices** with complete readiness criteria (per `triage`'s readiness checklist): clear acceptance criteria, dependency status, verification commands, rollback expectation, AFK/HITL classification, outage-risk classification, workflow-base worktree policy, review/finalize policy, human review requirement, and module grill evidence (when applicable).
- **AFK-eligible** issues have `ready-for-agent` only after triage confirms all readiness criteria.
- **No horizontal issue creation** at any stage — all issues are independent vertical slices with observable outcomes.
- **Matched wording** to #43/#47: emphasis on vertical-slice concepts, AFK safety gates, outage risk, rollback expectations, verification, and decision-log references.

## Specialized Audit / Refactor Lane (NOT the default product flow)

`repo-audit` and `to-prd` migration mode form a **specialized lane** separate from the default vertical-slice product workflow (successor to the retired `design-plan` + `execute-phase` pair — D-006 planning-lane consolidation, 2026-08-19):

- **Repo evidence audit** → `repo-audit` (input to current workflow, not a default loop itself)
- **Route audit findings** based on type:
  - Product/feature gaps → feed into `workflow-roadmap`, then proceed through the default flow above
  - Already-clear vertical implementation slices → route to `to-issues` or `triage` directly
  - Repo-wide refactors, migrations, or multi-phase remediation → `to-prd` **migration mode** (FIND-NN/REQ-NN anchors, parent + ordered children, pilot/canary, rollback, sync-gate child issues) → `to-issues` → `triage` → `execute-prd`; each child carries the normal `workflow-review` and `workflow-finalize` gates
- **Do not route audit findings straight to execution** — a human-approved roadmap, or a migration-mode PRD built from a human-approved audit/brief with triaged children, must exist first
- **Key constraint:** PRD/spec parent issues must not be labeled `ready-for-agent` (per `triage` skill) — only child implementation issues produced by `to-issues` and meeting all readiness criteria may receive `ready-for-agent`

## Roadmap Gate Rule

For product/feature planning that will produce PRDs and implementation issues, require an approved `workflow-roadmap` artifact before dispatching `to-prd` (product mode) or `to-issues`.

- If roadmap evidence exists and is in scope: proceed.
- If roadmap is missing, stale, or out of scope: route to `workflow-roadmap` first and halt downstream dispatch until approved.
- Only an explicit user waiver may bypass this gate.
- **Migration-mode exception (in-rule, not a waiver):** `to-prd` migration mode satisfies this gate with its input artifact instead — a **human-approved** repo-audit report or migration brief, per the mode's own roadmap-gate delta (D-006 planning-lane consolidation, 2026-08-19). The scope there is already settled; do not force a `workflow-roadmap` detour.

### Roadmap Doc Invariant (drift guard)

The roadmap is a **capability-altitude** artifact, not a status tracker. Enforce, and instruct `workflow-roadmap` to enforce:

- **Exactly one canonical `docs/roadmap.md`.** Never create a dated/named roadmap sibling (`docs/roadmaps/2026-*.md`, `fleet-roadmap.md`). Update the canonical, or move superseded planning to `docs/roadmaps/archive/`. Where a repo ships it, `python3 scripts/chorus/validate.py roadmap` fails on a competing file.
- **Never restate execution state in the roadmap** — per-issue status, agent/board state, and progress live in GitHub + the workboard. The roadmap holds capabilities ordered by `depends on` (bands Now/Next/Later), each with `outcome` · `unlocks` · `effort` · `priority`. Copied state is what drifts.
- New idea → append a capability (or backlog-pool entry) with its deps; do not renumber or fork the doc.

## Learning Loop

At the end of any confirmed non-trivial route, and whenever the user corrects the routing choice, produce a `ROUTER_LEARNING_NOTE`.

```markdown
ROUTER_LEARNING_NOTE:
- Initial classification:
- Confirmed classification:
- Confidence was:
- User correction:
- What made the route right or wrong:
- Accepted feedback:
- Durable destination: none|project decision log|backlog|skill-backlog (via session-insight reflection)|memory proposal
- Skill/workflow improvement suggested:
```

Learning rules:

- Do not silently edit memories or skills.
- Project-specific lessons go to the project decision log only when the active workflow allows writing project artifacts.
- Future-work items go to backlog only with user approval or inside a workflow that already owns issue creation.
- Reusable process lessons become `session-insight` reflections, harvested and triaged by `skill-backlog`.
- If the workflow was AFK, multi-stage, corrected by the user, halted for a process gap, or produced planning/execution artifacts, run or recommend `skill-system-audit` before final closure.
- If a recommendation is accepted during a review or audit loop, classify it before persisting: project-specific, future-work, reusable process, or local wording only.

## Graceful degradation

These fallbacks apply only when the target workflow does not list the
missing tool in `Requires:` and does not define it as a blocking runtime
gate. If a required dependency is missing, the preflight rule above wins:
halt, report the missing requirement, and do not proceed.

| Missing tool | Impact | Behavior |
|--------------|--------|----------|
| `gh` | Can't interact with GitHub | Local-only analysis is allowed only for non-shipping workflows that do not require `gh`; delivery workflows halt |
| OMC | Can't dispatch to Codex team | Halt unless the selected workflow/mode explicitly allows Claude fallback and the user approves it |
| CORA | Can't validate contracts | Skip CORA validation only; do not skip the target workflow's own gates |
| `playwright-mcp` | Can't run UJ QA | For frontend/user-facing changes, halt for human waiver or setup; do not silently skip |
| Project test runner | Can't verify | Halt and request setup info |

## Process

```
0. Resume check: `ledger.sh reconcile`; if an active/paused run exists, offer to resume at the reconciled frontier before classifying
1. Receive work description (user input, issue, or automated trigger)
2. Classify using signal table above
3. If ambiguous or confidence is low: ask ONE clarifying question (max 1 — don't interrogate)
4. Select the smallest safe agent budget
5. Emit ROUTE_CARD
6. Wait for user confirmation unless the route qualifies for the direct/read-only skip
7. After confirmation, run `ledger.sh preflight --skill <target>` (plus manual MCP/project-config checks and the Prior-Art & Roadmap Gate for any build/implement/design/ADR route); persist the run via `ledger.sh init`
8. If preflight passes: dispatch to target workflow (`ledger.sh set <step> active` on dispatch)
9. If preflight fails: report missing requirements
10. At completion, halt, or user correction: emit ROUTER_LEARNING_NOTE and run or recommend skill-system-audit when triggered
```

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
