# Config and Secrets Hygiene

## Summary

No embedded API keys, tokens, passwords, or credentials committed to the repo. No `.env*` files tracked. `.gitignore` properly excludes OMC runtime state. Minor findings: hardcoded organizational context ("iris"/"classdojo" project names in `slack-update` example output), machine-specific paths in documentation examples (acceptable as reference), and personally-identifying username `alexwelch` in a few phase-run outcome files and plan example paths. Secrets-handling patterns documented in skills (e.g., `slack-update`'s token-resolution chain) are sound — tokens are read from env or `.env` but never embedded in skill files.

## Findings

### PASS: No embedded credentials
- Grepped for `token`, `secret`, `password`, `credential`, `BEARER`, `BEGIN PRIVATE`, API-key patterns across all SKILL.md files, phase-run outcomes, and plan files
- All references are variable names, placeholder templates, or process descriptions — no actual values

### PASS: `.env*` files not committed
- `find -name '.env*'`: zero results in the repo
- `.gitignore` does not need env patterns added (none exist to ignore)

### LOW: Organizational context leak in slack-update examples
- `slack-update/SKILL.md` lines 113, 117: example Slack message output contains `<https://github.com/classdojo/iris/pull/128|#128>` — leaks employer + internal project name
- Assessment: documentation examples, not live URLs, but organizational info

### LOW: Machine-specific paths in docs
- `slack-update/SKILL.md` references `~/projects/iris/.env` as bot-token fallback location
- `write-to-obsidian/SKILL.md` hardcodes `~/Documents/Home/` as vault root
- `setup-worktree/SKILL.md` defaults to `~/wt/<repo>/phase-<N>/`
- Assessment: acceptable conventions using tilde expansion; no absolute `/Users/alexwelch/` paths hardcoded in skill files themselves

### LOW: Username in execution artifacts
- Several phase-run outcome files contain `/Users/alexwelch/...` absolute paths in `**Plan:**` headers and example prompts
- The username is the git author already (not a new leak), and phase-run files are working artifacts that get overwritten per run

### PASS: `.omc/` state doesn't leak
- Sampled `.omc/state/*.json`: session UUIDs, cost/token stats, timestamps — no credentials
- Pre-gitignore baseline commit `b9a579e` did capture some state, but it contained only runtime metadata (no secrets). Commit `019414d` untracked these, and `.gitignore` prevents future tracking.

### MEDIUM (process risk): Token resolution via .env reads
`slack-update` documents a token-resolution chain that reads `.env` files from project root and a hardcoded `~/projects/iris/.env` fallback. This is sound design (env-first, never-embedded) but depends on user discipline for `.env` file permissions.

## Evidence

- `find . -type f -name '.env*'`: 0 matches
- `grep -r 'alex.welch@' skills/*/SKILL.md`: 0 matches in skill bodies (only in CLAUDE.md's parent, outside this repo)
- `grep -r 'Users/alexwelch' docs/`: matches only in phase-run outcome files (runtime artifacts) and plan examples
- `git log -p b9a579e 019414d`: no API keys or tokens detected

## Open questions

1. Should the "iris"/"classdojo" references in `slack-update` examples be anonymized to `<your-org>/<project>` for open-source-ability?
2. Should phase-run outcome files sanitize absolute paths to relative before committing? (Currently tracked.)
3. If this repo ever gets pushed to a public GitHub remote, a pre-push hook with `gitleaks` or `trufflehog` would be prudent.
