# Phase Parsing

## Preflight

- Confirm working tree is clean with `git status --porcelain`. If
  dirty, abort; the phase sync gate requires a clean HEAD to branch
  from.
- **Re-anchor to authoritative state before trusting the local HEAD.**
  Run `git branch --contains HEAD` (and `git for-each-ref --contains HEAD
  refs/remotes`). If the current phase branch's HEAD is already contained
  in `main`/`origin/main`, the work merged upstream: STOP. Treat `main`
  as authoritative, do NOT mutate this (now orphaned) worktree, and
  re-run from a fresh worktree cut off updated `main`. A local worktree
  HEAD is a proxy — once merged, upstream wins. Likewise, if `git status`
  output is internally inconsistent across two adjacent reads (staged
  files appearing/disappearing), suspect a concurrent mutator and
  re-check the canonical repo refs rather than re-reading the worktree.
- Resolve `plan_path`:
  - If set, use it. Abort if the file does not exist.
  - Else pick the newest `docs/plans/*.md`. Abort with guidance if
    none exists: run `/design-plan` first or pass `plan_path`.
- Resolve `plan_slug`:
  - If set, use it verbatim.
  - Else derive from the plan filename stem by stripping a leading
    `<YYYY-MM-DD>-` and trailing `-design`.
  - Example: `2026-04-21-skills-updates-design.md` becomes
    `skills-updates`.
  - If the stem collapses to empty, use no slug component.
- Compute today's date as `<YYYY-MM-DD>`.
- Verify `phase` is a non-negative integer.
- Ensure `docs/executions/.phase-runs/` exists.
- Check for an existing outcome file at
  `docs/executions/.phase-runs/<date>[-<plan-slug>]-phase-<N>.md`.
  If present and `resume == false`, abort. The user must pass
  `resume=true` or delete the outcome file.

## ID Handling

Inspect the plan for `FIND-NN`, `REQ-NN`, `GAP-NN`, ticket slugs such
as `JIRA-123`, issue references such as `#456`, or any other ID scheme
in Addresses lines.

- All schemes are accepted.
- Echo IDs verbatim into commit messages and the outcome file header.
- Do not normalize or validate scheme-specific meaning.
- If no IDs are present, warn in the outcome file and omit the commit
  message parenthetical.

## Phase Extraction

Read the plan. Locate the section 5 execution plan, then the phase
header matching `### §5.<N> Phase <N>`. Heading levels 3 and 4 are
accepted.
Abort if not found and list the phase headers actually present.

Extract from the phase block:

- **Goal** - text under `**Goal:**`.
- **Tasks** - the enumerated list under `**Tasks:**`, preserving order
  and verbatim text.
- **Addresses** - comma-separated IDs, or `n/a`.
- **Verification** - paragraph under `**Verification:**`.
- **Rollback** - paragraph under `**Rollback:**`.
- **Deletes** - list under `**Deletes:**`, or `none`.

Missing sections are warnings, not fatal. Record them in
`## Plan parse warnings` and continue. Empty Tasks is fatal because the
plan was likely cut off mid-write.

## Task Partitioning

Walk the task list in order:

- Starts with `[auto]` -> `auto_tasks`.
- Starts with `[human]` -> `human_tasks`.
- Any other leading token -> `unknown_tasks`.

Unknown tasks are warnings and are not executed.

Group `auto_tasks` into clusters: consecutive tasks that touch the
same surface area. Tasks citing overlapping file paths, glob patterns,
or the same module belong in one cluster. Separate clusters get
separate subagents. When in doubt, use one cluster; serial execution is
safe.

## Single-Issue Mode

`execute-phase` supports both plan-phase and single-issue execution.

- **Plan-phase mode:** reads a phase from a design plan, creates a
  branch, and executes tasks.
- **Single-issue mode:** reads a GitHub issue directly, creates a
  branch from the issue number, and executes against acceptance
  criteria.

Single-issue mode is invoked by `workflow-build-one` when there is no
design plan, only a ready issue with clear acceptance criteria.
