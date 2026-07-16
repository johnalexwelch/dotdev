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

## Context

Typical workflows: post-implement review, workflow-finalize gate
Pairs well with: implement, tdd, workflow-finalize, workflow-review, receive-review

## References — load only what the request needs

- `references/workflow.md` — the full review pipeline (fetch → analyze → format → optional post). Load for non-trivial reviews.
- `references/comment-format.md` — exact GitHub markdown rules for nested code fences, file/line anchors, and review-thread vs. line-comment structure.
- `references/naming-conventions.md` — **locked-in standard** for column and table naming in dbt projects. Load for any PR that touches dbt SQL, schema yml, or introduces new columns/tables. Anchor naming feedback to specific rows in this doc.
- `references/posting.md` — how to post the comments as a pending review via `gh api`. Load only if the user wants to post, not just draft.

## How to work

1. **Clarify the link role.** If the user gives one URL with ambiguous framing ("review this PR, here is an example"), ask which is the review target and which is the standard. Do not infer.
2. **Fetch the PR.** Use `gh pr view <N> --json` and `gh pr diff <N>` for metadata and content. Note `headRefName` and `baseRefName`. If the review will run any file-scoped tool (linter, `dbt parse`, formatter), `gh pr checkout <N>` first so those tools see real content — an empty result on a not-checked-out ADDED file is a false pass, not "clean."
3. **Detect PR type and load standards.** Look at the changed files and load the matching standard:
   - dbt models / snapshots / yml → `dbt` skill (especially `references/snapshots.md` if snapshots are touched) **plus this skill's `references/naming-conventions.md`** and the `sql-standards` skill
   - Python DAGs → `airflow` skill
   - SQL formatting / lint findings → `sql-standards` skill (if available)
   - Multiple types → load each
   - **No matching standard found?** Apply the smell baseline below as the fallback. Skip any smell that tooling already enforces.
4. **Identify the spec source.** Look for the originating issue/PRD that this PR implements:
   1. Issue references in commit messages (`#123`, `Closes #45`)
   2. PR description body
   3. PRD/spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name
   4. If nothing found, note "no spec" and skip the Spec axis in the final summary.
5. **Compare against standards (Standards axis).** For each changed file, identify violations or gaps and capture the failure mode each one prevents. When no project-specific standard applies to a hunk, apply the smell baseline:
   - **Mysterious Name** — function/variable/type name that doesn't reveal what it does. → Rename; if no honest name comes, the design is murky.
   - **Duplicated Code** — same logic shape appears in more than one hunk or file. → Extract the shared shape.
   - **Feature Envy** — method reaches into another object's data more than its own. → Move the method onto the data it envies.
   - **Data Clumps** — same few fields/params keep travelling together. → Bundle into one type.
   - **Primitive Obsession** — primitive standing in for a domain concept. → Give it its own small type.
   - **Repeated Switches** — same switch/if-cascade on the same type recurs. → Replace with polymorphism or a shared map.
   - **Shotgun Surgery** — one logical change forces scattered edits across many files. → Gather what changes together.
   - **Divergent Change** — one module edited for several unrelated reasons. → Split so each module changes for one reason.
   - **Speculative Generality** — abstraction added for needs the spec doesn't have. → Delete; inline until a real need shows.
   - **Message Chains** — long `a.b().c().d()` navigation. → Hide the walk behind one method on the first object.
   - **Middle Man** — class/function that mostly just delegates. → Cut it; call the real target direct.
   - **Refused Bequest** — subclass that ignores or overrides most of what it inherits. → Drop the inheritance; use composition.
   Smell findings are always **judgement calls**, never hard violations. A documented repo standard overrides the baseline.
6. **Compare against spec (Spec axis).** If a spec was found in step 4:
   - Which acceptance criteria or requirements are **missing or only partially implemented**?
   - Which behavior in the diff **wasn't asked for** (scope creep)?
   - Which requirements look implemented but where the **implementation looks wrong**? Quote the spec line for each finding.
7. **Produce per-file comment blocks.** Use the format in `comment-format.md`. Each block has:
   - File path and approximate line range
   - Short heading describing the issue
   - Reasoning that leads with the failure mode, not the rule citation
   - A code example showing the fix
   - One supporting link (docs or an exemplar PR), not a wall of references
8. **Write the top-level PR summary** with two sections, `## Standards` and `## Spec` (omit Spec if no spec was found). Each section ends with total findings and the worst issue. Do not merge or rerank findings across axes — a change can pass one and fail the other.
9. **Build the JSON review payload** at `/tmp/pr-<N>-review.json`. Each finding becomes either a suggestion block (single-line mechanical rename) or a regular comment (multi-site or judgment call). See `posting.md` for the JSON schema and suggestion-block format, and `comment-format.md` for the suggestion fence rules. As a fallback when the user prefers manual pasting, also write `/tmp/pr-<N>-review-comments.md` in the old markdown-paste format.
10. **Run the tells check on the payload bodies**, then offer to post. See `posting.md` — the check and the `gh api` call are both documented there. Do not post without explicit confirmation.

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
