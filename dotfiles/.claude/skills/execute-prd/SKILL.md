---
name: execute-prd
model: sonnet
reasoning: medium
description: "Execute a parent PRD issue tree end-to-end: orders children by dependency, generates execution briefs, creates worktrees, implements unblocked slices, opens PRs, runs review/CI, reconciles, writes handoff. Use for \"execute this PRD\", \"implement all children of #N\"."
codex-compatible: true
---

# Execute PRD

## Model selection

Dispatch per-slice implementation workers on **Sonnet** (`model: sonnet`); reserve **Opus** for planning, review/CI reasoning, and reconciliation. Escalate a worker to Opus only for genuinely hard logic.

## Output discipline (during execution only)

While running the mechanical execution/implementation loop, compress **routine progress narration** to caveman style — drop articles, filler, and pleasantries; prefer `[thing] [action] [reason]. [next].` This cuts scroll and output tokens during the grind.

Snap back to **full prose** for anything that needs judgment: findings, scope violations, blockers, `NEEDS_HUMAN` gates, decisions/tradeoffs, and the final summary/handoff. The terseness is scoped to the loop — it ends when execution ends; do not carry it into the review or handoff that follows. See `caveman` for the full compression rules.

Drive a parent PRD issue tree from analysis through delivery. Unlike `run-backlog` (independent issues in batch), this skill handles **dependent, ordered, parent-aware** execution where child issues have relationships and must be sequenced.

## Contract

Consumes: parent PRD issue number (or URL), optional child issue list, optional scope boundaries, optional branch prefix
Produces: PRs (one per child issue), child execution briefs, reconciliation updates, parent handoff artifact
Requires: gh, git, subagent-dispatch, project-test-runner
Side effects: creates worktrees, branches, PRs; modifies issue labels/comments; writes handoff artifacts
Human gates: blocked children halt (with auto-handoff); not-AFK-safe children halt (with auto-handoff); missing workflow-review independent review evidence halts; review iteration exhaustion halts (with auto-handoff)

## Soft Context

Typical workflows: after workflow-feature produces a PRD + triaged issues, or when pointed at an existing PRD
Pairs well with: workflow-feature (produces PRDs this executes), workflow-build-one (executes individual children), prompt-builder (generates child briefs), reconcile-issues (post-child reconciliation), handoff (auto-invoked at exit)

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| parent | (required) | Parent PRD issue number or URL |
| children | (discover) | Child issue numbers/URLs, or discover from parent body |
| branch_prefix | `codex/<parent-slug>` | Branch prefix for all child branches |
| base_branch | resolved workflow base | Required remote base for child worktrees and PR branches |
| scope | (from parent) | Allowed files/areas; out-of-scope exclusions |
| verification | (from repo) | Commands to verify implementation |

## Flow

```
preflight → build-tree → order → [execute children] → reconcile-parent → handoff
```

## Workflow Progress Reporting

At the start of every run, display a step ledger before executing or dispatching any step.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| Phase 1: Preflight | required | pending | - |
| Phase 1.5: Resolve Workflow Base | required | pending | - |
| Phase 2: Build Issue Tree | required | pending | - |
| Phase 3: Determine Execution Order | required | pending | - |
| Phase 4: Execute Children | conditional | pending | Runs for ready children |
| Phase 5: Reconcile Against Parent | required | pending | - |
| Phase 6: Parent Handoff | required | pending | - |
```

Rules:

- Initialize every step as `pending`.
- Required steps cannot be skipped. If a child is blocked, mark the child disposition, not the workflow step, as blocked.
- Include the final ledger in every halt, handoff, and completion response.

### Phase 1: Preflight

1. Confirm repo and working directory
2. `git fetch origin --prune`
3. Load `setup-worktree/references/base-branch-policy.md`, resolve `<workflow-base-ref>`, and record `WORKFLOW_BASE_GATE`.
4. Confirm `gh` auth works
5. Discover repo conventions:
   - Build/test commands from package.json, Makefile, CI workflows
   - Repo-local skills from `.agents/skills/` or similar
6. Inspect current open PRs for overlap:

   ```
   gh pr list --state open --json number,title,headRefName,baseRefName,url,labels
   ```

7. Inspect recently merged PRs for already-done work:

   ```
   gh pr list --state merged --limit 20 --json number,title,headRefName,mergedAt
   ```

8. Fetch the parent PRD issue:

   ```
   gh issue view <parent> --json number,title,body,labels,state,url,assignees,milestone
   ```

9. Discover child issues from:
   - Explicit input (if provided)
   - Parent issue body task lists (`- [ ] #N`)
   - Linked issues
   - GitHub search for references to the parent
10. For each child, fetch full details (title, body, labels, state, linked PRs)

If any critical preflight step fails: **auto-handoff** with the failed command and what human action is needed.

### Phase 2: Build the Issue Tree

Load `references/issue-tree-classification.md` and use those
classifications for every child. Never fabricate acceptance criteria.
If criteria are absent or materially ambiguous, do not create an
execution brief. Mark the child `needs triage` / `needs-human` and
record the missing information. `[inferred]` criteria are allowed only
for planning summaries, not child execution.

### Phase 3: Determine Execution Order

Sequence `ready implementation` children by:

1. **Dependencies first** — schema/API/foundation before UI/integration
2. **Unblocked first** — if A depends on B, B goes first
3. **Independent in parallel** — non-overlapping file scopes can be concurrent
4. **Smaller and earlier** only if it unblocks others
5. **One PR per child** — prefer small, reviewable PRs over batching

### Phase 4: Execute Children

#### Parallel execution rules

