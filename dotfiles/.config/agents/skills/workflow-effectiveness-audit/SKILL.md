---
name: workflow-effectiveness-audit
model: sonnet
reasoning: high
description: Evaluate whether skills and workflows are actually working. Audits recent agent transcripts, GitHub PRs/issues, and execution artifacts for skipped steps, missing subagents, unresolved review comments, weak handoffs, and routing gaps.
codex-compatible: true
---

# Workflow Effectiveness Audit

## Purpose

Measure whether the skill system is producing the behavior it promises. This is a governance and feedback-loop skill: it finds places where workflows were invoked but required steps were skipped, degraded silently, or produced weak outcomes.

Use this when the user asks:

- "Are these skills working?"
- "Evaluate workflow effectiveness"
- "Find gaps in our workflows"
- "Why did this workflow skip a step?"
- "Audit recent agent transcripts"
- "Did PRs merge with unresolved review comments?"

## Contract

Consumes: recent agent transcripts, skill files, GitHub PR/issue state, docs/executions artifacts, optional CORA findings
Produces: workflow effectiveness scorecard, gap findings, recommended skill/workflow fixes
Requires: git
Side effects: none by default; may create follow-up issues only with approval
Human gates: approval before editing skills, creating issues, or applying labels

## Context

Typical workflows: skill library governance, weekly workflow retro, post-incident review after agent misses
Pairs well with: skill-maintenance, reconcile-issues, receive-review, workflow-router

## Load References

Load only the references needed for the step in progress:

- Step 2 (expected traces): `references/expected-traces.md` — per-workflow required trace table.
- Step 4 (gap patterns): `references/gap-patterns.md` — the numbered checklist of known gap patterns.

## Workflow Progress Reporting

Follow `../_docs/step-ledger.md` (step-ledger protocol): emit the `WORKFLOW_STEPS` ledger before executing or dispatching any step, update it at every status transition, and include the final ledger in every halt, handoff, and completion response.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| <step name> | required|conditional|optional | pending|completed|skipped|blocked|failed|not_applicable | <evidence, reason, or -> |
```

## Process

### 1. Define audit window

Default to the most recent 7 days or the latest 20 parent transcripts. If the user names a repo, PR, issue, or workflow, scope to that.

Collect evidence from:

- Parent agent transcripts only for user-facing behavior. Use subagent transcripts as supporting evidence, but cite parent transcript IDs to the user.
- `~/.claude/skills/` and `~/.codex/skills/` for the current skill definitions.
- `docs/executions/` artifacts: phase runs, handoffs, CI runs, PR bodies, retros.
- GitHub PRs/issues via `gh` when available.
- CORA findings when CORA is available.

### 2. Build expected workflow traces

Load `references/expected-traces.md` and, for each workflow invocation, derive the expected trace from its per-workflow table.

Mark each required step as:

- `done`: evidence exists
- `skipped-with-reason`: explicitly skipped with a valid reason
- `skipped-silently`: expected step missing and no reason recorded
- `failed`: attempted but did not complete
- `unknown`: evidence missing or ambiguous

### 3. Score effectiveness

Produce a scorecard with these dimensions:

| Dimension | What to measure |
|-----------|-----------------|
| Routing accuracy | Did the router pick the right workflow for the user request? |
| Step compliance | Were required workflow steps completed or explicitly skipped? |
| Review coverage | Did `workflow-review` choose the right `review_profile` and produce independent review evidence for required lanes? |
| Review resolution | Were PR review comments fixed, replied to, waived, or followed up before merge? |
| Issue hygiene | Were Closes/Fixes/Addresses dispositions used correctly? |
| Verification quality | Were tests/CI/lints actually run and evidenced? |
| Handoff quality | Did halts and completions produce usable handoff artifacts? |
| Autonomous backlog safety | Did module PRDs/issues preserve provenance, candidate confidence, grill-with-docs module answers, MODULE_GRILL_CONSENSUS artifacts, CONTEXT/ADR updates when needed, scoped second-pass decisions, rollback expectations, queue approval, outage-risk controls, and all gate blocks per PR? |
| Sync health | Did Claude/Codex skill copies and Stow source remain aligned? |

Use a simple rating:

- `green`: no material misses
- `yellow`: minor gaps or justified skips
- `red`: required step skipped, unsafe merge behavior, or lost context

### 4. Detect known gap patterns

Load `references/gap-patterns.md` and always check for every numbered pattern in that checklist.

### 5. Output

Return:

```markdown
# Workflow Effectiveness Audit

## Scope
- Window:
- Sources:
- Workflows audited:

## Scorecard
| Dimension | Rating | Evidence | Recommended fix |
|-----------|--------|----------|-----------------|

## Findings
### RED
- Finding, evidence, why it matters, proposed fix

### YELLOW
- Finding, evidence, proposed fix

### GREEN
- What is working as intended

## Repeated Corrections
- User correction pattern -> workflow/skill to update

## Autonomous Backlog Gate Matrix
| PR/Issue | Module PRD provenance | Confidence | Module grill | Rollback | Human review | AFK queue approval | Risk policy result | Draft PR state | Worktree gate | Review gate | Finalize gate | Result |
|----------|-----------------------|------------|--------------|----------|--------------|--------------------|--------------------|----------------|---------------|-------------|---------------|--------|

## Follow-up Work
- Skill edits recommended
- Issues to create
- CORA/sync checks to run
```

## Rules

- Findings require evidence. Cite transcript IDs, PR numbers, issue numbers, or artifact paths.
- Do not cite subagent transcript IDs to the user; cite the parent transcript ID.
- Do not create issues or edit skills unless the user asks for fixes or approves the proposed change list.
- Prefer changing the narrowest skill that owns the failure. Example: unresolved PR comments belong in `receive-review`, `workflow-finalize`, `watch-ci`, and `reconcile-issues`, not in every workflow.
- Treat green CI as insufficient evidence for reviewer-comment resolution.
