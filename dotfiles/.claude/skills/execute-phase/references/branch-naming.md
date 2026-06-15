# Branch Naming

## Branch Prefix

Derive the branch prefix from plan mode:

- Use `refactor/` when the plan uses `FIND-NN` references
  (audit-mode).
- For brief-mode plans without `FIND-NN`, inspect the plan filename
  slug for bug-class keywords: `fix`, `bug`, `broken`, `error`,
  `crash`, `regression`.
- If a bug-class keyword is present, use `fix/`.
- Otherwise brief-mode defaults to `feat/`.
- If the heuristic misfires, the user may override with
  `branch_prefix=<value>` on a later invocation. Existing branches can
  be renamed manually.

`/post-mortem`, `/describe-pr`, and `/watch-ci` glob
`{refactor,fix,feat}/phase-*` when walking the branch stack.

## Phase Slug

Compute the phase slug from the phase header:

1. Take the text after `Phase <N> -`.
2. Lowercase it.
3. Replace non-alphanumeric runs with `-`.
4. Trim trailing `-`.
5. Cap at 40 characters.

The branch name is `<prefix>/phase-<N>-<phase-slug>`.

## Branch Creation

On `dry_run == false`:

- Run `git checkout -b <prefix>/phase-<N>-<phase-slug>` from current
  HEAD.
- Current HEAD is the previous phase commit during auto-proceed chains,
  or `main` for the first phase unless the user checked out a different
  base before invoking `/execute-phase`.
- Abort if the branch already exists; a prior attempt likely exists and
  the user must rename or delete it before re-invoking.
- Record the branch name and starting commit hash in the outcome file's
  `## Commits` block.

On `dry_run == true`, skip branch creation and note
`branch creation skipped (dry_run)` in the outcome file.

## Stacked Parentage

Phase 0 branches from the currently checked-out base, normally `main`.
Phase N+1 branches from phase N's HEAD. Each successive outcome file
references the prior phase's outcome file in its `## Commits` section
as branch ancestry.

## Commit Message

On verification PASS, stage only the union of granted scopes and commit
with:

```text
phase-<N>: <phase Goal> (addresses <ID list>)
```

IDs are echoed verbatim from the phase's Addresses line:
`FIND-NN`, `REQ-NN`, `GAP-NN`, ticket slugs such as `JIRA-123`, issue
numbers such as `#456`, or any combination. Do not normalize IDs.

Examples:

- `phase-2: Port /execute-phase to production (addresses GAP-01)`
- `phase-1: Fix mobile scroll on profile page (addresses REQ-01)`
- `phase-3: Add dark-mode toggle (addresses ENG-456, REQ-02)`

If Addresses is `n/a` or absent, omit the parenthetical.

The commit message schema is load-bearing: `/post-mortem`,
`/describe-pr`, and `/watch-ci` parse it to attribute work to phases
and ID schemes.
