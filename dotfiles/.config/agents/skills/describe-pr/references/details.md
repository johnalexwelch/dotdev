# describe-pr — error handling, issue discovery, examples, tuning

Load when you hit an edge case, need the issue-discovery source list, or want a worked example.

## Error Handling

| Failure | Behavior |
|---------|----------|
| Not in a git repo | Abort. |
| `gh` CLI not installed and `pr_number == 0` | Proceed in text-only mode; no PR actions attempted. |
| No plan at `plan_path` / no newest plan | For routine single-issue work, continue in `issue_only` mode. For plan-backed, multi-phase, or `/execute-phase` work, halt and tell the user to pass `plan_path` or explicitly waive plan/phase evidence. |
| No `.phase-runs/` files matching the branch range | Degrade gracefully — produce the body from raw `git log` only, note in "Deviations" that phase-run outcome files were unavailable so drift detection is weaker. |
| Deviation subagent returns empty | Retry once with a tighter prompt; if still empty, surface in the body that deviation analysis was unavailable. |
| `gh pr edit` fails at apply step | Keep the body file; surface the `gh` error; tell the user to apply manually with `gh pr edit <N> --body-file <path>`. |
| `git hash-object` unavailable (unlikely) | Omit per-file diff permalinks; use the compare-view URL for the whole PR. |
| `git remote get-url origin` not GitHub | Omit diff permalinks; link the outcome files instead. Note in body that repo is not on GitHub. |
| Bot reviews don't arrive within 10 minutes | Record the timeout in the body/handoff and let `workflow-finalize` decide whether to halt, wait, or require an explicit waiver. |
| Bot review comment is ambiguous or conflicting | Out of scope for this skill. Route to `receive-review` through `workflow-finalize`. |
| `gh` CLI not installed and `workflow-finalize` invoked this skill | Halt. Draft PR creation and issue verification require `gh`; text-only mode is allowed only for standalone `describe-pr` usage outside delivery finalization. |
| No `.phase-runs/` files for plan-backed, multi-phase, or `/execute-phase` work | Halt unless the user explicitly waives phase evidence. Raw `git log` fallback is allowed only for routine non-`execute-phase` branches, which must be marked `issue_only`. |
| `graphify-out/graph.json` missing | Continue and record `graphify: not_available_with_reason`; do not rebuild automatically. |
| `graphify query` fails despite graph existing | Continue only if git/issue/plan evidence is sufficient; record `graphify: not_available_with_reason` with the command failure. |
| Caller supplies an existing hand-written PR body | Ignore it as source material unless it is explicitly cited as prior context; generate a fresh body file and evidence line from this skill's inputs. |

## Example Invocation

Describe the PR for the current branch (has an open PR on GitHub):

```
User: /describe-pr
Claude: [preflight — branch refactor/phase-2-skill-scaffolding,
         PR #142 detected, plan docs/plans/2026-04-20-design.md]
        [reads 3 .phase-runs/ files matching branch range]
        [dispatches deviation-review subagent]
        [writes docs/executions/.pr-bodies/2026-04-21-pr-142.md]

        PR body for branch refactor/phase-2-skill-scaffolding
        generated — 3 phases documented, 1 deviation flagged,
        2 new findings.
        PR: https://github.com/org/repo/pull/142
        Body: docs/executions/.pr-bodies/2026-04-21-pr-142.md
        describe_pr: body_file=docs/executions/.pr-bodies/2026-04-21-pr-142.md; mode=phase_run_backed; issues=#123,#124; phase_evidence=matched; graphify=queried; applied_to_pr=false
        (pass apply=true to push to GitHub)
```

Solo-to-main, no PR yet:

```
User: /describe-pr branch=refactor/phase-0-preflight
Claude: [no PR for branch; text-only mode]
        [writes docs/executions/.pr-bodies/2026-04-21-pr-refactor-phase-0-preflight.md]

        PR body generated (no PR exists yet). Phases: 1,
        deviations: 0, new findings: 0.
        Body: docs/executions/.pr-bodies/2026-04-21-pr-refactor-phase-0-preflight.md
        describe_pr: body_file=docs/executions/.pr-bodies/2026-04-21-pr-refactor-phase-0-preflight.md; mode=plan_backed; issues=none; phase_evidence=not_applicable; graphify=not_available_with_reason; applied_to_pr=false
```

