# Subagent Briefs

## Cluster Dispatch

For each `[auto]` cluster, dispatch one `general-purpose` Agent with an
explicit file or glob scope. Dispatch clusters in parallel only when
their scopes are disjoint. Serialize when scopes overlap or one
cluster depends on another's output.

Collect all subagent reports. If any task is marked `failed`, do not
dispatch later clusters. Surface the failure, write the outcome file,
and halt with no commit.

## Worker Brief Template

```markdown
**Phase goal (context):** <phase Goal>

**Your scope:** <explicit list of file paths or globs the cluster may
read and modify>. Do not touch files outside this scope.

**Ordered tasks (verbatim from the plan):**
<numbered list of the cluster's `[auto]` task text>

**Constraints:**

- Do not execute any `[human]` task even if you encounter one in
  context.
- Prefer absolute-path invocations for commands whose output is
  load-bearing evidence (`/bin/ls -la`, `/usr/bin/git`, etc.);
  tool-harness output truncation has been observed on bare `ls`.
- Report back per task: status (`done` or `failed`), files touched
  (absolute paths), exact command(s) run, notable output, and any
  deviation from the task text.

**Rollback reference (if you hit a recoverable failure):** <phase
Rollback text>. Do not invoke rollback silently; report and return.
```

## Scope Discipline

Err toward tight scopes. A cluster that needs to touch `src/foo.ts`
should be granted exactly that path, not `src/`. Wide scopes mask
scope-discipline breaks and make post-batch verification less useful.

## Evidence Commands

Prefer absolute-path invocations when command output is load-bearing
evidence. A prior phase observed a subagent's bare `ls -la` output
losing long-format columns through the tool harness, while
`/bin/ls -la` preserved them.

The scope-verification step still re-runs `git status --porcelain` and
`git diff --name-only HEAD` independently, rather than trusting quoted
cluster-subagent listings.
