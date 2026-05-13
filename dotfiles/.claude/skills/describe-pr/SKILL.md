---
name: describe-pr
description: Generate a deviation-aware PR description for a branch produced by /execute-phase. Reads the design plan, the phase-run outcome files, the post-mortem (in the Audit Loop), and the commit history; dispatches a general-purpose subagent to compare planned vs. actual; produces a PR body that lists phases completed, cites FIND-NN / REQ-NN / NEW-NN / ticket slugs / phase numbers with commit hashes, and flags any drift from the plan. Works on solo-to-main workflows (returns body text) and team workflows (optionally applies via `gh pr edit`). Followed by /watch-ci which polls CI, applies bounded auto-fixes, and runs self-review post-PR-open.
triggers:
  - "/describe-pr"
  - "describe pr"
  - "generate pr description"
  - "write pr body"
persona: Staff Engineer writing a PR body that closes the loop between plan and commits
inputs:
  - name: plan_path
    type: string
    default: ""
    description: Path to the design plan this PR implements. If empty, use the newest `docs/plans/*.md`.
  - name: pr_number
    type: integer
    default: 0
    description: GitHub PR number. If 0 and the current branch has a PR, use it. If 0 and no PR exists, produce the body text only (stdout) without attempting to apply.
  - name: branch
    type: string
    default: ""
    description: Branch name. If empty, use the current branch (`git rev-parse --abbrev-ref HEAD`).
  - name: apply
    type: boolean
    default: false
    description: If true, apply the generated body to the PR via `gh pr edit <pr_number> --body-file <path>`. If false, return the body text and write it to docs/executions/ for review.
  - name: base
    type: string
    default: "main"
    description: Base branch for the PR (used for diff range and URL construction).
reads:
  - docs/plans/<date>-design.md (newest unless `plan_path` is set)
  - docs/executions/.phase-runs/<date>[-<plan-slug>]-phase-<N>.md (all phases whose branches contributed to this PR)
  - docs/executions/<date>-post-mortem.md (the retro written by the post-mortem subagent; /describe-pr runs AFTER it in the Audit Loop and cites its `NEW-NN` + drift findings directly in the PR body)
  - git log, git diff, `gh pr view` (if gh CLI is available)
writes:
  - docs/executions/.pr-bodies/<date>-pr-<N>.md (the generated body, for review or for `gh pr edit --body-file`)
  - (optional, if `apply == true`) the PR body on GitHub via `gh pr edit`
---

## Contract

Consumes: git log, git diff, design plan (docs/plans/), phase-run outcome files (docs/executions/.phase-runs/), post-mortem (docs/executions/), issue/ticket refs, GitHub issues (via `gh issue view`)
Produces: PR body markdown file (docs/executions/.pr-bodies/), optionally applied to GitHub PR
Requires: gh, git
Side effects: creates/updates PR body on GitHub (when apply=true), writes body file to docs/executions/.pr-bodies/
Human gates: none

## Context

Typical workflows: audit-loop (after /post-mortem, before /watch-ci)
Pairs well with: execute-phase, post-mortem, watch-ci, design-plan

# /describe-pr — Deviation-Aware PR Description

## Purpose

A PR that lands a multi-phase refactor is hard to describe by hand:
the commits came from `/execute-phase` across several stacked branches,
the plan has `FIND-NN` / `GAP-NN` / phase-number vocabulary, and the
reviewer wants to know "what diverged from the plan." This skill
reads the plan, the phase-run outcome files, and the commits, then
dispatches one `general-purpose` subagent to produce a deviation-aware
PR body.

Solo-to-main: returns body text, writes it to
`docs/executions/.pr-bodies/` for review, does not touch any PR.
Team flow: applies to the PR via `gh pr edit --body-file` when
`apply == true`.

## Step 0: Preflight

- Confirm a git repo.
- Resolve `branch`: if empty, use `git rev-parse --abbrev-ref HEAD`.
  Abort if still empty.
- Resolve `plan_path`: if empty, use the newest `docs/plans/*.md`.
  Abort if no plan exists (nothing to compare against).
- Resolve `pr_number`: if 0, try
  `gh pr view --json number -q .number 2>/dev/null`. If still 0,
  set `apply = false` (no PR to apply to) and proceed — the output
  will just be body text + file artifact.
