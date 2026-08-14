# Issue tracker: Linear

Issues and PRDs for this repo live as Linear issues. Use the Linear MCP server or direct API calls.

## MCP Server

The Linear MCP server provides tools for issue operations. Ensure it's configured in your MCP settings.

## Conventions

- **Create an issue**: use `linear_create_issue` MCP tool with `title`, `description`, `teamId`, and optional `labelIds`, `assigneeId`, `projectId`.
- **Read an issue**: use `linear_get_issue` MCP tool with the issue ID or identifier (e.g., `ENG-123`).
- **List issues**: use `linear_search_issues` MCP tool with filters for state, labels, assignee, project.
- **Comment on an issue**: use `linear_create_comment` MCP tool with `issueId` and `body`.
- **Apply labels**: use `linear_update_issue` MCP tool with `labelIds` array.
- **Change state**: use `linear_update_issue` MCP tool with `stateId` (maps to your workflow states like Triage, Backlog, In Progress, Done, Canceled).
- **Assign**: use `linear_update_issue` MCP tool with `assigneeId`.

## API Fallback

If MCP is unavailable, use the Linear API directly:

```bash
# Read an issue
curl -s -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ issue(id: \"<id>\") { id title description state { name } labels { nodes { name } } comments { nodes { body } } } }"}' \
  https://api.linear.app/graphql

# Create an issue
curl -s -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"mutation { issueCreate(input: { title: \"...\", description: \"...\", teamId: \"...\" }) { issue { id identifier } } }"}' \
  https://api.linear.app/graphql
```

## Linear workflow states (map to triage labels)

Linear uses workflow states instead of labels for issue lifecycle. Common mappings:

| Triage role       | Linear state   |
|-------------------|----------------|
| `needs-triage`    | Triage         |
| `needs-info`      | Blocked        |
| `ready-for-agent` | Backlog / Todo |
| `ready-for-human` | Backlog / Todo |
| `wontfix`         | Canceled       |

Your team may have custom states — adjust the mapping in `docs/agents/triage-labels.md`.

## When a skill says "publish to the issue tracker"

Create a Linear issue using the MCP tool or API.

## When a skill says "fetch the relevant ticket"

Use `linear_get_issue` MCP tool or API query.

## Wayfinding operations

Used by the `/wayfinder` skill. The map is a Linear project or parent issue; tickets are issues within that project or sub-issues.

### Labels (bootstrap once)

Create labels in Linear's settings UI or via API:

- `wayfinder:map`, `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, `wayfinder:task`, `wayfinder:blocked`

### The map

- **Create**: create a Linear project or a parent issue with `wayfinder:map` label
- **Never** add `ready-for-agent` to a map — it is PRD-shaped.
- **Read**: `linear_get_issue` or `linear_get_project`
- **Update**: `linear_update_issue` or `linear_update_project`

### Tickets (child issues or project issues)

- **Create**: `linear_create_issue` with `parentId` (for sub-issues) or `projectId` (for project issues)
- **Claim**: `linear_update_issue` with `assigneeId: "@me"` — assignment is the claim.
- Type label is one of `wayfinder:research|prototype|grilling|task`.

### Blocking & the frontier

- Use Linear's native blocking relationships: `linear_update_issue` with `blockedByIds`
- Alternatively, add `wayfinder:blocked` label and note blockers in description
- **Frontier query**: search for open, unassigned issues in the project without `wayfinder:blocked` label and no unresolved blockers

### Resolution

1. **Answer**: `linear_create_comment` on the ticket
2. **Close**: `linear_update_issue` with state → Done
3. **Index it**: append one line to the map's description "Decisions so far"
4. **Mirror the decision** to `docs/decision-log.md` via `/decision-log`

## PRs as a request surface

Linear integrates with GitHub/GitLab — PRs link to issues via branch naming (`eng-123-feature-name`) or commit messages. PR triage happens in the code platform; Linear reflects the linked state. This setting is N/A for Linear-only workflows.
