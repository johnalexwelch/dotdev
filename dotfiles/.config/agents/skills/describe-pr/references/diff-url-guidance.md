# Diff URL Guidance

Load this during Step 1 when gathering PR inputs.

Generate per-file GitHub diff anchors inline:

1. `git remote get-url origin` and parse either `github.com:<owner>/<repo>.git` or `https://github.com/<owner>/<repo>.git` into `https://github.com/<owner>/<repo>`.
2. For each changed file, run `printf '%s' "<path>" | git hash-object --stdin` and use the first 8 characters as the diff anchor.
3. If a PR exists, use: `https://github.com/<owner>/<repo>/pull/<pr_number>/files#diff-<anchor>`.
4. If no PR exists, use: `https://github.com/<owner>/<repo>/compare/<base>...<branch>#diff-<anchor>`.
5. If the remote is not GitHub or `git hash-object` is unavailable, omit per-file permalinks and use the compare or PR URL instead.
