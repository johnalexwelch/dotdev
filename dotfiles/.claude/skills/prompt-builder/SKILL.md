---
name: prompt-builder
description: Generate an optimized agent prompt for a ready-for-agent issue. Reads the issue body, acceptance criteria, labels, related files, and project context to produce a copy-paste-ready prompt tailored for Claude or Codex. Use when preparing work for AFK execution, Codex dispatch, batch runs, or handoffs.
codex-compatible: true
---

# Prompt Builder

Generate a high-quality agent prompt from a GitHub issue so the executing agent starts with full context instead of figuring it out from scratch.

## Contract

Consumes: GitHub issue number (or URL), decision log, optional target tool hint (claude, codex)
Produces: structured agent prompt (printed to chat + optionally saved to file or issue comment)
Requires: gh
Side effects: optionally posts prompt as issue comment (with `--attach` flag)
Human gates: ambiguous behavior, scope, security, data, UX, or acceptance criteria blocks AFK prompt generation

## Soft Context

Typical workflows: pre-dispatch (before run-backlog, workflow-build-one, or manual Codex task), handoff prep
Pairs well with: triage (runs after triage labels issues ready-for-agent), run-backlog (calls prompt-builder per issue), handoff (prompt-builder generates prompts for suggested next-session work), workflow-build-one (can consume the generated prompt)

## Process

### 1. Read the issue

```
gh issue view <number> --json title,body,labels,assignees,milestone
```

Extract:
- Title and description
- Acceptance criteria (look for checkboxes, "AC:", "Acceptance Criteria", numbered lists under a criteria heading)
- Labels (bug, feature, ready-for-agent, security, frontend, etc.)
- Referenced issues, PRs, or plan documents
- Any file paths mentioned in the body

### 2. Gather context

- **Related files.** If the issue mentions file paths, verify they exist. If not, infer likely files from the issue title/description using a quick codebase search.
- **Project structure.** Check for CONTEXT.md, `docs/decision-log.md`, existing ADRs, test conventions (jest, pytest, vitest, etc.), build tools.
- **Prior work.** Check if the issue references a design plan, PRD, or parent issue. If so, read the relevant sections.
- **Dependencies.** Check if other issues block this one (`gh issue view <N> --json body` for "blocked by" or "depends on" references).

### 3. Determine execution strategy

Based on issue labels and content:

| Signal | Strategy |
|--------|----------|
| Label: `bug` | Use workflow-debug (diagnosis-first) with strict-tdd profile |
| Label: `security` | Flag for human review gate; do not auto-merge |
| Label: `frontend` | Include user-journey-qa step |
| Acceptance criteria are test-expressible | Use TDD approach |
| Issue references a design plan phase | Use execute-phase with the plan |
| Issue is a refactor with no behavior change | Use normal profile, focus on test preservation |
| No test runner detected | Flag as blocker; prompt should request setup info |

### 4. Generate the prompt

Structure the output as:

```markdown
## Task

[One sentence: what to build/fix, drawn from the issue title]

## Issue

[Issue URL and title]

## Acceptance criteria

[Extracted criteria as a numbered list. For execution prompts, do not infer missing criteria; halt and mark `needs-human`. For planning briefs only, inferred criteria must be labeled `[inferred]`.]

## Skill to invoke

[Which workflow/skill to use and why]
Example: `workflow-build-one` — this is a ready-for-agent issue with clear acceptance criteria.

## Files to read first

[List of file paths the agent should read before starting work]

## Constraints

[Any constraints extracted from labels, related issues, or project conventions]
- Must create a fresh per-issue worktree from `origin/staging` before starting implementation and include `WORKTREE_BASELINE_GATE` in the handoff
- For dependent stacked work, may instead create a fresh per-issue worktree from the clean parent branch only when the parent PR has complete gates; include `STACKED_WORKTREE_GATE` and target the PR at the parent branch
- Must run `workflow-review` and include `WORKFLOW_REVIEW_GATE` with `verdict: APPROVE`
- Must run `workflow-finalize` and include a complete `WORKFLOW_FINALIZE_GATE`
- Must create or update only a draft PR unless an existing non-draft PR already exists
- Must not mark the PR ready, approve it, merge it, enable auto-merge, force-push, rebase, or use destructive git
- TDD required (bug label)
- Must not break existing API contract (referenced in CONTEXT.md)
- Security-sensitive: human review gate before merge

## Context

[Brief project context the agent needs — domain terms, relevant decision-log entries, architectural decisions, related recent work]

## Verification

[How the agent should verify the work is complete — test commands, manual checks, expected behavior]
```

