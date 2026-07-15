---
name: workflow-finalize
model: sonnet
reasoning: medium
description: Universal delivery closure after review passes (PR body → reviewer comments → CI → reconcile → repo-policy-controlled final action)
---

# Workflow Finalize

## Purpose

Close the delivery loop after workflow-review approves. Handles PR creation/description, reviewer-comment resolution, CI monitoring, issue reconciliation, the conditional post-mortem gate, and repo-policy-controlled final PR actions. Does not duplicate review or testing logic.

## When to invoke

- workflow-review returns APPROVE verdict with independent review evidence
- After any successful implementation plus explicit workflow-review cycle
- Explicitly when work is done and needs to ship

## Precondition

workflow-review must have returned APPROVE with independent review evidence. If it hasn't run, lacks review-profile evidence, or returned REQUEST CHANGES / NEEDS HUMAN, halt and direct back to review.

Do not accept substitutes for this precondition. Green CI, passing tests, GitHub reviews, Claude Code Review, Bugbot, Codex review, resolved PR comments, or `receive-review` output are not enough unless the `workflow-review` synthesis exists and says APPROVE.

The precondition is satisfied only by a complete `WORKFLOW_REVIEW_GATE` block from `workflow-review` with `review_profile`, `independent_review: true`, and `verdict: APPROVE`. If the block is absent, incomplete, or self-reported by the author without an independent reviewer context, halt. Do not reconstruct it from prose.

The delivery branch must also have `WORKFLOW_BASE_GATE` plus `WORKTREE_BASELINE_GATE` evidence showing it was cut from the resolved workflow base, or valid `STACKED_WORKTREE_GATE` evidence showing it was cut from a clean parent branch and targets that parent branch. If the work was done in the primary checkout, on a branch based on local `main`/`staging`, or in a stacked child that targets the repository integration branch directly, halt and require a valid worktree.

If the change is frontend or user-facing, `user-journey-qa` must also have returned PASS or have an explicit user waiver before finalization proceeds.

When invoked by `run-backlog`, respect `REPO_DELIVERY_POLICY`:

- `human-only`: create/update a draft PR or preserve an existing non-draft PR, but do not mark ready, merge, or enable auto-merge.
- `auto-merge-eligible`: after all required gates pass, mark the PR ready and enable GitHub auto-merge. Prefer GitHub auto-merge over direct immediate merge.
- Human-review-required issues (`needs-human-review`, `Human review: required`, or equivalent explicit human-review gate) override `auto-merge-eligible`: leave the PR draft or otherwise blocked for human validation, and do not mark ready, merge, or enable auto-merge until that human validation is recorded.
- Missing policy defaults to `human-only`.

## Flow

```
[conditional post-mortem gate] → describe-pr → ensure draft PR → receive-review → watch-ci → reconcile-issues → [docs-freshness hook] → verification gate → repo-policy final action
```

## Workflow Progress Reporting

At the start of every run, display a step ledger before executing or dispatching any step. Use the exact step names from this skill and include conditional or optional steps.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| <step name> | required|conditional|optional | pending|completed|skipped|blocked|failed|not_applicable | <evidence, reason, or -> |
```

Rules:

- Initialize every known step as `pending`; conditional steps remain `pending` until their trigger is evaluated.
- As each step finishes or is skipped, update the ledger with the new status and evidence or reason.
- A step may be `skipped` only when this skill explicitly makes it optional/conditional or a routing decision stops the workflow; record the exact reason.
- Do not mark required gates as skipped. If a required gate cannot run, mark it `blocked` or `failed` and halt according to this workflow.
- At every halt, STOP, handoff, and final completion, include the final ledger in the response or artifact.
- The final ledger must distinguish `completed`, `skipped`, `blocked`, `failed`, and `not_applicable`, and every non-completed status must include a reason.

### Step 0.5: Conditional Post-mortem Gate

- Required before `describe-pr` for design-plan/execute-phase work, audit-derived refactors, multi-phase execution, significant drift, or `NEW-NN` findings.
- The post-mortem output is consumed by `describe-pr`, so do not generate the PR body first for design-plan, audit-derived, or multi-phase work.
- Skip only for routine single-issue work with no meaningful drift, and record `not_applicable_with_reason` in `WORKFLOW_FINALIZE_GATE`.

### Step 1: Describe PR (describe-pr)

- Load and execute `describe-pr/SKILL.md`. Do not hand-roll the PR body in `workflow-finalize`.
- `describe-pr` must write a body file under `docs/executions/.pr-bodies/` before any draft PR is created or updated.
- Pass the resolved `branch`, `base`, discovered `pr_number` if one exists, and `apply=false` when no PR exists yet. If a PR already exists, either pass `apply=true` or apply the returned body file in Step 1.5.
- The generated body must include issue awareness and a disposition table for all referenced issues when issues are discovered.
- If any referenced issue requires a human reviewer (`needs-human-review`
  label, `Human review: required`, or equivalent explicit human-review gate),
  the generated body must end with `## Reviewer validation steps`. The section
  must be the final section in the PR body and contain concrete ordered steps
  copied or condensed from the issue's explicit reviewer validation steps. Do
  not treat `ready-for-human` or `Type: HITL` as human-review-required; those
  mean human implementation or human interaction, not PR validation.
