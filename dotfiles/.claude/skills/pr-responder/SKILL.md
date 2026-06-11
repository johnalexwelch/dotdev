---
name: pr-responder
model: sonnet
description: "Processes open PR review comments in bulk: decides which to action, drafts the code edits, and posts replies for the rest. The actioning step after receive-review. Use when a PR has accumulated review comments to work through."
---

# PR Responder

## Purpose

After review lands on a PR, the responses pile up: blockers to fix, nits to address, comments to acknowledge, suggestions to push back on. Doing them one-by-one is slow and error-prone. This skill processes the queue end-to-end.

It composes with — does not replace — `receive-review` (which validates whether each comment is technically right) and `workflow-finalize` (which gates the merge).

## When to invoke

- "Respond to all the PR comments"
- "Action the review feedback on PR #X"
- After bots (e.g., Claude Code Review, Copilot) and humans have left a batch of comments

Routing:
- Evaluate whether each comment is right → `receive-review` first
- Just write a reply → use `gh pr review` / `gh api`; this skill is for the multi-comment batch
- Re-review after responses → `workflow-review`

## Process

### 1. Pull all open review comments on the PR

Via `gh pr view <num> --json reviews,comments` or `gh api repos/.../pulls/<num>/comments`.

For each comment:
- ID
- Author (human / bot — categorize: blocker | nit | question | suggestion)
- File + line
- Comment text
- Resolution status (open, resolved, outdated)

### 2. Classify each comment

| Class | Meaning |
|-------|---------|
| **Blocker** | Author won't approve until this is addressed |
| **Non-blocker / suggestion** | Author flagged for consideration |
| **Nit** | Stylistic; usually optional |
| **Question** | Author wants clarification |
| **Bot finding** | Automated tool comment |
| **Compliment / acknowledgment** | No action needed |

### 3. For each comment, run `receive-review` evaluation

For each substantive comment, ask:
- Is the comment technically correct?
- Is the suggested change actually better?
- Does it fit the codebase patterns?
- What's the cost of agreeing vs. pushing back?

Output a per-comment verdict: **action** / **reply-only** / **push-back** / **defer-to-followup**.

### 4. For "action" comments, draft the code change

Plan the actual edits:
- Group related fixes (same file, same concern) into one edit
- Order edits to avoid conflicts
- Note where one fix may require updating tests / docs

### 5. For "reply-only" comments, draft the response

Acknowledge concisely. "Good point — fixed in <commit>." or "Considered this; chose <approach> because <reason>."

### 6. For "push-back" comments, draft the response

Be specific:
- Acknowledge the reviewer's concern
- State the reason for the choice
- Offer a falsifier ("would change my mind if...")
- Or: propose a follow-up issue if the disagreement is real but out-of-scope

### 7. For "defer-to-followup" comments, file an issue

Create a follow-up issue, link from the comment reply.

### 8. Apply the code changes

Use Edit / Write to make the actual changes. Re-run tests / lint locally.

### 9. Commit and push

One commit per logical group of fixes (or one commit total, depending on PR norms). Follow conventional-commits format.

### 10. Post the replies

For each comment, post the drafted reply via `gh pr review` or `gh api`.

### 11. Output summary

```markdown
## PR Response Summary

**PR**: #<num>
**Comments processed**: <N>

### Actioned (<count>)
- [<file>:<line>] <comment summary> — fixed in <commit>
- ...

### Reply-only (<count>)
- [<file>:<line>] <comment summary> — replied: "<short>"
- ...

### Pushed back (<count>)
- [<file>:<line>] <comment summary> — reply: "<short>"
- ...

### Deferred to follow-up (<count>)
- [<file>:<line>] <comment summary> — filed issue #<X>

### Tests / lint
- <pass | fail with notes>
```

## Rules

- Run `receive-review` on each substantive comment before actioning. Don't blindly accept feedback.
- Group fixes into logical commits, not one-comment-per-commit.
- Reply to every comment, even acknowledgments. Silence reads as ignoring feedback.
- Push back with reasoning, never with dismissal.
- If a comment reveals a real problem out-of-scope, file a follow-up issue rather than expanding the PR.
- Re-run tests + lint before pushing. Don't trust that small fixes don't break anything.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Files and modules touched** by the PR — their owners, dependencies, prior bug history
- **Reviewers** and their typical comment patterns — common nits vs. blockers
- **Related ADRs** that constrain how the response should land
- **Prior similar PRs** in this area — what feedback was actioned vs. deferred

Insertion point: step 3 (run receive-review per comment) — graph context helps classify push-back vs. action and informs which patterns the reviewer cares about. Tag classifications informed by graph as `[GRAPH-PRIOR]`.

`--no-graph` skips. `--graph` forces graphify on the repo first.

## Contract

Consumes: PR number or PR URL
Produces: code changes applied, replies posted, summary report
Requires: `gh` CLI, repo write access, tests/lint runnable locally
Side effects: modifies code, commits, pushes, posts PR replies, may file follow-up issues
Human gates: before pushing, surface the summary and ask for confirmation if any push-back replies are being posted (those are higher-stakes)

## Context

Typical workflows: post-review batch processing, pre-merge cleanup
Pairs well with: receive-review (per-comment evaluation, this skill orchestrates), workflow-review (the review that produced these comments), workflow-finalize (downstream — gates merge after responses are in)