### 5. Adapt for target tool

**For Codex (AFK):**
- Be more explicit about file paths (Codex can't browse interactively)
- Include the full acceptance criteria (no "see issue for details")
- For root issues, include the exact mandatory per-issue worktree command before any code changes: `git fetch origin --prune && git worktree add -b <issue-branch> <issue-worktree-path> origin/staging`
- For root issues, require final handoff evidence: `WORKTREE_BASELINE_GATE: origin/staging -> <branch> @ <path>`
- For stacked dependent work, do not include the root `origin/staging` worktree command as the implementation command. Include the parent-gate precondition, create the child worktree from the parent branch with `git worktree add -b <child-branch> <child-worktree-path> <parent-branch>`, target the child PR at the parent branch, and require final handoff evidence:
  `STACKED_WORKTREE_GATE: origin/staging -> <parent-branch> -> <child-branch> @ <child-worktree-path>; parent_pr: #<n>; parent_gates: complete`
- Require `workflow-review` with a real `WORKFLOW_REVIEW_GATE` and `verdict: APPROVE`; green CI, GitHub reviews, Claude Code Review, Bugbot, or Codex review do not substitute for this gate.
- Require `workflow-finalize` with a complete `WORKFLOW_FINALIZE_GATE`.
- Require draft PR handoff only; do not mark ready, approve, merge, enable auto-merge, force-push, rebase, or use destructive git.
- Do not ask clarifying questions inside the generated prompt. If ambiguity affects behavior, scope, security, data, UX, or acceptance criteria, halt prompt generation and mark the issue `needs-human` instead of dispatching Codex.
- Conservative assumptions are allowed only for non-behavioral implementation details; record them explicitly.
- Include relevant decision-log entries when they explain why the issue asks for a particular approach. Do not make the worker rediscover accepted alternatives.
- Specify the test command to run
- **Always include handoff instruction:** append a section instructing the agent to produce a handoff artifact at `docs/executions/handoffs/<date>-<issue-slug>.md` before completing, summarizing what was done, what's left (if anything), and the PR link. This ensures context is preserved even when the Codex session ends.

**For Claude (interactive):**
- Can be slightly less verbose (Claude can ask the user)
- Include "Ask the user if..." for genuinely ambiguous points
- Reference skills by name (Claude has skill access)
- Include a note: "When this workflow halts or completes, invoke the handoff skill to preserve context for the next session"

### 6. Output

Print the prompt to chat. Then offer:
- `--attach`: post as a comment on the issue (useful for Codex pickup)
- `--file <path>`: save to a file (useful for batch scripts)
- `--clipboard`: copy to clipboard (useful for manual paste into Codex CLI)

## Rules

- Never fabricate acceptance criteria. If criteria are absent or materially ambiguous, halt AFK prompt generation and mark the issue `needs-human`. `[inferred]` criteria are allowed only for planning briefs, not execution prompts.
- Never generate a root execution prompt that omits mandatory per-issue worktree creation from `origin/staging`. If the issue cannot name a safe branch/worktree convention, include placeholders and require the worker to resolve them before coding.
- Never generate a stacked execution prompt unless the parent PR gate evidence is complete and the prompt tells the worker to target the child PR at the parent branch.
- Never generate an execution prompt that omits `workflow-review`, `WORKFLOW_REVIEW_GATE`, `workflow-finalize`, `WORKFLOW_FINALIZE_GATE`, draft-only PR handoff, and no mark-ready/merge/auto-merge/destructive-git constraints.
- Never assume the test runner. Check the project for package.json scripts, Makefile targets, or pytest.ini before suggesting test commands.
- If the issue is blocked by another issue, say so in the prompt. Do not generate a prompt that will lead to wasted work.
- Keep prompts under 500 lines. The point is focused context, not a novel.
- If the issue lacks enough information for a good prompt, say so and suggest what to add to the issue body before dispatching.

## Child Brief Mode

When called by `execute-prd` with `mode=child-brief`, produce a child execution brief rather than a direct implementation prompt.

Required inputs:

- parent issue
- child issue
- dependency context
- scope boundaries
- acceptance criteria copied from the child issue

Output must include:

- task summary
- issue URL/title
- acceptance criteria
- workflow: `workflow-build-one`
- files to read first
- related parent/child work
- dependencies
- scope
- verification
- handoff path

If child acceptance criteria or scope are missing or materially ambiguous, do not infer them for execution. Mark the child `needs-human` and return the missing information needed.
