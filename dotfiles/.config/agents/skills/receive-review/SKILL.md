---
name: receive-review
model: sonnet
reasoning: high
description: "Process PR review feedback end-to-end: evaluate each comment for correctness (no blind agreement), then action it — fix code, reply, push back with reasoning, or defer to a follow-up — and post replies for every thread. Use when bot or human review comments land on a PR, during workflow-finalize's review gate, or 'address/respond to the review comments'."
codex-compatible: true
---

# Receive Review

Evaluate code-review feedback with technical rigor, then process the whole comment queue to resolution. The default is to incorporate feedback (blockers, non-blockers, observations, questions, nits); decline only when a suggestion is technically invalid, conflicts with another reviewer, contradicts project invariants, or needs human/product judgment. (Composes with `workflow-finalize`, which gates the merge, and `workflow-review`, which produced the comments.)

## Contract

Consumes: PR number/URL, review comments (bot or human), code context, original intent
Produces: a triage table with verdicts, grouped fix commits, inline replies for every active thread, and a summary
Requires: `gh`, `git`, local test/lint runner
Side effects: pushes fix commits, posts replies, may file follow-up issues
Human gates: surface the summary before pushing; disagreements with **human** reviewers go to the user for decision before replying; push-back replies are higher-stakes — confirm first

## When to invoke

Bot reviews land (Claude, Codex, Bugbot, Copilot); a human submits a review; the `workflow-finalize` / `watch-ci` comment gate; or "address/respond to the review comments on PR #X."

## Process

1. **Gather all open comments.** `gh pr view <n> --json reviews,comments` or `gh api repos/<o>/<r>/pulls/<n>/comments`. Filter resolved/outdated. Per comment capture: id, author (bot vs human), severity signal (blocker/suggestion/nit/question/praise), file+line, suggested change.
   - If `gh` returns **"Could not resolve to a Repository"** (or 404 on a repo you know exists), run `gh auth status` first — the usual cause is an auth-account flip (the active `gh` account lacks access to that org/repo), not a wrong slug. Also pass `--repo <owner/slug>` explicitly when cwd may be a different repo's worktree. Fix auth before assuming the PR/number is wrong.
2. **Verify before acting** (the anti-blind-agreement core). For each non-trivial suggestion: read the *surrounding* code (not just the hunk); is it technically correct (compiles, edge cases, matches patterns)?; is it contextually appropriate (does the reviewer have full intent)?; does it actually improve the code vs. style preference?
3. **Classify each comment** with a verdict + action:

   | Verdict | Action |
   |---|---|
   | Accept | implement the fix |
   | Accept (modified) | implement a better version, explain the change |
   | Decline (incorrect) | reply with evidence (test output, spec) |
   | Accept + follow-up | fix locally now, link a follow-up for the broader work |
   | Decline (out of scope) | file a follow-up issue, reply with the link, human-gate if reviewer wanted it now |
   | Decline (convention) | reply citing CONTEXT.md / ADR / linter config |
   | Clarify | reply with missing context, ask a specific question |
   | Acknowledge | brief reply; no code change |

4. **Action the queue.** Implement accepted changes grouped into logical commits (one per blocker `fix(pr-review): …`; batch related non-blockers; single `style(pr-review): nits` commit). Order edits to avoid conflicts; update tests/docs where a fix requires it. Draft push-back replies with: acknowledge the concern → state the reason → offer a falsifier ("would change my mind if…") → or propose a follow-up if the disagreement is real but out-of-scope.
5. **Verify, push, reply.** Run tests/lint locally (fix before pushing); commit; push; reply to each thread with the commit hash (fixes), evidence (declines), context (clarifications), or acknowledgment. Confirm **every** active thread has a reply — none left merely "seen."
6. **Summary:**

```markdown
## PR Response Summary — #<num> (<N> comments)
### Actioned (<k>)   - [file:line] <summary> — fixed in <commit>
### Reply-only (<k>) - [file:line] <summary> — "<short>"
### Pushed back (<k>)- [file:line] <summary> — "<short>"
### Deferred (<k>)   - [file:line] <summary> — issue #<x>
### Tests/lint: pass | fail (notes)
Accepted N, declined M (with reasons), clarified K, acknowledged A; unanswered 0.
```

## Bot vs human handling

| Reviewer | Trust | Disagreement |
|---|---|---|
| Linter/formatter bot | high (deterministic) | fix unless the rule is wrong (then update config) |
| AI review bot | medium (can hallucinate) | verify every suggestion against actual behavior |
| Human | context-dependent | present disagreements to the user; never auto-decline |

## Anti-patterns

Blind agreement (reviewers can be wrong); performative changes (changing correct code to show responsiveness); scope creep (route broader work to follow-ups); arguing style nits that match the linter (just fix them); silent disagreement or silent acknowledgment (always reply).

## Graph context (graph-first)

Optionally query the graph for: files/modules the PR touches (owners, deps, bug history), the reviewers' typical nit-vs-blocker patterns, constraining ADRs, and prior similar PRs (what was actioned vs deferred). Use at step 2–3 to sharpen action-vs-push-back; tag `[GRAPH-PRIOR]`. `--no-graph` skips.