- Ensure `docs/executions/.pr-bodies/` exists (`mkdir -p`).
- Compute the diff range:
  - If PR exists: use `gh pr view <pr_number> --json baseRefName -q .baseRefName` as base, `<branch>` as head.
  - Else: use `<base>` (default `main`) as base.

## Step 1: Gather inputs

1. **Plan sections.** Read the plan's `## §3 Goals`, `## §5 Execution plan`, and any phase-header Addresses entries. Build a map `phase_N → [FIND-NN, GAP-NN, ...]`.
2. **Phase-run outcomes.** Glob `docs/executions/.phase-runs/*-phase-*.md` and filter to those whose `**Branch:**` header matches a branch that merged into this PR — trace via `git log --format=%H <base>..<branch> --grep "^phase-"` and `git branch --list '{refactor,fix,feat}/phase-*'` for stacked branches. For each matched outcome: read `## Commits`, `## Scope violations`, `## Follow-ups`, `## Chain state`.
3. **Commits.** `git log --oneline <base>..<branch>` and `git diff --stat <base>..<branch>`. Note which commits use the `phase-<N>: ...` schema and which don't.
4. **Diff URLs.** Generate per-file GitHub diff anchors (inline, no external script):
   - `git remote get-url origin` → parse `github.com:<owner>/<repo>.git` → `https://github.com/<owner>/<repo>`.
   - For each changed file: `printf '%s' "<path>" | git hash-object --stdin` → use first 8 chars as the diff anchor.
   - PR permalink per file: `https://github.com/<owner>/<repo>/pull/<pr_number>/files#diff-<anchor>`.
   - If no PR: `https://github.com/<owner>/<repo>/compare/<base>...<branch>#diff-<anchor>`.
5. **Ticket-reference detection (pluggable regex).** Scan commit messages and plan §5 Addresses for any of: `FIND-NN`, `REQ-NN`, `NEW-NN`, `GAP-NN`, `phase-N`, `[A-Z]+-\d+` (JIRA-style), `ENG-\d+`, `LL-\d+`, `#\d+` (GitHub issue/PR style). Collect unique references. Do not hardcode Linear-specific URL construction — link ticket refs only if the plan or a `.tickets.env` file declares a base URL.
6. **Issue discovery.** Run the Issue Discovery pipeline (see § Issue Discovery) across all 7 sources. For each discovered issue, fetch title/state via `gh issue view`. Build the issue list that will feed into the disposition table in Step 3.

## Step 2: Dispatch deviation-review subagent

Spawn one `general-purpose` `Agent` with this brief:

> You are reviewing a PR against its design plan. Your job is to flag deviations — tasks added, tasks skipped, scope changed mid-phase, rollback invoked, plan sections unimplemented.
>
> **Plan:** <plan_path>
> **Branch:** <branch>
> **Base:** <base>
> **Commits in PR:**
> <git log --oneline <base>..<branch>>
>
> **Phase-run outcomes (richer than raw git log — prefer these as evidence):**
> <list the .phase-runs/ files to read>
>
> **Your output (return, do not write files):**
>
> 1. Per-phase summary: for each phase header in plan §5, name what the PR actually did. One of: `as planned`, `drifted`, `skipped`, or `not this PR`.
> 2. For each `drifted` phase: quote the specific task text that changed, cite the commit hash(es) that implemented the deviation, and flag whether the drift is benign (equivalent outcome) or material (scope/intent change).
> 3. For each `skipped` phase: explain from the plan and outcome files whether the skip is intentional (deferred to a future plan per §9 Open questions) or an accidental miss.
> 4. Any `## Scope violations` or `## Follow-ups` (NEW-NN) across the outcome files — elevate to the PR body's risk section.
>
> Be concrete. Cite commit short-hashes. Do not invent drift that isn't in the evidence.

Wait for the subagent to return. Record the report.

## Step 3: Compose the PR body

Write to `docs/executions/.pr-bodies/<date>-pr-<N>.md` (or `<date>-pr-<branch>.md` if no PR) using this template:

```
## What this PR does

<One paragraph. Drawn from plan §3 Goals + the overall pattern of
commits. Do not quote verbatim — summarize.>

## Phases completed

<For each phase with at least one commit in this PR:
- **Phase <N> — <plan Goal>** — addresses <FIND-NN, ...>
  - Status: as planned | drifted | skipped
  - Commits: <short-hash> <short-hash> ...
  - Evidence: `docs/executions/.phase-runs/<outcome file>`
>

## Issues

<For each issue discovered by Issue Discovery (§ Issue Discovery),
assign a disposition per § Issue Disposition Table rules:

| Issue | Disposition | Rationale |
|-------|-------------|-----------|
| #N    | Closes / Fixes / Addresses / Refs / ... | Why this disposition |

For auto-closing dispositions, add GitHub keywords after the table:
Closes #N
Fixes #N

If no issues discovered: omit this section.>

## User-facing changes

<Bulleted list, one per observable change. Each item ends with a
per-file diff permalink from Step 1.4. Skip if the PR is purely
internal (tests, refactors, docs).>

## How I implemented it

<Walkthrough by phase, not by file. For each phase: one paragraph
on approach, with 2-3 per-file permalinks for the meatiest files.
Keep this under ~300 words.>

## Deviations from the plan

<Verbatim from the deviation-review subagent's report. If no
deviations: "Plan followed as written." If any `## Scope violations`
surfaced: list them here with attribution.>

## New findings surfaced during execution

<NEW-NN entries from `## Follow-ups` across phase-run outcome files.
For each: title, severity, recommendation (promote to FIND-NN in
next /repo-audit / fix inline / defer). If none: omit this section.>

## How to verify

<From the plan's Verification blocks for each phase in this PR,
plus the phase-run outcome files' `## Verification` overall
PASS/FAIL. Cite any UNVERIFIED load-bearing claim as a reviewer
focus item.>

## Changelog entry

<One line, imperative mood, conventional-commit style:
`feat(scope): <outcome>` or `refactor(scope): <outcome>`. Omit if
this is a purely internal change.>

## References

<Ticket refs collected in Step 1.5, as a flat list. Only linkify
when a base URL is declared (see Tuning notes). No Linear-specific
URL construction by default.>
```

## Step 4: Apply (optional)

If `apply == true` and a PR exists:

- `gh pr edit <pr_number> --body-file docs/executions/.pr-bodies/<date>-pr-<N>.md`
- Confirm success; record the command and the resulting `gh pr view --json url -q .url` in chat.

If `apply == false` (default): skip.

## Step 5: Surface

Print to chat:

- One-sentence summary: "PR body for branch `<branch>` generated — <K> phases documented, <M> deviations flagged, <N> new findings."
- PR URL if one exists.
- Pointer to the body file: `docs/executions/.pr-bodies/<date>-pr-<N>.md`.
- If `apply == true`: confirmation that the PR body was updated.

## Output Format

Markdown body text at `docs/executions/.pr-bodies/<date>-pr-<N>.md`, structured per Step 3. Optionally applied to a GitHub PR via `gh pr edit`.

## Error Handling

| Failure | Behavior |
|---------|----------|
| Not in a git repo | Abort. |
| `gh` CLI not installed and `pr_number == 0` | Proceed in text-only mode; no PR actions attempted. |
| No plan at `plan_path` / no newest plan | Abort. Tell the user to run `/design-plan` first or pass `plan_path`. |
| No `.phase-runs/` files matching the branch range | Degrade gracefully — produce the body from raw `git log` only, note in "Deviations" that phase-run outcome files were unavailable so drift detection is weaker. |
| Deviation subagent returns empty | Retry once with a tighter prompt; if still empty, surface in the body that deviation analysis was unavailable. |
| `gh pr edit` fails at apply step | Keep the body file; surface the `gh` error; tell the user to apply manually with `gh pr edit <N> --body-file <path>`. |
| `git hash-object` unavailable (unlikely) | Omit per-file diff permalinks; use the compare-view URL for the whole PR. |
| `git remote get-url origin` not GitHub | Omit diff permalinks; link the outcome files instead. Note in body that repo is not on GitHub. |

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

Deduplicate across all sources. For each discovered issue, fetch its title and status via `gh issue view <N> --json title,state,labels -q '{title,state,labels}'` (skip silently if `gh` is unavailable or the issue doesn't exist).

## Issue Disposition Table

When generating the PR body (Step 3), include an `## Issues` section immediately after `## Phases completed`. For each discovered issue, assign a disposition:

### Disposition rules

