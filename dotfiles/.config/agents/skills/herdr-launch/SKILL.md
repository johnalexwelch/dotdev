---
name: herdr-launch
description: >
  Open stage-appropriate companion tools in herdr after setup-worktree.
  Stages: implement (workspace + lazygit + yazi), review (gh pr diff + gh pr
  view), ci (gh run watch), cleanup (lazygit + worktree list). Only runs when
  HERDR_ENV=1. Call after setup-worktree; pass workspace_id for stages after
  implement.
triggers:
  - "/herdr-launch"
  - "herdr launch"
  - "open tools"
  - "open companion tools"
inputs:
  - name: stage
    type: string
    description: "One of: implement | review | ci | cleanup"
  - name: worktree_path
    type: string
    default: ""
    description: Absolute worktree path. Required for implement stage.
  - name: issue_slug
    type: string
    default: ""
    description: Short label for the workspace/tab (e.g. "issue-42"). Derived from worktree path if empty.
  - name: workspace_id
    type: string
    default: ""
    description: Herdr workspace id from the implement stage. Required for review, ci, cleanup.
  - name: pr_number
    type: string
    default: ""
    description: PR number for review stage. Auto-detected from gh if empty.
  - name: run_id
    type: string
    default: ""
    description: GH Actions run id for ci stage. Uses gh run watch (auto picks latest) if empty.
  - name: open_yazi
    type: boolean
    default: true
    description: Open yazi file browser tab during implement stage.
reads: []
requires: herdr, lazygit, gh, yazi (implement), delta (review)
side_effects: creates herdr workspaces, tabs, and panes; does not mutate repo files
human_gates: none
---

# herdr-launch — Stage-Aware Companion Tools

## Contract

Consumes: `stage` (implement|review|ci|cleanup), `worktree_path` (implement), `workspace_id` (review/ci/cleanup), optional `pr_number`/`run_id`/`issue_slug`; env `HERDR_ENV`
Produces: herdr workspace/tabs/panes running stage-appropriate companion tools; the `workspace_id` (from implement) that later stages require
Requires: `HERDR_ENV=1`; herdr, lazygit, gh, yazi (implement), delta (review)
Side effects: creates herdr workspaces, tabs, and panes; does not mutate repo files
Human gates: none (halts and asks the caller for `workspace_id` if missing on review/ci/cleanup)

## Precondition

**Check `HERDR_ENV` first.** If `HERDR_ENV` is not `1`, print a single line:

```
herdr-launch: HERDR_ENV not set — skipping (not running inside herdr).
```

Then stop. Do not attempt any herdr commands.

## Resolve inputs

- `issue_slug`: if empty, derive from `worktree_path` basename (strip leading
  date prefix if present; e.g. `~/wt/chorus/issue-42-auth` → `issue-42-auth`).
- `workspace_id`: required for review/ci/cleanup stages. If missing, halt and
  tell the caller to pass it from the implement stage output.

---

## Stage: implement

**Purpose**: Create an isolated herdr workspace at the worktree and open
lazygit (and optionally yazi) as companion tools.

### Steps

1. Create the workspace:
   ```bash
   herdr workspace create --cwd <worktree_path> --label "<issue_slug>"
   ```
   Parse `workspace_id` from `result.workspace.workspace_id` (or equivalent
   field). Record it — caller needs it for later stages.

2. List panes in the new workspace to find the root pane id:
   ```bash
   herdr pane list
   ```
   Find the pane belonging to the new workspace. Record as `ROOT_PANE`.

3. Split the root pane right and open lazygit:
   ```bash
   herdr pane split <ROOT_PANE> --direction right --no-focus
   ```
   Parse `LAZYGIT_PANE` from `result.pane.pane_id`.
   ```bash
   herdr pane run <LAZYGIT_PANE> "lazygit"
   ```

4. If `open_yazi` is true, open a yazi tab:
   ```bash
   herdr tab create --workspace <workspace_id> --label "files"
   ```
   Parse `FILES_TAB_PANE` (root pane of new tab).
   ```bash
   herdr pane run <FILES_TAB_PANE> "yazi <worktree_path>"
   ```

