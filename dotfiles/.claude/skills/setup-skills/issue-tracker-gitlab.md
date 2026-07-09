# Issue tracker: GitLab

Issues and PRDs for this repo live as GitLab issues. Use the [`glab`](https://gitlab.com/gitlab-org/cli) CLI for all operations.

## PRs as a request surface

**PRs as a request surface**: yes / no (default: no)

If yes, `/triage` pulls external merge requests into the same triage queue as issues and runs them through the same labels and states — GitLab calls a PR a "merge request" (MR), but the concept is the same: an issue with attached code. Collaborators' (project members') in-flight MRs are excluded from discovery (an explicitly named MR is still triaged regardless of author).

- **External author**: the MR author is not a project member. Check with `glab api projects/:id/members/all -F json` and compare against the MR's author.
- **Read an MR**: `glab mr view <number> --comments`, plus `glab mr diff <number>` for the change itself.
- **List MRs**: `glab mr list -F json` with appropriate `--label` filters; filter out member authors before presenting for triage discovery.
- **Comment on an MR**: `glab mr note <number> --message "..."`
- **Apply / remove labels**: `glab mr update <number> --label "..."` / `--unlabel "..."`
- **Close**: `glab mr close <number>` (post the explanation first with `glab mr note <number> --message "..."`, then close; triage closes, it does not merge)

## Conventions

- **Create an issue**: `glab issue create --title "..." --description "..."`. Use a heredoc for multi-line descriptions. Pass `--description -` to open an editor.
- **Read an issue**: `glab issue view <number> --comments`. Use `-F json` for machine-readable output.
- **List issues**: `glab issue list -F json` with appropriate `--label` filters.
- **Comment on an issue**: `glab issue note <number> --message "..."`. GitLab calls comments "notes".
- **Apply / remove labels**: `glab issue update <number> --label "..."` / `--unlabel "..."`. Multiple labels can be comma-separated or by repeating the flag.
- **Close**: `glab issue close <number>`. `glab issue close` does not accept a closing comment, so post the explanation first with `glab issue note <number> --message "..."`, then close.
- **Merge requests**: GitLab calls PRs "merge requests". Use `glab mr create`, `glab mr view`, `glab mr note`, etc. — the same shape as `gh pr ...` with `mr` in place of `pr` and `note`/`--message` in place of `comment`/`--body`.

Infer the repo from `git remote -v` — `glab` does this automatically when run inside a clone.

## When a skill says "publish to the issue tracker"

Create a GitLab issue.

## When a skill says "fetch the relevant ticket"

Run `glab issue view <number> --comments`.
