---
name: workflow-finalize
layer: orchestrator
model: sonnet
reasoning: medium
description: Universal delivery closure after review passes (PR body → reviewer comments → CI → reconcile → repo-policy-controlled final action)
---

# Workflow Finalize

## Purpose

Close the delivery loop after the review gate passes. Handles PR creation/description, reviewer-comment resolution, CI monitoring, issue reconciliation, the conditional post-mortem gate, and repo-policy-controlled final PR actions, ending in the kernel's finalize stamp. Does not duplicate review or testing logic.

## Precondition — `ledger.sh check review`

The precondition is one kernel call: `ledger.sh check review` must exit 0 — the review gate is stamped, its checks passed (or were loudly overridden), and it is fresh under the kernel's freshness rule (any commit after the stamp except the stamp's own snapshot commit fails `STALE`; contract: `workflow-ledger/SKILL.md`). If it fails, halt and route back to `workflow-review` plus a fresh review stamp. Green CI, passing tests, GitHub reviews, Claude Code Review, Bugbot, Codex review, resolved PR comments, or `receive-review` output are never substitutes — only the stamp is, and the stamp already verified the worktree baseline, profile floor, and lane files, so no prose re-check of those belongs here.

If the change is frontend or user-facing, `user-journey-qa` must also have returned PASS or have an explicit user waiver before finalization proceeds.

When invoked by `run-backlog`, respect `REPO_DELIVERY_POLICY`:

- `human-only`: create/update a draft PR or preserve an existing non-draft PR, but do not mark ready, merge, or enable auto-merge.
- `auto-merge-eligible`: after all required gates pass, mark the PR ready and enable GitHub auto-merge. Prefer GitHub auto-merge over direct immediate merge.
- Human-review-required issues (`needs-human-review`, `Maintainer/operator gate: required`, or another explicit maintainer/operator gate) override `auto-merge-eligible`: leave the PR draft or otherwise blocked for human validation, and do not mark ready, merge, or enable auto-merge until that human validation is recorded.
  - `Reviewer validation: required`, reviewer validation steps, or objective PR-body checks are not human-review blockers by themselves. Treat them as verification work satisfied by the review stamp, required commands, CI, and any repo merge policy.
  - **Stale-label exception (C30, SB-065):** A stale `needs-human-review` label or body line is NOT a merge blocker when the issue/PR evidence shows only reviewer-validation work and no maintainer/operator gate. After merging, reconcile the stale label. Gate-type classification: `workflow-ledger/SKILL.md` (gate types table).
- Missing policy defaults to `human-only`.
- **Before asserting a blanket "a human must merge this" blocker, check `.github/CODEOWNERS` (and branch protection) against the changed paths — read them directly, never infer merge authority from a CLAUDE.md summary sentence or prose recap.** State the specific rule/owner that blocks, or don't claim the block. Absence of any CODEOWNERS/protection rule does not by itself authorize an auto-merge — `REPO_DELIVERY_POLICY` (default `human-only`) still governs.

## PR-state ground truth

The finalize stamp is the authority: at stamp time the kernel resolves the branch's PR itself via forge `pr-for-branch` (an attested `pr_number` must match), and checks CI green, PR open, and review threads resolved. Mid-flow judgment that the stamp cannot do for you:

- **Before pushing a fix to an existing PR branch** (review-fix in Step 2, CI-fix in Step 3, long-lived-PR sync in Step 7), run `gh pr view <n> --json state,mergedAt,headRefOid,mergeStateStatus`. If `state` is `MERGED` or `CLOSED`, do not re-push — a same-SHA re-push fires no `synchronize` event; land a fresh PR onto the base for the remaining changes instead. If review rounds or CI waits took real wall-clock time, re-fetch the base and re-check `mergeStateStatus` before any merge/ready action — unrelated merges may have made this PR `CONFLICTING`.
- **Transient GitHub GraphQL 5xx** on `gh pr create`/`merge` is a server-side blip — the branch push already succeeded. Retry 2–3× with short backoff; if it still fails, hand over the compare URL (`https://github.com/<owner>/<repo>/compare/main...<branch>?expand=1`). Never assume the operation failed without checking (`gh pr list --head <branch>`) — a create can succeed while the response errors.

## Flow

```
[conditional post-mortem gate] → describe-pr → ensure draft PR → enumerate session PRs → receive-review (fan-out, per PR) → watch-ci → reconcile-issues → [docs-freshness hook] → verify-local → ledger.sh stamp finalize → repo-policy final action
```

