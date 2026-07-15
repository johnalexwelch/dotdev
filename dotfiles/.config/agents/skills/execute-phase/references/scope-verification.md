# Scope Verification

After `[auto]` clusters complete, dispatch one short read-only
`general-purpose` subagent to verify scope discipline.

## Verification Brief

```markdown
Run `git status --porcelain` and `git diff --name-only HEAD`.
Compare the changed-files set against the granted scopes of each
cluster that just ran (inlined below). Report:

- Any file present in the diff but NOT covered by any cluster's
  granted scope -> **scope violation**. Quote the file path and which
  cluster's scope it leaked from, if attributable.
- Any cluster whose granted scope saw zero writes -> note only, not a
  failure.

Do not modify anything. Return a structured report.

Granted scopes:

- Cluster 1: <paths/globs>
- Cluster 2: <paths/globs>
- ...
```

The orchestrator runs these diff commands through the verification
subagent. Do not rely only on working subagent reports for changed-file
sets.

## Violation Behavior

Any scope violation halts the phase.

- Populate `## Scope violations` in the outcome file.
- Do not run behavioral verification.
- Do not commit.
- Surface the exact paths and granted scopes to the user.
- The user must revert out-of-scope writes or explicitly expand scope
  in the plan before continuing.

Files with zero writes inside a granted cluster scope are informational
only and do not fail the phase.