Before executing, load `references/wave-parallelization.md`. Use it to
compute file scopes, check overlap, group children into sequential
waves, and fall back to serial execution when scope is uncertain.

#### Per-child execution

For each child (parallel within a wave, sequential across waves):

1. **Generate child execution brief** via `prompt-builder --mode child-brief` or `references/child-execution-brief-template.md`
2. **Create isolated worktree** from `<workflow-base-ref>`:

   ```
   git worktree add -b <branch_prefix>/<issue-number>-<child-slug> ../worktrees/<issue-number>-<slug> <workflow-base-ref>
   ```

3. **Record worktree baseline evidence**: `WORKFLOW_BASE_GATE` and `WORKTREE_BASELINE_GATE: <workflow-base-ref> -> <branch_prefix>/<issue-number>-<child-slug> @ ../worktrees/<issue-number>-<slug>`
4. **Execute** using the `workflow-build-one` chain:

   ```
   preflight → triage → execute-phase → workflow-review → [conditional blocking] user-journey-qa → workflow-finalize
   ```

5. **Enforce the workflow-review gate** — the child may not proceed to `workflow-finalize`, PR creation, CI monitoring, reconcile, or clean handoff unless `workflow-review` emitted a complete `WORKFLOW_REVIEW_GATE` block with `review_profile`, `independent_review: true`, and `verdict: APPROVE`. Do not substitute green CI, GitHub reviews, Claude Code Review, Bugbot, Codex review, resolved PR comments, or prose claims that review happened.
6. **Keep scope tight** — only files relevant to this child
7. **Let workflow-finalize own PR/CI/reviewer-comment closure** — do not duplicate or skip around its `describe-pr → ensure draft PR → receive-review → watch-ci → reconcile-issues` flow. The child is not complete until `workflow-finalize` emits a complete `WORKFLOW_FINALIZE_GATE` block.
8. **Enforce the Partial-Completion Contract** before the child exits. The child executor must be in exactly one state:
   - Complete: all changes committed and pushed to the remote branch.
   - WIP-paused: current progress committed with a `wip:` prefix in the subject line, naming exactly what remains, then pushed.
   - Rolled back: `git reset --hard <baseline>` leaves the worktree clean.
9. **Verify clean exit** with `git status --short`. If any source file shows `M` or `??`, the child contract is not satisfied; commit or reset and re-check before exiting.
10. **Write child handoff** at `docs/executions/handoffs/<date>-<issue>-<slug>.md`

If a child becomes blocked mid-execution: stop that child, write its handoff, continue with other unblocked children in the same wave.

### Phase 5: Reconcile Against Parent

After each child PR:

1. Update child issue state based on actual completion
2. Use closing keywords (`Fixes #N`) only when ALL acceptance criteria are met
3. Use `Addresses #N` or `Refs #N` for partial work
4. Comment on the child issue with: PR link, `WORKFLOW_REVIEW_GATE`, `WORKFLOW_FINALIZE_GATE`, verification summary, remaining work
5. Include Partial-Completion Contract evidence in the child issue comment: exit state, pushed commit or reset baseline, and final `git status --short`
6. Update parent PRD tracking:
   - Completed children
   - In-review children
   - Blocked children
   - Deferred/duplicate children
7. Do NOT mark parent complete until every child is completed, explicitly deferred, or blocked with documented next action

### Phase 6: Parent Handoff

Always write a parent handoff artifact at exit:

`docs/executions/handoffs/<date>-prd-<parent-number>-<slug>.md`

Contents:

- Parent PRD URL and title
- Child issue disposition table (status per child)
- Execution order chosen and rationale
- PRs opened (URLs, CI status, review status)
- PRs merged
- Acceptance criteria coverage summary
- Blockers with next actions
- Deferred work
- Duplicate/overlapping PRs discovered
- Verification commands and results
- Remaining human actions
- Ready-to-use prompts (via prompt-builder) for remaining children

## Child Execution Brief Template

Load `references/child-execution-brief-template.md` for the inline
fallback template whenever `prompt-builder --mode child-brief` is not
available.

## Execution Limits

- Max children per run: 10 (prevent context exhaustion)
- Review iterations per child: max 2 then auto-handoff
- CI fix attempts per child: max 3 (inherited from watch-ci)
- If context is getting long after 5+ children: auto-handoff remaining work

## Exit Behavior

Every exit produces an auto-handoff:

- Completion: parent handoff with full disposition table
- Partial completion: handoff with remaining children as ready-to-use prompts
- Blocker: handoff with specific blocker and next action
- Context exhaustion: handoff with remaining queue

Before any exit, enforce the Partial-Completion Contract for every child worktree touched in the run. Each touched child worktree must be Complete and pushed, WIP-paused with a pushed `wip:` commit that names exactly what remains, or Rolled back to its baseline with a clean worktree. Run `git status --short` in each touched worktree; if any source file shows `M` or `??`, commit or reset and re-check before writing the final parent handoff.

## Distinction from other workflows

| Scenario | Use |
|----------|-----|
| One ready issue, implement it | `workflow-build-one` |
| Batch of independent ready issues | `run-backlog` |
| Parent PRD with dependent ordered children | **execute-prd** (this skill) |
| Vague idea, needs definition first | `workflow-feature` → then `execute-prd` |

## Rules

- Never implement directly from the PRD summary — always create a child brief first
- Never fabricate acceptance criteria
- Never batch unrelated children into one PR
- Never mark parent complete until every child is resolved
- Check for duplicate/overlapping PRs BEFORE implementing
- Document conservative assumptions in the handoff
- If blocked: halt, write handoff, don't guess