Routine single-issue branch, no design plan:

```
User: /describe-pr branch=fix/123-settings-crash
Claude: [no plan or phase-run evidence expected]
        [issue_only mode]
        [runs git log/diff and issue discovery]
        [writes docs/executions/.pr-bodies/2026-04-21-pr-fix-123-settings-crash.md]

        PR body generated — issue-only mode, 1 issue discovered,
        phase/deviation sections marked not applicable.
        Body: docs/executions/.pr-bodies/2026-04-21-pr-fix-123-settings-crash.md
        describe_pr: body_file=docs/executions/.pr-bodies/2026-04-21-pr-fix-123-settings-crash.md; mode=issue_only; issues=#123; phase_evidence=not_applicable; graphify=queried; applied_to_pr=false
```

## Issue Discovery

Discover related issues from these sources (checked in order during Step 1):

1. **Branch name** — parse issue numbers from the branch name (e.g., `feat/123-add-auth` → `#123`, `fix/gh-45-crash` → `#45`). Regex: `(?:^|/)(?:gh-)?(\d+)[-_]` against the branch.
2. **Commit messages** — scan `git log --oneline <base>..<branch>` for `#N` references. Collect unique issue numbers.
3. **Design plan refs** — if executing a design plan, extract issue references (`#N`, ticket slugs) from plan §3 Goals, §5 phase Addresses entries, and §9 Open questions.
4. **to-issues output** — if issues were created by `/to-issues`, the plan or issue bodies reference the parent PRD. Follow the link to collect the PRD issue number and all child issue numbers.
5. **execute-phase outcomes** — read `.phase-runs/` outcome files for issue references in `## Commits`, `## Follow-ups`, and `## Scope violations` sections.
6. **Post-mortems** — extract issue numbers from `docs/executions/<date>-post-mortem.md`, particularly from `## New findings` and `## Issues created` sections.
7. **Explicit input** — user or calling workflow provides issue numbers directly (via prompt text or future `issues` input parameter).

Deduplicate across all sources. For each discovered issue, fetch its title and status via `gh issue view <N> --json title,state,labels -q '{title,state,labels}'`. If lookup fails, record the failure, do not use `Closes`, `Fixes`, or `Resolves` for that issue, and mark the disposition as `Refs` or `Needs human verification`.

## Human-Reviewer Validation Steps

When any discovered issue requires human review, the PR body must end with
`## Reviewer validation steps`.

Detection:

- Issue has the `ready-for-human` label.
- Issue body declares `Type: HITL`.
- Issue body contains an equivalent explicit human review gate.

Composition rules:

- Place the section after `## References`; it must be the final PR-body
  section.
- Derive steps from the issue's acceptance criteria and required verification.
- Write steps as an ordered list, phrased as reviewer actions.
- Prefer three concise steps when the issue naturally has three reviewer
  actions, but do not invent filler steps.
- Include concrete artifact paths, commands, or evidence links when available.
- Preserve safety scope: if the issue says the work does not authorize runtime,
  PRD creation, issue creation, deployment, merge, or automation, include that
  as a validation step.

## Issue Disposition Table

When generating the PR body (Step 3), load
`references/issue-disposition-rules.md`. Include an `## Issues`
section immediately after `## Phases completed` when issues are
discovered, and use that reference to assign dispositions and place
GitHub auto-closing keywords.

## Vertical Slice Progress Table

When PRD and issue lineage can be reconstructed, include the `## Vertical slice progress`
section from `references/pr-body-template.md` before `## Issues`.

Table requirements:

- Render PRD rows first, then issue rows directly underneath each PRD.
- Keep the schema exact:
  - `Status | Title | Description | Date closed / merged`
