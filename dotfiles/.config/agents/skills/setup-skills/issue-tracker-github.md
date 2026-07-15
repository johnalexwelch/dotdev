# Issue tracker: GitHub

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## PRs as a request surface

**PRs as a request surface**: yes / no (default: no)

If yes, `/triage` pulls external pull requests into the same triage queue as issues and runs them through the same labels and states — a PR is an issue with attached code. Collaborators' in-flight PRs are excluded from discovery (an explicitly named PR is still triaged regardless of author).

- **External author**: the PR author is not a repository collaborator. Check with `gh api repos/{owner}/{repo}/collaborators --jq '[.[].login]'` and compare against the PR's `author.login`.
- **Read a PR**: `gh pr view <number> --comments`, plus `gh pr diff <number>` for the change itself.
- **List PRs**: `gh pr list --state open --json number,title,body,labels,author,comments,createdAt` with appropriate `--label` filters; filter out collaborator authors before presenting for triage discovery.
- **Comment on a PR**: `gh pr comment <number> --body "..."`
- **Apply / remove labels**: `gh pr edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh pr close <number> --comment "..."` (triage closes; it does not merge)

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v` — `gh` does this automatically when run inside a clone.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

Used by the `/wayfinder` skill. The map is a GitHub issue; tickets are its sub-issues.

### Labels (bootstrap once)

```bash
for l in map research prototype grilling task blocked; do
  gh label create "wayfinder:$l" --force >/dev/null 2>&1 || true
done
```

### The map

- **Create**: `gh issue create --title "<map name>" --label wayfinder:map --body-file <body>`
- **Never** add `ready-for-agent` to a map — it is PRD-shaped and `workflow-guard.sh` will block it. The map is a planning artifact only.
- **Read the body**: `gh issue view <map> --json title,body`
- **Update the body** (Decisions so far / Not yet specified / Out of scope): `gh issue edit <map> --body-file <updated>`

### Tickets (child issues of the map)

- **Create then attach** as a sub-issue of the map:
  - `gh issue create --title "<ticket name>" --label "wayfinder:<type>" --body-file <body>`
  - attach: `gh api -X POST repos/{owner}/{repo}/issues/<map>/sub_issues -f sub_issue_id=<ticket-id>` (or the github MCP `sub_issue_write` tool in-session)
- **Claim** (do this first, before any work): `gh issue edit <ticket> --add-assignee @me` — assignment *is* the claim.
- Type label is one of `wayfinder:research|prototype|grilling|task`.

### Blocking & the frontier

- **Native**: use GitHub issue dependencies ("blocked by") when available — it renders the frontier in the GitHub UI.
- **Fallback** (always safe): add a `Blocked by: #N` line to the blocked ticket's body and label it `wayfinder:blocked`; drop the label when the last blocker closes.
- **Frontier query** (open, unblocked, unclaimed children of the map):
  `gh issue list --state open --search "no:assignee -label:wayfinder:blocked" --json number,title,labels,assignees`, then keep only sub-issues of the map whose blockers are all closed.

### Resolution

1. **Answer**: `gh issue comment <ticket> --body-file <answer>`
2. **Close**: `gh issue close <ticket>`
3. **Index it**: append one line to the map body's "Decisions so far" (`gh issue edit <map> --body-file ...`)
4. **Mirror the decision** to `docs/decision-log.md` via `/decision-log` — the canonical record with alternatives/tradeoffs.

### Local-markdown fallback

If no GitHub tracker is available, the map is `docs/wayfinder/<slug>/map.md` and tickets are files under `tickets/`, with `Blocked by:` lines and a front-matter `status:` field standing in for labels/assignment.
