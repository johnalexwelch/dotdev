# PR Body Template

Load this during Step 3 when composing the PR body.

Write to `docs/executions/.pr-bodies/<date>-pr-<N>.md` or `<date>-pr-<branch>.md` if no PR exists.

```markdown
## What this PR does

<One paragraph. Drawn from plan §3 Goals + the overall pattern of commits. Do not quote verbatim — summarize.>

## Phases completed

<For each phase with at least one commit in this PR:
- **Phase <N> — <plan Goal>** — addresses <FIND-NN, ...>
  - Status: as planned | drifted | skipped
  - Commits: <short-hash> <short-hash> ...
  - Evidence: `docs/executions/.phase-runs/<outcome file>`
>

## Issues

<For each issue discovered by Issue Discovery, assign a disposition using `references/issue-disposition-rules.md`. For auto-closing dispositions, add GitHub keywords after the table. If no issues are discovered, omit this section.>

## User-facing changes

<Bulleted list, one per observable change. Each item ends with a per-file diff permalink from `references/diff-url-guidance.md`. Skip if purely internal.>

## How I implemented it

<Walkthrough by phase, not by file. For each phase: one paragraph on approach, with 2-3 per-file permalinks for the meatiest files. Keep this under ~300 words.>

## Deviations from the plan

<Verbatim from the deviation-review subagent's report. If no deviations: "Plan followed as written." If scope violations surfaced, list them with attribution.>

## New findings surfaced during execution

<NEW-NN entries from `## Follow-ups` across phase-run outcome files. For each: title, severity, recommendation. If none, omit this section.>

## How to verify

<From the plan's Verification blocks and phase-run outcome files' `## Verification` PASS/FAIL. Cite any UNVERIFIED load-bearing claim as a reviewer focus item.>

## Changelog entry

<One line, imperative mood, conventional-commit style: `feat(scope): <outcome>` or `refactor(scope): <outcome>`. Omit if purely internal.>

## References

<Ticket refs collected in Step 1.5, as a flat list. Only linkify when a base URL is declared.>
```
