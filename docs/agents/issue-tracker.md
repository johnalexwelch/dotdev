# Issue tracker: GitHub

Issues and PRDs for this repo (`johnalexwelch/dotdev`) live as GitHub issues. Use the `gh` CLI for all operations. This repo already runs the delivery funnel on itself (see `docs/decision-log.md`: PRD #52 → issue #53 → PRs).

## PRs as a request surface

**PRs as a request surface**: no.

Solo repo — external pull requests are not a triage intake surface. `/triage` handles issues only.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc or `--body-file` for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, fetching labels alongside.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with `--label`/`--state` filters.
- **Comment**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

The repo is inferred from `git remote -v` — `gh` does this automatically inside a clone.

## Triage labels

Canonical five (names as-is): `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`, plus the local additions `needs-human-review` (review gate) and the three-way `wontfix` split (already-implemented / rejected-bug / rejected-enhancement). `workflow-guard.sh` enforces that PRD/spec-shaped parent issues are **never** labelled `ready-for-agent` — only child implementation issues are.

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
- **Claim** (first, before any work): `gh issue edit <ticket> --add-assignee @me` — assignment *is* the claim.
- Type label is one of `wayfinder:research|prototype|grilling|task`.

### Blocking & the frontier

- **Native**: use GitHub issue dependencies ("blocked by") when available — renders the frontier in the GitHub UI.
- **Fallback** (always safe): add a `Blocked by: #N` line to the blocked ticket's body and label it `wayfinder:blocked`; drop the label when the last blocker closes.
- **Frontier query** (open, unblocked, unclaimed children of the map):
  `gh issue list --state open --search "no:assignee -label:wayfinder:blocked" --json number,title,labels,assignees`, then keep only sub-issues of the map whose blockers are all closed.

### Resolution

1. **Answer**: `gh issue comment <ticket> --body-file <answer>`
2. **Close**: `gh issue close <ticket>`
3. **Index it**: append one line to the map body's "Decisions so far" (`gh issue edit <map> --body-file ...`)
4. **Mirror the decision** to `docs/decision-log.md` via `/decision-log` — the canonical record with alternatives/tradeoffs.

### How a cleared route hands off

Wayfinder plans; it does not deliver. When a map's route is clear, hand it into the normal funnel by the destination's shape (named in the map's `## Notes`):

- product / feature work → `/to-prd` → `/to-issues` → `/triage`
- refactor / migration / infra → `/design-plan` → `/execute-phase`
- strategic decision / roadmap → `/workflow-roadmap` (human gate) or a `/decision-log` entry, then stop.