### Output

Report to chat:
```
herdr-launch [implement]
  workspace : <workspace_id>  label: <issue_slug>
  tab "work": Pi pane <ROOT_PANE> | lazygit pane <LAZYGIT_PANE>
  tab "files": yazi pane <FILES_TAB_PANE>   (or: skipped)

Pass workspace_id=<workspace_id> to next herdr-launch call.
```

---

## Stage: review

**Purpose**: Add a review tab with the PR diff (via delta) and PR comment view.

### Steps

1. Detect PR number if not provided:
   ```bash
   gh pr view --json number --jq .number
   ```

2. Create review tab in existing workspace:
   ```bash
   herdr tab create --workspace <workspace_id> --label "review"
   ```
   Parse `REVIEW_PANE` (root pane of new tab).

3. Open PR diff through delta:
   ```bash
   herdr pane run <REVIEW_PANE> "gh pr diff <pr_number> | delta --paging always"
   ```

4. Split right and open PR view (comments, status):
   ```bash
   herdr pane split <REVIEW_PANE> --direction right --no-focus
   ```
   Parse `PR_VIEW_PANE`.
   ```bash
   herdr pane run <PR_VIEW_PANE> "gh pr view <pr_number>"
   ```

### Output

```
herdr-launch [review]
  tab "review": diff pane <REVIEW_PANE> | pr-view pane <PR_VIEW_PANE>
```

---

## Stage: ci

**Purpose**: Add a CI tab watching the current run.

### Steps

1. Create ci tab:
   ```bash
   herdr tab create --workspace <workspace_id> --label "ci"
   ```
   Parse `CI_PANE`.

2. Start watching. If `run_id` provided:
   ```bash
   herdr pane run <CI_PANE> "gh run watch <run_id> --exit-status"
   ```
   Otherwise (auto-pick latest for current branch):
   ```bash
   herdr pane run <CI_PANE> "gh run watch --exit-status"
   ```

### Output

```
herdr-launch [ci]
  tab "ci": gh run watch pane <CI_PANE>
```

---

## Stage: cleanup

**Purpose**: Add a cleanup tab with lazygit and worktree state for
`cleanup-delivery` to work from.

### Steps

1. Create cleanup tab:
   ```bash
   herdr tab create --workspace <workspace_id> --label "cleanup"
   ```
   Parse `CLEANUP_PANE`.

2. Open lazygit in cleanup pane:
   ```bash
   herdr pane run <CLEANUP_PANE> "lazygit"
   ```

3. Split right for worktree + branch overview:
   ```bash
   herdr pane split <CLEANUP_PANE> --direction right --no-focus
   ```
   Parse `WT_PANE`.
   ```bash
   herdr pane run <WT_PANE> "git worktree list && echo '---' && git branch -vv"
   ```

### Output

```
herdr-launch [cleanup]
  tab "cleanup": lazygit pane <CLEANUP_PANE> | worktree-list pane <WT_PANE>
Ready for cleanup-delivery.
```

---

## Error handling

| Failure | Behavior |
|---------|----------|
| `HERDR_ENV != 1` | Print skip message, stop. |
| `workspace create` fails | Abort, surface herdr error. Do not proceed. |
| `pane split` / `tab create` fails | Warn, continue with remaining steps. |
| Tool not found (lazygit, yazi, etc.) | Warn per tool, skip that pane. Do not abort entire stage. |
| `workspace_id` missing for review/ci/cleanup | Halt, ask caller to provide it. |

## Calling convention (for workflow skills)

```
# After setup-worktree:
/herdr-launch stage=implement worktree_path=<path> issue_slug=<slug>
# → note returned workspace_id

# Before workflow-review:
/herdr-launch stage=review workspace_id=<id>

# Inside workflow-finalize (after PR pushed):
/herdr-launch stage=ci workspace_id=<id>

# Before cleanup-delivery:
/herdr-launch stage=cleanup workspace_id=<id>
```
