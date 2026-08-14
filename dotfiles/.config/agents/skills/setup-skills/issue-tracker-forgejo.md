# Issue tracker: Forgejo/Gitea

Issues and PRDs for this repo live as Forgejo (or Gitea) issues. Use the [`tea`](https://gitea.com/gitea/tea) CLI for all operations.

## PRs as a request surface

**PRs as a request surface**: yes / no (default: no)

If yes, `/triage` pulls external pull requests into the same triage queue as issues and runs them through the same labels and states — a PR is an issue with attached code. Collaborators' in-flight PRs are excluded from discovery (an explicitly named PR is still triaged regardless of author).

- **External author**: the PR author is not a repository collaborator.
- **Read a PR**: `tea pr view <number>`, plus `tea pr diff <number>` for the change itself.
- **List PRs**: `tea pr list --output json` with appropriate filters; filter out collaborator authors before presenting for triage discovery.
- **Comment on a PR**: `tea pr comment <number> "..."`
- **Apply / remove labels**: `tea pr edit <number> --labels "..."` (comma-separated list, replaces existing)
- **Close**: `tea pr close <number>` (triage closes; it does not merge)

## Conventions

- **Create an issue**: `tea issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `tea issue view <number>`.
- **List issues**: `tea issue list --output json` with appropriate `--state` and `--label` filters.
- **Comment on an issue**: `tea issue comment <number> "..."`
- **Apply / remove labels**: `tea issue edit <number> --labels "..."` (comma-separated list, replaces existing labels)
- **Close**: `tea issue close <number>`

Configure `tea` with `tea login add` to set up the remote. Infer the repo from `git remote -v` — `tea` does this automatically when run inside a clone if logged in.

## When a skill says "publish to the issue tracker"

Create a Forgejo/Gitea issue.

## When a skill says "fetch the relevant ticket"

Run `tea issue view <number>`.

## Wayfinding operations

Used by the `/wayfinder` skill. The map is a Forgejo/Gitea issue; tickets are its linked issues.

### Labels (bootstrap once)

```bash
for l in map research prototype grilling task blocked; do
  tea label create "wayfinder:$l" 2>/dev/null || true
done
```

### The map

- **Create**: `tea issue create --title "<map name>" --labels "wayfinder:map" --body "..."`
- **Never** add `ready-for-agent` to a map — it is PRD-shaped.
- **Read**: `tea issue view <map>`
- **Update**: `tea issue edit <map> --body "..."`

### Tickets (linked issues)

- **Create**: `tea issue create --title "<ticket name>" --labels "wayfinder:<type>" --body "..."`
- **Link**: reference the map in the body with `Related to #<map>` (Forgejo/Gitea shows these as linked issues)
- **Claim**: `tea issue edit <ticket> --assignees @me` — assignment is the claim.
- Type label is one of `wayfinder:research|prototype|grilling|task`.

### Blocking & the frontier

- Add a `Blocked by: #N` line to the blocked ticket's body and label it `wayfinder:blocked`; drop the label when the last blocker closes.
- **Frontier query**: `tea issue list --state open --output json`, then filter for unlabeled `wayfinder:blocked`, unassigned, and related to the map.

### Resolution

1. **Answer**: `tea issue comment <ticket> "..."`
2. **Close**: `tea issue close <ticket>`
3. **Index it**: append one line to the map body's "Decisions so far"
4. **Mirror the decision** to `docs/decision-log.md` via `/decision-log`
