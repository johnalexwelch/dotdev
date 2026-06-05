# Issue Disposition Rules

Load this during Step 3 when writing the `## Issues` section.

## Dispositions

| Disposition | When to use | GitHub effect |
|-------------|-------------|---------------|
| **Closes** | ALL acceptance criteria fully met | Auto-closes on merge |
| **Fixes** | Bug fully fixed with regression test | Auto-closes on merge |
| **Resolves** | Issue fully addressed (non-bug) | Auto-closes on merge |
| **Addresses** | Partial progress only | Does NOT close |
| **Refs** | Related context, no direct work | Does NOT close |
| **Follow-up created** | New work spawned during this PR | Does NOT close |
| **Supersedes** | This PR replaces the issue's approach | Manual close needed |

Critical rule: never use `Closes`, `Fixes`, or `Resolves` unless the issue is fully complete. Partial work uses `Addresses`. When in doubt, prefer `Addresses`.

## Table Format

```markdown
## Vertical slice progress

<Render before `## Issues` when PRD/issue lineage exists; use the grouped PRD -> issue format from `references/pr-body-template.md`.>

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

## Assignment Logic

1. If the issue has acceptance criteria, diff each criterion against commits and changed files.
   - All met: `Closes`, or `Fixes` if labeled `bug` and a test was added.
   - Some met: `Addresses`, with a rationale listing met and unmet criteria.
   - None met: `Refs`.
2. If the issue was explicitly provided as "closes" by the user or workflow, treat that as a claim to verify, not as proof. Use an auto-closing disposition only after confirming all acceptance criteria are met.
3. If the issue was discovered only from branch name or commit messages but no direct work maps to it, use `Refs`.
4. If a `NEW-NN` finding in the post-mortem created a follow-up issue, use `Follow-up created`.
5. If the plan explicitly states this approach replaces an earlier issue, use `Supersedes`.

For auto-closing dispositions, place the exact keyword outside the table so GitHub recognizes it: `Closes #123`, `Fixes #124`, or `Resolves #125`.

When `## Vertical slice progress` is present, keep `## Issues` focused on disposition semantics only (close/fix/address/refs rationale). Do not duplicate lineage or date fields in the disposition table.
