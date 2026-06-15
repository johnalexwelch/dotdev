# Exhaustion Handoff

Load this reference when `/watch-ci` exhausts bounded auto-fix attempts or halts with no progress.

`watch-ci` does not invoke `diagnose` directly. It produces a self-contained handoff artifact and halts. `workflow-debug` or `workflow-build-one` picks up the artifact and routes to diagnose.

## Output Path

Prefer issue-local context when available:

```text
docs/tasks/{issue-number}-{slug}/ci-handoff.md
```

Fallback:

```text
docs/executions/ci-handoffs/{pr-number}-{date}.md
```

## Template

````markdown
## CI Exhaustion Handoff - [PR #N]

**Workflow:** [workflow name that failed]
**Job:** [specific job name]
**Classification:** [lint | type-error | test-failure | build-failure | deploy-failure | timeout | unknown]
**Attempts:** 3/3 (exhausted)

### Failure pattern
[Concise description of what's failing and why auto-fix couldn't resolve it]

### Log excerpt
```
[Relevant error lines from the most recent failure - max 50 lines]
```

### Attempts tried
1. [What was tried in attempt 1 + why it didn't work]
2. [What was tried in attempt 2 + why it didn't work]
3. [What was tried in attempt 3 + why it didn't work]

### Suspected root cause
[Best guess based on the pattern - may be wrong, diagnose should verify]

### Recommended diagnosis mode
[quick | standard | deep | regression - based on failure complexity]
````

## Rules

- The artifact must be self-contained; diagnose should be able to start without re-reading CI logs.
- Include exact workflow/job names, the most recent relevant log excerpt, and attempted fix history.
- Halt after writing the artifact and PR comment.
- Do not force-push, rebase, reset, or invoke destructive git behavior to escape exhaustion.