## Workflow Progress Reporting

Follow the step-ledger reporting protocol in `workflow-ledger/SKILL.md`: the durable record is `ledger.sh set` at every transition (the invoking run's `finalize` step, plus any run-local steps); the table is a render of the ledger (`ledger.sh show`), emitted at run start, on transitions, and in every halt/handoff/completion.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| <step name> | required|conditional|optional | pending|completed|skipped|blocked|failed|not_applicable | <evidence, reason, or -> |
```

### Step 0.5: Conditional Post-mortem Gate

- Required before `describe-pr` for migration-mode PRD work (or legacy design-plan/execute-phase branches), audit-derived refactors, multi-phase execution, significant drift, or `NEW-NN` findings.
- The post-mortem output is consumed by `describe-pr`, so do not generate the PR body first for migration-mode, audit-derived, or multi-phase work.
- Skip only for routine single-issue work with no meaningful drift, and record `not_applicable_with_reason` (it becomes the stamp's `post_mortem` attestation).

### Step 1: Describe PR (describe-pr)

- Load and execute `describe-pr/SKILL.md`. **Do not hand-roll the PR body in `workflow-finalize`.** Hand-written PR bodies, GitHub default bodies, copied issue text, or current-agent summaries are **invalid** for PR finalization.
- `describe-pr` must write a body file under `docs/executions/.pr-bodies/` **before any draft PR is created or updated.** Draft PR creation is **blocked** until this file exists and was produced by `describe-pr` in this run.
- Pass the resolved `branch`, `base`, discovered `pr_number` if one exists, and `apply=false` when no PR exists yet. If a PR already exists, either pass `apply=true` or apply the returned body file in Step 1.5.
- The generated body must include issue awareness and a disposition table for all referenced issues when issues are discovered.
- If any referenced issue requires maintainer/operator review (`needs-human-review` label tied to a maintainer/operator gate, `Maintainer/operator gate: required`, or equivalent explicit gate), the generated body must end with `## Reviewer validation steps` — the final section, with concrete ordered steps copied or condensed from the issue's explicit reviewer validation steps. Do not treat `ready-for-human`, `Type: HITL`, or `Reviewer validation: required` as human-review-required; those mean human implementation, human interaction, or independent review, not PR-blocking maintainer/operator validation.
- Record describe-pr evidence for the stamp's `describe_pr` attestation: body file path, mode (`plan_backed`, `phase_run_backed`, or `issue_only`), issue refs discovered, phase evidence status, graphify usage, whether the body was applied to the PR, and deviation/new-finding counts when applicable.
- If `describe-pr` halts because required phase evidence is missing for plan-backed or multi-phase work, halt finalization. Do not create a draft PR with a replacement body unless the user explicitly waives phase evidence.
- For routine single-issue work with no design plan or phase-run files, `describe-pr` must run in issue-only mode using git log/diff plus issue discovery; absence of a design plan is not a reason to skip `describe-pr`.

### Step 1.5: Ensure Draft PR Exists

- Verify that the `describe-pr` body file from Step 1 exists and was produced by `describe-pr` in this run. If not, halt and rerun `describe-pr` first.
- Run `git fetch origin --prune` before pushing or stating any branch position. Never report commits ahead/behind or diff counts from stale remote-tracking refs.
- Before pushing, check for these known non-deliverable scratch filenames at repo root: `BRIEF.md`, `PROGRESS.md`, `DECISIONS.md`, `HUMAN-DECISIONS.md`, `MASTER-HANDOFF.md`. If any is tracked/staged AND was introduced on this branch (absent from `origin/<base>`), `git rm --cached` + gitignore it before push. Do not remove a matching file that already existed in the base branch. `HANDOFF.md`, `PRD.md`, `ISSUES.md` are skill-defined artifacts, not scratch — leave as-is.
- Push the branch to origin.
- If a PR exists, update the body with the file from `describe-pr`. If no PR exists, create one as draft with `gh pr create --draft --body-file <pr-body-path>`. `auto-merge-eligible` PRs are still created as draft until verification, review-comment resolution, CI, and issue reconciliation pass.
- If an existing PR is not draft, continue but do not mark it ready or enable auto-merge until Step 8.
- Record PR number and URL before proceeding. Do not run `receive-review` until a PR exists.

### Step 2: Resolve PR Reviewer Comments (receive-review) — fan out over every session-opened PR

- **Enumerate session PRs first**: run `gh pr list --author @me --repo <owner/repo>` (scoped to this repo) to find every open PR this session created or updated — not only the one most recently touched. Run the remainder of this step, and Steps 3–6, for each PR found.
- Ground-truth PR state before pushing any fix (see PR-state ground truth above).
- Wait for expected reviewer bots when configured for the repo (Claude, Codex, Bugbot, or repo-specific bots).
- Fetch all review-level and inline comments via GitHub; invoke `receive-review` on every unresolved reviewer comment.
- Address accepted blockers, non-blockers, and nits; reply to declined or clarified comments with evidence.
- Push review-fix commits and re-check review threads. Any code commit after the review stamp makes `ledger.sh check review` fail `STALE` — rerun `workflow-review` on the updated diff and re-stamp (`ledger.sh stamp review`) before continuing.
- If any blocker, unresolved human disagreement, or unanswered reviewer question remains on a given PR: **halt that PR's progression** with auto-handoff, then continue processing the remaining enumerated session PRs independently — one PR's block never gates another PR's merge.
- **Reviewer-response is non-skippable, per PR**: each PR advances to its own Step 8 only once its own review threads are resolved or explicitly human-waived. Finalize is not complete until every PR enumerated at Step 2 has reached that state.

This gate applies to bot and human review comments. A green CI run does not override unresolved review feedback.

### Step 3: Watch CI (watch-ci)

- Monitor GitHub Actions; ground-truth PR state before pushing any auto-fix.
- Auto-fix up to 3 attempts on failure. A CI auto-fix commit stales the review stamp like any other code commit — rerun `workflow-review` and re-stamp before continuing.
- If exhausted: **auto-handoff** (exit_reason: halt, remaining: CI diagnosis needed, include CI logs and what was tried) then halt.
- If green: proceed.

### Step 4: Reconcile Issues (reconcile-issues)

- Check referenced issues against PR dispositions; verify labels are consistent; flag any drift before merge.
- If issue-label drift found: report but don't block (info-level).
- If unresolved reviewer comments remain: block final handoff and route back to Step 2.

### Step 4.5: Docs Freshness Hook (conditional, openwiki)

Applies only to **openwiki-enabled repos**. Detect via any of: an `openwiki/` directory, an `<!-- OPENWIKI:START -->` block in `AGENTS.md`/`CLAUDE.md`, or an existing `.github/workflows/openwiki-update.yml`. If none are present, this step is `not_applicable` — skip and record the reason.

- **Do not run `openwiki --update` inline.** Doc regeneration is LLM-driven; running it here would land generated changes after the review stamp (staling it) and add cost/latency to every ship. Docs regenerate out-of-band via the CI hook after merge.
- **Verify a durable hook exists** (either mechanism counts): a CI hook (`.github/workflows/openwiki-update.yml`) or a local launchd hook (repo path listed in `~/.config/openwiki/repos.conf`; see `~/.config/openwiki/com.alexwelch.openwiki.plist`). Either present → record `present`. Neither → **info-level flag, do not block**: recommend wiring one (copy `workflow-finalize/references/openwiki-update.yml` for GitHub repos, else add the path to `repos.conf`) and record `missing_flagged`. Wiring is one-time setup outside the finalize hot path.
- This step never halts finalization.

### Step 5: Post-CI Retro Addendum (conditional)

- Triggered when CI required auto-fixes, or `watch-ci` discovered new follow-up work after the PR body was generated.
- Append to the existing post-mortem or create a small follow-up note. Do not require `describe-pr` to consume this late addendum.
- Skip only for routine single-issue work with no CI auto-fixes and no new follow-up work.

### Step 6: Verify before handoff

1. **Run `ledger.sh verify-local`** — it executes the repo's CI-parity command set (`docs/executions/ci-commands.yaml`) at HEAD and records a green result the finalize stamp requires. The manifest is the authoritative gate: keep it in sync with what CI actually runs (full test suite, lint and format *checks* over every directory CI covers, drift targets) — file-scoped or single-test proxies passing while CI fails is exactly the failure mode the manifest exists to close. If the repo has no manifest yet, derive the command set from CI workflow definitions/`Makefile`/`package.json` and create it; do not substitute a hand-picked subset.
2. **Confirm review comment resolution** — fetch review threads one final time; the stamp's forge check will refuse unresolved threads, so fix or reply now, not at stamp time. Any actionable reviewer comment with no fix, reply, or explicit human waiver halts before handoff.
3. **Confirm review freshness** — `ledger.sh check review` again after the last code-changing commit; `STALE` → rerun `workflow-review` and re-stamp.
4. **Confirm human-review PR-body footer when required** — when any referenced issue requires maintainer/operator review, inspect the PR body file and confirm its final section is `## Reviewer validation steps` with ordered validation actions. If missing or not last, route back to Step 1 (`describe-pr`).
5. **Check for large diffs** — `git fetch origin --prune` first, then `git diff --stat origin/<base>..HEAD | tail -1`. If **>15 files** or **>500 lines**: logically atomic changes proceed with the size noted in the PR description; unrelated concerns **halt** — split into separate branches from the resolved workflow base and open separate PRs before merging any of them.
6. **Clean-state exit contract (C31, SB-071)** — the stamp checks `git status --porcelain` on the touched worktree; additionally report: primary checkout state (`primary_untouched` or `primary_dirty_status: committed|handed_off|wip_preserved`) and remaining run artifacts (`committed|handed_off|explicitly_preserved` per artifact class). Do not mask drift behind an implicit cleanup assumption — if there is no plan for dirty state, halt and require explicit action (commit, reset, hand-off, or waiver).

### Step 7: Long-lived PR maintenance (conditional)

If the PR has been open >24 hours or has accumulated >5 review comments:

- Triage all unresolved reviewer comments: blocker, non-blocker, nit, or stale.
- Ground-truth PR state before pushing the sync; sync with base if conflicts exist (`git fetch origin && git rebase origin/<base>`, or merge per repo policy); fix any new CI issues introduced by the sync. A sync moves HEAD, so re-review + re-stamp applies **and** `ledger.sh verify-local` must be re-run — the stamp requires its green record at the current HEAD.
- Re-check all review threads after the sync push and reply to any that are now resolved.
- Skipped for fresh PRs that go straight through.

### Step 8: Stamp, then Final PR Action (repo-policy-controlled)

Gate: `ledger.sh stamp finalize --attest post_mortem=<...> describe_pr=<...> pr_number=<n>` — the kernel checks review-gate freshness, clean tree, a green `verify-local` record at HEAD, and (via `forge.sh`) CI green, PR state, and threads resolved; it resolves the PR itself and refuses a mismatched attested `pr_number`. A stamp that won't write means finalization isn't done — fix the reported failure, never hand-edit state.

**Known collision — draft PRs (Phase 3 review F3):** the stamp's forge check currently requires `pr-state = open`; `draft`, `merged`, and `closed` all fail it. Under `human-only` policy the PR intentionally stays draft, so the documented default path cannot stamp as-is. Until the kernel accepts `draft` (follow-up recorded in `_docs/decision-log.md` § D-006 Phase 3), the routes are: create/keep the PR non-draft when the user has approved that for the run (prior non-draft deliveries, e.g. PR #162, took this route), or — on explicit user instruction only — record the audited override (`--override --reason "human-only policy keeps PR draft"`). Do not silently mark a human-only PR ready just to make the stamp pass.

Then act per policy:

- Human-review-required issue: leave the PR draft or otherwise blocked for maintainer/operator validation, regardless of `REPO_DELIVERY_POLICY`. Reviewer-validation-only issues are not in this category once the review stamp, verification, and repo policy pass.
- `human-only` or missing policy: leave the PR in draft mode unless the user explicitly asks to mark it ready. Do not merge or enable auto-merge.
- `auto-merge-eligible`: mark the PR ready and enable GitHub auto-merge with the repo's configured merge method. If branch protection, permissions, required checks, or merge-queue configuration block it, halt with auto-handoff instead of direct-merging.
- Direct immediate merge is allowed only when the repo requires it and the user explicitly requested direct merge for this run.
- Record the action in `WORKFLOW_FINALIZE_GATE.merge_or_ready_action_taken`.

## Completion

When all steps pass:

- Apply Steps 2–8 to every PR enumerated at Step 2 — finalize is not complete while any session-opened PR still has unresolved review threads.
- Leave or advance each PR according to `REPO_DELIVERY_POLICY` and the human-review-required override.
- Report final status to user with **evidence** (verify-local output, CI link, comment-resolution summary, stamp result) and include the `WORKFLOW_FINALIZE_GATE` block in the final response and any handoff artifact.
- When invoked by `run-backlog`, `workflow-autonomous-backlog`, Codex, or any AFK worker, always write a per-issue handoff artifact even when no follow-up work remains: PR URL, gate blocks, verification evidence, review-comment resolution, CI status, issue reconciliation, residual risks.
- Enforce the Partial-Completion Contract before exit: **Complete** (all changes committed and pushed), **WIP-paused** (`wip:` commit naming what remains, pushed), or **Rolled back** (`git reset --hard <baseline>`, clean tree). Run `git status --short` before exit; any `M`/`??` source file fails the contract (and would fail the stamp).
- If follow-up work was discovered (NEW-NN findings, post-mortem action items, reconciliation drift): **auto-handoff** (exit_reason: completion with follow-ups, remaining: the follow-up items with prompt-builder outputs). If no remaining work and this was not an AFK/backlog/Codex run: skip handoff.
- **Close the run**: `ledger.sh close` on clean completion — the kernel owns the state files; never hand-edit `state.yaml`.
- After merge or explicit abandonment, **Load and run `cleanup-delivery/SKILL.md`** to remove stale local worktrees/branches and reconcile ticket residue — do not hand-roll the git cleanup commands. Do not run cleanup before the merge/abandonment decision.

## Gate block — the stamp is the gate, the block is its render

The durable finalize gate is the kernel's stamp record in `state.yaml` (checked: review fresh, tree clean, verify-local green at HEAD, forge CI/PR/threads; attested: post_mortem, describe_pr, pr_number). Every valid run also emits this block in the final response and handoffs as the in-conversation render of that record:

```markdown
WORKFLOW_FINALIZE_GATE:
  ledger_stamp: finalize @ <head_sha> (PASS|OVERRIDDEN: <reason>)
  post_mortem: completed|not_applicable_with_reason
  describe_pr: body_file=<docs/executions/.pr-bodies/...>; mode=plan_backed|phase_run_backed|issue_only; issues=<refs|none>; phase_evidence=matched|not_applicable|waived; graphify=queried|not_available_with_reason|not_applicable; applied_to_pr=true|false
  repo_delivery_policy: human-only|auto-merge-eligible
  pr_number: <number>
  pr_state: draft|existing_non_draft_not_modified|ready_auto_merge_enabled|pending_human_validation
  session_pr_fanout: enumerated=<N>; all_resolved|not_applicable_single_pr
  docs_freshness_hook: present|missing_flagged|not_applicable
  partial_completion: complete_pushed|wip_pushed|rolled_back
  merge_or_ready_action_taken: false|pending_human_validation|marked_ready_and_auto_merge_enabled|direct_merge_user_requested
```

If the stamp is absent or stale (`ledger.sh check finalize` fails), parent workflows must treat `workflow-finalize` as not run — a PR body, green CI, resolved comments, or a draft PR URL alone is not a valid finalization, and a block without a stamp behind it is prose, not a gate.

## Contract

Consumes: stamped review gate (`ledger.sh check review`), committed code on branch, issue references, PR reviewer comments, active ledger run state
Produces: finalize stamp, PR ready for human review/merge or auto-merge according to repo delivery policy, reconciliation report, closed ledger run (`ledger.sh close`)
Requires: gh (or Forgejo token via forge.sh), git, `ledger.sh` (workflow-ledger kernel)
Side effects: creates/updates PR, pushes commits (review/CI fixes), posts comments, commits `chore(ledger):` stamp snapshots, may mark ready and enable GitHub auto-merge when repo policy allows
Human gates: failed `ledger.sh check review`; missing/failed user-journey QA for frontend or user-facing changes unless waived; unresolved reviewer comments; CI exhaustion halts for diagnose; post-mortem presented for review; auto-merge setup failure on auto-merge-eligible repos

## Context

Typical workflows: workflow-deliver (final step), execute-prd (per-child final step), workflow-autonomous-backlog (per-issue repo-policy-controlled PR handoff)
Pairs well with: workflow-review (produces the verdict the review stamp records), workflow-ledger (owns the gates), describe-pr, receive-review, watch-ci, reconcile-issues, cleanup-delivery, post-mortem, handoff (auto-invoked at halt or completion-with-follow-ups), run-backlog
