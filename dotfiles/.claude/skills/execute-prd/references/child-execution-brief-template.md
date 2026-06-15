# Child Execution Brief Template

Load this during Phase 4 for each child selected for execution. Produce the brief before coding.

```markdown
# Child Execution Brief — #<number> <slug>

## Task
<One sentence: what to build/fix>

## Issue
- URL: <url>
- Title: <title>

## Acceptance Criteria
1. <criterion from issue>

Do not include inferred criteria in an execution brief. If acceptance
criteria are absent or materially ambiguous, stop and mark the child
`needs-human` instead of producing this brief.

## Workflow
`workflow-build-one`: preflight → triage → execute-phase → workflow-review → [conditional blocking] user-journey-qa → workflow-finalize

`workflow-review` is a hard gate. The child may not proceed to `workflow-finalize`, PR creation, CI monitoring, reconcile, or clean handoff unless `workflow-review/SKILL.md` was explicitly loaded and returned APPROVE with dispatch evidence. Green CI, GitHub reviews, Claude Code Review, Bugbot, Codex review, or resolved PR comments do not substitute for this gate.

## Files To Read First
- <path> (from issue references, repo search, related PRs)

## Related Work
- Parent PRD: <url>
- Related children: <urls>
- Open PRs: <urls or "none">
- Merged PRs: <urls or "none">

## Dependencies
- Status: unblocked | blocked | partially blocked
- Blocked by: <issue/PR or "none">

## Scope
- Base: origin/staging
- Worktree: create with `git worktree add -b <branch> <path> origin/staging`
- Required handoff evidence: `WORKTREE_BASELINE_GATE: origin/staging -> <branch> @ <path>`
- Branch: <prefix>/<number>-<slug>
- Allowed: <files/areas>
- Excluded: <files/areas>

## Verification
- <repo-verified command>

## Worktree
- Path: ../worktrees/<number>-<slug>
- Branch: <branch-name>
```
