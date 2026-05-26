---
name: receive-review
description: Critically evaluate code review feedback before implementing. Prevents blind agreement with suggestions — requires verifying each comment is technically correct, contextually appropriate, and actually improves the code. Use when receiving review comments on a PR, after bot reviews land, or when a human reviewer requests changes.
codex-compatible: true
---

# Receive Review

Evaluate code review feedback with technical rigor. The default is to incorporate reviewer feedback, including blockers, non-blockers, observations, comments, questions, and nits. Decline only when a suggestion is technically invalid, conflicts with another reviewer, contradicts project invariants, or requires human/product judgment.

## Contract

Consumes: PR review comments (bot or human), current code context, original intent/plan
Produces: triage table of comments with verdicts, fix commits for accepted items, inline replies for every active reviewer comment
Requires: gh, git, project-test-runner
Side effects: pushes fix commits, replies to review comments
Human gates: disagreements with human reviewers presented for user decision

## Soft Context

Typical workflows: workflow-finalize reviewer-comment gate, watch-ci reviewer-monitoring loop, long-lived PR maintenance
Pairs well with: workflow-finalize, watch-ci, workflow-review, babysit (Cursor built-in)

## When to invoke

- Bot reviews land on a PR (Claude, Codex, Bugbot, etc.)
- Human reviewer submits review with comments
- During `workflow-finalize` or `watch-ci` review-comment handling
- Explicitly: "address the review comments"

## Process

### 1. Gather all comments

```
gh api repos/<owner>/<repo>/pulls/<pr_number>/reviews
gh api repos/<owner>/<repo>/pulls/<pr_number>/comments
```

Filter out resolved threads. For each active comment, extract:
- Author (bot vs human)
- Severity signal (blocking, suggestion, nit, question, praise)
- File and line location
- The suggested change (if any)

### 2. Verify each suggestion before acting

For each non-trivial suggestion, before implementing:

1. **Read the surrounding code** — understand the full context, not just the diff hunk
2. **Check if the suggestion is technically correct** — does it compile? Does it handle edge cases? Does it match the codebase's patterns?
3. **Check if the suggestion is contextually appropriate** — does the reviewer have full context? Is the suggestion based on a misunderstanding of intent?
4. **Check if the suggestion actually improves the code** — is it a genuine improvement or a style preference? Does it align with the project's conventions?

### 3. Classify each comment

| Verdict | Meaning | Action |
|---------|---------|--------|
| **Accept** | Suggestion is correct and improves the code | Implement the fix |
| **Accept (modified)** | Core point is valid but suggestion needs adjustment | Implement a better version, explain the modification |
| **Decline (incorrect)** | Suggestion introduces a bug or breaks behavior | Reply with evidence (test output, spec reference) |
| **Accept (follow-up needed too)** | Suggestion is valid and small enough to include now, but reveals broader work | Implement the local fix and create/link follow-up for broader work |
| **Decline (out of scope)** | Valid improvement but cannot safely fit this PR | Create a follow-up issue, reply with the issue link, and mark as human-gated if the reviewer asked for it now |
| **Decline (convention mismatch)** | Suggestion contradicts project conventions | Reply citing the convention (CONTEXT.md, ADR, linter config) |
| **Clarify** | Comment is ambiguous or based on incomplete context | Reply with the missing context, ask for confirmation |
| **Acknowledge** | Praise or purely informational note | Reply with acknowledgment; no code change needed |

### 4. Implement accepted changes

Group fixes by type:
- **Blockers** — one commit per blocker with `fix(pr-review): <summary>`
- **Non-blockers / observations / comments** — batch into a focused commit if related
- **Questions** — answer inline, and make code/doc changes if the answer exposes ambiguity
- **Nits** — single `style(pr-review): address nits` commit

For each fix commit, reply to the original comment thread with the commit hash.

### 5. Reply to declined/clarified items

For declined suggestions:
- Be specific about WHY, not just that you disagree
- Provide evidence: test output, spec references, convention citations
- Propose an alternative if the underlying concern is valid
- For human reviewers: present the disagreement to the user for final decision before replying
- For AI/bot reviewers: decline only when verified incorrect or harmful; otherwise incorporate the feedback

For clarification requests:
- Provide the missing context concisely
- Ask a specific follow-up question if needed

For acknowledged comments:
- Reply briefly so the thread is not left hanging
- Do not create code churn for praise or informational comments

### 6. Verify, Push, And Reply

After all changes:
1. Run verification locally (tests, lint, build)
2. If verification fails, fix before committing or pushing
3. Commit accepted changes
4. Push fix commits
5. Reply to each fixed comment with the commit hash
6. Confirm every active reviewer comment has one of: fix commit reply, evidence-backed decline reply, clarification reply, acknowledgment reply, or explicit human waiver
7. Summarize: "Accepted N, declined M (with reasons), clarified K, acknowledged A; unanswered 0"

## Incorporation Rule

All actionable reviewer feedback should be incorporated before the PR is handed back:

- **Blockers** must be fixed or human-gated.
- **Non-blockers** should be fixed unless doing so would expand scope materially.
- **Observations/comments** should be treated as improvement suggestions; incorporate the underlying improvement when valid.
- **Questions** must be answered, and any ambiguity they reveal should be fixed in code/docs.
- **Nits** should be fixed in a grouped nit commit.

Do not leave a thread merely "seen." Every thread gets a code change, a doc/test change, a direct answer, or an evidence-backed human-gated reason.

## Anti-patterns

- **Blind agreement** — implementing every suggestion without checking correctness. Reviewers can be wrong.
- **Performative changes** — making a change just to show responsiveness when the original code was correct.
- **Scope creep** — accepting suggestions that expand the PR's scope. These should be follow-up issues.
- **Arguing style** — declining nits that match the project's linter/formatter config. Just fix them.
- **Silent disagreement** — ignoring comments without replying. Always reply, even if declining.
- **Silent acknowledgment** — treating praise or informational comments as resolved without any reply when the workflow requires all comments answered.

## Bot vs human review handling

| Reviewer type | Trust level | Disagreement handling |
|---------------|-------------|----------------------|
| **Linter/formatter bot** | High (deterministic) | Fix unless the rule is wrong (then update config) |
| **AI review bot** (Claude, Codex, Bugbot) | Medium (can hallucinate) | Verify every suggestion against actual code behavior |
| **Human reviewer** | Context-dependent | Present disagreements to user; never auto-decline human feedback |