- Record describe-pr evidence for the final gate: body file path, mode (`plan_backed`, `phase_run_backed`, or `issue_only`), issue refs discovered, phase evidence status, and deviation/new-finding counts when applicable.
- If `describe-pr` halts because required phase evidence is missing for plan-backed or multi-phase work, halt finalization. Do not create a draft PR with a replacement body unless the user explicitly waives phase evidence.
- For routine single-issue work with no design plan or phase-run files, `describe-pr` must run in issue-only mode using git log/diff plus issue discovery; absence of a design plan is not a reason to skip `describe-pr`.

### Step 1.5: Ensure Draft PR Exists

- Run `git fetch origin --prune` before pushing or stating any branch position. Never report commits ahead/behind, "this PR includes N commits", or a large-diff count from local remote-tracking refs without a fresh fetch first — stale refs after a batch of merges produce false ahead/behind counts.
- Push the branch to origin.
- If a PR exists, update the body with the file from `describe-pr`.
- If no PR exists, create one as draft with `gh pr create --draft --body-file <pr-body-path>`. `auto-merge-eligible` PRs are still created as draft until verification, review-comment resolution, CI, and issue reconciliation pass.
- If an existing PR is not draft, continue but do not mark it ready or enable auto-merge until Step 8.
- Record PR number and URL before proceeding. Do not run `receive-review` until a PR exists.

### Step 2: Resolve PR Reviewer Comments (receive-review)

- Wait for expected reviewer bots when configured for the repo (Claude, Codex, Bugbot, or repo-specific bots)
- Fetch all review-level and inline comments via GitHub
- Invoke `receive-review` on every unresolved reviewer comment
- Address accepted blockers, non-blockers, and nits; reply to declined or clarified comments with evidence
- Push review-fix commits and re-check review threads
- If any code changes were pushed after the incoming `WORKFLOW_REVIEW_GATE`, rerun `workflow-review` on the updated diff and require a new `WORKFLOW_REVIEW_GATE` with `review_profile`, `independent_review: true`, and `verdict: APPROVE` before continuing
- If any blocker, unresolved human disagreement, or unanswered reviewer question remains: **halt** with auto-handoff

This gate applies to bot and human review comments. A green CI run does not override unresolved review feedback.

### Step 3: Watch CI (watch-ci)

- Monitor GitHub Actions
- Auto-fix up to 3 attempts on failure
- If any CI auto-fix changes code after the latest `WORKFLOW_REVIEW_GATE`, rerun `workflow-review` on the updated diff and require a new `WORKFLOW_REVIEW_GATE` with `review_profile`, `independent_review: true`, and `verdict: APPROVE` before continuing
- If exhausted: **auto-handoff** (exit_reason: halt, remaining: CI diagnosis needed, include CI logs and what was tried) then halt
- If green: proceed

### Step 4: Reconcile Issues (reconcile-issues)

- Check referenced issues against PR dispositions
- Check for unresolved or unanswered PR reviewer comments before merge
- Verify labels are consistent
- Flag any drift before merge
- If issue-label drift found: report but don't block (info-level)
- If unresolved reviewer comments remain: block final handoff and route back to Step 2

### Step 4.5: Docs Freshness Hook (conditional, openwiki)

Applies only to **openwiki-enabled repos**. Detect via any of: an `openwiki/` directory, an `<!-- OPENWIKI:START -->` block in `AGENTS.md`/`CLAUDE.md`, or an existing `.github/workflows/openwiki-update.yml`. If none are present, this step is `not_applicable` — skip and record the reason.

