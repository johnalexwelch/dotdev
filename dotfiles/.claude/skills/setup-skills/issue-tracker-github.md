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
