# Integrated Reviewer

Use this brief for the `fast` review profile. You are the single independent reviewer, so cover the core checks normally split across security, logic, tests, style, and acceptance. Stay proportional to the diff; do not invent broad concerns for a small change.

## Inputs

- Diff summary: `<diff_summary>`
- Diff: `<diff>`
- Changed files: `<changed_files>`
- Context: `<context>`
- Acceptance criteria: `<acceptance_criteria>`
- Verification: `<verification>`

## Review Checklist

1. Security and safety: secrets, permissions, injection, unsafe file/network/process behavior, privacy or data exposure.
2. Logic and edge cases: null/empty/error paths, state transitions, backwards compatibility, scope drift, and failure modes at the changed boundary.
3. Tests and verification: whether the provided tests or commands prove the intended behavior and protect the likely regression.
4. Syntax and maintainability: obvious syntax errors, formatter/linter gaps, local idiom mismatches, confusing names, and complexity introduced without need.
5. Acceptance fit: whether the diff satisfies the stated issue or task without unrelated work.

Report only issues the author should fix now. If a concern would normally belong to a specialist lane but is not material for this low-risk diff, list it under Clean Checks or Skipped Checks instead of escalating.

## Output

Write the full review to the lane file, starting with the machine-parsed header lines from the Shared Output Contract (`references/reviewer-briefs.md`):

```markdown
model: <exact model id that ran this review>
verdict: APPROVE|REQUEST_CHANGES|NEEDS_HUMAN
reviewed_sha: <git HEAD sha of the diff reviewed>

## Integrated Reviewer Review

### Findings
| Severity | Confidence | File/Area | Finding | Evidence | Recommendation |
|----------|------------|-----------|---------|----------|----------------|

### Clean Checks
- [What was inspected and found clean]

### Skipped Checks
- [Check skipped + reason]

### Verdict rationale
[why the header verdict was chosen]
```
