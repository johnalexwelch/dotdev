# Outcome File Template

## Standard Path

Write standard phase outcomes to:

```text
docs/executions/.phase-runs/<date>[-<plan-slug>]-phase-<N>.md
```

The `plan_slug` disambiguates multiple plans on the same day. Fall back
to `<date>-phase-<N>.md` when the slug is empty. `/post-mortem` and
`/describe-pr` tolerate both forms.

Never modify a prior phase's outcome file. Chain state is appended in
the new phase outcome.

## Issue Context Path

When issue context is available, write phase outcomes to:

```text
docs/tasks/{issue-number}-{slug}/phase-{N}-outcome.md
```

Derive the issue slug from the issue title: lowercase, spaces to
hyphens, max 40 characters.

Example: issue `#42` titled `Add user authentication` becomes:

```text
docs/tasks/42-add-user-authentication/phase-1-outcome.md
```

When no issue context exists, use the standard `.phase-runs` path.

## Template

```markdown
# Phase <N> - <phase Goal>

**Plan:** <relative path to plan>
**Plan slug:** <plan_slug> (or "-" if none)
**Date:** <YYYY-MM-DD>
**Goal:** <goal text>
**Addresses:** <ID list from plan>
**Mode:** live | dry_run
**Branch:** <prefix>/phase-<N>-<phase-slug>
**Parent:** <starting commit short-hash> (<prior phase branch name or "main">)

## Executed
<For each [auto] task:
  - **Task <i>** [cluster <C>]: <verbatim task text>
  - Status: done | pending (dry_run) | failed
  - Files touched: <absolute paths from subagent report>
  - Subagent command(s): <as reported>
  - Notes: <brief; include verification evidence if relevant>>

## Pending human
<For each [human] task: verbatim text, numbered. If none, "None.">

## Verification
<Overall: PASS | FAIL | UNVERIFIED>
<Verbatim Verification text from plan, followed by per-claim
breakdown from the verification subagent.>

## Rollback (reference)
<Verbatim Rollback text from plan.>

## Commits
<For each commit on the phase branch:
  - <short-hash> <subject line>
  - Changed files: <paths>>

## Scope violations
<For each out-of-scope write (or "None."):
  - Path: <absolute path>
  - Attributed to cluster: <N>
  - Cluster's granted scope: <what it was supposed to touch>>

## Plan parse warnings
<Anything parsed oddly. If none, "None.">

## Follow-ups
<NEW-NN candidates surfaced during execution. For each:
  - **NEW-NN - <short title>**
  - Severity: low | medium | high
  - Source: <commit|subagent report|observation>
  - Recommendation: promote to FIND-NN in next /repo-audit | fix
    inline | defer.
Feeds forward into /post-mortem.>

## Chain state
<For each phase in the current auto-proceed chain:
  - Phase N: status (done|halted|not-started), branch, HEAD hash>
```

The outcome file is the artifact downstream skills consume. Keep the
section names stable.