- **Do not run `openwiki --update` inline.** Doc regeneration is LLM-driven; running it here would land generated changes after the `WORKFLOW_REVIEW_GATE` (tripping review-freshness, Step 6.4) and add cost/latency to every ship. Docs regenerate out-of-band via the CI hook after merge, so they stay current even when humans push.
- **Verify a durable hook exists** (either mechanism counts):
  - **CI hook** — `.github/workflows/openwiki-update.yml` present (GitHub-hosted repos), or
  - **Local launchd hook** — the repo path is listed in `~/.config/openwiki/repos.conf` (host-agnostic; for repos not on GitHub). See `~/.config/openwiki/com.alexwelch.openwiki.plist`.
  - Either present → record `present`.
  - Neither → **info-level flag, do not block.** Recommend wiring one: for GitHub repos copy `workflow-finalize/references/openwiki-update.yml` to `.github/workflows/` (set the provider API-key secret); otherwise add the repo path to `~/.config/openwiki/repos.conf`. Record `missing_flagged`. Wiring is one-time setup outside the finalize hot path, so it never mutates the reviewed diff.
- This step never halts finalization.

### Step 5: Post-CI Retro Addendum (conditional)

- Triggered when:
  - CI required auto-fixes (something unexpected happened)
  - `watch-ci` discovered new follow-up work after the PR body was generated
- Append to the existing post-mortem or create a small follow-up note. Do not require `describe-pr` to consume this late addendum.
- Skip only for routine single-issue work with no CI auto-fixes and no new follow-up work.

### Step 6: Verify before handoff

Before declaring the PR ready for final action, run a verification gate:

1. **Run repo verification commands** — execute the project's test/build/lint suite one final time against the PR branch. Check `package.json` scripts, `Makefile` targets, or CI workflow definitions for the canonical commands.
2. **Confirm verification passes** — do not claim "tests pass" without running them. If any command fails, halt and fix before proceeding.
3. **Confirm review comment resolution** — fetch review threads/comments one final time. If any actionable reviewer comment has no fix, reply, or explicit human waiver, halt before handoff.
4. **Confirm review freshness** — verify the latest `WORKFLOW_REVIEW_GATE` was produced after the final code-changing commit. If finalization pushed review-fix or CI-fix commits after the last review gate, halt and rerun `workflow-review`.
5. **Confirm human-review PR-body footer when required** — when any referenced
   issue requires a human reviewer (`needs-human-review`, `Human review:
   required`, or equivalent explicit human-review gate), inspect the PR body
   file and confirm its final section is `## Reviewer validation steps` with
   ordered validation actions copied or condensed from the issue's explicit
   reviewer validation steps. If missing or not last, route back to Step 1
   (`describe-pr`) before creating/updating or handing off the PR. Do not use
   `ready-for-human` or generic `Type: HITL` as this trigger.
6. **Check for large diffs** — run `git fetch origin --prune` first (a stale `origin/<base>` inflates or hides the count), then `git diff --stat origin/<base>..HEAD | tail -1` and parse the file count. If **>15 files changed** or **>500 lines changed**, flag for potential PR splitting:
   - If the changes are logically atomic (single feature, single refactor), proceed but note the size in the PR description
   - If the changes span unrelated concerns, **halt**: identify the independent concerns, resolve `WORKFLOW_BASE_GATE`, create a separate branch for each from the resolved workflow base, cherry-pick or re-implement the relevant commits onto each branch, and open separate PRs before merging any of them

### Step 7: Long-lived PR maintenance (conditional)

If the PR has been open >24 hours or has accumulated >5 review comments:

- Triage all unresolved reviewer comments: categorize as blocker, non-blocker, nit, or stale (no longer applies after recent changes)
- Sync with base branch if conflicts exist: `git fetch origin && git rebase origin/<base>` (or merge if the repo policy prefers merge)
- Fix any new CI issues introduced by the sync
- Re-check all review threads after the sync push and reply to any that are now resolved
- This step is skipped for fresh PRs that go straight through

### Step 8: Final PR Action (repo-policy-controlled)

After all previous gates pass:

- Human-review-required issue: leave the PR draft or otherwise blocked for human validation. Do not mark ready, merge, or enable auto-merge until the human validation is recorded, regardless of `REPO_DELIVERY_POLICY`.
- `human-only` or missing policy: leave the PR in draft mode unless the user explicitly asks to mark it ready for review. Do not merge or enable auto-merge.
- `auto-merge-eligible`: mark the PR ready and enable GitHub auto-merge. Use the repo's configured merge method. If auto-merge cannot be enabled because branch protection, permissions, required checks, or merge queue configuration block it, halt with auto-handoff instead of direct-merging.
- Direct immediate merge is allowed only when the repo requires it and the user explicitly requested direct merge for this run.
- Record the action in `WORKFLOW_FINALIZE_GATE.merge_or_ready_action_taken`.