- For issue rows, include a visual prefix in `Title` (for example `↳`).
- If an issue was closed by a merged PR, link the issue title to that PR URL.
- Prefer PR merge date for closed-by-PR rows; otherwise use issue closed date.
- If lineage or dates are unavailable, use `-` and continue without blocking.
- If no PRD/issue lineage can be found, omit the section.

## Tuning notes

- **Prefer phase-run outcome files over raw `git log`.** They have
  the plan-to-actual mapping already; the deviation subagent's job
  is easier when given rich evidence. Fall back to `git log` only
  for non-`execute-phase` branches. If the branch appears phase-based
  or `workflow-finalize` expects phase evidence, halt until phase-run
  outcomes exist or the user explicitly waives that evidence.

- **Ticket URL construction is opt-in.** By default, ticket refs
  like `ENG-1234` are listed but not linked — avoids hardcoding
  Linear / JIRA / Shortcut specifics. To enable linking: declare a
  base URL in a repo-root `.tickets.env` file (e.g.
  `TICKET_BASE_URL=https://linear.app/myorg/issue/`), and this skill
  will concatenate the ref with the base.

- **PR description vs. commit messages.** This skill writes the PR
  body; it does not rewrite commit messages. If `/execute-phase`
  produced a commit with the wrong message, fix it in the commit
  (not here) — the PR body pulls from commits, so the fix
  propagates.

- **Solo projects.** Run with `apply=false` (default) and review
  the body file before pushing. Useful even without a PR — the
  body file becomes a compressed changelog entry.

- **Graphify evidence is opportunistic, not a rebuild trigger.** If
  `graphify-out/graph.json` exists, query it and record the evidence. If it
  does not exist, record `not_available_with_reason` and continue from git,
  issue, plan, and phase evidence. Never run extraction from this skill.

- **Fail closed in workflow-finalize.** `workflow-finalize` may create or
  update a PR only from the body file and `describe_pr` evidence produced by
  this skill. A nice-looking ad-hoc PR body is still missing evidence.

- **Review-comment ownership.** `/describe-pr` produces the body only.
  `workflow-finalize` owns reviewer-comment resolution through
  `receive-review` and `watch-ci`.

- **Follow with `workflow-finalize`.** `workflow-finalize` owns draft PR
  creation, reviewer-comment resolution, `watch-ci`, reconciliation,
  and final handoff. Do not skip around it from this skill.

- **Ported from** `~/Desktop/skills/describe-pr/SKILL.md`. Drops:
  `implementation-reviewer` subagent type (→ `general-purpose`
  with an explicit deviation-analysis brief), external
  `scripts/pr_diff_urls.sh` (→ `references/diff-url-guidance.md`),
  `.humanlayer/tasks/<slug>/pr-description.md` output path (→
  `docs/executions/.pr-bodies/`), and Linear-specific
  `linear get-issue-v2` calls plus hardcoded Linear URL assembly (→
  pluggable regex + opt-in base URL). Keeps reusable PR-body and
  deviation-review material in this skill's bundled `references/`
  files. Adds: `## Phases completed` section mapping commits to plan
  §5 phase numbers, `## New findings surfaced during execution` from
  phase-run outcome files' `## Follow-ups`, `.phase-runs/`-first
  evidence preference with `git log` fallback.

## Pairing with the core loop

```
/repo-audit     →  docs/audits/<date>-repo-audit.md          (FIND-NN; optional —
     ↓                                                        brief-mode skips this)
/design-plan    →  docs/plans/<date>[-<slug>]-design.md      (audit OR brief mode)
     ↓
/execute-phase  →  docs/executions/.phase-runs/*.md          ({refactor,fix,feat}/
     ↓                                                        phase-* branches)
/workflow-review → review synthesis with independent review evidence   (in-loop, risk-sized profile)
     ↓
/post-mortem    →  docs/executions/<date>-post-mortem.md     (NEW-NN, drift)
     ↓
/workflow-finalize → describe-pr, draft PR, receive-review,
                     watch-ci, reconcile, draft handoff
     ↓
[human merge]

(on-demand side-car: /setup-worktree → isolated checkout for human review)
```
