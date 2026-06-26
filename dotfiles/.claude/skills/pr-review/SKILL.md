---
name: pr-review
model: sonnet
reasoning: high
description: Review a GitHub pull request against project standards. Fetches the PR diff, compares it to a reference standard skill or exemplar PR, produces per-file review comments with file/line anchors, and outputs GitHub-ready markdown. Use when the user asks to "review this PR", "look at PR #N", or paste a GitHub PR link.
---

# pr-review

Structured review of a GitHub pull request against a chosen standard or exemplar. Produces GitHub-ready review comments with file/line anchors, not free-form prose.

## Contract

Consumes: a PR number or URL, optionally a reference standard (skill name or exemplar PR)
Produces: `/tmp/pr-<N>-review-comments.md` containing per-file comment blocks, file anchors, and a top-level PR summary
Requires: `gh` CLI authenticated to the target repo
Side effects: writes the comments file; does not post to GitHub unless the user explicitly asks
Human gates: if the link role is ambiguous (target vs. reference), clarify before any work

## References — load only what the request needs

- `references/workflow.md` — the full review pipeline (fetch → analyze → format → optional post). Load for non-trivial reviews.
- `references/comment-format.md` — exact GitHub markdown rules for nested code fences, file/line anchors, and review-thread vs. line-comment structure.
- `references/naming-conventions.md` — **locked-in standard** for column and table naming in dbt projects. Load for any PR that touches dbt SQL, schema yml, or introduces new columns/tables. Anchor naming feedback to specific rows in this doc.
- `references/posting.md` — how to post the comments as a pending review via `gh api`. Load only if the user wants to post, not just draft.

## How to work

1. **Clarify the link role.** If the user gives one URL with ambiguous framing ("review this PR, here is an example"), ask which is the review target and which is the standard. Do not infer.
2. **Fetch the PR.** Use `gh pr view <N> --json` and `gh pr diff <N>` for metadata and content. Note `headRefName` and `baseRefName`.
3. **Detect PR type.** Look at the changed files and load the matching standard:
   - dbt models / snapshots / yml → `dbt` skill (especially `references/snapshots.md` if snapshots are touched) **plus this skill's `references/naming-conventions.md`** and the `sql-standards` skill
   - Python DAGs → `airflow` skill
   - SQL formatting / lint findings → `sql-standards` skill (if available)
   - Multiple types → load each
4. **Compare against the standard.** For each changed file, identify violations or gaps and capture the failure mode each one prevents.
5. **Produce per-file comment blocks.** Use the format in `comment-format.md`. Each block has:
   - File path and approximate line range
   - Short heading describing the issue
   - Reasoning that leads with the failure mode, not the rule citation
   - A code example showing the fix
   - One supporting link (docs or an exemplar PR), not a wall of references
6. **Write the top-level PR summary** that groups the asks by severity (blocking vs. style sweep vs. follow-up).
7. **Build the JSON review payload** at `/tmp/pr-<N>-review.json`. Each finding becomes either a suggestion block (single-line mechanical rename) or a regular comment (multi-site or judgment call). See `posting.md` for the JSON schema and suggestion-block format, and `comment-format.md` for the suggestion fence rules. As a fallback when the user prefers manual pasting, also write `/tmp/pr-<N>-review-comments.md` in the old markdown-paste format.
8. **Run the tells check on the payload bodies**, then offer to post. See `posting.md` — the check and the `gh api` call are both documented there. Do not post without explicit confirmation.

## Voice

PR review comments are not blog posts. Full guidance in the humanizer skill's `references/code-review-voice.md` and this skill's `references/comment-format.md`. Core rules:

- **First person plural.** Write "we" for the team and "this" for the code. Not "the author", "the reviewer", "the next person", "downstream consumers", "anyone editing this".
- **No hedging.** State the recommendation. "Add a guardrail." Not "It might be worth adding a guardrail." Banned phrasings: "worth confirming", "worth a look", "worth adding", "worth pulling into", "OK to defer", "could be", "might want to", "probably fine", "it seems like". Direct equivalents are in `references/comment-format.md`.
- **Lead with the failure mode**, not the rule that cites it.
- **One supporting link** per comment, not a `References:` footer.
- **No em dashes**, no bolded inline list headers, no rule-of-three padding.
- **Code blocks** for the recommended pattern, not for the prose.

Acceptable status statements (these are factual, not hedges): "Not blocking." / "OK to merge as-is." / "Confirmed by the test plan."

The tells check runs on the JSON payload bodies before posting (see `posting.md`). Zero em dashes, chatbot artifacts, bolded list headers, hedges.

## When NOT to use this skill

- Posting an approval or "LGTM" — that is a single `gh pr review --approve` call, no skill needed
- Triaging a list of existing review comments — use `triage_comments` instead
- Inline coaching during a live conversation — just answer directly