## Completion

When all steps pass:

- Leave or advance the PR according to `REPO_DELIVERY_POLICY` and the human-review-required override
- Report final status to user with **evidence** (test output, CI link, verification command results, comment-resolution summary)
- Include the required `WORKFLOW_FINALIZE_GATE` block in the final response and any handoff artifact
- When invoked by `run-backlog`, `workflow-autonomous-backlog`, Codex, or any AFK worker, always write a per-issue handoff artifact even when no follow-up work remains. Include PR URL, all gate blocks, verification evidence, review-comment resolution, CI status, issue reconciliation, and residual risks.
- Enforce the Partial-Completion Contract before exit:
  - Complete: all changes committed and pushed to the remote branch.
  - WIP-paused: current progress committed with a `wip:` prefix in the subject line, naming exactly what remains, then pushed.
  - Rolled back: `git reset --hard <baseline>` leaves the worktree clean.
- Run `git status --short` before exit. If any source file shows `M` or `??`, the contract is not satisfied; commit or reset and re-check before reporting completion or handoff.
- If follow-up work was discovered (NEW-NN findings, post-mortem action items, reconciliation drift): **auto-handoff** (exit_reason: completion with follow-ups, remaining: the follow-up items with prompt-builder outputs)
- If no remaining work and this was not an AFK/backlog/Codex run: skip handoff
- **Close the run cockpit.** If `docs/executions/state.yaml` exists for this run, set `status: done` and `next: ""` on clean completion (leave the file as a record; the next confirmed route overwrites it). Schema: `../_docs/state-cockpit.md`.
- After merge or explicit abandonment, use `cleanup-delivery` to remove stale local worktrees/branches and reconcile ticket residue. Do not run cleanup before the merge/abandonment decision.

## Required Gate Block

Every valid `workflow-finalize` run must emit this block verbatim:

```markdown
WORKFLOW_FINALIZE_GATE:
  workflow_base: origin/staging|origin/<default-branch>
  worktree_baseline: <workflow-base-ref> -> <branch> @ <worktree-path> OR stacked: <workflow-base-ref> -> <parent-branch> -> <child-branch> @ <child-worktree-path>
  workflow_review_gate: APPROVE
  post_mortem: completed|not_applicable_with_reason
  describe_pr: body_file=<docs/executions/.pr-bodies/...>; mode=plan_backed|phase_run_backed|issue_only; issues=<refs|none>; phase_evidence=matched|not_applicable|waived
  repo_delivery_policy: human-only|auto-merge-eligible
  pr_state: draft|existing_non_draft_not_modified|ready_auto_merge_enabled|pending_human_validation
  pr_number: <number>
  review_comments: all_resolved|human_waived
  ci: green
  issue_reconciliation: complete
  docs_freshness_hook: present|missing_flagged|not_applicable
  verification: passed
  partial_completion: complete_pushed|wip_pushed|rolled_back
  final_git_status_short: clean
  merge_or_ready_action_taken: false|pending_human_validation|marked_ready_and_auto_merge_enabled|direct_merge_user_requested
```

If this block is absent or incomplete, parent workflows must treat `workflow-finalize` as not run. `required_but_missing` is a halt state, never a completion value. A PR body, green CI, resolved comments, or a draft PR URL alone is not a valid finalization.

`workflow_review_gate: APPROVE` must refer to the latest review gate after all code-changing review fixes and CI fixes. If the branch changed after that gate, the finalization gate is invalid.

## Contract

Consumes: approved review verdict, committed code on branch, issue references, PR reviewer comments, `docs/executions/state.yaml` (active run, when present)
Produces: PR ready for human review/merge or auto-merge according to repo delivery policy, reconciliation report, closed run cockpit (`status: done` in `docs/executions/state.yaml`)
Requires: gh, git
Side effects: creates/updates PR, pushes commits (review/CI fixes), posts comments, may mark ready and enable GitHub auto-merge when repo policy allows
Human gates: missing workflow-review independent review evidence; missing/failed user-journey QA for frontend or user-facing changes unless waived; unresolved reviewer comments; CI exhaustion halts for diagnose; post-mortem presented for review; auto-merge setup failure on auto-merge-eligible repos

## Context

Typical workflows: workflow-build-one (final step), workflow-debug (final step), workflow-autonomous-backlog (per-issue repo-policy-controlled PR handoff)
Pairs well with: workflow-review (precondition), describe-pr, receive-review, watch-ci, reconcile-issues, cleanup-delivery, post-mortem, handoff (auto-invoked at halt or completion-with-follow-ups), run-backlog