| Disposition | When to use | GitHub effect |
|-------------|-------------|---------------|
| **Closes** | ALL acceptance criteria fully met | Auto-closes on merge |
| **Fixes** | Bug fully fixed with regression test | Auto-closes on merge |
| **Resolves** | Issue fully addressed (non-bug) | Auto-closes on merge |
| **Addresses** | Partial progress only | Does NOT close |
| **Refs** | Related context, no direct work | Does NOT close |
| **Follow-up created** | New work spawned during this PR | Does NOT close |
| **Supersedes** | This PR replaces the issue's approach | Manual close needed |

**Critical rule:** Never use Closes/Fixes/Resolves unless the issue is FULLY complete. Partial work uses "Addresses" only. When in doubt, prefer "Addresses" over "Closes".

### Table format in the PR body

```markdown
## Issues

| Issue | Disposition | Rationale |
|-------|-------------|-----------|
| #123 | Closes | All acceptance criteria met |
| #124 | Fixes | Bug root cause addressed + regression test added |
| #125 | Addresses | Partial progress — 3 of 5 criteria met |
| #126 | Refs | Related context, no direct work done |
| #127 | Follow-up created | New work discovered → #130 |
| #128 | Supersedes | This approach replaces #128 |
```

### Disposition assignment logic

To determine the correct disposition for each issue:

1. If the issue was explicitly provided as "closes" by the user or workflow → **Closes** (trust the caller).
2. If the issue has acceptance criteria, diff each criterion against the commits and changed files:
   - All met → **Closes** (or **Fixes** if the issue is labeled `bug` and a test was added).
   - Some met → **Addresses** with a rationale listing which criteria are met/unmet.
   - None met → **Refs**.
3. If the issue was discovered only from branch name or commit messages but no direct work maps to it → **Refs**.
4. If a `NEW-NN` finding in the post-mortem created a follow-up issue → **Follow-up created** with a link to the new issue.
5. If the plan explicitly states this approach replaces an earlier issue → **Supersedes**.

### GitHub keyword placement

For auto-closing dispositions (Closes/Fixes/Resolves), place the keyword in the PR body so GitHub recognizes it:

- Use the exact format: `Closes #123`, `Fixes #124`, `Resolves #125` (one per line, outside the table).
- Place these keywords in the `## Issues` section footer, after the table.
- Non-closing dispositions use plain `#N` references only (no GitHub keyword prefix).

## Tuning notes

- **Prefer phase-run outcome files over raw `git log`.** They have
  the plan-to-actual mapping already; the deviation subagent's job
  is easier when given rich evidence. Fall back to `git log` only
  when outcome files are absent or mismatched.

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

- **Follow with `/watch-ci`.** Once the PR is opened (manually via
  `gh pr create` with the body this skill produced, or
  automatically by `/watch-ci` if no PR exists yet), `/watch-ci`
  polls GitHub Actions, classifies failures, applies bounded
  auto-fixes (max 3 attempts, halt on no-progress), runs
  `/security-review` on green, and submits Approve when clean.
  `/describe-pr` produces the body; `/watch-ci` runs the loop.

- **Ported from** `~/Desktop/skills/describe-pr/SKILL.md`. Drops:
  `implementation-reviewer` subagent type (→ `general-purpose`
  with an explicit deviation-analysis brief), external
  `scripts/pr_diff_urls.sh` (inlined git-remote-parse + `git
  hash-object` logic), `.humanlayer/tasks/<slug>/pr-description.md`
  output path (→ `docs/executions/.pr-bodies/`),
  Linear-specific `linear get-issue-v2` call and hardcoded Linear
  URL assembly (→ pluggable regex + opt-in base URL),
  `{SKILLBASE}/references/pr_description_template.md` and
  `{SKILLBASE}/references/describe_pr_final_answer.md` (inlined).
  Adds: `## Phases completed` section mapping commits to plan §5
  phase numbers, `## New findings surfaced during execution` from
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
/review         →  inline reviewer comments (workspace)      (in-loop, fresh subagent)
     ↓
/post-mortem    →  docs/executions/<date>-post-mortem.md     (NEW-NN, drift)
     ↓
/describe-pr    →  PR body / docs/executions/.pr-bodies/*.md (this skill;
     ↓                                                        cites NEW-NN from retro)
[human gh pr create]
     ↓
/watch-ci       →  docs/executions/.ci-runs/*.md             (poll, auto-fix,
                                                              /security-review,
                                                              approve when clean)
     ↓
[human merge]

(on-demand side-car: /setup-worktree → isolated checkout for human review)
```
